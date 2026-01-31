extends Node3D

const PLAYER_SCENE := preload("res://scenes/entites/player.tscn")

@onready var spawn_points: Array[Node]
@onready var players_container: Node3D = $Players
@onready var game_over_label: Label = $GameOverUI/GameOverLabel
@onready var game_over_ui: CanvasLayer = $GameOverUI

var spawned_players := {}
var hacker_id: int = -1
var detective_id: int = -1
var game_over := false

func _ready() -> void:
	add_to_group("game")
	spawn_points = $NavigationRegion3D/FuncGodotMap.find_children("*_info_player_start", "Marker3D", true)
	# Connect to multiplayer signals
	MultiplayerManager.player_connected.connect(_on_player_connected)
	MultiplayerManager.player_disconnected.connect(_on_player_disconnected)
	
	# Hide game over UI initially
	if game_over_ui:
		game_over_ui.visible = false
	
	# Spawn existing players (including ourselves)
	for player_id in MultiplayerManager.get_all_player_ids():
		_spawn_player(player_id)
	
	# If we're the server and only one player, spawn ourselves
	if MultiplayerManager.is_server() and spawned_players.is_empty():
		_spawn_player(1)
	
	# Assign roles after a short delay to ensure all players are spawned
	if MultiplayerManager.is_server():
		get_tree().create_timer(0.5).timeout.connect(_assign_roles)

func _on_player_connected(peer_id: int) -> void:
	# Only the server initiates spawning for everyone
	if multiplayer.is_server():
		_spawn_player_remote.rpc(peer_id)
		# Reassign roles when a new player joins
		_assign_roles()

func _on_player_disconnected(peer_id: int) -> void:
	_remove_player(peer_id)

func _spawn_player(peer_id: int) -> void:
	if spawned_players.has(peer_id):
		return
	
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	
	players_container.add_child(player, true)
	spawned_players[peer_id] = player
	
	# Get spawn position
	var spawn_index := spawned_players.size() % spawn_points.size()
	var spawn_point := spawn_points[spawn_index]
	if spawn_point:
		player.global_position = spawn_point.global_position
	
	print("Spawned player %d" % peer_id)

func _remove_player(peer_id: int) -> void:
	if spawned_players.has(peer_id):
		spawned_players[peer_id].queue_free()
		spawned_players.erase(peer_id)
		print("Removed player %d" % peer_id)

@rpc("authority", "reliable", "call_local")
func _spawn_player_remote(peer_id: int) -> void:
	_spawn_player(peer_id)

func _assign_roles() -> void:
	if not multiplayer.is_server():
		return
	
	if game_over:
		return
	
	var player_ids = spawned_players.keys()
	if player_ids.size() < 2:
		# Need at least 2 players
		return
	
	# Randomly assign hacker and detective
	player_ids.shuffle()
	hacker_id = player_ids[0]
	detective_id = player_ids[1]
	
	# Set roles for all players
	for player_id in player_ids:
		var player = spawned_players.get(player_id)
		if player:
			var role = Player.Role.NONE
			if player_id == hacker_id:
				role = Player.Role.HACKER
			elif player_id == detective_id:
				role = Player.Role.DETECTIVE
			# Call RPC to set role on all clients
			player.set_role.rpc_id(player_id, role)
	
	print("Roles assigned - Hacker: %d, Detective: %d" % [hacker_id, detective_id])

func handle_unmask_request(requester_id: int, target_robot_path: String) -> void:
	if not multiplayer.is_server():
		return
	
	if game_over:
		print("Game over, ignoring unmask request")
		return
	
	# Verify requester is detective
	if requester_id != detective_id:
		print("Requester %d is not detective %d, denying unmask" % [requester_id, detective_id])
		return
	
	# Get target robot by node path
	var target_robot = get_node_or_null(target_robot_path)
	
	if not target_robot or not target_robot is Robot or target_robot.is_mask_removed:
		print("Invalid target or already unmasked")
		return
	
	print("Unmasking target robot: %s" % target_robot.name)
	# Unmask the target
	target_robot.remove_mask.rpc()
	
	# Wait 1 second
	await get_tree().create_timer(1.0).timeout
	
	# Check if detective unmasked the hacker (only applies to players)
	# For players, their name is their peer_id
	if target_robot is Player:
		var target_id = target_robot.name.to_int()
		if target_id == hacker_id:
			_detective_wins()
	
func _detective_wins() -> void:
	if not multiplayer.is_server():
		return
	
	game_over = true
	_show_game_over.rpc("Detective Wins!")
	print("Detective wins by unmasking the hacker!")

@rpc("authority", "call_local", "reliable")
func _show_game_over(message: String) -> void:
	if game_over_label and game_over_ui:
		game_over_label.text = message
		game_over_ui.visible = true
		
		# Capture mouse for UI
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	game_over = true

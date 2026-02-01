extends Node3D

const PLAYER_SCENE := preload("res://scenes/entites/player.tscn")
const NPC_SPAWNER_SCENE := preload("res://scenes/components/npc_spawner.tscn")

const SFX_INCORRECT := preload("res://assets/sfx/incorrect.mp3")
const SFX_WIN := preload("res://assets/sfx/win.mp3")

@onready var spawn_points: Array[Node]
@onready var players_container: Node3D = $Players
@onready var game_over_label: Label = $GameOverUI/GameOverLabel
@onready var game_over_ui: CanvasLayer = $GameOverUI
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var spawned_players := {}
var hacker_id: int = -1
var detective_id: int = -1
var detective_guesses_remaining := 3
var game_over := false

# NPC Spawner reference
var npc_spawner: NPCSpawner = null

# Track hacked NPCs for win condition
var total_npcs := 0
var hacked_npcs := 0
const HACK_WIN_PERCENTAGE := 0.7

func _ready() -> void:
	add_to_group("game")
	spawn_points = $Map.find_children("*_info_player_start", "Marker3D", true)
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
	
	# Create and add the NPC spawner
	_setup_npc_spawner()
	
	# Assign roles after a short delay to ensure all players are spawned
	if MultiplayerManager.is_server():
		get_tree().create_timer(0.5).timeout.connect(_assign_roles)
		# Count NPCs after they've spawned (give more time for NPC spawner)
		get_tree().create_timer(2.0).timeout.connect(_count_npcs)

func _process(_delta: float) -> void:
	if game_over:
		$GameOverUI/MenuReturnLabel.text = "Returning to lobby in " + str(int($MenuTimer.time_left) + 1) + " second(s)"

func _setup_npc_spawner() -> void:
	# Instantiate the NPC spawner
	npc_spawner = NPC_SPAWNER_SCENE.instantiate() as NPCSpawner
	add_child(npc_spawner)
	
	# If there's a SpawnRegion in the scene, use it
	var spawn_region = get_node_or_null("SpawnRegion")
	if spawn_region:
		npc_spawner.spawn_area = spawn_region

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
	
	detective_guesses_remaining = 3
	
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
	
	# Initial guess count sync
	if spawned_players.has(detective_id):
		spawned_players[detective_id].update_guesses.rpc_id(detective_id, detective_guesses_remaining)
	
	# Initial hacker progress sync
	_sync_hacker_progress()

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
	
	# Check if detective has guesses left
	if detective_guesses_remaining <= 0:
		print("Detective out of guesses")
		return
	
	# Get target robot by node path
	var target_robot = get_node_or_null(target_robot_path)
	
	if not target_robot or not target_robot is Robot or target_robot.is_mask_removed:
		print("Invalid target or already unmasked")
		return
	
	# Decrement guesses
	detective_guesses_remaining -= 1
	
	# Sync remaining guesses
	if spawned_players.has(detective_id):
		spawned_players[detective_id].update_guesses.rpc_id(detective_id, detective_guesses_remaining)
		
	print("Unmasking target robot: %s. Guesses remaining: %d" % [target_robot.name, detective_guesses_remaining])
	
	# Determine if this is the hacker
	var is_hacker = false
	if target_robot is Player and target_robot.name.to_int() == hacker_id:
		is_hacker = true
	
	# Play appropriate sound
	_play_sfx.rpc(is_hacker)
	
	# Unmask the target
	target_robot.remove_mask.rpc()
	
	# Wait 1 second
	await get_tree().create_timer(1.0).timeout
	
	# Check if detective unmasked the hacker
	if is_hacker:
		_detective_wins()
	elif detective_guesses_remaining <= 0 and not game_over:
		_hacker_wins_no_guesses()

@rpc("authority", "call_local", "reliable")
func _play_sfx(is_win: bool) -> void:
	if sfx_player:
		sfx_player.stream = SFX_WIN if is_win else SFX_INCORRECT
		sfx_player.play()

func _hacker_wins_no_guesses() -> void:
	if not multiplayer.is_server():
		return
	
	game_over = true
	$MenuTimer.start()
	
	_show_game_over.rpc("Hacker Wins!\nDetective out of guesses")
	print("Hacker wins because detective ran out of guesses!")

func _detective_wins() -> void:
	if not multiplayer.is_server():
		return
	
	game_over = true
	$MenuTimer.start()
	
	_show_game_over.rpc("Detective Wins!")
	print("Detective wins by unmasking the hacker!")

func _count_npcs() -> void:
	# Use the NPC spawner's count if available
	if npc_spawner:
		total_npcs = npc_spawner.get_valid_npc_count()
	else:
		# Fallback: count from robot group
		var npcs = get_tree().get_nodes_in_group("robot")
		for robot in npcs:
			if robot is NPC:
				total_npcs += 1
	print("Total NPCs counted: %d" % total_npcs)
	_sync_hacker_progress()

func handle_hack_request(requester_id: int, target_robot_path: String, hacker_robot_path: String) -> void:
	if not multiplayer.is_server():
		return
	
	if game_over:
		print("Game over, ignoring hack request")
		return
	
	# Verify requester is hacker
	if requester_id != hacker_id:
		print("Requester %d is not hacker %d, denying hack" % [requester_id, hacker_id])
		return
	
	# Get target robot by node path
	var target_robot = get_node_or_null(target_robot_path)
	var hacker_robot = get_node_or_null(hacker_robot_path)
	
	if not target_robot or not target_robot is Robot or target_robot.is_hacked:
		print("Invalid target or already hacked")
		return
	
	if not hacker_robot or not hacker_robot is Robot:
		print("Invalid hacker robot")
		return
	
	print("Hacking target robot: %s" % target_robot.name)
	
	# Convert colors to a regular array for RPC
	var hacker_colors_array: Array = []
	for color in hacker_robot.current_colors:
		hacker_colors_array.append(color)
	
	# Apply hack to target with hacker's attributes
	target_robot.apply_hack.rpc(
		hacker_robot.current_head_idx,
		hacker_robot.current_arms_idx,
		hacker_robot.current_body_idx,
		hacker_robot.current_bottom_idx,
		hacker_robot.current_accessory_idx,
		hacker_colors_array
	)
	
	# Track hacked NPCs
	if target_robot is NPC:
		hacked_npcs += 1
		print("NPCs hacked: %d / %d (%.1f%%)" % [hacked_npcs, total_npcs, (float(hacked_npcs) / max(total_npcs, 1)) * 100])
		_sync_hacker_progress()
		_check_hacker_win()

func _sync_hacker_progress() -> void:
	if spawned_players.has(hacker_id):
		print("Syncing hacker progress to %d: %d/%d" % [hacker_id, hacked_npcs, total_npcs])
		spawned_players[hacker_id].update_infection_progress.rpc_id(hacker_id, hacked_npcs, total_npcs, HACK_WIN_PERCENTAGE)
	
	if spawned_players.has(detective_id):
		spawned_players[detective_id].update_infection_progress.rpc_id(detective_id, hacked_npcs, total_npcs, HACK_WIN_PERCENTAGE)

func _check_hacker_win() -> void:
	if not multiplayer.is_server():
		return
	
	if total_npcs <= 0:
		return
	
	var hack_percentage = float(hacked_npcs) / float(total_npcs)
	if hack_percentage >= HACK_WIN_PERCENTAGE:
		_hacker_wins()

func _hacker_wins() -> void:
	if not multiplayer.is_server():
		return
	
	game_over = true
	$MenuTimer.start()
	
	_show_game_over.rpc("Hacker Wins!\nHacked %d%% of NPCs" % [int((float(hacked_npcs) / float(total_npcs)) * 100)])
	print("Hacker wins by hacking %.1f%% of NPCs!" % [(float(hacked_npcs) / float(total_npcs)) * 100])

@rpc("authority", "call_local", "reliable")
func _show_game_over(message: String) -> void:
	if game_over_label and game_over_ui:
		game_over_label.text = message
		game_over_ui.visible = true
		
		# Capture mouse for UI
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	game_over = true
	$MenuTimer.start()


func _on_menu_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

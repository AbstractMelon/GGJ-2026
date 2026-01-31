extends Node3D

const PLAYER_SCENE := preload("res://scenes/entites/player.tscn")

@onready var spawn_points: Node3D = $SpawnPoints
@onready var players_container: Node3D = $Players

var spawned_players := {}

func _ready() -> void:
	# Connect to multiplayer signals
	MultiplayerManager.player_connected.connect(_on_player_connected)
	MultiplayerManager.player_disconnected.connect(_on_player_disconnected)
	
	# Spawn existing players (including ourselves)
	for player_id in MultiplayerManager.get_all_player_ids():
		_spawn_player(player_id)
	
	# If we're the server and only one player, spawn ourselves
	if MultiplayerManager.is_server() and spawned_players.is_empty():
		_spawn_player(1)

func _on_player_connected(peer_id: int) -> void:
	# Only the server spawns players
	if multiplayer.is_server():
		_spawn_player(peer_id)
		
		# Tell the new player to spawn all existing players
		for existing_id in spawned_players.keys():
			if existing_id != peer_id:
				_spawn_player_remote.rpc_id(peer_id, existing_id)

func _on_player_disconnected(peer_id: int) -> void:
	_remove_player(peer_id)

func _spawn_player(peer_id: int) -> void:
	if spawned_players.has(peer_id):
		return
	
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	
	# Get spawn position
	var spawn_index := spawned_players.size() % spawn_points.get_child_count()
	var spawn_point := spawn_points.get_child(spawn_index) as Node3D
	if spawn_point:
		player.global_position = spawn_point.global_position
	
	players_container.add_child(player, true)
	spawned_players[peer_id] = player
	
	print("Spawned player %d" % peer_id)

func _remove_player(peer_id: int) -> void:
	if spawned_players.has(peer_id):
		spawned_players[peer_id].queue_free()
		spawned_players.erase(peer_id)
		print("Removed player %d" % peer_id)

@rpc("authority", "reliable", "call_local")
func _spawn_player_remote(peer_id: int) -> void:
	_spawn_player(peer_id)

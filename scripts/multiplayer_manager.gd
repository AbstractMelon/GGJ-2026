extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal connection_succeeded()
signal server_created()

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 2

var player_info := {}
var local_player_name := "Player"
var in_lobby: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS)
	
	if error != OK:
		push_error("Failed to create server: %s" % error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	player_info[1] = {"name": local_player_name}
	in_lobby = true
	
	print("Server created on port %d" % port)
	server_created.emit()
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	
	if error != OK:
		push_error("Failed to create client: %s" % error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Connecting to %s:%d" % [address, port])
	return OK

func disconnect_from_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	player_info.clear()
	in_lobby = false

func is_server() -> bool:
	return multiplayer.is_server()

func get_unique_id() -> int:
	return multiplayer.get_unique_id()

func _on_peer_connected(id: int) -> void:
	print("Peer connected: %d" % id)
	# Send our info to the new peer
	_register_player.rpc_id(id, local_player_name)
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: %d" % id)
	player_info.erase(id)
	player_disconnected.emit(id)
	

func _on_connected_to_server() -> void:
	print("Connected to server!")
	var my_id := multiplayer.get_unique_id()
	player_info[my_id] = {"name": local_player_name}
	connection_succeeded.emit()
	in_lobby = true

func _on_connection_failed() -> void:
	print("Connection failed!")
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("Server disconnected!")
	multiplayer.multiplayer_peer = null
	player_info.clear()
	player_disconnected.emit(1)
	in_lobby = false

@rpc("any_peer", "reliable")
func _register_player(player_name: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	player_info[sender_id] = {"name": player_name}
	print("Registered player %s with id %d" % [player_name, sender_id])
	player_connected.emit(sender_id)

func get_player_count() -> int:
	return player_info.size()

func get_all_player_ids() -> Array:
	return player_info.keys()

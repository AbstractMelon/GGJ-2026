extends Control

# Main Menu - Handles hosting and joining games

@onready var main_menu: VBoxContainer = $MainMenu
@onready var host_menu: VBoxContainer = $HostMenu
@onready var join_menu: VBoxContainer = $JoinMenu
@onready var lobby_menu: VBoxContainer = $LobbyMenu

@onready var player_name_input: LineEdit = $MainMenu/PlayerNameInput
@onready var port_input_host: LineEdit = $HostMenu/PortInput
@onready var ip_input: LineEdit = $JoinMenu/IPInput
@onready var port_input_join: LineEdit = $JoinMenu/PortInput
@onready var status_label: Label = $LobbyMenu/StatusLabel
@onready var player_list: Label = $LobbyMenu/PlayerList
@onready var start_button: Button = $LobbyMenu/StartButton

func _ready() -> void:
	_show_main_menu()
	
	# Connect multiplayer signals
	MultiplayerManager.server_created.connect(_on_server_created)
	MultiplayerManager.connection_succeeded.connect(_on_connection_succeeded)
	MultiplayerManager.connection_failed.connect(_on_connection_failed)
	MultiplayerManager.player_connected.connect(_on_player_connected)
	MultiplayerManager.player_disconnected.connect(_on_player_disconnected)
	
	_process_test_flags()

func _show_main_menu() -> void:
	main_menu.visible = true
	host_menu.visible = false
	join_menu.visible = false
	lobby_menu.visible = false

func _show_host_menu() -> void:
	main_menu.visible = false
	host_menu.visible = true
	join_menu.visible = false
	lobby_menu.visible = false

func _show_join_menu() -> void:
	main_menu.visible = false
	host_menu.visible = false
	join_menu.visible = true
	lobby_menu.visible = false

func _show_lobby() -> void:
	main_menu.visible = false
	host_menu.visible = false
	join_menu.visible = false
	lobby_menu.visible = true
	_update_player_list()

# Main Menu buttons
func _on_host_button_pressed() -> void:
	_show_host_menu()

func _on_join_button_pressed() -> void:
	_show_join_menu()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

# Host Menu buttons
func _on_create_server_button_pressed() -> void:
	var player_name := player_name_input.text if player_name_input.text != "" else "Host"
	MultiplayerManager.local_player_name = player_name
	
	var port := port_input_host.text.to_int()
	if port <= 0:
		port = MultiplayerManager.DEFAULT_PORT
	
	var error := MultiplayerManager.host_game(port)
	if error == OK:
		status_label.text = "Hosting on port %d\nWaiting for player..." % port
		start_button.visible = true
		_show_lobby()

func _on_host_back_button_pressed() -> void:
	_show_main_menu()

# Join Menu buttons
func _on_connect_button_pressed() -> void:
	var player_name := player_name_input.text if player_name_input.text != "" else "Client"
	MultiplayerManager.local_player_name = player_name
	
	var ip := ip_input.text if ip_input.text != "" else "127.0.0.1"
	var port := port_input_join.text.to_int()
	if port <= 0:
		port = MultiplayerManager.DEFAULT_PORT
	
	var error := MultiplayerManager.join_game(ip, port)
	if error == OK:
		status_label.text = "Connecting to %s:%d..." % [ip, port]
		start_button.visible = false
		_show_lobby()

func _on_join_back_button_pressed() -> void:
	_show_main_menu()

# Lobby buttons
func _on_start_button_pressed() -> void:
	if MultiplayerManager.is_server():
		_start_game.rpc()

func _on_lobby_back_button_pressed() -> void:
	MultiplayerManager.disconnect_from_game()
	_show_main_menu()

# Multiplayer callbacks
func _on_server_created() -> void:
	status_label.text = "Server created!\nWaiting for player to join..."
	_update_player_list()

func _on_connection_succeeded() -> void:
	status_label.text = "Connected to server!"
	_update_player_list()

func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"
	await get_tree().create_timer(2.0).timeout
	_show_main_menu()

func _on_player_connected(_peer_id: int) -> void:
	_update_player_list()
	if MultiplayerManager.is_server():
		status_label.text = "Player joined! Ready to start."

func _on_player_disconnected(_peer_id: int) -> void:
	_update_player_list()
	if MultiplayerManager.is_server():
		status_label.text = "Player left. Waiting for player..."

func _update_player_list() -> void:
	var text := "Players:\n"
	for player_id in MultiplayerManager.player_info:
		var info: Dictionary = MultiplayerManager.player_info[player_id]
		var name_str: String = info.get("name", "Unknown")
		text += "- %s (ID: %d)\n" % [name_str, player_id]
	player_list.text = text

@rpc("authority", "reliable", "call_local")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _process_test_flags() -> void:
	var args := OS.get_cmdline_args()
	var user_args := OS.get_cmdline_user_args()
	
	var is_host := "--test-host" in args or "--test-host" in user_args
	var is_client := "--test-client" in args or "--test-client" in user_args
	
	if is_host:
		print("Test Host flag detected")
		player_name_input.text = "TestHost"
		# Small delay to ensure everything is initialized
		await get_tree().create_timer(0.2).timeout
		_on_create_server_button_pressed()
		
		# Auto-start game when a player joins
		MultiplayerManager.player_connected.connect(func(_id):
			print("Player joined, auto-starting game...")
			_on_start_button_pressed()
		, CONNECT_ONE_SHOT)
		
	elif is_client:
		print("Test Client flag detected")
		player_name_input.text = "TestClient"
		# Wait for the host to be ready
		await get_tree().create_timer(1.0).timeout
		_on_connect_button_pressed()

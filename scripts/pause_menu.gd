extends CanvasLayer

@onready var pause_panel: Control = $PausePanel
@onready var settings_menu: Control = $SettingsMenu
@onready var ip_label: Label = $PausePanel/VBoxContainer/IPLabel

func _ready() -> void:
	visible = false
	_show_pause()
	ip_label.text = "Host IP: " + SettingsManager.get_ip_address()
	if settings_menu.has_signal("back_pressed"):
		settings_menu.back_pressed.connect(_show_pause)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			if settings_menu.visible:
				_show_pause()
			else:
				resume_game()
		else:
			pause_game()

func pause_game() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_pause()

func resume_game() -> void:
	visible = false
	# Only trap mouse if player exists and isn't game over
	var game = get_tree().get_first_node_in_group("game")
	if game and not game.game_over:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_pause() -> void:
	pause_panel.visible = true
	settings_menu.visible = false

func _show_settings() -> void:
	pause_panel.visible = false
	settings_menu.visible = true

# Pause Menu Signals
func _on_resume_button_pressed() -> void:
	resume_game()

func _on_settings_button_pressed() -> void:
	_show_settings()

func _on_back_to_lobby_button_pressed() -> void:
	get_tree().paused = false
	MultiplayerManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()




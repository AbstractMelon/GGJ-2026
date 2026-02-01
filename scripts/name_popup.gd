extends AcceptDialog

@onready var name_input: LineEdit = $MarginContainer/VBoxContainer/NameInput

func _ready() -> void:
	dialog_text = "Welcome to Machine Masquerade!\n\nPlease enter your designation:"
	ok_button_text = "Confirm"
	name_input.text = ""
	name_input.grab_focus()

func _on_confirmed() -> void:
	var entered_name = name_input.text.strip_edges()
	if entered_name == "":
		entered_name = "Anonymous"
	
	SettingsManager.player_name = entered_name
	SettingsManager.first_time = false
	SettingsManager.save_settings()
	queue_free()

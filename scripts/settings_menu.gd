extends Control

signal back_pressed

@onready var sfx_slider: HSlider = $CenterContainer/VBoxContainer/SFXContainer/SFXSlider
@onready var music_slider: HSlider = $CenterContainer/VBoxContainer/MusicContainer/MusicSlider
@onready var fullscreen_check: CheckButton = $CenterContainer/VBoxContainer/FullscreenContainer/FullscreenCheck
@onready var vsync_check: CheckButton = $CenterContainer/VBoxContainer/VSyncContainer/VSyncCheck
@onready var resolution_option: OptionButton = $CenterContainer/VBoxContainer/ResolutionContainer/ResolutionOption

var resolutions = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

func _ready() -> void:
	# Setup resolution options
	resolution_option.clear()
	for res in resolutions:
		resolution_option.add_item("%dx%d" % [res.x, res.y])
	
	# Initialize settings UI values
	sfx_slider.value = SettingsManager.sfx_volume
	music_slider.value = SettingsManager.music_volume
	fullscreen_check.button_pressed = SettingsManager.fullscreen
	vsync_check.button_pressed = SettingsManager.vsync
	
	for i in range(resolutions.size()):
		if resolutions[i] == SettingsManager.resolution:
			resolution_option.selected = i
			break

func _on_sfx_slider_value_changed(value: float) -> void:
	SettingsManager.sfx_volume = value
	SettingsManager.apply_settings()

func _on_music_slider_value_changed(value: float) -> void:
	SettingsManager.music_volume = value
	SettingsManager.apply_settings()

func _on_fullscreen_check_toggled(button_pressed: bool) -> void:
	SettingsManager.fullscreen = button_pressed
	SettingsManager.apply_settings()

func _on_vsync_check_toggled(button_pressed: bool) -> void:
	SettingsManager.vsync = button_pressed
	SettingsManager.apply_settings()

func _on_resolution_option_item_selected(index: int) -> void:
	SettingsManager.resolution = resolutions[index]
	SettingsManager.apply_settings()

func _on_back_button_pressed() -> void:
	SettingsManager.save_settings()
	back_pressed.emit()

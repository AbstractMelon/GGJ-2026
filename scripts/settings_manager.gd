extends Node

const SETTINGS_FILE = "user://settings.cfg"

var sfx_volume: float = 0.8
var music_volume: float = 0.5
var fullscreen: bool = false
var vsync: bool = true
var resolution: Vector2i = Vector2i(1280, 720)

func _ready() -> void:
	load_settings()
	apply_settings()

func apply_settings() -> void:
	# Audio
	# Try to find Music and SFX buses, fallback to Master
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
	
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))

	# Display
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
	
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "resolution", resolution)
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		return
	
	sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
	music_volume = config.get_value("audio", "music_volume", 0.5)
	fullscreen = config.get_value("display", "fullscreen", false)
	vsync = config.get_value("display", "vsync", true)
	resolution = config.get_value("display", "resolution", Vector2i(1280, 720))

func get_ip_address() -> String:
	var ips = IP.get_local_addresses()
	for ip in ips:
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			return ip
	return "127.0.0.1"

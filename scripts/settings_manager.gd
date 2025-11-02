extends Node

const SETTINGS_PATH = "user://settings.cfg"
var settings_data = { }

const DEFAULTS = {
	"graphics": {
		"resolution": Vector2i(1920, 1080),
		"vsync_mode": DisplayServer.VSYNC_ENABLED,
		"fullscreen": true,
	},
}


func _ready():
	load_settings()


func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)

	if err != OK or config.get_sections().is_empty():
		print("No settings file found, loading defaults.")
		settings_data = DEFAULTS
		save_settings()
		return

	for section in config.get_sections():
		settings_data[section] = { }
		for key in config.get_section_keys(section):
			settings_data[section][key] = config.get_value(section, key)

	apply_graphics_settings()


func save_settings():
	var config = ConfigFile.new()

	for section in settings_data:
		for key in settings_data[section]:
			config.set_value(section, key, settings_data[section][key])

	config.save(SETTINGS_PATH)


func apply_graphics_settings():
	var gfx = settings_data["graphics"]

	DisplayServer.window_set_vsync_mode(gfx["vsync_mode"])

	if gfx["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	DisplayServer.window_set_size(gfx["resolution"])


func set_setting(section, key, value):
	if not settings_data.has(section):
		settings_data[section] = { }
	settings_data[section][key] = value


func get_setting(section, key):
	return settings_data.get(section, { }).get(key, null)

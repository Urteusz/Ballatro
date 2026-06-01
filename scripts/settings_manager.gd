extends Node

const SETTINGS_PATH = "user://settings.cfg"

enum WindowMode {
	FULLSCREEN,
	BORDERLESS,
	WINDOWED
}

const VSYNC_MODES = {
	"Disabled": DisplayServer.VSYNC_DISABLED,
	"Enabled": DisplayServer.VSYNC_ENABLED,
	"Adaptive": DisplayServer.VSYNC_ADAPTIVE,
	"Mailbox": DisplayServer.VSYNC_MAILBOX,
}

const RESOLUTIONS = [
	Vector2i(640, 480),
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

enum PostProcessAA {
	DISABLED,
	FXAA,
	SMAA,
	TAA,
}

const SCALING_3D_MODES = {
	"Bilinear": Viewport.SCALING_3D_MODE_BILINEAR,
	"FSR 1.0": Viewport.SCALING_3D_MODE_FSR,
	"FSR 2.2": Viewport.SCALING_3D_MODE_FSR2,
}

const ANISOTROPY_LEVELS = {
	"Disabled": 0,
	"2x": 1,
	"4x": 2,
	"8x": 3,
	"16x": 4
}

const DEFAULTS = {
	"graphics": {
		"resolution": Vector2i(1920, 1080),
		"vsync_mode": DisplayServer.VSYNC_ENABLED,
		"window_mode": WindowMode.FULLSCREEN,
		"msaa": Viewport.MSAA_DISABLED,
		"aa": PostProcessAA.SMAA,
		"anisotropy": 3,
		"max_fps": 60,
		"resolution_scale_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"resolution_scale": 1.0,
		"ui_scale": 1.0,
		"ssao_enabled": true,
		"ssil_enabled": true,
	},
	"controls": {
		"inverted_mouse": false,
		"pad_sensitivity": 1.0,
	},
	"audio": {
		"master_volume": 1.0,
	}
}

var settings_data = {}

func _ready():
	load_settings()
	apply_audio_settings()
	apply_graphics_settings()

func load_settings():
	settings_data = DEFAULTS.duplicate(true)
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)

	if err != OK:
		print("No settings file found or file corrupted. Using defaults.")
		save_settings()
		apply_graphics_settings()
		return

	for section in config.get_sections():
		if settings_data.has(section):
			for key in config.get_section_keys(section):
				if settings_data[section].has(key):
					var raw_value = config.get_value(section, key)
					settings_data[section][key] = validate_setting(section, key, raw_value)

	save_settings()

func save_settings():
	var config = ConfigFile.new()
	for section in settings_data:
		for key in settings_data[section]:
			config.set_value(section, key, settings_data[section][key])
	config.save(SETTINGS_PATH)

func apply_graphics_settings():
	var gfx = settings_data["graphics"]
	DisplayServer.window_set_vsync_mode(gfx["vsync_mode"])
	Engine.max_fps = gfx["max_fps"]
	
	ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", gfx["anisotropy"])
	
	var window = get_window()
	
	match gfx["window_mode"]:
		WindowMode.FULLSCREEN:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		WindowMode.BORDERLESS:
			window.mode = Window.MODE_FULLSCREEN
		WindowMode.WINDOWED:
			window.mode = Window.MODE_WINDOWED
			window.size = gfx["resolution"]
			var current_screen = DisplayServer.window_get_current_screen()
			var screen_pos = DisplayServer.screen_get_position(current_screen)
			var screen_size = DisplayServer.screen_get_size(current_screen)
			window.position = screen_pos + (screen_size / 2) - (window.size / 2)
	
	get_window().content_scale_factor = gfx["ui_scale"]
	
	var viewports = []
	_get_all_viewports(get_tree().root, viewports)
	
	for vp in viewports:
		vp.msaa_3d = gfx["msaa"]
		vp.scaling_3d_mode = gfx["resolution_scale_mode"]
		vp.scaling_3d_scale = gfx["resolution_scale"]
		
		match gfx["aa"]:
			PostProcessAA.DISABLED:
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				vp.use_taa = false
			PostProcessAA.FXAA:
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
				vp.use_taa = false
			PostProcessAA.SMAA:
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
				vp.use_taa = false
			PostProcessAA.TAA:
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				vp.use_taa = true
				
		var environment: Environment = null
		var camera = vp.get_camera_3d()
		
		if camera and camera.environment:
			environment = camera.environment
		elif vp.find_world_3d():
			environment = vp.find_world_3d().environment
			if not environment:
				environment = vp.find_world_3d().fallback_environment
				
		if environment:
			environment.ssao_enabled = gfx["ssao_enabled"]
			environment.ssil_enabled = gfx["ssil_enabled"]

func apply_audio_settings():
	var volume = settings_data["audio"]["master_volume"]
	var bus_index = AudioServer.get_bus_index("Master")
	if volume <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume))

func validate_setting(section: String, key: String, value: Variant) -> Variant:
	var default_value = DEFAULTS[section][key]
	
	if typeof(default_value) == TYPE_FLOAT and typeof(value) == TYPE_INT:
		value = float(value)
	elif typeof(value) != typeof(default_value):
		push_warning("Settings: Type mismatch for %s/%s. Falling back to default." % [section, key])
		return default_value
		
	match section:
		"graphics":
			match key:
				"window_mode":
					if not value in WindowMode.values(): return default_value
				"vsync_mode":
					if not value in VSYNC_MODES.values(): return default_value
				"aa":
					if not value in PostProcessAA.values(): return default_value
				"anisotropy":
					if not value in ANISOTROPY_LEVELS.values(): return default_value
				"msaa":
					if not [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X].has(value):
						return default_value
				"resolution":
					if not value in RESOLUTIONS: return default_value
				"max_fps":
					return clampi(int(value), 0, 360)
				"resolution_scale_mode":
					if not value in SCALING_3D_MODES.values(): return default_value
				"resolution_scale":
					return clampf(value, 0.5, 2.0)
				"ui_scale":
					return clampf(value, 0.5, 2.0)
		"controls":
			match key:
				"pad_sensitivity":
					return clampf(value, 0.1, 5.0)
		"audio":
			match key:
				"master_volume":
					return clampf(value, 0.0, 1.0)
	
	return value
	
func set_setting(section, key, value):
	if not settings_data.has(section):
		settings_data[section] = {}
	settings_data[section][key] = value

func get_setting(section, key):
	return settings_data.get(section, {}).get(key, null)

func _get_all_viewports(node: Node, viewports: Array) -> void:
	if node is Viewport:
		viewports.append(node)
	for child in node.get_children():
		_get_all_viewports(child, viewports)

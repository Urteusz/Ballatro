extends CanvasLayer

signal options_closed

# --- REFERENCJE DO WĘZŁÓW ---
@onready var resolution_button = %ResolutionButton
@onready var vsync_button = %VSyncButton
@onready var window_mode_button = %WindowModeButton

@onready var max_fps_slider = %MaxFPSSlider
@onready var max_fps_value_label = %MaxFPSValue

@onready var res_scale_mode_button = %ResolutionScaleModeButton
@onready var res_scale_slider = %ResolutionScaleSlider
@onready var res_scale_value_label = %ResolutionScaleValue

# broken
@onready var ui_scale_slider = %UIScaleSlider
@onready var ui_scale_value = %UIScaleValue

@onready var ssao_button = %SSAOButton
@onready var ssil_button = %SSILButton

# Anti-Aliasing
@onready var msaa_button = %MSAAButton
@onready var aa_button = %AAButton
@onready var anisotropy_button = %AnisotropyButton

@onready var apply_button = %ApplyButton

@onready var inverted_mouse_button = %InvertedMouseButton
@onready var pad_sensitivity_slider = %PadSensitivitySlider
@onready var pad_sensitivity_value_label = %PadSensitivityValue
@onready var volume_slider = %VolumeSlider
@onready var volume_value_label = %VolumeValue

@onready var quit_button = %QuitButton if has_node("%QuitButton") else null
@onready var reset_button = %ResetButton if has_node("%ResetButton") else null
@onready var root_ui = $Background

# Confirm dialog nodes
@onready var confirm_dialog = %ConfirmDialog
@onready var confirm_label = %ConfirmLabel
@onready var confirm_accept_button = %ConfirmAcceptButton
@onready var confirm_revert_button = %ConfirmRevertButton
@onready var confirm_timer = %ConfirmTimer

const COUNTDOWN_LENGTH: int = 10

var focused = false
var _open_dropdown = null

var _backup_graphics_settings: Dictionary = {}
var _countdown_time: int = COUNTDOWN_LENGTH

func _ready():
	root_ui.modulate.a = 0.0
	visible = false
	
	apply_button.pressed.connect(_on_apply_pressed)
	
	pad_sensitivity_slider.value_changed.connect(_on_pad_sensitivity_slider_value_changed)
	volume_slider.value_changed.connect(_on_volume_slider_value_changed)
	res_scale_slider.value_changed.connect(_on_res_scale_slider_value_changed)
	ui_scale_slider.value_changed.connect(_on_ui_scale_slider_value_changed)
	max_fps_slider.value_changed.connect(_on_max_fps_slider_value_changed)
	
	window_mode_button.item_selected.connect(_on_window_mode_selected)
	vsync_button.item_selected.connect(_on_vsync_selected)
	msaa_button.item_selected.connect(_on_msaa_selected)
	aa_button.item_selected.connect(_on_aa_selected)
	anisotropy_button.item_selected.connect(_on_anisotropy_selected)
	res_scale_mode_button.item_selected.connect(_on_res_scale_mode_selected)
	
	ssao_button.toggled.connect(_on_ssao_toggled)
	ssil_button.toggled.connect(_on_ssil_toggled)
	inverted_mouse_button.toggled.connect(_on_inverted_mouse_toggled)
	
	if quit_button:
		quit_button.pressed.connect(_on_back_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)

	confirm_accept_button.pressed.connect(_on_confirm_accept)
	confirm_revert_button.pressed.connect(_on_confirm_revert)
	confirm_timer.timeout.connect(_on_confirm_timer_tick)
	confirm_dialog.hide()

	populate_vsync_options()
	populate_aa_options()
	populate_anisotropy_options()
	populate_resolution_options()
	populate_window_mode_options()
	populate_res_scale_mode_options()
	load_current_settings()

	_setup_focus_nav()

	for ob in [resolution_button, vsync_button, window_mode_button, msaa_button, aa_button, anisotropy_button, res_scale_mode_button]:
		if ob:
			var popup = ob.get_popup()
			if not popup.about_to_popup.is_connected(_on_dropdown_about_to_popup):
				popup.about_to_popup.connect(_on_dropdown_about_to_popup.bind(ob))
			if not popup.popup_hide.is_connected(_on_dropdown_hidden):
				popup.popup_hide.connect(_on_dropdown_hidden)

func _on_vsync_selected(index: int) -> void:
	SettingsManager.set_setting("graphics", "vsync_mode", vsync_button.get_item_id(index))
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _on_window_mode_selected(index: int) -> void:
	var mode_id = window_mode_button.get_item_id(index)
	resolution_button.disabled = (mode_id == SettingsManager.WindowMode.BORDERLESS)
	SettingsManager.set_setting("graphics", "window_mode", mode_id)
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _on_msaa_selected(index: int) -> void:
	SettingsManager.set_setting("graphics", "msaa", msaa_button.get_item_id(index))
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _on_aa_selected(index: int) -> void:
	SettingsManager.set_setting("graphics", "aa", aa_button.get_item_id(index))
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _on_anisotropy_selected(index: int) -> void:
	SettingsManager.set_setting("graphics", "anisotropy", anisotropy_button.get_item_id(index))
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _on_res_scale_mode_selected(index: int) -> void:
	var mode_id = res_scale_mode_button.get_item_id(index)
	SettingsManager.set_setting("graphics", "resolution_scale_mode", res_scale_mode_button.get_item_id(index))
	_update_aa_availability(mode_id)
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _update_aa_availability(current_scale_mode: int) -> void:
	if current_scale_mode == Viewport.SCALING_3D_MODE_FSR2:
		aa_button.disabled = true
		for i in range(aa_button.item_count):
			if aa_button.get_item_id(i) == SettingsManager.PostProcessAA.TAA:
				aa_button.select(i)
				break
	else:
		aa_button.disabled = false
		var saved_aa = SettingsManager.get_setting("graphics", "aa")
		for i in range(aa_button.item_count):
			if aa_button.get_item_id(i) == saved_aa:
				aa_button.select(i)
				break

func _on_ssao_toggled(toggled_on: bool) -> void:
	SettingsManager.set_setting("graphics", "ssao_enabled", toggled_on)
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _on_ssil_toggled(toggled_on: bool) -> void:
	SettingsManager.set_setting("graphics", "ssil_enabled", toggled_on)
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _on_inverted_mouse_toggled(toggled_on: bool) -> void:
	SettingsManager.set_setting("controls", "inverted_mouse", toggled_on)
	SettingsManager.save_settings()

func _on_dropdown_about_to_popup(ob) -> void:
	_open_dropdown = ob
	ob.focus_neighbor_left = ^"."
	ob.focus_neighbor_right = ^"."
	ob.focus_neighbor_top = ^"."
	ob.focus_neighbor_bottom = ^"."

func _on_dropdown_hidden() -> void:
	_open_dropdown = null
	_setup_focus_nav()

func _setup_focus_nav() -> void:
	var ret = quit_button
	var def = reset_button

	for c in [resolution_button, vsync_button, window_mode_button, msaa_button, aa_button, anisotropy_button, 
		max_fps_slider, res_scale_mode_button, res_scale_slider, ui_scale_slider, ssao_button, ssil_button,
		inverted_mouse_button, pad_sensitivity_slider, volume_slider, apply_button, ret, def]:
		if c:
			c.focus_mode = Control.FOCUS_ALL

	_nb(resolution_button, apply_button, inverted_mouse_button, window_mode_button, vsync_button)
	_nb(vsync_button, def if def else apply_button, pad_sensitivity_slider, resolution_button, window_mode_button)
	_nb(window_mode_button, ret if ret else (def if def else apply_button), volume_slider, vsync_button, resolution_button)

	_nb(inverted_mouse_button, resolution_button, apply_button, volume_slider, pad_sensitivity_slider)
	_nb(pad_sensitivity_slider, vsync_button, def if def else apply_button, inverted_mouse_button, volume_slider)
	_nb(volume_slider, window_mode_button, ret if ret else (def if def else apply_button), pad_sensitivity_slider, inverted_mouse_button)

	if def and ret:
		_nb(apply_button,   inverted_mouse_button,  resolution_button,  ret,          def)
		_nb(def,            pad_sensitivity_slider, vsync_button,       apply_button, ret)
		_nb(ret,            volume_slider,          window_mode_button, def,          apply_button)
	elif def:
		_nb(apply_button,   inverted_mouse_button,  resolution_button,  def,          def)
		_nb(def,            pad_sensitivity_slider, vsync_button,       apply_button, apply_button)
	elif ret:
		_nb(apply_button,   inverted_mouse_button,  resolution_button,  ret,          ret)
		_nb(ret,            volume_slider,          window_mode_button, apply_button, apply_button)
	else:
		_nb(apply_button,   inverted_mouse_button,  resolution_button,  inverted_mouse_button, inverted_mouse_button)

func _nb(node, left, right, top, bottom) -> void:
	if not node: return
	node.focus_neighbor_left = node.get_path_to(left) if left else NodePath()
	node.focus_neighbor_right = node.get_path_to(right) if right else NodePath()
	node.focus_neighbor_top = node.get_path_to(top) if top else NodePath()
	node.focus_neighbor_bottom = node.get_path_to(bottom) if bottom else NodePath()

func _input(event) -> void:
	if not visible:
		return
	
	if confirm_dialog.visible:
		if event.is_action_pressed("ui_cancel"):
			_on_confirm_revert()
			get_viewport().set_input_as_handled()
		return
	
	if _open_dropdown:
		if event.is_action_pressed("ui_accept"):
			var popup = _open_dropdown.get_popup()
			var idx: int = popup.get_focused_item()
			if idx >= 0:
				_open_dropdown.select(idx)
				_open_dropdown.item_selected.emit(idx)
			popup.hide()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			_open_dropdown.get_popup().hide()
			get_viewport().set_input_as_handled()
			return

	if !focused and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
		or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		resolution_button.grab_focus()
		focused = true
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if focused:
			resolution_button.release_focus()
			focused = false
		_on_back_pressed()

func populate_vsync_options() -> void:
	vsync_button.clear()
	for text in SettingsManager.VSYNC_MODES:
		vsync_button.add_item(text, SettingsManager.VSYNC_MODES[text])

func populate_resolution_options() -> void:
	resolution_button.clear()
	for i in range(SettingsManager.RESOLUTIONS.size()):
		var res = SettingsManager.RESOLUTIONS[i]
		resolution_button.add_item("%d x %d" % [res.x, res.y], i)
		
func populate_window_mode_options() -> void:
	window_mode_button.clear()
	for key in SettingsManager.WindowMode.keys():
		window_mode_button.add_item(key.capitalize(), SettingsManager.WindowMode[key])
		
func populate_res_scale_mode_options() -> void:
	res_scale_mode_button.clear()
	for key in SettingsManager.SCALING_3D_MODES.keys():
		res_scale_mode_button.add_item(key, SettingsManager.SCALING_3D_MODES[key])
		
func populate_aa_options() -> void:
	msaa_button.clear()
	aa_button.clear()
	
	msaa_button.add_item("Disabled", Viewport.MSAA_DISABLED)
	msaa_button.add_item("2x", Viewport.MSAA_2X)
	msaa_button.add_item("4x", Viewport.MSAA_4X)
	msaa_button.add_item("8x", Viewport.MSAA_8X)
	
	for key in SettingsManager.PostProcessAA.keys():
		aa_button.add_item(key.capitalize(), SettingsManager.PostProcessAA[key])

func populate_anisotropy_options() -> void:
	anisotropy_button.clear()
	for key in SettingsManager.ANISOTROPY_LEVELS.keys():
		anisotropy_button.add_item(key, SettingsManager.ANISOTROPY_LEVELS[key])

func load_current_settings() -> void:
	var vsync_mode = SettingsManager.get_setting("graphics", "vsync_mode")
	var resolution = SettingsManager.get_setting("graphics", "resolution")
	var window_mode = SettingsManager.get_setting("graphics", "window_mode")
	var msaa = SettingsManager.get_setting("graphics", "msaa")
	var aa = SettingsManager.get_setting("graphics", "aa")
	var anisotropy = SettingsManager.get_setting("graphics", "anisotropy")
	var max_fps = SettingsManager.get_setting("graphics", "max_fps")
	var res_scale_mode = SettingsManager.get_setting("graphics", "resolution_scale_mode")
	var res_scale = SettingsManager.get_setting("graphics", "resolution_scale")
	var ui_scale = SettingsManager.get_setting("graphics", "ui_scale")
	var ssao = SettingsManager.get_setting("graphics", "ssao_enabled")
	var ssil = SettingsManager.get_setting("graphics", "ssil_enabled")
	
	var inverted_mouse = SettingsManager.get_setting("controls", "inverted_mouse")
	var pad_sensitivity = SettingsManager.get_setting("controls", "pad_sensitivity")

	for i in range(vsync_button.item_count):
		if vsync_button.get_item_id(i) == vsync_mode:
			vsync_button.select(i)
			break

	var res_index = -1
	for i in range(SettingsManager.RESOLUTIONS.size()):
		if SettingsManager.RESOLUTIONS[i] == resolution:
			res_index = i
			break
	
	if res_index != -1:
		resolution_button.select(res_index)
	else:
		resolution_button.add_item("%d x %d (Custom)" % [resolution.x, resolution.y])
		resolution_button.select(resolution_button.item_count - 1)

	for i in range(window_mode_button.item_count):
		if window_mode_button.get_item_id(i) == window_mode:
			window_mode_button.select(i)
			break
		
	for i in range(msaa_button.item_count):
		if msaa_button.get_item_id(i) == msaa:
			msaa_button.select(i)
			break
			
	for i in range(aa_button.item_count):
		if aa_button.get_item_id(i) == aa:
			aa_button.select(i)
			break

	for i in range(anisotropy_button.item_count):
		if anisotropy_button.get_item_id(i) == anisotropy:
			anisotropy_button.select(i)
			break

	for i in range(res_scale_mode_button.item_count):
		if res_scale_mode_button.get_item_id(i) == res_scale_mode:
			res_scale_mode_button.select(i)
			break
			
	_update_aa_availability(res_scale_mode)
			
	if res_scale != null:
		res_scale_slider.set_value_no_signal(res_scale * 100.0)
		res_scale_value_label.text = "%d%%" % int(res_scale_slider.value)
		
	if ui_scale != null:
		ui_scale_slider.set_value_no_signal(ui_scale * 100.0)
		ui_scale_value.text = "%d%%" % int(ui_scale_slider.value)

	if max_fps != null:
		max_fps_slider.set_value_no_signal(max_fps)
		if max_fps == 0:
			max_fps_value_label.text = "Uncapped"
		else:
			max_fps_value_label.text = "%d FPS" % int(max_fps)
		
	ssao_button.set_pressed_no_signal(ssao)
	ssil_button.set_pressed_no_signal(ssil)
			
	resolution_button.disabled = (window_mode == SettingsManager.WindowMode.BORDERLESS)

	inverted_mouse_button.set_pressed_no_signal(inverted_mouse)
	
	if pad_sensitivity != null:
		pad_sensitivity_slider.set_value_no_signal(pad_sensitivity * 100.0)
		pad_sensitivity_value_label.text = "%d%%" % int(pad_sensitivity_slider.value)

	var master_volume = SettingsManager.get_setting("audio", "master_volume")
	if master_volume != null:
		volume_slider.set_value_no_signal(master_volume * 100.0)
		volume_value_label.text = "%d%%" % int(volume_slider.value)

func _on_pad_sensitivity_slider_value_changed(value: float) -> void:
	pad_sensitivity_value_label.text = "%d%%" % int(value)
	SettingsManager.set_setting("controls", "pad_sensitivity", value / 100.0)
	SettingsManager.save_settings()

func _on_volume_slider_value_changed(value: float) -> void:
	var linear_volume = value / 100.0
	volume_value_label.text = "%d%%" % int(value)
	SettingsManager.set_setting("audio", "master_volume", linear_volume)
	SettingsManager.apply_audio_settings()
	SettingsManager.save_settings()

func _on_res_scale_slider_value_changed(value: float) -> void:
	res_scale_value_label.text = "%d%%" % int(value)
	SettingsManager.set_setting("graphics", "resolution_scale", value / 100.0)
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _on_ui_scale_slider_value_changed(value: float) -> void:
	ui_scale_value.text = "%d%%" % int(value)
	SettingsManager.set_setting("graphics", "ui_scale", value / 100.0)
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _on_max_fps_slider_value_changed(value: float) -> void:
	if value > 0 and value < 30:
		max_fps_slider.set_value_no_signal(0)
		value = 0
		
	if value == 0:
		max_fps_value_label.text = "Uncapped"
	else:
		max_fps_value_label.text = "%d FPS" % int(value)
		
	SettingsManager.set_setting("graphics", "max_fps", int(value))
	SettingsManager.apply_graphics_settings()
	SettingsManager.save_settings()

func _on_apply_pressed() -> void:
	var old_resolution = SettingsManager.get_setting("graphics", "resolution")
	
	var resolution_id: int = resolution_button.selected
	var new_resolution = SettingsManager.RESOLUTIONS[resolution_id] if resolution_id < SettingsManager.RESOLUTIONS.size() else old_resolution

	var display_changed = (old_resolution != new_resolution)
	
	if display_changed:
		_backup_graphics_settings = SettingsManager.settings_data["graphics"].duplicate(true)
		SettingsManager.set_setting("graphics", "resolution", new_resolution)
		SettingsManager.apply_graphics_settings()
		_start_confirmation_countdown()

func _on_back_pressed() -> void:
	fade_out()
	focused = false
	options_closed.emit()

func _on_reset_button_pressed() -> void:
	var def_vsync = SettingsManager.DEFAULTS["graphics"]["vsync_mode"]
	for i in range(vsync_button.item_count):
		if vsync_button.get_item_id(i) == def_vsync:
			vsync_button.select(i)
			_on_vsync_selected(i)
			break

	var def_res = SettingsManager.DEFAULTS["graphics"]["resolution"]
	for i in range(resolution_button.item_count):
		if SettingsManager.RESOLUTIONS[i] == def_res:
			resolution_button.select(i)
			break

	var def_window = SettingsManager.DEFAULTS["graphics"]["window_mode"]
	for i in range(window_mode_button.item_count):
		if window_mode_button.get_item_id(i) == def_window:
			window_mode_button.select(i)
			_on_window_mode_selected(i)
			break

	var def_msaa = SettingsManager.DEFAULTS["graphics"]["msaa"]
	for i in range(msaa_button.item_count):
		if msaa_button.get_item_id(i) == def_msaa:
			msaa_button.select(i)
			_on_msaa_selected(i)
			break

	var def_aa = SettingsManager.DEFAULTS["graphics"]["aa"]
	for i in range(aa_button.item_count):
		if aa_button.get_item_id(i) == def_aa:
			aa_button.select(i)
			_on_aa_selected(i)
			break

	var def_anisotropy = SettingsManager.DEFAULTS["graphics"]["anisotropy"]
	for i in range(anisotropy_button.item_count):
		if anisotropy_button.get_item_id(i) == def_anisotropy:
			anisotropy_button.select(i)
			_on_anisotropy_selected(i)
			break
			
	var def_res_scale_mode = SettingsManager.DEFAULTS["graphics"]["resolution_scale_mode"]
	for i in range(res_scale_mode_button.item_count):
		if res_scale_mode_button.get_item_id(i) == def_res_scale_mode:
			res_scale_mode_button.select(i)
			_on_res_scale_mode_selected(i)
			break
			
	var def_res_scale = SettingsManager.DEFAULTS["graphics"]["resolution_scale"]
	res_scale_slider.value = def_res_scale * 100.0 

	var def_ui_scale = SettingsManager.DEFAULTS["graphics"]["ui_scale"]
	ui_scale_slider.value = def_ui_scale * 100.0

	var def_max_fps = SettingsManager.DEFAULTS["graphics"]["max_fps"]
	max_fps_slider.value = def_max_fps
	
	ssao_button.button_pressed = SettingsManager.DEFAULTS["graphics"]["ssao_enabled"]
	_on_ssao_toggled(ssao_button.button_pressed)
	
	ssil_button.button_pressed = SettingsManager.DEFAULTS["graphics"]["ssil_enabled"]
	_on_ssil_toggled(ssil_button.button_pressed)
			
	inverted_mouse_button.button_pressed = SettingsManager.DEFAULTS["controls"]["inverted_mouse"]
	_on_inverted_mouse_toggled(inverted_mouse_button.button_pressed)
	
	pad_sensitivity_slider.value = SettingsManager.DEFAULTS["controls"]["pad_sensitivity"] * 100.0
	volume_slider.value = SettingsManager.DEFAULTS["audio"]["master_volume"] * 100.0
	
	print("Przywrócono domyślne. Kliknij Apply aby zapisać rozdzielczość.")

func _start_confirmation_countdown() -> void:
	_countdown_time = COUNTDOWN_LENGTH
	_update_confirm_label()
	confirm_dialog.show()
	confirm_timer.start(1.0)
	
	confirm_revert_button.focus_neighbor_left = confirm_accept_button.get_path()
	confirm_revert_button.focus_neighbor_right = confirm_accept_button.get_path()
	confirm_accept_button.focus_neighbor_left = confirm_revert_button.get_path()
	confirm_accept_button.focus_neighbor_right = confirm_revert_button.get_path()
	
	confirm_revert_button.grab_focus()
	
func _update_confirm_label() -> void:
	confirm_label.text = "Keep new display settings?\nSettings will revert in %d seconds..." % _countdown_time
	
func _on_confirm_timer_tick() -> void:
	_countdown_time -= 1
	_update_confirm_label()
	if _countdown_time <= 0:
		_on_confirm_revert()
		
func _on_confirm_accept() -> void:
	confirm_timer.stop()
	confirm_dialog.hide()
	
	SettingsManager.save_settings()
	print("Ustawienia zapisane")
	apply_button.grab_focus()
	
func _on_confirm_revert() -> void:
	confirm_timer.stop()
	confirm_dialog.hide()
	
	SettingsManager.settings_data["graphics"] = _backup_graphics_settings.duplicate(true)
	SettingsManager.apply_graphics_settings()
	
	load_current_settings()
	apply_button.grab_focus()

func fade_in() -> void:
	visible = true
	root_ui.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(root_ui, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC)

func fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(root_ui, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	visible = false

extends Control

@export var move_offset := Vector2(50.0, 0.0) # Moves right by default
@export var effect_radius: float = 200.0
@export var smooth_speed: float = 15.0

@onready var options: CanvasLayer = %OptionsMenu
@onready var options_button: Button = %OptionsButton
@onready var play_button: Button = %PlayButton
@onready var quit_button: Button = %QuitButton

# Using Control allows the array to hold both ColorRects and Buttons
var ui_elements: Array[Control] = []
var menu_buttons: Array[Button] = []
var original_positions: Dictionary = {}
var last_focused_button: Control = null
var focused_button_index: int = 0

func _ready() -> void:
	menu_buttons = [play_button, options_button, quit_button]
	for i in range(menu_buttons.size()):
		var button := menu_buttons[i]
		button.focus_mode = Control.FOCUS_ALL
		button.focus_neighbor_top = button.get_path_to(menu_buttons[(i - 1 + menu_buttons.size()) % menu_buttons.size()])
		button.focus_neighbor_bottom = button.get_path_to(menu_buttons[(i + 1) % menu_buttons.size()])
		button.focus_previous = button.focus_neighbor_top
		button.focus_next = button.focus_neighbor_bottom
		button.focus_entered.connect(_on_button_focus_entered.bind(button))

	for child in get_children():
		if child is ColorRect or child is Button:
			ui_elements.append(child)
			original_positions[child] = child.position

	_focus_button(0)

	if options.has_signal("hidden"):
		options.hidden.connect(_on_options_closed)

func _input(event: InputEvent) -> void:
	if options.visible: return

	if _is_ui_nav_pressed(event, "ui_up"):
		_focus_button(focused_button_index - 1)
		get_viewport().set_input_as_handled()
	elif _is_ui_nav_pressed(event, "ui_down"):
		_focus_button(focused_button_index + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		var focused_button := get_viewport().gui_get_focus_owner() as Button
		if focused_button and menu_buttons.has(focused_button) and not focused_button.disabled:
			focused_button.emit_signal("pressed")
			get_viewport().set_input_as_handled()
	elif _is_ui_nav_pressed(event, "ui_left") or _is_ui_nav_pressed(event, "ui_right"):
		if not (get_viewport().gui_get_focus_owner() is Button):
			_focus_button(focused_button_index)
			get_viewport().set_input_as_handled()
	elif _is_ui_nav_motion(event):
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var mouse_pos := get_local_mouse_position()

	for element in ui_elements:
		var orig_pos: Vector2 = original_positions[element]
		var target_position := orig_pos

		if element.has_focus():
			target_position = orig_pos + move_offset
		else:
			var closest_x: float = clamp(mouse_pos.x, orig_pos.x, orig_pos.x + element.size.x)
			var closest_y: float = clamp(mouse_pos.y, orig_pos.y, orig_pos.y + element.size.y)
			var closest_point := Vector2(closest_x, closest_y)

			var distance := mouse_pos.distance_to(closest_point)
			var proximity_factor: float = clamp(1.0 - (distance / effect_radius), 0.0, 1.0)

			target_position = orig_pos + (move_offset * proximity_factor)

		element.position = element.position.lerp(target_position, smooth_speed * delta)

func _on_button_focus_entered(btn: Button) -> void:
	last_focused_button = btn
	focused_button_index = menu_buttons.find(btn)

func _focus_button(index: int) -> void:
	if menu_buttons.is_empty():
		return
	focused_button_index = wrapi(index, 0, menu_buttons.size())
	var button := menu_buttons[focused_button_index]
	if is_instance_valid(button) and not button.disabled:
		button.grab_focus()

func _is_ui_nav_pressed(event: InputEvent, action: String) -> bool:
	if InputManager and InputManager.has_method("is_ui_navigation_action_pressed_once"):
		return InputManager.is_ui_navigation_action_pressed_once(event, action)
	return event.is_action_pressed(action)

func _is_ui_nav_motion(event: InputEvent) -> bool:
	return InputManager and InputManager.has_method("is_ui_navigation_motion") and InputManager.is_ui_navigation_motion(event)

func _on_options_closed() -> void:
	if last_focused_button and is_instance_valid(last_focused_button) and not last_focused_button.disabled:
		last_focused_button.call_deferred("grab_focus")
	else:
		options_button.call_deferred("grab_focus")

func _on_options_button_pressed() -> void:
	options.fade_in()

func _on_play_button_pressed() -> void:
	if play_button.disabled: return
	_lock_buttons()

	var target_width := get_viewport_rect().size.x
	var tween := create_tween().set_parallel(true)

	for element in ui_elements:
		var distance := element.position.distance_to(play_button.position)
		var delay := distance * 0.0015

		tween.tween_property(element, "size:x", target_width, 0.5) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN_OUT) \
			.set_delay(delay)

	LoadManager.load_scene(ScenePaths.LEVEL_SELECT_MAP)

func _on_quit_button_pressed() -> void:
	_lock_buttons()

	var target_width := get_viewport_rect().size.x
	var tween := create_tween().set_parallel(true)

	for element in ui_elements:
		var distance := element.position.distance_to(quit_button.position)
		var delay := distance * 0.0015

		tween.tween_property(element, "size:x", target_width, 0.5) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN_OUT) \
			.set_delay(delay)

	await tween.finished

	get_tree().quit()

func _lock_buttons() -> void:
	if play_button: play_button.disabled = true
	if options_button: options_button.disabled = true
	if quit_button: quit_button.disabled = true

extends PanelContainer

@onready var play_button: TextureButton = %PlayButtonTextured
@onready var options_button: TextureButton = %OptionsButtonTextured
@onready var quit_button: TextureButton = %QuitButtonTextured
@onready var options: CanvasLayer = %OptionsMenu

var focused = false
var menu_buttons: Array[TextureButton] = []
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
		button.focus_entered.connect(_on_button_focus_entered.bind(i))

	_focus_button(0)
	focused = true

func _input(input) -> void:
	if options.visible:
		return

	if _is_ui_nav_pressed(input, "ui_up"):
		_focus_button(focused_button_index - 1)
		focused = true
		get_viewport().set_input_as_handled()
	elif _is_ui_nav_pressed(input, "ui_down"):
		_focus_button(focused_button_index + 1)
		focused = true
		get_viewport().set_input_as_handled()
	elif input.is_action_pressed("ui_accept"):
		if !focused:
			_focus_button(focused_button_index)
			focused = true
		else:
			var button := menu_buttons[focused_button_index]
			if is_instance_valid(button) and not button.disabled:
				button.emit_signal("pressed")
		get_viewport().set_input_as_handled()
	elif !focused and \
		(_is_ui_nav_pressed(input, "ui_left") or _is_ui_nav_pressed(input, "ui_right") or \
		input.is_action_pressed("ui_cancel") or input.is_action_pressed("pause")):
		_focus_button(focused_button_index)
		focused = true
	elif _is_ui_nav_motion(input):
		get_viewport().set_input_as_handled()
	elif input.is_action_pressed("ui_cancel"):
		Utils.drop_focus()
		focused = false

func _on_play_button_pressed() -> void:
	if play_button.disabled: return
	await get_tree().create_timer(0.15).timeout
	_lock_buttons()
	play_button.set_pressed_no_signal(true)
	LoadManager.load_scene(ScenePaths.LEVEL_SELECT_MAP)


func _on_options_button_pressed() -> void:
	options.fade_in()

func _on_quit_button_pressed() -> void:
	_lock_buttons()
	get_tree().quit()

func _lock_buttons() -> void:
	play_button.disabled = true
	options_button.disabled = true
	quit_button.disabled = true

func _on_button_focus_entered(index: int) -> void:
	focused_button_index = index

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

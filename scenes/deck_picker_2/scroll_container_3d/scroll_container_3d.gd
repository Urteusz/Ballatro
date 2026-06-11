extends Node3D

@export var item_scene: PackedScene
@export var spacing: float = 2.0
@export var scroll_speed : float = 2.0
@export var lerp_speed: float = 10.0

@onready var camera: Camera3D = %Camera3D

var target_y: float = 0.0
var max_scroll_y: float = 0.0
var buttons: Array[Button3D] = []
var focused_button_index: int = -1

func _ready() -> void:
	var power_ups = PlayerData.PowerUp.values()
	
	for i in range(power_ups.size()):
		var power_up_enum = power_ups[i]
		_spawn_item(power_up_enum, i)
	
	max_scroll_y = max(0, (power_ups.size() - 1) * spacing)
	
	var active_index = power_ups.find(PlayerData.active_power_up)
	if active_index != -1:
		focused_button_index = active_index
		target_y = clampf(active_index * spacing, 0.0, max_scroll_y)
		position.y = target_y
	
func _spawn_item(power_up_enum: int, index: int) -> void:
	if not item_scene:
		push_error("ScrollContainer3D::_ready: Item scene not assigned in inspector")
		return
	
	var instance := item_scene.instantiate() as Button3D
	add_child(instance)
	
	instance.position = Vector3(0, -index * spacing, 0)
	
	var is_owned = PlayerData.unlocked_power_ups.has(power_up_enum)
	var is_active = PlayerData.active_power_up == power_up_enum
	var label_text = "";
	match PlayerData.PowerUp.values()[index]:
		PlayerData.PowerUp.NONE:
			label_text = "None"
		PlayerData.PowerUp.MIDAIR_DASH:
			label_text = "DASH"
		#PlayerData.PowerUp.MIDAIR_CONTROL:
			#label_text = "MIDAIR CONTROL"
		_:
			label_text = ""	
	
	if instance.has_method("setup"):
		instance.setup(label_text, index, not is_owned, is_active)
		
	instance.button_selected.connect(_on_button_selected)
	buttons.append(instance)
		
func _on_button_selected(selected_button: Button3D) -> void:
	_activate_button(selected_button)

func _activate_button(selected_button: Button3D) -> void:
	if not selected_button or selected_button.is_disabled:
		return

	for button in buttons:
		if button != selected_button and button.is_latched:
			button.set_latched(false)
			
	selected_button.set_latched(true)
	focused_button_index = selected_button.button_index
	
	var selected_enum = (PlayerData.PowerUp as Dictionary).values()[selected_button.button_index]
	PlayerData.active_power_up = selected_enum
	PlayerData.save_progress()
	
	target_y = selected_button.button_index * spacing
	target_y = clampf(target_y, 0.0, max_scroll_y)

func _unhandled_input(event: InputEvent) -> void:
	if camera and camera.looking_at_deck:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_focus(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move_focus(1)
	
	elif _is_ui_nav_pressed(event, "ui_up"):
		move_focus(-1)
		get_viewport().set_input_as_handled()
	elif _is_ui_nav_pressed(event, "ui_down"):
		move_focus(1)
		get_viewport().set_input_as_handled()
	elif _is_ui_nav_motion(event):
		get_viewport().set_input_as_handled()
		
func move_focus(step: int) -> bool:
	if buttons.is_empty():
		return false

	var start_index := focused_button_index
	if start_index < 0 or start_index >= buttons.size():
		start_index = 0

	var new_index := clampi(start_index + step, 0, buttons.size() - 1)
	while new_index >= 0 and new_index < buttons.size() and buttons[new_index].is_disabled:
		new_index += step

	if new_index < 0 or new_index >= buttons.size():
		return false

	_activate_button(buttons[new_index])
	return new_index != start_index
	
func _process(delta: float) -> void:
	position.y = lerp(position.y, target_y, delta * lerp_speed)

func _is_ui_nav_pressed(event: InputEvent, action: String) -> bool:
	if InputManager and InputManager.has_method("is_ui_navigation_action_pressed_once"):
		return InputManager.is_ui_navigation_action_pressed_once(event, action)
	return event.is_action_pressed(action)

func _is_ui_nav_motion(event: InputEvent) -> bool:
	return InputManager and InputManager.has_method("is_ui_navigation_motion") and InputManager.is_ui_navigation_motion(event)

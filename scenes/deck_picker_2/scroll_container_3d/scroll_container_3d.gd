extends Node3D

@export var item_scene: PackedScene
@export var spacing: float = 2.0
@export var scroll_speed : float = 2.0
@export var lerp_speed: float = 10.0

var target_y: float = 0.0
var max_scroll_y: float = 0.0
var buttons: Array[Button3D] = []

func _ready() -> void:
	var power_ups = PlayerData.PowerUp.values()
	
	for i in range(power_ups.size()):
		var power_up_enum = power_ups[i]
		_spawn_item(power_up_enum, i)
	
	max_scroll_y = max(0, (power_ups.size() - 1) * spacing)
	
	var active_index = power_ups.find(PlayerData.active_power_up)
	if active_index != -1:
		target_y = clamp(active_index * spacing, 0.0, max_scroll_y)
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
	for button in buttons:
		if button != selected_button and button.is_latched:
			button.set_latched(false)
			
	selected_button.set_latched(true)
	
	var selected_enum = (PlayerData.PowerUp as Dictionary).values()[selected_button.button_index]
	PlayerData.active_power_up = selected_enum
	PlayerData.save_progress()
	
	target_y = selected_button.button_index * spacing
	target_y = clamp(target_y, 0.0, max_scroll_y)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll(-scroll_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll(scroll_speed)
	
	elif event.is_action_pressed("ui_up"):
		_scroll(-scroll_speed)
	elif event.is_action_pressed("ui_down"):
		_scroll(scroll_speed)
		
func _scroll(amount: float) -> void:
	target_y += amount
	target_y = clamp(target_y, 0.0, max_scroll_y)
	
func _process(delta: float) -> void:
	position.y = lerp(position.y, target_y, delta * lerp_speed)

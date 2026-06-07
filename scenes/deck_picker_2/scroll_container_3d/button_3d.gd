extends Area3D
class_name Button3D

signal button_selected(button: Button3D)

@export var press_depth: float = -0.15
@export var animation_speed: float = 0.1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $MeshInstance3D/Label3D

var material: ShaderMaterial
var is_pressed: bool = false
var is_latched: bool = false
var is_disabled: bool = false
var button_index: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	
	var original_material = mesh_instance.material_override
	if original_material:
		mesh_instance.material_override = original_material.duplicate()
		material = mesh_instance.material_override as ShaderMaterial
	else:
		push_error("Button3D::Ready: Failed to retrieve the original material!")

func setup(label_text: String, index: int, disabled: bool, latched: bool) -> void:
	label.text = label_text
	button_index = index
	is_disabled = disabled
	is_latched = latched
	
	_update_visuals()
	var start_depth = press_depth if is_latched else 0.0
	mesh_instance.position.z = start_depth
	if material:
		material.set_shader_parameter("z_offset", start_depth)

func set_latched(state: bool) -> void:
	is_latched = state
	_update_visuals()
	_release()
	
func _update_visuals() -> void:
	if not material: return
	
	if is_disabled:
		material.set_shader_parameter("albedo_color", Color(0.3, 0.3, 0.3))
	elif is_latched:
		material.set_shader_parameter("albedo_color", Color(0.2, 0.8, 0.2))
	else:
		material.set_shader_parameter("albedo_color", Color(0.2, 0.6, 1.0))

func _input_event(_camera: Camera3D, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if is_disabled or is_latched:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not is_pressed:
			_press_down(event_position)
		elif not event.pressed and is_pressed:
			button_selected.emit(self)
			_release()

func _on_mouse_exited() -> void:
	if is_pressed:
		_release()

func _press_down(click_world_position: Vector3) -> void:
	is_pressed = true
	
	var tween = create_tween().set_parallel(true)
	
	tween.tween_property(mesh_instance, "position:z", press_depth, animation_speed).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if material:
		tween.tween_property(material, "shader_parameter/z_offset", press_depth, animation_speed).set_trans(Tween.TRANS_SPRING)
		
func _release() -> void:
	is_pressed = false
	var target_depth = press_depth if is_latched else 0.0
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(mesh_instance, "position:z", target_depth, animation_speed * 2)
	if material:
		tween.tween_property(material, "shader_parameter/z_offset", target_depth, animation_speed * 2)

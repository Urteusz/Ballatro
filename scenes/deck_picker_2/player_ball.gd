extends Node3D

@export var float_offset: float = 0.02
@export var drag_sensitivity: float = 0.005
@export var pad_sensitivity: float = 15.0
@export var damping: float = 2.0
@export var min_speed: float = 0.2
@export var inertia_transfer: float = 5.0

@export_group("Hold Settings")
@export var hold_time_required: float = 1.0
@export var hold_delay: float = 0.15

@onready var camera: Camera3D = %Camera3D
@onready var progress_quad: MeshInstance3D = $ProgressQuad

var start_position: Vector3 = Vector3.ZERO
var sin_value: float = 0.0
var is_dragging: bool = false
var current_velocity: Vector2 = Vector2.ZERO
var rotation_velocity: Vector2 = Vector2.ZERO
var hold_progress: float = 0.0

func _ready() -> void:
	start_position = global_position
	rotation_velocity = Vector2(min_speed, 0.0)
	if progress_quad:
		progress_quad.visible = false

func _input(event: InputEvent) -> void:
	if camera.looking_at_deck:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			if _is_hovering(event.position):
				is_dragging = true
		else:
			is_dragging = false
			
	if event is InputEventMouseMotion and is_dragging:
		current_velocity += event.relative

func _process(delta: float) -> void:
	if camera.looking_at_deck:
		return
	
	sin_value += delta
	global_position.y = start_position.y + sin(sin_value) * float_offset

	var pad_vector = Input.get_vector("ui_look_left", "ui_look_right", "ui_look_up", "ui_look_down")
	
	if pad_vector.length() > 0.1:
		is_dragging = false
		var pad_vel = pad_vector * pad_sensitivity
		rotation_velocity = pad_vel
	elif is_dragging:
		if delta > 0.0:
			var drag_vel = (current_velocity * drag_sensitivity) / delta
			if current_velocity != Vector2.ZERO:
				rotation_velocity = rotation_velocity.lerp(drag_vel, inertia_transfer * delta)
		current_velocity = Vector2.ZERO
	else:
		rotation_velocity = rotation_velocity.move_toward(Vector2.ZERO, damping * delta)
		
	if is_dragging:
		hold_progress += delta
		if hold_progress > hold_delay:
			var active_hold = hold_progress - hold_delay
			var ratio = clamp(active_hold / hold_time_required, 0.0, 1.0)

			if progress_quad:
				progress_quad.visible = true
				progress_quad.global_position = global_position
				var mat = progress_quad.get_active_material(0)
				if mat is ShaderMaterial:
					mat.set_shader_parameter("progress", ratio)

			if active_hold >= hold_time_required:
				is_dragging = false
				_reset_hold()
	else:
		_reset_hold()
		
	if rotation_velocity.length() < min_speed:
		if rotation_velocity.is_zero_approx():
			rotation_velocity = Vector2(min_speed, 0.0)
		else:
			rotation_velocity = rotation_velocity.normalized() * min_speed

	var current_camera = get_viewport().get_camera_3d()
	if current_camera:
		var cam_right = current_camera.global_transform.basis.x.normalized()
		var cam_up = current_camera.global_transform.basis.y.normalized()
		
		global_rotate(cam_up, rotation_velocity.x * delta)
		global_rotate(cam_right, rotation_velocity.y * delta)

func _reset_hold() -> void:
	hold_progress = 0.0
	if progress_quad:
		progress_quad.visible = false
		var mat = progress_quad.get_active_material(0)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("progress", 0.0)

func _is_hovering(mouse_pos: Vector2) -> bool:
	var current_camera = get_viewport().get_camera_3d()
	if not current_camera:
		return false
	
	var ray_origin = current_camera.project_ray_origin(mouse_pos)
	var ray_dir = current_camera.project_ray_normal(mouse_pos)
	
	var center = global_position
	var radius = 0.5
	var mesh_inst = get_node_or_null("MeshInstance3D")
	if mesh_inst and mesh_inst.mesh:
		radius = mesh_inst.mesh.get_aabb().size.length() * 0.5 * mesh_inst.scale.x
		
	var l = center - ray_origin
	var tca = l.dot(ray_dir)
	if tca < 0.0:
		return false
		
	var d2 = l.dot(l) - tca * tca
	return d2 <= radius * radius

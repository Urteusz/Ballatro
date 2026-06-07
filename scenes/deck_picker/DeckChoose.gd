extends Node3D

const BALL_POSITIONS: Array[Vector3] = [
	Vector3(1.147, 0.0, -2.0),
	Vector3(1.736, 0.0, -1.0),
	Vector3(0.558, 0.0, -1.0),
	Vector3(1.147, 0.0, 0.0),
	Vector3(2.265, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
]

signal ball_swapped(inventory_ball_data)

@export var ball_hover_offset: float = 0.4

@export var float_offset: float = 0.02
@export var drag_sensitivity: float = 0.005
@export var pad_sensitivity: float = 15.0
@export var damping: float = 2.0
@export var min_speed: float = 0.2
@export var inertia_transfer: float = 5.0
@export var panel_home_y: float = 750.0

@onready var camera: Camera3D = %Camera3D
@onready var balls_container: Node3D = %DeckBalls
@onready var ball_selected_marker: Marker3D = %BallSelectedPosition
@onready var arrow_button: TextureButton = %ArrowButton
@onready var ball_list_panel: Panel = %Panel
var base_y: float = 0.0

var selected_ball: Node3D = null
var is_animating: bool = false

var arrow_home_y: float = 0.0
var arrow_hidden_y: float = 0.0
var panel_hidden_y: float = 0.0

var sin_value: float = 0.0
var is_dragging: bool = false
var current_velocity: Vector2 = Vector2.ZERO
var rotation_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_spawn_deck()
	
	arrow_home_y = arrow_button.position.y
	arrow_hidden_y = arrow_home_y + 150.0
	arrow_button.position.y = arrow_hidden_y
	
	panel_hidden_y = panel_home_y + ball_list_panel.size.y
	ball_list_panel.position.y = panel_hidden_y
	
func _unhandled_input(event: InputEvent) -> void:
	if selected_ball == null or is_animating:
		return
		
	if event.is_action_pressed("ui_cancel"):
		_deselect_ball()
		return
		
	if event.is_action_pressed("ui_accept"):
		_start_level_with_ball()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			if _is_hovering(event.position, selected_ball):
				is_dragging = true
			else:
				_deselect_ball()
		else:
			is_dragging = false
			
	if event is InputEventMouseMotion and is_dragging:
		current_velocity += event.relative

func _process(delta: float) -> void:
	if selected_ball == null or is_animating:
		return
		
	sin_value += delta
	selected_ball.global_position.y = ball_selected_marker.global_position.y + sin(sin_value) * float_offset

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
		
	if rotation_velocity.length() < min_speed:
		if rotation_velocity.is_zero_approx():
			rotation_velocity = Vector2(min_speed, 0.0)
		else:
			rotation_velocity = rotation_velocity.normalized() * min_speed

	if camera:
		var cam_right = camera.global_transform.basis.x.normalized()
		var cam_up = camera.global_transform.basis.y.normalized()
		
		selected_ball.global_rotate(cam_up, rotation_velocity.x * delta)
		selected_ball.global_rotate(cam_right, rotation_velocity.y * delta)

func _spawn_deck() -> void:
	var owned_ids = PlayerData.owned_balls
	var balls_to_spawn = min(owned_ids.size(), BALL_POSITIONS.size())
	
	for i in range(balls_to_spawn):
		var ball_id = owned_ids[i]
		var ball_data = PlayerData.ball_data_map.get(ball_id)
		
		if not ball_data or not ball_data.scene:
			continue
			
		var ball_instance = ball_data.scene.instantiate()
		
		if ball_data.texture:
			var mesh = ball_instance.get_node_or_null("MeshInstance3D")
			if mesh:
				var original_mat = mesh.get_active_material(0)
				if original_mat:
					var new_mat = original_mat.duplicate()
					new_mat.albedo_texture = ball_data.texture
					mesh.material_override = new_mat
				else:
					var new_mat = StandardMaterial3D.new()
					new_mat.albedo_texture = ball_data.texture
					mesh.material_override = new_mat
				
		balls_container.add_child(ball_instance)
		
		ball_instance.position = BALL_POSITIONS[i]
		ball_instance.rotate_x(deg_to_rad(-87.0))
		ball_instance.rotate_y(deg_to_rad(180.0))
		
		ball_instance.set_meta("home_transform", ball_instance.global_transform)
		
		base_y = BALL_POSITIONS[i].y
		
		if ball_instance is CollisionObject3D:
			ball_instance.input_ray_pickable = true
			ball_instance.mouse_entered.connect(_animate_lift.bind(ball_instance, base_y + ball_hover_offset))
			ball_instance.mouse_exited.connect(_animate_lift.bind(ball_instance, base_y))
			ball_instance.input_event.connect(_on_ball_input_event.bind(ball_instance))
		
		if ball_instance is RigidBody3D:
			ball_instance.freeze = true

func _animate_lift(ball: Node3D, target_y: float) -> void:
	if selected_ball != null:
		return
	if camera and not camera.looking_at_deck:
		return
		
	if target_y < base_y + ball_hover_offset:
		if ball.has_meta("active_tween"):
			var current_tween = ball.get_meta("active_tween") as Tween
			if current_tween and current_tween.is_valid() and current_tween.is_running():
				await current_tween.finished
				
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ball.set_meta("active_tween", tween)
	tween.tween_property(ball, "position:y", target_y, 0.15)

func _on_ball_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, ball: Node3D) -> void:
	if not camera.looking_at_deck: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_move_ball_to_camera_center(ball)

func _move_ball_to_camera_center(ball: Node3D) -> void:
	if selected_ball != null or is_animating:
		return
	
	selected_ball = ball
	is_animating = true
	rotation_velocity = Vector2(min_speed, 0.0)
	sin_value = 0.0
	
	if camera:
		camera.is_locked = true
		
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ball.set_meta("active_tween", tween)
	tween.tween_property(ball, "global_transform", ball_selected_marker.global_transform, 0.2)

	# arrow button stuff
	var arrow_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	arrow_tween.tween_property(arrow_button, "position:y", arrow_home_y, 0.4)

	await tween.finished
	is_animating = false
	
	# panel
	var panel_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	panel_tween.set_parallel(true)
	panel_tween.tween_property(ball_list_panel, "position:y", panel_home_y, 0.1)
	

func _deselect_ball() -> void:
	if selected_ball == null:
		return

	is_animating = true
	is_dragging = false
	
	var home_transform = selected_ball.get_meta("home_transform")

	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	selected_ball.set_meta("active_tween", tween)
	tween.tween_property(selected_ball, "global_transform", home_transform, 0.2)

	var arrow_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	arrow_tween.tween_property(arrow_button, "position:y", arrow_hidden_y, 0.3)

	await tween.finished

	camera.is_locked = false
	selected_ball = null
	is_animating = false
	
	# panel
	var panel_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	panel_tween.set_parallel(true)
	panel_tween.tween_property(ball_list_panel, "position:y", panel_hidden_y, 0.1)

func _is_hovering(mouse_pos: Vector2, ball: Node3D) -> bool:
	if not camera:
		return false
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	var mesh_instance = ball.get_node_or_null("MeshInstance3D")
	
	var center = ball.global_position
	var radius = 0.5
	const radius_scale = 0.6
	var mesh_inst = ball.get_node_or_null("MeshInstance3D")
	if mesh_inst and mesh_inst.mesh:
		radius = mesh_inst.mesh.get_aabb().size.length() * 0.5 * mesh_inst.scale.x * radius_scale
		
	var l = center - ray_origin
	var tca = l.dot(ray_dir)
	if tca < 0.0:
		return false
		
	var d2 = l.dot(l) - tca * tca
	return d2 <= radius * radius

func _on_inventory_ball_pressed(_camera, event, _pos, _normal, _shape, ball_instance: Node3D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ball_data = ball_instance.get_meta("ball_data")
		emit_signal("ball_swapped", ball_data)

func _start_level_with_ball() -> void:
	if selected_ball

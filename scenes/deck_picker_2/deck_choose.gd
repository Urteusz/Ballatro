extends Node3D

const BALL_POSITIONS: Array[Vector3] = [
	Vector3(1.147, 0.0, -2.0),
	Vector3(1.736, 0.0, -1.0),
	Vector3(0.558, 0.0, -1.0),
	Vector3(1.147, 0.0, 0.0),
	Vector3(2.265, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
]

@export var ball_hover_offset: float = 0.4
@export var inventory_hide_offset: float = -3.0
var inventory_home_y: float = 0.0
@onready var inventory: Node3D = $%InventoryBalls

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
	
	inventory_home_y = inventory.position.z
	inventory.position.z = inventory_home_y + inventory_hide_offset
	inventory.visible = false
	
	inventory.ball_swapped.connect(_handle_swap)
	
func _unhandled_input(event: InputEvent) -> void:
	if selected_ball == null or is_animating:
		return
		
	if event.is_action_pressed("ui_cancel"):
		_deselect_ball()
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
	var deck = PlayerData.current_deck
	var balls_to_spawn = min(deck.size(), BALL_POSITIONS.size())
	
	for i in range(balls_to_spawn):
		var ball_data = deck[i]
		
		if not ball_data or not ball_data.scene:
			continue
			
		var ball_instance = ball_data.scene.instantiate()
		ball_instance.set_meta("ball_data", ball_data)
		
		if ball_data.texture:
			var mesh = ball_instance.get_node_or_null("MeshInstance3D")
			if mesh:
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
	
	inventory.visible = true
	
	# panel
	var bottom_ui_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bottom_ui_tween.set_parallel(true)
	bottom_ui_tween.tween_property(ball_list_panel, "position:y", panel_home_y, 0.1)
	bottom_ui_tween.tween_property(inventory, "position:z", inventory_home_y, 0.1)

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
	
	var bottom_ui_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	bottom_ui_tween.set_parallel(true)
	bottom_ui_tween.tween_property(ball_list_panel, "position:y", panel_hidden_y, 0.1)
	bottom_ui_tween.tween_property(inventory, "position:z", inventory_home_y + inventory_hide_offset, 0.1)
	
	await bottom_ui_tween.finished
	
	inventory.visible = false
	
	is_animating = false
	
func _is_hovering(mouse_pos: Vector2, ball: Node3D) -> bool:
	if not camera:
		return false
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	var mesh_instance = ball.get_node_or_null("MeshInstance3D")
	
	var center = ball.global_position
	var radius = 0.5
	const radius_scale = 0.6
	var mesh_inst := ball.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst and mesh_inst.mesh:
		radius = mesh_inst.mesh.get_aabb().size.length() * 0.5 * mesh_inst.scale.x * radius_scale
		
	var l = center - ray_origin
	var tca = l.dot(ray_dir)
	if tca < 0.0:
		return false
		
	var d2 = l.dot(l) - tca * tca
	return d2 <= radius * radius
	
func _handle_swap(new_ball_data: BallData) -> void:
	if selected_ball == null:
		return
		
	var old_ball_data = selected_ball.get_meta("ball_data")
	var deck_index = PlayerData.current_deck.find(old_ball_data)
	
	if deck_index == -1:
		return
		
	PlayerData.current_deck[deck_index] = new_ball_data
	
	var old_name: String = PlayerData.get_ball_id(old_ball_data)
	var new_name: String = PlayerData.get_ball_id(new_ball_data)
	
	var old_inventory_index := PlayerData.owned_balls.find(old_name)
	var new_inventory_index := PlayerData.owned_balls.find(new_name)
	
	if old_inventory_index != -1 and new_inventory_index != -1:
		PlayerData.owned_balls[old_inventory_index] = new_name
		PlayerData.owned_balls[new_inventory_index] = old_name
	
	_update_visuals_after_swap(deck_index, new_ball_data)
	inventory.refresh_inventory()
	
	_deselect_ball()

func _update_visuals_after_swap(index: int, new_ball_data: BallData) -> void:
	selected_ball.queue_free()
	
	var new_ball = new_ball_data.scene.instantiate()
	new_ball.set_meta("ball_data", new_ball_data)
	
	inventory.configure_ball_light(new_ball)
	
	if new_ball_data.texture:
		var mesh = new_ball.get_node_or_null("MeshInstance3D")
		if mesh:
			var new_mat = StandardMaterial3D.new()
			new_mat.albedo_texture = new_ball_data.texture
			mesh.material_override = new_mat

	balls_container.add_child(new_ball)
	
	new_ball.position = BALL_POSITIONS[index]
	new_ball.rotate_x(deg_to_rad(-87.0))
	new_ball.rotate_y(deg_to_rad(180.0))
	new_ball.set_meta("home_transform", new_ball.global_transform)
	
	if new_ball is CollisionObject3D:
		new_ball.input_ray_pickable = true
		new_ball.mouse_entered.connect(_animate_lift.bind(new_ball, BALL_POSITIONS[index].y + ball_hover_offset))
		new_ball.mouse_exited.connect(_animate_lift.bind(new_ball, BALL_POSITIONS[index].y))
		new_ball.input_event.connect(_on_ball_input_event.bind(new_ball))
		
	if new_ball is RigidBody3D:
		new_ball.freeze = true
		
func _start_selected_level() -> void:
	if selected_ball != null or is_animating:
		return
	var level_path = PlayerData.get_level_path()
	
	if LoadManager:
		LoadManager.load_scene(level_path)

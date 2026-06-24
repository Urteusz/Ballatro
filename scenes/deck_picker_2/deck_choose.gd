extends Node3D

const BALL_POSITIONS: Array[Vector3] = [
	Vector3(1.147, 0.0, -2.0),
	Vector3(1.736, 0.0, -1.0),
	Vector3(0.558, 0.0, -1.0),
	Vector3(1.147, 0.0, 0.0),
	Vector3(2.265, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
]

@onready var move_to_power_up_button: TextureButton = %MoveToPowerUpButton

@export var ball_hover_offset: float = 0.4
@export var inventory_hide_offset: float = -3.0
var inventory_home_pos: Vector3
var inventory_hidden_pos: Vector3
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
var base_y: float = 0.0

var selected_ball: Node3D = null
var is_animating: bool = false
var deck_balls: Array[Node3D] = []
var focused_deck_ball_index: int = -1

var deck_rows: Array = []
var ball_grid_pos: Dictionary = {}

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

	inventory_home_pos = inventory.global_position
	var up_axis = Vector3.UP
	if camera:
		up_axis = camera.global_transform.basis.y.normalized()
	inventory_hidden_pos = inventory_home_pos + (up_axis * inventory_hide_offset)

	inventory.set("initial_global_pos", inventory_hidden_pos)
	inventory.global_position = inventory_hidden_pos
	inventory.visible = false

	inventory.ball_swapped.connect(_handle_swap)
	call_deferred("_set_focused_deck_ball", 0)

func _unhandled_input(event: InputEvent) -> void:
	if selected_ball == null:
		if is_animating:
			return
		if camera and camera.looking_at_deck:
			if _is_ui_nav_pressed(event, "ui_left"):
				_move_deck_focus_horizontal(-1)
				get_viewport().set_input_as_handled()
				return
			if _is_ui_nav_pressed(event, "ui_right"):
				_move_deck_focus_horizontal(1)
				get_viewport().set_input_as_handled()
				return
			if _is_ui_nav_pressed(event, "ui_up"):
				_move_deck_focus_vertical(-1)
				get_viewport().set_input_as_handled()
				return
			if _is_ui_nav_pressed(event, "ui_down"):
				_move_deck_focus_vertical(1)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("ui_accept"):
				_move_focused_deck_ball_to_center()
				get_viewport().set_input_as_handled()
				return
			if _is_ui_nav_motion(event):
				get_viewport().set_input_as_handled()
				return
		return

	if selected_ball == null or is_animating:
		return

	if event.is_action_pressed("ui_cancel"):
		_deselect_ball()
		get_viewport().set_input_as_handled()
		return

	if _is_ui_nav_pressed(event, "ui_left"):
		inventory.move_focus(-1)
		get_viewport().set_input_as_handled()
		return

	if _is_ui_nav_pressed(event, "ui_right"):
		inventory.move_focus(1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		inventory.select_focused()
		get_viewport().set_input_as_handled()
		return

	if _is_ui_nav_motion(event):
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			if _is_hovering(event.position, selected_ball):
				is_dragging = true
			elif inventory.visible and event.position.y > get_viewport().get_visible_rect().size.y * 0.6:
				pass
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
		ball_instance.set_meta("deck_base_y", BALL_POSITIONS[i].y)
		ball_instance.set_meta("deck_slot_index", i)
		deck_balls.append(ball_instance)

		base_y = BALL_POSITIONS[i].y

		if ball_instance is CollisionObject3D:
			ball_instance.input_ray_pickable = true
			ball_instance.mouse_entered.connect(_on_deck_ball_mouse_entered.bind(ball_instance))
			ball_instance.mouse_exited.connect(_on_deck_ball_mouse_exited.bind(ball_instance))
			ball_instance.input_event.connect(_on_ball_input_event.bind(ball_instance))

		if ball_instance is RigidBody3D:
			ball_instance.freeze = true

	_sort_deck_balls_for_navigation.call_deferred()

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

func _set_focused_deck_ball(index: int) -> void:
	if deck_balls.is_empty() or selected_ball != null:
		return

	var wrapped_index := wrapi(index, 0, deck_balls.size())
	if wrapped_index == focused_deck_ball_index:
		return

	if focused_deck_ball_index >= 0 and focused_deck_ball_index < deck_balls.size():
		var old_ball := deck_balls[focused_deck_ball_index]
		if is_instance_valid(old_ball):
			_animate_lift(old_ball, _get_deck_base_y(old_ball))

	focused_deck_ball_index = wrapped_index
	var new_ball := deck_balls[focused_deck_ball_index]
	if is_instance_valid(new_ball):
		_animate_lift(new_ball, _get_deck_base_y(new_ball) + ball_hover_offset)

func _clear_focused_deck_ball() -> void:
	if focused_deck_ball_index >= 0 and focused_deck_ball_index < deck_balls.size():
		var ball := deck_balls[focused_deck_ball_index]
		if is_instance_valid(ball):
			_animate_lift(ball, _get_deck_base_y(ball))
	focused_deck_ball_index = -1

func _move_focused_deck_ball_to_center() -> void:
	if deck_balls.is_empty():
		return
	if focused_deck_ball_index < 0:
		_set_focused_deck_ball(0)
	var ball := deck_balls[focused_deck_ball_index]
	if is_instance_valid(ball):
		_move_ball_to_camera_center(ball)

func _move_deck_focus_horizontal(step: int) -> void:
	if deck_balls.is_empty() or selected_ball != null:
		return

	if focused_deck_ball_index < 0 or focused_deck_ball_index >= deck_balls.size():
		_set_focused_deck_ball(0)
		return

	if not ball_grid_pos.has(focused_deck_ball_index):
		_set_focused_deck_ball(focused_deck_ball_index + step)
		return

	var grid: Vector2i = ball_grid_pos[focused_deck_ball_index]
	var row_arr: Array = deck_rows[grid.x]
	var new_col := clampi(grid.y + step, 0, row_arr.size() - 1)
	
	if new_col == grid.y:
		if step == 1 and camera and camera.has_method("_show_power_up_view"):
			camera._show_power_up_view()
		return
		
	_set_focused_deck_ball(row_arr[new_col])

func _move_deck_focus_vertical(step: int) -> void:
	if deck_balls.is_empty() or selected_ball != null:
		return

	if focused_deck_ball_index < 0 or focused_deck_ball_index >= deck_balls.size():
		_set_focused_deck_ball(0)
		return

	if not ball_grid_pos.has(focused_deck_ball_index):
		return

	var grid: Vector2i = ball_grid_pos[focused_deck_ball_index]
	var new_row := grid.x + step
	if new_row < 0 or new_row >= deck_rows.size():
		return

	var cur_arr: Array = deck_rows[grid.x]
	var target_arr: Array = deck_rows[new_row]

	var frac := 0.5
	if cur_arr.size() > 1:
		frac = float(grid.y) / float(cur_arr.size() - 1)

	var target_col := 0
	if target_arr.size() > 1:
		target_col = clampi(int(round(frac * float(target_arr.size() - 1))), 0, target_arr.size() - 1)

	_set_focused_deck_ball(target_arr[target_col])

func _sort_deck_balls_for_navigation() -> void:
	if not camera:
		return
	deck_balls.sort_custom(_deck_ball_screen_order)
	_build_deck_rows()

func _build_deck_rows() -> void:
	deck_rows.clear()
	ball_grid_pos.clear()
	if deck_balls.is_empty() or not camera:
		return

	var current_row: Array = []
	var prev_y: float = camera.unproject_position(deck_balls[0].global_position).y

	for i in range(deck_balls.size()):
		var screen_y: float = camera.unproject_position(deck_balls[i].global_position).y
		if not current_row.is_empty() and absf(screen_y - prev_y) > 20.0:
			deck_rows.append(current_row)
			current_row = []
		current_row.append(i)
		prev_y = screen_y

	if not current_row.is_empty():
		deck_rows.append(current_row)

	for r in range(deck_rows.size()):
		for c in range(deck_rows[r].size()):
			ball_grid_pos[deck_rows[r][c]] = Vector2i(r, c)

func _deck_ball_screen_order(a: Node3D, b: Node3D) -> bool:
	var a_screen: Vector2 = camera.unproject_position(a.global_position)
	var b_screen: Vector2 = camera.unproject_position(b.global_position)
	if absf(a_screen.y - b_screen.y) > 20.0:
		return a_screen.y < b_screen.y
	return a_screen.x < b_screen.x

func _get_deck_base_y(ball: Node3D) -> float:
	if ball.has_meta("deck_base_y"):
		return float(ball.get_meta("deck_base_y"))
	return base_y

func _on_deck_ball_mouse_entered(ball: Node3D) -> void:
	var index := deck_balls.find(ball)
	if index != -1:
		_set_focused_deck_ball(index)

func _on_deck_ball_mouse_exited(ball: Node3D) -> void:
	if selected_ball != null:
		return
	if InputManager and InputManager.current_device == "gamepad":
		return
	if focused_deck_ball_index >= 0 and focused_deck_ball_index < deck_balls.size() and deck_balls[focused_deck_ball_index] == ball:
		_clear_focused_deck_ball()

func _on_ball_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, ball: Node3D) -> void:
	if not camera.looking_at_deck: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_move_ball_to_camera_center(ball)

func _move_ball_to_camera_center(ball: Node3D) -> void:
	if selected_ball != null or is_animating:
		return

	focused_deck_ball_index = deck_balls.find(ball)
	selected_ball = ball

	is_animating = true
	rotation_velocity = Vector2(min_speed, 0.0)
	sin_value = 0.0

	if camera:
		camera.is_locked = true
	if move_to_power_up_button:
		move_to_power_up_button.visible = false

	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ball.set_meta("active_tween", tween)
	tween.tween_property(ball, "global_transform", ball_selected_marker.global_transform, 0.2)

	var arrow_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	arrow_tween.tween_property(arrow_button, "position:y", arrow_home_y, 0.4)

	await tween.finished
	is_animating = false

	inventory.visible = true
	inventory.focus_first()

	var bottom_ui_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bottom_ui_tween.set_parallel(true)
	bottom_ui_tween.tween_property(inventory, "initial_global_pos", inventory_home_pos, 0.1)

func _deselect_ball() -> void:
	if selected_ball == null:
		return

	is_animating = true
	is_dragging = false
	inventory.clear_focus()
	var returning_index := focused_deck_ball_index

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
	bottom_ui_tween.tween_property(inventory, "initial_global_pos", inventory_hidden_pos, 0.1)

	await bottom_ui_tween.finished

	inventory.visible = false
	if move_to_power_up_button:
		move_to_power_up_button.visible = true

	if not deck_balls.is_empty():
		focused_deck_ball_index = -1
		_set_focused_deck_ball(clampi(returning_index, 0, deck_balls.size() - 1))
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
	var nav_index := deck_balls.find(selected_ball)
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
	new_ball.set_meta("deck_base_y", BALL_POSITIONS[index].y)
	new_ball.set_meta("deck_slot_index", index)
	if nav_index >= 0 and nav_index < deck_balls.size():
		deck_balls[nav_index] = new_ball
	selected_ball = new_ball

	if new_ball is CollisionObject3D:
		new_ball.input_ray_pickable = true
		new_ball.mouse_entered.connect(_on_deck_ball_mouse_entered.bind(new_ball))
		new_ball.mouse_exited.connect(_on_deck_ball_mouse_exited.bind(new_ball))
		new_ball.input_event.connect(_on_ball_input_event.bind(new_ball))

	if new_ball is RigidBody3D:
		new_ball.freeze = true

func _start_selected_level() -> void:
	if selected_ball != null or is_animating:
		return
	var level_path = PlayerData.get_level_path()

	if LoadManager:
		LoadManager.load_scene(level_path)

func _is_ui_nav_pressed(event: InputEvent, action: String) -> bool:
	if InputManager and InputManager.has_method("is_ui_navigation_action_pressed_once"):
		return InputManager.is_ui_navigation_action_pressed_once(event, action)
	return event.is_action_pressed(action)

func _is_ui_nav_motion(event: InputEvent) -> bool:
	return InputManager and InputManager.has_method("is_ui_navigation_motion") and InputManager.is_ui_navigation_motion(event)

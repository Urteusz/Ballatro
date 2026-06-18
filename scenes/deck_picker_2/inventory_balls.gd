extends Node3D

signal ball_swapped(inventory_ball_data)

@export var spread: float = 1.0
@export var ball_radius: float = 0.5

@export_group("Scroll Settings")
@export var scroll_speed: float  = 15.0
@export var edge_scroll_margin: float = 100.0
@export var scroll_smoothing: float = 10.0
@export var drag_scroll_sensitivity: float = 0.007

var initial_global_pos: Vector3
var max_scroll_distance: float = 0.0
var target_scroll_x: float = 0.0
var current_scroll_x: float = 0.0
var inventory_balls: Array[Node3D] = []
var focused_ball_index: int = -1

var pressed_ball: Node3D = null
var is_dragging_scroll: bool = false
var drag_accum: float = 0.0

func _ready() -> void:
	initial_global_pos = global_position
	spawn_unequipped_balls()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or max_scroll_distance <= 0:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_scroll = true
			drag_accum = 0.0
		else:
			is_dragging_scroll = false
			
	if event is InputEventMouseMotion and is_dragging_scroll:
		drag_accum += abs(event.relative.x) + abs(event.relative.y)
		target_scroll_x += event.relative.x * drag_scroll_sensitivity
		target_scroll_x = clamp(target_scroll_x, -max_scroll_distance, max_scroll_distance)

func _process(delta: float) -> void:
	if max_scroll_distance <= 0:
		return
	
	var scroll_dir := 0.0
	var on_gamepad := InputManager and InputManager.current_device == "gamepad"
	var on_keyboard := InputManager and InputManager.current_device == "keyboard"

	# Na padzie pasek podąża za zaznaczoną kulą (patrz _scroll_focus_into_view),
	# więc przewijanie krawędziami myszy jest wyłączone, żeby się nie biły.
	if not on_gamepad and not on_keyboard:
		var viewport = get_viewport()
		if viewport:
			var mouse_pos = viewport.get_mouse_position()
			var vp_size = viewport.get_visible_rect().size

			if mouse_pos.x < edge_scroll_margin:
				scroll_dir = 1.0
			elif mouse_pos.x > vp_size.x - edge_scroll_margin:
				scroll_dir = -1.0
	
	target_scroll_x += scroll_dir * scroll_speed * delta
	target_scroll_x = clamp(target_scroll_x, -max_scroll_distance, max_scroll_distance)
	
	current_scroll_x = lerp(current_scroll_x, target_scroll_x, scroll_smoothing * delta)
	
	var right_vector = global_transform.basis.x.normalized()
	global_position = initial_global_pos + (right_vector * current_scroll_x)
	
func spawn_unequipped_balls() -> void:	
	var unequipped_balls: Array[BallData] = []
	
	for ball_name in PlayerData.owned_balls:
		if PlayerData.ball_data_map.has(ball_name):
			var ball_data = PlayerData.ball_data_map[ball_name]
			if not PlayerData.current_deck.has(ball_data):
				unequipped_balls.append(ball_data)
		
	var num_balls = unequipped_balls.size()
	if num_balls == 0:
		max_scroll_distance = 0.0
		return
		
	max_scroll_distance = max(0.0, (float(num_balls - 1) / 2.0) * spread)
		
	var base_transform := global_transform
	var base_position := initial_global_pos
	
	var right_vector := base_transform.basis.x.normalized()
	var up_vector := base_transform.basis.y.normalized()
	
	var y_offset := up_vector * ball_radius
	var start_x_scalar: float = -(float(num_balls - 1) / 2.0) * spread
	
	for i in range(num_balls):
		var ball_data = unequipped_balls[i]
		if not ball_data or not ball_data.scene:
			continue
			
		var x_offset = (start_x_scalar + (float(i) * spread)) * right_vector
		var spawn_pos = base_position + x_offset + y_offset
		
		var new_ball = ball_data.scene.instantiate()
		new_ball.set_meta("ball_data", ball_data)
		new_ball.set_meta("inventory_base_scale", new_ball.scale)
		new_ball.input_event.connect(_on_inventory_ball_pressed.bind(new_ball))
		if new_ball is RigidBody3D:
			new_ball.freeze = true
			new_ball.rotate_x(deg_to_rad(-90))

		add_child(new_ball)
		inventory_balls.append(new_ball)
		
		if new_ball is RigidBody3D:
			new_ball.input_ray_pickable = true
			new_ball.mouse_entered.connect(_on_ball_mouse_entered.bind(new_ball))
			new_ball.mouse_exited.connect(_on_ball_mouse_exited.bind(new_ball))
		
		configure_ball_light(new_ball)
		new_ball.global_position = spawn_pos
		
		if ball_data.texture:
			apply_texture_to_ball(new_ball, ball_data.texture)

func apply_texture_to_ball(ball_instance: Node3D, texture: Texture2D) -> void:
	var mesh_instance = find_mesh_instance(ball_instance)
	
	if mesh_instance:
		var new_mat = StandardMaterial3D.new()
		new_mat.albedo_texture = texture
		mesh_instance.material_override = new_mat
	else:
		push_warning("Warning: Could not find MeshInstance3D in ball instance: " + ball_instance.name)

func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var mesh_instance = find_mesh_instance(child)
		if mesh_instance:
			return mesh_instance
	return null

# epickie
func configure_ball_light(ball_instance: Node3D) -> void:
	var light = _find_light_recursive(ball_instance)
	if light:
		light.omni_range = 0.5
	_disable_all_particles(ball_instance)

func _find_light_recursive(node: Node) -> OmniLight3D:
	if node is OmniLight3D:
		return node
	for child in node.get_children():
		var found = _find_light_recursive(child)
		if found: return found
	return null

func _disable_all_particles(node: Node) -> void:
	if node is GPUParticles3D:
		node.emitting = false
		node.process_material = null
		node.visible = false
		
	for child in node.get_children():
		_disable_all_particles(child)

func _on_ball_mouse_entered(ball: Node3D) -> void:
	var index := inventory_balls.find(ball)
	if index != -1:
		_set_focused_ball(index)

func _on_ball_mouse_exited(ball: Node3D) -> void:
	if focused_ball_index >= 0 and focused_ball_index < inventory_balls.size() and inventory_balls[focused_ball_index] == ball:
		if not InputManager or InputManager.current_device != "gamepad":
			clear_focus()

func _animate_scale(ball: Node3D, target_scale: Vector3) -> void:
	if ball.has_meta("scale_tween"):
		var old_tween = ball.get_meta("scale_tween") as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
			
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ball.set_meta("scale_tween", tween)
	tween.tween_property(ball, "scale", target_scale, 0.15)

func _on_inventory_ball_pressed(_camera, event, _pos, _normal, _shape, ball_instance: Node3D) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed_ball = ball_instance
		elif not event.pressed and pressed_ball == ball_instance:
			if drag_accum <= 5.0:
				var ball_data = ball_instance.get_meta("ball_data")
				ball_swapped.emit(ball_data)
			pressed_ball = null

func focus_first() -> void:
	if inventory_balls.is_empty():
		focused_ball_index = -1
		return
	_set_focused_ball(0)
	_scroll_focus_into_view()

func move_focus(step: int) -> void:
	if inventory_balls.is_empty():
		focused_ball_index = -1
		return
	if focused_ball_index < 0:
		_set_focused_ball(0)
		_scroll_focus_into_view()
		return
	_set_focused_ball(wrapi(focused_ball_index + step, 0, inventory_balls.size()))
	_scroll_focus_into_view()

func select_focused() -> void:
	if focused_ball_index < 0 or focused_ball_index >= inventory_balls.size():
		return
	var ball := inventory_balls[focused_ball_index]
	if is_instance_valid(ball):
		ball_swapped.emit(ball.get_meta("ball_data"))

func clear_focus() -> void:
	if focused_ball_index >= 0 and focused_ball_index < inventory_balls.size():
		var ball := inventory_balls[focused_ball_index]
		if is_instance_valid(ball):
			_animate_scale(ball, _get_base_scale(ball))
	focused_ball_index = -1

func _set_focused_ball(index: int) -> void:
	if inventory_balls.is_empty():
		return

	var new_index := wrapi(index, 0, inventory_balls.size())
	if new_index == focused_ball_index:
		return

	if focused_ball_index >= 0 and focused_ball_index < inventory_balls.size():
		var old_ball := inventory_balls[focused_ball_index]
		if is_instance_valid(old_ball):
			_animate_scale(old_ball, _get_base_scale(old_ball))

	focused_ball_index = new_index
	var new_ball := inventory_balls[focused_ball_index]
	if is_instance_valid(new_ball):
		_animate_scale(new_ball, _get_base_scale(new_ball) * 1.2)

# Przesuwa pasek tak, aby zaznaczona kula znalazła się na środku (w granicach przewijania).
func _scroll_focus_into_view() -> void:
	if focused_ball_index < 0 or inventory_balls.size() <= 1 or max_scroll_distance <= 0.0:
		return
	var centered := (float(inventory_balls.size() - 1) / 2.0 - float(focused_ball_index)) * spread
	target_scroll_x = clamp(centered, -max_scroll_distance, max_scroll_distance)

func _get_base_scale(ball: Node3D) -> Vector3:
	if ball.has_meta("inventory_base_scale"):
		return ball.get_meta("inventory_base_scale") as Vector3
	return Vector3.ONE

func refresh_inventory() -> void:
	target_scroll_x = 0.0
	current_scroll_x = 0.0
	global_position = initial_global_pos
	focused_ball_index = -1
	inventory_balls.clear()
	
	for child in get_children():
		if child.has_meta("ball_data"):
			child.queue_free()
			
	spawn_unequipped_balls()

extends Node3D

signal ball_swapped(inventory_ball_data)

@export var spread: float = 1.0
@export var ball_radius: float = 0.5

func _ready() -> void:
	spawn_unequipped_balls()

func spawn_unequipped_balls() -> void:
	var unequipped_balls: Array[BallData] = []
	
	for ball_name in PlayerData.owned_balls:
		if PlayerData.ball_data_map.has(ball_name):
			var ball_data = PlayerData.ball_data_map[ball_name]
			if not PlayerData.current_deck.has(ball_data):
				unequipped_balls.append(ball_data)
		
	var num_balls = unequipped_balls.size()
	if num_balls == 0:
		return
		
	var base_transform := global_transform
	var base_position := base_transform.origin
	var right_vector := base_transform.basis.x
	var up_vector := base_transform.basis.y
	
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
		new_ball.input_event.connect(_on_inventory_ball_pressed.bind(new_ball))
		if new_ball is RigidBody3D:
			new_ball.freeze = true
			new_ball.rotate_x(deg_to_rad(-90))

		add_child(new_ball)
		
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
		#light.light_energy = 0.05
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
	_animate_scale(ball, Vector3.ONE * 1.2)

func _on_ball_mouse_exited(ball: Node3D) -> void:
	_animate_scale(ball, Vector3.ONE)

func _animate_scale(ball: Node3D, target_scale: Vector3) -> void:
	if ball.has_meta("scale_tween"):
		var old_tween = ball.get_meta("scale_tween") as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
			
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ball.set_meta("scale_tween", tween)
	tween.tween_property(ball, "scale", target_scale, 0.15)

func _on_inventory_ball_pressed(_camera, event, _pos, _normal, _shape, ball_instance: Node3D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ball_data = ball_instance.get_meta("ball_data")
		ball_swapped.emit(ball_data)

func refresh_inventory() -> void:
	for child in get_children():
		if child.has_meta("ball_data"):
			child.queue_free()
			
	spawn_unequipped_balls()

extends Node3D

@export var ray_length: float = 1000.0
@export var impulse_strength: float = 10.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_shoot_ray(event.position)

func _shoot_ray(mouse_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
		
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_normal := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_normal * ray_length
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		if collider is RigidBody3D:
			var push_direction: Vector3 = -result.normal
			
			var hit_offset: Vector3 = result.position - collider.global_position
			
			collider.apply_impulse(push_direction * impulse_strength, hit_offset)

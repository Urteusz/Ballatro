extends Node3D

@export var rotation_speed: float = 5.0

@onready var dash_effect: Node3D = $DashEffect

var camera: Camera3D

func _ready() -> void:
	camera = get_viewport().get_camera_3d()

func _process(delta: float) -> void:
	if dash_effect and !dash_effect.visible:
		return
	
	if camera:
		var target_pos = camera.global_position
		var current_pos = global_position
		var dir = target_pos - current_pos
		
		if dir.length_squared() < 0.001:
			return
			
		var up_vector = Vector3.UP
		
		if abs(dir.normalized().y) > 0.999:
			up_vector = Vector3.RIGHT
		
		var target_transform = global_transform.looking_at(camera.global_position, Vector3.UP)
		
		var clean_transform = global_transform.orthonormalized()
		
		global_transform = clean_transform.interpolate_with(target_transform, rotation_speed * delta)

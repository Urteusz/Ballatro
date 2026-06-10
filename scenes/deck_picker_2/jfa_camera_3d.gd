extends Camera3D

@onready var player_camera: Camera3D = %Camera3D

func _process(delta: float) -> void:
	fov = player_camera.fov
	global_transform = player_camera.global_transform

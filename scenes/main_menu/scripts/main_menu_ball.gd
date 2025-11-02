# skrypt dla tej jednej kuli co sie patrzy w kamere
extends RigidBody3D

@onready var camera = get_viewport().get_camera_3d()


func _process(delta: float) -> void:
	if camera:
		look_at(camera.global_position)

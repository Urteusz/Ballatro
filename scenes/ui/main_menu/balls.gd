extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for ball in get_children():
		if ball is Node3D:
			ball.rotate(Vector3(randf(), randf(), randf()).normalized(), randf() * TAU)

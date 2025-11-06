extends GPUParticles3D

func _ready() -> void:
	emitting = false

func explode_at(position: Vector3) -> void:
	# Przenieś do root sceny
	var scene_root = get_tree().root
	var current_parent = get_parent()
	
	current_parent.remove_child(self)
	scene_root.add_child(self)
	
	local_coords = false
	global_position = position
	
	emitting = true
	restart()
	
	print("SmokeBOOM at: ", global_position)

func _process(delta: float) -> void:
	pass

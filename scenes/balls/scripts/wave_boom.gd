extends GPUParticles3D

func _ready() -> void:
	emitting = false
	local_coords = false

func explode_at(position: Vector3) -> void:
	# KLUCZOWE: Najpierw przenieś do root
	var scene_root = get_tree().root
	var current_parent = get_parent()
	
	if current_parent:
		current_parent.remove_child(self)
		scene_root.add_child(self)
	
	# Teraz ustaw pozycję
	global_position = position
	local_coords = false
	
	# Poczekaj klatkę, żeby transform się zaktualizował
	await get_tree().process_frame
	
	# Dopiero teraz uruchom
	emitting = true
	restart()
	
	print("WaveBOOM moved to root at: ", global_position)
	print("Parent: ", get_parent().name)

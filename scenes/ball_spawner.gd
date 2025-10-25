extends Marker3D

@export var ball_scene: PackedScene
@export var spread: float = 1.0 
@export var depth: float = 1.0 
@export var height: float = 1.0


func _ready():
	if !ball_scene:
		print_rich("[color=red]Error:[/color] 'Object Scene' or 'Spawn Point' not set.")
		return

	var base_transform = global_transform
	var base_position = base_transform.origin
	
	var right = base_transform.basis.x
	var back = base_transform.basis.z
	
	var y_offset = Vector3(0.0, height, 0.0)
	var pos1 = base_position + y_offset
	var pos2 = base_position - (back * depth) - (right * spread) + y_offset
	var pos3 = base_position - (back * depth) + (right * spread) + y_offset
	var positions = [pos1, pos2, pos3]

	for pos in positions:
		var new_instance = ball_scene.instantiate()
		add_child(new_instance)
		new_instance.global_position = pos

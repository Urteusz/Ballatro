extends RigidBody3D

const COLLISION_SHAPE_PATH = "CollisionShape3D"

@export var impulse_strength = 30.0
@export var target_sprite: Node3D

var camera: Camera3D = null
var radius = 0.0

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	# jesli kula bedzie zmieniac swoj promien to nalezaloby przeniesc
	#	ten call do push_ball()
	radius = get_ball_radius()
	
	if not camera:
		push_error("Error: No camera found.")
		set_process(false)
		return
	
	if not target_sprite:
		push_warning("Warning: 'target_sprite' not assigned.")
	
func _process(delta: float) -> void:
	pass

func _input(event):
	# Drugi warunek zaklada ze biala bila jest dodana pierwsza
	# 	niedobrze
	if event.is_action_pressed("push_ball") && camera.current_target_index == 0:
		push_ball()
		#camera.current_target_index = camera.ball_list.size()
		#camera.target = null

func get_ball_radius() -> float:
	var collision_shape_node = get_node_or_null(COLLISION_SHAPE_PATH)
	
	if not collision_shape_node:
		push_error("Error: Could not find CollisionShape3D child node at path:", COLLISION_SHAPE_PATH)
		return 0.0
	
	var shape_resource = collision_shape_node.shape
	
	if not shape_resource:
		push_error("Error: CollisionShape3D node has no shape resource assigned.")
		return 0.0
	
	if shape_resource is SphereShape3D:
		var sphere_shape = shape_resource as SphereShape3D
		return sphere_shape.radius
	else:
		push_error("Error: The shape is not a SphereShape3D. Cannot retrieve radius.")
		return 0.0
		
func push_ball():
	if !camera:
		print("Error: No active Camera3D found.")
		return
	
	var camera_position = camera.global_position
	var ball_position = global_position
	var direction_to_camera = (camera_position - ball_position).normalized()
	
	var impulse_position = -direction_to_camera * radius
	var impulse_vector = direction_to_camera * impulse_strength
	
	apply_impulse(-impulse_vector, impulse_position)
	

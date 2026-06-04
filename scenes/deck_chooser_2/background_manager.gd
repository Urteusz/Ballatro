extends Node3D

@export_group("Spawning Parameters")
@export var floating_objects: Array[PackedScene]
@export var object_count: int = 50
@export var min_distance: float = 100.0
@export var max_distance: float = 200.0

@export_group("Movement")
@export var drift_speed: float = 1.0
@export var camera_to_follow: Camera3D 

var _spawned_instances: Array[Node3D] = []
var _drift_axes: Array[Vector3] = []

func _ready() -> void:
	if floating_objects.is_empty():
		push_warning("BackgroundSpawner: No floating objects assigned!")
		return

	for i in range(object_count):
		var scene = floating_objects.pick_random()
		var instance = scene.instantiate() as Node3D
		
		_disable_depth_draw(instance)
		add_child(instance)

		var random_dir = Vector3(
			randf_range(-1.0, 1.0), 
			randf_range(-1.0, 1.0), 
			randf_range(-1.0, 1.0)
		).normalized()
		
		var dist = randf_range(min_distance, max_distance)
		instance.position = random_dir * dist

		instance.rotation = Vector3(
			randf_range(0, TAU), 
			randf_range(0, TAU), 
			randf_range(0, TAU)
		)

		_spawned_instances.append(instance)
		_drift_axes.append(Vector3(
			randf_range(-1.0, 1.0), 
			randf_range(-1.0, 1.0), 
			randf_range(-1.0, 1.0)
		).normalized())

func _process(delta: float) -> void:
	if camera_to_follow:
		global_position = camera_to_follow.global_position

	for i in range(_spawned_instances.size()):
		var obj = _spawned_instances[i]
		var axis = _drift_axes[i]
		
		obj.position = obj.position.rotated(axis, drift_speed * delta * 0.05)
		obj.rotate(axis, drift_speed * delta * 0.1)

func _disable_depth_draw(node: Node) -> void:
	if node is MeshInstance3D:
		var mat = node.get_active_material(0)
		var new_mat: BaseMaterial3D
		
		if mat is BaseMaterial3D:
			new_mat = mat.duplicate()
		else:
			new_mat = StandardMaterial3D.new()
			
		new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		new_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		
		node.material_override = new_mat
		
	for child in node.get_children():
		_disable_depth_draw(child)

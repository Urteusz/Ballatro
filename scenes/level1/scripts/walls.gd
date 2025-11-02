extends MeshInstance3D

@export var object_node: Node3D

var _material: ShaderMaterial


func _ready():
	# Get the shader material from this MeshInstance3D
	# Assumes the material is in surface 0
	_material = self.get_active_material(0)

	# Safety checks
	if not object_node:
		print_debug("Fade shader warning: 'Object to Track' is not set.")
	if not _material:
		print_debug("Fade shader warning: No ShaderMaterial found on surface 0.")


func _process(_delta):
	if object_node and _material:
		var object_pos = object_node.global_position
		_material.set_shader_parameter("object_position", object_pos)
	else:
		print_debug("object node or material are null, not pushing object position")

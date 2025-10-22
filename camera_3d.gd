extends Camera3D

@export var target: Node3D
@export var mouse_sensitivity = 0.005
@export var radius = 5.0

const MIN_PHI = 0.25
const MAX_PHI = PI - 1.0
var theta = 0.0
var phi = 1.0

var ball_list;
var current_target_index: int = -1
var offset = Vector3(0.0, 0.0, 0.0)
var pivot = Vector3.ZERO
var animating = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	self.position = Vector3.ZERO
	ball_list = get_tree().get_nodes_in_group("balls")

func _process(delta: float) -> void:	
	var x = radius * sin(phi) * cos(theta)
	var y = radius * cos(phi)
	var z = radius * sin(phi) * sin(theta)
	offset = Vector3(x, y, z)
	
	var target_center = Vector3.ZERO
	if target:
		target_center = target.global_position
		
	if animating:
		pivot = lerp(pivot, target_center, 0.2)

		if pivot.distance_to(target_center) < 0.01:
			animating = false
			pivot = target_center
	else:
		pivot = target_center

	global_position = pivot + offset
	look_at(pivot)

func _input(event):
	if event is InputEventMouseMotion:
		phi += event.relative.y * mouse_sensitivity
		phi = clamp(phi, MIN_PHI, MAX_PHI)
		theta += event.relative.x * mouse_sensitivity
		
	if event.is_action_pressed("next_camera_target"):
		current_target_index += 1
		update_camera_target()

	if event.is_action_pressed("previous_camera_target"):
		current_target_index -= 1
		update_camera_target()
		
func update_camera_target():
		var total_targets = ball_list.size() + 1
		current_target_index = wrapi(current_target_index, 0, total_targets)
		
		if current_target_index == ball_list.size():
			target = null
		else:
			target = ball_list[current_target_index]

		animating = true

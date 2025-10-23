extends Camera3D

@export var target: Node3D
@export var mouse_sensitivity = 0.003
@export var table_camera_radius = 13.0 # dystans kamery od celu
@export var ball_camera_radius = 5.0
@export var camera_lerp_speed = 10

const MIN_PHI = 0.25
const MAX_PHI = 1.45
var theta = 0.0
var phi = 1.0

var ball_list
var camera_current_radius
var camera_target_radius
var current_target_index: int = 0 # Biala bila
var offset = Vector3(0.0, 0.0, 0.0)
var pivot = Vector3.ZERO
var animating = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	self.position = Vector3.ZERO
	ball_list = get_tree().get_nodes_in_group("balls")
	
	camera_current_radius = ball_camera_radius
	camera_target_radius = camera_current_radius

func _process(delta: float) -> void:
	camera_current_radius = lerp(camera_current_radius, camera_target_radius, camera_lerp_speed * delta)
	
	var x = camera_current_radius * sin(phi) * cos(theta)
	var y = camera_current_radius * cos(phi)
	var z = camera_current_radius * sin(phi) * sin(theta)
	offset = Vector3(x, y, z)
	
	var target_center = Vector3.ZERO
	if target:
		target_center = target.global_position
		
	if animating:
		pivot = lerp(pivot, target_center, camera_lerp_speed * delta)

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
		
# Kamera przechodzi po kulach w kolejnosci w jakiej zostaly dodane do listy
#	zamiast tego powinno dac sie zmieniac pomiedzy najblizszymi kulami
func update_camera_target():
		var total_targets = ball_list.size() + 1
		current_target_index = wrapi(current_target_index, 0, total_targets)
		
		# Scene center
		if current_target_index == ball_list.size():
			camera_target_radius = table_camera_radius
			target = null
		else:
			camera_target_radius = ball_camera_radius
			target = ball_list[current_target_index]

		animating = true

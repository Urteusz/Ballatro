extends Camera3D

# do testow
var points_popup = preload(ScenePaths.POINTS_POPUP_PATH)

@export var target: Node3D
@export var mouse_sensitivity = 0.003
@export var table_camera_radius = 13.0 # dystans kamery od celu
@export var ball_camera_radius = 5.0
@export var camera_lerp_speed: float = 10.0

const MIN_PHI = 0.25
const MAX_PHI = 1.45
const MIN_CURSOR_PHI = 0.2
const MAX_CURSOR_PHI = 1.8
var theta = PI / 2
var phi = 1.0
var cursor_phi = 1.0
var previous_theta = theta

var ball_list
var camera_current_radius
var camera_target_radius
var current_target_index: int = 0 # Biala bila
var offset = Vector3(0.0, 0.0, 0.0)
var pivot = Vector3.ZERO
var animating = false
var cursor_position := Vector3.ZERO

signal targetting_center

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	self.position = Vector3.ZERO
	ball_list = get_tree().get_nodes_in_group("balls")
	
	camera_current_radius = ball_camera_radius
	camera_target_radius = camera_current_radius

func _process(delta: float) -> void:
	camera_current_radius = lerp(camera_current_radius, camera_target_radius, camera_lerp_speed * delta)
	cursor_phi = clamp(cursor_phi, MIN_CURSOR_PHI, MAX_CURSOR_PHI)
	print_debug("Cursor phi: ", cursor_phi)
	
	# na szybko to napisalem
	var x = camera_current_radius * sin(cursor_phi) * cos(theta)
	var y = camera_current_radius * cos(cursor_phi)
	var z = camera_current_radius * sin(cursor_phi) * sin(theta)
	
	var cursor_offset = Vector3(x, y, z)
	phi = clamp(cursor_phi, MIN_PHI, MAX_PHI)
	
	x = camera_current_radius * sin(phi) * cos(theta)
	y = camera_current_radius * cos(phi)
	z = camera_current_radius * sin(phi) * sin(theta)
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

	cursor_position = pivot + cursor_offset
	global_position = pivot + offset
	look_at(pivot)

func _input(event):
	if event is InputEventMouseMotion:
		cursor_phi += event.relative.y * mouse_sensitivity
		theta += event.relative.x * mouse_sensitivity
		
	#if event.is_action_pressed("next_camera_target"):
		#current_target_index += 1
		#update_camera_target()
#
	#if event.is_action_pressed("previous_camera_target"):
		#current_target_index -= 1
		#update_camera_target()
	
	# zakomentowalem tymczasowo te wyzej, zeby nie dalo sie patrzec na zwykle bile
	if event.is_action_pressed("next_camera_target") || \
		event.is_action_pressed("previous_camera_target"):
			if current_target_index != 0:
				theta = previous_theta
				current_target_index = 0
			else:
				previous_theta = theta
				current_target_index = ball_list.size()
			update_camera_target()
	
	if event.is_action_pressed("toggle_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
	if event.is_action_pressed("reload_scene"):
		reload_current_scene()
			
# Kamera przechodzi po kulach w kolejnosci w jakiej zostaly dodane do listy
#	zamiast tego powinno dac sie zmieniac pomiedzy najblizszymi kulami
func update_camera_target():
		var total_targets = ball_list.size() + 1
		current_target_index = wrapi(current_target_index, 0, total_targets)
		
		# Scene center
		if current_target_index == ball_list.size():
			camera_target_radius = table_camera_radius
			emit_signal("targetting_center")
			target = null
		else:
			camera_target_radius = ball_camera_radius
			target = ball_list[current_target_index]

		animating = true
		
func get_camera_theta() -> float:
	return theta

func reload_current_scene() -> void:
	var error_code = get_tree().reload_current_scene()
	if error_code != OK:
		print("Error reloading scene: ", error_code)

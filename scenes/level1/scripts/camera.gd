extends Camera3D

const BALLS_GROUP = "balls"

var points_popup = preload(ScenePaths.POINTS_POPUP_PATH)

@export var target: Node3D
@export var table_camera_radius: float = 13.0 # dystans kamery od celu gdy patrzy sie na srodek
@export var ball_camera_radius: float = 5.0 #		i gdy patrzy sie na kule
@export var camera_lerp_speed: float = 10.0

@export var mouse_sensitivity: float = 0.003
@export var controller_sensitivity: float = 1.5
@export var touch_sensitivity: float = 0.2
@export var controller_deadzone: float = 0.15

@export var min_phi: float = 0.25 # max wysokosc kamery
@export var max_phi: float = 1.45 #		min wysokosc, albo na odwrot nie pamietam
@export var min_cursor_phi: float = 0.2 # min/max wysokosc 'celownika'
@export var max_cursor_phi: float = 1.8

# do obliczania pozycji kamery/celownika
var theta = PI / 2
var phi = 1.0
var cursor_phi = 1.0
# kamera patrzy sie w tym sammy kierunku po powrocie do bili, co przed przelaczeniem kamery na srodek
var previous_theta = theta

var ball_list
var camera_current_radius: float = 0.0
var camera_target_radius: float = 0.0
var current_target_index: int = 0 # Biala bila
var offset := Vector3(0.0, 0.0, 0.0) # Przesuniecie kamery od celu
var pivot := Vector3.ZERO # Punkt wokol ktorego kamera sie obraca
var animating: bool = false # czy jest w trakcie lerp
var cursor_position := Vector3.ZERO

signal targetting_center


func _ready() -> void:
	if OS.has_feature("desktop"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	self.position = Vector3.ZERO
	ball_list = get_tree().get_nodes_in_group(BALLS_GROUP)

	camera_current_radius = ball_camera_radius
	camera_target_radius = camera_current_radius


# do podzielenia na mniejsze funkcje
func _process(delta: float) -> void:
	var controller_input_horizontal: float = Input.get_axis("camera_look_left", "camera_look_right")
	var controller_input_vertical: float = Input.get_axis("camera_look_up", "camera_look_down")
	
	if abs(controller_input_horizontal) > controller_deadzone:
		theta += controller_input_horizontal * controller_sensitivity * delta
		
	if abs(controller_input_horizontal) > controller_deadzone:
		cursor_phi += controller_input_vertical * controller_sensitivity * delta
	
	camera_current_radius = lerp(camera_current_radius, camera_target_radius, camera_lerp_speed * delta)
	cursor_phi = clamp(cursor_phi, min_cursor_phi, max_cursor_phi)

	var x: float = camera_current_radius * sin(cursor_phi) * cos(theta)
	var y: float = camera_current_radius * cos(cursor_phi)
	var z: float = camera_current_radius * sin(cursor_phi) * sin(theta)

	var cursor_offset := Vector3(x, y, z)
	phi = clamp(cursor_phi, min_phi, max_phi)

	x = camera_current_radius * sin(phi) * cos(theta)
	y = camera_current_radius * cos(phi)
	z = camera_current_radius * sin(phi) * sin(theta)
	offset = Vector3(x, y, z)

	var target_center := Vector3.ZERO
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


func _input(event) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_camera_rotation_relative(event.relative, mouse_sensitivity)
	elif event is InputEventScreenDrag:
		_handle_camera_rotation_relative(event.relative, touch_sensitivity)
	
	if event.is_action_pressed("next_camera_target") || event.is_action_pressed("previous_camera_target"):
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
		_reload_current_scene()

func _handle_camera_rotation_relative(relative_motion: Vector2, sensitivity: float) -> void:
	cursor_phi += relative_motion.y * sensitivity
	theta += relative_motion.x * sensitivity

# do przepisania, nie powinno uzywac ball_list array w taki sposob
#	chyba ze chcemy wykorzystac mozliwosc patrzenia na inne bile (niz biala)
func update_camera_target() -> void:
	var total_targets: int = ball_list.size() + 1
	current_target_index = wrapi(current_target_index, 0, total_targets)

	if current_target_index == ball_list.size():
		camera_target_radius = table_camera_radius
		emit_signal("targetting_center")
		target = null
	else:
		camera_target_radius = ball_camera_radius
		target = ball_list[current_target_index]

	animating = true


func is_looking_at_player() -> bool:
	return current_target_index == 0


func is_looking_at_center() -> bool:
	if ball_list:
		return current_target_index == ball_list.size() + 1
	else:
		push_error("Error: camera.ball_list is null")
		return false


func _reload_current_scene() -> void:
	var error_code = get_tree().reload_current_scene()
	if error_code != OK:
		print("Error reloading scene: ", error_code)

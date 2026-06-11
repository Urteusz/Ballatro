extends Camera3D

@export_category("Movement")
@export var max_speed := 8.0
@export var acceleration := 2.0 # Mniejsze wartości = większy "poślizg" (gładki ruch jak po lodzie)
@export var friction := 2.0
@export var sprint_multiplier := 2.5

@export_category("Mouse Look")
@export var mouse_sensitivity := 0.002
@export var mouse_smoothness := 8.0 # Niskie wartości dają efekt "ciężkiej kamery filmowej"

@export_category("Cinematic Effects")
@export var roll_amount := 3.5 # Kąt przechyłu przy ruchu na boki (styl drona)
@export var roll_smoothness := 4.0
@export var zoom_speed := 5.0 # Zmiana kąta widzenia rolką
@export var zoom_smoothness := 5.0

# --- Zmienne "atrapy" żeby zapobiec crashom ze strony player_ball.gd ---
var current_target_index := -1
var spin_offset := 0.0
var vertical_spin_offset := 0.0
var cursor_position := Vector3.ZERO
var cursor_phi := 0.0
var phi := 0.0

func is_looking_at_player() -> bool:
	return false
# ------------------------------------------------------------------------

var _velocity := Vector3.ZERO

# Zmienne wygładzania
var _target_yaw := 0.0
var _target_pitch := 0.0
var _yaw := 0.0
var _pitch := 0.0

var _target_roll := 0.0
var _roll := 0.0

var _target_fov := 75.0

func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x
	_target_yaw = _yaw
	_target_pitch = _pitch
	_target_fov = fov
	
	current = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	# Obrót kamery myszką (zapisujemy do targetu, żeby później to wygładzić)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_target_yaw -= event.relative.x * mouse_sensitivity
		_target_pitch -= event.relative.y * mouse_sensitivity
		_target_pitch = clamp(_target_pitch, -PI/2, PI/2)

	# Zbliżenia rolką myszy
	if event is InputEventMouseButton and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_fov = clamp(_target_fov - zoom_speed, 10.0, 120.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_fov = clamp(_target_fov + zoom_speed, 10.0, 120.0)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if event.keycode == KEY_H:
			_toggle_ui(get_tree().root)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	var unscaled_delta = delta if not get_tree().paused else 1.0/Engine.get_frames_per_second()
	if unscaled_delta <= 0:
		unscaled_delta = 0.016
		
	# 1. Kinematograficzne wygładzanie obrotu (Mouse Look Lerp)
	_yaw = lerp(_yaw, _target_yaw, mouse_smoothness * unscaled_delta)
	_pitch = lerp(_pitch, _target_pitch, mouse_smoothness * unscaled_delta)
	rotation.y = _yaw
	rotation.x = _pitch
		
	# 2. Sterowanie pozycją
	var input_dir := Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W): input_dir.z -= 1
	if Input.is_key_pressed(KEY_S): input_dir.z += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	if Input.is_key_pressed(KEY_Q): input_dir.y -= 1
	if Input.is_key_pressed(KEY_E): input_dir.y += 1
	
	input_dir = input_dir.normalized()
	
	var move_dir = (transform.basis * input_dir)
	
	var speed = max_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= sprint_multiplier
		
	if move_dir.length() > 0:
		_velocity = _velocity.lerp(move_dir * speed, acceleration * unscaled_delta)
	else:
		_velocity = _velocity.lerp(Vector3.ZERO, friction * unscaled_delta)
		
	global_position += _velocity * unscaled_delta
	
	# 3. Efekt Drona (Lekkie wychylanie na boki podczas ruchu A/D)
	_target_roll = -input_dir.x * roll_amount * (PI/180.0)
	_roll = lerp(_roll, _target_roll, roll_smoothness * unscaled_delta)
	rotation.z = _roll
	
	# 4. Płynny Zoom / Zmiana FOV
	fov = lerp(fov, _target_fov, zoom_smoothness * unscaled_delta)

func _toggle_ui(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			child.visible = !child.visible
		_toggle_ui(child)

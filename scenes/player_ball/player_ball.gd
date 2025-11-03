extends RigidBody3D

enum Phase { AIMING, MOVING }

# Minimalna predkosc po ktorej uznajemy ze kula stoi w miejscu
#	nie najlepsze, bo nie zawsze faktycznie sie zatrzymuje, ale nie wiem jak to lepiej zrobic
const MOVEMENT_THRESHOLD: float = 0.1
# ile czasu program czeka aby uznac ze kula na pewno sie zatrzymala
#	bez tego 'runda' konczyla sie od razu po strzale bo kula w pierwszej klatce po ruchu
#	nadal miala bardzo niskie velocity
const STOP_DELAY: float = 0.4
const RING_ALPHA: float = 0.7
const MIN_IMPULSE: float = 0.2

# Ustawienia uderzenia
@export var max_charge_duration: float = 3.0
@export var max_impulse_strength: float = 30.0

# Kolorki pierscienia ladowania strzalu
@export var weak_charge_color := Color(0.0, 1.0, 0.0, 1.0)
@export var medium_charge_color := Color(1.0, 1.0, 0.0, 1.0)
@export var strong_charge_color := Color(1.0, 0.0, 0.0, 1.0)

@export var aim_line_ray_range: float = 20.0

# Sciezki
@onready var collision_shape := $CollisionShape3D
@onready var charge_ring: MeshInstance3D = $ChargeRing
@onready var animation_player := $AnimationPlayer
@onready var control_gameplay = $/root/Node3D/GameplayUI/ControlGameplay

@onready var ball_radius: float = get_ball_radius()
@onready var aim_line: MeshInstance3D = null

var ring_material: StandardMaterial3D = null
var hit_position: Vector3 # Pozycja kamery w momencie jak zaczelismy ladowac strzal, nie wiem jak nazwac lepiej :(
var charging: bool = false
var charge_timer: float = 0.0
var aimed_at_ball: BallParent = null
var camera: Camera3D = null
var current_phase: Phase = Phase.AIMING
var stop_timer: float = 0.0 # patrzy STOP_DELAY wyzej

signal ball_pushed(impulse_power: float)
signal round_ended


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	ball_radius = get_ball_radius()

	if not camera:
		push_error("Error: No camera found.")
		set_process(false)
		return

	setup_charge_ring()
	create_aim_line_mesh()


func _process(delta: float) -> void:
	if charging and camera and charge_ring:
		_animate_charge_ring(delta)

	if !is_stopped():
		if current_phase == Phase.AIMING:
			current_phase = Phase.MOVING
		stop_timer = 0.0
		_clear_aim_line()

	else:
		if current_phase == Phase.MOVING:
			stop_timer += delta
			if stop_timer >= STOP_DELAY:
				emit_signal("round_ended")
				current_phase = Phase.AIMING
		if camera.is_looking_at_player():
			_setup_aim_line()


func _input(event) -> void:
	if charging:
		if event.is_action_pressed("cancel_charging"):
			charge_ring.visible = false
			charging = false

	if event.is_action_pressed("push_ball") && \
		current_phase == Phase.AIMING && \
		camera.current_target_index == 0 && !charging:
		start_charging()
	elif event.is_action_released("push_ball"):
		release_push()



func _animate_charge_ring(delta: float) -> void:
	hit_position = camera.cursor_position
	var direction_to_camera: Vector3 = (camera.cursor_position - global_position).normalized()
	charge_ring.global_position = global_position + direction_to_camera * 1.0
	charge_ring.look_at(camera.cursor_position, Vector3.UP)
	charge_ring.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	charge_timer += delta
	var ratio: float = clamp(charge_timer / max_charge_duration, 0.0, 1.0)
	if ring_material:
		var current_color := get_charge_color(ratio)
		current_color.a = RING_ALPHA # Alpha może rosnąć z ratio ale teraz ustawiam na stałe
		ring_material.albedo_color = current_color


func get_charge_color(ratio: float) -> Color:
	# Gradient: czerwony -> żółty -> zielony
	if ratio < 0.5:
		# 0.0 - 0.5: czerwony -> żółty
		var local_ratio = ratio * 2.0 # 0.0 - 1.0
		return weak_charge_color.lerp(medium_charge_color, local_ratio)
	else:
		# 0.5 - 1.0: żółty -> zielony
		var local_ratio = (ratio - 0.5) * 2.0 # 0.0 - 1.0
		return medium_charge_color.lerp(strong_charge_color, local_ratio)


func start_charging() -> void:
	camera.cursor_phi = camera.phi
	charging = true
	charge_timer = 0.0
	charge_ring.visible = true


func release_push() -> void:
	if !charging:
		return

	charging = false
	charge_ring.visible = false

	charge_timer = clamp(charge_timer, 0.0, max_charge_duration)
	var impulse_power: float = clamp(charge_timer / max_charge_duration, MIN_IMPULSE, 1.0) * max_impulse_strength
	push_ball(impulse_power)
	current_phase = Phase.MOVING


func push_ball(impulse_power: float) -> void:
	if !camera:
		push_error("Error: No active Camera3D found.")
		return

	var camera_position = hit_position
	var ball_position = global_position
	var direction_to_camera = (camera_position - ball_position).normalized()

	print_debug("Impulse power: ", impulse_power)
	var impulse_position = -direction_to_camera * ball_radius
	var impulse_vector = direction_to_camera * impulse_power
	#print_debug("Pushed ball with force: ", impulse_power)

	print_debug("Impulse_vector: ", impulse_vector)
	apply_impulse(-impulse_vector, impulse_position)
	emit_signal("ball_pushed", impulse_power)


func setup_charge_ring() -> void:
	if charge_ring.get_surface_override_material(0):
		ring_material = charge_ring.get_surface_override_material(0).duplicate()
		charge_ring.set_surface_override_material(0, ring_material)
		# Początkowy kolor ringa (niewidoczny)
		var color = ring_material.albedo_color
		color.a = 0.0
		ring_material.albedo_color = color

		# Zacznij animacje
		var charge_animation = animation_player.get_animation("charge")
		charge_animation.loop_mode = Animation.LOOP_PINGPONG
		animation_player.play("charge")
	else:
		push_error("Error: ChargeRing has no material!")
		return


func create_aim_line_mesh() -> void:
	var mesh := ImmediateMesh.new()

	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color(1.0, 1.0, 1.0, 0.7)
	line_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

	aim_line = MeshInstance3D.new()
	aim_line.mesh = mesh
	aim_line.material_override = line_material
	add_child(aim_line)


func _clear_aim_line() -> void:
	if aimed_at_ball != null:
		aimed_at_ball.stop_being_aimed_at()
		aimed_at_ball = null
	if aim_line:
		(aim_line.mesh as ImmediateMesh).clear_surfaces()


func _setup_aim_line() -> void:
	var draw = func _draw_aim_line(to: Vector3):
		if !aim_line or !aim_line.mesh:
			return
		var mesh := aim_line.mesh as ImmediateMesh
		mesh.clear_surfaces()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(aim_line.to_local(to))

		mesh.surface_end()

	var direction_to_camera := (camera.global_position - global_position)
	direction_to_camera.y = 0.0
	direction_to_camera = direction_to_camera.normalized()
	var ray_origin := global_position
	var ray_target := ray_origin - direction_to_camera * aim_line_ray_range
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	var new_aimed_at_ball: BallParent = null

	if result: # jesli raycast w cos trafil to rysuj do tego punktu
		draw.call(result.position)
		var collider = result.collider
		if collider is BallParent:
			new_aimed_at_ball = collider
	else: # jesli nie rysuj do punktu ktory wybralismy jako cel
		draw.call(ray_target)

	if aimed_at_ball != new_aimed_at_ball:
		if aimed_at_ball:
			aimed_at_ball.stop_being_aimed_at()
		if new_aimed_at_ball:
			new_aimed_at_ball.start_being_aimed_at()
		aimed_at_ball = new_aimed_at_ball


func is_stopped() -> bool:
	return sleeping or linear_velocity.length() < MOVEMENT_THRESHOLD

func get_ball_radius() -> float:
	if !collision_shape:
		push_error("Error: CollisionShape3D of PlayerBall is null")
		return 0.0
	var shape_resource = collision_shape.shape
	if not shape_resource:
		push_error("Error: CollisionShape3D node has no shape resource assigned.")
		return 0.0
	if shape_resource is SphereShape3D:
		var sphere_shape := shape_resource as SphereShape3D
		return sphere_shape.radius
	else:
		push_error("Error: The shape is not a SphereShape3D. Cannot retrieve radius.")
		return 0.0

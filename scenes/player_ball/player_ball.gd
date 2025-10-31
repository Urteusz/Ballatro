extends RigidBody3D

const COLLISION_SHAPE_PATH = "CollisionShape3D"
const MOVEMENT_THRESHOLD = Vector3(0.03, 0.03, 0.03)

# Ustawienia uderzenia
@export var max_charge_time: float = 3.0
@export var max_impulse_strength: float = 30.0

var hit_position: Vector3 # Pozycja kamery w momencie jak zaczelismy ladowac strzal, nie wiem jak nazwac lepiej :(
var charging: bool = false
var charge_timer: float = 0.0
var impulse_power: float
var ratio: float

var cant_move := false

# Kolorki
@export var weak_color: Color = Color(0.0, 1.0, 0.0, 1.0)
@export var medium_color: Color = Color(1.0, 1.0, 0.0, 1.0)
@export var strong_color: Color = Color(1.0, 0.0, 0.0, 1.0)

# Ring i materiał ringa
@onready var charge_ring: MeshInstance3D = $ChargeRing
var ring_material: StandardMaterial3D = null

@onready var aim_line: MeshInstance3D = null
var ray_query: PhysicsRayQueryParameters3D
@export var aim_line_ray_range: float = 20.0
var currently_aimed_ball: BallParent = null

var camera: Camera3D = null
var radius = 0.0

enum Phase {AIMING, MOVING}
var current_phase: Phase = Phase.AIMING
var stop_timer: float = 0.0
const STOP_DELAY: float = 0.3

signal ball_pushed
signal round_ended

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	radius = get_ball_radius()
	
	if not camera:
		push_error("Error: No camera found.")
		set_process(false)
		return
	
	setup_charge_ring()
	setup_aim_line()

	var charge_animation = $AnimationPlayer.get_animation("charge")
	charge_animation.loop_mode = Animation.LOOP_PINGPONG
	$AnimationPlayer.play("charge")
	
	var control_gameplay = get_node("/root/Node3D/GameplayUI/ControlGameplay")
	control_gameplay.connect("player_died", _on_player_died)
	
func _on_player_died():
	print("Player dead in his script")
	cant_move = true

func _process(delta: float) -> void:
	if charging:
		if camera:
			hit_position = camera.global_position
			var direction_to_camera = (camera.global_position - global_position).normalized()
			charge_ring.global_position = global_position + direction_to_camera * 1.0
			charge_ring.look_at(camera.global_position, Vector3.UP)
			charge_ring.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
		charge_timer += delta
		ratio = clamp(charge_timer / max_charge_time, 0.0, 1.0)
		if charge_ring:
			if ring_material:
				var current_color = get_charge_color(ratio)
				current_color.a = 0.7 # Alpha może rosnąć z ratio ale teraz ustawiam na stałe
				ring_material.albedo_color = current_color
	
	if !is_stopped():
		stop_timer = 0.0
		if currently_aimed_ball:
			currently_aimed_ball.stop_being_aimed_at()
			currently_aimed_ball = null
		if aim_line:
			(aim_line.mesh as ImmediateMesh).clear_surfaces()
		if current_phase == Phase.AIMING:
			current_phase = Phase.MOVING
		return # WAŻNE - nie rysuj linii gdy kulka się rusza
	
	if current_phase == Phase.MOVING:
		stop_timer += delta
		if stop_timer >= STOP_DELAY:
			emit_signal("round_ended")
			current_phase = Phase.AIMING
	
	if camera.current_target_index == 0:
		var new_aimed_ball: BallParent = null

		var direction_to_camera = (camera.global_position - global_position)
		direction_to_camera.y = 0.0
		direction_to_camera = direction_to_camera.normalized()
			
		var ray_origin = global_position
		var ray_target = ray_origin - direction_to_camera * aim_line_ray_range
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
			
		if result:
			draw_aim_line(result.position)
			var collider = result.collider
			if collider is BallParent:
				new_aimed_ball = collider
		else:
			draw_aim_line(ray_target)
		if currently_aimed_ball != new_aimed_ball:
			if currently_aimed_ball:
				currently_aimed_ball.stop_being_aimed_at()
			if new_aimed_ball:
				new_aimed_ball.start_being_aimed_at()
			currently_aimed_ball = new_aimed_ball
	
func get_charge_color(ratio: float) -> Color:
	# Gradient: czerwony -> żółty -> zielony
	if ratio < 0.5:
		# 0.0 - 0.5: czerwony -> żółty
		var local_ratio = ratio * 2.0 # 0.0 - 1.0
		return weak_color.lerp(medium_color, local_ratio)
	else:
		# 0.5 - 1.0: żółty -> zielony
		var local_ratio = (ratio - 0.5) * 2.0 # 0.0 - 1.0
		return medium_color.lerp(strong_color, local_ratio)

func _input(event):
	if charging:
		if event.is_action_pressed("cancel_charging"):
			charge_ring.visible = false
			charging = false
	if event.is_action_pressed("push_ball") && current_phase == Phase.AIMING && camera.current_target_index == 0:
		start_charging()
	elif event.is_action_released("push_ball"):
		release_push()

func start_charging():
	charging = true
	charge_timer = 0.0
	charge_ring.visible = true

func release_push():
	if !charging:
		return
		
	charging = false
	charge_ring.visible = false
	
	impulse_power = clamp(charge_timer / max_charge_time, 0.0, 1.0) * max_impulse_strength
	push_ball(impulse_power)
	emit_signal("ball_pushed")
	current_phase = Phase.MOVING

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

func push_ball(impulse_strength):
	if !camera:
		print("Error: No active Camera3D found.")
		return
	
	var camera_position = hit_position
	var ball_position = global_position
	var direction_to_camera = (camera_position - ball_position).normalized()
	
	var impulse_position = - direction_to_camera * radius
	var impulse_vector = direction_to_camera * impulse_strength
	print("Pushed ball with force: ", impulse_strength)
	
	apply_impulse(-impulse_vector, impulse_position)
	
func setup_charge_ring():
	if charge_ring.get_surface_override_material(0):
		ring_material = charge_ring.get_surface_override_material(0).duplicate()
		charge_ring.set_surface_override_material(0, ring_material)
		# Początkowy kolor ringa (niewidoczny)
		var color = ring_material.albedo_color
		color.a = 0.0
		ring_material.albedo_color = color
	else:
		push_error("Error: ChargeRing has no material!")
		return

# Jesli wycelujemy i ustawimy kamere w jednym miejscu a potem przelaczymy na srodek
#	to przy powrocie lepiej by bylo gdyby kamera najpierw wrocila na miejsce w ktorym ja zostawilismy
#	i dopiero potem oddala kontrole
#	bo teraz nie mozna przycelowac spojrzec jak to wyglada i wrocic, bo przy powrocie sie zmienia
func draw_aim_line(to: Vector3):
	if !aim_line or !aim_line.mesh:
			return
	var mesh := aim_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(aim_line.to_local(to))
	
	mesh.surface_end()

func setup_aim_line():
	var mesh := ImmediateMesh.new()
	
	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color(1.0, 1.0, 1.0, 0.7)
	line_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	aim_line = MeshInstance3D.new()
	aim_line.mesh = mesh
	aim_line.material_override = line_material
	add_child(aim_line)
	
func get_hit_velocity_ratio():
	return impulse_power / max_impulse_strength
	
func is_stopped() -> bool:
	return sleeping or linear_velocity.length() < 0.1

extends RigidBody3D
const COLLISION_SHAPE_PATH = "CollisionShape3D"

@export var target_sprite: Node3D

# Ustawienia uderzenia
@export var max_charge_time = 3.0
@export var max_impulse_strength = 30.0
var hit_position: Vector3 # Pozycja kamery w momencie jak zaczelismy ladowac strzal, nie wiem jak nazwac lepiej :(
var charging = false
var charge_timer = 0.0
var impulse_power

# Kolorki
@export var weak_color: Color = Color(0.0, 1.0, 0.0, 1.0)
@export var medium_color: Color = Color(1.0, 1.0, 0.0, 1.0)
@export var strong_color: Color = Color(1.0, 0.0, 0.0, 1.0)

# Ring i materiał ringa
@onready var charge_ring: MeshInstance3D = $ChargeRing
var ring_material: StandardMaterial3D = null

var camera: Camera3D = null
var radius = 0.0

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	radius = get_ball_radius()
	
	if not camera:
		push_error("Error: No camera found.")
		set_process(false)
		return
	
	if not target_sprite:
		push_warning("Warning: 'target_sprite' not assigned.")
	
	charge_ring.top_level = true
	
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

func _process(delta: float) -> void:
	
	# Ustaw pozycję pierścienia na pozycję kuli
	#charge_ring.global_position = global_position - Vector3(0.0, 0.0, -2.0)
	#if camera:
		#charge_ring.global_rotation_degrees = Vector3(90, rad_to_deg(-camera.get_camera_theta()) + 90, 0)
	
	if charging:
		charge_timer += delta
		var ratio = clamp(charge_timer / max_charge_time, 0.0, 1.0)
		if ring_material:
			var current_color = get_charge_color(ratio)
			current_color.a = 0.7  # Alpha może rosnąć z ratio ale teraz ustawiam na stałe
			ring_material.albedo_color = current_color

func get_charge_color(ratio: float) -> Color:
	# Gradient: czerwony -> żółty -> zielony
	if ratio < 0.5:
		# 0.0 - 0.5: czerwony -> żółty
		var local_ratio = ratio * 2.0  # 0.0 - 1.0
		return weak_color.lerp(medium_color, local_ratio)
	else:
		# 0.5 - 1.0: żółty -> zielony
		var local_ratio = (ratio - 0.5) * 2.0  # 0.0 - 1.0
		return medium_color.lerp(strong_color, local_ratio)

func _input(event):
	if event.is_action_pressed("push_ball") && camera.current_target_index == 0:
		hit_position = camera.global_position
		start_charging()
	elif event.is_action_released("push_ball"):
		release_push()

func start_charging():
	if camera:
		charge_ring.global_rotation_degrees = Vector3(90, rad_to_deg(-camera.get_camera_theta()) + 90, 0)
		var direction_to_camera = camera.global_position - global_position
		direction_to_camera.y = 0
		direction_to_camera = direction_to_camera.normalized()
		charge_ring.global_position = global_position + direction_to_camera * 1.0
	charging = true
	charge_timer = 0.0
	if ring_material:
		var color = ring_material.albedo_color
		color.a = 0.0
		ring_material.albedo_color = color
		print("Started charging")

func release_push():
	if !charging:
		return
	charging = false
	
	if ring_material:
		var color = ring_material.albedo_color
		color.a = 0.0
		ring_material.albedo_color = color
		print("Released charge")
	
	impulse_power = clamp(charge_timer / max_charge_time, 0.0, 1.0) * max_impulse_strength
	push_ball(impulse_power)

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
	
	var impulse_position = -direction_to_camera * radius
	var impulse_vector = direction_to_camera * impulse_strength
	print("Pushed ball with force: ",impulse_strength)
	
	apply_impulse(-impulse_vector, impulse_position)

extends BallParent
class_name ExplosiveBomb
@export var extra_speed: float = 10.0
@export var explosion_radius: float = 5.0
@export var explosion_force: float = 20.0
@export var particle_effect: GPUParticles3D
@export var shockwave_effect: GPUParticles3D

func _ready():
	super._ready()
	base_value = 500
	
	if particle_effect:
		particle_effect.emitting = false
	if shockwave_effect:
		shockwave_effect.emitting = false
	
func on_hit():
	print("points")
	super.on_hit()
	
	
func _on_body_entered(body: Node3D) -> void:
	$AudioStreamPlayer3D.play() # Narazie nie ma zadnego dzwieku ustawionego
	if body.is_in_group("table"):
		return
	on_hit()
	if body.name != "PlayerBall":
		if particle_effect && shockwave_effect:
			particle_effect.emitting = true
			particle_effect.restart()
			shockwave_effect.emitting = true
			shockwave_effect.restart()
	explode()


func explode():
	print("BOOM! Eksplozja w pozycji: ", global_position)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = global_transform
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result["collider"]
		
		if body is RigidBody3D and body != self:
			var direction = (body.global_position - global_position).normalized()
			var distance = global_position.distance_to(body.global_position)
			var force_multiplier = 1.0 - (distance / explosion_radius)
			force_multiplier = clamp(force_multiplier, 0.0, 1.0)
			
			var force = direction * explosion_force * force_multiplier
			body.apply_central_impulse(force)
			
			print("Odpychanie: ", body.name, " z siłą: ", force.length())

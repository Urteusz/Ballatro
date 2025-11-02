extends BallParent
class_name ExplosiveBomb

@export var extra_speed: float = 10.0
@export var explosion_radius: float = 5.0  # Promień eksplozji
@export var explosion_force: float = 20.0  # Siła wybuchu

func _ready():
	super._ready()
	speed_max += extra_speed
	points = 500
	
func on_hit(points, hit_position):
	print("points")
	super.on_hit(points, hit_position)
	explode()

func explode():
	print("BOOM! Eksplozja w pozycji: ", global_position)
	
	# Znajdź wszystkie ciała w promieniu
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Stwórz sferę jako kształt zapytania
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = global_transform
	
	# Opcjonalnie: ustaw maski kolizji jeśli masz
	# query.collision_mask = 1  # Dostosuj do swoich layerów
	
	var results = space_state.intersect_shape(query)
	
	# Przejdź przez wszystkie znalezione obiekty
	for result in results:
		var body = result["collider"]
		
		# Sprawdź czy to RigidBody3D (piłka) i czy to nie my sami
		if body is RigidBody3D and body != self:
			# Oblicz kierunek od bomby do piłki
			var direction = (body.global_position - global_position).normalized()
			
			# Oblicz odległość dla falloff (siła maleje z odległością)
			var distance = global_position.distance_to(body.global_position)
			var force_multiplier = 1.0 - (distance / explosion_radius)
			force_multiplier = clamp(force_multiplier, 0.0, 1.0)
			
			# Zastosuj impuls
			var force = direction * explosion_force * force_multiplier
			body.apply_central_impulse(force)
			
			print("Odpychanie: ", body.name, " z siłą: ", force.length())

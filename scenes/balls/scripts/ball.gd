extends RigidBody3D
class_name BallParent

signal points_scored(points, world_position)

var points_popup = preload(ScenePaths.POINTS_POPUP_PATH)

@export var speed_max: float = 30.0
@export var points: int = 100
var current_score_total: int = 0
var current_bounces: int = 0
var total_score_popup_instance = null

func on_hit(points, hit_position):
	# dobrze by bylo gdzies wyswietlac ten potencjalne punkty do zdobycia
	#	wszystkie razem lub dla kazdej kuli osobno
	#	albo pokazywac w jakis sposob ze kula jest wiecej warta
	# przenies do oddzielnej funkcji, 
	current_bounces += 1
	var final_points = points * current_bounces
	current_score_total += final_points
	print_debug(name, ": + ", final_points, "points, total_points:  ", current_score_total, "bounces: ", current_bounces)

	var popup_instance = points_popup.instantiate()
	get_parent().add_child(popup_instance)
	popup_instance.global_position = hit_position
	popup_instance.set_and_play(final_points)

func _on_body_entered(body: Node3D):
	#print_debug("=== COLLISION DEBUG ===")
	#print("Ball class: ", get_class())
	#print("Current speed_max: ", speed_max)
	if body.is_in_group("table"):
		return
	# moze przydaloby sie tu sprawdzac czy jest w grupie od kul
	#if body.has_method("get_hit_velocity_ratio"):
		#var velocity_ratio = body.get_hit_velocity_ratio()
		#var bounce_direction = (global_position - body.global_position).normalized()
		#var bounce_force = velocity_ratio * speed_max
		#apply_central_impulse(bounce_direction * bounce_force)
	on_hit(points, global_position)

func start_being_aimed_at():
	print_debug(name, " POINTS: ", current_score_total)
	if !total_score_popup_instance:
		total_score_popup_instance = points_popup.instantiate()
		get_parent().add_child(total_score_popup_instance)
		total_score_popup_instance.global_position = global_position
		total_score_popup_instance.total_points(current_score_total)
	
func stop_being_aimed_at():
	if total_score_popup_instance:
		total_score_popup_instance.remove()
		total_score_popup_instance = null
	print_debug(name, " stopped getting aimed at")

func pocketed():
	print("Kieszen")
	points_scored.emit(points, global_position)
	# mozliwe ze to psuje kod ktory pozwalal na zmiane celu na kule
	#	ale teraz tego nie uzywamy
	queue_free()

func _on_round_ended():
	current_bounces = 0

# ball.gd (BallParent)

func _ready():
	print("BallParent _ready() called for: ", name)
	var error = body_entered.connect(_on_body_entered)
	if error != OK:
		print("BŁĄD PODŁĄCZENIA body_entered dla:", name, " Error:", error)
	else:
		print("SUKCES: Podłączono body_entered dla:", name) # <--- Sprawdź ten log!

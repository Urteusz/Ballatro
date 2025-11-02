extends RigidBody3D

class_name BallParent

signal points_scored(points, world_position)

var points_popup = preload(ScenePaths.POINTS_POPUP_PATH)

# Bazowa ilosc punktow za zderzenie
@export var base_value: int = 100 
#@export var point_multiplier: int = 1


var total_points: int = 0 # Suma punktow jaka sie dostanie za wbicie kuli
var total_bounces_round: int = 0 # Suma odbic w jednej rundzie (do momentu zatrzymania sie bialej bili)
var total_score_popup_instance = null


func pocketed() -> void:
	points_scored.emit(total_points, global_position)
	# mozliwe ze to psuje kod ktory pozwalal na zmiane celu na kule
	#	ale teraz tego nie uzywamy
	queue_free() # Podobnie jak z wyswietlaniem punktow mozliwe ze przy wiekszej ilosci lepiej bedzie zaimplementowac 'object pool'
	

func on_hit() -> void:
	total_bounces_round += 1

	var points_gained: int = _calculate_points()
	print_debug(name, ": + ", points_gained, "points, total_points:  ", total_points, "bounces: ", total_bounces_round)
	total_points += points_gained

	_show_popup(global_position, points_gained) # global_position -> miejsce kuli w momencie zderzenia

# Inne kule zmienialyby implementacje tego
func _calculate_points() -> int:
	return base_value * total_bounces_round
	
func _show_popup(hit_position: Vector3, points_gained: int) -> void:
	var popup_instance = points_popup.instantiate()
	get_parent().add_child(popup_instance)
	popup_instance.global_position = hit_position
	popup_instance.set_and_play(points_gained)

func _on_body_entered(body: Node3D) -> void:
	$AudioStreamPlayer3D.play() # Narazie nie ma zadnego dzwieku ustawionego
	if body.is_in_group("table"):
		return
	on_hit()


func start_being_aimed_at() -> void:
	if !total_score_popup_instance:
		total_score_popup_instance = points_popup.instantiate()
		get_parent().add_child(total_score_popup_instance)
		total_score_popup_instance.global_position = global_position
		total_score_popup_instance.total_points(total_points)


func stop_being_aimed_at() -> void:
	if total_score_popup_instance:
		total_score_popup_instance.remove()
		total_score_popup_instance = null
	print_debug(name, " stopped getting aimed at")


func _on_round_ended() -> void:
	total_bounces_round = 0


func _ready() -> void:
	var error = body_entered.connect(_on_body_entered)
	if error != OK:
		push_error("BŁĄD PODŁĄCZENIA body_entered dla:", name, " Error:", error)
	#else:
		#print_debug("SUKCES: Podłączono body_entered dla:", name)

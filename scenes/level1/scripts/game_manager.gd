extends Node3D

const BALLS_GROUP = "balls"

@export var default_level_move_count: int = 10
@export var player_ball: RigidBody3D
@export var shop_ui: Control

var moves_left: int
var game_over := false
var ball_list: Array
var points: int = 0

signal player_died
signal player_win
signal moves_changed(moves_left: int)
signal points_changed(points: int)

func _ready() -> void:
	moves_left = default_level_move_count
	
	ball_list = get_tree().get_nodes_in_group(BALLS_GROUP)
	ball_list.erase(player_ball)
	for ball in ball_list:
		if ball.has_signal("ball_pocketed"):
			ball.ball_pocketed.connect(_on_ball_pocketed)
	
	player_ball.connect("ball_pushed", _on_ball_pushed)

	for ball in ball_list:
		if ball.has_signal("points_scored"):
			ball.points_scored.connect(_on_points_scored)

	if shop_ui:
		connect("points_changed", shop_ui._on_points_updated)

func _on_ball_pocketed(ball):
	ball_list.erase(ball)
	if ball_list.size() == 0:
		emit_signal("player_win")


func _on_ball_pushed(impulse_power: float) -> void:
	if game_over:
		return
	if moves_left > 1:
		moves_left -= 1
		emit_signal("moves_changed", moves_left)
	else:
		_on_game_over()

func _on_points_scored(points_earned: int, world_pos: Vector3) -> void:
	points += points_earned
	print_debug("Zdobyto punkty:", points_earned, "Suma:", points)
	emit_signal("points_changed", points)

func _on_game_over() -> void:
	if game_over:
		return
	game_over = true
	emit_signal("player_died")

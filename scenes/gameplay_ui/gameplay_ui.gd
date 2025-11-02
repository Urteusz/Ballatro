extends Control

@export var default_level_moves = 10
@onready var player_ball = get_node("/root/Node3D/SubViewportContainer/SubViewport/Table/PlayerBall")

signal player_died

var moves_left = default_level_moves
var dead_screen := false


func _ready():
	player_ball.connect("ball_pushed", _on_ball_pushed)

	$VBoxContainer/Count.text = "%d" % moves_left
	$VBoxContainer/Label_count.text = "Moves left"
	$HBoxContainer.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	$HBoxContainer/Button_again.pressed.connect(_on_try_again)
	$HBoxContainer/Button_exit.pressed.connect(_on_main_menu)


func _on_ball_pushed(impulse_power: float):
	if !dead_screen:
		if (moves_left - 1) > 0:
			moves_left -= 1
			$VBoxContainer/Count.text = "%d" % moves_left
		else:
			_toggle_death()
			$VBoxContainer/Count.text = ""
			$VBoxContainer/Label_count.text = "You died"


func _on_try_again():
	moves_left = default_level_moves
	LoadManager.load_scene(ScenePaths.LEVEL1_PATH)


func _on_main_menu():
	LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)


func _toggle_death():
	dead_screen = !dead_screen
	$HBoxContainer.visible = dead_screen
	if dead_screen:
		emit_signal("player_died")
		mouse_filter = Control.MOUSE_FILTER_STOP
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

extends Control

@export var default_level_move_count: int = 10
@export var player_ball: RigidBody3D = null

# nie za dobre tak odnosic sie sciezkami do rzeczy chyba, '%' mi nie dzialalo
@onready var moves_title_label: Label = $"MovesLeftHUD/MovesTitleLabel"
@onready var moves_count_label: Label = $"MovesLeftHUD/MovesCountLabel"
@onready var game_over_window := $"GameOverWindow"
@onready var again_button: Button = $"GameOverWindow/ExitButton"
@onready var exit_button: Button = $"GameOverWindow/ExitButton"

signal player_died

var moves_left: int = default_level_move_count
var game_over: bool = false


func _ready() -> void:
	player_ball.connect("ball_pushed", _on_ball_pushed)
	_setup_ui()

func _setup_ui() -> void:
	moves_count_label.text = "%d" % moves_left
	moves_title_label.text = "Moves left"
	game_over_window.visible = false
	again_button.pressed.connect(_on_try_again)
	exit_button.pressed.connect(_on_main_menu)
	_ignore_mouse()


func _on_ball_pushed(impulse_power: float) -> void:
	if !game_over:
		if (moves_left - 1) > 0:
			moves_left -= 1
			moves_count_label.text = "%d" % moves_left
		else:
			# powinno czekac az kula sie zatrzyma a nie dawac od razu game over
			_on_game_over()
			moves_count_label.text = ""
			moves_title_label.text = "You died"


func _on_try_again():
	moves_left = default_level_move_count
	LoadManager.load_scene(ScenePaths.LEVEL1_PATH)


func _on_main_menu():
	LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)


func _on_game_over():
	if game_over:
		return
	game_over = true
	game_over_window.visible = true
	emit_signal("player_died")
	_enable_mouse()


func _ignore_mouse() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enable_mouse() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

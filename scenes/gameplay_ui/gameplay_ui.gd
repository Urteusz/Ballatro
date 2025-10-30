extends Control

@export var moves_left=10

signal player_died

var dead_screen := false

func _ready():
	$VBoxContainer/Count.text = "%d" % moves_left
	$VBoxContainer/Label_count.text = "Moves left"
	$HBoxContainer.visible = false
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	$HBoxContainer/Button_again.pressed.connect(_on_try_again)
	$HBoxContainer/Button_exit.pressed.connect(_on_main_menu)
	
func _on_move():
	if (moves_left-1)>0:
		moves_left -= 1
		$VBoxContainer/Count.text = "%d" % moves_left
	else:
		_toggle_death()
		$VBoxContainer/Count.text = ""
		$VBoxContainer/Label_count.text = "You died"

func _on_try_again():
	moves_left = 10
	LoadManager.load_scene(ScenePaths.LEVEL1_PATH)

func _on_main_menu():
	LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)

func _process(delta):
	#tymaczosow tu bedzie cos innego trzeba zrobić poki co sciaga w
	if Input.is_action_just_pressed("push_ball") && !dead_screen:
		_on_move()

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
	

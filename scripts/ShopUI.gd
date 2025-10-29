extends Control

@onready var shop_camera = $SubViewportContainer/SubViewport/Camera3D
@onready var shop_balls = $SubViewportContainer/SubViewport/ShopBalls
var shop_positions_set := false

@export var points: int = 100
var shop_open := false

func _ready():
	$Label.text = "Punkty: %d" % points
	$HBoxContainer.visible = false
	
	for ball in get_tree().get_nodes_in_group("balls"):
		if ball.has_signal("points_scored"):
			ball.points_scored.connect(_on_points_scored)
			print("Podłączono sygnał do piłki:", ball.name)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	for item_button in $HBoxContainer.get_children():
		item_button.connect("pressed", Callable(self, "_on_item_pressed").bind(item_button.text))

func _on_points_scored(points_earned: int, world_pos: Vector3):
	points += points_earned
	$Label.text = "Punkty: %d" % points
	print("Zdobyto punkty:", points_earned, "Suma:", points)

func _on_item_pressed(item_name: String):
	print("Kliknięto przycisk:", item_name)
	match item_name:
		"Kulka Czerwona":
			_buy_item(item_name, 20)
		"Kulka Zielona":
			_buy_item(item_name, 25)
		"Kulka Niebieska":
			_buy_item(item_name, 30)
		"Kulka Złota":
			_buy_item(item_name, 50)
		"Kulka Ciemna":
			_buy_item(item_name, 40)

func _buy_item(item_name: String, cost: int):
	if points >= cost:
		points -= cost
		$Label.text = "Punkty: %d" % points
		print("Kupiono:", item_name)
	else:
		print("Za mało punktów na", item_name)

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_shop()

func _toggle_shop():
	shop_open = !shop_open
	$HBoxContainer.visible = shop_open
	if shop_balls:
		for shop_ball in shop_balls.get_children():
			shop_ball.visible = shop_open
	if shop_open:
		mouse_filter = Control.MOUSE_FILTER_STOP 
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if not shop_positions_set:
			align_shop_items()
			shop_positions_set = true
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func align_shop_items():
	await get_tree().process_frame
	

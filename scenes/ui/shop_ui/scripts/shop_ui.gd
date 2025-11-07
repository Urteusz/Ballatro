extends Control

@onready var shop_camera = $SubViewportContainer/SubViewport/Camera3D
@onready var shop_balls = $SubViewportContainer/SubViewport/ShopBalls
@onready var label = $LabelPoints
@onready var buttons_container = $HBoxContainer

var shop_open := false
var shop_positions_set := false
var points: int = 0

func _ready() -> void:
	buttons_container.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item_button in buttons_container.get_children():
		item_button.connect("pressed", Callable(self, "_on_item_pressed").bind(item_button.text))

func _on_points_updated(new_points: int) -> void:
	points = new_points
	label.text = "Punkty: %d" % points

func _on_item_pressed(item_name: String) -> void:
	match item_name:
		"Kulka Czerwona": _buy_item(item_name, 20)
		"Kulka Zielona": _buy_item(item_name, 25)
		"Kulka Niebieska": _buy_item(item_name, 30)
		"Kulka Złota": _buy_item(item_name, 50)
		"Kulka Ciemna": _buy_item(item_name, 40)

func _buy_item(item_name: String, cost: int) -> void:
	if points >= cost:
		points -= cost
		label.text = "Punkty: %d" % points
		print_debug("Kupiono:", item_name)
	else:
		print_debug("Za mało punktów na", item_name)

func _process(delta) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_shop()

func _toggle_shop() -> void:
	shop_open = !shop_open
	buttons_container.visible = shop_open
	$QuitButton.visible = shop_open

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

func align_shop_items() -> void:
	await get_tree().process_frame

func _on_quit_button_pressed() -> void:
	LoadManager.load_scene(ScenePaths.MAIN_MENU_PATH)

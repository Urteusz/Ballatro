extends Control

@export var move_offset := Vector2(50.0, 0.0) # Moves right by default
@export var effect_radius: float = 200.0
@export var smooth_speed: float = 15.0

@onready var options: CanvasLayer = %OptionsMenu
@onready var options_button: Button = %OptionsButton
@onready var play_button: Button = %PlayButton
@onready var quit_button: Button = %QuitButton

# Using Control allows the array to hold both ColorRects and Buttons
var ui_elements: Array[Control] = []
var original_positions: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is ColorRect or child is Button:
			ui_elements.append(child)
			original_positions[child] = child.position

func _process(delta: float) -> void:
	var mouse_pos := get_local_mouse_position()
	
	for element in ui_elements:
		var orig_pos: Vector2 = original_positions[element]
		
		var closest_x: float = clamp(mouse_pos.x, orig_pos.x, orig_pos.x + element.size.x)
		var closest_y: float = clamp(mouse_pos.y, orig_pos.y, orig_pos.y + element.size.y)
		var closest_point := Vector2(closest_x, closest_y)
		
		var distance := mouse_pos.distance_to(closest_point)
		
		var proximity_factor: float = clamp(1.0 - (distance / effect_radius), 0.0, 1.0)
		
		var target_position := orig_pos + (move_offset * proximity_factor)
		
		element.position = element.position.lerp(target_position, smooth_speed * delta)
		
func _on_options_button_pressed() -> void:
	options.fade_in()
	
func _on_play_button_pressed() -> void:
	if play_button.disabled: return
	_lock_buttons()
	
	var target_width := get_viewport_rect().size.x
	var tween := create_tween().set_parallel(true)

	for element in ui_elements:
		var distance := element.position.distance_to(play_button.position)
		var delay := distance * 0.0015
		
		tween.tween_property(element, "size:x", target_width, 0.5) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN_OUT) \
			.set_delay(delay)
			
	LoadManager.load_scene(ScenePaths.LEVEL_SELECT_MAP)

func _on_quit_button_pressed() -> void:
	_lock_buttons()
	
	var target_width := get_viewport_rect().size.x
	var tween := create_tween().set_parallel(true)

	for element in ui_elements:
		var distance := element.position.distance_to(quit_button.position)
		var delay := distance * 0.0015
		
		tween.tween_property(element, "size:x", target_width, 0.5) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN_OUT) \
			.set_delay(delay)
			
	await tween.finished
	
	get_tree().quit()

func _lock_buttons() -> void:
	if play_button: play_button.disabled = true
	if options_button: options_button.disabled = true
	if quit_button: quit_button.disabled = true

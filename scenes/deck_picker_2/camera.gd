extends Camera3D

const BLUR_AMOUNT: float = 0.12

@export var camera_tween_duration: float = 1.0

@onready var camera_position_player_ball: Marker3D = %CameraPositionPlayerBall
@onready var camera_position_deck: Marker3D = %CameraPositionDeck
@onready var player_ball: Node3D = %player_black
@onready var power_up_selector: Node = %ScrollContainer3D
# these should just receive a signal
#	but i cba
@onready var move_to_power_up_button: TextureButton = %MoveToPowerUpButton
@onready var move_to_deck_button: TextureButton = %MoveToDeckButton

@export_group("Hold Settings")
@export var hold_time_required: float = 1.0
@export var hold_delay: float = 0.15

var looking_at_deck: bool = true
var tween: Tween
var is_locked: bool = false
var is_moving_to_deck: bool = true
var deck_ball_focus_active: bool = false

var hold_progress: float = 0.0
var base_ball_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	global_transform = camera_position_deck.global_transform
	if player_ball:
		base_ball_scale = player_ball.scale

func _input(event: InputEvent) -> void:
	if is_locked:
		return
	
	if event.is_action_pressed("ui_cancel") and looking_at_deck:
		if deck_ball_focus_active:
			return
		if LoadManager:
			LoadManager.load_scene(ScenePaths.LEVEL_SELECT_MAP)
		return
	
	if is_moving_to_deck and (_is_ui_nav_pressed(event, "ui_right") or event.is_action_pressed("ui_details")):
		_show_power_up_view()
		get_viewport().set_input_as_handled()
		return

	if not is_moving_to_deck and _is_ui_nav_pressed(event, "ui_right"):
		if power_up_selector and power_up_selector.has_method("move_focus"):
			power_up_selector.move_focus(1)
		get_viewport().set_input_as_handled()
		return

	if not is_moving_to_deck and _is_ui_nav_pressed(event, "ui_left"):
		var moved_power_up_focus := false
		if power_up_selector and power_up_selector.has_method("move_focus"):
			moved_power_up_focus = bool(power_up_selector.move_focus(-1))
		if not moved_power_up_focus:
			_show_deck_view()
		get_viewport().set_input_as_handled()
		return

	if (event.is_action_pressed("ui_details") or event.is_action_pressed("ui_cancel")) and not is_moving_to_deck:
		_show_deck_view()
		get_viewport().set_input_as_handled()
		return

func _process(delta: float) -> void:
	var is_pressing = false
	
	if not looking_at_deck and not is_moving_to_deck:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mouse_pos = get_viewport().get_mouse_position()
			if _is_hovering(mouse_pos, player_ball):
				is_pressing = true
		elif Input.is_action_pressed("ui_accept"):
			is_pressing = true
			
	if is_pressing:
		hold_progress += delta
		if hold_progress > hold_delay:
			var active_hold = hold_progress - hold_delay
			var ratio = clamp(active_hold / hold_time_required, 0.0, 1.0)
			
			if player_ball:
				player_ball.scale = base_ball_scale.lerp(base_ball_scale + Vector3(0.2, 0.2, 0.2), ratio)
				
			if active_hold >= hold_time_required:
				hold_progress = 0.0
				var level_path = PlayerData.get_level_path()
				if LoadManager:
					LoadManager.load_scene(level_path)
	else:
		if hold_progress > 0.0:
			_reset_ball_hold()

func move_to(target_transform: Transform3D, target_blur_amount: float) -> void:
	if tween and tween.is_valid():
		tween.kill()
		
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	
	var attributes = self.attributes as CameraAttributesPractical
	if attributes:
		tween.tween_property(attributes, "dof_blur_amount", target_blur_amount, camera_tween_duration)
	tween.tween_property(self, "global_transform", target_transform, camera_tween_duration)

func _reset_ball_hold() -> void:
	hold_progress = 0.0
	if player_ball and player_ball.scale != base_ball_scale:
		var scale_tween = create_tween()
		scale_tween.tween_property(player_ball, "scale", base_ball_scale, 0.2)

func _is_hovering(mouse_pos: Vector2, target_node: Node3D) -> bool:
	if not target_node: 
		return false
	
	var ray_origin = project_ray_origin(mouse_pos)
	var ray_dir = project_ray_normal(mouse_pos)
	var center = target_node.global_position
	
	var radius = 0.5
	var mesh_inst = target_node.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst and mesh_inst.mesh:
		radius = mesh_inst.mesh.get_aabb().size.length() * 0.5 * mesh_inst.scale.x * 0.6
		
	var l = center - ray_origin
	var tca = l.dot(ray_dir)
	if tca < 0.0:
		return false
		
	var d2 = l.dot(l) - tca * tca
	return d2 <= radius * radius

# setting of state in these two is the same as at the top of this file
#	rewrite this
func _on_move_to_power_up_button_pressed() -> void:
	_show_power_up_view()

func _show_power_up_view() -> void:
	if deck_ball_focus_active:
		return
	is_moving_to_deck = false
	move_to_power_up_button.visible = false
	move_to_deck_button.visible = true
	looking_at_deck = false
	move_to(camera_position_player_ball.global_transform, BLUR_AMOUNT)


func _on_move_to_deck_button_pressed() -> void:
	_show_deck_view()

func _show_deck_view() -> void:
	is_moving_to_deck = true
	looking_at_deck = true
	move_to_power_up_button.visible = true
	move_to_deck_button.visible = false
	move_to(camera_position_deck.global_transform, 0.0)

func set_deck_ball_focus_active(active: bool) -> void:
	deck_ball_focus_active = active

func _is_ui_nav_pressed(event: InputEvent, action: String) -> bool:
	if deck_ball_focus_active:
		return false
	if InputManager and InputManager.has_method("is_ui_navigation_action_pressed_once"):
		return InputManager.is_ui_navigation_action_pressed_once(event, action)
	return event.is_action_pressed(action)

extends Camera3D

const BLUR_AMOUNT: float = 0.12

@export var tween_duration: float = 1.0

@onready var camera_position_player_ball: Marker3D = %CameraPositionPlayerBall
@onready var camera_position_deck: Marker3D = %CameraPositionDeck

var looking_at_deck: bool = true
var tween: Tween
# so the input logic doesnt run when the player has selected a ball in the deck
var is_locked: bool = false
var is_moving_to_deck: bool = true

func _ready() -> void:
	global_transform = camera_position_deck.global_transform

func _input(event: InputEvent) -> void:
	if is_locked:
		return
	
	if Input.is_action_just_pressed("look_right") and is_moving_to_deck:
		is_moving_to_deck = false
		looking_at_deck = false
		move_to(camera_position_player_ball.global_transform, BLUR_AMOUNT)
	if Input.is_action_just_pressed("look_left") and not is_moving_to_deck:
		is_moving_to_deck = true
		looking_at_deck = true
		move_to(camera_position_deck.global_transform, 0.0)

func move_to(target_transform: Transform3D, target_blur_amount: float) -> void:
	if tween and tween.is_valid():
		tween.kill()
		
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	
	var attributes = self.attributes as CameraAttributesPractical
	
	tween.tween_property(attributes, "dof_blur_amount", target_blur_amount, tween_duration)
	tween.tween_property(self, "global_transform", target_transform, tween_duration)

extends TextureRect

@export var scale_amount: float = 1.01
@export var reset_time: float = 0.5

var tween: Tween = null

var initial_scale: Vector2 = Vector2(1.0, 1.0)
var target_scale: Vector2 = Vector2.ONE

var press_count: int = 0
var time_since_last_press: float = 0.0

func _ready() -> void:
	initial_scale = scale
	target_scale = initial_scale * scale_amount

func _process(delta: float) -> void:
	if press_count > 0:
		time_since_last_press += delta
		if time_since_last_press > reset_time:
			press_count = 0
			time_since_last_press = 0.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		press_count += 1
		time_since_last_press = 0.0
		
		if press_count >= 10:
			PlayerData.unlock_ball("opona")
			press_count = 0

func _on_mouse_entered() -> void:
	if tween and tween.is_valid() and tween.is_running():
		tween.kill()

	tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, 0.15)

func _on_mouse_exited() -> void:
	if tween and tween.is_valid() and tween.is_running():
		tween.kill()

	tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", initial_scale, 0.15)

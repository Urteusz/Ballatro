extends TextureRect

@export var scale_amount: float = 1.01

var tween: Tween = null

var initial_scale: Vector2 = Vector2(1.0, 1.0)
var target_scale: Vector2 = initial_scale * scale

func _ready() -> void:
	initial_scale = scale
	target_scale = initial_scale * scale_amount

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

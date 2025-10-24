extends RigidBody3D

signal points_scored(points, world_position)

var points_popup = preload("res://scenes/points_popup.tscn")

func on_hit(points, hit_position):
	var popup_instance = points_popup.instantiate()
	get_parent().add_child(popup_instance)
	popup_instance.global_position = hit_position
	popup_instance.set_and_play(points)
	print("on hit")

func _on_body_entered(body: Node3D):
	var points = 100
	on_hit(points, global_position)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	pass

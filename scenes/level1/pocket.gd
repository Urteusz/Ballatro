extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_pocket_body_entered)	
	
func _on_pocket_body_entered(body: Node3D):
	if body is BallParent:
		body.pocketed()

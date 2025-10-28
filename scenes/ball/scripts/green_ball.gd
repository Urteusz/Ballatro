extends BallParent
class_name SuperBall

@export var extra_speed: float = 10.0

func _ready():
	print("SuperBall _ready() START")
	super._ready()
	print("SuperBall _ready() after super")
	speed_max += extra_speed
	print("SuperBall speed_max: ", speed_max)

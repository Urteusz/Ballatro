extends BallParent

class_name SuperBall

@export var extra_speed: float = 10.0


# jesli chcesz uzywac tej kuli to trzeba to napisac od nowa
#	i zmienic model bo gra sie laduje 10 sekund dluzej jak trzeba go wczytac 🐸
func _ready() -> void:
	print_debug("SuperBall _ready() START")
	super._ready()
	print_debug("SuperBall _ready() after super")
	#speed_max += extra_speed
	#print("SuperBall speed_max: ", speed_max)

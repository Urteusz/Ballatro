extends Node3D

# to musi byc potem przepisane zeby uzywalo object pool
#	inaczej bedzie lagowac pewnie
# aby dzialalo to z edge detection shaderem ustawilem render priority label3d na 127 i 126

func set_and_play(value):
	print_debug("set_and_play() called")
	%Label3D.text = str(value)
	%AnimationPlayer.play("PointsPopupAnimation")

func total_points(value):
	%Label3D.text = str(value)
	%AnimationPlayer.play("TotalPointsAnimation")

func remove():
	queue_free()

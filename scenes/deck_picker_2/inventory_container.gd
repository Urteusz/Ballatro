extends Node3D

signal ball_selected(ball_data)

const GOLDEN_ANGLE = 2.39996 
@export var spacing: float = 1.2
@export var pan_speed: float = 0.02

@onready var camera: Camera3D = %Camera3D
var balls: Array[Node3D] = []
var center_ball: Node3D = null

func setup(deck_ball: Node3D, inventory_data: Array[BallData]) -> void:
	center_ball = deck_ball
	
	# Spawn inventory balls in a spiral
	for i in range(inventory_data.size()):
		var ball_data = inventory_data[i]
		var ball = ball_data.scene.instantiate()
		add_child(ball)
		ball.set_meta("ball_data", ball_data)
		
		# Fermat's Spiral math
		var r = spacing * sqrt(i + 1)
		var theta = (i + 1) * GOLDEN_ANGLE
		ball.position = Vector3(r * cos(theta), r * sin(theta), 0)
		
		# Setup click detection
		if ball is CollisionObject3D:
			ball.input_event.connect(_on_ball_clicked.bind(ball))
		
		balls.append(ball)

func _process(_delta: float) -> void:
	var viewport = get_viewport()
	var center_screen = viewport.get_visible_rect().size / 2.0
	
	for ball in balls:
		# Calculate scale based on distance to center of screen
		var screen_pos = camera.unproject_position(ball.global_position)
		var dist = screen_pos.distance_to(center_screen)
		
		# Lens Effect: 1.0 scale at center, 0.3 at edges
		var scale_factor = clamp(1.0 - (dist / 600.0), 0.3, 1.0)
		ball.scale = Vector3.ONE * scale_factor

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Pan container
		position.x += event.relative.x * pan_speed
		position.y -= event.relative.y * pan_speed

func _on_ball_clicked(_cam, event, _pos, _normal, _shape, ball):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ball_selected.emit(ball.get_meta("ball_data"))

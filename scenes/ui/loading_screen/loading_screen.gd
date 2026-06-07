extends CanvasLayer

signal loading_screen_has_full_coverage

@export_category("Video Files")
@export var file_fill: VideoStream = preload("res://scenes/ui/loading_screen/fill.ogv")
@export var file_empty: VideoStream = preload("res://scenes/ui/loading_screen/empty.ogv")

# Reference both players
@onready var player_fill: VideoStreamPlayer = $VideoLayer_Fill
@onready var player_empty: VideoStreamPlayer = $VideoLayer_Empty
@onready var progress_bar: ProgressBar = $Panel/ProgressBar
@onready var panel: Panel = $Panel
@onready var animation_player = $AnimationPlayer

var _is_loading_finished: bool = false
var _fill_finished: bool = false

func _ready() -> void:
	player_fill.stream = file_fill
	player_empty.stream = file_empty

	player_fill.play()
	player_empty.play()

	await get_tree().process_frame

	player_fill.paused = true
	player_empty.paused = true
	player_empty.stream_position = 0.0
	player_empty.hide()

	player_fill.finished.connect(_on_fill_finished)

	player_fill.paused = false

func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _update_progress_bar(new_value: float) -> void:
	progress_bar.set_value_no_signal(new_value * 100)

func _start_outro_animation() -> void:
	_is_loading_finished = true
	_check_and_start_outro()

func _on_fill_finished() -> void:
	_fill_finished = true
	
	player_fill.paused = true
	
	loading_screen_has_full_coverage.emit()
	_check_and_start_outro()

func _check_and_start_outro() -> void:
	if _fill_finished and _is_loading_finished:
		_transition_to_empty()

func _transition_to_empty() -> void:
	player_empty.show()

	player_empty.paused = false

	if not is_instance_valid(animation_player) or not is_instance_valid(player_fill):
		return

	animation_player.play("loading_end")

	player_fill.queue_free()

	await player_empty.finished
	queue_free()

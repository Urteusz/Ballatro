extends Button
class_name InventoryItem

enum State {
	LOCKED,
	UNLOCKED,
	EQUIPPED
}

var current_state = State.LOCKED
var base_color: Color

func _ready() -> void:
	base_color = self_modulate
	update_visuals()
	
func setup(initial_state: State) -> void:
	current_state = initial_state
	if is_inside_tree():
		update_visuals()
		
func change_state(new_state: State) -> void:
	current_state = new_state
	update_visuals()

func update_visuals() -> void:
	if base_color == Color.BLACK or base_color == Color(0, 0, 0 ,0):
		base_color = self_modulate
	
	match current_state:
		State.LOCKED:
			disabled = true
			self_modulate = self_modulate.darkened(0.5)
		State.UNLOCKED:
			disabled = false
			self_modulate = base_color
		State.EQUIPPED:
			self_modulate = base_color + Color(0.0, 0.3, 0.5, 0.0)

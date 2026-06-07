extends GridContainer

signal item_selected(index)
signal selection_changed(new_index)

const INVENTORY_ITEM_SCENE = preload("res://scenes/DeckChoose/InventoryBallItem.tscn")

var current_index: int = 0

func _ready() -> void:
	refresh_ui()
	
func refresh_ui() -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()

	# Populate from PlayerData
	var owned_ids = PlayerData.owned_balls
	var deck = PlayerData.current_deck

	for ball_id in owned_ids:
		var ball_data = PlayerData.ball_data_map.get(ball_id)
		# Skip if already in deck
		if not ball_data or ball_data in deck:
			continue

		var item = INVENTORY_ITEM_SCENE.instantiate()
		add_child(item)
		item.setup(ball_data)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Reset index if we have fewer items than before
	var items = get_inventory_items()
	current_index = clampi(current_index, 0, maxi(0, items.size() - 1))
	
	update_visuals()

# Handles navigation math internally
func navigate(dx: int, dy: int) -> void:
	var items = get_inventory_items()
	if items.is_empty():
		return
		
	var count = items.size()
	var cols = maxi(1, columns)
	
	var col = current_index % cols
	var row = current_index / cols
	var last_row = (count - 1) / cols
	
	var new_index = current_index
	
	if dx == 1:
		if col < cols - 1 and current_index + 1 < count:
			new_index = current_index + 1
	elif dx == -1:
		if col > 0:
			new_index = current_index - 1
	elif dy == 1: # Up
		if current_index - cols >= 0:
			new_index = current_index - cols
	elif dy == -1: # Down
		if current_index + cols < count:
			new_index = current_index + cols
		elif row < last_row: # Snap to last item if row is incomplete
			new_index = count - 1

	if new_index != current_index:
		current_index = new_index
		update_visuals()
		emit_signal("selection_changed", current_index)

func update_visuals() -> void:
	var items = get_inventory_items()
	
	# Highlight
	for i in range(items.size()):
		var target_color = Color(1, 1, 1, 1) if i == current_index else Color(0.55, 0.55, 0.6, 1)
		create_tween().tween_property(items[i], "modulate", target_color, 0.12)
	
	# Scroll
	if current_index >= 0 and current_index < items.size():
		var scroll = get_parent() as ScrollContainer
		if scroll:
			scroll.ensure_control_visible(items[current_index])

func get_selected_item() -> Control:
	var items = get_inventory_items()
	if current_index >= 0 and current_index < items.size():
		return items[current_index]
	return null

func get_inventory_items() -> Array:
	var result: Array = []
	for item in get_children():
		if item is Control and item.visible:
			result.append(item)
	return result

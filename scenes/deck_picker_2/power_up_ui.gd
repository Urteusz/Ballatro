extends Control

var inventory_item_scene := preload("res://scenes/deck_picker_2/inventory_item.tscn")

@onready var vbox_container: VBoxContainer = $ScrollContainer/VBoxContainer

func _ready() -> void:
	_populate_list()
	
func _populate_list() -> void:
	for child in vbox_container.get_children():
		child.queue_free()
		
	for powerup_id in PlayerData.PowerUp.values():
		var item: InventoryItem = inventory_item_scene.instantiate()
		
		var assigned_state = InventoryItem.State.LOCKED
		
		if powerup_id == PlayerData.active_power_up:
			assigned_state = InventoryItem.State.EQUIPPED
		elif powerup_id in PlayerData.unlocked_power_ups:
			assigned_state = InventoryItem.State.UNLOCKED
			
		item.setup(assigned_state)
		
		item.text = PlayerData.PowerUp.keys()[powerup_id].capitalize()

		vbox_container.add_child(item)

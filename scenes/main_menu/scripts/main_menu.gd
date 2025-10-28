extends PanelContainer

func _on_play_button_pressed() -> void:
	LoadManager.load_scene(ScenePaths.LEVEL1_PATH)

func _on_options_button_pressed() -> void:
	pass # Replace with function body.

func _on_quit_button_pressed() -> void:
	get_tree().quit()

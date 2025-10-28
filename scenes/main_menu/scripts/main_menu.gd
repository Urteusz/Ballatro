extends PanelContainer

func _on_play_button_pressed() -> void:
	LoadManager.load_scene(ScenePaths.LEVEL1_PATH)

# moze lepiej by bylo sobie darowac ten loading screen tutaj
func _on_options_button_pressed() -> void:
	LoadManager.load_scene(ScenePaths.OPTIONS_MENU_PATH)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

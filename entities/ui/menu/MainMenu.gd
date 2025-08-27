class_name MainMenu extends Control

func _on_new_game_button_pressed():
	get_tree().change_scene_to_file("res://entities/station/station_scene.tscn")

func _on_load_game_button_pressed():
	pass

func _on_settings_button_pressed():
	pass

func _on_quit_button_pressed():
	get_tree().quit()

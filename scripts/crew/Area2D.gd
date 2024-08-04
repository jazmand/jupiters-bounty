extends Area2D

signal gui_toggle

func _input_event(viewport, event, _shape_idx):
	if event.is_action_pressed("select"):
		gui_toggle.emit()
		viewport.set_input_as_handled()

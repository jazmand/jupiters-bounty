extends Area2D

signal gui_toggle

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			gui_toggle.emit()

class_name GUIManager extends Control

const POPUP_SCENE: PackedScene = preload("res://entities/ui/popup/popup.tscn")

func new_popup(default_visible: bool, accept_function: Callable, decline_function: Callable) -> GUIPopup:
	var popup: GUIPopup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.set_visibility(default_visible).connect_yes(accept_function).connect_no(decline_function)
	return popup

func _on_add_crew_pressed() -> void: # TEMPORARY
	Events.gui_add_crew_pressed.emit()

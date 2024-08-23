# GUIManager.gd

class_name GUIManager
extends Control

const popup_scene: PackedScene = preload("res://popup.tscn")

signal add_crew_pressed # TEMPORARY

func new_popup(default_visible: bool, accept_function: Callable, decline_function: Callable) -> GUIPopup:
	var popup: GUIPopup = popup_scene.instantiate()
	add_child(popup)
	popup.set_visibility(default_visible).connect_yes(accept_function).connect_no(decline_function)
	return popup

func _on_add_crew_pressed() -> void: # TEMPORARY
	emit_signal("add_crew_pressed")

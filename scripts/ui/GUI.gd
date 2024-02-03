# GUI.gd

class_name GUI
extends Control

const popup_scene: PackedScene = preload("res://popup.tscn")

@onready var build_menu: BuildMenu = $BuildMenu

func new_popup(popup_message: String, default_visible: bool, accept_function: Callable, decline_function: Callable) -> GUIPopup:
	var popup: GUIPopup = popup_scene.instantiate()
	add_child(popup)
	popup.set_text(popup_message).set_visibility(default_visible).connect_yes(accept_function).connect_no(decline_function)
	return popup

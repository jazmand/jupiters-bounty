# BuildMenu.gd

class_name BuildMenu
extends Control

signal action_completed(action: int)

enum Action {CLOSE, OPEN, SELECT_ROOMTYPE}

var selected_room_type_id: int
var room_buttons: Dictionary = {}

func show_build_button() -> void:
	$BuildButton.visible = true

func hide_build_button() -> void:
	$BuildButton.visible = false

func show_room_panel(room_types: Array[RoomType]) -> void:
	for room_type in room_types:
		if room_type.name not in room_buttons:
			room_buttons[room_type.name] = room_type
			var button = Button.new()
			button.text = room_type.name
			button.pressed.connect(_on_room_selected.bind(room_type)) # Must "bind" to pass param to a connect callback
			$RoomPanel/HBoxContainer.add_child(button)
	$RoomPanel.visible = true

func hide_room_panel() -> void:
	$RoomPanel.visible = false

func show_popup() -> void:
	$PopupPanel.visible = true

func hide_popup() -> void:
	$PopupPanel.visible = false

func set_popup_text(text: String) -> void:
	$PopupPanel/Label.text = text
	
func connect_popup_yes(f: Callable) -> void:
	$PopupPanel/YesButton.pressed.connect(f)

func connect_popup_no(f: Callable) -> void:
	$PopupPanel/NoButton.pressed.connect(f)

func _on_build_button_pressed() -> void:
	action_completed.emit(Action.OPEN)

func _on_build_close_button_pressed() -> void:
	action_completed.emit(Action.CLOSE)

func _on_room_selected(room_type) -> void:
	selected_room_type_id = room_type.id
	action_completed.emit(Action.SELECT_ROOMTYPE)

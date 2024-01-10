# BuildMenu.gd

extends Control

signal action_pressed(action: int)

var build_mode = false
var selected_room_type_id: int

enum Action {STOP_BUILDING, START_BUILDING, SELECT_ROOM}

# Called when the node enters the scene tree for the first time
func _ready():
	var main_node = get_tree().root.get_node("Main")
	for room_type in main_node.room_types:
		var button = Button.new()
		button.text = room_type.name
		button.pressed.connect(_on_room_selected.bind(room_type)) # Must "bind" to pass param to a connect callback
		$RoomPanel/HBoxContainer.add_child(button)

func _on_build_button_pressed():
	action_pressed.emit(Action.START_BUILDING)

func _on_build_close_button_pressed():
	action_pressed.emit(Action.STOP_BUILDING)

func _on_room_selected(room_type):
	selected_room_type_id = room_type.id
	action_pressed.emit(Action.SELECT_ROOM)

# BuildMenu.gd

class_name BuildMenu

extends Control

signal action_pressed(action: int)

var selected_room_type_id: int

enum Action {STOP_BUILDING, START_BUILDING, SELECT_ROOM}

# Called when the node enters the scene tree for the first time
func _ready():
	var building_manager = get_tree().root.get_node("Main/BuildingManager")
	for room_type in building_manager.room_types:
		var button = Button.new()
		button.text = room_type.name
		button.pressed.connect(_on_room_selected.bind(room_type)) # Must "bind" to pass param to a connect callback
		$RoomPanel/HBoxContainer.add_child(button)

func show_build_button():
	$BuildButton.visible = true

func hide_build_button():
	$BuildButton.visible = false

func show_room_panel():
	$RoomPanel.visible = true

func hide_room_panel():
	$RoomPanel.visible = false

func show_popup():
	$PopupPanel.visible = true

func hide_popup():
	$PopupPanel.visible = false

func set_popup_text(text: String):
	$PopupPanel/Label.text = text
	
func connect_popup_yes(f: Callable):
	$PopupPanel/YesButton.pressed.connect(f)

func connect_popup_no(f: Callable):
	$PopupPanel/NoButton.pressed.connect(f)

func _on_build_button_pressed():
	action_pressed.emit(Action.START_BUILDING)

func _on_build_close_button_pressed():
	action_pressed.emit(Action.STOP_BUILDING)

func _on_room_selected(room_type):
	selected_room_type_id = room_type.id
	action_pressed.emit(Action.SELECT_ROOM)

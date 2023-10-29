# Build.gd

extends Control

var build_mode = false
var room_selected = false
var selected_room_type_id: int

# Called when the node enters the scene tree for the first time.
func _ready():
	var main_node = get_tree().root.get_node("Main")
	for room_type in main_node.room_types:
		var button = Button.new()
		button.text = room_type.name
		button.pressed.connect(_on_room_selected.bind(room_type)) # Must "bind" to pass param to a connect callback.
		button.mouse_entered.connect(_on_room_panel_mouse_entered)
		button.mouse_exited.connect(_on_room_panel_mouse_exited)
		$RoomPanel/HBoxContainer.add_child(button)

func _on_build_button_pressed():
	$RoomPanel.visible = true
	$BuildButton.visible = false

func _on_build_close_button_pressed():
	build_mode = false
	$RoomPanel.visible = false
	$BuildButton.visible = true
	
func _on_room_selected(room_type):
	room_selected = true
	print(room_type.name)
	selected_room_type_id = room_type.id
	
# Need way to clear initial tile when build_mode == false
func _on_room_panel_mouse_entered():
	build_mode = false

func _on_room_panel_mouse_exited():
	if room_selected == true:
		build_mode = true

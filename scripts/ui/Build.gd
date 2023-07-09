# Build.gd

extends Control

var build_mode = false
var room_selected = false

# Called when the node enters the scene tree for the first time.
func _ready():
	var main_node = get_tree().root.get_node("Main")
	for room in main_node.room_types:
		var button = Button.new()
		button.text = room.name
		button.pressed.connect(_on_room_selected)
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
	
func _on_room_selected():
	room_selected = true
	
# Need way to clear initial tile when build_mode == false
func _on_room_panel_mouse_entered():
	build_mode = false

func _on_room_panel_mouse_exited():
	if room_selected == true:
		build_mode = true

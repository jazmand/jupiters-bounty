# Build.gd

extends Control

var build_mode = false; # TODO: Tie to is_editing

# Called when the node enters the scene tree for the first time.
func _ready():
	var main_node = get_tree().root.get_node("Main")
	for room in main_node.room_types:
		var button = Button.new()
		button.text = room.name
		$RoomPanel/HBoxContainer.add_child(button)
		
func _on_build_button_pressed():
	build_mode = true
	$RoomPanel.visible = true
	$BuildButton.visible = false

func _on_build_close_button_pressed():
	build_mode = false
	$RoomPanel.visible = false
	$BuildButton.visible = true
	

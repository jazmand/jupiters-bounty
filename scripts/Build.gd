extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
	
func _on_build_button_pressed():
	$RoomPanel.visible = true
	$BuildButton.visible = false


func _on_build_close_button_pressed():
	$RoomPanel.visible = false
	$BuildButton.visible = true



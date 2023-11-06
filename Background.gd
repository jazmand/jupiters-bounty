extends ColorRect


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func rotate_jupiter(in_game_time, one_in_game_day) -> void:
	var degree_rotation = (float(in_game_time) / float(one_in_game_day)) * 360.0
	$Jupiter.rotation_degrees = degree_rotation
	var overlay_offset = sin(degree_rotation * PI / 4) - 1 # Gives overlay an oscillation of +/- 1 degree
	$Jupiter/JupiterOverlay.rotation_degrees = overlay_offset

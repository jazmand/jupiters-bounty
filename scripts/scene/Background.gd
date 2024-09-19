extends ColorRect

func _ready() -> void:
	GameTime.second.connect(rotate_jupiter)

func rotate_jupiter() -> void:
	var degree_rotation: float = (GameTime.current_time_in_seconds() / GameTime.SECONDS_PER_DAY) * 360.0
	$Jupiter.rotation_degrees = degree_rotation
	var overlay_offset = sin(degree_rotation * PI / 4) - 1 # Gives overlay an oscillation of +/- 1 degree
	$Jupiter/JupiterOverlay.rotation_degrees = overlay_offset

class_name Background extends ColorRect

const DAY_MODULATE: Color = Color(1.0, 1.0, 1.0)
const NIGHT_MODULATE: Color = Color(0.35, 0.35, 0.5)

func _ready() -> void:
	GameTime.second.connect(rotate_jupiter)
	GameTime.phase_changed.connect(_on_phase_changed)
	_apply_phase_visual()

func _on_phase_changed() -> void:
	_apply_phase_visual()

func _apply_phase_visual() -> void:
	var modulate_color: Color = NIGHT_MODULATE if GameTime.is_night() else DAY_MODULATE
	$Jupiter.modulate = modulate_color

func rotate_jupiter() -> void:
	var degree_rotation: float = (GameTime.current_time_in_seconds() / GameTime.SECONDS_PER_DAY) * 360.0
	$Jupiter.rotation_degrees = degree_rotation
	var overlay_offset = sin(degree_rotation * PI / 4) - 1 # Gives overlay an oscillation of +/- 1 degree
	$Jupiter/JupiterOverlay.rotation_degrees = overlay_offset

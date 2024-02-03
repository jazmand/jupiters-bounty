class_name PowerMeter
extends Sprite2D

@onready var dial: Sprite2D = $Dial
@onready var light: Sprite2D = $PowerMeterLightBurst

const ROTATION_LIMIT_DEG: int = 66

var delta_time: float
var dial_rotation_direction: int

func _ready() -> void:
	delta_time = 0
	dial_rotation_direction = 1

func _process(delta: float) -> void:
	delta_time += delta
	
	modulate_light()
	rotate_dial()
	
	# Update every 0.1 real-world seconds
	if delta_time >= 0.1:
		delta_time = 0

func modulate_light() -> void:
	light.modulate = Color(255, 255, 215, 0.8 - delta_time)

func rotate_dial() -> void:
	dial.rotation_degrees += delta_time * dial_rotation_direction
	
	# Check if the rotation has reached the limits, and change direction accordingly
	if dial.rotation_degrees >= ROTATION_LIMIT_DEG or dial.rotation_degrees <= -ROTATION_LIMIT_DEG:
		dial_rotation_direction *= -1

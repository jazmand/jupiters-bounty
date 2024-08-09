class_name PowerMeter
extends Sprite2D

@onready var power_label: Label = $Power
@onready var dial: Sprite2D = $Dial
@onready var light: Sprite2D = $PowerMeterLightBurst

const ROTATION_LIMIT_DEG: int = 66
const ROTATION_LIMIT_KW: float = 2500.0
const POWER_CHANGE_DURATION: float = 5.0

var target_power: int
var current_power: int
var elapsed_time: float = 0.0

func _ready() -> void:
	target_power = Global.station.power
	current_power = target_power
	set_power_label(current_power)
	Global.station.power_updated.connect(on_power_updated)

func _process(delta: float) -> void:
	update_power_reading(delta)
	modulate_light()
	rotate_dial()

func on_power_updated(new_power: int) -> void:
	target_power = new_power
	elapsed_time = 0.0

func update_power_reading(delta: float) -> void:
	if current_power != target_power:
		elapsed_time += delta 
		var transition_amount = clamp(elapsed_time / POWER_CHANGE_DURATION, 0.0, 1.0)
		
		current_power = round(lerp(current_power, target_power, transition_amount))
		set_power_label(current_power)
		
		if transition_amount >= 1.0:
			current_power = target_power

func set_power_label(power: int) -> void:
	power_label.text = format_number_with_spaces(power) + "  K  W"

func modulate_light() -> void:
	var brightness_ratio = clamp((current_power / ROTATION_LIMIT_KW), 0.0, 1.0)
	var eased_brightness = ease(brightness_ratio, 0.5) # 0.5 is the exponent for ease in/out
	 
	# Add a flicker effect
	var flicker = 0
	
	light.modulate = Color(1, 1, 1, eased_brightness + flicker)

func rotate_dial() -> void:
	var rotation_ratio = clamp((current_power / ROTATION_LIMIT_KW), 0.0, 1.0)
	var base_rotation = lerp(-ROTATION_LIMIT_DEG, ROTATION_LIMIT_DEG, rotation_ratio)
	
	# Add a slight oscillation effect
	var oscillation = 0
	
	dial.rotation_degrees = base_rotation + oscillation

func format_number_with_spaces(number: int) -> String:
	var num_string = str(number)
	var space_string = "   "
	var formatted_string = ""
	for i in range(num_string.length()):
		formatted_string += num_string[i]
		if i < num_string.length() - 1:
			formatted_string += space_string
	return formatted_string

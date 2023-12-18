# GUI.gd

extends Control

# Gets resources from Station.gd with initial values in station_resources.tres
@export var resources: Resource

var delta_time: float
var dial_rotation_direction: int

func _ready():
	delta_time = 0
	dial_rotation_direction = 1

	if resources:
		# Set values of GUI nodes with station resource values and update text 		
		update_resource("currency");
		update_resource("crew");
		update_resource("power");
		$HydrogenMeter/HydrogenMeterFluid.value = resources.hydrogen;
		# Animate hydrogen progress bar to initially start from 0
		animate_progress_bar($HydrogenMeter/HydrogenMeterFluid, 0, resources.hydrogen);


func _process(delta):
	delta_time += delta
	
	$PowerMeter/PowerMeterLightBurst.modulate = Color(255, 255, 215, 0.8 - delta_time)
	$PowerMeter/Dial.rotation_degrees += delta_time * dial_rotation_direction
	
	# Check if the rotation has reached the limits, and change direction accordingly
	if $PowerMeter/Dial.rotation_degrees >= 66 or $PowerMeter/Dial.rotation_degrees <= -66:
		dial_rotation_direction *= -1
	# Update every 0.1 real-world seconds
	if delta_time >= 0.1:
		delta_time = 0
		
# Animate progress bar to increase or decrease
func animate_progress_bar(progressBar, from, to) -> void:
	var tween = get_tree().create_tween();
	tween.tween_property(progressBar, "value", to, 2).set_trans(Tween.TRANS_LINEAR).from(from);
		
func update_clock(in_game_time) -> void:
	var hours = int(in_game_time / 3600)
	var minutes = int((in_game_time % 3600) / 60)
	$Clock/Time.text = str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2)

func show_popup(popup_type: String, popup_message: String, accept_function: Callable, decline_function: Callable) -> void:
#	if popup_type == "confirm_build":
		$BuildMenu/PopupPanel.visible = true
		$BuildMenu/PopupPanel/Label.text = popup_message
		# Connect the buttons to the confirmation functions in the GUI script
		$BuildMenu/PopupPanel/YesButton.pressed.connect(accept_function)
		$BuildMenu/PopupPanel/NoButton.pressed.connect(decline_function)
#	elif popup_type == "room_details":
#		$Build/PopupPanel.visible = true
#		$Build/PopupPanel/Label.text = popup_message
		# Show the room_details_popup
		# ... (handle the room_details_popup logic and connect signals as needed)
		
func update_resource(resource_to_update: String) -> void: 
	if resource_to_update == "currency":
		$CurrencyAndCrew/Currency.text = "Currency:" + str(resources.currency);
	if resource_to_update == "crew":
		$CurrencyAndCrew/Crew.text = "Crew:" + str(resources.crew)
	if resource_to_update == "power":
		pass
		#Must calculate/match how to set dial roation to power value
		#$PowerMeter/Dial.rotation_degrees = resources.power;
	if resource_to_update == "hydrogen":
		animate_progress_bar($HydrogenMeter/HydrogenMeterFluid, $HydrogenMeter/HydrogenMeterFluid.value, resources.hydrogen)
		$HydrogenMeter/HydrogenMeterFluid.value = resources.hydrogen;

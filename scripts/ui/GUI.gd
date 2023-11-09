# GUI.gd

extends Control

# Gets resources from Station.gd with initial values in station_resources.tres
@export var resources: Resource

func _ready():
	if resources:
		# Set values of GUI nodes with station resource values and update text 
		$HydrogenBar.value = resources.hydrogen;
		$HydrogenBar/Fraction.text = str(resources.hydrogen)+ "\n" + $HydrogenBar/Fraction.text + "\n" + str($HydrogenBar.max_value);
		
		$PowerBar.value = resources.power;
		$PowerBar/Percentage.text = str(resources.power) + $PowerBar/Percentage.text;
		
		$VBoxContainer/Currency.text += str(resources.currency);
		
		$VBoxContainer/Crew.text += str(resources.crew);
		
		# Add progress bars needing animation in array below
		animate_progress_bar([$HydrogenBar, $PowerBar]);
		
# Animate progress bars to start from 0 and stop at their current value
func animate_progress_bar(progressBarArr):
	for x in progressBarArr:	
		var tween = get_tree().create_tween();
		tween.tween_property(x, "value", x.value, 2).set_trans(Tween.TRANS_LINEAR).from(0);
		
func update_clock(in_game_time) -> void:
	var hours = int(in_game_time / 3600)
	var minutes = int((in_game_time % 3600) / 60)
	$Clock/Time.text = str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2)

func show_popup(popup_message):
	# TODO disable button click for rooms
	$Build/PopupPanel.visible = true
	$Build/PopupPanel/Label.text = popup_message

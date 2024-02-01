# Main.gd

extends Node

var gui: GUI
var background: Control

var elapsed_time: int # TODO: Save & load on init
var in_game_time: int
var one_in_game_day: int
var delta_time: float

func _ready():
	# Find UI elements
	gui = $CanvasLayer/GUI
	background = $Background
	
	delta_time = 0
	one_in_game_day = 36000 # 10 in game hours per in game day
	in_game_time = 7200 # Start at 02:00
		
	update_in_game_time()
	background.rotate_jupiter(in_game_time, one_in_game_day)

func _process(delta):
	delta_time += delta
	
	# Update every 0.25 real-world seconds
	if delta_time >= 0.25:
		delta_time = 0
		update_in_game_time()
		gui.update_clock(in_game_time)
		background.rotate_jupiter(in_game_time, one_in_game_day)

func update_in_game_time():
	in_game_time += 5 # Add 5 in game seconds every 0.25 real world seconds
		
	if in_game_time >= one_in_game_day:  # 10 hours * 3600 seconds/hour
		in_game_time = 5 # Reset

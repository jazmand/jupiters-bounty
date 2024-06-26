# Main.gd

extends Node

@onready var manager: GameManager = $GameManager
@onready var background: Control = $GameManager/Background

var in_game_time: int = 7200 # Start at 02:00
var one_in_game_hour: int = 3600 
var one_in_game_day: int = 36000 # 10 in game hours per in game day
var delta_time: float = 0.0

func _ready():
	update_in_game_time()
	background.rotate_jupiter(in_game_time, one_in_game_day)
	for i in range(1):
		manager.new_crew_member()

func _process(delta):
	delta_time += delta
	
	# Update every 0.25 real-world seconds
	if delta_time >= 0.25:
		delta_time = 0
		update_in_game_time()
		Global.station.update_power()
		Global.station.update_hydrogen()
		Global.station.time = in_game_time
		background.rotate_jupiter(in_game_time, one_in_game_day)

func update_in_game_time():
	in_game_time += 5 # Add 5 in game seconds every 0.25 real world seconds
	if in_game_time >= one_in_game_day:  # 10 hours * 3600 seconds/hour
		in_game_time = 5 # Reset

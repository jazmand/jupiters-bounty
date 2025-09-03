class_name CrewAI extends Node

@onready var timer: Timer = %DecisionTimer as Timer
@onready var agent: UtilityAIAgent = %Agent as UtilityAIAgent

func _ready() -> void:
	timer.timeout.connect(act)
	# Split AI decisions across crew to avoid simultaneous idle state
	timer.stop()
	timer.wait_time = randf_range(1.5, 2.5)
	timer.start(randf_range(0.0, timer.wait_time))

func act() -> void:
	var action = agent.determine_best_action()
	action.execute()

class_name CrewAI extends Node

@onready var timer: Timer = %DecisionTimer as Timer
@onready var agent: UtilityAIAgent = %Agent as UtilityAIAgent

func _ready() -> void:
	timer.timeout.connect(act)

func act() -> void:
	var action = agent.determine_best_action()
	action.execute()

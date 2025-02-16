class_name CrewAI extends UtilityAIAgent

@onready var timer = %DecisionTimer

func _ready() -> void:
	timer.timeout.connect(act)

func act() -> void:
	determine_best_action()
	current_action.execute()

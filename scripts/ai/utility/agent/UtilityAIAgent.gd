class_name UtilityAIAgent extends Node

@export var actions: Array[UtilityAIAction]

var current_action: UtilityAIAction

func determine_best_action() -> void:
	var best_score: float = 0.0
	var best_action_idx: int = 0
	
	for i in actions.size():
		print("action: ", actions[i].action_name)
		print("score: ", actions[i].calculate_score())
		var action_score: float = actions[i].calculate_score()
		if action_score > best_score:
			best_score = action_score
			best_action_idx = i
	
	current_action = actions[best_action_idx]


class_name UtilityAIAgent extends Node

var actions: Array[UtilityAIAction] = []

var current_action: UtilityAIAction

func _ready() -> void:
	for child: Node in get_children():
		if child is UtilityAIAction:
			actions.append(child)
		

func determine_best_action() -> UtilityAIAction:
	var best_score: float = 0.0
	var best_action_idx: int = 0
	
	for i in actions.size():
		var action_score: float = actions[i].calculate_score()
		if action_score > best_score:
			best_score = action_score
			best_action_idx = i
	
	current_action = actions[best_action_idx]
	return current_action

class_name UtilityAIAction extends Node

@export var action_name: StringName

@export var considerations: Array[UtilityAIConsideration]

var score: float = 0.0:
	set(s):
		score = clampf(s, 0.0, 1.0)

func calculate_score() -> float:
	var temp_score: float = 1.0
	
	for consideration: UtilityAIConsideration in considerations:
		temp_score *= consideration.calculate_score()
		
		if temp_score == 0.0:
			return temp_score
	
	# average total scores
	var mod_factor: float = 1 - (1 / len(considerations))
	var makeup_value: float = (1 - temp_score) * mod_factor
	score = temp_score + (makeup_value * temp_score)
	
	return score

# NOTE: Inheriting actions should override this function
func execute() -> void:
	pass

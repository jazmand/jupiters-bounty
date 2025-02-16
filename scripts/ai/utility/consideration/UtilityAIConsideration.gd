class_name UtilityAIConsideration extends Node

@export var consideration_name: StringName

var score: float = 0.0:
	set(s):
		score = clampf(s, 0.0, 1.0)

# NOTE: Inheriting actions should override this function
# and return a float between 0.0 and 1.0
func calculate_score() -> float:
	return score

class_name UtilityAIBooleanConsideration extends UtilityAIConsideration

@export var node: Node

@export var method: StringName

func calculate_score() -> float:
	return float(node.call(method))

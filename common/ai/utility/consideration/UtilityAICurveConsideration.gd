class_name UtilityAICurveConsideration extends UtilityAIConsideration

@export var curve: Curve

func calculate_score() -> float:
	return curve.sample_baked(score)

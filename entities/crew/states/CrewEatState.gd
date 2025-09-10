class_name CrewEatState extends CrewStateBase

## Handles crew eating behavior at food furniture
## TODO: Implement when adding appetite system and food furniture

func _ready() -> void:
	state_name = "eat"

func enter_state(previous_state: CrewStateBase = null, data: Dictionary = {}) -> void:
	"""Enter eating state"""
	super.enter_state(previous_state, data)
	# TODO: Start appetite recovery process
	# TODO: Set eating animation
	# TODO: Connect to food furniture
	# TODO: Start eating speech sounds ("*munch*", "*nom*")
	# TODO: Record eating start time

func process_state(delta: float) -> void:
	"""Process eating behavior"""
	# TODO: Handle appetite recovery
	# TODO: Process eating sound timing
	# TODO: Check if fully fed (transition back to previous state)
	# TODO: Handle furniture interaction
	pass

func physics_process_state(delta: float) -> void:
	"""Physics processing for eating"""
	# TODO: Maintain position at food furniture
	# TODO: Handle any eating animations
	pass

func can_transition_to(new_state: String) -> bool:
	"""Check valid transitions from eating"""
	# Can transition to other states when done eating or interrupted
	var valid_states = ["idle", "walk", "work"]
	return new_state in valid_states

func get_valid_transitions() -> Array[String]:
	"""Get valid transitions from eating state"""
	return ["idle", "walk", "work"]

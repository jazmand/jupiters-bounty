class_name CrewIdleState extends CrewStateBase

## Handles crew idle behavior - standing around, waiting for tasks
## TODO: Implement when migrating to state pattern

func _ready() -> void:
	state_name = "idle"

func enter_state(previous_state: CrewStateBase = null, data: Dictionary = {}) -> void:
	"""Enter idle state"""
	super.enter_state(previous_state, data)
	# TODO: Set animation to idle
	# TODO: Stop movement
	# TODO: Reset navigation target to current position
	# TODO: Clear assignment
	# TODO: Randomize idle duration

func process_state(delta: float) -> void:
	"""Process idle behavior"""
	# TODO: Update idle timer
	# TODO: Check if idle time limit reached
	# TODO: Transition to walking if idle time expires

func physics_process_state(delta: float) -> void:
	"""Physics processing for idle state"""
	# TODO: Handle any minor movement adjustments
	pass

func can_transition_to(new_state: String) -> bool:
	"""Check valid transitions from idle"""
	var valid_states = ["walk", "work", "rest"]
	return new_state in valid_states

func get_valid_transitions() -> Array[String]:
	"""Get valid transitions from idle state"""
	return ["walk", "work", "rest"]

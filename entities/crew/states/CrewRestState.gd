class_name CrewRestState extends CrewStateBase

## Handles crew resting/vigour recovery behavior
## TODO: Implement when migrating to state pattern

func _ready() -> void:
	state_name = "rest"

func enter_state(previous_state: CrewStateBase = null, data: Dictionary = {}) -> void:
	"""Enter resting state"""
	super.enter_state(previous_state, data)
	# TODO: Start vigour recovery process
	# TODO: Set resting animation and direction
	# TODO: Stop all movement
	# TODO: Start zzz speech sounds
	# TODO: Record rest start time

func process_state(delta: float) -> void:
	"""Process resting behavior"""
	# TODO: Handle vigour recovery
	# TODO: Process zzz sound timing
	# TODO: Check if fully recovered (transition back to walking)
	pass

func physics_process_state(delta: float) -> void:
	"""Physics processing for resting"""
	# TODO: Ensure no movement during rest
	# TODO: Maintain resting position
	pass

func can_transition_to(new_state: String) -> bool:
	"""Check valid transitions from resting"""
	# Can only transition to walking when fully recovered
	if new_state == "walk":
		return crew_vigour.get_vigour() >= crew_vigour.MAX_VIGOUR
	return false

func get_valid_transitions() -> Array[String]:
	"""Get valid transitions from resting state"""
	return ["walk"]  # Only back to walking when recovered

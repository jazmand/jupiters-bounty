class_name CrewStateBase extends Node

signal state_entered()
signal state_exited()
signal state_transition_requested(new_state: String, data: Dictionary)

# State identification
var state_name: String = ""

# Component references
var crew_member: Node
var crew_movement: CrewMovement
var crew_animation: CrewAnimation
var crew_vigour: CrewVigour
var crew_speech: CrewSpeech
var crew_appetite: CrewAppetite  # Future
var crew_contentment: CrewContentment  # Future

func _ready() -> void:
	# Will be set by state manager when implemented
	pass

func initialize(member: Node) -> void:
	"""Initialize state with crew member and component references"""
	crew_member = member
	# TODO: Get component references when implemented
	pass

# Virtual methods to be overridden by specific states
func enter_state(previous_state: CrewStateBase = null, data: Dictionary = {}) -> void:
	"""Called when entering this state"""
	state_entered.emit()

func exit_state(next_state: CrewStateBase = null) -> void:
	"""Called when exiting this state"""
	state_exited.emit()

func process_state(delta: float) -> void:
	"""Called every frame while in this state"""
	pass

func physics_process_state(delta: float) -> void:
	"""Called every physics frame while in this state"""
	pass

func handle_input(event: InputEvent) -> void:
	"""Handle input events while in this state"""
	pass

func can_transition_to(new_state: String) -> bool:
	"""Check if transition to new state is allowed"""
	return true

func get_valid_transitions() -> Array[String]:
	"""Get list of valid state transitions from this state"""
	return []

# Helper methods for common state operations
func request_transition(new_state: String, data: Dictionary = {}) -> void:
	"""Request transition to a new state"""
	if can_transition_to(new_state):
		state_transition_requested.emit(new_state, data)

func get_state_name() -> String:
	return state_name

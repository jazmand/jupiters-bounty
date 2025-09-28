class_name CrewAppetite extends Node

## Handles crew hunger/appetite system including eating behavior
## Manages appetite depletion over time and recovery through eating at furniture
## TODO: Implement when adding eating state and food furniture

signal appetite_changed(new_appetite: int)
signal hunger_started()  # When appetite hits 0
signal eating_started()
signal eating_finished()
signal hunger_level_changed(is_hungry: bool)

# Appetite constants (TODO: Define based on game balance)
const MAX_APPETITE: int = 10
const APPETITE_LOW_THRESHOLD: int = 2
const WORK_APPETITE_TICK_S: float = 4.0  # Time to lose 1 appetite while working
const EAT_APPETITE_TICK_S: float = 0.3   # Time to gain 1 appetite while eating
const HUNGER_INTERVAL: float = 5.0       # Interval between hunger complaints

# Current state
var current_appetite: int = MAX_APPETITE
var is_eating: bool = false
var eating_furniture: Furniture = null  # Reference to food furniture being used

# Internal timers
var appetite_work_accum: float = 0.0
var appetite_eat_accum: float = 0.0
var hunger_complaint_timer: float = 0.0

# Component references
var crew_member: Node
var crew_speech: CrewSpeech

func _ready() -> void:
	crew_member = get_parent() as CrewMember
	# crew_speech will be connected when implemented

func initialize(starting_appetite: int = MAX_APPETITE) -> void:
	current_appetite = starting_appetite
	appetite_changed.emit(current_appetite)

func process_working(delta: float) -> void:
	# TODO: Implement appetite loss during work
	pass

func process_eating(delta: float, furniture: Furniture) -> void:
	# TODO: Implement eating behavior and appetite recovery
	pass

func should_eat() -> bool:
	return current_appetite == 0

func is_hungry() -> bool:
	return current_appetite <= APPETITE_LOW_THRESHOLD

func can_eat_at_furniture(furniture: Furniture) -> bool:
	# TODO: Check if furniture provides food and has capacity
	return false

func start_eating_at_furniture(furniture: Furniture) -> void:
	# TODO: Implement eating state initiation
	pass

func stop_eating() -> void:
	# TODO: Implement eating state cleanup
	pass

# Private helper methods (TODO: Implement)
func _start_eating() -> void:
	pass

func _finish_eating() -> void:
	pass

func _increase_appetite(amount: int) -> void:
	pass

func _decrease_appetite(amount: int) -> void:
	pass

# Public getters
func get_appetite() -> int:
	return current_appetite

func get_eating_furniture() -> Furniture:
	return eating_furniture

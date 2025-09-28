class_name CrewContentment extends Node

## Handles crew happiness/satisfaction system based on work, environment, and conditions
## Manages contentment calculation from work suitability, salary, and surroundings
## TODO: Implement when adding contentment mechanics

signal contentment_changed(new_contentment: int)
signal mood_changed(mood_level: String)  # "happy", "neutral", "unhappy"
signal contentment_bonus_applied(bonus_type: String, amount: int)

# Contentment constants (TODO: Define based on game design)
const MAX_CONTENTMENT: int = 10
const MIN_CONTENTMENT: int = 0
const HAPPY_THRESHOLD: int = 7     # Above this = happy
const UNHAPPY_THRESHOLD: int = 3   # Below this = unhappy
const NEUTRAL_RANGE: Array = [3, 7] # Between these = neutral

# Contentment factors (TODO: Implement calculation system)
enum ContentmentFactor {
	WORK_SUITABILITY,    # How well job matches personality
	SALARY,              # Payment amount
	ROOM_QUALITY,        # Quality of assigned room/furniture
	SOCIAL_INTERACTION,  # Interaction with other crew
	WORK_ENVIRONMENT,    # Station conditions, lighting, etc.
	ACHIEVEMENT,         # Completing tasks, promotions
	PERSONAL_SPACE       # Privacy, personal items
}

# Current state
var current_contentment: int = 6  # Start neutral
var current_mood: String = "neutral"

# Contentment factors tracking
var work_suitability_bonus: int = 0
var salary_bonus: int = 0
var environment_bonus: int = 0
var social_bonus: int = 0

# Component references
var crew_member: Node
var crew_speech: CrewSpeech

func _ready() -> void:
	crew_member = get_parent() as CrewMember
	# crew_speech will be connected when implemented

func initialize(starting_contentment: int = 6) -> void:
	current_contentment = starting_contentment
	_update_mood()
	contentment_changed.emit(current_contentment)

func evaluate_work_assignment(room: Room, furniture: Furniture) -> void:
	# TODO: Check work assignment against personality traits
	# TODO: Calculate work suitability bonus/penalty
	pass

func evaluate_salary(amount: int) -> void:
	# TODO: Calculate satisfaction with payment
	pass

func evaluate_environment(room: Room) -> void:
	# TODO: Check room quality, furniture, lighting, etc.
	pass

func evaluate_social_interaction(interaction_type: String, other_crew: Node) -> void:
	# TODO: Handle crew interactions, teamwork, conflicts
	pass

func apply_contentment_modifier(factor: ContentmentFactor, amount: int, reason: String = "") -> void:
	# TODO: Implement modifier system
	pass

func get_work_performance_multiplier() -> float:
	# TODO: Return performance bonus/penalty based on mood
	match current_mood:
		"happy":
			return 1.2  # 20% bonus when happy
		"unhappy":
			return 0.8  # 20% penalty when unhappy
		_:
			return 1.0  # Normal performance when neutral

func get_contentment_speech_phrases() -> Array[String]:
	# TODO: Return contextual phrases based on mood
	match current_mood:
		"happy":
			return ["I love working here!", "This is great!", "Best job ever!"]
		"unhappy":
			return ["I hate this place.", "This is terrible.", "I want to quit."]
		_:
			return ["It's okay, I guess.", "Could be better.", "Not bad."]

func _update_mood() -> void:
	var old_mood = current_mood
	
	if current_contentment >= HAPPY_THRESHOLD:
		current_mood = "happy"
	elif current_contentment <= UNHAPPY_THRESHOLD:
		current_mood = "unhappy"
	else:
		current_mood = "neutral"
	
	if old_mood != current_mood:
		mood_changed.emit(current_mood)

func _recalculate_contentment() -> void:
	# TODO: Sum up all contentment factors and bonuses
	var total = 6  # Base contentment
	# total += work_suitability_bonus
	# total += salary_bonus
	# total += environment_bonus
	# total += social_bonus
	
	var old_contentment = current_contentment
	current_contentment = clamp(total, MIN_CONTENTMENT, MAX_CONTENTMENT)
	
	if old_contentment != current_contentment:
		_update_mood()
		contentment_changed.emit(current_contentment)

# Public getters
func get_contentment() -> int:
	return current_contentment

func get_mood() -> String:
	return current_mood

func is_happy() -> bool:
	return current_mood == "happy"

func is_unhappy() -> bool:
	return current_mood == "unhappy"

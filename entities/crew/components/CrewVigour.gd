class_name CrewVigour extends Node

## Handles crew energy/fatigue system including resting behavior
## Manages vigour depletion during movement and recovery during rest

signal vigour_changed(new_vigour: int)
signal resting_started()
signal resting_finished()
signal fatigue_level_changed(is_fatigued: bool)

# Vigour constants
const MAX_VIGOUR: int = 10
const VIGOUR_LOW_THRESHOLD: int = 2
## Real seconds of walking to lose 1 vigour point. Tuned so full→empty over ~one in-game day (10h) at default time scale.
@export var walk_vigour_tick_s: float = 180.0
const REST_VIGOUR_TICK_S: float = 0.4  # Time to gain 1 vigour while resting
const ZZZ_INTERVAL: float = 3.0  # Interval between zzz sounds

## At night: multiplier applied to walk depletion (e.g. 1.5 = lose vigour faster). Day uses 1.0.
@export var night_walk_depletion_multiplier: float = 1.5
## When working: multiplier applied to depletion (e.g. 1.5 = lose vigour faster while working).
@export var work_depletion_multiplier: float = 1.5
## Personality: industrious crew deplete vigour slower (e.g. 0.9 = 10% slower depletion).
@export var industrious_depletion_multiplier: float = 0.9
## At night: multiplier applied to rest recovery (e.g. 0.8 = recover vigour slower). Day uses 1.0.
@export var night_rest_recovery_multiplier: float = 0.8

# Current state
var current_vigour: int = MAX_VIGOUR
var is_resting: bool = false
var resting_direction: Vector2 = Vector2.ZERO

# Internal timers
var vigour_walk_accum: float = 0.0
var vigour_work_accum: float = 0.0
var vigour_rest_accum: float = 0.0
var zzz_timer: float = 0.0

# Component references
var crew_member: Node

func _ready() -> void:
	crew_member = get_parent()

func initialize(starting_vigour: int = MAX_VIGOUR) -> void:
	current_vigour = starting_vigour
	vigour_changed.emit(current_vigour)

func process_walking(delta: float) -> void:
	if is_resting:
		return
	var multiplier: float = _get_walk_depletion_multiplier()
	vigour_walk_accum += delta * multiplier
	if vigour_walk_accum >= walk_vigour_tick_s:
		vigour_walk_accum = 0.0
		_decrease_vigour(1)

func process_working(delta: float) -> void:
	if is_resting:
		return
	var multiplier: float = _get_work_depletion_multiplier()
	vigour_work_accum += delta * multiplier
	if vigour_work_accum >= walk_vigour_tick_s:
		vigour_work_accum = 0.0
		_decrease_vigour(1)

func process_resting(delta: float, current_animation_direction: Vector2, current_move_direction: Vector2) -> void:
	# Start resting if not already
	if not is_resting:
		_start_resting(current_animation_direction, current_move_direction)
	
	# Handle repeated zzz sounds
	zzz_timer += delta
	if zzz_timer >= ZZZ_INTERVAL:
		if crew_member and crew_member.crew_speech:
			crew_member.crew_speech.say("*zzz*", 1.5)
		zzz_timer = 0.0
	
	# Recover vigour
	var recovery_multiplier: float = _get_rest_recovery_multiplier()
	vigour_rest_accum += delta * recovery_multiplier
	if vigour_rest_accum >= REST_VIGOUR_TICK_S:
		vigour_rest_accum = 0.0
		_increase_vigour(1)
		
		# Check if fully recovered
		if current_vigour >= MAX_VIGOUR:
			_finish_resting()

func should_rest() -> bool:
	return current_vigour == 0

func is_fatigued() -> bool:
	return current_vigour <= VIGOUR_LOW_THRESHOLD

func get_fatigue_scale() -> float:
	if is_resting:
		return 0.0
	elif is_fatigued():
		return 0.5  # FATIGUE_SPEED_SCALE
	else:
		return 1.0

func _start_resting(current_animation_direction: Vector2, current_move_direction: Vector2) -> void:
	is_resting = true
	# Store the current direction when entering rest
	resting_direction = current_animation_direction if current_animation_direction != Vector2.ZERO else current_move_direction
	if resting_direction == Vector2.ZERO:
		resting_direction = Vector2(0, 1)  # Default to facing down
	
	# Use bridge method to call CrewMember's speech (safer migration)
	if crew_member and crew_member.crew_speech:
		crew_member.crew_speech.say("*zzz*", 1.5)
	zzz_timer = 0.0
	resting_started.emit()

func _finish_resting() -> void:
	is_resting = false
	resting_direction = Vector2.ZERO
	zzz_timer = 0.0
	resting_finished.emit()

func _increase_vigour(amount: int) -> void:
	var old_vigour = current_vigour
	current_vigour = min(MAX_VIGOUR, current_vigour + amount)
	if current_vigour != old_vigour:
		vigour_changed.emit(current_vigour)

func _decrease_vigour(amount: int) -> void:
	var old_vigour = current_vigour
	var was_fatigued = is_fatigued()
	
	current_vigour = max(0, current_vigour - amount)
	
	if current_vigour != old_vigour:
		vigour_changed.emit(current_vigour)
	
	# Check for fatigue state change
	var is_now_fatigued = is_fatigued()
	if was_fatigued != is_now_fatigued:
		fatigue_level_changed.emit(is_now_fatigued)

# Public getters
func get_vigour() -> int:
	return current_vigour

func get_resting_direction() -> Vector2:
	return resting_direction

func _get_walk_depletion_multiplier() -> float:
	var base: float = 1.0
	if GameTime.is_night():
		base = night_walk_depletion_multiplier
	var personality: float = _get_personality_depletion_multiplier()
	return base * personality

func _get_work_depletion_multiplier() -> float:
	var base: float = work_depletion_multiplier
	if GameTime.is_night():
		base *= night_walk_depletion_multiplier
	var personality: float = _get_personality_depletion_multiplier()
	return base * personality

func _get_personality_depletion_multiplier() -> float:
	if crew_member == null:
		return 1.0
	var data = crew_member.get("data")
	if data == null:
		return 1.0
	if data.get("is_industrious"):
		return industrious_depletion_multiplier
	return 1.0

func _get_rest_recovery_multiplier() -> float:
	if GameTime.is_night():
		return night_rest_recovery_multiplier
	return 1.0

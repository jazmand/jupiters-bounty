class_name CrewMovement extends Node

## Handles crew movement, navigation, and pathfinding
## Manages target setting, direction calculation, and physics movement

signal navigation_finished()
signal collision_detected(collision: KinematicCollision2D)
signal target_reached()

# Movement constants
const DIRECTIONS = {
	UP = Vector2(0, -1),
	UP_RIGHT = Vector2(1, -1),
	RIGHT = Vector2(1, 0),
	DOWN_RIGHT = Vector2(1, 1),
	DOWN = Vector2(0, 1),
	DOWN_LEFT = Vector2(-1, 1),
	LEFT = Vector2(-1, 0),
	UP_LEFT = Vector2(-1, -1)
}

# Movement state
var target: Vector2 = Vector2.ZERO
var current_move_direction: Vector2 = Vector2.ZERO
var current_animation_direction: Vector2 = Vector2.ZERO
var current_path_waypoint: Vector2 = Vector2.ZERO
var speed_multiplier: float = 1.0

# Walking behavior
var walk_segments_remaining: int = 0
@export var walk_segments_per_cycle_min: int = 1
@export var walk_segments_per_cycle_max: int = 3

# Component references
var crew_member: Node
var navigation_agent: NavigationAgent2D

func _ready() -> void:
	crew_member = get_parent() as CrewMember
	navigation_agent = crew_member.get_node("Navigation/NavigationAgent2D") as NavigationAgent2D

func initialize() -> void:
	# Randomise per-crew speed to avoid synchronisation
	speed_multiplier = randf_range(0.85, 1.15)

func set_movement_target(movement_target: Vector2) -> void:
	target = movement_target
	navigation_agent.target_position = movement_target

func process_movement(delta: float, base_speed: int, speed_scale: float) -> void:
	if navigation_agent.is_navigation_finished():
		navigation_finished.emit()
		return
	
	set_rounded_direction()
	var final_speed = base_speed * speed_multiplier * speed_scale
	var velocity = current_move_direction.normalized() * final_speed
	
	var collision = crew_member.move_and_collide(velocity)
	if collision:
		collision_detected.emit(collision)

func set_rounded_direction() -> void:
	var to_next = (navigation_agent.get_next_path_position() - crew_member.global_position)
	
	# Movement direction (quantized) remains responsive
	if to_next == Vector2.ZERO:
		current_move_direction = Vector2.ZERO
		return
		
	var move_quantized = snap_to_eight_directions(to_next)
	current_move_direction = move_quantized

	# Lock animation direction to the current path segment: only change
	# when the agent advances to a new next_path_position (i.e., a bend).
	var next_pos = navigation_agent.get_next_path_position()
	if current_animation_direction == Vector2.ZERO:
		current_animation_direction = move_quantized
		current_path_waypoint = next_pos
		return
		
	# If still on the same segment, keep current animation direction
	if current_path_waypoint.distance_to(next_pos) <= 0.1:
		return
		
	# Segment changed: update animation direction to new segment and reset hold
	current_animation_direction = move_quantized
	current_path_waypoint = next_pos

func snap_to_eight_directions(vec: Vector2) -> Vector2:
	if vec == Vector2.ZERO:
		return Vector2.ZERO
		
	var v = vec.normalized()
	var best_dir = DIRECTIONS.RIGHT
	var best_dot = -INF
	var dirs = [DIRECTIONS.RIGHT, DIRECTIONS.UP_RIGHT, DIRECTIONS.UP, DIRECTIONS.UP_LEFT, 
				DIRECTIONS.LEFT, DIRECTIONS.DOWN_LEFT, DIRECTIONS.DOWN, DIRECTIONS.DOWN_RIGHT]
	
	for d in dirs:
		var dot = v.dot(d.normalized())
		if dot > best_dot:
			best_dot = dot
			best_dir = d
	
	return best_dir

func randomise_target_position() -> void:
	"""Generate a random reachable target position"""
	const MIN_DISTANCE = 200.0
	var attempts = 0
	const MAX_ATTEMPTS = 10

	while attempts < MAX_ATTEMPTS:
		var new_target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))

		# Ensure target is far enough from current position
		if crew_member.position.distance_to(new_target) >= MIN_DISTANCE:
			set_movement_target(new_target)
			if navigation_agent.is_target_reachable():
				return
		attempts += 1

	# Fallback: if we can't find a good target, use any reachable one
	var fallback_target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
	set_movement_target(fallback_target)

func randomise_target_position_in_room() -> void:
	"""Generate random target within assigned room (TODO: implement)"""
	# TODO: get crew member assigned room
	# TODO: find hotspots in room
	# TODO: set target inside room
	pass

func setup_walk_cycle() -> void:
	"""Setup a new walking cycle with random segments"""
	walk_segments_remaining = randi_range(walk_segments_per_cycle_min, walk_segments_per_cycle_max)

func can_continue_walk_cycle() -> bool:
	"""Check if current walk cycle can continue"""
	return walk_segments_remaining > 1

func advance_walk_cycle() -> void:
	"""Advance to next segment in walk cycle"""
	walk_segments_remaining -= 1
	randomise_target_position()

func stop_movement() -> void:
	"""Stop all movement immediately"""
	current_move_direction = Vector2.ZERO
	navigation_agent.target_position = crew_member.position
	crew_member.velocity = Vector2.ZERO

# Public getters
func get_current_move_direction() -> Vector2:
	return current_move_direction

func get_current_animation_direction() -> Vector2:
	return current_animation_direction

func is_navigation_finished() -> bool:
	return navigation_agent.is_navigation_finished()

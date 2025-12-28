class_name CrewMember extends CharacterBody2D

signal state_transitioned(state: StringName)

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

const STATE = {
	IDLE = &"idle",
	WALK = &"walk",
	WORK = &"work",
	CHAT = &"chat",
	REST = &"rest"
}

# Explicit preloads for typed component references
const CrewMovement = preload("res://entities/crew/components/CrewMovement.gd")
const CrewAnimation = preload("res://entities/crew/components/CrewAnimation.gd")

# Collision layer constants - simplified to single layer
const COLLISION_LAYERS = {
	OBSTACLES = 1,  # Layer 1: All obstacles (walls, furniture)
	CREW = 2        # Layer 2: Crew members
}

@export var speed: int = 5

# TODO: temporary solution, will improve later
# @export_category("Working Hours")
@export var starts_work_hour: int = 2
@export var starts_work_minute: int = 10
@export var stops_work_hour: int = 2
@export var stops_work_minute: int = 25

@onready var state_manager = $CrewStateManager
@onready var navigation_agent: NavigationAgent2D = $Navigation/NavigationAgent2D
@onready var crew_movement: CrewMovement = $CrewMovement
@onready var navigation_timer: Timer = $Navigation/Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var crew_animation: CrewAnimation = $CrewAnimation
@onready var crew_speech: CrewSpeech = $CrewSpeech
@onready var crew_debug: CrewDebug = $CrewDebug
@onready var sprite_idle: Sprite2D = $AgathaIdle
@onready var sprite_walk: Sprite2D = $AgathaWalk
@onready var area: Area2D = $BodyArea
@onready var crew_vigour: CrewVigour = $CrewVigour

var data: CrewData

var target = Vector2(0, 0)
var current_move_direction = Vector2(0, 0)
var current_animation_direction = Vector2(0, 0)
var current_path_waypoint = Vector2(0, 0)

var state = STATE.IDLE:
	set(animation_state):
		state = animation_state
		state_transitioned.emit(state)
		if crew_animation:
			crew_animation.set_sprite_visibility(state)
		
var current_animation = state + "_down"

var idle_timer = 0.0
var idle_time_limit = 2.0
@export var idle_time_min: float = 0.8
@export var idle_time_max: float = 3.0

var speed_multiplier: float = 1.0
var is_hovered: bool = false
var hover_tween: Tween

@export var walk_segments_per_cycle_min: int = 1
@export var walk_segments_per_cycle_max: int = 3

var walk_segments_remaining: int = 0
var assignment: StringName = &""

# Collision avoidance variables
var _avoidance_offset: Vector2 = Vector2.ZERO
var _avoidance_timer: float = 0.0
const AVOIDANCE_DURATION: float = 0.5  # How long to maintain avoidance offset
const AVOIDANCE_DISTANCE: float = 32.0  # Distance to side-step

# Wall collision handling
var _wall_collision_timer: float = 0.0
var _wall_collision_count: int = 0
var _original_target: Vector2 = Vector2.ZERO
const WALL_COLLISION_PAUSE: float = 0.3  # Reduced from 1.0 to 0.3 seconds for faster redirection
const MAX_WALL_COLLISIONS: int = 1  # Reduced from 2 to 1 for more responsive redirection

# Performance optimization for pathfinding
var _pathfinding_cooldown: float = 0.0
const PATHFINDING_COOLDOWN: float = 0.1  # Reduced from 0.5 to 0.1 seconds for more responsive redirection
var _last_pathfinding_time: float = 0.0

# Throttling accumulators for expensive checks
var _path_validation_accum: float = 0.0
const PATH_VALIDATION_INTERVAL: float = 0.1
var _avoidance_check_accum: float = 0.0
const AVOIDANCE_CHECK_INTERVAL: float = 0.1

# Multi-waypoint pathfinding system
var _alternative_waypoints: Array[Vector2] = []
var _current_waypoint_index: int = 0
var _final_destination: Vector2 = Vector2.ZERO

# Vigour constants moved to CrewVigour component


var is_speaking: bool = false # legacy; handled by CrewSpeech

@export var debug_assignment_flow: bool = false

var workplace: Room
var furniture_workplace: Furniture  # Store reference to assigned furniture
var work_location: Vector2i

# Waypoint-based movement for multi-step navigation (e.g., via doors)
var pending_waypoints: Array[Vector2] = []
var _saved_path_max_distance: float = -1.0
var _saved_avoidance_enabled: bool = true
var _saved_postprocessing: int = -1
var _last_logged_next_path: Vector2 = Vector2.ZERO
var assignment_path: Array[Vector2] = []
var assignment_path_idx: int = 0
const ASSIGNMENT_WAYPOINT_EPS: float = 8.0

# Flow-field following
var _is_flow_following: bool = false
var _flow_furniture: Furniture = null
var _flow_timer: Timer = null
var _flow_wander_goal: Vector2i = Vector2i.ZERO
var _assignment_target_tile: Vector2i = Vector2i.ZERO
var _oscillation_count: int = 0
var _last_tile: Vector2i = Vector2i.ZERO
var _flow_step_target: Vector2i = Vector2i.ZERO
var _tile_history: Array[Vector2i] = []  # Track last few tiles for oscillation detection
const TILE_HISTORY_SIZE: int = 4
var _oscillation_cooldown: float = 0.0  # Cooldown timer after detecting oscillation
const OSCILLATION_COOLDOWN_DURATION: float = 1.0  # Pause flow for 1.0s after oscillation

# Debug overlay for assignment beacon and flow field
var _debug_canvas: Node2D = null
var _debug_draw_node: Node2D = null
var _debug_flow_field = null

# Hybrid flow system state tracking
var _last_crew_tile: Vector2i = Vector2i.ZERO
var _last_navigation_target: Vector2 = Vector2.ZERO
var _assignment_retargeting_enabled: bool = true

# Flow-field services
const FlowFieldServiceScript = preload("res://scripts/utilities/FlowFieldManager.gd")
const NavGridProviderScript = preload("res://scripts/utilities/NavGridProvider.gd")
const FlowTargetsScript = preload("res://scripts/utilities/FlowTargets.gd")
var _flow_service: FlowFieldService = null
var _nav_grid = NavGridProviderScript.new()
var _flow_targets = FlowTargetsScript.new()
var _cached_field = null
var _cached_field_goal: Vector2i = Vector2i.ZERO
var _cached_field_room_id: int = -1
var _cached_field_version: int = -1  # nav ^ furniture version
var _cached_nav_version: int = -1
var _cached_furn_version: int = -1
var _cached_room_id_for_tile: Dictionary = {} # tile -> room_id
var _cached_seeds_key: String = ""
const ASSIGN_DEBUG := false  # Set true to enable assignment debug logs

func _is_on_assignment() -> bool:
	return assignment == &"work" or furniture_workplace != null or not pending_waypoints.is_empty()

func has_pending_assignment_path() -> bool:
	return not pending_waypoints.is_empty()

# Vigour variables moved to CrewVigour component

# Walk timing (keep for now, may move to CrewMovement later)
var walk_start_time: float = 0.0
const MIN_WALK_TIME: float = 1.0  # Minimum 1 second of walking
const ASSIGNMENT_GIVE_UP_LINES: Array[String] = [
	"This joint’s tighter than a drum.",
	"I’m stumped, see? Can’t get there."
]

func _ready() -> void:
	data = CrewData.new()
	navigation_timer.timeout.connect(_on_timer_timeout)
	call_deferred("actor_setup")
	area.input_event.connect(_on_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	
	# Initialize CrewVigour component
	crew_vigour.initialize(data.vigour)
	crew_vigour.vigour_changed.connect(_on_vigour_changed)
	crew_vigour.resting_started.connect(_on_resting_started)
	crew_vigour.resting_finished.connect(_on_resting_finished)
	crew_vigour.fatigue_level_changed.connect(_on_fatigue_level_changed)
	
	# Randomise per-crew speed and initial idle phase to avoid synchronisation
	speed_multiplier = randf_range(0.85, 1.15)
	idle_time_limit = randf_range(idle_time_min, idle_time_max)
	idle_timer = randf_range(0.0, idle_time_limit)
	# Jitter the navigation timer start to spread work across framesß
	navigation_timer.stop()
	navigation_timer.start(randf_range(0.0, navigation_timer.wait_time))
	if crew_speech:
		crew_speech.initialize()
	# Use shared flow service if available
	if Global and Global.flow_service:
		_flow_service = Global.flow_service
	else:
		_flow_service = FlowFieldServiceScript.new()
	
func actor_setup():
	await get_tree().physics_frame
	set_movement_target(target)
	# Relax path tolerances and enable smoothing to avoid boundary jitter
	navigation_agent.target_desired_distance = 10.0
	navigation_agent.path_desired_distance = 10.0
	navigation_agent.path_postprocessing = 1  # string pulling
	navigation_agent.avoidance_enabled = true
	if crew_movement:
		crew_movement.initialize()
	navigation_agent.debug_enabled = ASSIGN_DEBUG

func _on_input_event(viewport, event, _shape_idx):
	if event.is_action_pressed("select"):
		viewport.set_input_as_handled()
		select()

func _on_mouse_entered():
	is_hovered = true
	_update_visual_state()
	Global.is_crew_input = true

func _on_mouse_exited():
	is_hovered = false
	_update_visual_state()
	Global.is_crew_input = false

func select() -> void:
	Global.crew_selected.emit(self)

func _update_visual_state():
	# Create smooth fade transition for hover effect
	if hover_tween:
		hover_tween.kill()
	
	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_CUBIC)
	
	var target_color: Color
	if is_hovered:
		target_color = Global.COLOR_HOVER_HIGHLIGHT
	else:
		target_color = Color.WHITE  # Normal color when not hovered
	
	hover_tween.tween_property(self, "modulate", target_color, 0.2)

func set_movement_target(movement_target: Vector2) -> void:
	# Store the original target for repathing if needed
	_original_target = movement_target
	_final_destination = movement_target
	_wall_collision_count = 0
	_wall_collision_timer = 0.0
	_alternative_waypoints.clear()
	_current_waypoint_index = 0
	
	if crew_movement:
		crew_movement.set_movement_target(movement_target)
	else:
		navigation_agent.target_position = movement_target

func find_alternative_route(blocked_target: Vector2) -> Vector2:
	"""Find an alternative route around obstacles using multiple ray directions"""
	var directions: Array[Vector2] = [
		Vector2(1, 0),   # Right
		Vector2(-1, 0),  # Left
		Vector2(0, 1),   # Down
		Vector2(0, -1),  # Up
		Vector2(1, 1),   # Down-right
		Vector2(-1, 1),  # Down-left
		Vector2(1, -1),  # Up-right
		Vector2(-1, -1)  # Up-left
	]
	
	var distance: float = global_position.distance_to(blocked_target)
	var step_size: float = 200.0  # Increased from 128 to step back further
	var max_steps = 3  # Limit search to avoid performance issues
	
	# Try different directions at increasing distances
	for direction in directions:
		for i in range(1, min(max_steps, int(distance / step_size) + 1)):
			var test_target: Vector2 = global_position + direction * (step_size * i)
			if check_path_for_static_obstacles(test_target):
				return test_target
	
	return Vector2.ZERO

func validate_current_path() -> void:
	"""Continuously validate the current navigation path against physics obstacles"""
	# While on an assignment, let the assignment flow loop drive retargeting entirely
	if _is_on_assignment():
		return
	if navigation_agent.is_navigation_finished():
		return
		
	var current_path = navigation_agent.get_current_navigation_path()
	if current_path.size() < 2:
		return
		
	# Check the next few path points for obstacles
	var next_target = navigation_agent.get_next_path_position()
	
	# If the next target is blocked, find an alternative
	if not check_path_for_static_obstacles(next_target):
		# Use the new smart pathfinding system
		var alternative: Vector2 = _find_smart_alternative_route(_final_destination)
		if alternative != Vector2.ZERO:
			# Set up waypoint system: intermediate point -> final destination
			_alternative_waypoints.clear()
			_alternative_waypoints.append(alternative)
			_alternative_waypoints.append(_final_destination)
			_current_waypoint_index = 0
			navigation_agent.target_position = alternative
		else:
			# Try to find a route around the obstacle
			var around_obstacle: Vector2 = find_route_around_obstacle(global_position, next_target)
			if around_obstacle != Vector2.ZERO:
				navigation_agent.target_position = around_obstacle

func find_route_around_obstacle(start: Vector2, blocked_end: Vector2) -> Vector2:
	"""Find a route that goes around an obstacle"""
	var direction_to_target = (blocked_end - start).normalized()
	var perpendicular = Vector2(-direction_to_target.y, direction_to_target.x)
	
	# Try both sides of the obstacle
	for side in [-1, 1]:
		var around_point = start + perpendicular * side * 400.0  # Increased from 256 to step back further
		if check_path_for_static_obstacles(around_point):
			return around_point
	
	return Vector2.ZERO

func _force_navigation_rebake() -> void:
	# Force rebake the navigation mesh
	var nav_region = get_tree().get_first_node_in_group("navigation")
	if nav_region and nav_region.has_method("bake_navigation_polygon"):
		nav_region.bake_navigation_polygon()

func set_rounded_direction() -> void:
	var next_point: Vector2
	# Always just follow the NavigationAgent path (assignment uses the same wander flow loop)
	next_point = navigation_agent.get_next_path_position()
	if next_point == Vector2.ZERO:
		next_point = global_position

	var to_next = (next_point - global_position)
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
	var normalized_vec = vec.normalized()
	var best_direction = DIRECTIONS.RIGHT
	var best_dot_product = -INF
	var directions: Array[Vector2] = [DIRECTIONS.RIGHT, DIRECTIONS.UP_RIGHT, DIRECTIONS.UP, DIRECTIONS.UP_LEFT, DIRECTIONS.LEFT, DIRECTIONS.DOWN_LEFT, DIRECTIONS.DOWN, DIRECTIONS.DOWN_RIGHT]
	for direction in directions:
		var dot_product = normalized_vec.dot(direction.normalized())
		if dot_product > best_dot_product:
			best_dot_product = dot_product
			best_direction = direction
	return best_direction

func set_current_animation() -> void:
	if not crew_animation:
		return
	var dir_for_anim: Vector2 = current_animation_direction
	if dir_for_anim == Vector2.ZERO:
		dir_for_anim = current_move_direction
	if dir_for_anim == Vector2.ZERO:
		dir_for_anim = DIRECTIONS.DOWN
	if crew_vigour.is_resting:
		var rest_dir: Vector2 = crew_vigour.get_resting_direction()
		if rest_dir == Vector2.ZERO:
			rest_dir = DIRECTIONS.DOWN
		crew_animation.update_animation(STATE.REST, rest_dir, true, rest_dir)
	else:
		crew_animation.update_animation(state, dir_for_anim, false)
	current_animation = crew_animation.get_current_animation()

func _update_animation_speed() -> void:
	if crew_animation:
		crew_animation.set_animation_speed(crew_vigour.get_fatigue_scale())

func randomise_target_position() -> void:
	const MIN_DISTANCE = 200.0  # Minimum distance from current position
	var attempts = 0
	const MAX_ATTEMPTS = 10

	while attempts < MAX_ATTEMPTS:
		target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))

		# Ensure target is far enough from current position
		if position.distance_to(target) >= MIN_DISTANCE:
			set_movement_target(target)
			if navigation_agent.is_target_reachable():
				return
		attempts += 1

	# Fallback: if we can't find a good target, use any reachable one
	target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
	set_movement_target(target)

func randomise_target_position_in_room() -> void:
	# get crew member assigned room
	# find hotspots in room
	# set target inside room
	pass

func _on_timer_timeout() -> void:
	set_current_animation()
	_update_animation_speed()
	if crew_animation:
		crew_animation.play_current_animation()
		# If resting, pause the animation to prevent walking in place
		if crew_vigour.is_resting:
			crew_animation.pause_animation()

func say(text: String, duration: float = 2.5) -> void:
	if crew_speech:
		crew_speech.say(text, duration)

func _setup_assignment_debug_canvas() -> void:
	if crew_debug:
		crew_debug.set_assignment_target(_assignment_target_tile)
		crew_debug.set_debug_field(_debug_flow_field)

func _teardown_assignment_debug_canvas() -> void:
	if crew_debug:
		crew_debug.teardown()


func _on_idling_state_entered() -> void:
	state = STATE.IDLE
	# Do not clear target or assignment while on an active assignment path
	if not _is_on_assignment():
		navigation_agent.target_position = position
		assignment = &""
		state_manager.set_expression_property(&"assignment", assignment)
		# Randomise idle duration each cycle
		idle_time_limit = randf_range(idle_time_min, idle_time_max)
		idle_timer = 0.0
		current_animation_direction = Vector2.ZERO

func _on_idling_state_physics_processing(_delta: float) -> void:
	# Update z_index based on Y position for proper depth sorting
	_update_depth_sorting()
	
	# GUARD: If assigned to work, force transition/stay in work state
	if assignment == &"work":
		_transition_to_work()
		return
	
	idle_timer += _delta
	if idle_timer >= idle_time_limit:
		state_manager.send_event(&"walk")
		idle_timer = 0.0
		# Start/refresh flow wandering instead of random direct target
		_start_flow_wander()

func _on_walking_state_entered() -> void:
	# Don't override state if resting
	if not crew_vigour.is_resting:
		state = STATE.WALK
	walk_start_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	# If walking freely, start/continue flow-field wandering
	# Don't restart if already working (prevents oscillation)
	if not _is_on_assignment() and assignment != &"work":
		_start_flow_wander()

func _on_walking_state_physics_processing(_delta: float) -> void:
	# Update z_index based on Y position for proper depth sorting
	_update_depth_sorting()
	
	# GUARD: If assigned to work and not flow following (random movement), stop and transition
	# This catches cases where the crew finished a path but the state machine didn't catch up
	if assignment == &"work" and not _is_flow_following:
		_transition_to_work()
		return
	
	# Handle wall collision pause
	if _wall_collision_timer > 0:
		_wall_collision_timer -= _delta
		# Stop movement and animation during pause
		velocity = Vector2.ZERO
		current_move_direction = Vector2.ZERO
		current_animation_direction = Vector2.ZERO
		return
	
	# Handle resting when vigour is 0 or already resting
	if crew_vigour.should_rest() or crew_vigour.is_resting:
		crew_vigour.process_resting(_delta, current_animation_direction, current_move_direction)
		# Stop all movement during rest
		velocity = Vector2.ZERO
		# Do not clear the agent target; keep target so path is preserved after rest
		current_move_direction = Vector2.ZERO
		current_animation_direction = crew_vigour.get_resting_direction()
		return
	
	# Handle navigation completion only when not flow-following
	if not _is_flow_following:
		var reached_leg := false
		if _is_on_assignment() and assignment_path.size() > 0:
			var leg_goal: Vector2 = assignment_path[assignment_path.size() - 1]
			reached_leg = global_position.distance_to(leg_goal) <= ASSIGNMENT_WAYPOINT_EPS
		else:
			reached_leg = navigation_agent.is_navigation_finished()
		if reached_leg:
			# Continue along any pending waypoints before completing assignment
			if not pending_waypoints.is_empty():
				var next_target: Vector2 = pending_waypoints.pop_front()
				set_movement_target(next_target)
				# Freeze the next leg's path as well
				await get_tree().physics_frame
				_snapshot_agent_path()
				return
			
			# Handle alternative waypoints for obstacle avoidance
			if not _alternative_waypoints.is_empty() and _current_waypoint_index < _alternative_waypoints.size():
				var next_waypoint: Vector2 = _alternative_waypoints[_current_waypoint_index]
				_current_waypoint_index += 1
				navigation_agent.target_position = next_waypoint
				return
			# If walking freely (not heading to work), optionally chain additional targets
			if assignment == &"" and walk_segments_remaining > 1:
				walk_segments_remaining -= 1
				randomise_target_position()
				return
			else:
				# Restore path limit if we had overridden it for an assignment
				if _saved_path_max_distance >= 0.0:
					navigation_agent.path_max_distance = _saved_path_max_distance
					_saved_path_max_distance = -1.0
					# TEST: restore avoidance and postprocessing
					navigation_agent.avoidance_enabled = _saved_avoidance_enabled
					navigation_agent.path_postprocessing = _saved_postprocessing
				# Arrived at navigation target
				# For assignments: flow timer handles beacon arrival, don't transition here
				# For free walking: transition to idle
				if furniture_workplace != null and _assignment_target_tile != Vector2i.ZERO:
					# Only finish if actually close to the beacon; otherwise keep walking toward it.
					var goal_world := _nav_grid.tile_center_world(_assignment_target_tile)
					if global_position.distance_to(goal_world) <= 32.0:
						_transition_to_work()
						return
					# Too far: re-issue target to continue walking
					navigation_agent.target_position = goal_world
					state_manager.send_event(&"walk")
					return
				if furniture_workplace == null:
					state_manager.send_event(&"to_assignment")
				return

	# When following a flow field, use direct movement to the next flow tile
	# instead of NavigationAgent2D pathfinding (which may conflict with flow directions)
	if _is_flow_following and _flow_step_target != Vector2i.ZERO:
		# Check for oscillation cooldown - pause movement if cooling down
		if _oscillation_cooldown > 0.0:
			_oscillation_cooldown -= _delta
			velocity = Vector2.ZERO
			current_move_direction = Vector2.ZERO
			return
		
		# Check if we've arrived at the assignment target tile every frame for immediate response
		if _assignment_target_tile != Vector2i.ZERO and _flow_wander_goal == _assignment_target_tile:
			var current_tile := _nav_grid.world_to_tile(global_position)
			# Check exact tile match
			if current_tile == _assignment_target_tile:
				# Arrived at exact beacon tile - transition to work immediately
				velocity = Vector2.ZERO
				current_move_direction = Vector2.ZERO
				_transition_to_work()
				return
			# Also check distance-based arrival (within half tile)
			var target_world := _nav_grid.tile_center_world(_assignment_target_tile)
			if global_position.distance_to(target_world) <= 48.0:  # Within half a tile
				# Close enough - snap to target center and transition to work
				global_position = target_world
				velocity = Vector2.ZERO
				current_move_direction = Vector2.ZERO
				_transition_to_work()
				return
		
		# Continue moving toward next flow tile
		var target_world := _nav_grid.tile_center_world(_flow_step_target)
		var to_target := target_world - global_position
		var dist_to_next := to_target.length()
		
		if dist_to_next > 4.0:  # Only update direction if not already at target
			current_move_direction = snap_to_eight_directions(to_target)
			current_animation_direction = current_move_direction
			# Track tile changes
			var current_tile := _nav_grid.world_to_tile(global_position)
			if _last_tile != current_tile:
				_last_tile = current_tile
				_oscillation_count = 0  # Reset oscillation counter on successful tile change
				
				# Track tile history for oscillation detection
				_tile_history.append(current_tile)
				if _tile_history.size() > TILE_HISTORY_SIZE:
					_tile_history.pop_front()
				
				# Detect oscillation between 2 tiles
				if _tile_history.size() >= TILE_HISTORY_SIZE:
					var is_oscillating := false
					# Check if alternating between two tiles (A-B-A-B pattern)
					if (_tile_history[0] == _tile_history[2] and 
						_tile_history[1] == _tile_history[3] and 
						_tile_history[0] != _tile_history[1]):
						is_oscillating = true
					
					if is_oscillating:
						# Active corner-avoidance: force a perpendicular move to break oscillation
						var tile_a := _tile_history[0]
						var tile_b := _tile_history[1]
						
						# Calculate perpendicular directions to the oscillation axis
						var dir_between := tile_b - tile_a
						var perpendicular := Vector2i(-dir_between.y, dir_between.x)
						
						# Try both perpendicular directions to find a walkable path around the corner
						var avoid_tile := Vector2i.ZERO
						if _is_viable_transition(current_tile, current_tile + perpendicular):
							avoid_tile = current_tile + perpendicular
						elif _is_viable_transition(current_tile, current_tile - perpendicular):
							avoid_tile = current_tile - perpendicular
						
						if avoid_tile != Vector2i.ZERO:
							# Force movement away from corner to break oscillation
							print("[AssignFlow][oscillation] Breaking corner oscillation at ", current_tile, " - forcing recalculation")
							# Snap to current tile center to break momentum
							var curr_tile_center := _nav_grid.tile_center_world(current_tile)
							global_position = curr_tile_center
							velocity = Vector2.ZERO
							current_move_direction = Vector2.ZERO
							# Clear flow step target to bypass strict centering and force recalculation
							_flow_step_target = Vector2i.ZERO
							_tile_history.clear()
							_oscillation_count = 0
							# Immediately regenerate flow field from current position
							# This will create a fresh flow field with tie-breaking applied
							if is_instance_valid(_flow_timer):
								_flow_timer.stop()
								_on_flow_timer_timeout()  # Call directly for immediate regeneration
							# Continue movement - new flow field will guide us forward
							return
						
						# Fallback: if no perpendicular move available, pause as before
						print("[AssignFlow][oscillation] Detected between ", tile_a, " and ", tile_b, " - pausing (no avoidance path found)")
						var curr_tile_center := _nav_grid.tile_center_world(current_tile)
						global_position = curr_tile_center
						velocity = Vector2.ZERO
						current_move_direction = Vector2.ZERO
						_tile_history.clear()
						_oscillation_count = 0
						_oscillation_cooldown = OSCILLATION_COOLDOWN_DURATION
						# Also pause the flow timer to prevent immediate recalculation
						if is_instance_valid(_flow_timer):
							_flow_timer.stop()
							_flow_timer.start()  # Restart with full interval
						# Return early to skip this frame's movement
						return
		else:
			current_move_direction = Vector2.ZERO
			# We reached the flow step center. Force immediate update to pick next tile.
			if is_instance_valid(_flow_timer):
				_on_flow_timer_timeout()
	else:
		set_rounded_direction()
	
	# Validate current path at a limited rate to reduce raycasts (only for non-flow movement)
	if not _is_flow_following:
		_path_validation_accum += _delta
		if _path_validation_accum >= PATH_VALIDATION_INTERVAL:
			validate_current_path()
			_path_validation_accum = 0.0
	
	# Update collision avoidance
	update_avoidance(_delta)
	
	# Apply avoidance offset to movement direction
	if _avoidance_offset != Vector2.ZERO:
		current_move_direction += _avoidance_offset.normalized() * 0.3  # Blend avoidance with normal movement
	
	# Get speed scale from CrewVigour component (handles fatigue)
	var fatigue_scale = crew_vigour.get_fatigue_scale()
	var current_speed_scale: float = speed_multiplier * fatigue_scale
	
	# Calculate desired velocity
	var desired_velocity := current_move_direction.normalized() * (speed * current_speed_scale)
	# Update facing from velocity if moving meaningfully (guards against jitter when near-stop)
	if desired_velocity.length() > 0.1:
		var proposed_facing := snap_to_eight_directions(desired_velocity)
		if current_animation_direction == Vector2.ZERO or proposed_facing.dot(current_animation_direction) < 0.995:
			current_animation_direction = proposed_facing
	
	# When flow following, clamp velocity to prevent overshooting the target tile
	if _is_flow_following and _flow_step_target != Vector2i.ZERO:
		var target_pos := _nav_grid.tile_center_world(_flow_step_target)
		var distance_to_target := global_position.distance_to(target_pos)
		# If we're close to target, limit speed to prevent overshooting
		if distance_to_target < 64.0:  # Within 1 tile
			# Apply progressive slowdown as we approach the target
			var slowdown_factor: float = clamp(distance_to_target / 64.0, 0.3, 1.0)
			var max_speed: float = (distance_to_target / get_physics_process_delta_time()) * slowdown_factor
			if desired_velocity.length() > max_speed:
				desired_velocity = desired_velocity.normalized() * max_speed
	
	velocity = desired_velocity
	
	
	
	var collision = move_and_collide(velocity)
	if collision:
		_handle_wall_collision(collision)
		if crew_speech:
			crew_speech.say_collision_phrase(collision.get_collider())

	# Oscillation detection: only for non-flow movement (flow movement handles it above)
	if _is_on_assignment() and not _is_flow_following:
		var np := navigation_agent.get_next_path_position()
		var current_tile := _nav_grid.world_to_tile(global_position)
		if current_tile == _last_tile:
			_oscillation_count += 1
		else:
			_oscillation_count = 0
			_last_tile = current_tile
		if _oscillation_count >= 6:
			# Force a side-step to break oscillation
			var step := _choose_side_step(current_tile, _nav_grid.world_to_tile(np))
			if step != Vector2i.ZERO:
				var w := _nav_grid.tile_center_world(step)
				navigation_agent.target_position = w
				_oscillation_count = 0

func _snapshot_agent_path() -> void:
	# Capture current computed path from the agent for this assignment leg
	assignment_path.clear()
	assignment_path_idx = 0
	var path := navigation_agent.get_current_navigation_path()
	for p in path:
		assignment_path.append(p)
	# Skip any initial points that are essentially our current position
	while assignment_path.size() > 1 and assignment_path_idx < assignment_path.size() - 1:
		if global_position.distance_to(assignment_path[assignment_path_idx]) <= ASSIGNMENT_WAYPOINT_EPS:
			assignment_path_idx += 1
		else:
			break

func _on_working_state_entered() -> void:
	# Honor furniture-defined use state when present (e.g., rest/sleep vs work)
	var desired_state := assignment if assignment != &"" else STATE.WORK
	state = desired_state
	# Stop all movement when entering working state
	velocity = Vector2.ZERO
	current_move_direction = Vector2.ZERO
	navigation_agent.target_position = global_position

func _on_working_state_physics_processing(_delta: float) -> void:
	# Update z_index for depth sorting
	_update_depth_sorting()
	
	# FORCE STOP: Ensure velocity is zero every frame
	velocity = Vector2.ZERO
	current_move_direction = Vector2.ZERO
	
	# Ensure flow following is stopped (defensive check)
	if _is_flow_following:
		_stop_flow_follow()
	
	# If assigned to furniture, stay in place at the beacon
	if furniture_workplace != null:
		# Ensure crew stays stationary at furniture
		current_animation_direction = Vector2.ZERO  # Preserve animation direction
		navigation_agent.target_position = global_position
		return
	
	# If not assigned to furniture, can do room work (future implementation)
	# For now, stay in place
	velocity = Vector2.ZERO
	current_move_direction = Vector2.ZERO

# Old resting functions removed - functionality moved to CrewVigour component

# _handle_resting function moved to CrewVigour component

func _on_working_state_exited() -> void:
	pass

func can_assign() -> bool:
	return Global.station.rooms.size() > 0

# DEPRECATED: This method is no longer used. Use assign_to_furniture_via_flow() instead.
# TODO: Delete this method after confirming flow-based assignment works correctly.
func assign(room: Room, center: Vector2) -> void:
	workplace = room
	work_location = center
	state_manager.send_event(&"assigned")

func assign_to_furniture_via_flow(furniture: Furniture) -> void:
	if furniture == null:
		return
	
	# Store furniture reference
	furniture_workplace = furniture
	
	# Reserve an exact access tile at the furniture (unique per crew)
	var flow_targets := FlowTargetsScript.new()
	var candidates: Array[Vector2i] = flow_targets.furniture_access_tiles(furniture)
	# Fallback 1: adjacent walkable tiles handled inside furniture reservation when candidates empty
	# Fallback 2: door tiles handled inside furniture reservation when still empty
	var reserved: Vector2i = furniture.reserve_access_tile_for_crew(self, candidates)
	_assignment_target_tile = reserved if reserved != Vector2i.ZERO else Vector2i.ZERO
	if _assignment_target_tile != Vector2i.ZERO:
		# Set flow goal immediately for clarity
		_flow_wander_goal = _assignment_target_tile
		# Debug log reservation
		var r: Room = furniture.get_parent() if (furniture.get_parent() is Room) else null
		var rid: int = r.data.id if (r and r.data) else -1
		if ASSIGN_DEBUG:
			print("[AssignFlow] crew=", get_instance_id(), " reserved=", _assignment_target_tile, " furniture=", furniture.name, " room_id=", rid)
		# Setup debug overlay if enabled
		if debug_assignment_flow:
			_setup_assignment_debug_canvas()
	
	# Start flow-following toward the reserved beacon (per-crew flow field)
	_is_flow_following = true
	_flow_furniture = furniture
	_flow_step_target = Vector2i.ZERO
	_last_tile = Vector2i.ZERO
	_flow_wander_goal = _assignment_target_tile
	_tile_history.clear()
	_oscillation_count = 0
	_oscillation_cooldown = 0.0
	_cached_room_id_for_tile.clear()
	_cached_seeds_key = ""
	
	# Ensure sane agent settings while following assignment flow
	navigation_agent.avoidance_enabled = true
	navigation_agent.path_postprocessing = 1  # string pulling
	
	# Kick off flow timer; it will compute per-crew flow steps
	_ensure_flow_timer()
	_on_flow_timer_timeout()
	_flow_timer.start()
	state_manager.send_event(&"walk")

func unassign_from_furniture() -> void:
	var prev_furniture := furniture_workplace
	furniture_workplace = null
	state_manager.send_event(&"unassigned")
	_stop_flow_follow()
	# Release reserved tile on previous furniture
	if prev_furniture != null and is_instance_valid(prev_furniture) and prev_furniture.has_method("release_access_tile_for_crew"):
		prev_furniture.release_access_tile_for_crew(self)
	# Reset assignment tracking
	_assignment_target_tile = Vector2i.ZERO

func _give_up_on_assignment() -> void:
	unassign_from_furniture()
	var line: String = ASSIGNMENT_GIVE_UP_LINES[randi() % ASSIGNMENT_GIVE_UP_LINES.size()]
	say(line, 2.5)

func go_to_work() -> void:
	# Avoid retargeting while following a fixed assignment path
	if has_pending_assignment_path():
		return
	# Avoid recomputing path if target is already set
	if navigation_agent.target_position == Vector2(work_location.x, work_location.y):
		return
	set_movement_target(work_location)
	assignment = &"work"
	state_manager.set_expression_property(&"assignment", assignment)
	# Don't chain segments when heading to work
	walk_segments_remaining = 1
	state_manager.send_event(&"walk")

func _ensure_flow_timer() -> void:
	if is_instance_valid(_flow_timer):
		return
	var flow_timer_node := Timer.new()
	flow_timer_node.name = "FlowFollowTimer"
	flow_timer_node.one_shot = true
	flow_timer_node.autostart = false
	flow_timer_node.wait_time = 0.15  # ~6.6 Hz
	add_child(flow_timer_node)
	flow_timer_node.timeout.connect(_on_flow_timer_timeout)
	_flow_timer = flow_timer_node
	_cached_field = null
	_cached_field_goal = Vector2i.ZERO
	_cached_field_room_id = -1
	_cached_field_version = -1
	_cached_nav_version = -1
	_cached_furn_version = -1
	_cached_seeds_key = ""

func _on_flow_timer_timeout() -> void:
	# If already working, stop processing and ensure flow following is fully stopped
	if assignment == &"work" or state == STATE.WORK:
		_stop_flow_follow()
		return
	
	# Set goal: priority assignment, otherwise wander
	if _assignment_target_tile != Vector2i.ZERO:
		_flow_wander_goal = _assignment_target_tile
		_is_flow_following = true
	elif _flow_wander_goal == Vector2i.ZERO:
		if Global and Global.wander_beacons:
			var beacon_tile: Vector2i = Global.wander_beacons.pick_beacon_for_crew()
			if beacon_tile != Vector2i.ZERO:
				_flow_wander_goal = Global.wander_beacons.jitter(beacon_tile, 2)
		if _flow_wander_goal == Vector2i.ZERO:
			_flow_wander_goal = _nav_grid.random_walkable_tile()
	
	var curr_tile: Vector2i = _nav_grid.world_to_tile(global_position)
	
	# Strict centering for flow-following: finish current step before recalculating
	if _is_flow_following and _flow_step_target != Vector2i.ZERO:
		var target_world := _nav_grid.tile_center_world(_flow_step_target)
		if global_position.distance_to(target_world) > 8.0:
			_flow_timer.start()
			return
		curr_tile = _flow_step_target
	
	# Build per-crew flow field
	var field = null
	if _assignment_target_tile != Vector2i.ZERO:
		var furniture_room := _get_furniture_room()
		var seeds: Array[Vector2i] = []
		var furniture_room_id: int = _get_furniture_room_id()
		var crew_room_id: int = _cached_room_id_for_tile.get(curr_tile, -999)
		if crew_room_id == -999:
			crew_room_id = Room.find_tile_room_id(curr_tile)
			_cached_room_id_for_tile[curr_tile] = crew_room_id
		var is_on_door_tile: bool = false
		if furniture_room:
			is_on_door_tile = furniture_room.data.door_tiles.has(curr_tile)
			if crew_room_id != furniture_room_id and not is_on_door_tile:
				seeds = _flow_targets.door_tiles(furniture_room)
				if seeds.is_empty():
					if ASSIGN_DEBUG:
						print("[AssignFlow][error] no door seeds for room ", furniture_room_id, " crew=", get_instance_id(), " curr=", curr_tile)
					_flow_timer.start()
					return
				field = _get_or_build_flow_field(seeds, null)
			else:
				seeds = [_assignment_target_tile]
				field = _get_or_build_flow_field(seeds, furniture_room)
			if ASSIGN_DEBUG:
				print("[AssignFlow][seed] crew=", get_instance_id(), " curr_room=", crew_room_id, " furniture_room=", furniture_room_id, " on_door=", is_on_door_tile, " seeds=", seeds.size())
		else:
			seeds = [_assignment_target_tile]
			field = _get_or_build_flow_field(seeds, null)
			if ASSIGN_DEBUG:
				print("[AssignFlow][seed] crew=", get_instance_id(), " no room context; seed furniture tile ", _assignment_target_tile)
		_debug_flow_field = field
	else:
		field = _get_or_build_flow_field([_flow_wander_goal], null)
	
	if field == null:
		if ASSIGN_DEBUG:
			print("[AssignFlow][error] no field for crew=", get_instance_id(), " goal=", _flow_wander_goal)
		_flow_timer.start()
		return
	
	var next_tile: Vector2i = _flow_service.get_next_tile(field, curr_tile)
	if ASSIGN_DEBUG and _assignment_target_tile != Vector2i.ZERO:
		var dir_vec: Vector2i = Vector2i.ZERO
		var distance_val: int = -1
		if field != null:
			dir_vec = field.direction.get(curr_tile, Vector2i.ZERO)
			distance_val = field.distance.get(curr_tile, -1)
		print("[AssignFlow][step] crew=", get_instance_id(), " curr=", curr_tile, " next=", next_tile, " dir=", dir_vec, " dist=", distance_val, " goal=", _assignment_target_tile)

	# If flow suggests an invalid transition, try a viable downhill neighbor
	if field != null:
		var curr_dist: int = field.distance.get(curr_tile, INF)
		var best_tile := next_tile
		var best_dist := curr_dist
		var candidates: Array[Vector2i] = [
			curr_tile + Vector2i(0, -1),
			curr_tile + Vector2i(1, 0),
			curr_tile + Vector2i(0, 1),
			curr_tile + Vector2i(-1, 0)
		]
		for cand: Vector2i in candidates:
			if not field.distance.has(cand):
				continue
			if not _nav_grid.is_walkable(cand):
				continue
			if not _nav_grid.can_traverse(curr_tile, cand):
				continue
			var d: int = field.distance[cand]
			if d < best_dist:
				best_dist = d
				best_tile = cand
		if best_tile != next_tile and ASSIGN_DEBUG and _assignment_target_tile != Vector2i.ZERO:
			print("[AssignFlow][adjust] crew=", get_instance_id(), " curr=", curr_tile, " flow_next=", next_tile, " adjusted_next=", best_tile, " curr_dist=", curr_dist, " best_dist=", best_dist)
		next_tile = best_tile
	
	# Assignment arrival handling
	if _assignment_target_tile != Vector2i.ZERO and _flow_wander_goal == _assignment_target_tile:
		if curr_tile == _assignment_target_tile:
			var target_world := _nav_grid.tile_center_world(_assignment_target_tile)
			if global_position.distance_to(target_world) <= 4.0:
				if ASSIGN_DEBUG:
					print("[AssignFlow][arrive] crew=", get_instance_id(), " tile=", curr_tile, " dist_to_center=", global_position.distance_to(target_world))
				global_position = target_world
				_transition_to_work()
				return
			next_tile = _assignment_target_tile
		elif next_tile == curr_tile or next_tile == Vector2i.ZERO:
			# No downhill direction; nudge toward goal if possible
			var nudged := _find_viable_neighbor_toward_goal(curr_tile, _assignment_target_tile)
			if nudged != Vector2i.ZERO:
				next_tile = nudged
			else:
				if ASSIGN_DEBUG:
					print("[AssignFlow][stall] crew=", get_instance_id(), " curr=", curr_tile, " goal=", _assignment_target_tile, " at_door=", _nav_grid.is_door_tile(curr_tile))
				_flow_timer.start()
				return
	
	# Random wander stall handling
	if _assignment_target_tile == Vector2i.ZERO and (next_tile == curr_tile or next_tile == Vector2i.ZERO):
		if Global and Global.wander_beacons and _flow_wander_goal != Vector2i.ZERO:
			Global.wander_beacons.release_beacon(_flow_wander_goal)
		_flow_wander_goal = Vector2i.ZERO
		_flow_timer.start()
		return
	
	if next_tile == Vector2i.ZERO:
		_flow_timer.start()
		return
	
	var next_world := _nav_grid.tile_center_world(next_tile)
	if next_tile != _flow_step_target or navigation_agent.target_position != next_world:
		_flow_step_target = next_tile
		navigation_agent.target_position = next_world
	state_manager.send_event(&"walk")
	_flow_timer.start()

func _stop_flow_follow() -> void:
	_is_flow_following = false
	_flow_furniture = null
	_flow_wander_goal = Vector2i.ZERO
	_flow_step_target = Vector2i.ZERO
	_tile_history.clear()
	_oscillation_count = 0
	_oscillation_cooldown = 0.0
	_teardown_assignment_debug_canvas()
	if is_instance_valid(_flow_timer):
		_flow_timer.stop()

func _get_furniture_use_state() -> StringName:
	# Decide the state to enter when arriving at the assigned furniture.
	var furn := furniture_workplace if furniture_workplace != null else _flow_furniture
	if is_instance_valid(furn) and furn.furniture_type != null and furn.furniture_type.has_method("get_use_state"):
		var desired := furn.furniture_type.get_use_state()
		if desired != StringName():
			return desired
	return &"work"

func _transition_to_work() -> void:
	"""Helper to transition crew to work state when arriving at assignment"""
	var current_tile := _nav_grid.world_to_tile(global_position)
	if ASSIGN_DEBUG:
		print("[AssignFlow][transition] Crew ", get_instance_id(), " transitioning to work at tile ", current_tile, " (target was ", _assignment_target_tile, ")")
	
	# Snap to exact target position if known
	if _assignment_target_tile != Vector2i.ZERO:
		global_position = _nav_grid.tile_center_world(_assignment_target_tile)
	
	var target_state := _get_furniture_use_state()
	assignment = target_state
	state_manager.set_expression_property(&"assignment", assignment)
	
	# Stop all movement systems
	velocity = Vector2.ZERO
	current_move_direction = Vector2.ZERO
	_stop_flow_follow()
	
	# Ensure navigation agent is also stopped
	navigation_agent.target_position = global_position
	
	# Reflect desired state for animations/UI; state chart will still process to_assignment.
	state = target_state
	state_manager.send_event(&"to_assignment")

func _get_furniture_room() -> Room:
	"""Get the room containing the assigned furniture, or null if not applicable"""
	if is_instance_valid(_flow_furniture) and (_flow_furniture.get_parent() is Room):
		return _flow_furniture.get_parent() as Room
	return null

func _get_furniture_room_id() -> int:
	"""Get the room ID of the assigned furniture's room, or -1 if not applicable"""
	var room := _get_furniture_room()
	return room.data.id if (room and room.data) else -1

func _start_flow_wander() -> void:
	# Begin or continue wandering using a flow field toward a random walkable tile
	_ensure_flow_timer()
	# Disable flow following for random wander - rely on NavigationAgent2D for smoother movement
	_is_flow_following = false
	_flow_furniture = null
	
	# Reset flow tracking to prevent stale targets from blocking movement (Strict Centering)
	_flow_step_target = Vector2i.ZERO
	_last_tile = Vector2i.ZERO
	
	if _flow_wander_goal == Vector2i.ZERO:
		_flow_wander_goal = _nav_grid.random_walkable_tile()
	_on_flow_timer_timeout()
	_flow_timer.start()

func _choose_side_step(from_tile: Vector2i, to_tile: Vector2i) -> Vector2i:
	# Pick a perpendicular neighbor to avoid a blocked wall/corner
	var dir := to_tile - from_tile
	var left := Vector2i(-dir.y, dir.x)
	var right := Vector2i(dir.y, -dir.x)
	var cand1 := from_tile + left.sign()
	var cand2 := from_tile + right.sign()
	if _is_viable_transition(from_tile, cand1):
		return cand1
	if _is_viable_transition(from_tile, cand2):
		return cand2
	return Vector2i.ZERO

func _is_viable_transition(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	# Stay on nav, obey door transitions
	if not _nav_grid.is_walkable(to_tile):
		return false
	if not _nav_grid.can_traverse(from_tile, to_tile):
		return false
	# Trust logical connectivity (NavGrid) over physical line-of-sight (raycast)
	# to allow movement around tight corners.
	return true

func _find_viable_neighbor_toward_goal(curr_tile: Vector2i, goal_tile: Vector2i) -> Vector2i:
	"""Find a walkable neighbor tile that moves toward the goal"""
	var dirs: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
	var best_tile := Vector2i.ZERO
	var best_dist := INF
	
	for dir: Vector2i in dirs:
		var neighbor: Vector2i = curr_tile + dir
		if not _nav_grid.is_walkable(neighbor):
			continue
		if not _nav_grid.can_traverse(curr_tile, neighbor):
			continue
		# Check if this neighbor moves us toward the goal
		var neighbor_world: Vector2 = _nav_grid.tile_center_world(neighbor)
		var goal_world: Vector2 = _nav_grid.tile_center_world(goal_tile)
		var curr_world: Vector2 = _nav_grid.tile_center_world(curr_tile)
		var dist_to_goal := neighbor_world.distance_to(goal_world)
		var curr_dist_to_goal := curr_world.distance_to(goal_world)
		
		# Prefer neighbors that get us closer to goal
		if dist_to_goal < curr_dist_to_goal or best_tile == Vector2i.ZERO:
			if dist_to_goal < best_dist:
				best_dist = dist_to_goal
				best_tile = neighbor
	
	return best_tile
	
func _get_or_build_flow_field(seeds: Array[Vector2i], room: Room):
	if seeds.is_empty():
		return null
	var goal := seeds[0]
	var room_id := room.data.id if (room and room.data) else -1
	var seeds_key := str(goal.x) + ":" + str(goal.y) + ":" + str(room_id)
	if _cached_field != null and _cached_seeds_key == seeds_key and _cached_field_room_id == room_id and _cached_field_goal == goal:
		return _cached_field
	var field := _flow_service.get_field_for_seeds(seeds, room)
	_cached_field = field
	_cached_field_goal = goal
	_cached_field_room_id = room_id
	_cached_field_version = field.version if field != null else -1
	_cached_seeds_key = seeds_key
	return field
	
func is_assigned() -> bool:
	return workplace != null or furniture_workplace != null

func get_assignment_type() -> String:
	if furniture_workplace != null:
		return "furniture"
	elif workplace != null:
		return "room"
	else:
		return "none"

func get_crew_info() -> Dictionary:
	var info = {}
	if data:
		info["Name"] = data.name
	return info
	
func is_within_working_hours() -> bool:
	var current_time: int = GameTime.current_time_in_minutes()
	
	var after_starts_work = current_time >= ((starts_work_hour * 60) + starts_work_minute)
	var before_stops_work = current_time < ((stops_work_hour * 60) + stops_work_minute) 
	return after_starts_work and before_stops_work

# CrewVigour component signal handlers
func _on_vigour_changed(new_vigour: int) -> void:
	data.vigour = new_vigour
	state_manager.set_expression_property(&"vigour", new_vigour)

func _on_resting_started() -> void:
	state_transitioned.emit(STATE.REST)

func _on_resting_finished() -> void:
	state = STATE.WALK
	# Force immediate animation update to walking
	set_current_animation()
	_update_animation_speed()
	if crew_animation:
		crew_animation.play_current_animation()
	# If we are on assignment (have pending waypoints or furniture target), do not randomise target

## Collision Detection and Avoidance

func check_path_for_static_obstacles(target_pos: Vector2) -> bool:
	"""Check if path to target intersects static obstacles (walls/furniture)"""
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target_pos)
	query.collision_mask = COLLISION_LAYERS.OBSTACLES
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _is_segment_clear(from_pos: Vector2, to_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = COLLISION_LAYERS.OBSTACLES
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _agent_has_active_path() -> bool:
	# Consider there is an active path if the agent has a non-zero next position
	# or the current navigation path contains at least 2 points
	var next_pos := navigation_agent.get_next_path_position()
	if next_pos != Vector2.ZERO:
		return true
	var path := navigation_agent.get_current_navigation_path()
	return path.size() >= 2

func check_for_crew_collisions() -> Vector2:
	"""Check for nearby crew members and return avoidance offset"""
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + current_move_direction * 64.0)
	query.collision_mask = COLLISION_LAYERS.CREW
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if not result.is_empty():
		# Check if it's a crew member by checking if it has collision_layer property
		if result.collider.has_method("get") and result.collider.get("collision_layer") != null:
			var collider_layer = result.collider.get("collision_layer")
			if collider_layer & COLLISION_LAYERS.CREW:
				# Calculate perpendicular direction for side-step
				var perpendicular = Vector2(-current_move_direction.y, current_move_direction.x)
				# Randomly choose left or right
				if randf() < 0.5:
					perpendicular = -perpendicular
				return perpendicular * AVOIDANCE_DISTANCE
	
	return Vector2.ZERO

func update_avoidance(_delta: float) -> void:
	"""Update avoidance offset and timer"""
	if _avoidance_timer > 0:
		_avoidance_timer -= _delta
		if _avoidance_timer <= 0:
			_avoidance_offset = Vector2.ZERO
	else:
		# Check for new crew collisions at a limited rate
		_avoidance_check_accum += _delta
		if _avoidance_check_accum >= AVOIDANCE_CHECK_INTERVAL:
			var new_offset = check_for_crew_collisions()
			if new_offset != Vector2.ZERO:
				_avoidance_offset = new_offset
				_avoidance_timer = AVOIDANCE_DURATION
			_avoidance_check_accum = 0.0

func _handle_wall_collision(collision: KinematicCollision2D) -> void:
	"""Handle collision with walls - pause and repath if needed"""
	# If we're on an assignment, immediately retarget via the flow loop to avoid stalling
	if _is_on_assignment():
		# Reset flow target to bypass strict centering check and force new path calc
		_flow_step_target = Vector2i.ZERO
		_on_flow_timer_timeout()
		return
	var collider = collision.get_collider()
	
	# Check if collision is with a wall/obstacle (not another crew)
	var is_wall_collision = false
	
	if collider is TileMap:
		# TileMap objects (room walls) are always obstacles
		is_wall_collision = true
	elif collider and collider.has_method("get") and collider.get("collision_layer") != null:
		# Other objects with collision_layer property
		var collider_layer = collider.get("collision_layer")
		
		if collider_layer & COLLISION_LAYERS.OBSTACLES:
			is_wall_collision = true
	
	if is_wall_collision:
		# Only increment collision count if not currently paused
		if _wall_collision_timer <= 0:
			_wall_collision_count += 1
			
			if _wall_collision_count <= MAX_WALL_COLLISIONS:
				# First collision: pause for 1 second
				_wall_collision_timer = WALL_COLLISION_PAUSE
			else:
				# Second collision: try to repath around the obstacle
				_attempt_repath_around_obstacle()

func _attempt_repath_around_obstacle() -> void:
	"""Try to find an alternative route around the obstacle to reach the same destination"""
	# Performance optimization: limit pathfinding frequency using monotonic time (seconds)
	var now := Time.get_ticks_msec() / 1000.0
	var time_since_last := now - _last_pathfinding_time
	if time_since_last < PATHFINDING_COOLDOWN:
		return
	_last_pathfinding_time = now
	
	# Try multiple strategies to find a circuitous route to the same destination
	var alternative_target = _find_smart_alternative_route(_final_destination)
	
	if alternative_target != Vector2.ZERO:
		# Set up waypoint system: intermediate point -> final destination
		_alternative_waypoints.clear()
		_alternative_waypoints.append(alternative_target)
		_alternative_waypoints.append(_final_destination)
		_current_waypoint_index = 0
		
		navigation_agent.target_position = alternative_target
		_wall_collision_count = 0  # Reset collision count
	else:
		# Fallback to closest reachable point if no valid route exists
		var closest_reachable = _find_closest_reachable_point(_final_destination)
		if closest_reachable != Vector2.ZERO:
			# Set up waypoint system: closest point -> final destination
			_alternative_waypoints.clear()
			_alternative_waypoints.append(closest_reachable)
			_alternative_waypoints.append(_final_destination)
			_current_waypoint_index = 0
			
			navigation_agent.target_position = closest_reachable
			_wall_collision_count = 0
		else:
			# Stop trying to move to avoid infinite collision loop
			navigation_agent.target_position = global_position

func _find_circuitous_route(destination: Vector2) -> Vector2:
	"""Find a circuitous route around obstacles to reach the same destination"""
	var directions: Array[Vector2] = [
		Vector2(1, 0),   # Right
		Vector2(-1, 0),  # Left
		Vector2(0, 1),   # Down
		Vector2(0, -1),  # Up
		Vector2(1, 1),   # Down-right
		Vector2(-1, 1),  # Down-left
		Vector2(1, -1),  # Up-right
		Vector2(-1, -1)  # Up-left
	]
	
	var current_pos: Vector2 = global_position
	var distance_to_dest: float = current_pos.distance_to(destination)
	var step_size: float = 200.0  # Increased from 128 to step back further
	var max_steps = 5  # Allow for more circuitous routes
	
	# Try different directions at increasing distances
	for direction in directions:
		for i in range(1, max_steps + 1):
			var test_target: Vector2 = current_pos + direction * (step_size * i)
			
			# Check if this intermediate point is clear
			if check_path_for_static_obstacles(test_target):
				# Check if we can reach the final destination from this intermediate point
				if _can_reach_destination_from(test_target, destination):
					return test_target
	
	return Vector2.ZERO

func _can_reach_destination_from(start: Vector2, destination: Vector2) -> bool:
	"""Check if we can reach the destination from the given start point"""
	# Use a simple ray cast to check if there's a clear path
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start, destination)
	query.collision_mask = COLLISION_LAYERS.OBSTACLES
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _find_smart_alternative_route(destination: Vector2) -> Vector2:
	"""Find an intelligent alternative route that prioritizes obstacle avoidance"""
	var current_pos = global_position
	
	# First, try room-based pathfinding if destination is in a room
	var room_based_route: Vector2 = _try_room_based_pathfinding(current_pos, destination)
	if room_based_route != Vector2.ZERO:
		return room_based_route
	
	# If room-based fails, try multi-step pathfinding with obstacle avoidance
	return _find_multi_step_route_with_avoidance(current_pos, destination)

func _try_room_based_pathfinding(start: Vector2, destination: Vector2) -> Vector2:
	"""Try to find a route using room entrances and common paths"""
	# Find the room containing the destination
	var dest_room = _get_room_containing_point(destination)
	if dest_room == null:
		return Vector2.ZERO
	
	# Find the room containing the start position
	var start_room = _get_room_containing_point(start)
	if start_room == null:
		return Vector2.ZERO
	
	# If we're already in the same room, try direct path
	if start_room == dest_room:
		if check_path_for_static_obstacles(destination):
			return destination
		return Vector2.ZERO
	
	# Try to find a route through room entrances
	var entrance_route = _find_route_via_room_entrances(start_room, dest_room, start, destination)
	if entrance_route != Vector2.ZERO:
		return entrance_route
	
	return Vector2.ZERO

func _get_room_containing_point(point: Vector2) -> Room:
	"""Get the room that contains the given point"""
	# Query for rooms at the given point
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = COLLISION_LAYERS.OBSTACLES
	
	var result = space_state.intersect_point(query)
	for hit in result:
		if hit.collider is Room:
			return hit.collider as Room
	
	return null

func _find_route_via_room_entrances(start_room: Room, dest_room: Room, start: Vector2, destination: Vector2) -> Vector2:
	"""Find a route that goes through room entrances"""
	# This is a simplified version - in a full implementation, you'd have
	# a graph of room connections and find the shortest path through entrances
	# For now, try to find the nearest entrance to the destination room
	
	# Get all room entrances (this would need to be implemented based on your room system)
	var entrances: Array[Vector2] = _get_room_entrances(dest_room)
	if entrances.is_empty():
		return Vector2.ZERO
	
	# Find the entrance closest to our current position that we can reach
	var best_entrance: Vector2 = Vector2.ZERO
	var best_distance: float = INF
	
	for entrance in entrances:
		if check_path_for_static_obstacles(entrance):
			var distance: float = start.distance_to(entrance)
			if distance < best_distance:
				best_distance = distance
				best_entrance = entrance
	
	return best_entrance

func _get_room_entrances(room: Room) -> Array[Vector2]:
	"""Get the entrance points for a room"""
	# This would need to be implemented based on your room system
	# For now, return empty array - you'd implement this based on how
	# doors and entrances are defined in your room system
	return []

func _find_multi_step_route_with_avoidance(start: Vector2, destination: Vector2) -> Vector2:
	"""Find a multi-step route that avoids obstacles"""
	var directions: Array[Vector2] = [
		Vector2(1, 0),   # Right
		Vector2(-1, 0),  # Left
		Vector2(0, 1),   # Down
		Vector2(0, -1),  # Up
		Vector2(1, 1),   # Down-right
		Vector2(-1, 1),  # Down-left
		Vector2(1, -1),  # Up-right
		Vector2(-1, -1)  # Up-left
	]
	
	var step_size = 200.0  # Increased from 128 to step back further
	var max_steps = 6  # Reduced for performance with 150 crew members
	
	# Try different directions with increasing distances
	for direction in directions:
		for i in range(1, max_steps + 1):
			var test_target = start + direction * (step_size * i)
			
			# Check if this intermediate point is clear
			if check_path_for_static_obstacles(test_target):
				# Check if we can reach the final destination from this intermediate point
				if _can_reach_destination_from(test_target, destination):
					# Also check if the path from start to intermediate point is clear
					if check_path_for_static_obstacles(test_target):
						return test_target
	
	return Vector2.ZERO

func _find_closest_reachable_point(destination: Vector2) -> Vector2:
	"""Find the closest point to the destination that is actually reachable"""
	var current_pos = global_position
	var search_radius = 256.0  # Start with 256 pixel radius
	var max_radius = 768.0     # Reduced maximum search radius for performance
	var step_size = 128.0      # Increased search resolution for performance
	
	while search_radius <= max_radius:
		# Search in a spiral pattern around the destination
		var angle = 0.0
		var angle_step = PI / 4.0  # 4 directions per radius for performance
		
		while angle < 2 * PI:
			var offset = Vector2(cos(angle), sin(angle)) * search_radius
			var test_point = destination + offset
			
			# Check if this point is reachable
			if check_path_for_static_obstacles(test_point):
				# Double-check that we can reach it from our current position
				if check_path_for_static_obstacles(test_point):
					return test_point
			
			angle += angle_step
		
		search_radius += step_size
	
	# If no reachable point found, return current position
	return current_pos

func _on_fatigue_level_changed(is_fatigued: bool) -> void:
	# Could be used for future fatigue effects
	pass

func _update_depth_sorting() -> void:
	"""Update z_index based on Y position for proper depth sorting"""
	# Use Y position directly to avoid per-frame TileMap lookups
	z_as_relative = false
	z_index = int(global_position.y / 64) + 25

func _world_center_of_footprint(furniture: Furniture) -> Vector2:
	var occupiedTiles: Array[Vector2i] = furniture.get_occupied_tiles()
	if occupiedTiles.is_empty():
		return furniture.global_position
	var worldSum := Vector2.ZERO
	for occTile in occupiedTiles:
		worldSum += _nav_grid.tile_center_world(occTile)
	return worldSum / float(occupiedTiles.size())


func get_furniture_workplace() -> Furniture:
	return furniture_workplace

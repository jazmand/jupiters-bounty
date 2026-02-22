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

# Unreachable handling
const UNREACHABLE_RETRY_LIMIT: int = 3
const UNREACHABLE_RETRY_WINDOW: float = 6.0
const UNREACHABLE_RETRY_DELAY: float = 2.0

# Explicit preloads for typed component references
const CrewNavigation = preload("res://entities/crew/CrewNavigation.gd")
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
var assigned_bed: Furniture = null  # Optional bed for rest; pathing and rest logic target this when tired
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

# Unreachable tracking
var _unreachable_attempts: int = 0
var _unreachable_window_start: float = 0.0

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
		# Connect to cache invalidation signal to detect when walls are built
		_flow_service.cache_invalidated.connect(_on_flow_cache_invalidated)
	else:
		_flow_service = FlowFieldServiceScript.new()
		if _flow_service:
			_flow_service.cache_invalidated.connect(_on_flow_cache_invalidated)
	
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
	CrewNavigation.set_movement_target(self, movement_target)

func find_alternative_route(blocked_target: Vector2) -> Vector2:
	return CrewNavigation.find_alternative_route(self, blocked_target)

func validate_current_path() -> void:
	CrewNavigation.validate_current_path(self)

func find_route_around_obstacle(start: Vector2, blocked_end: Vector2) -> Vector2:
	return CrewNavigation.find_route_around_obstacle(self, start, blocked_end)

func _force_navigation_rebake() -> void:
	# Force rebake the navigation mesh
	var nav_region = get_tree().get_first_node_in_group("navigation")
	if nav_region and nav_region.has_method("bake_navigation_polygon"):
		nav_region.bake_navigation_polygon()

func set_rounded_direction() -> void:
	CrewNavigation.set_rounded_direction(self)

func snap_to_eight_directions(vec: Vector2) -> Vector2:
	return CrewNavigation.snap_to_eight_directions(vec)

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
	CrewNavigation.randomise_target_position(self)

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
	CrewNavigation.process_walking_state(self, _delta)

func _snapshot_agent_path() -> void:
	CrewNavigation._snapshot_agent_path(self)

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
	
	# If assigned to furniture, stay in place at the beacon and deplete vigour while working
	if furniture_workplace != null:
		crew_vigour.process_working(_delta)
		current_animation_direction = Vector2.ZERO  # Preserve animation direction
		navigation_agent.target_position = global_position
		return
	
	# Resting at assigned bed: recover vigour at this location (task 5.2)
	if assignment == &"rest" or state == STATE.REST:
		current_animation_direction = crew_vigour.get_resting_direction()
		navigation_agent.target_position = global_position
		crew_vigour.process_resting(_delta, current_animation_direction, current_move_direction)
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
	CrewNavigation.assign_to_furniture_via_flow(self, furniture)

func unassign_from_furniture(from_furniture: Furniture = null) -> void:
	if from_furniture == null:
		from_furniture = furniture_workplace
	if from_furniture == assigned_bed:
		assigned_bed = null
	if from_furniture != furniture_workplace:
		return
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
	_reset_unreachable_attempts()
	if crew_speech:
		crew_speech.say_unreachable()

func _reset_unreachable_attempts() -> void:
	_unreachable_attempts = 0
	_unreachable_window_start = 0.0

func _schedule_unreachable_retry() -> void:
	_ensure_flow_timer()
	_flow_timer.start(UNREACHABLE_RETRY_DELAY)

func _mark_unreachable_attempt() -> bool:
	# Returns true if we give up
	if _assignment_target_tile == Vector2i.ZERO:
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if _unreachable_window_start == 0.0 or (now - _unreachable_window_start) > UNREACHABLE_RETRY_WINDOW:
		_unreachable_window_start = now
		_unreachable_attempts = 1
	else:
		_unreachable_attempts += 1
	if _unreachable_attempts >= UNREACHABLE_RETRY_LIMIT:
		_give_up_on_assignment()
		return true
	_schedule_unreachable_retry()
	return false

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
	CrewNavigation._ensure_flow_timer(self)

func _on_flow_timer_timeout() -> void:
	CrewNavigation.on_flow_timer_timeout(self)

func _on_flow_cache_invalidated() -> void:
	"""Handle flow field cache invalidation (e.g., when walls are built)"""
	# Clear cached flow field data
	_cached_field = null
	_cached_field_version = -1
	_cached_seeds_key = ""
	_cached_nav_version = -1
	_cached_furn_version = -1
	_cached_room_id_for_tile.clear()
	
	# If freely roaming (not on assignment), clear wander goal and pick new beacon
	if not _is_on_assignment() and _flow_wander_goal != Vector2i.ZERO:
		if Global and Global.wander_beacons:
			Global.wander_beacons.release_beacon(_flow_wander_goal)
		_flow_wander_goal = Vector2i.ZERO
		_flow_step_target = Vector2i.ZERO
	
	# Force immediate flow field recalculation if flow following
	if _is_flow_following and is_instance_valid(_flow_timer):
		_flow_timer.stop()
		_on_flow_timer_timeout()
		_flow_timer.start()

func _stop_flow_follow() -> void:
	CrewNavigation._stop_flow_follow(self)

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
	_reset_unreachable_attempts()
	
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
	CrewNavigation._start_flow_wander(self)

func _choose_side_step(from_tile: Vector2i, to_tile: Vector2i) -> Vector2i:
	return CrewNavigation._choose_side_step(self, from_tile, to_tile)

func _is_viable_transition(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	return CrewNavigation._is_viable_transition(self, from_tile, to_tile)

func _find_viable_neighbor_toward_goal(curr_tile: Vector2i, goal_tile: Vector2i) -> Vector2i:
	return CrewNavigation._find_viable_neighbor_toward_goal(self, curr_tile, goal_tile)
	
func _get_or_build_flow_field(seeds: Array[Vector2i], room: Room):
	return CrewNavigation._get_or_build_flow_field(self, seeds, room)
	
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
	# If we were resting at assigned bed (Working state), leave assignment and release bed tile (task 5.2)
	if assignment == &"rest":
		if assigned_bed != null and is_instance_valid(assigned_bed) and assigned_bed.has_method("release_access_tile_for_crew"):
			assigned_bed.release_access_tile_for_crew(self)
		assignment = &""
		state_manager.set_expression_property(&"assignment", assignment)
		_assignment_target_tile = Vector2i.ZERO
		state_manager.send_event(&"idle")
	state = STATE.WALK
	# Force immediate animation update to walking
	set_current_animation()
	_update_animation_speed()
	if crew_animation:
		crew_animation.play_current_animation()
	# If we are on assignment (have pending waypoints or furniture target), do not randomise target

## Collision Detection and Avoidance

func check_path_for_static_obstacles(target_pos: Vector2) -> bool:
	return CrewNavigation.check_path_for_static_obstacles(self, target_pos)

func _is_segment_clear(from_pos: Vector2, to_pos: Vector2) -> bool:
	return CrewNavigation._is_segment_clear(self, from_pos, to_pos)

func _agent_has_active_path() -> bool:
	return CrewNavigation._agent_has_active_path(self)

func check_for_crew_collisions() -> Vector2:
	return CrewNavigation.check_for_crew_collisions(self)

func update_avoidance(_delta: float) -> void:
	CrewNavigation.update_avoidance(self, _delta)

func _handle_wall_collision(collision: KinematicCollision2D) -> void:
	CrewNavigation._handle_wall_collision(self, collision)

func _attempt_repath_around_obstacle() -> void:
	CrewNavigation._attempt_repath_around_obstacle(self)

func _find_circuitous_route(destination: Vector2) -> Vector2:
	return CrewNavigation._find_circuitous_route(self, destination)

func _can_reach_destination_from(start: Vector2, destination: Vector2) -> bool:
	return CrewNavigation._can_reach_destination_from(self, start, destination)

func _find_smart_alternative_route(destination: Vector2) -> Vector2:
	return CrewNavigation._find_smart_alternative_route(self, destination)

func _try_room_based_pathfinding(start: Vector2, destination: Vector2) -> Vector2:
	return CrewNavigation._try_room_based_pathfinding(self, start, destination)

func _get_room_containing_point(point: Vector2) -> Room:
	return CrewNavigation._get_room_containing_point(self, point)

func _find_route_via_room_entrances(start_room: Room, dest_room: Room, start: Vector2, destination: Vector2) -> Vector2:
	return CrewNavigation._find_route_via_room_entrances(self, start_room, dest_room, start, destination)

func _get_room_entrances(room: Room) -> Array[Vector2]:
	return CrewNavigation._get_room_entrances(self, room)

func _find_multi_step_route_with_avoidance(start: Vector2, destination: Vector2) -> Vector2:
	return CrewNavigation._find_multi_step_route_with_avoidance(self, start, destination)

func _find_closest_reachable_point(destination: Vector2) -> Vector2:
	return CrewNavigation._find_closest_reachable_point(self, destination)

func _on_fatigue_level_changed(is_fatigued: bool) -> void:
	# Could be used for future fatigue effects
	pass

func _update_depth_sorting() -> void:
	"""Update z_index based on Y position for proper depth sorting"""
	# Use Y position directly to avoid per-frame TileMap lookups
	z_as_relative = false
	z_index = int(global_position.y / 64) + 25

func _world_center_of_footprint(furniture: Furniture) -> Vector2:
	return CrewNavigation._world_center_of_footprint(self, furniture)


func get_furniture_workplace() -> Furniture:
	return furniture_workplace

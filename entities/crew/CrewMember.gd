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
@onready var navigation_timer: Timer = $Navigation/Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var speech_label: Label = $SpeechLabel
@onready var speech_timer: Timer = $SpeechTimer
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
		set_sprite_visibility(state)
		
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

# Multi-waypoint pathfinding system
var _alternative_waypoints: Array[Vector2] = []
var _current_waypoint_index: int = 0
var _final_destination: Vector2 = Vector2.ZERO

# Vigour constants moved to CrewVigour component


var is_speaking: bool = false

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

func _is_on_assignment() -> bool:
	return assignment == &"work" or furniture_workplace != null or not pending_waypoints.is_empty()

func has_pending_assignment_path() -> bool:
	return not pending_waypoints.is_empty()

# Vigour variables moved to CrewVigour component

# Walk timing (keep for now, may move to CrewMovement later)
var walk_start_time: float = 0.0
const MIN_WALK_TIME: float = 1.0  # Minimum 1 second of walking

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
	# Ensure speech label exists (no random speech timer)
	_ensure_speech_label()
	
func actor_setup():
	await get_tree().physics_frame
	set_movement_target(target)

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
	
	navigation_agent.target_position = movement_target

func find_alternative_route(blocked_target: Vector2) -> Vector2:
	"""Find an alternative route around obstacles using multiple ray directions"""
	var directions = [
		Vector2(1, 0),   # Right
		Vector2(-1, 0),  # Left
		Vector2(0, 1),   # Down
		Vector2(0, -1),  # Up
		Vector2(1, 1),   # Down-right
		Vector2(-1, 1),  # Down-left
		Vector2(1, -1),  # Up-right
		Vector2(-1, -1)  # Up-left
	]
	
	var distance = global_position.distance_to(blocked_target)
	var step_size = 200.0  # Increased from 128 to step back further
	var max_steps = 3  # Limit search to avoid performance issues
	
	# Try different directions at increasing distances
	for direction in directions:
		for i in range(1, min(max_steps, int(distance / step_size) + 1)):
			var test_target = global_position + direction * (step_size * i)
			if check_path_for_static_obstacles(test_target):
				return test_target
	
	return Vector2.ZERO

func validate_current_path() -> void:
	"""Continuously validate the current navigation path against physics obstacles"""
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
		var alternative = _find_smart_alternative_route(_final_destination)
		if alternative != Vector2.ZERO:
			# Set up waypoint system: intermediate point -> final destination
			_alternative_waypoints.clear()
			_alternative_waypoints.append(alternative)
			_alternative_waypoints.append(_final_destination)
			_current_waypoint_index = 0
			navigation_agent.target_position = alternative
		else:
			# Try to find a route around the obstacle
			var around_obstacle = find_route_around_obstacle(global_position, next_target)
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
	# Prefer a frozen cached path during assignment to avoid per-tick re-planning
	if _is_on_assignment() and assignment_path.size() > 0 and assignment_path_idx < assignment_path.size():
		next_point = assignment_path[assignment_path_idx]
		# Advance cached waypoint when close enough
		if global_position.distance_to(next_point) <= ASSIGNMENT_WAYPOINT_EPS:
			assignment_path_idx += 1
			if assignment_path_idx < assignment_path.size():
				next_point = assignment_path[assignment_path_idx]
			else:
				# No more cached points; fall back to agent
				next_point = navigation_agent.get_next_path_position()
	else:
		next_point = navigation_agent.get_next_path_position()

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
	var v = vec.normalized()
	var best_dir = DIRECTIONS.RIGHT
	var best_dot = -INF
	var dirs = [DIRECTIONS.RIGHT, DIRECTIONS.UP_RIGHT, DIRECTIONS.UP, DIRECTIONS.UP_LEFT, DIRECTIONS.LEFT, DIRECTIONS.DOWN_LEFT, DIRECTIONS.DOWN, DIRECTIONS.DOWN_RIGHT]
	for d in dirs:
		var dot = v.dot(d.normalized())
		if dot > best_dot:
			best_dot = dot
			best_dir = d
	return best_dir

func set_current_animation() -> void:
	# Special handling for resting - use idle animation with resting direction
	if crew_vigour.is_resting:
		var dir_for_anim = crew_vigour.get_resting_direction()
		if dir_for_anim == Vector2.ZERO:
			dir_for_anim = DIRECTIONS.DOWN
		_set_animation_for_direction(STATE.IDLE, dir_for_anim)
		return

	var animation_state = STATE.IDLE  # Default to idle for all non-walking states
	if state == STATE.WALK:
		animation_state = STATE.WALK
	var dir_for_anim = current_animation_direction if current_animation_direction != Vector2.ZERO else current_move_direction
	_set_animation_for_direction(animation_state, dir_for_anim)

func _set_animation_for_direction(animation_state: StringName, direction: Vector2) -> void:
	match direction:
		DIRECTIONS.UP:
			current_animation = animation_state + "_up"
		DIRECTIONS.UP_RIGHT:
			current_animation = animation_state + "_up_right"
		DIRECTIONS.RIGHT:
			current_animation = animation_state + "_right"
		DIRECTIONS.DOWN_RIGHT:
			current_animation = animation_state + "_down_right"
		DIRECTIONS.DOWN:
			current_animation = animation_state + "_down"
		DIRECTIONS.DOWN_LEFT:
			current_animation = animation_state + "_down_left"
		DIRECTIONS.LEFT:
			current_animation = animation_state + "_left"
		DIRECTIONS.UP_LEFT:
			current_animation = animation_state + "_up_left"

func _update_animation_speed() -> void:
	# Get animation speed from CrewVigour component
	var speed_scale = crew_vigour.get_fatigue_scale()
	animation_player.speed_scale = speed_scale

func set_sprite_visibility(animation_state: StringName) -> void:
	match animation_state:
		STATE.IDLE:
			sprite_idle.show()
			sprite_walk.hide()
		STATE.WALK:
			sprite_idle.hide()
			sprite_walk.show()
		STATE.WORK:
			sprite_idle.show()
			sprite_walk.hide()
		STATE.REST:
			# Use idle visuals for resting (no dedicated rest sprites yet)
			sprite_idle.show()
			sprite_walk.hide()

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
	if animation_player.current_animation != current_animation or not animation_player.is_playing():
		animation_player.play(current_animation)
	_update_animation_speed()
	
	# If resting, pause the animation to prevent walking in place
	if crew_vigour.is_resting:
		animation_player.pause()

func say(text: String, duration: float = 2.5) -> void:
	if is_speaking:
		return
	_ensure_speech_label()
	if not is_instance_valid(speech_label):
		return
	# Reset and show
	speech_label.text = text
	speech_label.visible = true
	speech_label.modulate.a = 0.0
	# Center horizontally above the crew after size updates
	await get_tree().process_frame
	speech_label.position.x = -speech_label.size.x / 2.0
	# Fade in, wait, fade out
	var t := create_tween()
	is_speaking = true
	t.tween_property(speech_label, "modulate:a", 1.0, 0.2)
	t.tween_interval(max(0.0, duration - 0.4))
	t.tween_property(speech_label, "modulate:a", 0.0, 0.2)
	t.finished.connect(func():
		speech_label.visible = false
		is_speaking = false
	)

const RANDOM_PHRASES := [
	"Excuse me.",
	"Move, damn it!",
	"Why’s this here?",
	"Ugh!",
	"*Yawn*",
]

func _on_speech_timer_timeout() -> void:
	# 50% chance to speak when timer fires
	if randi() % 2 == 0:
		var idx = randi() % RANDOM_PHRASES.size()
		say(RANDOM_PHRASES[idx], 2.0)
	_reset_speech_timer()

func _reset_speech_timer() -> void:
	# Random interval between 6 and 14 seconds
	_ensure_speech_timer()
	if is_instance_valid(speech_timer):
		speech_timer.wait_time = randf_range(6.0, 14.0)
		speech_timer.start()

func _ensure_speech_nodes() -> void:
	_ensure_speech_label()
	_ensure_speech_timer()

func _ensure_speech_label() -> void:
	# Ensure the label exists
	if not is_instance_valid(speech_label):
		var lbl := Label.new()
		lbl.name = "SpeechLabel"
		add_child(lbl)
		speech_label = lbl
	# Configure size and placement
	speech_label.position = Vector2(0, -350)
	speech_label.z_index = 10
	speech_label.visible = false
	speech_label.modulate.a = 0.0
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := LabelSettings.new()
	settings.font_size = 48
	speech_label.label_settings = settings

func _ensure_speech_timer() -> void:
	if is_instance_valid(speech_timer):
		return
	var t := Timer.new()
	t.name = "SpeechTimer"
	t.one_shot = true
	t.autostart = false
	add_child(t)
	t.timeout.connect(_on_speech_timer_timeout)
	speech_timer = t

func _handle_collision_speech(collision: KinematicCollision2D) -> void:
	var other := collision.get_collider()
	if other == null:
		return
	# Do not speak again while current message is in progress
	if is_speaking:
		return
	if other.has_method("say"):
		if randi() % 2 == 0:
			say("Excuse me.", 2.5)
		else:
			say("Move, damn it!", 2.5)
	else:
		say("Why’s this here?", 2.5)

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
	
	idle_timer += _delta
	if idle_timer >= idle_time_limit:
		state_manager.send_event(&"walk")
		idle_timer = 0.0
		# Set number of walk segments for this free-walk cycle
		walk_segments_remaining = randi_range(walk_segments_per_cycle_min, walk_segments_per_cycle_max)
		randomise_target_position()

func _on_walking_state_entered() -> void:
	# Don't override state if resting
	if not crew_vigour.is_resting:
		state = STATE.WALK
	walk_start_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	# If walking freely, generate a new random target; otherwise keep assignment target/waypoint
	if not _is_on_assignment():
		randomise_target_position()
		walk_segments_remaining = randi_range(walk_segments_per_cycle_min, walk_segments_per_cycle_max)

func _on_walking_state_physics_processing(_delta: float) -> void:
	# Update z_index based on Y position for proper depth sorting
	_update_depth_sorting()
	
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
	
	# Handle navigation completion only if not exhausted
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
			var next_waypoint = _alternative_waypoints[_current_waypoint_index]
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
			# Arrived at final waypoint: stay at work location
			state_manager.send_event(&"to_assignment")
			return

	set_rounded_direction()
	
	# Validate current path against obstacles
	validate_current_path()
	
	# Update collision avoidance
	update_avoidance(_delta)
	
	# Apply avoidance offset to movement direction
	if _avoidance_offset != Vector2.ZERO:
		current_move_direction += _avoidance_offset.normalized() * 0.3  # Blend avoidance with normal movement
	
	# Get speed scale from CrewVigour component (handles fatigue)
	var fatigue_scale = crew_vigour.get_fatigue_scale()
	var current_speed_scale = speed_multiplier * fatigue_scale
	
	velocity = current_move_direction.normalized() * (speed * current_speed_scale)
	var collision = move_and_collide(velocity)
	if collision:
		_handle_wall_collision(collision)
		_handle_collision_speech(collision)

	# TEST: log next path position changes while on assignment
	if _is_on_assignment():
		var np := navigation_agent.get_next_path_position()
		if _last_logged_next_path.distance_to(np) > 4.0:
			_last_logged_next_path = np

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
	state = STATE.WORK

func _on_working_state_physics_processing(_delta: float) -> void:
	randomise_target_position_in_room()

# Old resting functions removed - functionality moved to CrewVigour component

# _handle_resting function moved to CrewVigour component

func _on_working_state_exited() -> void:
	pass

func can_assign() -> bool:
	return Global.station.rooms.size() > 0

func assign(room: Room, center: Vector2) -> void:
	workplace = room
	work_location = center
	state_manager.send_event(&"assigned")

func assign_to_furniture(furniture: Furniture, position: Vector2) -> void:
	# Store furniture reference
	furniture_workplace = furniture
	work_location = position
	state_manager.send_event(&"assigned")

func assign_to_furniture_via_waypoints(furniture: Furniture, waypoints: Array[Vector2]) -> void:
	# Set up a two-step (or multi-step) path, e.g., door tile then furniture
	furniture_workplace = furniture
	assignment = &"work"
	state_manager.set_expression_property(&"assignment", assignment)
	pending_waypoints = waypoints.duplicate()
	# Set final work location to last waypoint (where crew should remain)
	if not waypoints.is_empty():
		var final_wp: Vector2 = waypoints[waypoints.size() - 1]
		work_location = Vector2i(int(final_wp.x), int(final_wp.y))
	if not pending_waypoints.is_empty():
		var first_target: Vector2 = pending_waypoints.pop_front()
		set_movement_target(first_target)
		# Snapshot the initial computed path for this assignment leg (to freeze it)
		await get_tree().physics_frame
		_snapshot_agent_path()
	else:
		# Fallback: go directly to stored work_location if no waypoints provided
		set_movement_target(work_location)
	# Notify UI/state that we've been assigned
	state_manager.send_event(&"assigned")
	# Ensure we are walking immediately
	state_manager.send_event(&"walk")

func override_path_limit_for_assignment() -> void:
	# Save and remove path distance limit for long paths to door/furniture
	if _saved_path_max_distance < 0.0:
		_saved_path_max_distance = navigation_agent.path_max_distance
		navigation_agent.path_max_distance = 0.0
		# TEST: disable avoidance and postprocessing to stabilize next path point
		_saved_avoidance_enabled = navigation_agent.avoidance_enabled
		_saved_postprocessing = navigation_agent.path_postprocessing
		navigation_agent.avoidance_enabled = false
		navigation_agent.path_postprocessing = 0

func unassign_from_furniture() -> void:
	furniture_workplace = null
	state_manager.send_event(&"unassigned")

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
	animation_player.play(current_animation)
	animation_player.speed_scale = 1.0
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
		# Check for new crew collisions
		var new_offset = check_for_crew_collisions()
		if new_offset != Vector2.ZERO:
			_avoidance_offset = new_offset
			_avoidance_timer = AVOIDANCE_DURATION

func _handle_wall_collision(collision: KinematicCollision2D) -> void:
	"""Handle collision with walls - pause and repath if needed"""
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
	# Performance optimization: limit pathfinding frequency using delta time
	var current_time = Time.get_time_dict_from_system()
	var time_since_last = current_time.second - _last_pathfinding_time
	if time_since_last < PATHFINDING_COOLDOWN:
		return
	
	_last_pathfinding_time = current_time.second
	
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
	var directions = [
		Vector2(1, 0),   # Right
		Vector2(-1, 0),  # Left
		Vector2(0, 1),   # Down
		Vector2(0, -1),  # Up
		Vector2(1, 1),   # Down-right
		Vector2(-1, 1),  # Down-left
		Vector2(1, -1),  # Up-right
		Vector2(-1, -1)  # Up-left
	]
	
	var current_pos = global_position
	var distance_to_dest = current_pos.distance_to(destination)
	var step_size = 200.0  # Increased from 128 to step back further
	var max_steps = 5  # Allow for more circuitous routes
	
	# Try different directions at increasing distances
	for direction in directions:
		for i in range(1, max_steps + 1):
			var test_target = current_pos + direction * (step_size * i)
			
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
	var room_based_route = _try_room_based_pathfinding(current_pos, destination)
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
	var entrances = _get_room_entrances(dest_room)
	if entrances.is_empty():
		return Vector2.ZERO
	
	# Find the entrance closest to our current position that we can reach
	var best_entrance = Vector2.ZERO
	var best_distance = INF
	
	for entrance in entrances:
		if check_path_for_static_obstacles(entrance):
			var distance = start.distance_to(entrance)
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
	var directions = [
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
	# Convert world position to tile coordinates
	var tile_map = get_tree().get_first_node_in_group("navigation")
	if tile_map and tile_map is TileMap:
		var tile_pos = tile_map.local_to_map(tile_map.to_local(global_position))
		# Higher Y values (further down) should have higher z_index (appear in front)
		# Crew should appear above furniture (which has z_index = tile_y + 15), so add a higher base offset
		z_as_relative = false
		z_index = tile_pos.y + 25  # Base offset to ensure crew appears above furniture
	else:
		# Fallback: use Y position directly
		z_as_relative = false
		z_index = int(global_position.y / 64) + 25

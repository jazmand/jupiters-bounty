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
	CHAT = &"chat"
}

@export var speed: int = 5

# TODO: temporary solution, will improve later
@export_category("Working Hours")
@export var starts_work_hour: int = 2
@export var starts_work_minute: int = 10
@export var stops_work_hour: int = 2
@export var stops_work_minute: int = 25

@onready var state_manager: StateChart = $CrewStateManager
@onready var navigation_agent: NavigationAgent2D = $Navigation/NavigationAgent2D
@onready var navigation_timer: Timer = $Navigation/Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var speech_label: Label = $SpeechLabel
@onready var speech_timer: Timer = $SpeechTimer
@onready var sprite_idle: Sprite2D = $AgathaIdle
@onready var sprite_walk: Sprite2D = $AgathaWalk
@onready var area: Area2D = $BodyArea

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

@export var walk_segments_per_cycle_min: int = 1
@export var walk_segments_per_cycle_max: int = 3

var walk_segments_remaining: int = 0
var assignment: StringName = &""

const ANIMATION_SWITCH_ANGLE_DEGREES: float = 8.0
const ANIMATION_SWITCH_ANGLE_COSINE: float = cos(deg_to_rad(ANIMATION_SWITCH_ANGLE_DEGREES))


var is_speaking: bool = false

var workplace: Room
var furniture_workplace: Furniture  # Store reference to assigned furniture
var work_location: Vector2i

func _ready() -> void:
	data = CrewData.new()
	navigation_timer.timeout.connect(_on_timer_timeout)
	call_deferred("actor_setup")
	area.input_event.connect(_on_input_event)
	area.mouse_entered.connect(func(): Global.is_crew_input = true)
	area.mouse_exited.connect(func(): Global.is_crew_input = false)
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

func select() -> void:
	Global.crew_selected.emit(self)

func set_movement_target(movement_target: Vector2) -> void:
	navigation_agent.target_position = movement_target

func set_rounded_direction() -> void:
	var to_next = (navigation_agent.get_next_path_position() - global_position)
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
	var animation_state = STATE.WALK if state == STATE.WALK else STATE.IDLE
	var dir_for_anim = current_animation_direction if current_animation_direction != Vector2.ZERO else current_move_direction
	match dir_for_anim:
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

func randomise_target_position() -> void:
	target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
	set_movement_target(target)
	while !navigation_agent.is_target_reachable():
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
	if other is CrewMember:
		if randi() % 2 == 0:
			say("Excuse me.", 2.5)
		else:
			say("Move, damn it!", 2.5)
	else:
		say("Why’s this here?", 2.5)

func _on_idling_state_entered() -> void:
	state = STATE.IDLE
	navigation_agent.target_position = position
	assignment = &""
	state_manager.set_expression_property(&"assignment", assignment)
	# Randomise idle duration each cycle
	idle_time_limit = randf_range(idle_time_min, idle_time_max)
	idle_timer = 0.0
	current_animation_direction = Vector2.ZERO

func _on_idling_state_physics_processing(delta: float) -> void:
	idle_timer += delta
	if idle_timer >= idle_time_limit:
		state_manager.send_event(&"walk")
		idle_timer = 0.0
		# Set number of walk segments for this free-walk cycle
		walk_segments_remaining = randi_range(walk_segments_per_cycle_min, walk_segments_per_cycle_max)
		randomise_target_position()

func _on_walking_state_entered() -> void:
	state = STATE.WALK

func _on_walking_state_physics_processing(_delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		# If walking freely (not heading to work), optionally chain additional targets
		if assignment == &"" and walk_segments_remaining > 1:
			walk_segments_remaining -= 1
			randomise_target_position()
			return
		else:
			state_manager.send_event(&"to_assignment")
			return
	
	set_rounded_direction()
	#velocity = velocity.lerp(current_direction.normalized() * speed, 1.0)
	velocity = current_move_direction.normalized() * (speed * speed_multiplier)
	var collision = move_and_collide(velocity)
	if collision:
		_handle_collision_speech(collision)
		#velocity = -current_direction.normalized() * speed
		#move_and_collide(velocity)
		#var x = -navigation_agent.target_position.x
		#var y = -navigation_agent.target_position.y
		#set_movement_target(Vector2(x,y))

func _on_working_state_entered() -> void:
	state = STATE.WORK

func _on_working_state_physics_processing(_delta: float) -> void:
	randomise_target_position_in_room()

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

func unassign_from_furniture() -> void:
	furniture_workplace = null
	state_manager.send_event(&"unassigned")

func go_to_work() -> void:
	set_movement_target(work_location)
	assignment = &"work"
	state_manager.set_expression_property(&"assignment", assignment)
	# Don't chain segments when heading to work
	walk_segments_remaining = 1
	state_manager.send_event(&"walk")
	
func is_assigned() -> bool:
	return workplace != null or furniture_workplace != null

func get_assignment_type() -> String:
	"""Get the type of assignment (room, furniture, or none)"""
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

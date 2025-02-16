class_name CrewMember extends CharacterBody2D

signal state_transitioned(state: StringName)

const DIRECTION = {
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

@export_category("Working Hours")
@export var starts_work_hour: int = 2
@export var starts_work_minute: int = 10
@export var stops_work_hour: int = 2
@export var stops_work_minute: int = 25

@onready var state_manager: StateChart = $CrewStateManager
@onready var navigation_agent: NavigationAgent2D = $Navigation/NavigationAgent2D
@onready var navigation_timer: Timer = $Navigation/Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_idle: Sprite2D = $AgathaIdle
@onready var sprite_walk: Sprite2D = $AgathaWalk
@onready var area: Area2D = $BodyArea

var data: CrewData

var target = Vector2(0, 0)
var current_direction = Vector2(0, 0)

var state = STATE.IDLE:
	set(animation_state):
		state = animation_state
		state_transitioned.emit(state)
		set_sprite_visibility(state)
		
var current_animation = state + "_down"

var idle_timer = 0.0
var idle_time_limit = 2.0

var workplace: Room
var work_location: Vector2i

func _ready() -> void:
	data = CrewData.new()
	print(data.name)
	navigation_timer.timeout.connect(_on_timer_timeout)
	call_deferred("actor_setup")
	area.input_event.connect(_on_input_event)
	area.mouse_entered.connect(func(): Global.is_crew_input = true)
	area.mouse_exited.connect(func(): Global.is_crew_input = false)
	
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
	var direction = (navigation_agent.get_next_path_position() - global_position).normalized()
	direction.x = roundi(direction.x)
	direction.y = roundi(direction.y)
	current_direction = direction

func set_current_animation() -> void:
	var animation_state = STATE.WALK if state == STATE.WALK else STATE.IDLE
	match current_direction:
		DIRECTION.UP:
			current_animation = animation_state + "_up"
		DIRECTION.UP_RIGHT:
			current_animation = animation_state + "_up_right"
		DIRECTION.RIGHT:
			current_animation = animation_state + "_right"
		DIRECTION.DOWN_RIGHT:
			current_animation = animation_state + "_down_right"
		DIRECTION.DOWN:
			current_animation = animation_state + "_down"
		DIRECTION.DOWN_LEFT:
			current_animation = animation_state + "_down_left"
		DIRECTION.LEFT:
			current_animation = animation_state + "_left"
		DIRECTION.UP_LEFT:
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
	animation_player.play(current_animation)

func _on_idling_state_entered() -> void:
	state = STATE.IDLE
	navigation_agent.target_position = position
	state_manager.set_expression_property(&"assignment", &"")

func _on_idling_state_physics_processing(delta: float) -> void:
	idle_timer += delta
	if idle_timer >= idle_time_limit:
		state_manager.send_event(&"walk")
		idle_timer = 0.0
		randomise_target_position()

func _on_walking_state_entered() -> void:
	state = STATE.WALK

func _on_walking_state_physics_processing(_delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		state_manager.send_event(&"to_assignment")
		return
	
	set_rounded_direction()
	#velocity = velocity.lerp(current_direction.normalized() * speed, 1.0)
	velocity = current_direction.normalized() * speed
	var collision = move_and_collide(velocity)
	
	#var collision = move_and_slide()
	if collision:
		pass
		#velocity = -current_direction.normalized() * speed
		#move_and_collide(velocity)
		#var x = -navigation_agent.target_position.x
		#var y = -navigation_agent.target_position.y
		#set_movement_target(Vector2(x,y))

func _on_working_state_entered() -> void:
	print("working...")
	state = STATE.WORK

func _on_working_state_physics_processing(_delta: float) -> void:
	randomise_target_position_in_room()

func _on_working_state_exited() -> void:
	print("stopped working")

func can_assign() -> bool:
	return Global.station.rooms.size() > 0

func assign(room: Room, center: Vector2) -> void:
	workplace = room
	work_location = center
	state_manager.send_event(&"assigned")
	print(data.name, " assigned to room ", room.data.id)

func go_to_work() -> void:
	set_movement_target(work_location)
	state_manager.set_expression_property(&"assignment", &"work")
	state_manager.send_event(&"walk")
	
func is_assigned() -> bool:
	return workplace != null
	
func is_within_working_hours() -> bool:
	var current_time: int = GameTime.current_time_in_minutes()
	
	var after_start = current_time >= ((starts_work_hour * 60) + starts_work_minute)
	var before_stop = current_time < ((stops_work_hour * 60) + stops_work_minute) 
	return after_start and before_stop

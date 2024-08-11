# CrewMember.gd

class_name CrewMember
extends CharacterBody2D

signal state_transitioned(state: StringName)

const Direction = {
	UP = Vector2(0, -1),
	UP_RIGHT = Vector2(1, -1),
	RIGHT = Vector2(1, 0),
	DOWN_RIGHT = Vector2(1, 1),
	DOWN = Vector2(0, 1),
	DOWN_LEFT = Vector2(-1, 1),
	LEFT = Vector2(-1, 0),
	UP_LEFT = Vector2(-1, -1)
}

const AnimationState = {
	IDLE = &"idle",
	WALK = &"walk",
	WORK = &"work",
	CHAT = &"chat"
}

@export var speed: int = 5

@onready var state_manager: StateChart = $CrewStateManager
@onready var navigation_agent: NavigationAgent2D = $Navigation/NavigationAgent2D
@onready var navigation_timer: Timer = $Navigation/Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_idle: Sprite2D = $AgathaIdle
@onready var sprite_walk: Sprite2D = $AgathaWalk
@onready var area: Area2D = $Area2D

var info: CrewInfo

var target = Vector2(0, 0)
var current_direction = Vector2(0, 0)

var animation_state = AnimationState.IDLE:
	set(state):
		animation_state = state
		state_transitioned.emit(state)
var current_animation = animation_state + "_down"

var idle_timer = 0.0
var idle_time_limit = 2.0

func _ready() -> void:
	Global.station.crew += 1
	info = CrewInfo.new()
	print(info.name)
	navigation_timer.timeout.connect(_on_timer_timeout)
	call_deferred("actor_setup")
	area.gui_toggle.connect(select)

func actor_setup():
	await get_tree().physics_frame
	set_movement_target(target)

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
	match current_direction:
		Direction.UP:
			current_animation = animation_state + "_up"
		Direction.UP_RIGHT:
			current_animation = animation_state + "_up_right"
		Direction.RIGHT:
			current_animation = animation_state + "_right"
		Direction.DOWN_RIGHT:
			current_animation = animation_state + "_down_right"
		Direction.DOWN:
			current_animation = animation_state + "_down"
		Direction.DOWN_LEFT:
			current_animation = animation_state + "_down_left"
		Direction.LEFT:
			current_animation = animation_state + "_left"
		Direction.UP_LEFT:
			current_animation = animation_state + "_up_left"

func set_sprite_visibility(state: StringName) -> void:
	match state:
		AnimationState.IDLE:
			sprite_idle.show()
			sprite_walk.hide()
		AnimationState.WALK:
			sprite_idle.hide()
			sprite_walk.show()
		AnimationState.WORK:
			sprite_idle.show()
			sprite_walk.hide()

func randomise_target_position() -> void:
	target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
	set_movement_target(target)
	while !navigation_agent.is_target_reachable():
		target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
		set_movement_target(target)

func _on_idling_state_entered() -> void:
	animation_state = AnimationState.IDLE
	set_sprite_visibility(animation_state)
	state_manager.set_expression_property(&"assignment", &"")

func _on_idling_state_physics_processing(delta: float) -> void:
	idle_timer += delta
	if idle_timer >= idle_time_limit:
		state_manager.send_event(&"walk")
		idle_timer = 0.0
		randomise_target_position()

func _on_walking_state_entered() -> void:
	animation_state = AnimationState.WALK
	set_sprite_visibility(animation_state)

func _on_walking_state_physics_processing(delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		state_manager.send_event(&"to_assignment")
		return
	
	set_rounded_direction()
	#velocity = velocity.lerp(current_direction.normalized() * speed, 1.0)
	velocity = current_direction.normalized() * speed
	move_and_collide(velocity)
	
	#var collision = move_and_slide()
	#if collision:
		#var x = -navigation_agent.target_position.x
		#var y = -navigation_agent.target_position.y
		#set_movement_target(Vector2(x,y))

func _on_timer_timeout() -> void:
	set_current_animation()
	animation_player.play(current_animation)

func _on_working_state_entered() -> void:
	print("working...")
	animation_state = AnimationState.IDLE
	set_sprite_visibility(animation_state)

func _on_working_state_exited() -> void:
	print("stopped working")

func can_assign() -> bool:
	return Global.station.rooms.size() > 0

func assign(room: Room, center: Vector2) -> void:
	state_manager.send_event(&"assigned")
	print(info.name, " assigned to room ", room.id)
	set_movement_target(center)
	state_manager.set_expression_property(&"assignment", &"work")
	state_manager.send_event(&"walk")

# CrewMember.gd

class_name CrewMember
extends CharacterBody2D

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
	IDLE = "idle",
	WALK = "walk",
	WORK = "work",
	CHAT = "chat"
}

@export var speed: int = 250
@export var acceleration: int = 6

@onready var state_manager: StateChart = $CrewStateManager
@onready var navigation_agent: NavigationAgent2D = $Navigation/NavigationAgent2D
@onready var navigation_timer: Timer = $Navigation/Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_idle: Sprite2D = $AgathaIdle
@onready var sprite_walk: Sprite2D = $AgathaWalk
@onready var area: Area2D = $Area2D
@onready var gui: CrewGUI = $CrewGUI

var target = Vector2(0, 0)
var current_direction = Vector2(0, 0)
var animation_state = AnimationState.IDLE
var current_animation = animation_state + "_down"

var gui_open_temp = false
var gui_open_perm = false

var idle_timer = 0.0
var idle_time_limit = 4.0

func _ready() -> void:
	Global.station.crew += 1
	navigation_timer.timeout.connect(_on_timer_timeout)
	call_deferred("actor_setup")
	area.mouse_entered.connect(show_gui_temp.bind(true))
	area.mouse_exited.connect(show_gui_temp.bind(false))
	area.gui_toggle.connect(show_gui_perm)
	gui.assign_button.pressed.connect(start_assigning)

func show_gui_temp(is_open: bool) -> void:
	gui_open_temp = is_open
	should_show()

func show_gui_perm() -> void:
	gui_open_perm = !gui_open_perm
	should_show()

func should_show() -> void:
	gui.assign_button.disabled = Global.station.rooms.size() == 0
	if gui_open_temp or gui_open_perm:
		gui.show()
	else:
		gui.hide()

func actor_setup():
	await get_tree().physics_frame
	set_movement_target(target)

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

func randomise_target_position() -> void:
	target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
	set_movement_target(target)
	while !navigation_agent.is_target_reachable():
		target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
		set_movement_target(target)

func _on_idling_state_entered() -> void:
	animation_state = AnimationState.IDLE
	state_manager.set_expression_property(&"assignment", &"")
	gui.idle_button.disabled = true
	sprite_walk.hide()
	sprite_idle.show()

func _on_idling_state_exited() -> void:
	gui.idle_button.disabled = false

func _on_idling_state_physics_processing(delta: float) -> void:
	idle_timer += delta
	if idle_timer >= idle_time_limit:
		state_manager.send_event(&"walk")
		idle_timer = 0.0
		randomise_target_position()

func _on_walking_state_entered() -> void:
	animation_state = AnimationState.WALK
	sprite_idle.hide()
	sprite_walk.show()

func _on_walking_state_physics_processing(delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		state_manager.send_event(&"to_assignment")
		return
	
	set_rounded_direction()
	velocity = velocity.lerp(current_direction.normalized() * speed, acceleration * delta)
	#var collision = move_and_collide(velocity * delta)
	#if collision:
		#velocity = velocity.bounce(collision.get_normal())
	move_and_slide()

func _on_timer_timeout() -> void:
	set_current_animation()
	animation_player.play(current_animation)

func start_assigning() -> void:
	gui_open_perm = false
	state_manager.send_event(&"assign")

func assign(room: Room, center: Vector2) -> void:
	state_manager.send_event(&"assigned")
	print("assigned to room ", room.id)
	set_movement_target(center)
	state_manager.set_expression_property(&"assignment", &"work")
	state_manager.send_event(&"walk")


func _on_working_state_entered() -> void:
	print("working...")
	animation_state = AnimationState.IDLE
	sprite_walk.hide()
	sprite_idle.show()


func _on_working_state_exited() -> void:
	print("stopped working")

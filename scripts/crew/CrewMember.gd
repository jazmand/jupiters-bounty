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

@export var speed: int = 250
@export var acceleration: int = 6
@export var target: Node2D

@onready var state_manager: StateChart = $CrewStateManager
@onready var navigation_agent: NavigationAgent2D = $Navigation/NavigationAgent2D
@onready var navigation_timer: Timer = $Navigation/Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var current_animation = ''
var current_direction = Vector2(0, 0)

func _ready() -> void:
	Global.station.crew += 1
	navigation_timer.timeout.connect(_on_timer_timeout)
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	call_deferred("actor_setup")

func actor_setup():
	await get_tree().physics_frame
	print("target: ", target.global_position)
	set_movement_target(target.global_position)

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
			current_animation = 'walk_up'
		Direction.UP_RIGHT:
			current_animation = 'walk_up_right'
		Direction.RIGHT:
			current_animation = 'walk_right'
		Direction.DOWN_RIGHT:
			current_animation = 'walk_down_right'
		Direction.DOWN:
			current_animation = 'walk_down'
		Direction.DOWN_LEFT:
			current_animation = 'walk_down_left'
		Direction.LEFT:
			current_animation = 'walk_left'
		Direction.UP_LEFT:
			current_animation = 'walk_up_left'


func randomise_target_position() -> void:
	target.position = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
	set_movement_target(target.position)
	while !navigation_agent.is_target_reachable():
		target.position = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
		set_movement_target(target.position)

func _on_walking_state_physics_processing(delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		randomise_target_position()
		return
		
	velocity = velocity.lerp(current_direction * speed, acceleration * delta)
	move_and_slide()


func _on_timer_timeout():
	if !navigation_agent.is_target_reachable() or (abs(target.global_position.x - global_position.x) < 200 and abs(target.global_position.y - global_position.y) < 200):
		randomise_target_position()
	set_movement_target(target.global_position)
	set_rounded_direction()
	set_current_animation()
	animation_player.play(current_animation)

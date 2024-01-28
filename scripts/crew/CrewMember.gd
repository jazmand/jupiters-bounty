class_name CrewMember
extends CharacterBody2D

@export var speed: int = 200
@export var acceleration: int = 5
@export var target: Node2D

@onready var state_manager: StateChart = $CrewStateManager
@onready var navigation_agent: NavigationAgent2D = $Navigation/NavigationAgent2D
@onready var navigation_timer: Timer = $Navigation/Timer

func _ready() -> void:
	navigation_timer.timeout.connect(_on_timer_timeout)
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	call_deferred("actor_setup")

func actor_setup():
	await get_tree().physics_frame
	set_movement_target(target.global_position)

func set_movement_target(movement_target: Vector2) -> void:
	navigation_agent.target_position = movement_target

func randomise_target_position() -> void:
	target.position = Vector2(randf_range(0.0, 4000.0), randf_range(0, 2000.0))
	set_movement_target(target.position)
	while !navigation_agent.is_target_reachable():
		target.position = Vector2(randf_range(0.0, 4000.0), randf_range(0, 2000.0))
		set_movement_target(target.position)

func _on_walking_state_physics_processing(delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		print("finished navigation")
		randomise_target_position()
		print("new target: ", target.position)
		return

	var direction: Vector2 = (navigation_agent.get_next_path_position() - global_position).normalized()
	velocity = velocity.lerp(direction * speed, acceleration * delta)

	move_and_slide()


func _on_timer_timeout():
	if !navigation_agent.is_target_reachable() or (abs(target.global_position.x - global_position.x) < 50 and abs(target.global_position.x - global_position.x) < 50):
		randomise_target_position()
	set_movement_target(target.global_position)

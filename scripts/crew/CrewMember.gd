class_name CrewMember
extends CharacterBody2D

@export var speed: int = 10
@export var target: Vector2 = Vector2(0.0, 0.0)

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var timer: Timer = $Timer
@onready var state_manager: StateChart = $CrewStateManager

func _ready() -> void:
	timer.timeout.connect(update_state)
	# These values need to be adjusted for the actor's speed
	# and the navigation layout.
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0


func set_movement_target(movement_target: Vector2) -> void:
	navigation_agent.target_position = movement_target

func update_state() -> void:
	state_manager.send_event("crew_transition")
	set_movement_target(target)
	while !navigation_agent.is_target_reachable():
		target = Vector2(randf_range(0.0, 4000.0), randf_range(0, 2000.0))
		set_movement_target(target)

func _on_walking_state_physics_processing(_delta) -> void:
	if navigation_agent.is_navigation_finished():
		return

	var current_agent_position: Vector2 = global_position
	var next_path_position: Vector2 = navigation_agent.get_next_path_position()

	var new_velocity: Vector2 = next_path_position - current_agent_position
	new_velocity = new_velocity.normalized()
	new_velocity = new_velocity * speed

	velocity = new_velocity
	move_and_slide()

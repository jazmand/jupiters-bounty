class_name CrewMember
extends CharacterBody2D

@export var speed: int = 250
@export var acceleration: int = 6
@export var target: Node2D

@onready var state_manager: StateChart = $CrewStateManager
@onready var navigation_agent: NavigationAgent2D = $Navigation/NavigationAgent2D
@onready var navigation_timer: Timer = $Navigation/Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var current_animation = ''

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
	

func randomise_target_position() -> void:
	target.position = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
	set_movement_target(target.position)
	while !navigation_agent.is_target_reachable():
		target.position = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
		set_movement_target(target.position)

func _on_walking_state_physics_processing(delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		print("finished navigation")
		randomise_target_position()
		print("new target: ", target.position)
		return
		
	var direction: Vector2 = (navigation_agent.get_next_path_position() - global_position).normalized()
	velocity = velocity.lerp(direction * speed, acceleration * delta)
	
	var angle = rad_to_deg(direction.angle())
	var rounded_angle = str(round(angle / 45) * 45)

#	if animation_name != current_animation:
#		animation_player.play(animation_name)
#		current_animation = animation_name
#
	if angle >= 22.5 and angle < 67.5:
		current_animation = 'walk_down_right'
	elif angle >= 67.5 and angle < 112.5:
		current_animation = 'walk_down'
	elif angle >= 112.5 and angle < 157.5:
		current_animation = 'walk_down_left'
	elif angle >=  157.5 and angle < 180 or angle >= -180 and angle < -157.5:
		current_animation = 'walk_left'
	elif angle <= -22.5 and angle > -67.5:
		current_animation = 'walk_up_right'
	elif angle <= -67.5 and angle > -112.5:
		current_animation = 'walk_up'
	elif angle <= -112.5 and angle > -157.5:
		current_animation = 'walk_up_left'
	else:
		current_animation = 'walk_right'
		
	animation_player.play(current_animation)
	move_and_slide()


func _on_timer_timeout():
	if !navigation_agent.is_target_reachable() or (abs(target.global_position.x - global_position.x) < 200 and abs(target.global_position.y - global_position.y) < 200):
		randomise_target_position()
	set_movement_target(target.global_position)

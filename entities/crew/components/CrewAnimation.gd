class_name CrewAnimation extends Node

## Handles crew visual representation including sprites and animations
## Manages animation state, direction-based animation selection, and speed scaling

signal animation_changed(animation_name: String)

# Animation state constants
const STATE = {
	IDLE = &"idle",
	WALK = &"walk",
	WORK = &"work",
	REST = &"rest"
}

# Current animation state
var current_animation: String = "idle_down"
var current_state: StringName = STATE.IDLE

# Component references
var crew_member: CrewMember
var animation_player: AnimationPlayer
var sprite_idle: Sprite2D
var sprite_walk: Sprite2D

func _ready() -> void:
	crew_member = get_parent() as CrewMember
	animation_player = crew_member.get_node("AnimationPlayer") as AnimationPlayer
	sprite_idle = crew_member.get_node("AgathaIdle") as Sprite2D
	sprite_walk = crew_member.get_node("AgathaWalk") as Sprite2D

func initialize() -> void:
	set_sprite_visibility(STATE.IDLE)

func update_animation(state: StringName, direction: Vector2, is_resting: bool = false, resting_direction: Vector2 = Vector2.ZERO) -> void:
	current_state = state
	
	# Special handling for resting - use idle animation with resting direction
	if is_resting:
		var dir_for_anim = resting_direction if resting_direction != Vector2.ZERO else Vector2(0, 1)  # DOWN
		_set_animation_for_direction(STATE.IDLE, dir_for_anim)
		set_sprite_visibility(STATE.REST)
		return

	var animation_state = STATE.IDLE  # Default to idle for all non-walking states
	if state == STATE.WALK:
		animation_state = STATE.WALK
	
	var dir_for_anim = direction if direction != Vector2.ZERO else Vector2(0, 1)  # Default DOWN
	_set_animation_for_direction(animation_state, dir_for_anim)
	set_sprite_visibility(state)

func play_current_animation() -> void:
	if animation_player.current_animation != current_animation or not animation_player.is_playing():
		animation_player.play(current_animation)

func set_animation_speed(speed_scale: float) -> void:
	animation_player.speed_scale = speed_scale

func pause_animation() -> void:
	animation_player.pause()

func resume_animation() -> void:
	animation_player.speed_scale = 1.0

func _set_animation_for_direction(animation_state: StringName, direction: Vector2) -> void:
	var direction_suffix = _get_direction_suffix(direction)
	var new_animation = animation_state + direction_suffix
	
	if current_animation != new_animation:
		current_animation = new_animation
		animation_changed.emit(current_animation)

func _get_direction_suffix(direction: Vector2) -> String:
	"""Convert direction vector to animation suffix"""
	# Use the same DIRECTIONS from CrewMovement
	const DIRECTIONS = {
		Vector2(0, -1): "_up",           # UP
		Vector2(1, -1): "_up_right",     # UP_RIGHT
		Vector2(1, 0): "_right",         # RIGHT
		Vector2(1, 1): "_down_right",    # DOWN_RIGHT
		Vector2(0, 1): "_down",          # DOWN
		Vector2(-1, 1): "_down_left",    # DOWN_LEFT
		Vector2(-1, 0): "_left",         # LEFT
		Vector2(-1, -1): "_up_left"      # UP_LEFT
	}
	
	return DIRECTIONS.get(direction, "_down")  # Default to down

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

# Public getters
func get_current_animation() -> String:
	return current_animation

func get_current_state() -> StringName:
	return current_state

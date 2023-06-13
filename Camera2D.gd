extends Camera2D

var zoomSpeed: float = 0.05
var zoomMin: float = 0.01
var zoomMax: float = 2.0
var input_direction: Vector2 = Vector2.ZERO
var camera_motion: Vector2 = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event

		# Check if an arrow key was pressed
		if key_event.pressed:
			# Calculate the input direction
			input_direction = Vector2(
				Input.get_action_strength("right") - Input.get_action_strength("left"),
				Input.get_action_strength("down") - Input.get_action_strength("up")
			)
			# Reset the input direction when the arrow key is released
		elif key_event.pressed == false:
			input_direction = Vector2.ZERO

func _process(delta):
	var fps = Engine.get_frames_per_second()
	# Move the camera based on the input direction
	if input_direction == Vector2.ZERO:
		camera_motion = camera_motion.lerp(Vector2.ZERO, 0.2)
	else:
		camera_motion = input_direction * (fps / 4)
		
	print(delta)
	print(camera_motion)
	position += camera_motion

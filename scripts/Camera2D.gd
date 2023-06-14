extends Camera2D

var input_direction: Vector2 = Vector2.ZERO
var camera_motion: Vector2 = Vector2.ZERO
var camera_speed: float = 500.0

var zoom_min: float = 0.5
var zoom_max: float = 2.0

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
			
	# Check for mouse scroll inputs
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if motion_event.is_action_pressed("wheel_up") || motion_event.is_action_pressed("wheel_down"):
			var zoom_delta = Vector2(motion_event.relative.y, motion_event.relative.y)
			update_zoom(zoom_delta)
		
	# Check for pan gestures
	if event is InputEventPanGesture:
		print(event)
		var pan_event: InputEventPanGesture = event
		var zoom_delta = Vector2(pan_event.delta.y, pan_event.delta.y)
		update_zoom(zoom_delta)
		
func update_zoom(zoom_delta: Vector2) -> void:
	zoom += zoom_delta
	
	# Clamp zoom value within the specified range
	zoom.x = clamp(zoom.x, zoom_min, zoom_max)
	zoom.y = clamp(zoom.y, zoom_min, zoom_max)

func _process(delta):
	
	# Reconsider using fps instead of delta
	# var fps = Engine.get_frames_per_second()
	
	# Move the camera based on the input direction
	if input_direction == Vector2.ZERO:
		camera_motion = camera_motion.lerp(Vector2.ZERO, 0.2)
	else:
		camera_motion = input_direction * (delta * camera_speed)
		
	position += camera_motion

	# Clamp the camera's position to the desired boundaries
	# TODO: Update boundaries
	position.x = clamp(position.x, 0, 1000)
	position.y = clamp(position.y, 0, 500)

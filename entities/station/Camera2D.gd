class_name StationCamera extends Camera2D

var input_direction: Vector2 = Vector2.ZERO
var camera_motion: Vector2 = Vector2.ZERO
var camera_speed: float = 1000.0

var zoom_smoothing: float = 0.05
var zoom_min: float = 0.2
var zoom_max: float = 1

func _input(event: InputEvent) -> void:
	# Check for mouse scroll inputs
	if event is InputEventMouseButton:
		var motion_event: InputEventMouseButton = event
		# mouse/trackpad scroll in: InputEventMouseButton and button_index = 4
		# mouse/trackpad scroll out: InputEventMouseButton and button_index = 5
		var zoom_delta = Vector2(0.25, 0.25) 
		if motion_event.button_index == 4:
			update_zoom(zoom_delta)
		elif motion_event.button_index == 5:
			update_zoom(-zoom_delta)

	# Check for pan gestures
	if event is InputEventPanGesture:
		var pan_event: InputEventPanGesture = event
		var zoom_delta = Vector2(pan_event.delta.y, pan_event.delta.y)
		update_zoom(zoom_delta)

func update_zoom(zoom_delta: Vector2) -> void:
	var mouse_pos_before_zoom = get_global_mouse_position()

	zoom += zoom_delta * zoom_smoothing
	# Clamp zoom value within the specified range
	zoom.x = clamp(zoom.x, zoom_min, zoom_max)
	zoom.y = clamp(zoom.y, zoom_min, zoom_max)

	var mouse_pos_after_zoom = get_global_mouse_position()

	# Adjust the camera position to keep mouse-centered zoom
	position += (mouse_pos_before_zoom - mouse_pos_after_zoom)

func _process(delta):
	# Calculate the input direction
	input_direction = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)

	# Move the camera based on the input direction
	if input_direction == Vector2.ZERO:
		camera_motion = camera_motion.lerp(Vector2.ZERO, 0.2)
	else:
		camera_motion = input_direction * (delta * camera_speed)
	position += camera_motion

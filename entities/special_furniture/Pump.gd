class_name Pump extends Node2D

signal pump_clicked

@export var pump_data: PumpData
@export var position_tiles: Array[Vector2i] = []

var is_hovered: bool = false
var hover_tween: Tween

func _ready() -> void:
	# Initialize pump data if not set
	if not pump_data:
		pump_data = PumpData.new()
	
	# Set up visual representation first
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/special_furniture/pump_standard.png")
	add_child(sprite)
	
	# Set up input handling
	var area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var capsule_shape = CapsuleShape2D.new()
	
	# Set capsule shape size (pill shaped)
	capsule_shape.radius = 125   # Smaller radius for more pill-like shape
	capsule_shape.height = 600  # Taller cylindrical part
	collision_shape.shape = capsule_shape
	
	# Position collision shape at center (move up by half its length)
	collision_shape.position = Vector2(0, 100)
	
	area.add_child(collision_shape)
	add_child(area)
	
	# Connect signals
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	
	# Set initial tile position based on current world position
	_set_initial_tile_position()
	
	# Set proper z-index to appear above crew (crew uses tile_y + 25)
	_update_z_index()
	
	# Set z_as_relative to false for absolute z-index sorting
	z_as_relative = false

func _update_z_index() -> void:
	"""Update z-index based on bottom position of the Pump for proper depth sorting"""
	# For tall objects like the Pump, use the bottom Y position for z-index calculation
	# The Pump has a height of 600 units, with collision shape at (0, 100)
	# Bottom of the Pump is approximately at position.y + 400 (half height + offset)
	const PUMP_HEIGHT_OFFSET: float = 400.0  # Approximate bottom of the visual Pump
	var bottom_y: float = global_position.y + PUMP_HEIGHT_OFFSET
	
	# Use same calculation method as crew: int(y / 64) + offset
	# Pump should appear above crew (crew uses +25), so use higher offset
	z_index = int(bottom_y / 64) + 35

func _set_initial_tile_position() -> void:
	# Convert current world position to tile coordinates
	var tile_map = get_tree().get_first_node_in_group("navigation")
	if tile_map and tile_map is TileMap:
		var tile_pos = tile_map.local_to_map(tile_map.to_local(global_position))
		position_tiles = [tile_pos]
	else:
		# Fallback: calculate from world position
		var tile_size = 64
		var tile_x = int(global_position.x / tile_size)
		var tile_y = int(global_position.y / tile_size)
		position_tiles = [Vector2i(tile_x, tile_y)]

func _on_area_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Pump clicked! Model: ", pump_data.get_full_name())
		emit_signal("pump_clicked")

func _on_mouse_entered():
	is_hovered = true
	_update_visual_state()

func _on_mouse_exited():
	is_hovered = false
	_update_visual_state()

func _update_visual_state():
	# Create smooth fade transition for hover effect
	if hover_tween:
		hover_tween.kill()
	
	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_CUBIC)
	
	var target_color: Color
	if is_hovered:
		target_color = Color(1.4, 1.4, 1.4, 1.0)  # Even lighter when hovered
	else:
		target_color = Color(1.2, 1.2, 1.2, 1.0)  # Current hover color as default
	
	hover_tween.tween_property(self, "modulate", target_color, 0.2)

func set_position_from_tiles(tiles: Array[Vector2i]) -> void:
	position_tiles = tiles
	if tiles.is_empty():
		return
	
	# Calculate center of all occupied tiles
	var center_tile = Vector2i.ZERO
	for tile in tiles:
		center_tile += tile
	
	center_tile = center_tile / tiles.size()
	
	# Convert tile coordinates to world position
	var tile_size = 64  # Assuming 64x64 tiles
	position = Vector2(center_tile.x * tile_size, center_tile.y * tile_size)
	
	# Update z-index after position change
	_update_z_index()

func get_occupied_tiles() -> Array[Vector2i]:
	return position_tiles

func is_tile_occupied(tile: Vector2i) -> bool:
	return tile in position_tiles

func _physics_process(_delta: float) -> void:
	"""Continuously update z-index for proper depth sorting as crew moves around"""
	_update_z_index()

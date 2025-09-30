class_name Furniture extends Node2D

signal furniture_clicked
signal crew_assigned(crew_member: Node)
signal crew_unassigned(crew_member: Node)

@onready var area = $Area2D
@onready var collision_shape = $Area2D/CollisionShape2D

# Furniture data
var furniture_type: FurnitureType
var position_tiles: Array[Vector2i]  # Tiles this furniture occupies
var rotation_state: int = 0  # 0 = normal, 1 = rotated

# Crew assignment
var assigned_crew: Array[Node] = []
var max_crew_capacity: int = 1

# Visual and interaction
var is_hovered: bool = false
var is_selected: bool = false

func _ready():
	area.connect("input_event", self._on_area_input_event)
	area.connect("mouse_entered", self._on_mouse_entered)
	area.connect("mouse_exited", self._on_mouse_exited)

func initialize(furniture_type_data: FurnitureType, tiles: Array[Vector2i], rotation: int = 0) -> void:
	furniture_type = furniture_type_data
	position_tiles = tiles
	rotation_state = rotation
	max_crew_capacity = furniture_type.simultaneous_users
	
	# Set up collision shape to cover all occupied tiles
	_setup_collision_shape()
	
	# Set the furniture's position to the center of the occupied tiles
	_set_position_from_tiles()

func _setup_collision_shape() -> void:
	if not collision_shape or position_tiles.is_empty():
		return
	
	# Calculate bounds of occupied tiles
	var min_x = position_tiles[0].x
	var max_x = position_tiles[0].x
	var min_y = position_tiles[0].y
	var max_y = position_tiles[0].y
	
	for tile in position_tiles:
		min_x = min(min_x, tile.x)
		max_x = max(max_x, tile.x)
		min_y = min(min_y, tile.y)
		max_y = max(max_y, tile.y)
	
	# Create collision shape covering all tiles
	var rect_shape = RectangleShape2D.new()
	var tile_size = 64  # Assuming 64x64 tiles, adjust if different
	var width = (max_x - min_x + 1) * tile_size
	var height = (max_y - min_y + 1) * tile_size
	
	rect_shape.size = Vector2(width, height)
	collision_shape.shape = rect_shape
	
	# Position collision shape relative to furniture center
	var center_offset = Vector2(width, height) / 2
	collision_shape.position = center_offset

func _set_position_from_tiles() -> void:
	if position_tiles.is_empty():
		return
	
	# Calculate center of all occupied tiles
	var center_tile = Vector2i.ZERO
	for tile in position_tiles:
		center_tile += tile
	
	center_tile = center_tile / position_tiles.size()
	
	# Convert tile coordinates to world position
	var tile_size = 64  # Assuming 64x64 tiles, adjust if different
	position = Vector2(center_tile.x * tile_size, center_tile.y * tile_size)
	
	# Set z_index based on tile Y position for proper depth sorting
	# Higher Y values (further down) should have higher z_index (appear in front)
	# Furniture tile map has z_index = 5, so furniture instances should be above that
	z_index = center_tile.y + 15  # Base offset to ensure furniture appears above tile map and rooms

func _on_area_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("furniture_clicked")

func _on_mouse_entered():
	is_hovered = true
	_update_visual_state()

func _on_mouse_exited():
	is_hovered = false
	_update_visual_state()

func _update_visual_state():
	if is_selected:
		modulate = Color(1.2, 1.2, 1.0)
	elif is_hovered:
		modulate = Color(1.1, 1.1, 1.0)
	else:
		modulate = Color.WHITE

func select() -> void:
	is_selected = true
	_update_visual_state()

func deselect() -> void:
	is_selected = false
	_update_visual_state()

# Crew Assignment Functions

func can_assign_crew() -> bool:
	return assigned_crew.size() < max_crew_capacity

func assign_crew(crew_member: Node) -> bool:
	if not can_assign_crew():
		return false
	
	if crew_member in assigned_crew:
		return false  # Already assigned
	
	assigned_crew.append(crew_member)
	emit_signal("crew_assigned", crew_member)
	return true

func unassign_crew(crew_member: Node) -> bool:
	if crew_member not in assigned_crew:
		return false
	
	assigned_crew.erase(crew_member)
	emit_signal("crew_unassigned", crew_member)
	return true

func get_assigned_crew() -> Array[Node]:
	return assigned_crew.duplicate()

func is_crew_assigned(crew_member: Node) -> bool:
	return crew_member in assigned_crew

# Information and Status

func get_furniture_info() -> Dictionary:
	var info = {
		"name": furniture_type.name if furniture_type else "Unknown",
		"type": furniture_type.id if furniture_type else -1,
		"price": furniture_type.price if furniture_type else 0,
		"power_consumption": furniture_type.power_consumption if furniture_type else 0,
		"assigned_crew_count": assigned_crew.size(),
		"max_crew_capacity": max_crew_capacity,
		"rotation_state": rotation_state,
		"occupied_tiles": position_tiles.size(),
		"tile_positions": position_tiles.duplicate()
	}
	return info

func get_crew_assignment_info() -> Dictionary:
	var crew_info = []
	for crew in assigned_crew:
		if crew and is_instance_valid(crew):
			var crew_name = "Unknown"
			if crew.has_method("get_name"):
				crew_name = crew.get_name()
			elif crew.has_property("data") and crew.data and crew.data.has_property("name"):
				crew_name = crew.data.name
			elif crew.has_property("name"):
				crew_name = crew.name
			
			crew_info.append({
				"name": crew_name,
				"id": crew.get_instance_id(),
				"assigned_time": Time.get_unix_time_from_system()  # Could track actual assignment time
			})
	
	return {
		"assigned_crew": crew_info,
		"available_slots": max_crew_capacity - assigned_crew.size(),
		"utilization_percentage": (float(assigned_crew.size()) / max_crew_capacity) * 100.0
	}

# Utility Functions

func get_occupied_tiles() -> Array[Vector2i]:
	return position_tiles.duplicate()

func is_tile_occupied(tile_coord: Vector2i) -> bool:
	return tile_coord in position_tiles

func get_center_tile() -> Vector2i:
	if position_tiles.is_empty():
		return Vector2i.ZERO
	
	var center = Vector2i.ZERO
	for tile in position_tiles:
		center += tile
	
	return center / position_tiles.size()

func get_bounds() -> Dictionary:
	if position_tiles.is_empty():
		return {"min": Vector2i.ZERO, "max": Vector2i.ZERO}
	
	var min_pos = position_tiles[0]
	var max_pos = position_tiles[0]
	
	for tile in position_tiles:
		min_pos.x = min(min_pos.x, tile.x)
		min_pos.y = min(min_pos.y, tile.y)
		max_pos.x = max(max_pos.x, tile.x)
		max_pos.y = max(max_pos.y, tile.y)
	
	return {"min": min_pos, "max": max_pos}

func find_adjacent_tile() -> Vector2i:
	var adjacent_directions = [
		Vector2i(0, -1),  # North
		Vector2i(1, 0),   # East
		Vector2i(0, 1),   # South
		Vector2i(-1, 0),  # West
		Vector2i(1, -1),  # Northeast
		Vector2i(1, 1),   # Southeast
		Vector2i(-1, 1),  # Southwest
		Vector2i(-1, -1)  # Northwest
	]
	
	# Try to find an adjacent tile that's not occupied by furniture or other obstacles
	for direction in adjacent_directions:
		for tile in position_tiles:
			var adjacent_tile = tile + direction
			
			# Check if this adjacent tile is not occupied by the furniture itself
			if not is_tile_occupied(adjacent_tile):
				# Check if it's not occupied by other furniture (basic check)
				# TODO: Add collision detection with other furniture
				return adjacent_tile
	
	# If no adjacent tile found, return the first tile's position (fallback)
	return position_tiles[0] if position_tiles.size() > 0 else Vector2i.ZERO

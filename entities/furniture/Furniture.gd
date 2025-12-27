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

# Per-furniture reservation of exact access tiles for assigned crew
var _reserved_by_crew: Dictionary = {} # crew_id(String) -> Vector2i
var _reserved_by_tile: Dictionary = {} # tile_key(String) -> int (crew_id)

# Visual and interaction
var is_hovered: bool = false
var is_selected: bool = false
var is_preview: bool = false:
	set(value):
		is_preview = value
		if is_preview:
			# Disable collision for preview furniture
			var static_body = get_node_or_null("StaticBody2D")
			if static_body:
				static_body.set_collision_layer_value(1, false)
				static_body.set_collision_mask_value(1, false)
var is_valid_preview: bool = true
var hover_tween: Tween

func _ready():
	area.connect("input_event", self._on_area_input_event)
	area.connect("mouse_entered", self._on_mouse_entered)
	area.connect("mouse_exited", self._on_mouse_exited)
	# Hot-reload: when furniture types are reloaded, refresh our visuals if our type id still exists
	var rm = get_node_or_null("/root/ResourceManager")
	if rm and rm.has_signal("furniture_types_reloaded"):
		rm.furniture_types_reloaded.connect(_on_furniture_types_reloaded)

func initialize(furniture_type_data: FurnitureType, tiles: Array[Vector2i], rotation: int = 0) -> void:
	furniture_type = furniture_type_data
	position_tiles = tiles
	rotation_state = rotation
	max_crew_capacity = furniture_type.simultaneous_users
	
	# Set up collision shape to cover all occupied tiles
	_setup_collision_shape()
	
	# Set the furniture's position to the center of the occupied tiles
	_set_position_from_tiles()
	
	# Set up sprite representation instead of tiles
	_setup_sprite_representation()

func _setup_collision_shape() -> void:
	if not collision_shape or position_tiles.is_empty():
		return
	
	# Always compute collision footprint from actual occupied tiles so it matches click trigger
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
	
	# Calculate how many tiles in each direction
	var num_tiles_x = (max_x - min_x + 1)
	var num_tiles_y = (max_y - min_y + 1)
	
	# Build polygon from TileMap transforms to match the exact occupied tiles
	var tile_map = get_tree().get_first_node_in_group("navigation")
	var polygon_shape = ConvexPolygonShape2D.new()
	var points = PackedVector2Array()
	var shape_offset := Vector2.ZERO
	
	if tile_map and tile_map is TileMap:
		var anchor_local = tile_map.map_to_local(Vector2i(min_x, min_y))
		var anchor_global = tile_map.to_global(anchor_local)
		# Per-tile basis vectors in world space
		var right1_local = tile_map.map_to_local(Vector2i(min_x + 1, min_y))
		var right1_global = tile_map.to_global(right1_local)
		var down1_local = tile_map.map_to_local(Vector2i(min_x, min_y + 1))
		var down1_global = tile_map.to_global(down1_local)
		var ex = right1_global - anchor_global
		var ey = down1_global - anchor_global
		
		# Construct union-of-tiles diamond using per-tile basis
		var top = -0.5 * ex - 0.5 * ey
		var right = (float(num_tiles_x) - 0.5) * ex - 0.5 * ey
		var bottom = (float(num_tiles_x) - 0.5) * ex + (float(num_tiles_y) - 0.5) * ey
		var left = -0.5 * ex + (float(num_tiles_y) - 0.5) * ey
		
		points.append(top)
		points.append(right)
		points.append(bottom)
		points.append(left)
		shape_offset = Vector2.ZERO
	else:
		# Fallback using approximate iso half sizes
		var tile_half_width = 256.0
		var tile_half_height = 148.0
		var ex = Vector2(tile_half_width, tile_half_height)
		var ey = Vector2(-tile_half_width, tile_half_height)
		var top = -0.5 * ex - 0.5 * ey
		var right = (float(num_tiles_x) - 0.5) * ex - 0.5 * ey
		var bottom = (float(num_tiles_x) - 0.5) * ex + (float(num_tiles_y) - 0.5) * ey
		var left = -0.5 * ex + (float(num_tiles_y) - 0.5) * ey
		points.append(top)
		points.append(right)
		points.append(bottom)
		points.append(left)
		shape_offset = Vector2.ZERO

	polygon_shape.points = points
	collision_shape.shape = polygon_shape
	collision_shape.position = shape_offset
	collision_shape.rotation = 0
	
	# Also set up the StaticBody2D collision shape for crew collision
	var static_body = get_node("StaticBody2D")
	var static_collision = static_body.get_node("CollisionShape2D")
	if static_collision:
		var static_polygon_shape = ConvexPolygonShape2D.new()
		static_polygon_shape.points = points
		static_collision.shape = static_polygon_shape
		static_collision.position = shape_offset
		static_collision.rotation = 0

func _set_position_from_tiles() -> void:
	if position_tiles.is_empty():
		return
	
	# Find the top-left tile (minimum x and y coordinates)
	var min_x = position_tiles[0].x
	var min_y = position_tiles[0].y
	
	for tile in position_tiles:
		min_x = min(min_x, tile.x)
		min_y = min(min_y, tile.y)
	
	# Get the tile map to convert tile coordinates to world position
	var tile_map = get_tree().get_first_node_in_group("navigation")
	if tile_map and tile_map is TileMap:
		# Use TileMap's map_to_local to get the world position of the tile center
		var tile_center_local = tile_map.map_to_local(Vector2i(min_x, min_y))
		# Convert to global position
		var tile_center_global = tile_map.to_global(tile_center_local)
		
		# If this furniture is a child of a room, convert global to local
		if get_parent():
			global_position = tile_center_global
		else:
			position = tile_center_global
	else:
		# Fallback to manual calculation
		var tile_size = 64
		position = Vector2(min_x * tile_size, min_y * tile_size)
	
	# Depth sorting for isometric: use max(x+y) over occupied tiles
	# This guarantees items further down-right render above up-left ones
	z_as_relative = false
	var sort_key := position_tiles[0].x + position_tiles[0].y
	for tile in position_tiles:
		sort_key = max(sort_key, tile.x + tile.y)
	# Furniture slightly below crew (crew uses +25)
	z_index = sort_key + 22

func _setup_sprite_representation() -> void:
	# Get the sprite node
	var sprite = get_node("Sprite2D")
	if not sprite:
		push_error("Furniture scene missing Sprite2D node")
		return
	
	# Ensure sprite is centered
	sprite.centered = true
	
	# Load the appropriate texture based on furniture type and rotation
	var texture_path = _get_furniture_texture_path()
	if texture_path:
		sprite.texture = load(texture_path)
	
	# Set sprite position to true isometric center of occupied tiles
	# Compute the average of TileMap world centers of all occupied tiles,
	# then convert that to local coordinates relative to this Furniture node
	var tile_map = get_tree().get_first_node_in_group("navigation")
	var base_local: Vector2 = Vector2.ZERO
	if tile_map and tile_map is TileMap:
		var sum: Vector2 = Vector2.ZERO
		for tile in position_tiles:
			var tile_center_local: Vector2 = tile_map.map_to_local(tile)
			sum += tile_map.to_global(tile_center_local)
		var center_global: Vector2 = sum / float(position_tiles.size())
		base_local = to_local(center_global)
	else:
		# Fallback to approximate center using grid metrics
		var tile_size = 64
		var min_x = position_tiles[0].x
		var max_x = position_tiles[0].x
		var min_y = position_tiles[0].y
		var max_y = position_tiles[0].y
		for tile in position_tiles:
			min_x = min(min_x, tile.x)
			max_x = max(max_x, tile.x)
			min_y = min(min_y, tile.y)
			max_y = max(max_y, tile.y)
		var width_in_tiles = max_x - min_x + 1
		var height_in_tiles = max_y - min_y + 1
		base_local = Vector2(width_in_tiles * tile_size / 2.0, height_in_tiles * tile_size / 2.0)
	# Nudge up slightly to avoid overlap with floor
	base_local.y -= 25
	
	# Apply furniture-specific offsets based on type and rotation
	var furniture_offset = furniture_type.get_sprite_offset_for_rotation(rotation_state == 1)
	
	# Use furniture type offset if set, otherwise fall back to default positioning
	if furniture_offset != Vector2.ZERO:
		sprite.position = base_local + furniture_offset
	else:
		# Fallback to default positioning logic
		var offset_x = -100.0  # Move left by 100px
		var offset_y = 20.0    # Move down by 20px
		sprite.position = base_local + Vector2(offset_x, offset_y)
	
	# Scale sprite uniformly
	# All furniture sprites are 512x512 with perfect proportions
	# We scale uniformly to maintain aspect ratio and make them visible
	if sprite.texture:
		# Uniform scale - don't squish the sprite based on tile dimensions
		# The sprite already has the correct proportions for the furniture
		var uniform_scale = 1.6  # Scale factor for 512x512 sprites (will result in ~819x819 on screen)
		sprite.scale = Vector2(uniform_scale, uniform_scale)
	
	# No need to rotate sprite - we use different sprite files for different orientations

func _on_furniture_types_reloaded() -> void:
	# Find updated type by id and reapply offsets/texture
	var rm = get_node_or_null("/root/ResourceManager")
	if rm and rm.has_method("get_furniture_type_by_id") and furniture_type:
		var updated = rm.get_furniture_type_by_id(furniture_type.id)
		if updated:
			furniture_type = updated
			_setup_sprite_representation()
func _get_furniture_texture_path() -> String:
	# Map furniture types to their texture paths
	# bed_e = horizontal (east-west), bed_w = vertical (rotated)
	
	match furniture_type.id:
		1:  # Bed
			if furniture_type.supports_rotation and rotation_state == 1:
				return "res://assets/sprites/furniture/bed_e.png"  # bed_e is vertical (rotated)
			else:
				return "res://assets/sprites/furniture/bed_w.png"  # bed_w is horizontal (default)
		0:  # Canister
			return "res://assets/tilesets/mock_items_tileset.png"
		_:
			# Fallback to generic furniture texture
			return "res://assets/tilesets/mock_furniture_tileset.png"

func _on_area_input_event(viewport, event, shape_idx):
	# Don't handle input for preview furniture
	if is_preview:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("furniture_clicked")

func _on_mouse_entered():
	# Don't handle hover for preview furniture
	if is_preview:
		return
		
	is_hovered = true
	_update_visual_state()

func _on_mouse_exited():
	# Don't handle hover for preview furniture
	if is_preview:
		return
		
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
	if is_preview:
		# Preview state - show with reduced opacity
		if is_valid_preview:
			target_color = Global.COLOR_PREVIEW_VALID
		else:
			target_color = Global.COLOR_PREVIEW_INVALID
	elif is_selected:
		target_color = Global.COLOR_SELECTED_HIGHLIGHT
	elif is_hovered:
		target_color = Global.COLOR_HOVER_HIGHLIGHT
	else:
		target_color = Color.WHITE  # Normal color
	
	# Apply color directly to the Sprite2D so preview/hover tints are always visible
	var sprite := get_node_or_null("Sprite2D")
	if sprite:
		hover_tween.tween_property(sprite, "modulate", target_color, 0.2)
	else:
		# Fallback to tinting this node if sprite is missing
		hover_tween.tween_property(self, "modulate", target_color, 0.2)

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
	# Release any reserved access tile for this crew
	release_access_tile_for_crew(crew_member)
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
			elif crew.has_property("data") and crew.data != null and crew.data.has_property("name"):
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

# --- Reservation API for exact access tiles ---

func reserve_access_tile_for_crew(crew: Node, candidate_tiles: Array[Vector2i] = []) -> Vector2i:
	if crew == null:
		return Vector2i.ZERO
	var crew_key := str(crew.get_instance_id())
	# If already reserved, return existing
	if _reserved_by_crew.has(crew_key):
		return _reserved_by_crew[crew_key]

	# Build candidate list
	var grid := preload("res://scripts/utilities/NavGridProvider.gd").new()
	var targets := preload("res://scripts/utilities/FlowTargets.gd").new()
	var room: Room = get_parent() if (get_parent() is Room) else null

	var access_tiles: Array[Vector2i] = []
	if candidate_tiles != null and not candidate_tiles.is_empty():
		access_tiles = candidate_tiles.duplicate()
	else:
		access_tiles = targets.furniture_access_tiles(self)
		# Fallback 1: adjacent walkable tiles around furniture footprint
		if access_tiles.is_empty():
			var occupied_tiles: Array[Vector2i] = get_occupied_tiles()
			var adjacent_dirs := [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
			for occupied in occupied_tiles:
				for dir in adjacent_dirs:
					var candidate: Vector2i = occupied + dir
					if not occupied_tiles.has(candidate) and grid.is_walkable(candidate):
						if room == null or room.is_coord_in_room(candidate):
							access_tiles.append(candidate)
		# Fallback 2: door tiles of the room
		if access_tiles.is_empty() and room != null:
			access_tiles = targets.door_tiles(room)

	if access_tiles.is_empty():
		return Vector2i.ZERO

	# Filter candidates: walkable, nav-centered, not reserved, in same room, adjacent to furniture
	var candidates: Array[Vector2i] = []
	for tile in access_tiles:
		if not grid.is_walkable(tile):
			continue
		if not _is_nav_centered(tile):
			continue
		if _reserved_by_tile.has(_key(tile)):
			continue
		if room != null and not room.is_coord_in_room(tile):
			continue
		if not _is_adjacent_to_furniture(tile):
			continue
		candidates.append(tile)

	if candidates.is_empty():
		return Vector2i.ZERO

	# Pick tile closest to furniture center
	var best_tile := candidates[0]
	var best_dist := INF
	var furniture_center := _furniture_center_world()
	for candidate in candidates:
		var candidate_world := grid.tile_center_world(candidate)
		var dist := furniture_center.distance_to(candidate_world)
		if dist < best_dist:
			best_dist = dist
			best_tile = candidate

	# Reserve
	_reserved_by_crew[crew_key] = best_tile
	_reserved_by_tile[_key(best_tile)] = crew.get_instance_id()
	return best_tile

func release_access_tile_for_crew(crew: Node) -> void:
	if crew == null:
		return
	var crew_key := str(crew.get_instance_id())
	if not _reserved_by_crew.has(crew_key):
		return
	var tile: Vector2i = _reserved_by_crew[crew_key]
	_reserved_by_crew.erase(crew_key)
	_reserved_by_tile.erase(_key(tile))

# --- Helpers ---

func _key(tile: Vector2i) -> String:
	return str(tile.x) + ":" + str(tile.y)

func _is_nav_centered(tile: Vector2i) -> bool:
	var grid := preload("res://scripts/utilities/NavGridProvider.gd").new()
	var center := grid.tile_center_world(tile)
	return grid._is_on_navigation(center)

func _is_adjacent_to_furniture(tile: Vector2i) -> bool:
	var occupied_tiles: Array[Vector2i] = get_occupied_tiles()
	var adjacent_dirs := [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
	for occ in occupied_tiles:
		for dir in adjacent_dirs:
			if occ + dir == tile:
				return true
	return false

func _furniture_center_world() -> Vector2:
	var grid := preload("res://scripts/utilities/NavGridProvider.gd").new()
	var occupied_tiles: Array[Vector2i] = get_occupied_tiles()
	if occupied_tiles.is_empty():
		return global_position
	var sum := Vector2.ZERO
	for t in occupied_tiles:
		sum += grid.tile_center_world(t)
	return sum / float(occupied_tiles.size())

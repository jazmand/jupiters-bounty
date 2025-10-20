class_name FlowTargets
extends Node

# Computes target tiles for flow fields, e.g., furniture access tiles and room door tiles.
# It leverages existing logic for access-required sides and rotation used by FurnishingManager/FurnitureType.

func furniture_access_tiles(furniture: Furniture) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if furniture == null or furniture.furniture_type == null:
		return out

	var ft: FurnitureType = furniture.furniture_type
	
	
	# Determine required sides based on furniture's rotation
	var is_rotated := furniture.rotation_state == 1
	var required_sides: Array = []
	if is_rotated and ft.access_required_sides_rotated.size() > 0:
		required_sides = ft.access_required_sides_rotated.duplicate()
		
	else:
		# Transform base sides by rotation
		required_sides = _transform_sides_for_rotation(ft.access_required_sides, is_rotated)
		

	# Build quick lookup for occupied tiles
	var occupied := {}
	var tiles := furniture.get_occupied_tiles()
	
	for t in tiles:
		occupied[t] = true

	# Bounds for iteration
	var min_x: int = int(tiles[0].x)
	var max_x: int = int(tiles[0].x)
	var min_y: int = int(tiles[0].y)
	var max_y: int = int(tiles[0].y)
	for t in tiles:
		min_x = min(min_x, t.x)
		max_x = max(max_x, t.x)
		min_y = min(min_y, t.y)
		max_y = max(max_y, t.y)
	
	

	# For each side, collect all adjacent tiles along that side
	for side in required_sides:
		
		match side:
			"north":
				var north_y: int = min_y - 1
				for x in range(min_x, max_x + 1):
					var adjacent_tile := Vector2i(x, north_y)
					if not occupied.has(adjacent_tile) and _is_valid_access_tile(adjacent_tile, furniture):
						out.append(adjacent_tile)
			"south":
				var south_y: int = max_y + 1
				for x in range(min_x, max_x + 1):
					var adjacent_tile := Vector2i(x, south_y)
					if not occupied.has(adjacent_tile) and _is_valid_access_tile(adjacent_tile, furniture):
						out.append(adjacent_tile)
			"west":
				var west_x: int = min_x - 1
				for y in range(min_y, max_y + 1):
					var adjacent_tile := Vector2i(west_x, y)
					if not occupied.has(adjacent_tile) and _is_valid_access_tile(adjacent_tile, furniture):
						out.append(adjacent_tile)
			"east":
				var east_x: int = max_x + 1
				for y in range(min_y, max_y + 1):
					var adjacent_tile := Vector2i(east_x, y)
					if not occupied.has(adjacent_tile) and _is_valid_access_tile(adjacent_tile, furniture):
						out.append(adjacent_tile)
	# De-duplicate
	var unique_keys := {}
	var result: Array[Vector2i] = []
	for access_tile in out:
		var key := str(access_tile.x) + ":" + str(access_tile.y)
		if not unique_keys.has(key):
			unique_keys[key] = true
			result.append(access_tile)
	
	
	return result

func door_tiles(room: Room) -> Array[Vector2i]:
	if room == null or room.data == null:
		return []
	return room.data.door_tiles.duplicate()

func _is_valid_access_tile(tile: Vector2i, furniture: Furniture) -> bool:
	# Must be inside the containing room and not occupied by furniture
	var room := furniture.get_parent()
	if room == null or not (room is Room):
		
		return false
	if not room.is_coord_in_room(tile):
		
		return false
	# Avoid counting tiles already occupied by any furniture instance
	var fm_script := preload("res://scripts/utilities/NavGridProvider.gd")
	var grid := fm_script.new()
	var fm := grid._get_furnishing_manager()
	if fm != null:
		var here: Array = fm.get_furniture_at_tile(tile)
		if here != null and not here.is_empty():
				
			return false
	
	
	return true

func _transform_sides_for_rotation(sides: Array, is_rotated: bool) -> Array:
	if not is_rotated:
		return sides.duplicate()
	var mapping := {
		"north": "east",
		"east": "south",
		"south": "west",
		"west": "north"
	}
	var out: Array = []
	for s in sides:
		if mapping.has(s):
			out.append(mapping[s])
		else:
			out.append(s)
	return out



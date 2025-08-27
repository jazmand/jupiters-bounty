class_name Room extends Node2D

static var tile_to_id_map: Dictionary = {}

var data: RoomData

func _init() -> void:
	data = RoomData.new()

func set_data(
	id: int,
	room_type: RoomType, 
	top_left: Vector2i,
	bottom_right: Vector2i,
	door_tiles: Array[Vector2i]
	) -> void:
		data.id = id
		data.type = room_type
		data.top_left = top_left
		data.bottom_right = bottom_right
		data.door_tiles.append_array(door_tiles)
		add_room_to_id_map(id, top_left, bottom_right)

func add_room_to_id_map(id: int, top_left: Vector2i, bottom_right: Vector2i) -> void:
	var min_x: int = min(top_left.x, bottom_right.x)
	var min_y: int = min(top_left.y, bottom_right.y)
	for y in range(min_y, max(top_left.y, bottom_right.y) + 1):
		for x in range(min_x, max(top_left.x, bottom_right.x) + 1):
			tile_to_id_map[Vector2i(x, y)] = id

static func find_tile_room_id(tile_coords: Vector2i) -> int:
	return tile_to_id_map.get(tile_coords, 0)

static func calculate_room_price(price: int, tile_count: int) -> int:
	return price * tile_count

static func calculate_tile_count(vector1: Vector2, vector2: Vector2) -> int:
	return (abs(vector2.x - vector1.x) + 1) * (abs(vector2.y - vector1.y) + 1)

func can_assign_crew() -> bool:
	return data.assigned_crew_ids.size() < data.hot_spots.size()

func assign_crew(crew: CrewMember) -> Vector2:
	data.assigned_crew_ids.append(crew.data.id)
	return data.hot_spots[data.assigned_crew_ids.size() - 1]

# --- Room Drawing and Rendering ---

func draw_room() -> void:
	var min_x = min(data.top_left.x, data.bottom_right.x)
	var max_x = max(data.top_left.x, data.bottom_right.x) + 1
	var min_y = min(data.top_left.y, data.bottom_right.y)
	var max_y = max(data.top_left.y, data.bottom_right.y) + 1
	
	var tileset_mapper = {
		Vector2i(min_x, min_y): Vector2i(2, 0), # north corner
		Vector2i(min_x, max_y - 1): Vector2i(0, 3), # west corner
		Vector2i(max_x - 1, max_y - 1): Vector2i(3, 1), # south corner
		Vector2i(max_x - 1, min_y): Vector2i(1, 0), # east corner
	}
	
	# Add mappings for a range of y values between min_y and max_y - 1
	for y in range(min_y + 1, max_y - 1):
		tileset_mapper[Vector2i(min_x, y)] = Vector2i(1, 1) # north west
		tileset_mapper[Vector2i(max_x - 1, y)] = Vector2i(0, 2) # south east
	
	# Add mappings for a range of x values between min_x and max_x - 1
	for x in range(min_x + 1, max_x - 1):
		tileset_mapper[Vector2i(x, min_y)] = Vector2i(3, 0) # north east
		tileset_mapper[Vector2i(x, max_y - 1)] = Vector2i(2, 2) # south west
	
	# Find the matching room type and draw tiles
	for room_type in ResourceManager.room_types:
		if (room_type.id == data.type.id):
			# Use the temporary fix that was working
			var tileset_id = TileMapManager.BuildTileset.MOCK_ROOM # Generic room tileset
			
			# Iterate over the tiles within the room's boundaries and set them on the building layer
			for x in range(min_x, max_x):
				for y in range(min_y, max_y):
					var tileset_coords = Vector2i(0, 0)
					if tileset_mapper.has(Vector2i(x, y)):
						tileset_coords = tileset_mapper[Vector2i(x, y)]
					TileMapManager.set_building_cell(Vector2i(x, y), tileset_id, tileset_coords)
					TileMapManager.erase_base_cell(Vector2i(x, y)) # Required for navigation. Sets wall bounds.
			
			# Draw door tiles
			for door_tile in data.door_tiles:
				if door_tile.x == min_x:
					TileMapManager.set_building_cell(door_tile, tileset_id, Vector2i(2, 1))
				elif door_tile.x == max_x - 1:
					TileMapManager.set_building_cell(door_tile, tileset_id, Vector2i(1, 2))
				elif door_tile.y == min_y:
					TileMapManager.set_building_cell(door_tile, tileset_id, Vector2i(0, 1))
				elif door_tile.y == max_y - 1:
					TileMapManager.set_building_cell(door_tile, tileset_id, Vector2i(3, 2))
			
			break # Exit the loop after finding the matching room type

# --- Room Validation Methods ---

func is_coord_in_room(coords: Vector2i) -> bool:
	var min_x = min(data.top_left.x, data.bottom_right.x)
	var max_x = max(data.top_left.x, data.bottom_right.x)
	var min_y = min(data.top_left.y, data.bottom_right.y)
	var max_y = max(data.top_left.y, data.bottom_right.y)
	
	return coords.x >= min_x and coords.x <= max_x and coords.y >= min_y and coords.y <= max_y

func is_on_room_edge_and_not_corner(coords: Vector2i) -> bool:
	var min_x = min(data.top_left.x, data.bottom_right.x)
	var max_x = max(data.top_left.x, data.bottom_right.x)
	var min_y = min(data.top_left.y, data.bottom_right.y)
	var max_y = max(data.top_left.y, data.bottom_right.y)
	
	var is_x_on_edge = (coords.x == min_x or coords.x == max_x) and coords.y >= min_y and coords.y <= max_y
	var is_y_on_edge = (coords.y == min_y or coords.y == max_y) and coords.x >= min_x and coords.x <= max_x
	var is_on_corner = (coords.x == min_x or coords.x == max_x) and (coords.y == min_y or coords.y == max_y)
	
	return not is_on_corner and (is_x_on_edge or is_y_on_edge)

func is_blocking_door(coords: Vector2i) -> bool:
	for door_tile in data.door_tiles:
		if (abs(coords.x - door_tile.x) + abs(coords.y - door_tile.y)) == 1:
			return true
	return false

# --- Room Utility Methods ---

func get_room_bounds() -> Dictionary:
	return {
		"min_x": min(data.top_left.x, data.bottom_right.x),
		"max_x": max(data.top_left.x, data.bottom_right.x),
		"min_y": min(data.top_left.y, data.bottom_right.y),
		"max_y": max(data.top_left.y, data.bottom_right.y)
	}

func get_room_area() -> int:
	var bounds = get_room_bounds()
	return (bounds.max_x - bounds.min_x + 1) * (bounds.max_y - bounds.min_y + 1)

# --- Static Utility Methods for Managers ---

static func generate_unique_room_id(existing_rooms: Array) -> int:
	var unique_id = existing_rooms.size() + 1
	while check_room_id_exists(unique_id, existing_rooms):
		unique_id += 1
	return unique_id

static func check_room_id_exists(room_id: int, existing_rooms: Array) -> bool:
	return existing_rooms.any(func(room: Room): return room.data.id == room_id)

static func is_room_placement_valid(
	coords: Vector2i, 
	check_price_and_size: bool, 
	room_type: RoomType, 
	initial_tile_coords: Vector2i, 
	transverse_tile_coords: Vector2i,
	station_currency: int
) -> bool:
	# Check if outside station bounds
	var tile_data = TileMapManager.get_base_cell_tile_data(coords)
	if tile_data == null:
		return false
		
	# Check if on a non-buildable tile (see: tileset custom layer)
	elif tile_data and not tile_data.get_custom_data("is_buildable"):
		return false
		
	# Check if overlapping an existing room
	elif TileMapManager.is_building_cell_occupied(coords):
		return false
		
	# Check if price and size are permissible
	elif check_price_and_size:
		var tile_count = calculate_tile_count(initial_tile_coords, transverse_tile_coords)
		# Prevent skinny rooms
		var room_width = abs(transverse_tile_coords.x - initial_tile_coords.x) + 1
		var room_height = abs(transverse_tile_coords.y - initial_tile_coords.y) + 1
		
		if (calculate_room_price(room_type.price, tile_count) >= station_currency):
			return false
			
		if (tile_count < room_type.min_tiles or tile_count > room_type.max_tiles):
			return false
			
		if room_width <= 1 or room_height <= 1:
			return false
			
	return true

extends Node

## Centralized validation management for the game
## Eliminates scattered validation logic from other managers
## Provides a clean interface for all validation operations

# Signal for validation results
signal validation_failed(reason: String, details: Dictionary)
signal validation_succeeded(validation_type: String, details: Dictionary)

## Room Building Validation

func is_room_placement_valid(coords: Vector2i, check_price_and_size: bool = false, 
							room_type: RoomType = null, initial_coords: Vector2i = Vector2i.ZERO, 
							transverse_coords: Vector2i = Vector2i.ZERO) -> bool:
	"""
	Validates if a room can be placed at the given coordinates
	"""
	
	# Check if outside station bounds
	var tile_data = TileMapManager.get_base_cell_tile_data(coords)
	if tile_data == null:
		validation_failed.emit("out_of_bounds", {"coords": coords})
		return false
		
	# Check if on a non-buildable tile
	if tile_data && !tile_data.get_custom_data("is_buildable"):
		validation_failed.emit("non_buildable_tile", {"coords": coords, "tile_data": tile_data})
		return false
		
	# Check if overlapping an existing room
	if TileMapManager.is_building_cell_occupied(coords):
		validation_failed.emit("overlapping_room", {"coords": coords})
		return false
		
	# Check if blocking any existing doors
	if is_blocking_existing_door(coords):
		validation_failed.emit("blocking_door", {"coords": coords})
		return false
		
	# Check if price and size are permissible
	if check_price_and_size and room_type and initial_coords != Vector2i.ZERO and transverse_coords != Vector2i.ZERO:
		if not is_room_size_and_price_valid(room_type, initial_coords, transverse_coords):
			return false
			
	validation_succeeded.emit("room_placement", {"coords": coords})
	return true

func is_room_size_and_price_valid(room_type: RoomType, initial_coords: Vector2i, transverse_coords: Vector2i) -> bool:
	"""
	Validates room size and price constraints
	"""
	var tile_count = Room.calculate_tile_count(initial_coords, transverse_coords)
	var room_width = abs(transverse_coords.x - initial_coords.x) + 1
	var room_height = abs(transverse_coords.y - initial_coords.y) + 1
	
	# Check price
	var room_cost = Room.calculate_room_price(room_type.price, tile_count)
	if room_cost >= Global.station.currency:
		validation_failed.emit("insufficient_currency", {
			"required": room_cost, 
			"available": Global.station.currency,
			"tile_count": tile_count
		})
		return false
		
	# Check size constraints
	if tile_count < room_type.min_tiles or tile_count > room_type.max_tiles:
		validation_failed.emit("invalid_room_size", {
			"tile_count": tile_count,
			"min_tiles": room_type.min_tiles,
			"max_tiles": room_type.max_tiles
		})
		return false
		
	# Prevent skinny rooms
	if room_width <= 1 or room_height <= 1:
		validation_failed.emit("invalid_room_dimensions", {
			"width": room_width,
			"height": room_height
		})
		return false
		
	validation_succeeded.emit("room_size_price", {
		"tile_count": tile_count,
		"cost": room_cost,
		"width": room_width,
		"height": room_height
	})
	return true

func is_door_placement_valid(coords: Vector2i, room_initial_coords: Vector2i, room_transverse_coords: Vector2i) -> bool:
	"""
	Validates if a door can be placed at the given coordinates
	"""
	if not is_on_room_edge_and_not_corner(coords, room_initial_coords, room_transverse_coords):
		validation_failed.emit("invalid_door_position", {
			"coords": coords,
			"room_bounds": {"initial": room_initial_coords, "transverse": room_transverse_coords}
		})
		return false
		
	validation_succeeded.emit("door_placement", {"coords": coords})
	return true

func is_on_room_edge_and_not_corner(coords: Vector2i, initial_coords: Vector2i, transverse_coords: Vector2i) -> bool:
	"""
	Checks if coordinates are on the edge of a room but not on a corner
	"""
	var min_x = min(initial_coords.x, transverse_coords.x)
	var max_x = max(initial_coords.x, transverse_coords.x)
	var min_y = min(initial_coords.y, transverse_coords.y)
	var max_y = max(initial_coords.y, transverse_coords.y)
	
	var is_x_on_edge = (coords.x == min_x || coords.x == max_x) && coords.y >= min_y && coords.y <= max_y
	var is_y_on_edge = (coords.y == min_y || coords.y == max_y) && coords.x >= min_x && coords.x <= max_x
	var is_on_corner = (coords.x == min_x || coords.x == max_x) && (coords.y == min_y || coords.y == max_y)
	
	return !is_on_corner && (is_x_on_edge || is_y_on_edge)

func is_blocking_existing_door(coords: Vector2i) -> bool:
	"""
	Checks if the given coordinates would block any existing doors
	"""
	for room in Global.station.rooms:
		for door_tile in room.data.door_tiles:
			if (abs(coords.x - door_tile.x) + abs(coords.y - door_tile.y)) == 1:
				return true
	return false

## Furniture Placement Validation

func is_furniture_placement_valid(positions: Array[Vector2i], room_area: Array[Vector2i], 
								 furniture_type: FurnitureType, check_currency: bool = true) -> bool:
	"""
	Validates if furniture can be placed at the given positions
	"""
	# Check if all tiles are within the room
	if not are_tiles_in_room(positions, room_area):
		validation_failed.emit("furniture_outside_room", {
			"positions": positions,
			"room_area": room_area
		})
		return false
		
	# Check if tiles are already occupied
	if are_furniture_tiles_occupied(positions):
		validation_failed.emit("furniture_tiles_occupied", {
			"positions": positions
		})
		return false
		
	# Check currency if required
	if check_currency and not has_enough_currency(furniture_type.price):
		validation_failed.emit("insufficient_currency", {
			"required": furniture_type.price,
			"available": Global.station.currency,
			"furniture_type": furniture_type.name
		})
		return false
		
	validation_succeeded.emit("furniture_placement", {
		"positions": positions,
		"furniture_type": furniture_type.name
	})
	return true

func are_tiles_in_room(positions: Array[Vector2i], room_area: Array[Vector2i]) -> bool:
	"""
	Checks if all given positions are within the specified room area
	"""
	for pos in positions:
		if not room_area.has(pos):
			return false
	return true

func are_furniture_tiles_occupied(positions: Array[Vector2i]) -> bool:
	"""
	Checks if any of the given positions are already occupied by furniture
	"""
	for pos in positions:
		if TileMapManager.is_furniture_cell_occupied(pos):
			return true
	return false

func has_enough_currency(price: int) -> bool:
	"""
	Checks if the station has enough currency for a purchase
	"""
	return Global.station.currency >= price

## Utility Validation

func is_coord_in_bounds(coords: Vector2i) -> bool:
	"""
	Checks if coordinates are within the station bounds
	"""
	var tile_data = TileMapManager.get_base_cell_tile_data(coords)
	return tile_data != null

func is_coord_buildable(coords: Vector2i) -> bool:
	"""
	Checks if coordinates are on a buildable tile
	"""
	var tile_data = TileMapManager.get_base_cell_tile_data(coords)
	if not tile_data:
		return false
	return tile_data.get_custom_data("is_buildable") == true

## Room ID Validation

func is_room_id_unique(room_id: int) -> bool:
	"""
	Checks if a room ID is unique
	"""
	return !Global.station.rooms.any(func(room: Room): return room.data.id == room_id)

func generate_unique_room_id() -> int:
	"""
	Generates a unique room ID
	"""
	var unique_id = Global.station.rooms.size() + 1
	while not is_room_id_unique(unique_id):
		unique_id += 1
	return unique_id

## Furniture Position Calculation

func get_furniture_placement_positions(origin: Vector2i, furniture: FurnitureType) -> Array[Vector2i]:
	"""
	Calculates all tile positions needed for furniture placement
	"""
	var positions: Array[Vector2i] = []
	for y in range(furniture.height):
		for x in range(furniture.width):
			positions.append(origin + Vector2i(x, y))
	return positions

## Validation Result Helpers

func get_validation_error_message(error_type: String, details: Dictionary) -> String:
	"""
	Converts validation errors to user-friendly messages
	"""
	match error_type:
		"out_of_bounds":
			return "Cannot build outside station bounds"
		"non_buildable_tile":
			return "Cannot build on this type of tile"
		"overlapping_room":
			return "Cannot build overlapping existing room"
		"blocking_door":
			return "Cannot block existing door"
		"insufficient_currency":
			return "Not enough currency (need %d, have %d)" % [details.get("required", 0), details.get("available", 0)]
		"invalid_room_size":
			return "Room size must be between %d and %d tiles" % [details.get("min_tiles", 0), details.get("max_tiles", 0)]
		"invalid_room_dimensions":
			return "Room must be at least 2x2 tiles"
		"invalid_door_position":
			return "Door must be on room edge, not corner"
		"furniture_outside_room":
			return "Furniture must be placed inside room"
		"furniture_tiles_occupied":
			return "Furniture tiles are already occupied"
		_:
			return "Validation failed: " + error_type

## Performance Monitoring

var _validation_count: int = 0
var _validation_success_count: int = 0
var _validation_failure_count: int = 0

func get_validation_stats() -> Dictionary:
	"""
	Returns validation performance statistics
	"""
	return {
		"total_validations": _validation_count,
		"successful_validations": _validation_success_count,
		"failed_validations": _validation_failure_count,
		"success_rate": float(_validation_success_count) / max(_validation_count, 1) * 100.0
	}

func _on_validation_succeeded(validation_type: String, details: Dictionary) -> void:
	_validation_count += 1
	_validation_success_count += 1

func _on_validation_failed(reason: String, details: Dictionary) -> void:
	_validation_count += 1
	_validation_failure_count += 1

func _ready() -> void:
	# Connect to our own signals for statistics
	validation_succeeded.connect(_on_validation_succeeded)
	validation_failed.connect(_on_validation_failed)

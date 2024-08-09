# RoomBuilder.gd

class_name RoomBuilder
extends Node

signal action_completed(action: int)

var building_layer: int = 0
var drafting_layer: int = 1

var selection_tileset_id: int = 0
var drafting_tileset_id: int = 1
var invalid_tileset_id: int = 2
var mock_room_tileset_id: int = 3
var door_tileset_id: int = 4 # TEMPORARY. Door tiles will be included in room tilesets.

var initial_tile_coords = Vector2i()
var transverse_tile_coords = Vector2i()
var temp_door_coords: Array[Vector2i] = []

var any_invalid: bool = false

var selected_room_type: RoomType 

var base_tile_map: TileMap
var build_tile_map: TileMap
var room_types: Array[RoomType]

var popup_message: String = ""

enum Action {BACK, FORWARD, COMPLETE}

func _init(base_tile_map_node: TileMap, build_tile_map_node: TileMap, room_types_arr: Array[RoomType]) -> void:
	base_tile_map = base_tile_map_node
	build_tile_map = build_tile_map_node
	room_types = room_types_arr
	
	# TEMPORARY. Initial room.
	var new_room = Room.new()
	new_room.id = generate_unique_room_id()
	new_room.roomType = room_types[0];
	new_room.topLeft = Vector2i(18, -4)
	new_room.bottomRight = Vector2i(20, -5)
	set_doors(Vector2i(19, -4))
	new_room.doorTiles.append(Vector2i(19, -4))
	Global.station.add_room(new_room)
	draw_rooms()

func clear_selected_roomtype() -> void:
	selected_room_type = null # Deselect
	action_completed.emit(Action.BACK)

func stop_drafting() -> void:
	build_tile_map.clear_layer(drafting_layer)
	action_completed.emit(Action.BACK)

# --- Input functions ---

func selecting_tile(event: InputEventMouseButton, offset: Vector2, zoom: Vector2, current_room_type: RoomType) -> void:
	var coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	if !any_invalid:
		selected_room_type = current_room_type
		initial_tile_coords = coords
		action_completed.emit(Action.FORWARD)
		

func selecting_tile_motion(event: InputEventMouse, offset: Vector2, zoom: Vector2) -> void:
	var coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	select_tile(coords)

func drafting_room() -> void:
	if !any_invalid:
		action_completed.emit(Action.FORWARD)

func drafting_room_motion(event: InputEventMouseMotion, offset: Vector2, zoom: Vector2) -> void:
	transverse_tile_coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	draft_room(initial_tile_coords, transverse_tile_coords)

func setting_door(event: InputEventMouseButton, offset: Vector2, zoom: Vector2) -> void:
	temp_door_coords = []
	var coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	if is_on_room_edge_and_not_corner(coords):
		set_doors(coords)
		confirm_room_details()
	else:
		print("Door must be on the edge of the room")

func setting_door_motion(event: InputEventMouseMotion, offset: Vector2, zoom: Vector2) -> void:
	var coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	# Clear the previous door tile from the door_layer
	draft_room(initial_tile_coords, transverse_tile_coords)
	# Check if the tile is within the room and on the room's edge
	if is_on_room_edge_and_not_corner(coords):
		build_tile_map.set_cell(drafting_layer, coords, door_tileset_id, Vector2i(0, 0))

# -- Selection and drawing functions

func select_tile(coords: Vector2i) -> void:
	# Clear layer
	build_tile_map.clear_layer(drafting_layer)
	# Draw on tile
	if check_selection_valid(coords):
		build_tile_map.set_cell(drafting_layer, coords, selection_tileset_id, Vector2i(0, 0))
		any_invalid = false
	else:
		build_tile_map.set_cell(drafting_layer, coords, invalid_tileset_id, Vector2i(0, 0))
		any_invalid = true

func draft_room(initial_corner: Vector2i, opposite_corner: Vector2i) -> void:
	# Clear previous selection
	build_tile_map.clear_layer(drafting_layer)
	
	var min_x = min(initial_corner.x, opposite_corner.x)
	var max_x = max(initial_corner.x, opposite_corner.x) + 1
	var min_y = min(initial_corner.y, opposite_corner.y)
	var max_y = max(initial_corner.y, opposite_corner.y) + 1
	any_invalid = false
	
	# Check validity of all coordinates between initial and traverse corners
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var coords = Vector2(x, y)
			if !check_selection_valid(coords, true):
				any_invalid = true
				break  # If any tile is invalid, no need to continue checking
				
	# Redraw the entire selection based on whether any tile was invalid
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var coords = Vector2(x, y)
			var tileset_id
			if any_invalid:
				tileset_id = invalid_tileset_id
			else:
				tileset_id = drafting_tileset_id
			build_tile_map.set_cell(drafting_layer, coords, tileset_id, Vector2i(0, 0))

func set_doors(coords: Vector2i) -> void:
	temp_door_coords.append(coords)

func confirm_room_details() -> void:
	for room_type in room_types:
		if room_type.id == selected_room_type.id:
			var room_size = calculate_tile_count(initial_tile_coords, transverse_tile_coords)
			var room_cost_total = room_type.price * room_size
			popup_message = "Build " + room_type.name + " for " + str(room_cost_total)
			action_completed.emit(Action.FORWARD)

func confirm_build() -> void:
	save_room()
	draw_rooms()
	# Make deductions for buying rooms 
	Global.station.currency -= calculate_room_price()
	#print(Global.station.rooms, 'current rooms')
	action_completed.emit(Action.COMPLETE)

func cancel_build() -> void:
	stop_drafting()
	Global.station.rooms.pop_back()
	action_completed.emit(Action.COMPLETE)

func save_room() -> void:
	var new_room = Room.new()
	new_room.id = generate_unique_room_id()
	new_room.roomType = selected_room_type
	new_room.topLeft = initial_tile_coords
	new_room.bottomRight = transverse_tile_coords
	new_room.doorTiles = temp_door_coords
	Global.station.add_room(new_room)

func draw_rooms() -> void:
	# Clear drafting layer
	build_tile_map.clear_layer(drafting_layer)
	build_tile_map.clear_layer(building_layer)
	for room in Global.station.rooms:
		draw_room(room)
		
func draw_room(room) -> void:
	var min_x = min(room.topLeft.x, room.bottomRight.x)
	var max_x = max(room.topLeft.x, room.bottomRight.x) + 1
	var min_y = min(room.topLeft.y, room.bottomRight.y)
	var max_y = max(room.topLeft.y, room.bottomRight.y) + 1
	
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
	
	
	for room_type in room_types:
		if (room_type.id == room.roomType.id):
#			var tileset_id = room_type.tilesetId
			var tileset_id = mock_room_tileset_id # TEMPORARY
			# Iterate over the tiles within the room's boundaries and set them on the building layer
			for x in range(min_x, max_x):
				for y in range(min_y, max_y):
					var tileset_coords = Vector2i(0, 0)
					if tileset_mapper.has(Vector2i(x, y)):
						tileset_coords = tileset_mapper[Vector2i(x, y)]
					build_tile_map.set_cell(building_layer, Vector2(x, y), tileset_id, tileset_coords)
			for doorTile in room.doorTiles:
				if doorTile.x == min_x:
					build_tile_map.set_cell(building_layer, doorTile, tileset_id, Vector2(2, 1))
				elif doorTile.x == max_x - 1:
					build_tile_map.set_cell(building_layer, doorTile, tileset_id, Vector2(1, 2))
				elif doorTile.y == min_y:
					build_tile_map.set_cell(building_layer, doorTile, tileset_id, Vector2(0, 1)) 
				elif doorTile.y == max_y - 1:
					build_tile_map.set_cell(building_layer, doorTile, tileset_id, Vector2(3, 2))


# --- Helper functions ---

func check_selection_valid(coords: Vector2i, check_price_and_size: bool = false) -> bool:
	
	# Check if outside station bounds
	if !base_tile_map.get_cell_tile_data(0, coords) is TileData:
		return false
		
	# Check if overlapping an existing room
	elif build_tile_map.get_cell_tile_data(building_layer, coords) is TileData:
		return false
		
	# Check if blocking any existing doors
	elif is_blocking_door(coords):
		return false
		
	# Check if price and size are permissible
	elif check_price_and_size:
		var tile_count = calculate_tile_count(initial_tile_coords, transverse_tile_coords)
		# Prevent skinny rooms
		var room_width = abs(transverse_tile_coords.x - initial_tile_coords.x) + 1
		var room_height = abs(transverse_tile_coords.y - initial_tile_coords.y) + 1
		
		if (calculate_room_price() >= Global.station.currency):
			return false
			
		if (tile_count < selected_room_type.minTiles or tile_count > selected_room_type.maxTiles):
			return false
			
		if room_width <= 1 or room_height <=1:
			return false
			
	return true

func calculate_room_price() -> int:
	return selected_room_type.price * calculate_tile_count(initial_tile_coords, transverse_tile_coords)

func generate_unique_room_id() -> int:
	var unique_id = Global.station.rooms.size() + 1
	while check_room_id_exists(unique_id):
		unique_id += 1
	return unique_id

func check_room_id_exists(room_id: int) -> bool:
	return Global.station.rooms.any(func(room: Room): return room.id == room_id)

func calculate_tile_count(vector1: Vector2, vector2: Vector2) -> int:
	return (abs(vector2.x - vector1.x) + 1) * (abs(vector2.y - vector1.y) + 1)
	
func is_on_room_edge_and_not_corner(coords: Vector2i) -> bool:
	var min_x = min(initial_tile_coords.x, transverse_tile_coords.x)
	var max_x = max(initial_tile_coords.x, transverse_tile_coords.x)
	var min_y = min(initial_tile_coords.y, transverse_tile_coords.y)
	var max_y = max(initial_tile_coords.y, transverse_tile_coords.y)
	
	var is_x_on_edge = (coords.x == min_x || coords.x == max_x) && coords.y >= min_y && coords.y <= max_y
	var is_y_on_edge = (coords.y == min_y || coords.y == max_y) && coords.x >= min_x && coords.x <= max_x
	var is_on_corner = (coords.x == min_x || coords.x == max_x) && (coords.y == min_y || coords.y == max_y)
	
	return !is_on_corner && (is_x_on_edge || is_y_on_edge)

func is_blocking_door(coords: Vector2i) -> bool:
	for room in Global.station.rooms:
		for doorTile in room.doorTiles:
			if (abs(coords.x - doorTile.x) + abs(coords.y - doorTile.y)) == 1:
				return true
	return false
	

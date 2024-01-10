# RoomBuilder.gd

class_name RoomBuilder
extends Node2D

signal action_pressed(action: int)

var building_layer: int = 0
var drafting_layer: int = 1

var selection_tileset_id: int = 0
var drafting_tileset_id: int = 1
var invalid_tileset_id: int = 2
var door_tileset_id: int = 4 # TEMPORARY. Door tiles will be included in room tilesets.

var initial_tile_coords = Vector2i()
var transverse_tile_coords = Vector2i()

var any_invalid: bool = false

var selected_room_type_id: int = 0
var selected_room_type: RoomType 

var gui : Control
var build_menu : Control
var base_tile_map: TileMap
var build_tile_map: TileMap
var station: Station
var rooms: Array
var room_types: Array

var popup_message: String

enum Action {BACK, FORWARD, COMPLETE}

func _init(gui: Control, build_menu: Control, station: Station, base_tile_map: TileMap, build_tile_map: TileMap, rooms: Array, room_types: Array):
	self.gui = gui
	self.build_menu = build_menu
	self.station = station
	self.base_tile_map = base_tile_map
	self.build_tile_map = build_tile_map
	self.rooms = rooms
	self.room_types = room_types

func start_editing() -> void:
	selected_room_type = get_room_type_by_id(selected_room_type_id)	
	var new_room = Room.new()
	new_room.id = generate_unique_room_id()
	new_room.roomTypeId = selected_room_type.id
	rooms.append(new_room)

func stop_editing() -> void:
	selected_room_type_id = 0 # Deselect
	build_tile_map.clear_layer(drafting_layer)
	action_pressed.emit(Action.BACK)

# --- Input functions ---
func selecting_tile(event: InputEventMouseButton, offset: Vector2, zoom: Vector2, selected_room_type_id: int) -> void:
	var coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	if !any_invalid:
		self.selected_room_type_id = selected_room_type_id
		initial_tile_coords = coords
		start_editing()
		action_pressed.emit(Action.FORWARD)
		

func selecting_tile_motion(event: InputEventMouseMotion, offset: Vector2, zoom: Vector2) -> void:
	var coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	select_tile(coords)

func drafting_room() -> void:
	if !any_invalid:
		action_pressed.emit(Action.FORWARD)

func drafting_room_motion(event: InputEventMouseMotion, offset: Vector2, zoom: Vector2) -> void:
	transverse_tile_coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	draft_room(initial_tile_coords, transverse_tile_coords)

func setting_door(event: InputEventMouseButton, offset: Vector2, zoom: Vector2) -> void:
	var coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	if is_on_room_edge(coords):
		set_doors(coords)
		confirm_room_details()
	else:
		print("Door must be on the edge of the room")

func setting_door_motion(event: InputEventMouseMotion, offset: Vector2, zoom: Vector2) -> void:
	var coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	# Clear the previous door tile from the door_layer
	draft_room(initial_tile_coords, transverse_tile_coords)
	# Check if the tile is within the room and on the room's edge
	if is_on_room_edge(coords):
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

func set_room() -> void:
	var room = rooms[-1]
	room.topLeft = initial_tile_coords
	room.bottomRight = transverse_tile_coords

func set_doors(coords) -> void:
	var room = rooms[-1]
	room.doorTiles.append(coords)

func confirm_room_details() -> void:
	for room_type in room_types:
		if room_type.id == selected_room_type_id:
			var room_size = calculate_tile_count(initial_tile_coords, transverse_tile_coords)
			var room_cost_total = room_type.price * room_size
			popup_message = "Build " + room_type.name + " for " + str(room_cost_total)
			action_pressed.emit(Action.FORWARD)

func confirm_build() -> void:
	set_room()
	draw_rooms()
	# Make deductions for buying rooms 
	station.currency -= calculate_room_price()
	gui.update_resource("currency");	
	print(rooms, 'current rooms')
	action_pressed.emit(Action.COMPLETE)

func cancel_build() -> void:
	stop_editing()
	rooms.pop_back()
	action_pressed.emit(Action.COMPLETE)

func draw_rooms() -> void:
	# Clear drafting layer
	build_tile_map.clear_layer(drafting_layer)
	
	for room in rooms:
		var min_x = min(room.topLeft.x, room.bottomRight.x)
		var max_x = max(room.topLeft.x, room.bottomRight.x) + 1
		var min_y = min(room.topLeft.y, room.bottomRight.y)
		var max_y = max(room.topLeft.y, room.bottomRight.y) + 1
		for room_type in room_types:
			if (room_type.id == room.roomTypeId):
				var tileset_id = room_type.tilesetId
				# Iterate over the tiles within the room's boundaries and set them on the building layer
				for x in range(min_x, max_x):
					for y in range(min_y, max_y):
						build_tile_map.set_cell(building_layer, Vector2(x, y), tileset_id, Vector2i(0, 0))
		for doorTile in room.doorTiles:
			build_tile_map.set_cell(building_layer, doorTile, door_tileset_id, Vector2i(0, 0))

# --- Helper functions ---

func get_room_type_by_id(id):
	for room_type in room_types:
		if room_type.id == id:
			return room_type

func check_selection_valid(coords: Vector2i, check_price_and_size: bool = false) -> bool:
	var is_valid = true 
	
	# Check if outside station bounds
	if !base_tile_map.get_cell_tile_data(0, coords) is TileData:
		is_valid = false
		
	# Check if overlapping an existing room
	elif build_tile_map.get_cell_tile_data(building_layer, coords) is TileData:
		is_valid = false
		
	# Check if blocking any existing doors
	elif is_blocking_door(coords):
		is_valid = false
		
	# Check if price and size are permissible
	elif check_price_and_size:
		var tile_count = calculate_tile_count(initial_tile_coords, transverse_tile_coords)
		var room_width = abs(transverse_tile_coords.x - initial_tile_coords.x) + 1
		var room_height = abs(transverse_tile_coords.y - initial_tile_coords.y) + 1
		
		
		if (calculate_room_price() >= station.currency):
			print(calculate_room_price())
			is_valid = false
			
		if (tile_count < selected_room_type.minTiles or tile_count > selected_room_type.maxTiles):
			is_valid = false
			
		if room_width <= 1 or room_height <=1:
			is_valid = false
			
	return is_valid

func calculate_room_price() -> int:
	return selected_room_type.price * calculate_tile_count(initial_tile_coords, transverse_tile_coords)

func generate_unique_room_id() -> int:
	var unique_id = rooms.size() + 1
	while check_room_id_exists(unique_id):
		unique_id += 1
	return unique_id

func check_room_id_exists(room_id: int) -> bool:
	return room_id in rooms

func calculate_tile_count(vector1: Vector2, vector2: Vector2) -> int:
	return (abs(vector2.x - vector1.x) + 1) * (abs(vector2.y - vector1.y) + 1)
	
func is_on_room_edge(coords: Vector2i) -> bool:
	var min_x = min(initial_tile_coords.x, transverse_tile_coords.x)
	var max_x = max(initial_tile_coords.x, transverse_tile_coords.x)
	var min_y = min(initial_tile_coords.y, transverse_tile_coords.y)
	var max_y = max(initial_tile_coords.y, transverse_tile_coords.y)
	var is_x_on_edge = (coords.x == min_x || coords.x == max_x) && coords.y >= min_y && coords.y <= max_y
	var is_y_on_edge = (coords.y == min_y || coords.y == max_y) && coords.x >= min_x && coords.x <= max_x
	
	return is_x_on_edge || is_y_on_edge

func is_blocking_door(coords: Vector2i) -> bool:
	for room in rooms:
		for doorTile in room.doorTiles:
			if (abs(coords.x - doorTile.x) + abs(coords.y - doorTile.y)) == 1:
				return true
	return false
	

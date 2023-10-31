# RoomBuilder.gd

extends Node2D

class_name RoomBuilder

var building_layer: int = 0
var drafting_layer: int = 1

var selection_tileset_id: int = 0
var drafting_tileset_id: int = 1
var invalid_tileset_id: int = 2

var is_editing = false
var initial_tile_coords = Vector2i()
var transverse_tile_coords = Vector2i()
var any_invalid = false

var selected_room_type_id: int = 0

var base_tile_map: TileMap
var build_tile_map: TileMap
var rooms: Array
var room_types: Array

func _init(base_tile_map: TileMap, build_tile_map: TileMap, rooms: Array, room_types: Array):
	self.base_tile_map = base_tile_map
	self.build_tile_map = build_tile_map
	self.rooms = rooms
	self.room_types = room_types

func start_editing():
	is_editing = true

func stop_editing():
	is_editing = false
	selected_room_type_id = 0 # Deselect

func select_tile(coords: Vector2i):
	# Clear layer
	build_tile_map.clear_layer(drafting_layer)
	
	# Draw on tile
	if check_selection_valid(coords):
		build_tile_map.set_cell(drafting_layer, coords, selection_tileset_id, Vector2i(0, 0))
		any_invalid = false
	else:
		build_tile_map.set_cell(drafting_layer, coords, invalid_tileset_id, Vector2i(0, 0))
		any_invalid = true

func draft_room(initial_corner: Vector2i, opposite_corner: Vector2i):
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
			if !check_selection_valid(coords):
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

func set_room():	
	# Create a new Room instance and add it to the array
	var new_room = Room.new()
	new_room.id = generate_unique_room_id()
	new_room.roomTypeId = selected_room_type_id
	new_room.topLeft = initial_tile_coords
	new_room.bottomRight = transverse_tile_coords
	rooms.append(new_room)
	
	draw_rooms()
	print('Current rooms:', rooms)

func clear_all():
	is_editing = false
	selected_room_type_id = 0 # Deselect
	build_tile_map.clear_layer(drafting_layer)

func draw_rooms():
	# Clear drafting layer
	build_tile_map.clear_layer(drafting_layer)
	
	for room in rooms:
		var min_x = min(room.topLeft.x, room.bottomRight.x)
		var max_x = max(room.topLeft.x, room.bottomRight.x)
		var min_y = min(room.topLeft.y, room.bottomRight.y)
		var max_y = max(room.topLeft.y, room.bottomRight.y)
		
		var room_type_tileset_id = null
		for room_type in room_types:
			if room_type.id == room.roomTypeId:
				room_type_tileset_id = room_type.tilesetId
				break
		
		# Iterate over the tiles within the room's boundaries and set them on the building layer
		for x in range(min_x, max_x + 1):
			for y in range(min_y, max_y + 1):
				build_tile_map.set_cell(building_layer, Vector2(x, y), room_type_tileset_id, Vector2i(0, 0))

# --- Helper functions ---

func check_selection_valid(coords: Vector2i) -> bool:
	var is_valid = true 
	
	# Check if outside station bounds
	if !base_tile_map.get_cell_tile_data(0, coords) is TileData:
		is_valid = false
		
	# Check if overlapping an existing room
	elif build_tile_map.get_cell_tile_data(building_layer, coords) is TileData:
		is_valid = false
		
	# TODO: Check if size is within min & max range
	# TODO: Check if price is within budget
	
	return is_valid

func generate_unique_room_id() -> int:
	var unique_id = rooms.size() + 1
	while check_room_id_exists(unique_id):
		unique_id += 1
	return unique_id

func check_room_id_exists(room_id: int) -> bool:
	for room in rooms:
		if room.id == room_id:
			return true
	return false

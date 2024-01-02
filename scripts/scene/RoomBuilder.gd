# RoomBuilder.gd

extends Node2D

class_name RoomBuilder

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

enum State {
	SELECTING_TILE,
	DRAFTING_ROOM,
	SETTING_DOOR,
	CONFIRMING_ROOM
}
var state: int = State.SELECTING_TILE

func _init(gui: Control, build_menu: Control, station: Station, base_tile_map: TileMap, build_tile_map: TileMap, rooms: Array, room_types: Array):
	self.gui = gui
	self.build_menu = build_menu
	self.station = station
	self.base_tile_map = base_tile_map
	self.build_tile_map = build_tile_map
	self.rooms = rooms
	self.room_types = room_types

func start_editing() -> void:
	state = State.DRAFTING_ROOM
	selected_room_type = get_room_type_by_id(selected_room_type_id)	

func stop_editing() -> void:
	state = State.SELECTING_TILE
	selected_room_type_id = 0 # Deselect
	build_tile_map.clear_layer(drafting_layer)

# --- Input functions ---

func handle_building_input(event: InputEventMouse, offset: Vector2, zoom: Vector2, selected_room_type_id: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				1: on_left_mouse_button_press(event, offset, zoom, selected_room_type_id)
				2: on_right_mouse_button_press(event)
	elif event is InputEventMouseMotion:
		on_mouse_motion(event, offset, zoom)

func on_left_mouse_button_press(event: InputEventMouseButton, offset: Vector2, zoom: Vector2, selected_room_type_id: int) -> void:
	var coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	match state:
		State.SELECTING_TILE:
			if !any_invalid:
				self.selected_room_type_id = selected_room_type_id
				initial_tile_coords = coords
				start_editing()
		State.DRAFTING_ROOM:
			if !any_invalid:
				set_doors()
		State.SETTING_DOOR:
			if is_on_room_edge(coords):
				confirm_room_details()
			else:
				print("Door must be on the edge of the room")

func on_right_mouse_button_press(event: InputEventMouseButton) -> void:
	if state == State.DRAFTING_ROOM:
		stop_editing()
		
func on_mouse_motion(event: InputEvent, offset: Vector2, zoom: Vector2) -> void:
	var coords = base_tile_map.local_to_map((event.position / zoom) + offset)
	match state:
		State.SELECTING_TILE:
			select_tile(coords)
		State.DRAFTING_ROOM:
			transverse_tile_coords = coords
			draft_room(initial_tile_coords, transverse_tile_coords)
		State.SETTING_DOOR:
			# Clear the previous door tile from the door_layer
			draft_room(initial_tile_coords, transverse_tile_coords)
			# Check if the tile is within the room and on the room's edge
			if is_on_room_edge(coords):
				build_tile_map.set_cell(drafting_layer, coords, door_tileset_id, Vector2i(0, 0))
		State.CONFIRMING_ROOM:
			pass


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
	# Create a new Room instance and add it to the array
	var new_room = Room.new()
	new_room.id = generate_unique_room_id()
	new_room.roomTypeId = selected_room_type.id
	new_room.topLeft = initial_tile_coords
	new_room.bottomRight = transverse_tile_coords
	rooms.append(new_room)
	# Make deductions for buying rooms 
	station.currency -= calculate_room_price()
	gui.update_resource("currency");	

func set_doors() -> void:
	state = State.SETTING_DOOR

func confirm_room_details() -> void:
	state = State.CONFIRMING_ROOM
	for room_type in room_types:
		if room_type.id == selected_room_type_id:
			var room_size = calculate_tile_count(initial_tile_coords, transverse_tile_coords)
			var room_cost_total = room_type.price * room_size
			var popup_message = "Build " + room_type.name + " for " + str(room_cost_total)
			gui.show_popup("confirm_build", popup_message, confirm_build, cancel_build)

func confirm_build() -> void:
	set_room()
	draw_rooms()
	build_menu.build_mode = false
	print(rooms, 'current rooms')
	state = State.SELECTING_TILE

func cancel_build() -> void:
	stop_editing()
	state = State.SELECTING_TILE

func draw_rooms() -> void:
	# Clear drafting layer
	build_tile_map.clear_layer(drafting_layer)
	
	for room in rooms:
		var min_x = min(room.topLeft.x, room.bottomRight.x)
		var max_x = max(room.topLeft.x, room.bottomRight.x)
		var min_y = min(room.topLeft.y, room.bottomRight.y)
		var max_y = max(room.topLeft.y, room.bottomRight.y)
		for room_type in room_types:
			if (room_type.id == room.roomTypeId):
				var tileset_id = room_type.tilesetId
				# Iterate over the tiles within the room's boundaries and set them on the building layer
				for x in range(min_x, max_x + 1):
					for y in range(min_y, max_y + 1):
						build_tile_map.set_cell(building_layer, Vector2(x, y), tileset_id, Vector2i(0, 0))

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
	

# RoomBuilder.gd

extends Node2D

class_name RoomBuilder

var building_layer: int = 0
var drafting_layer: int = 1

var selection_tileset_id: int = 0
var drafting_tileset_id: int = 1
var invalid_tileset_id: int = 2

var is_editing = false
var is_confirming = false
var initial_tile_coords = Vector2i()
var transverse_tile_coords = Vector2i()
var any_invalid = false

var selected_room_type_id: int = 0
var selected_room_type: RoomType 

var gui : Control
var build_menu : Control
var station: Station
var base_tile_map: TileMap
var build_tile_map: TileMap
var rooms: Array
var room_types: Array

func _init(gui: Control, build_menu: Control, station: Station, base_tile_map: TileMap, build_tile_map: TileMap, rooms: Array, room_types: Array):
	self.gui = gui
	self.build_menu = build_menu
	self.station = station
	self.base_tile_map = base_tile_map
	self.build_tile_map = build_tile_map
	self.rooms = rooms
	self.room_types = room_types
	

func start_editing() -> void:
	is_editing = true
	selected_room_type = get_room_type_by_id(selected_room_type_id)	

func stop_editing() -> void:
	is_editing = false
	selected_room_type_id = 0 # Deselect
	build_tile_map.clear_layer(drafting_layer)

# --- Input functions ---

func handle_building_input(event: InputEvent, selected_room_type_id: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				1: on_left_mouse_button_press(event, selected_room_type_id)
				2: on_right_mouse_button_press(event)
	elif event is InputEventMouseMotion:
		on_mouse_motion(event)

func on_left_mouse_button_press(event: InputEvent, selected_room_type_id: int) -> void:
	if !is_editing:
		if !any_invalid:
			self.selected_room_type_id = selected_room_type_id
			initial_tile_coords = base_tile_map.local_to_map(event.position)
			start_editing()
	elif is_editing:
		if !any_invalid:
			confirm_room_details()

func on_right_mouse_button_press(event: InputEvent) -> void:
	if is_editing:
		stop_editing()
		
func on_mouse_motion(event: InputEvent) -> void:
	if is_editing && !is_confirming:
		transverse_tile_coords = base_tile_map.local_to_map(event.position)
		draft_room(initial_tile_coords, transverse_tile_coords)
	elif !is_editing:
		select_tile(base_tile_map.local_to_map(event.position))

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
	print("Money remaining: ", station.currency)
	
	draw_rooms()
	build_menu.build_mode = false
	print("Current rooms: ", rooms)

func confirm_room_details() -> void:
	is_confirming = true
	for room_type in room_types:
		if room_type.id == selected_room_type_id:
			var room_size = calculate_tile_count(initial_tile_coords, transverse_tile_coords)
			var room_cost_total = room_type.price * room_size
			var popup_message = "Build " + room_type.name + " for " + str(room_cost_total)
			gui.show_popup("confirm_build", popup_message, confirm_build, cancel_build)

func confirm_build() -> void:
	set_room()
	is_confirming = false

func cancel_build() -> void:
	stop_editing()
	is_confirming = false

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
	for room in rooms:
		if room.id == room_id:
			return true
	return false

func calculate_tile_count(vector1: Vector2, vector2: Vector2) -> int:
	var difference_x = abs(vector2.x - vector1.x) + 1 
	var difference_y = abs(vector2.y - vector1.y) + 1
	return difference_x * difference_y

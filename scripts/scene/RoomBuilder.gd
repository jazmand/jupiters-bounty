class_name RoomBuilder extends Node

const ROOM_SCENE: PackedScene = preload("res://room.tscn")

signal action_completed(action: int)
signal room_built(room_type, tiles)

@onready var base_tile_map: TileMap = %BaseTileMap
@onready var build_tile_map: TileMap = %BuildTileMap
@onready var furniture_tile_map: TileMap = %FurnitureTileMap
@onready var building_manager: BuildingManager = %BuildingManager

var drafting_layer: int = 0
var building_layer: int = 1

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

var base_tile_map_data: Dictionary = {}

var room_types: Array[RoomType]

var popup_title: String = ""
var popup_content: String = ""
var popup_yes_text: String = "Yes"
var popup_no_text: String = "No"

enum Action {BACK, FORWARD, COMPLETE}

func _ready() -> void:
	room_types = get_parent().room_types
	Global.station.rooms_updated.connect(draw_rooms)
	base_tile_map_data = save_base_tile_map_state()
	
	# TEMPORARY. Initial room.
	var _new_room = create_room(
		room_types[0],
		Vector2i(18, -4),
		Vector2i(20, -5),
		[Vector2i(19, -4)]
	)
	draw_rooms()

func create_room(
	room_type: RoomType,
	top_left: Vector2i,
	bottom_right: Vector2i,
	door_tiles: Array[Vector2i]
) -> Room:
	var new_room: Room = ROOM_SCENE.instantiate() as Room
	new_room.set_data(
		generate_unique_room_id(),
		room_type,
		top_left,
		bottom_right,
		door_tiles
	)
	Global.station.add_room(new_room)
	get_parent().add_child.call_deferred(new_room)
	return new_room

func clear_selected_roomtype() -> void:
	selected_room_type = null # Deselect
	action_completed.emit(Action.BACK)

func stop_drafting() -> void:
	build_tile_map.clear_layer(drafting_layer)
	action_completed.emit(Action.BACK)
	Global.hide_cursor_label.emit()
# --- Input functions ---

func selecting_tile(current_room_type: RoomType) -> void:
	var coords = base_tile_map.local_to_map(base_tile_map.get_global_mouse_position())
	if !any_invalid:
		selected_room_type = current_room_type
		initial_tile_coords = coords
		action_completed.emit(Action.FORWARD)
		

func selecting_tile_motion() -> void:
	var coords = base_tile_map.local_to_map(base_tile_map.get_global_mouse_position())
	select_tile(coords)
	

func drafting_room() -> void:
	if !any_invalid:
		action_completed.emit(Action.FORWARD)

func drafting_room_motion() -> void:
	transverse_tile_coords = base_tile_map.local_to_map(base_tile_map.get_global_mouse_position())
	draft_room(initial_tile_coords, transverse_tile_coords)
		
	var room_size = Room.calculate_tile_count(initial_tile_coords, transverse_tile_coords)
	var room_cost = selected_room_type.price * room_size
	var room_consumption = selected_room_type.power_consumption * room_size
	update_cursor_with_room_info(room_cost, room_consumption, base_tile_map.get_global_mouse_position())

func setting_door() -> void:
	temp_door_coords = []
	var coords = base_tile_map.local_to_map(base_tile_map.get_global_mouse_position())
	if is_on_room_edge_and_not_corner(coords):
		set_doors(coords)
		confirm_room_details()
	else:
		print("Door must be on the edge of the room")

func setting_door_motion() -> void:
	var coords = base_tile_map.local_to_map(base_tile_map.get_global_mouse_position())
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
				break # If any tile is invalid, no need to continue checking
				
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
	var room_size = Room.calculate_tile_count(initial_tile_coords, transverse_tile_coords)
	var room_cost = selected_room_type.price * room_size
	var room_width = abs(transverse_tile_coords.x - initial_tile_coords.x) + 1
	var room_height = abs(transverse_tile_coords.y - initial_tile_coords.y) + 1
	popup_title = "Confirm Construction"
	popup_content = "[b]Room Type: [/b]" + selected_room_type.name + "\n" + "[b]Dimensions: [/b]" + str(room_width) + "x" + str(room_height) + " tiles\n" + "[b]Cost: [/b]" + str(room_cost)
	action_completed.emit(Action.FORWARD)

func confirm_build() -> void:
	save_room()
	draw_rooms()
	# Make deductions for buying rooms
	var tile_count = Room.calculate_tile_count(initial_tile_coords, transverse_tile_coords)
	Global.station.currency -= Room.calculate_room_price(selected_room_type.price, tile_count)
	#print(Global.station.rooms, 'current rooms')
	action_completed.emit(Action.COMPLETE)

func cancel_build() -> void:
	stop_drafting()
	Global.station.rooms.pop_back()
	action_completed.emit(Action.COMPLETE)

func save_room() -> void:
	create_room(
		selected_room_type,
		initial_tile_coords,
		transverse_tile_coords,
		temp_door_coords
	)

func draw_rooms() -> void:
	# Clear drafting layer
	build_tile_map.clear_layer(drafting_layer)
	build_tile_map.clear_layer(building_layer)
	#furniture_tile_map.clear_layer(hotspot_layer)
	restore_base_tile_map_state()
	for room in Global.station.rooms:
		draw_room(room.data)
		
func draw_room(room) -> void:
	var min_x = min(room.top_left.x, room.bottom_right.x)
	var max_x = max(room.top_left.x, room.bottom_right.x) + 1
	var min_y = min(room.top_left.y, room.bottom_right.y)
	var max_y = max(room.top_left.y, room.bottom_right.y) + 1
	
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
		if (room_type.id == room.type.id):
#			var tileset_id = room_type.tileset_id
			var tileset_id = mock_room_tileset_id # TEMPORARY
			# Iterate over the tiles within the room's boundaries and set them on the building layer
			for x in range(min_x, max_x):
				for y in range(min_y, max_y):
					var tileset_coords = Vector2i(0, 0)
					if tileset_mapper.has(Vector2i(x, y)):
						tileset_coords = tileset_mapper[Vector2i(x, y)]
					build_tile_map.set_cell(building_layer, Vector2(x, y), tileset_id, tileset_coords)
					base_tile_map.erase_cell(0, Vector2i(x, y)) # Required for navigation. Sets wall bounds.
						
			for door_tile in room.door_tiles:
				if door_tile.x == min_x:
					build_tile_map.set_cell(building_layer, door_tile, tileset_id, Vector2(2, 1))
				elif door_tile.x == max_x - 1:
					build_tile_map.set_cell(building_layer, door_tile, tileset_id, Vector2(1, 2))
				elif door_tile.y == min_y:
					build_tile_map.set_cell(building_layer, door_tile, tileset_id, Vector2(0, 1))
				elif door_tile.y == max_y - 1:
					build_tile_map.set_cell(building_layer, door_tile, tileset_id, Vector2(3, 2))
					
			#for hotspot in room.hot_spots:
				#furniture_tile_map.set_cell(0, hotspot, 0, Vector2(0, 1)) # TEMPORARY
					
func save_base_tile_map_state() -> Dictionary:
	var tile_data = {}
	for x in range(base_tile_map.get_used_rect().position.x, base_tile_map.get_used_rect().position.x + base_tile_map.get_used_rect().size.x):
		for y in range(base_tile_map.get_used_rect().position.y, base_tile_map.get_used_rect().position.y + base_tile_map.get_used_rect().size.y):
			var coords = Vector2i(x, y)
			var cell_atlas_data = base_tile_map.get_cell_atlas_coords(0, coords)
			tile_data[coords] = cell_atlas_data
	return tile_data

func restore_base_tile_map_state() -> void:
	base_tile_map.clear()
	for coords in base_tile_map_data.keys():
		var atlas_coords = base_tile_map_data[coords]
		base_tile_map.set_cell(0, coords, 0, atlas_coords)

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
		var tile_count = Room.calculate_tile_count(initial_tile_coords, transverse_tile_coords)
		# Prevent skinny rooms
		var room_width = abs(transverse_tile_coords.x - initial_tile_coords.x) + 1
		var room_height = abs(transverse_tile_coords.y - initial_tile_coords.y) + 1
		
		if (Room.calculate_room_price(selected_room_type.price, tile_count) >= Global.station.currency):
			return false
			
		if (tile_count < selected_room_type.min_tiles or tile_count > selected_room_type.max_tiles):
			return false
			
		if room_width <= 1 or room_height <= 1:
			return false
			
	return true

func generate_unique_room_id() -> int:
	var unique_id = Global.station.rooms.size() + 1
	while check_room_id_exists(unique_id):
		unique_id += 1
	return unique_id

func check_room_id_exists(room_id: int) -> bool:
	return Global.station.rooms.any(func(room: Room): return room.data.id == room_id)
	
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
		for door_tile in room.data.door_tiles:
			if (abs(coords.x - door_tile.x) + abs(coords.y - door_tile.y)) == 1:
				return true
	return false

func update_cursor_with_room_info(room_cost: int, room_consumption: int, cursor_position: Vector2) -> void:
	var consumption_text = ""
	if room_consumption < 0:
		consumption_text = "Generates: " + str(-room_consumption) + "KW"
	else:
		consumption_text = "Consumes: " + str(room_consumption) + "KW"
	var label_text = "Cost: " + str(room_cost) + "\n" + consumption_text
	Global.update_cursor_label.emit(label_text, cursor_position)

func get_selected_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(min(initial_tile_coords.x, transverse_tile_coords.x), max(initial_tile_coords.x, transverse_tile_coords.x) + 1):
		for y in range(min(initial_tile_coords.y, transverse_tile_coords.y), max(initial_tile_coords.y, transverse_tile_coords.y) + 1):
			tiles.append(Vector2i(x, y))
	return tiles

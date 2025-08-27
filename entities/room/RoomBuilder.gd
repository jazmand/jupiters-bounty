class_name RoomBuilder extends Node

const ROOM_SCENE: PackedScene = preload("res://entities/room/room_scene.tscn")

signal action_completed(action: int)
signal room_built(room_type, tiles)

@onready var building_manager: BuildingManager = %BuildingManager


var initial_tile_coords = Vector2i()
var transverse_tile_coords = Vector2i()
var temp_door_coords: Array[Vector2i] = []

var any_invalid: bool = false

var selected_room_type: RoomType



var popup_title: String = ""
var popup_content: String = ""
var popup_yes_text: String = "Yes"
var popup_no_text: String = "No"

enum Action {BACK, FORWARD, COMPLETE}

func _ready() -> void:
	Global.station.rooms_updated.connect(draw_rooms)


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
	TileMapManager.clear_drafting_layer()
	action_completed.emit(Action.BACK)
	Global.hide_cursor_label.emit()
# --- Input functions ---

func selecting_tile(current_room_type: RoomType) -> void:
	var coords = TileMapManager.get_global_mouse_position()
	if !any_invalid:
		selected_room_type = current_room_type
		initial_tile_coords = coords
		action_completed.emit(Action.FORWARD)
		

func selecting_tile_motion() -> void:
	var coords = TileMapManager.get_global_mouse_position()
	select_tile(coords)
	

func drafting_room() -> void:
	if !any_invalid:
		action_completed.emit(Action.FORWARD)

func drafting_room_motion() -> void:
	transverse_tile_coords = TileMapManager.get_global_mouse_position()
	draft_room(initial_tile_coords, transverse_tile_coords)
		
	var room_size = Room.calculate_tile_count(initial_tile_coords, transverse_tile_coords)
	var room_cost = selected_room_type.price * room_size
	var room_consumption = selected_room_type.power_consumption * room_size
	update_cursor_with_room_info(room_cost, room_consumption, TileMapManager.base_tile_map.get_global_mouse_position())

func setting_door() -> void:
	temp_door_coords = []
	var coords = TileMapManager.get_global_mouse_position()
	if is_on_room_edge_and_not_corner(coords):
		set_doors(coords)
		confirm_room_details()
	else:
		print("Door must be on the edge of the room")

func setting_door_motion() -> void:
	var coords = TileMapManager.get_global_mouse_position()
	# Clear the previous door tile from the door_layer
	draft_room(initial_tile_coords, transverse_tile_coords)
	# Check if the tile is within the room and on the room's edge
	if is_on_room_edge_and_not_corner(coords):
		TileMapManager.set_drafting_cell(coords, TileMapManager.TilesetID.DOOR, Vector2i(0, 0))

# -- Selection and drawing functions

func select_tile(coords: Vector2i) -> void:
	# Clear layer
	TileMapManager.clear_drafting_layer()
	# Draw on tile
	if check_selection_valid(coords):
		TileMapManager.set_drafting_cell(coords, TileMapManager.TilesetID.SELECTION, Vector2i(0, 0))
		any_invalid = false
	else:
		TileMapManager.set_drafting_cell(coords, TileMapManager.TilesetID.INVALID, Vector2i(0, 0))
		any_invalid = true

func draft_room(initial_corner: Vector2i, opposite_corner: Vector2i) -> void:
	# Clear previous selection
	TileMapManager.clear_drafting_layer()
	
	var min_x = min(initial_corner.x, opposite_corner.x)
	var max_x = max(initial_corner.x, opposite_corner.x) + 1
	var min_y = min(initial_corner.y, opposite_corner.y)
	var max_y = max(initial_corner.y, opposite_corner.y) + 1
	any_invalid = false
	
	# Check validity of all coordinates between initial and traverse corners
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var coords = Vector2i(x, y)
			if !check_selection_valid(coords, true):
				any_invalid = true
				break # If any tile is invalid, no need to continue checking
				
	# Redraw the entire selection based on whether any tile was invalid
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var coords = Vector2i(x, y)
			var tileset_id
			if any_invalid:
				tileset_id = TileMapManager.TilesetID.INVALID
			else:
				tileset_id = TileMapManager.TilesetID.INVALID  # TODO: Update this (blue)
			TileMapManager.set_drafting_cell(coords, tileset_id, Vector2i(0, 0))

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
	var room = create_room(
		selected_room_type,
		initial_tile_coords,
		transverse_tile_coords,
		temp_door_coords
	)
	Global.selected_room = room

func draw_rooms() -> void:
	# Clear drafting layer
	TileMapManager.clear_drafting_layer()
	TileMapManager.clear_building_layer()
	#furniture_tile_map.clear_layer(hotspot_layer)
	TileMapManager.restore_base_tile_map_state()
	for room in Global.station.rooms:
		room.draw_room()
		


# --- Helper functions ---

func check_selection_valid(coords: Vector2i, check_price_and_size: bool = false) -> bool:
	# Use the new static method from Room class
	return Room.is_room_placement_valid(
		coords, 
		check_price_and_size, 
		selected_room_type, 
		initial_tile_coords, 
		transverse_tile_coords,
		Global.station.currency
	)

func generate_unique_room_id() -> int:
	# Use the new static method from Room class
	return Room.generate_unique_room_id(Global.station.rooms)

func is_on_room_edge_and_not_corner(coords: Vector2i) -> bool:
	# This function is now available on the Room class
	# For the current room being built, we need to calculate bounds here
	var min_x = min(initial_tile_coords.x, transverse_tile_coords.x)
	var max_x = max(initial_tile_coords.x, transverse_tile_coords.x)
	var min_y = min(initial_tile_coords.y, transverse_tile_coords.y)
	var max_y = max(initial_tile_coords.y, transverse_tile_coords.y)
	
	var is_x_on_edge = (coords.x == min_x or coords.x == max_x) and coords.y >= min_y and coords.y <= max_y
	var is_y_on_edge = (coords.y == min_y or coords.y == max_y) and coords.x >= min_x and coords.x <= max_x
	var is_on_corner = (coords.x == min_x or coords.x == max_x) and (coords.y == min_y or coords.y == max_y)
	
	return not is_on_corner and (is_x_on_edge or is_y_on_edge)

func is_blocking_existing_door(coords: Vector2i) -> bool:
	# Check if the coordinates block any existing room's door
	for room in Global.station.rooms:
		if room.is_blocking_door(coords):
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

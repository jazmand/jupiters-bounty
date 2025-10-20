class_name RoomBuilder extends Node

const ROOM_SCENE: PackedScene = preload("res://entities/room/room_scene.tscn")

signal action_completed(action: int)
signal room_built(room_type, tiles)

@onready var building_manager: BuildingManager = %BuildingManager
@onready var GUI: GUI = %GUI


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
	# Also clear any temporary door selections if we are backing out
	clear_temp_doors()
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
	var coords = TileMapManager.get_global_mouse_position()
	
	# Check if clicking on an existing door to remove it
	if temp_door_coords.has(coords):
		temp_door_coords.erase(coords)
		return
	
	# Calculate max allowed doors for current draft
	var room_size = Room.calculate_tile_count(initial_tile_coords, transverse_tile_coords)
	var max_doors = ValidationManager.calculate_required_doors(room_size)
	# Try to place a new door within limits
	if ValidationManager.is_door_placement_valid(coords, initial_tile_coords, transverse_tile_coords, temp_door_coords):
		if temp_door_coords.size() < max_doors:
			set_doors(coords)
		else:
			# Optional: feedback could be added here
			pass

func force_door_confirmation() -> void:
	# Do not auto-confirm if 0 doors; show tooltip but keep disabled
	if temp_door_coords.size() > 0:
		confirm_build()

func setting_door_motion() -> void:
	var coords = TileMapManager.get_global_mouse_position()
	# Clear the previous door tile from the door_layer
	draft_room(initial_tile_coords, transverse_tile_coords)
	
	# Draw all existing doors
	for door_coord in temp_door_coords:
		TileMapManager.set_building_drafting_cell(door_coord, TileMapManager.BuildTileset.DOOR, Vector2i(0, 0))
	
	# Check if the tile is within the room and on the room's edge
	if ValidationManager.is_door_placement_valid(coords, initial_tile_coords, transverse_tile_coords, temp_door_coords):
		TileMapManager.set_building_drafting_cell(coords, TileMapManager.BuildTileset.DOOR, Vector2i(0, 0))
	else:
		# Show invalid door placement
		TileMapManager.set_building_drafting_cell(coords, TileMapManager.BuildTileset.INVALID, Vector2i(0, 0))
	
	# Update cursor with door placement info
	update_cursor_with_door_info(coords)

# -- Selection and drawing functions

func select_tile(coords: Vector2i) -> void:
	# Clear layer
	TileMapManager.clear_drafting_layer()
	# Draw on tile
	if check_selection_valid(coords):
		TileMapManager.set_building_drafting_cell(coords, TileMapManager.BuildTileset.SELECTION, Vector2i(0, 0))
		any_invalid = false
	else:
		TileMapManager.set_building_drafting_cell(coords, TileMapManager.BuildTileset.INVALID, Vector2i(0, 0))
		any_invalid = true

func draft_room(initial_corner: Vector2i, opposite_corner: Vector2i) -> void:
	# Clear previous selection
	TileMapManager.clear_drafting_layer()
	
	var min_x = min(initial_corner.x, opposite_corner.x)
	var max_x = max(initial_corner.x, opposite_corner.x) + 1
	var min_y = min(initial_corner.y, opposite_corner.y)
	var max_y = max(initial_corner.y, opposite_corner.y) + 1
	any_invalid = false
	
	# OPTIMIZED: Single loop that checks validity AND draws tiles simultaneously
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var coords = Vector2i(x, y)
			var is_valid = check_selection_valid(coords, true)
			
			if !is_valid:
				any_invalid = true
			
			# Draw tile immediately with appropriate color
			var tileset_id = TileMapManager.BuildTileset.INVALID if any_invalid else TileMapManager.BuildTileset.SELECTION
			TileMapManager.set_building_drafting_cell(coords, tileset_id, Vector2i(0, 0))

func set_doors(coords: Vector2i) -> void:
	temp_door_coords.append(coords)

func confirm_room_details() -> void:
	var room_size = Room.calculate_tile_count(initial_tile_coords, transverse_tile_coords)
	var room_cost = selected_room_type.price * room_size
	var room_width = abs(transverse_tile_coords.x - initial_tile_coords.x) + 1
	var room_height = abs(transverse_tile_coords.y - initial_tile_coords.y) + 1
	var max_doors = ValidationManager.calculate_required_doors(room_size)
	
	popup_title = "Confirm Construction"
	popup_content = "[b]Room Type: [/b]" + selected_room_type.name + "\n" + \
					"[b]Dimensions: [/b]" + str(room_width) + "x" + str(room_height) + " tiles\n" + \
					"[b]Cost: [/b]" + str(room_cost) + "\n" + \
					"[b]Doors: [/b]" + str(temp_door_coords.size()) + " (max " + str(max_doors) + ")"
	action_completed.emit(Action.FORWARD)

func confirm_build() -> void:
	save_room()
	draw_rooms()
	# Navigation rebaking disabled - using physics-based path validation instead
	# if Global.station and Global.station.rooms_updated:
	#	Global.station.rooms_updated.emit()
	# Force all crew to recalculate their paths
	call_deferred("_force_crew_repath")
	# Make deductions for buying rooms
	var tile_count = Room.calculate_tile_count(initial_tile_coords, transverse_tile_coords)
	Global.station.currency -= Room.calculate_room_price(selected_room_type.price, tile_count)
	action_completed.emit(Action.COMPLETE)
	# Notify others that a room has been built
	room_built.emit(selected_room_type, get_selected_tiles())
	# Clear UI tooltip state after confirming
	if GUI and GUI.manager:
		GUI.manager.hide_room_confirm_tooltip()

func cancel_build() -> void:
	stop_drafting()
	Global.station.rooms.pop_back()
	action_completed.emit(Action.COMPLETE)
	if GUI and GUI.manager:
		GUI.manager.hide_room_confirm_tooltip()

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

func _force_crew_repath() -> void:
	# Force all crew members to recalculate their navigation paths
	var crew_members = get_tree().get_nodes_in_group("crew")
	for crew in crew_members:
		if crew.has_method("navigation_agent") and crew.navigation_agent:
			# Force the navigation agent to recalculate
			crew.navigation_agent.target_position = crew.navigation_agent.target_position

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

func update_cursor_with_door_info(coords: Vector2i) -> void:
	var room_size = Room.calculate_tile_count(initial_tile_coords, transverse_tile_coords)
	var max_doors = ValidationManager.calculate_required_doors(room_size)
	var placed_doors = temp_door_coords.size()
	
	var label_text = "Doors: " + str(placed_doors) + " (max " + str(max_doors) + ")"
	
	# Instruction text (doors optional; Enter to confirm anytime)
	label_text += "\nClick to place/remove doors\nPress Enter to confirm"
	
	# Add validation feedback
	if temp_door_coords.has(coords):
		label_text += "\nClick to remove door"
	elif not ValidationManager.is_door_placement_valid(coords, initial_tile_coords, transverse_tile_coords, temp_door_coords):
		label_text += "\nInvalid door position"
	
	Global.update_cursor_label.emit(label_text, TileMapManager.base_tile_map.get_global_mouse_position())

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

func clear_temp_doors() -> void:
	# Clear temporary door selections and drafting door visuals
	temp_door_coords.clear()
	TileMapManager.clear_drafting_layer()

func get_temp_door_count() -> int:
	return temp_door_coords.size()

func get_current_metrics() -> Dictionary:
	# Return dynamic metrics for the confirmation tooltip
	if selected_room_type == null or initial_tile_coords == Vector2i() or transverse_tile_coords == Vector2i():
		return {}
	var room_size := Room.calculate_tile_count(initial_tile_coords, transverse_tile_coords)
	var room_width: int = abs(transverse_tile_coords.x - initial_tile_coords.x) + 1
	var room_height: int = abs(transverse_tile_coords.y - initial_tile_coords.y) + 1
	var cost := selected_room_type.price * room_size
	var max_doors := ValidationManager.calculate_required_doors(room_size)
	return {
		"width": room_width,
		"height": room_height,
		"cost": cost,
		"doors": temp_door_coords.size(),
		"max_doors": max_doors
	}

func get_confirmation_anchor_screen_pos() -> Vector2:
	# Anchor near the last clicked corner (transverse_tile_coords), in screen space
	var build_tm := TileMapManager.build_tile_map
	if build_tm == null:
		return Vector2.ZERO
	
	# Calculate the drag direction to position popup away from the room
	var drag_direction = Vector2(transverse_tile_coords - initial_tile_coords).normalized()
	if drag_direction == Vector2.ZERO:
		drag_direction = Vector2(1, 0)  # Default to right if no drag
	
	# Position popup away from the room in the drag direction
	var offset_distance = 300.0  # Distance in pixels to offset from room
	var offset_tile = transverse_tile_coords + Vector2i(drag_direction * offset_distance / 256.0)
	
	var local := build_tm.map_to_local(offset_tile)
	var world := build_tm.to_global(local)
	# Convert world -> screen using the current canvas (camera) transform
	return get_viewport().get_canvas_transform() * world

class_name FurnishingManager extends Node

@onready var GUI: StationGUI = %GUI

@onready var base_tile_map: TileMap = %BaseTileMap
@onready var build_tile_map: TileMap = %BuildTileMap
@onready var furniture_tile_map: TileMap = %FurnitureTileMap

@onready var state_manager: StateChart = %StateManager

@onready var camera: Camera2D = %Camera

@onready var building_manager: BuildingManager = %BuildingManager

var furniture_types: Array[FurnitureType]
var selected_furnituretype: FurnitureType = null
var _current_room_area: Array[Vector2i] = []
var _current_room_type: RoomType = null

var drafting_layer: int = 0
var furnishing_layer: int = 1
var no_placement_layer: int = 2

var overlay_tileset_id = 1 #TEMPORARY

enum StateEvent {FURNISHING_STOP, FURNISHING_START, FURNISHING_BACK, FURNISHING_FORWARD}

const FURNISH_EVENTS = [&"furnishing_stop", &"furnishing_start", &"furnishing_back", &"furnishing_forward"]

func _init() -> void:
	load_furniture_types()
	
func _ready() -> void:
	building_manager.room_built.connect(start_furnishing)
	GUI.furniture_menu.action_completed.connect(on_furniture_menu_action)
	
	furniture_tile_map.set_layer_modulate(drafting_layer, Color(1, 1, 1, 0.5)) # Set drafting layer opacity to 50%
	
func load_furniture_types() -> void:
	var furniture_types_folder = "res://assets/furniture_type/"
	var furniture_type_files = DirAccess.open(furniture_types_folder)
	
	# Open the furniture types folder
	if furniture_type_files:
		# Iterate over each file in the folder
		furniture_type_files.list_dir_begin()
		var file_name = furniture_type_files.get_next()
		while file_name != "":
			var file_path = furniture_types_folder + file_name
			
			# Check if the file is a .tres resource
			if file_name.ends_with(".tres"):
				# Load the furniture type resource
				var furniture_type_resource = load(file_path)
				
				# Create an instance of the RoomType class
				var furniture_type_instance = FurnitureType.new()
				
				# Assign the property values to the instance
				furniture_type_instance.id = furniture_type_resource.id
				furniture_type_instance.name = furniture_type_resource.name
				furniture_type_instance.price = furniture_type_resource.price
				furniture_type_instance.power_consumption = furniture_type_resource.power_consumption
				furniture_type_instance.simultaneous_users = furniture_type_resource.simultaneous_users
				furniture_type_instance.height = furniture_type_resource.height
				furniture_type_instance.width = furniture_type_resource.width
				furniture_type_instance.tileset_id = furniture_type_resource.tileset_id
				furniture_type_instance.tileset_coords = furniture_type_resource.tileset_coords
				furniture_type_instance.valid_room_types = furniture_type_resource.valid_room_types
			
				# Add the furniture type instance to the list
				furniture_types.append(furniture_type_instance)
				
			file_name = furniture_type_files.get_next()
				
		furniture_type_files.list_dir_end()
	
func get_valid_furniture_for_room(room_type: RoomType) -> Array[FurnitureType]:
	var valid_furniture: Array[FurnitureType] = []
	for furniture in furniture_types:
		if room_type.id in furniture.valid_room_types:
			valid_furniture.append(furniture)
	return valid_furniture
		
func start_furnishing(room_type: RoomType, room_area: Array[Vector2i]) -> void:
	selected_furnituretype = null
	_current_room_area = room_area
	_current_room_type = room_type
	state_manager.send_event("furnishing_start")

func on_furniture_menu_action(action: int, clicked_furnituretype: FurnitureType) -> void:
	var event: String
	match action:
		GUI.furniture_menu.Action.CLOSE:
			event = FURNISH_EVENTS[StateEvent.FURNISHING_STOP]
		GUI.furniture_menu.Action.OPEN:
			event = FURNISH_EVENTS[StateEvent.FURNISHING_START]
		GUI.furniture_menu.Action.SELECT_FURNITURE:
			selected_furnituretype = clicked_furnituretype
			event = FURNISH_EVENTS[StateEvent.FURNISHING_FORWARD]
	state_manager.send_event(event)
			

func _on_selecting_furniture_state_entered():
	if _current_room_area == null:
		_current_room_area = [Global.selected_room.top_left, Global.selected_room.bottom_right]
	if _current_room_type == null:
		_current_room_type = Global.selected_room.data.type
	GUI.furniture_menu.show_furniture_panel(get_valid_furniture_for_room(_current_room_type))
	GUI.room_info_panel.open(Global.selected_room)
	show_invalid_overlay()

func _on_selecting_furniture_state_input(event):
	if event.is_action_pressed("cancel"):
		state_manager.send_event(FURNISH_EVENTS[StateEvent.FURNISHING_STOP])

func _on_selecting_furniture_state_exited() -> void:
	GUI.furniture_menu.hide_furniture_panel()
	hide_invalid_overlay()

func _on_placing_furniture_state_entered() -> void:
	show_invalid_overlay()

func _on_placing_furniture_state_input(event):
	if event.is_action_pressed("select"):
		place_furniture(event)
	elif event.is_action_pressed("cancel") or event.is_action_pressed("exit"):
		state_manager.send_event(FURNISH_EVENTS[StateEvent.FURNISHING_STOP])

func _on_placing_furniture_state_processing(delta) -> void:
	if selected_furnituretype == null:
		return
	
	update_furniture_preview()

func _on_placing_furniture_state_exited() -> void:
	hide_invalid_overlay()
	furniture_tile_map.clear_layer(drafting_layer)

func update_furniture_preview() -> void:
	furniture_tile_map.clear_layer(drafting_layer)

	var origin = furniture_tile_map.local_to_map(furniture_tile_map.get_global_mouse_position())
	var positions = get_placement_positions_from_origin(origin, selected_furnituretype)

	if positions.size() != selected_furnituretype.tileset_coords.size():
		return

	for i in positions.size():
		var tile_pos = positions[i]
		var tile_coord = selected_furnituretype.tileset_coords[i]
		furniture_tile_map.set_cell(drafting_layer, tile_pos, selected_furnituretype.tileset_id, tile_coord)


func place_furniture(event: InputEvent) -> void:
	if selected_furnituretype == null:
		print("No furniture selected")
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var origin = furniture_tile_map.local_to_map(furniture_tile_map.get_global_mouse_position())
		var positions = get_placement_positions_from_origin(origin, selected_furnituretype)

		if positions.size() != selected_furnituretype.tileset_coords.size():
			print("Tileset_coords size does not match width × height")
			return

		if !are_tiles_in_room(positions):
			print("Some tiles are outside the room area")
			return

		if are_tiles_occupied(positions):
			print("Some tiles are already occupied")
			return

		if not has_enough_currency(selected_furnituretype.price):
			print("Not enough currency to place this furniture")
			return

		# Place each tile of the furniture
		for i in positions.size():
			var world_tile = positions[i]
			var tileset_coord = selected_furnituretype.tileset_coords[i]
			furniture_tile_map.set_cell(furnishing_layer, world_tile, selected_furnituretype.tileset_id, tileset_coord)

		Global.station.currency -= selected_furnituretype.price
		print("Placed %s. Remaining currency: %d" % [selected_furnituretype.name, Global.station.currency])

func are_tiles_in_room(positions: Array[Vector2i]) -> bool:
	for pos in positions:
		if not _current_room_area.has(pos):
			return false
	return true

func are_tiles_occupied(positions: Array[Vector2i]) -> bool:
	for pos in positions:
		if furniture_tile_map.get_cell_source_id(furnishing_layer, pos) != -1:
			return true
	return false

func has_enough_currency(price: int) -> bool:
	return Global.station.currency >= price

func get_placement_positions_from_origin(origin: Vector2i, furniture: FurnitureType) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for y in range(furniture.height):
		for x in range(furniture.width):
			positions.append(origin + Vector2i(x, y))
	return positions

func show_invalid_overlay():
	furniture_tile_map.clear_layer(no_placement_layer)

	if _current_room_area.is_empty():
		return

	var all_station_tiles := base_tile_map.get_used_cells(0)
	var built_tiles := build_tile_map.get_used_cells(1) # Rooms are on layer 1 of build_tile_map

	var combined_tiles := all_station_tiles.duplicate()
	for pos in built_tiles:
		if not combined_tiles.has(pos):
			combined_tiles.append(pos)

	for pos in combined_tiles:
		if not _current_room_area.has(pos):
			furniture_tile_map.set_cell(no_placement_layer, pos, overlay_tileset_id, Vector2i(0, 0))

func hide_invalid_overlay():
	furniture_tile_map.clear_layer(no_placement_layer)




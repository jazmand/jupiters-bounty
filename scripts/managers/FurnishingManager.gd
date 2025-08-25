class_name FurnishingManager extends Node

@onready var GUI: GUI = %GUI

# Use centralized tile map manager instead of direct references

@onready var state_manager: StateChart = %StateManager

@onready var camera: Camera2D = %Camera

@onready var building_manager: BuildingManager = %BuildingManager

var selected_furnituretype: FurnitureType = null
var _current_room_area: Array[Vector2i] = []
var _current_room_type: RoomType = null

# Use centralized tile map manager layer constants

enum StateEvent {FURNISHING_STOP, FURNISHING_START, FURNISHING_BACK, FURNISHING_FORWARD}

const FURNISH_EVENTS = [&"furnishing_stop", &"furnishing_start", &"furnishing_back", &"furnishing_forward"]

func _ready() -> void:
	building_manager.room_built.connect(start_furnishing)
	GUI.furniture_menu.action_completed.connect(on_furniture_menu_action)
	
	# TileMapManager will be initialised by GameManager
	

	
func get_valid_furniture_for_room(room_type: RoomType) -> Array[FurnitureType]:
	return ResourceManager.get_valid_furniture_for_room(room_type)
		
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
	# No need to show invalid overlay - furniture preview will show validity

func _on_selecting_furniture_state_input(event):
	if event.is_action_pressed("cancel"):
		state_manager.send_event(FURNISH_EVENTS[StateEvent.FURNISHING_STOP])

func _on_selecting_furniture_state_exited() -> void:
	GUI.furniture_menu.hide_furniture_panel()
	GUI.room_info_panel.close()

func _on_placing_furniture_state_entered() -> void:
	GUI.room_info_panel.open(Global.selected_room)

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
	TileMapManager.clear_furniture_drafting_layer()
	GUI.room_info_panel.close() 

func update_furniture_preview() -> void:
	TileMapManager.clear_furniture_drafting_layer()

	var origin = TileMapManager.get_global_mouse_position_for_tilemap(TileMapManager.furniture_tile_map)
	var positions = get_placement_positions_from_origin(origin, selected_furnituretype)

	if positions.size() != selected_furnituretype.tileset_coords.size():
		return

	# Always show the furniture preview
	for i in positions.size():
		var tile_pos = positions[i]
		var tile_coord = selected_furnituretype.tileset_coords[i]
		TileMapManager.set_furniture_drafting_cell(tile_pos, selected_furnituretype.tileset_id, tile_coord)
	



func place_furniture(event: InputEvent) -> void:
	if selected_furnituretype == null:
		print("No furniture selected")
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var origin = TileMapManager.get_global_mouse_position_for_tilemap(TileMapManager.furniture_tile_map)
		var positions = get_placement_positions_from_origin(origin, selected_furnituretype)

		if positions.size() != selected_furnituretype.tileset_coords.size():
			print("Tileset_coords size does not match width × height")
			return

		if not is_furniture_placement_valid(positions):
			print("Invalid furniture placement")
			return

		# Place each tile of the furniture
		for i in positions.size():
			var world_tile = positions[i]
			var tileset_coord = selected_furnituretype.tileset_coords[i]
			TileMapManager.set_furniture_cell(world_tile, selected_furnituretype.tileset_id, tileset_coord)

		Global.station.currency -= selected_furnituretype.price
		print("Placed %s. Remaining currency: %d" % [selected_furnituretype.name, Global.station.currency])

func are_tiles_in_room(positions: Array[Vector2i]) -> bool:
	for pos in positions:
		if not _current_room_area.has(pos):
			return false
	return true

func are_tiles_occupied(positions: Array[Vector2i]) -> bool:
	for pos in positions:
		if TileMapManager.is_furniture_cell_occupied(pos):
			return true
	return false

func has_enough_currency(price: int) -> bool:
	return Global.station.currency >= price

func is_furniture_placement_valid(positions: Array[Vector2i]) -> bool:
	# Check if furniture placement is valid at the given positions
	return are_tiles_in_room(positions) and not are_tiles_occupied(positions) and has_enough_currency(selected_furnituretype.price)



func get_placement_positions_from_origin(origin: Vector2i, furniture: FurnitureType) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for y in range(furniture.height):
		for x in range(furniture.width):
			positions.append(origin + Vector2i(x, y))
	return positions

func show_invalid_overlay():
	TileMapManager.clear_furniture_overlay_layer()

	if _current_room_area.is_empty():
		return

	var all_station_tiles := TileMapManager.get_used_cells(TileMapManager.Layer.BASE)
	var built_tiles := TileMapManager.get_used_cells(TileMapManager.Layer.BUILDING) # Rooms are on layer 1 of build_tile_map

	var combined_tiles := all_station_tiles.duplicate()
	for pos in built_tiles:
		if not combined_tiles.has(pos):
			combined_tiles.append(pos)

	for pos in combined_tiles:
		if not _current_room_area.has(pos):
			TileMapManager.set_furniture_overlay_cell(pos, TileMapManager.TilesetID.OVERLAY, Vector2i(0, 0))

func hide_invalid_overlay():
	TileMapManager.clear_furniture_overlay_layer()




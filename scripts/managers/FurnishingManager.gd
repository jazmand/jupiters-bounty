class_name FurnishingManager extends Node

@onready var GUI: GUI = %GUI

@onready var base_tile_map: TileMap = %BaseTileMap
@onready var build_tile_map: TileMap = %BuildTileMap
# Note: furniture_tile_map is accessed through TileMapManager instead of @onready


@onready var camera: Camera2D = %Camera

@onready var building_manager: BuildingManager = %BuildingManager
@onready var game_manager: GameManager = get_parent()

var selected_furnituretype: FurnitureType = null
var _current_room_area: Array[Vector2i] = []
var _current_room_type: RoomType = null

var drafting_layer: int = 0
var furnishing_layer: int = 1
var no_placement_layer: int = 2
var overlay_tileset_id: int = 1 #TEMPORARY

# Furniture Instance Management
var _furniture_instances: Array[Furniture] = []
var _furniture_instance_map: Dictionary = {}  # Maps tile positions to Array[Furniture]
var _furniture_scene: PackedScene = preload("res://entities/furniture/furniture_scene.tscn")

enum StateEvent {FURNISHING_STOP, FURNISHING_START, FURNISHING_BACK, FURNISHING_FORWARD}

const FURNISH_EVENTS = [&"furnishing_stop", &"furnishing_start", &"furnishing_back", &"furnishing_forward"]

func _ready() -> void:
	building_manager.room_built.connect(start_furnishing)
	# TODO: Connect to room destruction signal when BuildingManager provides it
	# building_manager.room_destroyed.connect(cleanup_room_furniture)
	GUI.furniture_menu.action_completed.connect(on_furniture_menu_action)
	
	# Note: Layer modulate will be set up when tile maps become available

func _setup_layer_modulate() -> void:
	# Set the drafting layer opacity once the tile maps are ready
	if TileMapManager.furniture_tile_map:
		TileMapManager.furniture_tile_map.set_layer_modulate(drafting_layer, Color(1, 1, 1, 0.5)) # Set drafting layer opacity to 50%

func get_valid_furniture_for_room(room_type: RoomType) -> Array[FurnitureType]:
	return ResourceManager.get_valid_furniture_for_room(room_type)
		
func start_furnishing(room_type: RoomType, room_area: Array[Vector2i]) -> void:
	selected_furnituretype = null
	_current_room_area = room_area
	_current_room_type = room_type
	_furniture_rotation = 0  # Reset rotation state when starting furnishing

	# Set up layer modulate now that we're starting furnishing (tile maps should be ready)
	_setup_layer_modulate()

	game_manager.state_manager.send_event(FURNISH_EVENTS[StateEvent.FURNISHING_START])

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
		_:
			return

	game_manager.state_manager.send_event(event)
			

func _on_selecting_furniture_state_entered() -> void:
	# Reset rotation when starting to select furniture
	_furniture_rotation = 0

	_current_room_area = [Global.selected_room.data.top_left, Global.selected_room.data.bottom_right]
	if _current_room_type == null:
		_current_room_type = Global.selected_room.data.type

	# Show furniture menu and room info panel (only in selecting furniture state)
	GUI.furniture_menu.show_furniture_panel(get_valid_furniture_for_room(_current_room_type))
	GUI.room_info_panel.open(Global.selected_room)
	show_invalid_overlay()

func _on_selecting_furniture_state_input(event):
	if event.is_action_pressed("cancel"):
		game_manager.state_manager.send_event(FURNISH_EVENTS[StateEvent.FURNISHING_STOP])
		# Note: Select/click handling is now done globally in GameManager._input()

func _on_selecting_furniture_state_exited() -> void:
	GUI.furniture_menu.hide_furniture_panel()
	# Close RoomInfoPanel when exiting selecting furniture state
	GUI.room_info_panel.close()
	hide_invalid_overlay()

func _on_placing_furniture_state_entered() -> void:
	# RoomInfoPanel should only be open in selecting furniture state, not placing furniture
	show_invalid_overlay()

func _on_placing_furniture_state_input(event):
	if event.is_action_pressed("cancel") or event.is_action_pressed("exit"):
		game_manager.state_manager.send_event(FURNISH_EVENTS[StateEvent.FURNISHING_STOP])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate_furniture"):  # "R" key
		rotate_furniture()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("select"):
		place_furniture(event)
		# Always mark select events as handled in PlacingFurniture state
		# to prevent them from bubbling up to global input handler
		get_viewport().set_input_as_handled()

func rotate_furniture() -> void:
	if selected_furnituretype and selected_furnituretype.supports_rotation:
		# Toggle between normal (0) and rotated (1) states
		_furniture_rotation = (_furniture_rotation + 1) % 2
		
		# Force an immediate preview update to show the rotation instantly
		update_furniture_preview()

func _on_placing_furniture_state_processing(delta) -> void:
	if selected_furnituretype == null:
		return

	update_furniture_preview()

func _on_placing_furniture_state_exited() -> void:
	TileMapManager.clear_furniture_drafting_layer()

	# Restore the drafting layer opacity to normal
	if TileMapManager.furniture_tile_map:
		TileMapManager.furniture_tile_map.set_layer_modulate(TileMapManager.Layer.FURNITURE_DRAFTING, Color.WHITE)

	hide_invalid_overlay()
	GUI.room_info_panel.close()
	_furniture_rotation = 0  # Reset rotation state when exiting

# Crew assignment is now handled by GameManager in the crew state

func update_furniture_preview() -> void:
	TileMapManager.clear_furniture_drafting_layer()

	var origin = TileMapManager.get_global_mouse_position_for_tilemap(TileMapManager.furniture_tile_map)
	var positions = get_placement_positions_from_origin(origin, selected_furnituretype)

	# Get the appropriate tileset coordinates based on rotation state
	var tileset_coords_to_use: Array[Vector2i]
	if selected_furnituretype.supports_rotation:
		tileset_coords_to_use = selected_furnituretype.get_tileset_coords_for_rotation(_furniture_rotation == 1)
	else:
		tileset_coords_to_use = selected_furnituretype.tileset_coords

	if positions.size() != tileset_coords_to_use.size():
		return

	# Check if placement is valid at this position
	var is_valid_placement = _is_furniture_placement_valid_at_position(positions)
	
	# Set the preview color based on validity
	var preview_color: Color
	if is_valid_placement:
		# Valid placement: show true colors with good opacity
		preview_color = Color.WHITE  # True colors
	else:
		# Invalid placement: show red with reduced opacity
		preview_color = Color(1, 0, 0, 0.6)  # Red with 60% opacity

	# Draw the preview tiles with the appropriate color and rotation
	for i in positions.size():
		var tile_pos = positions[i]
		var tile_coord = tileset_coords_to_use[i]
		TileMapManager.set_furniture_drafting_cell(tile_pos, selected_furnituretype.tileset_id, tile_coord)
		
		# Apply the preview color to the drafting layer
		if TileMapManager.furniture_tile_map:
			TileMapManager.furniture_tile_map.set_layer_modulate(TileMapManager.Layer.FURNITURE_DRAFTING, preview_color)

func _is_furniture_placement_valid_at_position(positions: Array[Vector2i]) -> bool:
	# Check if furniture placement is valid at the given positions
	if not selected_furnituretype:
		return false
	
	# Check if tiles are within the room
	if not are_tiles_in_room(positions):
		return false
	
	# Check if tiles are already occupied
	if are_tiles_occupied(positions):
		return false
	
	# Check if we have enough currency
	if not has_enough_currency(selected_furnituretype.price):
		return false
	
	return true

func place_furniture(event: InputEvent) -> void:
	if selected_furnituretype == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var origin = TileMapManager.get_global_mouse_position_for_tilemap(TileMapManager.furniture_tile_map)
		var positions = get_placement_positions_from_origin(origin, selected_furnituretype)

		# Check if positions match the expected count (should always match now with rotation support)
		if positions.size() != selected_furnituretype.tileset_coords.size():
			return

		if !are_tiles_in_room(positions):
			return

		if are_tiles_occupied(positions):
			return

		if not has_enough_currency(selected_furnituretype.price):
			return

		# Spawn furniture instance instead of placing tiles
		var furniture_instance = _spawn_furniture_instance(selected_furnituretype, positions, _furniture_rotation)
		
		if furniture_instance:
			# Place tiles for visual representation (keeping current appearance)
			var tileset_coords_to_use: Array[Vector2i]
			if selected_furnituretype.supports_rotation:
				tileset_coords_to_use = selected_furnituretype.get_tileset_coords_for_rotation(_furniture_rotation == 1)
			else:
				tileset_coords_to_use = selected_furnituretype.tileset_coords
			
			for i in positions.size():
				var world_tile = positions[i]
				var tileset_coord = tileset_coords_to_use[i]
				TileMapManager.set_furniture_cell(world_tile, selected_furnituretype.tileset_id, tileset_coord)
			
			# Deduct currency
			Global.station.currency -= selected_furnituretype.price
		else:
			# Failed to spawn furniture instance
			push_error("Failed to spawn furniture instance")

func are_tiles_in_room(positions: Array[Vector2i]) -> bool:
	# Use the Room class method to check if tiles are within the current room
	if Global.selected_room:
		for pos in positions:
			if not Global.selected_room.is_coord_in_room(pos):
				return false
		return true
	else:
		# Fallback to old logic if no room is selected
		for pos in positions:
			if not _current_room_area.has(pos):
				return false
		return true

func are_tiles_occupied(positions: Array[Vector2i]) -> bool:
	# Check if tiles are occupied by placed furniture instances
	if _is_preview_colliding_with_furniture(positions):
		return true
	
	# Check if tiles are occupied by doors
	if _is_preview_colliding_with_doors(positions):
		return true
	
	return false

func has_enough_currency(price: int) -> bool:
	# TODO: Re-enable when ValidationManager autoload is working
	# return ValidationManager.has_enough_currency(price)
	
	# Temporary fallback to original logic
	return Global.station.currency >= price

func get_placement_positions_from_origin(origin: Vector2i, furniture: FurnitureType) -> Array[Vector2i]:
	# TODO: Re-enable when ValidationManager autoload is working
	# return ValidationManager.get_furniture_placement_positions(origin, furniture)
	
	# Temporary fallback to original logic with rotation support
	var positions: Array[Vector2i] = []
	
	# If furniture supports rotation and is currently rotated, swap width and height
	var effective_width = furniture.width
	var effective_height = furniture.height
	
	if furniture.supports_rotation and _furniture_rotation == 1:
		# Swap width and height for rotated orientation
		effective_width = furniture.height
		effective_height = furniture.width
	
	# Generate positions based on effective dimensions
	for y in range(effective_height):
		for x in range(effective_width):
			positions.append(origin + Vector2i(x, y))
	
	return positions

# Furniture Instance Functions

func _spawn_furniture_instance(furniture_type: FurnitureType, positions: Array[Vector2i], rotation: int) -> Furniture:
	var furniture_instance = _furniture_scene.instantiate() as Furniture
	if not furniture_instance:
		push_error("Failed to instantiate furniture scene")
		return null

	# Add to the current room (assuming we're in a room context)
	if Global.selected_room:
		Global.selected_room.add_child(furniture_instance)
	else:
		# Fallback: add to the station
		if Global.station:
			Global.station.add_child(furniture_instance)
		else:
			push_error("No room or station to add furniture to")
			furniture_instance.queue_free()
			return null

	# Initialize the furniture instance
	furniture_instance.initialize(furniture_type, positions, rotation)

	# Connect signals for crew management
	furniture_instance.crew_assigned.connect(_on_furniture_crew_assigned)
	furniture_instance.crew_unassigned.connect(_on_furniture_crew_unassigned)

	# Connect furniture click signal
	furniture_instance.furniture_clicked.connect(_on_furniture_clicked)

	# Add to our tracking arrays
	_furniture_instances.append(furniture_instance)
	_add_furniture_to_tile_map(furniture_instance, positions)

	return furniture_instance

func _add_furniture_to_tile_map(furniture_instance: Furniture, positions: Array[Vector2i]) -> void:
	for tile_pos in positions:
		if not _furniture_instance_map.has(tile_pos):
			_furniture_instance_map[tile_pos] = []
		_furniture_instance_map[tile_pos].append(furniture_instance)

func _remove_furniture_from_tile_map(furniture_instance: Furniture, positions: Array[Vector2i]) -> void:
	for tile_pos in positions:
		if _furniture_instance_map.has(tile_pos):
			_furniture_instance_map[tile_pos].erase(furniture_instance)
			if _furniture_instance_map[tile_pos].is_empty():
				_furniture_instance_map.erase(tile_pos)

func _get_furniture_at_tile(tile_pos: Vector2i) -> Array[Furniture]:
	if _furniture_instance_map.has(tile_pos):
		var raw_array = _furniture_instance_map[tile_pos]
		var furniture_array: Array[Furniture] = []
		for item in raw_array:
			if item is Furniture:
				furniture_array.append(item)
		return furniture_array
	return []

func _is_tile_occupied_by_furniture(tile_pos: Vector2i) -> bool:
	return _furniture_instance_map.has(tile_pos) and not _furniture_instance_map[tile_pos].is_empty()

func _is_preview_colliding_with_furniture(positions: Array[Vector2i]) -> bool:
	for tile_pos in positions:
		if _is_tile_occupied_by_furniture(tile_pos):
			return true
	return false

func _is_preview_colliding_with_doors(positions: Array[Vector2i]) -> bool:
	# TODO: Implement door collision detection
	# For now, return false as doors are not implemented yet
	return false

func _on_furniture_crew_assigned(crew_member: Node) -> void:
	# TODO: Implement crew assignment logic
	pass

func _on_furniture_crew_unassigned(crew_member: Node) -> void:
	# TODO: Implement crew unassignment logic
	pass

func _on_furniture_info_panel_closed() -> void:
	# Disconnect signals to prevent memory leaks
	var furniture_panel: Node = GUI.get_node_or_null("GUIManager/FurnitureInfoPanel")
	if furniture_panel and furniture_panel.crew_assigned.is_connected(_on_furniture_crew_assigned):
		furniture_panel.crew_assigned.disconnect(_on_furniture_crew_assigned)
	if furniture_panel and furniture_panel.crew_unassigned.is_connected(_on_furniture_crew_unassigned):
		furniture_panel.crew_unassigned.disconnect(_on_furniture_crew_unassigned)
	if furniture_panel and furniture_panel.panel_closed.is_connected(_on_furniture_info_panel_closed):
		furniture_panel.panel_closed.disconnect(_on_furniture_info_panel_closed)

func _on_furniture_clicked(furniture: Furniture) -> void:
	# This function is no longer used for crew assignment
	# Crew assignment is handled directly in the crew state
	pass

func remove_furniture_instance(furniture_instance: Furniture) -> void:
	if furniture_instance in _furniture_instances:
		_furniture_instances.erase(furniture_instance)
		
		# Remove from tile mapping
		var positions = furniture_instance.get_occupied_tiles()
		_remove_furniture_from_tile_map(furniture_instance, positions)
		
		# Disconnect signals
		if furniture_instance.crew_assigned.is_connected(_on_furniture_crew_assigned):
			furniture_instance.crew_assigned.disconnect(_on_furniture_crew_assigned)
		if furniture_instance.crew_unassigned.is_connected(_on_furniture_crew_unassigned):
			furniture_instance.crew_unassigned.disconnect(_on_furniture_crew_unassigned)
		if furniture_instance.furniture_clicked.is_connected(_on_furniture_clicked):
			furniture_instance.furniture_clicked.disconnect(_on_furniture_clicked)
		
		# Remove from scene
		furniture_instance.queue_free()

func cleanup_room_furniture(room: Node) -> void:
	var room_furniture = get_furniture_instances_in_room(room)
	for furniture in room_furniture:
		remove_furniture_instance(furniture)

func get_furniture_instances_in_room(room: Node) -> Array[Furniture]:
	var room_furniture: Array[Furniture] = []
	for furniture in _furniture_instances:
		if furniture.get_parent() == room:
			room_furniture.append(furniture)
	return room_furniture

func get_total_furniture_count() -> int:
	return _furniture_instances.size()

func get_furniture_by_type(furniture_type_id: int) -> Array[Furniture]:
	var type_furniture: Array[Furniture] = []
	for furniture in _furniture_instances:
		if furniture.furniture_type and furniture.furniture_type.id == furniture_type_id:
			type_furniture.append(furniture)
	return type_furniture

func get_furniture_at_tile(tile_pos: Vector2i) -> Array[Furniture]:
	if _furniture_instance_map.has(tile_pos):
		var raw_array = _furniture_instance_map[tile_pos]
		var furniture_array: Array[Furniture] = []
		for item in raw_array:
			if item is Furniture:
				furniture_array.append(item)
		return furniture_array
	return []



func show_invalid_overlay():
	# Instead of drawing red tiles, lower the opacity of everything except the selected room
	# This prevents the red tiles from covering other rooms and interfering with their visibility
	
	if _current_room_area.is_empty() or not Global.selected_room:
		return
	
	# Store the original opacity values for restoration later
	_store_original_opacities()
	
	# Lower opacity of base tiles (everything except the selected room)
	_lower_opacity_except_selected_room()

func hide_invalid_overlay():
	# Restore the original opacity values when hiding the overlay
	_restore_original_opacities()

# --- Opacity Management ---

var _original_opacities: Dictionary = {}
var _furniture_preview: Node2D = null
var _original_furniture_colors: Dictionary = {}
var _furniture_rotation: int = 0  # 0 = normal, 1 = rotated

func _store_original_opacities() -> void:
	# Store the current opacity of the base tile map (only layer we'll change)
	if TileMapManager.base_tile_map:
		_original_opacities["base"] = TileMapManager.base_tile_map.get_layer_modulate(TileMapManager.Layer.BASE)
	
	# No need to store building layer opacity since we won't change it
	# Building layer stays at 100% opacity throughout
	
	# Store the current opacity of all crew members
	_store_crew_opacities()
	
	# Store furniture colors for preview management
	_store_furniture_colors()

func _store_crew_opacities() -> void:
	# Store the current modulate (opacity) of all crew members
	if Global.station and Global.station.crew:
		for crew_member in Global.station.crew:
			if crew_member and is_instance_valid(crew_member):
				var crew_id = str(crew_member.get_instance_id())
				_original_opacities["crew_" + crew_id] = crew_member.modulate

func _store_furniture_colors() -> void:
	# Store the original colors of all furniture types for preview purposes
	if ResourceManager.furniture_types:
		for furniture_type in ResourceManager.furniture_types:
			if furniture_type:
				_original_furniture_colors[furniture_type.id] = Color.WHITE  # Default white color

func _lower_opacity_except_selected_room() -> void:
	if not Global.selected_room:
		return
	
	# Get the selected room's bounds (for reference, but we won't need them for this approach)
	var room_bounds = Global.selected_room.get_room_bounds()
	
	# Create a 50% opacity reduction for the base layer only
	var reduced_opacity = Color(1, 1, 1, 0.5)  # 50% opacity as requested
	var normal_opacity = Color(1, 1, 1, 1.0)  # 100% opacity
	
	# Set reduced opacity for base tiles (background) only
	if TileMapManager.base_tile_map:
		TileMapManager.base_tile_map.set_layer_modulate(TileMapManager.Layer.BASE, reduced_opacity)
	
	# Leave the building layer (rooms) at 100% opacity
	# This way the selected room will naturally stand out because it's brighter than the dimmed background
	# No need to change building layer opacity at all
	
	# Lower the opacity of all crew members to focus attention on the room
	_lower_crew_opacities()

func _lower_crew_opacities() -> void:
	# Lower the opacity of all crew members to 50% to focus attention on the selected room
	if Global.station and Global.station.crew:
		for crew_member in Global.station.crew:
			if crew_member and is_instance_valid(crew_member):
				# Set crew member opacity to 50% (same as background)
				crew_member.modulate = Color(1, 1, 1, 0.5)

func _create_dimming_overlay(room_bounds: Dictionary) -> void:
	# This function is no longer needed - we're using only opacity changes
	# No overlay tiles will be created
	pass

func _highlight_selected_room_area(room_bounds: Dictionary) -> void:
	# This function is no longer needed - we don't want a border
	# The selected room will stand out naturally due to the dimming of other areas
	pass

func _restore_original_opacities() -> void:
	# Restore base tile map opacity (only layer we changed)
	if TileMapManager.base_tile_map and _original_opacities.has("base"):
		TileMapManager.base_tile_map.set_layer_modulate(TileMapManager.Layer.BASE, _original_opacities["base"])
	
	# No need to restore building layer opacity since we never changed it
	# Building layer stays at 100% opacity throughout
	
	# Restore crew member opacities
	_restore_crew_opacities()
	
	# Clear stored opacities
	_original_opacities.clear()

func _restore_crew_opacities() -> void:
	# Restore the original modulate (opacity) of all crew members
	if Global.station and Global.station.crew:
		for crew_member in Global.station.crew:
			if crew_member and is_instance_valid(crew_member):
				var crew_id = str(crew_member.get_instance_id())
				var opacity_key = "crew_" + crew_id
				if _original_opacities.has(opacity_key):
					crew_member.modulate = _original_opacities[opacity_key]

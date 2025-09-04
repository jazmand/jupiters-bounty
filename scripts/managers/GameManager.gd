class_name GameManager extends Node2D

const CREW_SCENE: PackedScene = preload("res://entities/crew/crew_scene.tscn")

@onready var camera: Camera2D = %Camera
@onready var state_manager: StateChart = %StateManager
@onready var base_tile_map: TileMap = %BaseTileMap
@onready var build_tile_map: TileMap = %BuildTileMap
# Note: furniture_tile_map is accessed through TileMapManager instead of @onready

@onready var navigation_region: NavigationRegion2D = %NavigationRegion
@onready var furnishing_manager: FurnishingManager = %FurnishingManager
@onready var gui: GUI = %GUI

var selected_crew: CrewMember = null
var inspected_furniture: Furniture = null
var _original_opacities: Dictionary = {}
var is_in_crew_assignment_mode: bool = false

func _ready() -> void:
	Events.gui_add_crew_pressed.connect(new_crew_member)
	Global.crew_assigned.connect(crew_selected)
	Global.crew_selected.connect(crew_selected)
	Global.station.rooms_updated.connect(update_navigation_region)

	# Set up global input processing to handle crew/room/furniture clicks from any state
	set_process_input(true)

	# Get the tile maps from the scene tree
	var base_tile_map_node: TileMap = get_node("BaseTileMap")
	var build_tile_map_node: TileMap = get_node("BaseTileMap/BuildTileMap")
	var furniture_tile_map_node: TileMap = get_node("BaseTileMap/FurnitureTileMap")

	# Set the tile maps in TileMapManager and initialise it
	TileMapManager.set_tile_maps(base_tile_map_node, build_tile_map_node, furniture_tile_map_node)

func _input(event: InputEvent) -> void:
	## Global input handler for crew/room/furniture clicks from any state
	if event.is_action_pressed(&"select"):
		# If any Building state is active, let BuildingManager handle clicks
		var building_state = get_node_or_null("StateManager/GameState/Building")
		if building_state and building_state.active:
			return

		# Check if the click is over any UI control first
		if _is_mouse_over_ui():
			# Mouse is over a UI control, let the UI handle it
			return

		var mouse_position: Vector2 = local_mouse_position(event.position, camera)
		var selected_tile: Vector2i = build_tile_map.local_to_map(mouse_position)

		# Note: PlacingFurniture state has its own input handler for placement clicks
		# This global handler only manages state-transition clicks (crew, furniture, rooms, base layer)

		# Only handle clicks that cause state transitions
		# Check for crew member clicks first (highest priority)
		if Global.station and Global.station.crew:
			for crew_member in Global.station.crew:
				if crew_member and is_instance_valid(crew_member):
					var crew_tile = build_tile_map.local_to_map(crew_member.position)
					if crew_tile == selected_tile:
						print("DEBUG: Clicked on crew member - transitioning to inspecting_crew")
						start_inspecting_crew(crew_member)
						return

		# Check for furniture inspection clicks (lower priority than crew, higher than rooms)
		if furnishing_manager:
			var furniture_at_tile = furnishing_manager.get_furniture_at_tile(selected_tile)
			if furniture_at_tile and not furniture_at_tile.is_empty():
				var furniture = furniture_at_tile[0]
				
				# If in crew assignment mode, assign the crew and then inspect the furniture
				if is_in_crew_assignment_mode and selected_crew:
					print("DEBUG: Assigning crew to furniture and transitioning to inspecting_furniture")
					_assign_crew_to_furniture(furniture, selected_crew)
					is_in_crew_assignment_mode = false
					start_inspecting_furniture(furniture)
					return
				else:
					print("DEBUG: Clicked on furniture - transitioning to inspecting_furniture")
					start_inspecting_furniture(furniture)
					return

		# Check for room selection (lower priority than crew and furniture)
		var room_id: int = Room.find_tile_room_id(selected_tile)
		var room: Room = Global.station.find_room_by_id(room_id)
		if room:
			Global.selected_room = room
			state_manager.send_event(&"furnishing_start")
			return

		# If we reach here, the click was on empty space (base layer)
		# Send appropriate stop/back event based on the currently active state
		var inspecting_crew_state = get_node_or_null("StateManager/GameState/InspectingCrew")
		if inspecting_crew_state and inspecting_crew_state.active:
			state_manager.send_event(&"crew_inspection_stop")
			return

		var inspecting_furniture_state = get_node_or_null("StateManager/GameState/InspectingFurniture")
		if inspecting_furniture_state and inspecting_furniture_state.active:
			state_manager.send_event(&"furnishing_stop")
			return

		var selecting_furniture_state = get_node_or_null("StateManager/GameState/Furnishing/SelectingFurniture")
		if selecting_furniture_state and selecting_furniture_state.active:
			state_manager.send_event(&"furnishing_stop")
			return

		var placing_furniture_state = get_node_or_null("StateManager/GameState/Furnishing/PlacingFurniture")
		if placing_furniture_state and placing_furniture_state.active:
			state_manager.send_event(&"furnishing_stop")
			return

		# Fallback: already in default or another non-handled state
		print("DEBUG: Clicked on empty space (base layer) - no state change needed")

func _is_mouse_over_ui() -> bool:
	## Check if mouse is currently over any UI element
	var mouse_pos = get_viewport().get_mouse_position()

	# Check popup panels (highest priority - z-index 1)
	var crew_panel = _get_crew_info_panel()
	if crew_panel and crew_panel.visible:
		var rect = crew_panel.get_global_rect()
		if rect.has_point(mouse_pos):
			return true

	var furniture_panel = _get_furniture_info_panel()
	if furniture_panel and furniture_panel.visible:
		var rect = furniture_panel.get_global_rect()
		if rect.has_point(mouse_pos):
			return true

	var room_panel = _get_room_info_panel()
	if room_panel and room_panel.visible:
		var rect = room_panel.get_global_rect()
		if rect.has_point(mouse_pos):
			return true

	# Check furniture menu (lower priority - z-index 2)
	var furniture_menu: Node = _get_furniture_menu()
	if furniture_menu and furniture_menu.visible:
		# Prefer checking the actual panel that contains the buttons
		var furniture_menu_panel: Control = gui.get_node_or_null("GUIManager/FurnitureMenu/FurniturePanel")
		if furniture_menu_panel and furniture_menu_panel.visible:
			var panel_rect = furniture_menu_panel.get_global_rect()
			if panel_rect.has_point(mouse_pos):
				return true
		# Fallback: check the menu node itself
		var rect = furniture_menu.get_global_rect()
		if rect.has_point(mouse_pos):
			return true

	return false

func new_crew_member(position_vector: Vector2 = Vector2(5000, 3000)) -> CrewMember:
	var crew_member: CrewMember = CREW_SCENE.instantiate()
	crew_member.position = position_vector # Adjust spawning position
	add_child(crew_member)
	Global.station.add_crew(crew_member)
	return crew_member
	
func crew_selected(crew: CrewMember) -> void:
	start_inspecting_crew(crew)


func local_mouse_position(event_position: Vector2, game_camera: Camera2D) -> Vector2:
	return to_local((event_position / game_camera.zoom) + game_camera.offset)

func _on_inspecting_furniture_state_input(event: InputEvent) -> void:
	# Handle input while inspecting furniture
	if event.is_action_pressed(&"select"):
		var mouse_position: Vector2 = local_mouse_position(event.position, camera)
		var selected_tile: Vector2i = build_tile_map.local_to_map(mouse_position)

		# Check if we clicked on furniture
		if furnishing_manager:
			var furniture_at_tile = furnishing_manager.get_furniture_at_tile(selected_tile)
			if furniture_at_tile and not furniture_at_tile.is_empty():
				# Clicked on different furniture - switch to inspecting that one
				var furniture = furniture_at_tile[0]
				start_inspecting_furniture(furniture)
				get_viewport().set_input_as_handled()
				return

		# Check if we clicked on a room (to go back to furnishing mode)
		var room_id: int = Room.find_tile_room_id(selected_tile)
		var room = Global.station.find_room_by_id(room_id)
		if room:
			Global.selected_room = room
			state_manager.send_event(&"back_to_furnishing")
			get_viewport().set_input_as_handled()
			return

		# Clicked outside room - go back to default state
		state_manager.send_event(&"furnishing_stop")
		get_viewport().set_input_as_handled()

func _on_default_state_entered() -> void:
	# Ensure all popups are hidden when entering default state
	hide_all_panels()

func _on_default_state_unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"start_building"):
		state_manager.send_event(&"building_start")
	elif event.is_action_pressed(&"start_editing"):
		state_manager.send_event(&"editing_start")
	# Crew assignment is now triggered by clicking crew members, not by keys
	elif event.is_action_pressed(&"cancel") or event.is_action_pressed(&"exit"):
		return
	# Note: Select/click handling is now done globally in _input() method

# Crew assignment is now handled through the inspecting crew state

func show_furniture_info_panel(furniture: Furniture) -> void:
	## Show the furniture info panel with crew assignment options
	# Hide all other panels first
	hide_all_panels()

	# Show the furniture info panel
	var furniture_panel = _get_furniture_info_panel()
	if furniture_panel:
		furniture_panel.show_furniture_info(furniture, selected_crew)
		# Connect to unassignment and panel close signals only
		furniture_panel.crew_unassigned.connect(_on_furniture_crew_unassigned)
		furniture_panel.panel_closed.connect(_on_furniture_info_panel_closed)

func start_inspecting_furniture(furniture: Furniture) -> void:
	# Store the furniture being inspected in both local and Global
	inspected_furniture = furniture
	Global.inspected_furniture = furniture

	# Enter inspecting furniture state (panel will be shown in state handler)
	state_manager.send_event(&"inspect_furniture")

func show_furniture_info_panel_no_assignment(furniture: Furniture) -> void:
	var furniture_panel = _get_furniture_info_panel()
	if furniture_panel:
		furniture_panel.show_furniture_info(furniture, null)
		# Connect to unassignment signals only (no assignment)
		furniture_panel.crew_unassigned.connect(_on_furniture_crew_unassigned)
		furniture_panel.panel_closed.connect(_on_furniture_info_panel_closed)



func _assign_crew_to_furniture(furniture: Furniture, crew_member: CrewMember) -> bool:
	# Assign a crew member to furniture and handle the movement
	var success = furniture.assign_crew(crew_member)
	if success:
		# TODO: This is not working.		
		# Make the crew member walk to a position near the furniture
		var adjacent_tile = furniture.find_adjacent_tile()
		var world_position = build_tile_map.map_to_local(adjacent_tile)
		crew_member.assign_to_furniture(furniture, to_global(world_position))
		
		return true
	else:
		# TODO: Show error to users via UI
		print("Failed to assign crew member to furniture - may be at capacity")
		return false

func _on_furniture_crew_assigned(furniture: Furniture, crew_member: Node) -> void:
	if selected_crew:
		# Use the new helper function
		var success = _assign_crew_to_furniture(furniture, selected_crew)
		if success:
			# Clear selected crew after successful assignment
			selected_crew = null

func _on_furniture_crew_unassigned(furniture: Furniture, crew_member: Node) -> void:
	var success = furniture.unassign_crew(crew_member)
	if success:
		if crew_member.has_method("unassign_from_furniture"):
			crew_member.unassign_from_furniture()
	else:
		print("Failed to unassign crew member from furniture")
		# TODO: Show error to users via UI

func _on_furniture_info_panel_closed() -> void:
	# Disconnect signals to prevent memory leaks
	var furniture_panel = _get_furniture_info_panel()
	if furniture_panel and furniture_panel.crew_unassigned.is_connected(_on_furniture_crew_unassigned):
		furniture_panel.crew_unassigned.disconnect(_on_furniture_crew_unassigned)
	if furniture_panel and furniture_panel.panel_closed.is_connected(_on_furniture_info_panel_closed):
		furniture_panel.panel_closed.disconnect(_on_furniture_info_panel_closed)

func _on_inspecting_furniture_state_entered() -> void:
	# Get the furniture from Global
	inspected_furniture = Global.inspected_furniture

	# Ensure only furniture info panel is visible
	hide_all_panels()

	# Show the furniture info panel (only in inspecting furniture state)
	if inspected_furniture:
		show_furniture_info_panel_no_assignment(inspected_furniture)

	# Apply visual effects - lower opacity of everything except the inspected furniture
	apply_furniture_inspection_effects()

func _on_inspecting_furniture_state_exited() -> void:
	restore_normal_opacity()
	
	# Hide the furniture panel
	var furniture_panel = _get_furniture_info_panel()
	if furniture_panel:
		furniture_panel.hide_panel()

	# Clear inspected furniture reference
	inspected_furniture = null
	Global.inspected_furniture = null

func apply_furniture_inspection_effects() -> void:
	# Apply visual effects for furniture inspection (lower opacity of everything except the inspected furniture)
	if not inspected_furniture:
		return
	
	# Store original opacity values
	store_original_opacities()
	
	# Lower opacity of base tiles (background)
	if TileMapManager.base_tile_map:
		TileMapManager.base_tile_map.set_layer_modulate(TileMapManager.Layer.BASE, Color(1, 1, 1, 0.3))
	
	# Lower opacity of building layer (rooms)
	if TileMapManager.build_tile_map:
		TileMapManager.build_tile_map.set_layer_modulate(TileMapManager.Layer.BUILDING, Color(1, 1, 1, 0.3))
	
	# Lower opacity of furniture layer (other furniture)
	if TileMapManager.furniture_tile_map:
		TileMapManager.furniture_tile_map.set_layer_modulate(TileMapManager.Layer.FURNISHING, Color(1, 1, 1, 0.3))
	
	# Lower opacity of crew members
	if Global.station and Global.station.crew:
		for crew_member in Global.station.crew:
			if crew_member and is_instance_valid(crew_member):
				crew_member.modulate = Color(1, 1, 1, 0.3)
	
	# Keep the inspected furniture at full opacity by not changing its modulate
	# The furniture tiles will remain at full opacity while other layers are dimmed

func restore_normal_opacity() -> void:
	# Restore base tiles
	if TileMapManager.base_tile_map:
		TileMapManager.base_tile_map.set_layer_modulate(TileMapManager.Layer.BASE, Color(1, 1, 1, 1.0))
	
	# Restore building layer
	if TileMapManager.build_tile_map:
		TileMapManager.build_tile_map.set_layer_modulate(TileMapManager.Layer.BUILDING, Color(1, 1, 1, 1.0))
	
	# Restore furniture layer
	if TileMapManager.furniture_tile_map:
		TileMapManager.furniture_tile_map.set_layer_modulate(TileMapManager.Layer.FURNISHING, Color(1, 1, 1, 1.0))
	
	# Restore crew members
	if Global.station and Global.station.crew:
		for crew_member in Global.station.crew:
			if crew_member and is_instance_valid(crew_member):
				crew_member.modulate = Color(1, 1, 1, 1.0)

func store_original_opacities() -> void:
	_original_opacities = {}
	
	if TileMapManager.base_tile_map:
		_original_opacities["base"] = TileMapManager.base_tile_map.get_layer_modulate(TileMapManager.Layer.BASE)
	if TileMapManager.build_tile_map:
		_original_opacities["build"] = TileMapManager.build_tile_map.get_layer_modulate(TileMapManager.Layer.BUILDING)
	if TileMapManager.furniture_tile_map:
		_original_opacities["furniture"] = TileMapManager.furniture_tile_map.get_layer_modulate(TileMapManager.Layer.FURNISHING)

func hide_all_panels() -> void:
	var room_panel = _get_room_info_panel()
	if room_panel:
		room_panel.close()
	var furniture_panel = _get_furniture_info_panel()
	if furniture_panel:
		furniture_panel.hide_panel()
	var crew_panel = _get_crew_info_panel()
	if crew_panel:
		crew_panel.close()

func start_inspecting_crew(crew: CrewMember) -> void:
	selected_crew = crew

	# Enter inspecting crew state (popup will be shown in state handler)
	state_manager.send_event(&"inspect_crew")

func activate_crew_assignment_mode(crew: CrewMember) -> void:
	selected_crew = crew
	is_in_crew_assignment_mode = true

	# Make sure we're in the crew inspection state (for assignment mode)
	state_manager.send_event(&"inspect_crew")

	# Close the panel since we're entering assignment mode
	var crew_panel = _get_crew_info_panel()
	if crew_panel:
		crew_panel.close()

func _get_furniture_info_panel() -> Node:
	return gui.get_node_or_null("GUIManager/FurnitureInfoPanel")

func _get_room_info_panel() -> Node:
	return gui.get_node_or_null("GUIManager/RoomInfoPanel")

func _get_crew_info_panel() -> Node:
	return gui.get_node_or_null("GUIManager/CrewInfoPanel")

func _get_furniture_menu() -> Node:
	return gui.get_node_or_null("GUIManager/FurnitureMenu")

func _on_inspecting_crew_state_entered() -> void:
	## Handle entering crew inspection state
	print("DEBUG: ✅ Entered inspecting_crew state")
	# Ensure only crew info panel is visible
	hide_all_panels()

	# Show crew info panel for the selected crew
	var panel = _get_crew_info_panel()
	if panel and selected_crew:
		panel.open(selected_crew)
		print("DEBUG: ✅ Opened crew info panel for: ", selected_crew.data.name)

func _on_inspecting_crew_state_exited() -> void:
	# Hide crew info panel
	var panel = _get_crew_info_panel()
	if panel:
		panel.close()
	
	# Clear selected crew and reset assignment mode
	selected_crew = null
	is_in_crew_assignment_mode = false

func _on_inspecting_crew_state_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"start_building"): # Use building key to enter assignment mode
		is_in_crew_assignment_mode = true
		return
	elif event.is_action_pressed(&"cancel") or event.is_action_pressed(&"exit"):
		# Do not close the crew panel via right-click/escape; only exit assignment mode
		if is_in_crew_assignment_mode:
			is_in_crew_assignment_mode = false
			get_viewport().set_input_as_handled()
			return

func update_navigation_region() -> void:
	navigation_region.bake_navigation_polygon()


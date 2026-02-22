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

@export var initial_crew_count: int = 1
@export var spawn_fade_duration: float = 2.5
@onready var spawn_points: Node = %SpawnPoints

# Spawn management
var _spawning_in_progress: int = 0
var _next_spawn_index: int = 0


func _ready() -> void:
	Events.gui_add_crew_pressed.connect(_on_gui_add_crew_pressed)
	Global.crew_assigned.connect(crew_selected)
	Global.crew_selected.connect(crew_selected)
	# Navigation rebaking disabled - using physics-based path validation instead
	# Global.station.rooms_updated.connect(update_navigation_region)

	# Set up global input processing to handle crew/room/furniture clicks from any state
	set_process_input(true)

	# Get the tile maps from the scene tree
	var base_tile_map_node: TileMap = get_node("BaseTileMap")
	var build_tile_map_node: TileMap = get_node("BaseTileMap/BuildTileMap")
	var furniture_tile_map_node: TileMap = get_node("BaseTileMap/FurnitureTileMap")
	var special_furniture_tile_map_node: TileMap = get_node("BaseTileMap/SpecialFurnitureTileMap")

	# Set the tile maps in TileMapManager and initialise it
	TileMapManager.set_tile_maps(base_tile_map_node, build_tile_map_node, furniture_tile_map_node, special_furniture_tile_map_node)

	spawn_initial_crew()

func _input(event: InputEvent) -> void:
	# Global input handler for crew/room/furniture clicks from any state
	if event.is_action_pressed(&"select"):
		# If any Building state is active, let BuildingManager handle clicks
		var building_state = get_node_or_null("StateManager/GameState/Building")
		if building_state and building_state.active:
			return

		# Check if the click is over any UI control first
		if _is_mouse_over_ui():
			# Mouse is over a UI control, let the UI handle it
			return

		var selected_tile: Vector2i = TileMapManager.get_global_mouse_position()

		# Note: PlacingFurniture state has its own input handler for placement clicks
		# This global handler only manages state-transition clicks (crew, furniture, rooms, base layer)

		# Only handle clicks that cause state transitions
		# Check for crew member clicks first (highest priority)
		if Global.station and Global.station.crew:
			for crew_member in Global.station.crew:
				if crew_member and is_instance_valid(crew_member):
					var crew_tile = build_tile_map.local_to_map(crew_member.position)
					if crew_tile == selected_tile:
						start_inspecting_crew(crew_member)
						return

		# Check for furniture inspection clicks (lower priority than crew, higher than rooms)
		if furnishing_manager:
			var furniture_at_tile = furnishing_manager.get_furniture_at_tile(selected_tile)
			if furniture_at_tile and not furniture_at_tile.is_empty():
				var furniture = furniture_at_tile[0]
				
				# If in crew assignment mode, assign the crew and then inspect the furniture
				if is_in_crew_assignment_mode and selected_crew:
					_assign_crew_to_furniture(furniture, selected_crew)
					is_in_crew_assignment_mode = false
					start_inspecting_furniture(furniture)
					return
				else:
					start_inspecting_furniture(furniture)
					return

		# Check for special furniture (pumps) clicks
		var pump_at_tile = _get_pump_at_tile(selected_tile)
		if pump_at_tile:
			# Handle pump click - could show pump info panel or trigger special actions
			_handle_pump_click(pump_at_tile)
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

func _is_mouse_over_ui() -> bool:
	# Check if mouse is currently over any UI element
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

func new_crew_member_with_fade(position_vector: Vector2) -> CrewMember:
	var crew_member := new_crew_member(position_vector)
	# Fade only the visual sprites so movement is visible during fade
	var sprite_idle: Sprite2D = crew_member.get_node_or_null("AgathaIdle") as Sprite2D
	var sprite_walk: Sprite2D = crew_member.get_node_or_null("AgathaWalk") as Sprite2D
	if sprite_idle:
		sprite_idle.modulate.a = 0.0
	if sprite_walk:
		sprite_walk.modulate.a = 0.0
	_begin_spawn()
	var t: Tween = create_tween()
	# Use exponential ease-in so fade starts slowly and ends quickly
	t.set_trans(Tween.TRANS_EXPO)
	t.set_ease(Tween.EASE_IN)
	if sprite_idle:
		t.tween_property(sprite_idle, "modulate:a", 1.0, spawn_fade_duration)
	if sprite_walk:
		# Run walk sprite fade in parallel
		t.parallel().tween_property(sprite_walk, "modulate:a", 1.0, spawn_fade_duration)
	t.finished.connect(func():
		_end_spawn()
	)
	# Allow movement to begin 1.0s after spawning (while sprites are still fading)
	var early_move_time: float = 1.0
	if early_move_time > 0.0:
		var move_tween: Tween = create_tween()
		move_tween.tween_interval(early_move_time)
		move_tween.tween_callback(func():
			if is_instance_valid(crew_member) and crew_member.state == crew_member.STATE.IDLE:
				crew_member.state_manager.send_event(&"walk")
				if crew_member.has_method("_start_flow_wander"):
					crew_member._start_flow_wander()
		)
	else:
		# If fade is very short, trigger walking immediately
		if is_instance_valid(crew_member) and crew_member.state == crew_member.STATE.IDLE:
			crew_member.state_manager.send_event(&"walk")
			if crew_member.has_method("_start_flow_wander"):
				crew_member._start_flow_wander()
	return crew_member

func _get_spawn_positions_from_2x1_tile_area() -> Array[Vector2]:
	# Build two spawn positions that align exactly to a 2x1 tile area.
	var results: Array[Vector2] = []
	if not is_instance_valid(build_tile_map):
		return get_spawn_positions()
	if not is_instance_valid(spawn_points) or spawn_points.get_child_count() == 0:
		return get_spawn_positions()

	# Anchor from first marker's tile
	var first_marker := spawn_points.get_child(0)
	if not (first_marker is Marker2D):
		return get_spawn_positions()
	var first_global: Vector2 = (first_marker as Marker2D).global_position
	var first_tile: Vector2i = build_tile_map.local_to_map(build_tile_map.to_local(first_global))

	# Determine orientation using second marker if present; default horizontal
	var second_offset: Vector2i = Vector2i(1, 0)
	if spawn_points.get_child_count() >= 2:
		var second_marker := spawn_points.get_child(1)
		if second_marker is Marker2D:
			var second_global: Vector2 = (second_marker as Marker2D).global_position
			var second_tile: Vector2i = build_tile_map.local_to_map(build_tile_map.to_local(second_global))
			var delta := second_tile - first_tile
			var dx := 0
			var dy := 0
			if delta.x > 0:
				dx = 1
			elif delta.x < 0:
				dx = -1
			if delta.y > 0:
				dy = 1
			elif delta.y < 0:
				dy = -1
			if abs(delta.x) >= abs(delta.y):
				second_offset = Vector2i(dx if dx != 0 else 1, 0)
			else:
				second_offset = Vector2i(0, dy if dy != 0 else 1)

	var tile_a: Vector2i = first_tile
	var tile_b: Vector2i = first_tile + second_offset

	var local_a: Vector2 = build_tile_map.map_to_local(tile_a)
	var local_b: Vector2 = build_tile_map.map_to_local(tile_b)
	var world_a: Vector2 = build_tile_map.to_global(local_a)
	var world_b: Vector2 = build_tile_map.to_global(local_b)
	results.append(world_a)
	results.append(world_b)
	return results

func get_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if is_instance_valid(spawn_points):
		for c in spawn_points.get_children():
			if c is Marker2D:
				positions.append((c as Marker2D).global_position)
	return positions

func spawn_initial_crew() -> void:
	var positions := _get_spawn_positions_from_2x1_tile_area()
	if positions.is_empty():
		positions = [Vector2(5000, 3000)]
	for i in range(initial_crew_count):
		var pos := positions[i % positions.size()]
		var cm := new_crew_member_with_fade(pos)
		# Enable assignment flow debug overlay for the first (and only) crew
		if i == 0 and is_instance_valid(cm):
			cm.debug_assignment_flow = true
		# Face northwest (up-left) on spawn and idle
		if is_instance_valid(cm):
			cm.current_animation_direction = Vector2(-1, -1)
			cm.state = cm.STATE.IDLE
			cm.set_current_animation()
			if cm.animation_player:
				cm.animation_player.play(cm.current_animation)

func _on_gui_add_crew_pressed() -> void:
	var positions := _get_spawn_positions_from_2x1_tile_area()
	if positions.is_empty():
		positions = [Vector2(5000, 3000)]
	var pos := positions[_next_spawn_index % positions.size()]
	_next_spawn_index = (_next_spawn_index + 1) % max(1, positions.size())
	var cm := new_crew_member_with_fade(pos)
	if is_instance_valid(cm):
		cm.current_animation_direction = Vector2(-1, -1)
		cm.state = cm.STATE.IDLE
		cm.set_current_animation()
		if cm.animation_player:
			cm.animation_player.play(cm.current_animation)

func _set_add_crew_button_disabled(disabled: bool) -> void:
	if gui:
		var btn: Button = gui.get_node_or_null("GUIManager/AddCrew")
		if btn:
			btn.disabled = disabled

func _begin_spawn() -> void:
	_spawning_in_progress += 1
	_set_add_crew_button_disabled(true)

func _end_spawn() -> void:
	_spawning_in_progress = max(0, _spawning_in_progress - 1)
	if _spawning_in_progress == 0:
		_set_add_crew_button_disabled(false)
	
func crew_selected(crew: CrewMember) -> void:
	start_inspecting_crew(crew)


func local_mouse_position(event_position: Vector2, game_camera: Camera2D) -> Vector2:
	return to_local((event_position / game_camera.zoom) + game_camera.offset)

func _on_inspecting_furniture_state_input(event: InputEvent) -> void:
	# Handle input while inspecting furniture
	if event.is_action_pressed(&"select"):
		var selected_tile: Vector2i = TileMapManager.get_global_mouse_position()

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
	# Show the furniture info panel with crew assignment options
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
	var success = furniture.assign_crew(crew_member)
	if not success:
		return false
	# Bed assignment: store as assigned_bed only; pathing to bed happens when tired (task 5.1)
	if furniture.is_rest_furniture():
		crew_member.assigned_bed = furniture
		return true
	# Work assignment: path to furniture via flow fields
	crew_member.assign_to_furniture_via_flow(furniture)
	return true

# --- Assignment helpers ---

func _get_room_for_furniture(furniture: Furniture) -> Room:
	if furniture.get_parent() is Room:
		return furniture.get_parent()
	var occupied := furniture.get_occupied_tiles()
	for r in Global.station.rooms:
		for t in occupied:
			if r.is_coord_in_room(t):
				return r
	return null

func _get_closest_door_tile(room: Room, crew_world_pos: Vector2) -> Vector2i:
	if room == null or room.data == null or room.data.door_tiles.is_empty():
		return Vector2i.ZERO
		
	var best: Vector2i = room.data.door_tiles[0]
	var best_d := INF
	for d in room.data.door_tiles:
		var dw := to_global(build_tile_map.map_to_local(d))
		var dist := crew_world_pos.distance_to(dw)
		if dist < best_d:
			best_d = dist
			best = d
	return best

func _compute_door_approach_tiles(room: Room, door: Vector2i) -> Dictionary:
	var room_bounds := room.get_room_bounds()
	var outside_tile := door
	if door.x == room_bounds.min_x:
		outside_tile = door + Vector2i(-1, 0)
	elif door.x == room_bounds.max_x:
		outside_tile = door + Vector2i(1, 0)
	elif door.y == room_bounds.min_y:
		outside_tile = door + Vector2i(0, -1)
	elif door.y == room_bounds.max_y:
		outside_tile = door + Vector2i(0, 1)
	return {
		"outside": outside_tile,
		"door": door
	}

func _tile_center_world(tile: Vector2i) -> Vector2:
	# Convert tile coords to world position centered in tile (BuildTileMap space)
	var local := build_tile_map.map_to_local(tile)
	return build_tile_map.to_global(local)

func _get_adjacent_tile_inside_room(furniture: Furniture, room: Room) -> Vector2i:
	var directions := [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0),
		Vector2i(1,-1), Vector2i(1,1), Vector2i(-1,1), Vector2i(-1,-1)]
	for occupied_tile in furniture.get_occupied_tiles():
		for direction in directions:
			var candidate_tile: Vector2i = occupied_tile + direction
			if room.is_coord_in_room(candidate_tile) and not furniture.is_tile_occupied(candidate_tile):
				return candidate_tile
	# Fallback: use any tile adjacent to furniture even if boundary is tight
	return furniture.get_center_tile()

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
			crew_member.unassign_from_furniture(furniture)
	else:
		# TODO: Show error to users via UI
		pass

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
	
	# Lower opacity of furniture sprites (other furniture)
	_lower_furniture_opacities()
	
	# Lower opacity of special furniture layer (pumps, etc.)
	if TileMapManager.special_furniture_tile_map:
		TileMapManager.special_furniture_tile_map.set_layer_modulate(TileMapManager.Layer.SPECIAL_FURNITURE, Color(1, 1, 1, 0.3))
	
	# Lower opacity of crew members
	if Global.station and Global.station.crew:
		for crew_member in Global.station.crew:
			if crew_member and is_instance_valid(crew_member):
				crew_member.modulate = Color(1, 1, 1, 0.3)
	
	# Keep the inspected furniture at full opacity by not changing its modulate
	# The furniture sprites will remain at full opacity while other layers are dimmed

func _lower_furniture_opacities() -> void:
	# Lower opacity of all furniture sprites except the inspected one
	if Global.station and Global.station.rooms:
		for room in Global.station.rooms:
			if room and is_instance_valid(room):
				# Get all furniture in this room
				for child in room.get_children():
					if child is Furniture and child != inspected_furniture:
						child.modulate = Color(1, 1, 1, 0.3)

func _restore_furniture_opacities() -> void:
	# Restore normal opacity of all furniture sprites
	if Global.station and Global.station.rooms:
		for room in Global.station.rooms:
			if room and is_instance_valid(room):
				# Get all furniture in this room
				for child in room.get_children():
					if child is Furniture:
						child.modulate = Color(1, 1, 1, 1.0)

func restore_normal_opacity() -> void:
	# Restore base tiles
	if TileMapManager.base_tile_map:
		TileMapManager.base_tile_map.set_layer_modulate(TileMapManager.Layer.BASE, Color(1, 1, 1, 1.0))
	
	# Restore building layer
	if TileMapManager.build_tile_map:
		TileMapManager.build_tile_map.set_layer_modulate(TileMapManager.Layer.BUILDING, Color(1, 1, 1, 1.0))
	
	# Restore furniture sprites
	_restore_furniture_opacities()
	
	# Restore special furniture layer
	if TileMapManager.special_furniture_tile_map:
		TileMapManager.special_furniture_tile_map.set_layer_modulate(TileMapManager.Layer.SPECIAL_FURNITURE, Color(1, 1, 1, 1.0))
	
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
	if TileMapManager.special_furniture_tile_map:
		_original_opacities["special_furniture"] = TileMapManager.special_furniture_tile_map.get_layer_modulate(TileMapManager.Layer.SPECIAL_FURNITURE)

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

func _get_pump_at_tile(tile: Vector2i) -> Pump:
	# Find pump at the specified tile
	var pumps = get_tree().get_nodes_in_group("pumps")
	for pump in pumps:
		if pump is Pump and pump.is_tile_occupied(tile):
			return pump
	return null

func _handle_pump_click(pump: Pump) -> void:
	# Handle pump click - show pump model information
	pass

func _on_inspecting_crew_state_entered() -> void:
	# Handle entering crew inspection state
	# Ensure only crew info panel is visible
	hide_all_panels()

	# Show crew info panel for the selected crew
	var panel = _get_crew_info_panel()
	if panel and selected_crew:
		panel.open(selected_crew)

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
	# Defer baking to ensure TileMap edits are committed
	call_deferred("_deferred_bake_navigation")

func _deferred_bake_navigation() -> void:
	# Wait one physics frame for safety, then bake
	await get_tree().physics_frame
	navigation_region.bake_navigation_polygon()
	# Invalidate flow fields after nav changes
	if Global and Global.flow_service:
		Global.flow_service.mark_nav_dirty()
	if Global and Global.wander_beacons:
		Global.wander_beacons.rebuild_from_nav()



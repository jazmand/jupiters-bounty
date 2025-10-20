class_name AssignmentBeacons
extends Node

# Reserves a unique access-adjacent tile per crew when assigned to furniture.
# Releases the reservation on unassign.

var crewIdToTile: Dictionary = {}
var reservedKeyToCrew: Dictionary = {}

# Debug rendering
var debug_enabled: bool = false
var debug_canvas: CanvasLayer = null
var debug_draw_node: Control = null

func reserve_for_crew(furniture: Furniture, crew_id: int, crew_world_pos: Vector2) -> Vector2i:
	print("[AssignmentBeacons] Attempting to reserve beacon for crew ", crew_id, " at furniture ", furniture.furniture_type.name if furniture.furniture_type else "Unknown")
	
	if furniture == null:
		print("[AssignmentBeacons] ERROR: Furniture is null")
		return Vector2i.ZERO
	# If already reserved, return existing
	if crewIdToTile.has(str(crew_id)):
		var existing_tile = crewIdToTile[str(crew_id)]
		print("[AssignmentBeacons] Crew ", crew_id, " already has beacon at tile ", existing_tile)
		return existing_tile
	# Debug: Show furniture access requirements
	print("[AssignmentBeacons] Furniture access requirements:")
	print("  - Rule: ", furniture.furniture_type.access_rule)
	print("  - Required sides: ", furniture.furniture_type.access_required_sides)
	print("  - Required sides rotated: ", furniture.furniture_type.access_required_sides_rotated)
	print("  - Furniture rotation: ", furniture.rotation_state)
	
	# Compute access tiles (respecting rotation and room bounds)
	var accessTiles: Array[Vector2i] = FlowTargets.new().furniture_access_tiles(furniture)
	print("[AssignmentBeacons] Found ", accessTiles.size(), " access tiles for furniture")
	
	# Initialize grid for walkability checks
	var grid := NavGridProvider.new()
	
	# IMMEDIATE LENIENT FALLBACK: If no access tiles found, find any walkable tile adjacent to furniture
	if accessTiles.is_empty():
		print("[AssignmentBeacons] No access tiles found, trying LENIENT adjacent search...")
		var occupied_tiles: Array[Vector2i] = furniture.get_occupied_tiles()
		var adjacent_directions = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
		var room: Room = null
		if furniture.get_parent() is Room:
			room = furniture.get_parent()
		
		for occupied_tile in occupied_tiles:
			for direction in adjacent_directions:
				var candidate_tile: Vector2i = occupied_tile + direction
				if not occupied_tiles.has(candidate_tile) and grid.is_walkable(candidate_tile) and (room == null or room.is_coord_in_room(candidate_tile)):
					print("[AssignmentBeacons] Found lenient access tile: ", candidate_tile)
					accessTiles.append(candidate_tile)
		
		print("[AssignmentBeacons] Lenient search found ", accessTiles.size(), " tiles")
	
	# If STILL no access tiles after lenient search, try door tiles as last resort
	if accessTiles.is_empty():
		print("[AssignmentBeacons] Still no access tiles after lenient search, trying door tiles...")
		if furniture.get_parent() is Room:
			accessTiles = FlowTargets.new().door_tiles(furniture.get_parent())
			print("[AssignmentBeacons] Found ", accessTiles.size(), " door tiles as fallback")
		else:
			print("[AssignmentBeacons] ERROR: No access tiles and furniture not in room")
			return Vector2i.ZERO
	
	# Filter out already reserved tiles and require true adjacency to the furniture footprint
	var candidateTiles: Array[Vector2i] = []
	var crew_tile: Vector2i = grid.world_to_tile(crew_world_pos)
	print("[AssignmentBeacons] Crew current tile: ", crew_tile, " (world pos: ", crew_world_pos, ")")
	
	for accessTile in accessTiles:
		print("[AssignmentBeacons] Checking access tile ", accessTile)
		# Enforce that the beacon is in the same room as the furniture
		if furniture.get_parent() is Room and not (furniture.get_parent() as Room).is_coord_in_room(accessTile):
			print("[AssignmentBeacons] Tile ", accessTile, " rejected: not inside furniture room")
			continue
		if reservedKeyToCrew.has(_key(accessTile)):
			print("[AssignmentBeacons] Tile ", accessTile, " already reserved by crew ", reservedKeyToCrew[_key(accessTile)])
			continue
		if not is_adjacent_to_furniture(accessTile, furniture):
			print("[AssignmentBeacons] Tile ", accessTile, " not adjacent to furniture")
			continue
		if not grid.is_walkable(accessTile):
			print("[AssignmentBeacons] Tile ", accessTile, " not walkable")
			continue
		# If the crew is already standing on this tile, only accept it if it truly touches the furniture
		if accessTile == crew_tile and not is_adjacent_to_furniture(crew_tile, furniture):
			print("[AssignmentBeacons] Crew on tile ", accessTile, " but not adjacent to furniture")
			continue
		print("[AssignmentBeacons] Tile ", accessTile, " is valid candidate")
		candidateTiles.append(accessTile)
	
	print("[AssignmentBeacons] Found ", candidateTiles.size(), " candidate tiles")
	if candidateTiles.is_empty():
		print("[AssignmentBeacons] ERROR: No valid candidate tiles found")
		return Vector2i.ZERO
	# Pick the tile closest to the furniture footprint center to ensure adjacency
	var bestTile: Vector2i = candidateTiles[0]
	var bestDistance := INF
	var furnitureCenterWorld := _world_center_of_footprint(furniture)
	print("[AssignmentBeacons] Furniture center world: ", furnitureCenterWorld)
	for candidate in candidateTiles:
		var candidateWorld: Vector2 = _tile_world_center(candidate)
		var dist := furnitureCenterWorld.distance_to(candidateWorld)
		print("[AssignmentBeacons] Candidate ", candidate, " distance: ", dist)
		if dist < bestDistance:
			bestDistance = dist
			bestTile = candidate
	# Reserve
	print("[AssignmentBeacons] SUCCESS: Reserved tile ", bestTile, " for crew ", crew_id)
	crewIdToTile[str(crew_id)] = bestTile
	reservedKeyToCrew[_key(bestTile)] = crew_id
	
	# Draw debug info for this furniture
	if debug_enabled:
		draw_furniture_debug(furniture)
	
	return bestTile

func release_for_crew(crew_id: int) -> void:
	var crewKey := str(crew_id)
	if crewIdToTile.has(crewKey):
		var tile: Vector2i = crewIdToTile[crewKey]
		crewIdToTile.erase(crewKey)
		var tileKey := _key(tile)
		if reservedKeyToCrew.has(tileKey):
			reservedKeyToCrew.erase(tileKey)

func _tile_world_center(tile: Vector2i) -> Vector2:
	if TileMapManager and TileMapManager.build_tile_map:
		var local := TileMapManager.build_tile_map.map_to_local(tile)
		return TileMapManager.build_tile_map.to_global(local)
	return Vector2.ZERO

func _world_center_of_footprint(furniture: Furniture) -> Vector2:
	var occupiedTiles: Array[Vector2i] = furniture.get_occupied_tiles()
	if occupiedTiles.is_empty():
		return furniture.global_position
	var worldSum := Vector2.ZERO
	for occTile in occupiedTiles:
		worldSum += _tile_world_center(occTile)
	return worldSum / float(occupiedTiles.size())

func is_adjacent_to_furniture(tile: Vector2i, furniture: Furniture) -> bool:
	var cardinalDirs := [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
	var footprintTiles: Array[Vector2i] = furniture.get_occupied_tiles()
	var occupiedLookup := {}
	for footprintTile in footprintTiles:
		occupiedLookup[footprintTile] = true
	for cardinal in cardinalDirs:
		var neighborTile: Vector2i = tile + cardinal
		if occupiedLookup.has(neighborTile):
			return true
	return false

func _key(t: Vector2i) -> String:
	return str(t.x) + ":" + str(t.y)

# Debug rendering functions
func enable_debug_rendering() -> void:
	print("[AssignmentBeacons] DEBUG: enable_debug_rendering() called")
	debug_enabled = true
	_setup_debug_canvas()

func disable_debug_rendering() -> void:
	debug_enabled = false
	if debug_canvas:
		debug_canvas.queue_free()
		debug_canvas = null
		debug_draw_node = null

func _setup_debug_canvas() -> void:
	if debug_canvas:
		return
	
	print("[AssignmentBeacons] DEBUG: Setting up debug canvas...")
	
	debug_canvas = CanvasLayer.new()
	debug_canvas.name = "AssignmentBeaconsDebug"
	debug_canvas.layer = 100  # High layer to appear on top
	
	debug_draw_node = Control.new()
	debug_draw_node.name = "DebugDraw"
	debug_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	debug_canvas.add_child(debug_draw_node)
	get_tree().root.call_deferred("add_child", debug_canvas)
	
	print("[AssignmentBeacons] DEBUG: Canvas added to scene tree")
	
	# Connect to draw signal
	debug_draw_node.draw.connect(_on_debug_draw)
	
	# Start continuous redraw timer for real-time updates
	var redraw_timer = Timer.new()
	redraw_timer.name = "DebugRedrawTimer"
	redraw_timer.wait_time = 0.1  # Redraw 10 times per second
	redraw_timer.autostart = true
	redraw_timer.timeout.connect(func(): if debug_draw_node: debug_draw_node.queue_redraw())
	debug_canvas.add_child(redraw_timer)
	
	print("[AssignmentBeacons] DEBUG: Debug canvas setup complete")

func _on_debug_draw() -> void:
	if not debug_enabled or not debug_draw_node:
		return
	
	var viewport = get_viewport()
	if not viewport:
		return
	
	# Draw all reserved beacons as green circles
	for crew_key in crewIdToTile.keys():
		var tile: Vector2i = crewIdToTile[crew_key]
		var world_pos: Vector2 = _tile_world_center(tile)
		var screen_pos: Vector2 = viewport.get_screen_transform() * world_pos
		
		debug_draw_node.draw_circle(screen_pos, 8, Color.GREEN)
		debug_draw_node.draw_string(debug_draw_node.get_theme_default_font(), screen_pos + Vector2(10, -10), "Beacon", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.GREEN)
	
	# Draw furniture debug for all assigned furniture
	for crew_key in crewIdToTile.keys():
		var furniture = _get_furniture_for_crew(int(crew_key))
		if furniture:
			draw_furniture_debug(furniture)
	
	# Draw crew target arrows and lines
	draw_crew_targets()

func draw_furniture_debug(furniture: Furniture) -> void:
	if not debug_enabled or not debug_draw_node:
		return
	
	var viewport = get_viewport()
	if not viewport:
		return
	
	# Draw red circles at furniture occupied tiles
	var occupied_tiles = furniture.get_occupied_tiles()
	for tile in occupied_tiles:
		var world_pos = _tile_world_center(tile)
		var screen_pos = viewport.get_screen_transform() * world_pos
		debug_draw_node.draw_circle(screen_pos, 6, Color.RED)
	
	# Draw blue circles at furniture access tiles
	var flow_targets = FlowTargets.new()
	var access_tiles = flow_targets.furniture_access_tiles(furniture)
	for tile in access_tiles:
		var world_pos = _tile_world_center(tile)
		var screen_pos = viewport.get_screen_transform() * world_pos
		debug_draw_node.draw_circle(screen_pos, 4, Color.BLUE)

func draw_crew_targets() -> void:
	if not debug_enabled or not debug_draw_node:
		return
	
	var viewport = get_viewport()
	if not viewport:
		return
	
	# Find all crew members and draw their targets
	var crew_members = get_tree().get_nodes_in_group("crew")
	for crew in crew_members:
		if crew.has_method("_is_on_assignment") and crew._is_on_assignment():
			var crew_pos = crew.global_position
			var crew_screen = viewport.get_screen_transform() * crew_pos
			
			# Draw cyan line from crew to their beacon
			var beacon_tile = crewIdToTile.get(str(crew.get_instance_id()))
			if beacon_tile != null:
				var beacon_world = _tile_world_center(beacon_tile)
				var beacon_screen = viewport.get_screen_transform() * beacon_world
				debug_draw_node.draw_line(crew_screen, beacon_screen, Color.CYAN, 2)
				
				# Draw yellow arrow showing current target tile
				if crew.has_method("_get_current_target_tile"):
					var target_tile = crew._get_current_target_tile()
					if target_tile != Vector2i.ZERO:
						var target_world = _tile_world_center(target_tile)
						var target_screen = viewport.get_screen_transform() * target_world
						debug_draw_node.draw_circle(target_screen, 5, Color.YELLOW)
						debug_draw_node.draw_string(debug_draw_node.get_theme_default_font(), target_screen + Vector2(10, -10), "Target", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW)

func _get_furniture_for_crew(crew_id: int) -> Furniture:
	# Find furniture associated with this crew assignment
	var crew_members = get_tree().get_nodes_in_group("crew")
	for crew in crew_members:
		if crew.get_instance_id() == crew_id and crew.has_method("_is_on_assignment") and crew._is_on_assignment():
			if crew.has_method("get_furniture_workplace"):
				return crew.get_furniture_workplace()
	return null

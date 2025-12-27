class_name AssignmentBeacons
extends Node

# Simple assignment beacon system - reserves exact tiles per crew for furniture assignments
# Works like WanderBeacons but with unique reservations (no jitter, exact tiles)

var crewIdToTile: Dictionary = {}  # crew_id -> beacon_tile
var tileToCrewId: Dictionary = {}  # tile_key -> crew_id

# Debug rendering
var debug_enabled: bool = false
var debug_canvas: CanvasLayer = null
var debug_draw_node: Control = null

func reserve_for_crew(furniture: Furniture, crew_id: int, crew_world_pos: Vector2) -> Vector2i:
	if furniture == null:
		return Vector2i.ZERO
	
	# If already reserved for this crew, return existing
	var crew_key := str(crew_id)
	if crewIdToTile.has(crew_key):
		return crewIdToTile[crew_key]
	
	# Get furniture access tiles
	var access_tiles: Array[Vector2i] = FlowTargets.new().furniture_access_tiles(furniture)
	var grid := NavGridProvider.new()
	
	# Fallback: find adjacent walkable tiles if no access tiles
	if access_tiles.is_empty():
		var occupied_tiles: Array[Vector2i] = furniture.get_occupied_tiles()
		var adjacent_dirs := [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
		var room: Room = furniture.get_parent() if (furniture.get_parent() is Room) else null
		
		for occupied in occupied_tiles:
			for dir in adjacent_dirs:
				var candidate: Vector2i = occupied + dir
				if not occupied_tiles.has(candidate) and grid.is_walkable(candidate):
					if room == null or room.is_coord_in_room(candidate):
						access_tiles.append(candidate)
	
	# Last resort: use door tiles
	if access_tiles.is_empty() and furniture.get_parent() is Room:
		access_tiles = FlowTargets.new().door_tiles(furniture.get_parent())
	
	if access_tiles.is_empty():
		return Vector2i.ZERO
	
	# Filter: walkable, nav-centered, not reserved, in same room as furniture
	var candidates: Array[Vector2i] = []
	for tile in access_tiles:
		if not grid.is_walkable(tile):
			continue
		if not _is_nav_centered(tile):
			continue
		if tileToCrewId.has(_key(tile)):
			continue
		if furniture.get_parent() is Room:
			var room := furniture.get_parent() as Room
			if not room.is_coord_in_room(tile):
				continue
		if not _is_adjacent_to_furniture(tile, furniture):
			continue
		candidates.append(tile)
	
	if candidates.is_empty():
		return Vector2i.ZERO
	
	# Pick closest to furniture center
	var best_tile := candidates[0]
	var best_dist := INF
	var furniture_center := _furniture_center_world(furniture)
	for candidate in candidates:
		var candidate_world := _tile_world_center(candidate)
		var dist := furniture_center.distance_to(candidate_world)
		if dist < best_dist:
			best_dist = dist
			best_tile = candidate
	
	# Reserve
	crewIdToTile[crew_key] = best_tile
	tileToCrewId[_key(best_tile)] = crew_id
	
	if debug_enabled:
		_setup_debug_canvas()
	
	return best_tile

func release_for_crew(crew_id: int) -> void:
	var crew_key := str(crew_id)
	if not crewIdToTile.has(crew_key):
		return
	
	var tile: Vector2i = crewIdToTile[crew_key]
	crewIdToTile.erase(crew_key)
	tileToCrewId.erase(_key(tile))

func _key(tile: Vector2i) -> String:
	return str(tile.x) + ":" + str(tile.y)

func _is_nav_centered(tile: Vector2i) -> bool:
	if TileMapManager == null or TileMapManager.build_tile_map == null:
		return true
	var local := TileMapManager.build_tile_map.map_to_local(tile)
	var center := TileMapManager.build_tile_map.to_global(local)
	var nav := Engine.get_main_loop()
	if nav and nav.has_method("get_root"):
		var root: Node = nav.get_root()
		var region: NavigationRegion2D = root.get_node_or_null("Main/GameManager/NavigationRegion")
		if region:
			var rid: RID = region.get_navigation_map()
			if rid != RID():
				var closest := NavigationServer2D.map_get_closest_point(rid, center)
				return closest.distance_to(center) <= 8.0
	return true

func _is_adjacent_to_furniture(tile: Vector2i, furniture: Furniture) -> bool:
	var footprint := furniture.get_occupied_tiles()
	var footprint_set := {}
	for ft in footprint:
		footprint_set[ft] = true
	
	var dirs := [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
	for dir in dirs:
		if footprint_set.has(tile + dir):
			return true
	return false

func _tile_world_center(tile: Vector2i) -> Vector2:
	if TileMapManager and TileMapManager.build_tile_map:
		var local := TileMapManager.build_tile_map.map_to_local(tile)
		return TileMapManager.build_tile_map.to_global(local)
	return Vector2.ZERO

func _furniture_center_world(furniture: Furniture) -> Vector2:
	var occupied := furniture.get_occupied_tiles()
	if occupied.is_empty():
		return furniture.global_position
	var sum := Vector2.ZERO
	for tile in occupied:
		sum += _tile_world_center(tile)
	return sum / float(occupied.size())

# Debug rendering
func enable_debug_rendering() -> void:
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
	
	debug_canvas = CanvasLayer.new()
	debug_canvas.name = "AssignmentBeaconsDebug"
	debug_canvas.layer = 100
	
	debug_draw_node = Control.new()
	debug_draw_node.name = "DebugDraw"
	debug_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	debug_canvas.add_child(debug_draw_node)
	get_tree().root.call_deferred("add_child", debug_canvas)
	
	debug_draw_node.draw.connect(_on_debug_draw)
	
	var redraw_timer = Timer.new()
	redraw_timer.name = "DebugRedrawTimer"
	redraw_timer.wait_time = 0.1
	redraw_timer.autostart = true
	redraw_timer.timeout.connect(func(): if debug_draw_node: debug_draw_node.queue_redraw())
	debug_canvas.add_child(redraw_timer)

func _on_debug_draw() -> void:
	if not debug_enabled or not debug_draw_node:
		return
	
	var viewport = get_viewport()
	if not viewport:
		return
	
	# Draw reserved beacons as green circles
	for crew_key in crewIdToTile.keys():
		var tile: Vector2i = crewIdToTile[crew_key]
		var world_pos := _tile_world_center(tile)
		var screen_pos := viewport.get_screen_transform() * world_pos
		debug_draw_node.draw_circle(screen_pos, 8, Color.GREEN)
		debug_draw_node.draw_string(
			debug_draw_node.get_theme_default_font(),
			screen_pos + Vector2(10, -10),
			"Beacon",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color.GREEN
		)
		
		# Draw line from crew to beacon if crew exists
		var crew_id := int(crew_key)
		var crew_members = get_tree().get_nodes_in_group("crew")
		for crew in crew_members:
			if crew.get_instance_id() == crew_id:
				var crew_screen: Vector2 = viewport.get_screen_transform() * crew.global_position
				debug_draw_node.draw_line(crew_screen, screen_pos, Color.CYAN, 2)
				break

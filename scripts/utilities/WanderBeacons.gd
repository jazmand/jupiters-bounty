class_name WanderBeacons
extends Node

var beacons: Array[Vector2i] = []
var beaconTileToOccupancy: Dictionary = {}

# Debug rendering
var debug_enabled: bool = false
var debug_canvas: CanvasLayer = null
var debug_draw_node: Control = null

func rebuild_from_nav() -> void:
	beacons.clear()
	beaconTileToOccupancy.clear()
	if TileMapManager == null or TileMapManager.base_tile_map == null:
		return
	var used: Array[Vector2i] = TileMapManager.base_tile_map.get_used_cells(TileMapManager.Layer.BASE)
	if used.is_empty():
		return
	# Determine target count based on map size
	var targetBeaconCount: int = clamp(int(used.size() / 600), 6, 24)
	# Simple grid-stride sampling for uniform distribution
	var stride: int = max(1, int(sqrt(used.size() / max(targetBeaconCount, 1))))
	var pickedCount: int = 0
	for i in range(0, used.size(), stride):
		var candidateTile: Vector2i = used[i]
		if _is_nav_centered(candidateTile):
			beacons.append(candidateTile)
			pickedCount += 1
			if pickedCount >= targetBeaconCount:
				break

func pick_beacon_for_crew() -> Vector2i:
	if beacons.is_empty():
		rebuild_from_nav()
	if beacons.is_empty():
		return Vector2i.ZERO
	# Prefer least-occupied beacon
	var leastOccupiedBeacon: Vector2i = beacons[0]
	var leastOccupancy: int = int(beaconTileToOccupancy.get(_key(leastOccupiedBeacon), 0))
	for beacon in beacons:
		var occ: int = int(beaconTileToOccupancy.get(_key(beacon), 0))
		if occ < leastOccupancy:
			leastOccupiedBeacon = beacon
			leastOccupancy = occ
	# Reserve one slot
	beaconTileToOccupancy[_key(leastOccupiedBeacon)] = leastOccupancy + 1
	return leastOccupiedBeacon

func release_beacon(beaconTile: Vector2i) -> void:
	var key: String = _key(beaconTile)
	if beaconTileToOccupancy.has(key):
		beaconTileToOccupancy[key] = max(0, int(beaconTileToOccupancy[key]) - 1)

func jitter(tile: Vector2i, radius: int = 2) -> Vector2i:
	var jitterOffset := Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
	return tile + jitterOffset

func _key(t: Vector2i) -> String:
	return str(t.x) + ":" + str(t.y)

func _is_nav_centered(tile: Vector2i) -> bool:
	# Accept tiles whose centers lie on nav
	var center: Vector2 = TileMapManager.build_tile_map.map_to_local(tile)
	center = TileMapManager.build_tile_map.to_global(center)
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

# Debug rendering functions
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
	debug_canvas.name = "WanderBeaconsDebug"
	debug_canvas.layer = 99  # Just below assignment beacons
	
	debug_draw_node = Control.new()
	debug_draw_node.name = "DebugDraw"
	debug_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	debug_canvas.add_child(debug_draw_node)
	get_tree().root.call_deferred("add_child", debug_canvas)
	
	# Connect to draw signal
	debug_draw_node.draw.connect(_on_debug_draw)
	
	# Start continuous redraw timer for real-time updates
	var redraw_timer = Timer.new()
	redraw_timer.name = "DebugRedrawTimer"
	redraw_timer.wait_time = 0.1  # Redraw 10 times per second
	redraw_timer.autostart = true
	redraw_timer.timeout.connect(func(): if debug_draw_node: debug_draw_node.queue_redraw())
	debug_canvas.add_child(redraw_timer)

func _on_debug_draw() -> void:
	if not debug_enabled or not debug_draw_node:
		return
	
	# Draw all wander beacons as yellow circles
	var viewport = get_viewport()
	if not viewport:
		return
	var camera = viewport.get_camera_2d()
	if not camera:
		return
	
	for beacon in beacons:
		var world_pos: Vector2 = _tile_world_center(beacon)
		var screen_pos: Vector2 = viewport.get_screen_transform() * world_pos
		var occupancy = int(beaconTileToOccupancy.get(_key(beacon), 0))
		debug_draw_node.draw_circle(screen_pos, 6, Color.YELLOW)
		if occupancy > 0:
			debug_draw_node.draw_string(debug_draw_node.get_theme_default_font(), screen_pos + Vector2(8, -8), str(occupancy), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.YELLOW)

func _tile_world_center(tile: Vector2i) -> Vector2:
	if TileMapManager and TileMapManager.build_tile_map:
		var local := TileMapManager.build_tile_map.map_to_local(tile)
		return TileMapManager.build_tile_map.to_global(local)
	return Vector2.ZERO



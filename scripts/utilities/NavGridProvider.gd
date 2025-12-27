class_name NavGridProvider
extends Node

# Provides tile/world conversion and walkability queries backed by the current
# navigation TileMap and game managers. This utility is designed to be used by
# flow-field pathfinding and other systems that need fast tile queries.

## Tile/world conversion


func world_to_tile(world: Vector2) -> Vector2i:
	var nav_tilemap := _get_nav_tilemap()
	if nav_tilemap == null:
		return Vector2i.ZERO
	return nav_tilemap.local_to_map(nav_tilemap.to_local(world))


func tile_center_world(tile: Vector2i) -> Vector2:
	var nav_tilemap := _get_nav_tilemap()
	if nav_tilemap == null:
		return Vector2.ZERO
	var local_position := nav_tilemap.map_to_local(tile)
	return nav_tilemap.to_global(local_position)

## Walkability and traversal

func is_walkable(tile: Vector2i) -> bool:
	# Must lie on the navigation map
	var tile_world_center := tile_center_world(tile)
	if not _is_on_navigation(tile_world_center):
		return false
	
	# Door tiles are explicitly walkable, even if occupied by door furniture
	if is_door_tile(tile):
		return true
	
	# Must not be occupied by furniture
	if TileMapManager == null:
		return false
	var furnishing_manager: FurnishingManager = _get_furnishing_manager()
	if furnishing_manager != null:
		var furniture_at_tile: Array = furnishing_manager.get_furniture_at_tile(tile)
		if furniture_at_tile != null and not furniture_at_tile.is_empty():
			return false
	
	return true

func can_traverse(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	# Basic walkability on both ends
	if not is_walkable(from_tile) or not is_walkable(to_tile):
		return false
	# Doors-only rule when crossing room boundaries
	var from_room_id := Room.find_tile_room_id(from_tile)
	var to_room_id := Room.find_tile_room_id(to_tile)
	if from_room_id == to_room_id:
		return true
	# Crossing rooms: only allow if either tile is a door tile for the boundary involved
	var from_room := Global.station.find_room_by_id(from_room_id)
	var to_room := Global.station.find_room_by_id(to_room_id)
	# Check door sets on both rooms (defensive null checks)
	if from_room and from_room.data and not from_room.data.door_tiles.is_empty():
		if from_room.data.door_tiles.has(from_tile) or from_room.data.door_tiles.has(to_tile):
			return true
	if to_room and to_room.data and not to_room.data.door_tiles.is_empty():
		if to_room.data.door_tiles.has(from_tile) or to_room.data.door_tiles.has(to_tile):
			return true
	return false

func is_door_tile(tile: Vector2i) -> bool:
	"""Check if a tile is a door tile for any room"""
	# Iterate over all rooms to check if the tile is in any door set
	# Optimization: We could cache this if performance becomes an issue
	if Global.station == null:
		return false
		
	for room in Global.station.rooms:
		if room and room.data and room.data.door_tiles.has(tile):
			return true
	return false

func random_walkable_tile(max_attempts: int = 64) -> Vector2i:
	# Try random tiles within existing rooms first for better results
	if Global.station and Global.station.rooms and not Global.station.rooms.is_empty():
		for _i in range(max_attempts):
			var room := Global.station.rooms[randi() % Global.station.rooms.size()]
			if room and room.data:
				var b := room.get_room_bounds()
				var rand_x := randi_range(b.min_x, b.max_x)
				var rand_y := randi_range(b.min_y, b.max_y)
				var t := Vector2i(rand_x, rand_y)
				if room.is_coord_in_room(t) and is_walkable(t):
					return t
	# Fallback: probe around current nav tilemap extents
	if TileMapManager and TileMapManager.base_tile_map:
		var used := TileMapManager.base_tile_map.get_used_cells(TileMapManager.Layer.BASE)
		if not used.is_empty():
			for _j in range(max_attempts):
				var base := used[randi() % used.size()]
				var jitter := Vector2i(randi_range(-8, 8), randi_range(-8, 8))
				var t2 := base + jitter
				if is_walkable(t2):
					return t2
	return Vector2i.ZERO

## Internals

func _get_nav_tilemap() -> TileMap:
	# Use TileMapManager references directly to avoid reliance on scene tree membership
	if TileMapManager and TileMapManager.build_tile_map:
		return TileMapManager.build_tile_map
	if TileMapManager and TileMapManager.base_tile_map:
		return TileMapManager.base_tile_map
	return null

func _get_furnishing_manager() -> FurnishingManager:
	# Resolve via absolute path first to avoid reliance on local scene membership
	var root := _get_root()
	if root:
		var node := root.get_node_or_null("Main/GameManager/FurnishingManager")
		if node:
			return node
	# Fallback: search by group on the SceneTree
	var main_loop := Engine.get_main_loop()
	if main_loop and main_loop.has_method("get_nodes_in_group"):
		var furnishing_managers: Array = main_loop.get_nodes_in_group("FurnishingManager")
		if furnishing_managers and furnishing_managers.size() > 0:
			return furnishing_managers[0] as FurnishingManager
	return null

func _get_root() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop and main_loop.has_method("get_root"):
		return main_loop.get_root()
	return null

func _is_on_navigation(world_pos: Vector2) -> bool:
	var root_node := _get_root()
	if root_node == null:
		return false
	var navigation_region := root_node.get_node_or_null("Main/GameManager/NavigationRegion")
	if navigation_region == null:
		return true  # Fail-open if region not found to avoid blocking movement entirely
	var nav_map_rid: RID = navigation_region.get_navigation_map()
	if nav_map_rid == RID():
		return true
	var closest_point: Vector2 = NavigationServer2D.map_get_closest_point(nav_map_rid, world_pos)
	# Consider on-nav if the closest point is very near our query
	return closest_point.distance_to(world_pos) <= 8.0



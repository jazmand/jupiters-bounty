class_name FlowFieldService
extends Node

# Builds and caches flow fields (distance + direction) over the tile grid.
# Door-aware traversal: only allows crossing between rooms via door tiles.
# Furniture-aware walkability: blocks tiles occupied by furniture instances.

signal cache_invalidated

class FlowField:
	var id: int
	var version: int
	var bounds: Rect2i
	var distance := {}   # Dictionary<Vector2i, int>
	var direction := {}  # Dictionary<Vector2i, Vector2i>

var _next_id: int = 1
var _cache := {}             # Dictionary<String, FlowField>
var _nav_version: int = 0
var _furniture_version: int = 0

func mark_nav_dirty() -> void:
	_nav_version += 1
	_cache.clear()
	cache_invalidated.emit()

func mark_furniture_dirty() -> void:
	_furniture_version += 1
	_cache.clear()
	cache_invalidated.emit()

func get_current_version() -> int:
	"""Get the current combined version (nav_version ^ furniture_version)"""
	return _nav_version ^ _furniture_version

func get_field_to_tile(goal_tile: Vector2i, radius: int = -1, room: Room = null) -> FlowField:
	var cache_key := _make_key([goal_tile], room, radius)
	if _cache.has(cache_key):
		return _cache[cache_key]
	var seed_tiles: Array[Vector2i] = [goal_tile]
	var field := _build_field(seed_tiles, radius, room)
	_cache[cache_key] = field
	return field

func get_field_for_seeds(seed_tiles: Array[Vector2i], room: Room = null, radius: int = -1) -> FlowField:
	var cache_key := _make_key(seed_tiles, room, radius)
	if _cache.has(cache_key):
		return _cache[cache_key]
	var field := _build_field(seed_tiles, radius, room)
	_cache[cache_key] = field
	return field

func get_field_to_furniture(furniture: Furniture, radius: int = -1) -> FlowField:
	if furniture == null:
		return null
	var access_tiles := FlowTargets.new().furniture_access_tiles(furniture)
	# If there are no access tiles (e.g., furniture up against walls), seed the room's door tiles
	var room := furniture.get_parent() if (furniture.get_parent() is Room) else null
	if access_tiles.is_empty() and room != null:
		access_tiles = FlowTargets.new().door_tiles(room)
	return get_field_for_seeds(access_tiles, room, radius)

func get_direction(field: FlowField, tile: Vector2i) -> Vector2i:
	if field == null:
		return Vector2i.ZERO
	if field.direction.has(tile):
		return field.direction[tile]
	return Vector2i.ZERO

func get_next_tile(field: FlowField, tile: Vector2i) -> Vector2i:
	var dir := get_direction(field, tile)
	return tile + dir

func _build_field(seed_tiles: Array[Vector2i], radius: int, room: Room) -> FlowField:
	var field := FlowField.new()
	field.id = _next_id
	_next_id += 1
	field.version = _nav_version ^ _furniture_version

	var distance := {}
	var dir_out := {}

	var frontier: Array = []
	for seed in seed_tiles:
		if _is_walkable(seed) and (room == null or _is_in_room(room, seed)):
			distance[seed] = 0
			frontier.append(seed)

	# Door-aware BFS (4-neighborhood)
	var nav := NavGridProvider.new()
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var current_dist: int = distance[current]
		if radius > 0 and current_dist >= radius:
			continue
		for neighbor in _neighbors4(current):
			if not _is_walkable(neighbor):
				continue
			# Keep BFS bounded to the navigation map to prevent gradients outside nav area
			var neighbor_world := nav.tile_center_world(neighbor)
			if not nav._is_on_navigation(neighbor_world):
				continue
			if room != null and not _is_in_room(room, neighbor):
				# Allow stepping onto door tiles of this room OR crossing boundary on door edge
				if not _is_door_of_room(room, neighbor) and not _door_transition(current, neighbor):
					continue
			# Enforce door-only boundary transitions
			if not nav.can_traverse(current, neighbor):
				continue
			if not distance.has(neighbor):
				distance[neighbor] = current_dist + 1
				frontier.append(neighbor)

	# Create downhill directions with tie-breaking toward goal to prevent corner oscillations
	for tile_key in distance.keys():
		var best_dir := Vector2i.ZERO
		var best_val: int = int(distance[tile_key])
		var best_neighbors: Array[Vector2i] = []  # Track all neighbors with best distance
		
		for neighbor2 in _neighbors4(tile_key):
			if distance.has(neighbor2):
				var neighbor_dist: int = distance[neighbor2]
				if neighbor_dist < best_val:
					best_val = neighbor_dist
					best_neighbors.clear()
					best_neighbors.append(neighbor2)
				elif neighbor_dist == best_val:
					# Same distance - keep for tie-breaking
					best_neighbors.append(neighbor2)
		
		# If multiple neighbors have same best distance, pick the one most aligned with goal direction
		if best_neighbors.size() > 1:
			var goal_tile: Vector2i = Vector2i.ZERO
			# Find a seed tile as our goal (use first seed for direction hint)
			if seed_tiles.size() > 0:
				goal_tile = seed_tiles[0]
			
			var best_dot: float = -999999.0
			var chosen_neighbor: Vector2i = best_neighbors[0]
			var to_goal_normalized: Vector2 = Vector2(goal_tile - tile_key).normalized()
			
			for candidate in best_neighbors:
				var to_neighbor_normalized: Vector2 = Vector2(candidate - tile_key).normalized()
				var dot: float = to_neighbor_normalized.dot(to_goal_normalized)
				if dot > best_dot:
					best_dot = dot
					chosen_neighbor = candidate
			
			best_dir = chosen_neighbor - tile_key
		elif best_neighbors.size() == 1:
			best_dir = best_neighbors[0] - tile_key
		
		if best_dir != Vector2i.ZERO:
			dir_out[tile_key] = best_dir

	field.distance = distance
	field.direction = dir_out
	# Compute tight bounds
	var minx := 0
	var miny := 0
	var maxx := -1
	var maxy := -1
	for coord in distance.keys():
		if maxx < 0:
			minx = coord.x
			maxx = coord.x
			miny = coord.y
			maxy = coord.y
		else:
			minx = min(minx, coord.x)
			miny = min(miny, coord.y)
			maxx = max(maxx, coord.x)
			maxy = max(maxy, coord.y)
	field.bounds = Rect2i(Vector2i(minx, miny), Vector2i(max(0, maxx - minx + 1), max(0, maxy - miny + 1)))
	return field

func _neighbors4(t: Vector2i) -> Array[Vector2i]:
	return [t + Vector2i(0, -1), t + Vector2i(1, 0), t + Vector2i(0, 1), t + Vector2i(-1, 0)]

func _is_walkable(tile: Vector2i) -> bool:
	return NavGridProvider.new().is_walkable(tile)

func _is_in_room(room: Room, tile: Vector2i) -> bool:
	return room != null and room.is_coord_in_room(tile)

func _is_door_of_room(room: Room, tile: Vector2i) -> bool:
	if room == null or room.data == null:
		return false
	return room.data.door_tiles.has(tile)

func _door_transition(a: Vector2i, b: Vector2i) -> bool:
	# Returns true if the edge crosses a room boundary exactly at a door tile of either room
	var ra := Room.find_tile_room_id(a)
	var rb := Room.find_tile_room_id(b)
	if ra == rb:
		return false
	var r1 := Global.station.find_room_by_id(ra)
	var r2 := Global.station.find_room_by_id(rb)
	if r1 and r1.data and r1.data.door_tiles.has(a):
		return true
	if r1 and r1.data and r1.data.door_tiles.has(b):
		return true
	if r2 and r2.data and r2.data.door_tiles.has(a):
		return true
	if r2 and r2.data and r2.data.door_tiles.has(b):
		return true
	return false

func _make_key(seed_tiles: Array[Vector2i], room: Room, radius: int) -> String:
	var parts := []
	parts.append("nav:" + str(_nav_version))
	parts.append("furn:" + str(_furniture_version))
	if room:
		parts.append("room:" + str(room.data.id))
	parts.append("r:" + str(radius))
	# Sort seeds for deterministic key
	var sorted_seeds := seed_tiles.duplicate()
	sorted_seeds.sort_custom(func(a, b): return a.x == b.x and a.y < b.y or a.x < b.x)
	for tile in sorted_seeds:
		parts.append(str(tile.x) + "," + str(tile.y))
	return ";".join(parts)



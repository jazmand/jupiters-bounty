class_name FlowTargets
extends Node

# Computes target tiles for flow fields, e.g., furniture access tiles and room door tiles.
# It leverages existing logic for access-required sides and rotation used by FurnishingManager/FurnitureType.

func furniture_access_tiles(furniture: Furniture) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if furniture == null or furniture.furniture_type == null:
		print("[FlowTargets] ERROR: Furniture or furniture_type is null")
		return out

	var ft: FurnitureType = furniture.furniture_type
	print("[FlowTargets] Computing access tiles for ", ft.name, " (rotation: ", furniture.rotation_state, ")")
	
	# Determine required sides based on furniture's rotation
	var is_rotated := furniture.rotation_state == 1
	var required_sides: Array = []
	if is_rotated and ft.access_required_sides_rotated.size() > 0:
		required_sides = ft.access_required_sides_rotated.duplicate()
		print("[FlowTargets] Using rotated sides: ", required_sides)
	else:
		# Transform base sides by rotation
		required_sides = _transform_sides_for_rotation(ft.access_required_sides, is_rotated)
		print("[FlowTargets] Using transformed sides: ", required_sides, " (from base: ", ft.access_required_sides, ")")

	# Build quick lookup for occupied tiles
	var occupied := {}
	var tiles := furniture.get_occupied_tiles()
	print("[FlowTargets] Furniture occupied tiles: ", tiles)
	for t in tiles:
		occupied[t] = true

	# Bounds for iteration
	var min_x: int = int(tiles[0].x)
	var max_x: int = int(tiles[0].x)
	var min_y: int = int(tiles[0].y)
	var max_y: int = int(tiles[0].y)
	for t in tiles:
		min_x = min(min_x, t.x)
		max_x = max(max_x, t.x)
		min_y = min(min_y, t.y)
		max_y = max(max_y, t.y)
	
	print("[FlowTargets] Furniture bounds: min(", min_x, ",", min_y, ") max(", max_x, ",", max_y, ")")

	# For each side, collect all adjacent tiles along that side
	for side in required_sides:
		print("[FlowTargets] Processing side: ", side)
		match side:
			"north":
				var y: int = min_y - 1
				for x in range(min_x, max_x + 1):
					var adj := Vector2i(x, y)
					print("[FlowTargets] Checking north tile ", adj)
					if not occupied.has(adj) and _is_valid_access_tile(adj, furniture):
						print("[FlowTargets] Valid north access tile: ", adj)
						out.append(adj)
					else:
						print("[FlowTargets] Invalid north tile ", adj, " (occupied: ", occupied.has(adj), ", valid: ", _is_valid_access_tile(adj, furniture), ")")
			"south":
				var y2: int = max_y + 1
				for x2 in range(min_x, max_x + 1):
					var adj2 := Vector2i(x2, y2)
					print("[FlowTargets] Checking south tile ", adj2)
					if not occupied.has(adj2) and _is_valid_access_tile(adj2, furniture):
						print("[FlowTargets] Valid south access tile: ", adj2)
						out.append(adj2)
					else:
						print("[FlowTargets] Invalid south tile ", adj2, " (occupied: ", occupied.has(adj2), ", valid: ", _is_valid_access_tile(adj2, furniture), ")")
			"west":
				var xw: int = min_x - 1
				for y3 in range(min_y, max_y + 1):
					var adj3 := Vector2i(xw, y3)
					print("[FlowTargets] Checking west tile ", adj3)
					if not occupied.has(adj3) and _is_valid_access_tile(adj3, furniture):
						print("[FlowTargets] Valid west access tile: ", adj3)
						out.append(adj3)
					else:
						print("[FlowTargets] Invalid west tile ", adj3, " (occupied: ", occupied.has(adj3), ", valid: ", _is_valid_access_tile(adj3, furniture), ")")
			"east":
				var xe: int = max_x + 1
				for y4 in range(min_y, max_y + 1):
					var adj4 := Vector2i(xe, y4)
					print("[FlowTargets] Checking east tile ", adj4)
					if not occupied.has(adj4) and _is_valid_access_tile(adj4, furniture):
						print("[FlowTargets] Valid east access tile: ", adj4)
						out.append(adj4)
					else:
						print("[FlowTargets] Invalid east tile ", adj4, " (occupied: ", occupied.has(adj4), ", valid: ", _is_valid_access_tile(adj4, furniture), ")")

	# De-duplicate
	var unique := {}
	var result: Array[Vector2i] = []
	for a in out:
		var k := str(a.x) + ":" + str(a.y)
		if not unique.has(k):
			unique[k] = true
			result.append(a)
	
	print("[FlowTargets] Final access tiles: ", result)
	return result

func door_tiles(room: Room) -> Array[Vector2i]:
	if room == null or room.data == null:
		return []
	return room.data.door_tiles.duplicate()

func _is_valid_access_tile(tile: Vector2i, furniture: Furniture) -> bool:
	# Must be inside the containing room and not occupied by furniture
	var room := furniture.get_parent()
	if room == null or not (room is Room):
		print("[FlowTargets] Tile ", tile, " invalid: furniture not in room")
		return false
	if not room.is_coord_in_room(tile):
		print("[FlowTargets] Tile ", tile, " invalid: not in room")
		return false
	# Avoid counting tiles already occupied by any furniture instance
	var fm_script := preload("res://scripts/utilities/NavGridProvider.gd")
	var grid := fm_script.new()
	var fm := grid._get_furnishing_manager()
	if fm != null:
		var here: Array = fm.get_furniture_at_tile(tile)
		if here != null and not here.is_empty():
			print("[FlowTargets] Tile ", tile, " invalid: occupied by furniture")
			return false
	
	print("[FlowTargets] Tile ", tile, " is valid access tile")
	return true

func _transform_sides_for_rotation(sides: Array, is_rotated: bool) -> Array:
	if not is_rotated:
		return sides.duplicate()
	var mapping := {
		"north": "east",
		"east": "south",
		"south": "west",
		"west": "north"
	}
	var out: Array = []
	for s in sides:
		if mapping.has(s):
			out.append(mapping[s])
		else:
			out.append(s)
	return out



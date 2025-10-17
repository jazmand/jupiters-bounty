class_name AssignmentBeacons
extends Node

# Reserves a unique access-adjacent tile per crew when assigned to furniture.
# Releases the reservation on unassign.

var crewIdToTile: Dictionary = {}
var reservedKeyToCrew: Dictionary = {}

func reserve_for_crew(furniture: Furniture, crew_id: int, crew_world_pos: Vector2) -> Vector2i:
	if furniture == null:
		return Vector2i.ZERO
	# If already reserved, return existing
	if crewIdToTile.has(str(crew_id)):
		return crewIdToTile[str(crew_id)]
	# Compute access tiles (respecting rotation and room bounds)
	var accessTiles: Array[Vector2i] = FlowTargets.new().furniture_access_tiles(furniture)
	if accessTiles.is_empty():
		# Fall back to door tiles if furniture access is constrained
		if furniture.get_parent() is Room:
			accessTiles = FlowTargets.new().door_tiles(furniture.get_parent())
		else:
			return Vector2i.ZERO
	# Filter out already reserved tiles and require true adjacency to the furniture footprint
	var candidateTiles: Array[Vector2i] = []
	var grid := NavGridProvider.new()
	var crew_tile: Vector2i = grid.world_to_tile(crew_world_pos)
	for accessTile in accessTiles:
		if reservedKeyToCrew.has(_key(accessTile)):
			continue
		if not is_adjacent_to_furniture(accessTile, furniture):
			continue
		if not grid.is_walkable(accessTile):
			continue
		# If the crew is already standing on this tile, only accept it if it truly touches the furniture
		if accessTile == crew_tile and not is_adjacent_to_furniture(crew_tile, furniture):
			continue
		candidateTiles.append(accessTile)
	if candidateTiles.is_empty():
		return Vector2i.ZERO
	# Pick the tile closest to the furniture footprint center to ensure adjacency
	var bestTile: Vector2i = candidateTiles[0]
	var bestDistance := INF
	var furnitureCenterWorld := _world_center_of_footprint(furniture)
	for candidate in candidateTiles:
		var candidateWorld: Vector2 = _tile_world_center(candidate)
		var dist := furnitureCenterWorld.distance_to(candidateWorld)
		if dist < bestDistance:
			bestDistance = dist
			bestTile = candidate
	# Reserve
	crewIdToTile[str(crew_id)] = bestTile
	reservedKeyToCrew[_key(bestTile)] = crew_id
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



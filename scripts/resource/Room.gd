# Room.gd

class_name Room
extends Resource

@export var id: int
@export var roomType: RoomType
@export var topLeft: Vector2i
@export var bottomRight: Vector2i
@export var doorTiles: Array[Vector2i]
@export var hotSpots: Array[Vector2i]

func _init(
	p_id: int = 0,
	p_roomType: RoomType = RoomType.new(), # Instantiate a blank RoomType
	p_topLeft: Vector2i = Vector2i(0, 0),
	p_bottomRight: Vector2i = Vector2i(0, 0)
):
	id = p_id
	roomType = p_roomType
	topLeft = p_topLeft
	bottomRight = p_bottomRight
	doorTiles = []
	hotSpots = []

func add_door_tile(tile_coords: Vector2i) -> void:
	if is_exterior_tile(tile_coords):
		doorTiles.append(tile_coords)

func is_exterior_tile(tile_coords: Vector2i) -> bool:
	return (tile_coords.x == topLeft.x or tile_coords.x == bottomRight.x) and (tile_coords.y == topLeft.y or tile_coords.y == bottomRight.y)

func clear_door_tiles() -> void:
	doorTiles.clear()

func calculate_tile_count(vector1: Vector2i, vector2: Vector2i) -> int:
	return (abs(vector2.x - vector1.x) + 1) * (abs(vector2.y - vector1.y) + 1)

func calculate_power_consumption() -> int:
	var tile_count = calculate_tile_count(topLeft, bottomRight)
	return tile_count * roomType.powerConsumption
	
func generate_hotspots() -> void:
	hotSpots.clear()
	var capacity = roomType.capacity
	var tile_count = calculate_tile_count(topLeft, bottomRight)
	var available_tiles = []
	
	var min_x = min(topLeft.x, bottomRight.x)
	var max_x = max(topLeft.x, bottomRight.x) + 1
	var min_y = min(topLeft.y, bottomRight.y)
	var max_y = max(topLeft.y, bottomRight.y) + 1
	
	for x in range(min_x, bottomRight.x + 1):
		for y in range(min_y, max_y):
			var tile = Vector2i(x, y)
			if !doorTiles.has(tile):
				available_tiles.append(tile)
				
	var hotspot_count = int(round(available_tiles.size() * roomType.capacity))
	for i in hotspot_count:
		var rand_index = randi() % available_tiles.size()
		hotSpots.append(available_tiles[rand_index])
		available_tiles.remove_at(rand_index)
	

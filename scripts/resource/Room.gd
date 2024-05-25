# Room.gd

class_name Room
extends Resource

@export var id: int
@export var roomType: RoomType
@export var topLeft: Vector2i
@export var bottomRight: Vector2i
@export var doorTiles: Array[Vector2i]

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

func add_door_tile(tile_coords: Vector2i) -> void:
	if is_exterior_tile(tile_coords):
		doorTiles.append(tile_coords)

func is_exterior_tile(tile_coords: Vector2) -> bool:
	return (tile_coords.x == topLeft.x or tile_coords.x == bottomRight.x) and (tile_coords.y == topLeft.y or tile_coords.y == bottomRight.y)

func clear_door_tiles() -> void:
	doorTiles.clear()

func calculate_tile_count(vector1: Vector2, vector2: Vector2) -> int:
	return (abs(vector2.x - vector1.x) + 1) * (abs(vector2.y - vector1.y) + 1)

func calculate_power_consumption() -> int:
	var tileCount = calculate_tile_count(topLeft, bottomRight)
	return tileCount * roomType.powerConsumption
	

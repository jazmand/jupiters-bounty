# Room.gd

extends Resource

class_name Room

@export var id: int
@export var roomTypeId: int
@export var topLeft: Vector2i
@export var bottomRight: Vector2i
@export var doorTiles: Array[Vector2i]

func _init(
	p_id: int = 0,
	p_roomTypeId: int = 0,
	p_topLeft: Vector2i = Vector2i(0, 0),
	p_bottomRight: Vector2i = Vector2i(0, 0)
):
	id = p_id
	roomTypeId = p_roomTypeId
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

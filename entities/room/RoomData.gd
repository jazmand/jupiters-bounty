class_name RoomData extends Resource

var id: int
@export var type: RoomType
@export var top_left: Vector2i
@export var bottom_right: Vector2i
@export var door_tiles: Array[Vector2i]

# @export var furniture_items: Array[Furniture] = []

func _init(
	room_id: int = 0,
	room_type: RoomType = RoomType.new(), # Instantiate a blank RoomType
	room_top_left: Vector2i = Vector2i(0, 0),
	room_bottom_right: Vector2i = Vector2i(0, 0)
):
	id = room_id
	type = room_type
	top_left = room_top_left
	bottom_right = room_bottom_right
	door_tiles = []

	#furniture_items = []

func add_door_tile(tile_coords: Vector2i) -> void:
	if is_exterior_tile(tile_coords):
		door_tiles.append(tile_coords)

func is_exterior_tile(tile_coords: Vector2i) -> bool:
	return (tile_coords.x == top_left.x or tile_coords.x == bottom_right.x) and (tile_coords.y == top_left.y or tile_coords.y == bottom_right.y)

func clear_door_tiles() -> void:
	door_tiles.clear()

func calculate_tile_count(vector1: Vector2i, vector2: Vector2i) -> int:
	return (abs(vector2.x - vector1.x) + 1) * (abs(vector2.y - vector1.y) + 1)

func calculate_power_consumption() -> int:
	return 0

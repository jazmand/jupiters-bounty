class_name RoomData extends Resource

var id: int
@export var type: RoomType
@export var top_left: Vector2i
@export var bottom_right: Vector2i
@export var door_tiles: Array[Vector2i]
@export var hot_spots: Array[Vector2i]
var assigned_crew_ids: Array[int]

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
	hot_spots = []
	assigned_crew_ids = []

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
	var tile_count = calculate_tile_count(top_left, bottom_right)
	return tile_count * type.power_consumption
	
func generate_hotspots() -> void:
	hot_spots.clear()
	var available_tiles = []
	
	var min_x = min(top_left.x, bottom_right.x)
	var max_x = max(top_left.x, bottom_right.x) + 1
	var min_y = min(top_left.y, bottom_right.y)
	var max_y = max(top_left.y, bottom_right.y) + 1
	
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var tile = Vector2i(x, y)
			if !door_tiles.has(tile):
				available_tiles.append(tile)
				
	var hotspot_count = int(round(available_tiles.size() * type.capacity))
	for i in hotspot_count:
		var rand_index = randi() % available_tiles.size()
		hot_spots.append(available_tiles[rand_index])
		available_tiles.remove_at(rand_index)

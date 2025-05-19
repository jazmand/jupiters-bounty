class_name Room extends Node2D

static var tile_to_id_map: Dictionary = {}

var data: RoomData

func _init() -> void:
	data = RoomData.new()

func set_data(
	id: int,
	room_type: RoomType, 
	top_left: Vector2i,
	bottom_right: Vector2i,
	door_tiles: Array[Vector2i]
	) -> void:
		data.id = id
		data.type = room_type
		data.top_left = top_left
		data.bottom_right = bottom_right
		data.door_tiles.append_array(door_tiles)
		add_room_to_id_map(id, top_left, bottom_right)

func add_room_to_id_map(id: int, top_left: Vector2i, bottom_right: Vector2i) -> void:
	var min_x: int = min(top_left.x, bottom_right.x)
	var min_y: int = min(top_left.y, bottom_right.y)
	for y in range(min_y, max(top_left.y, bottom_right.y) + 1):
		for x in range(min_x, max(top_left.x, bottom_right.x) + 1):
			tile_to_id_map[Vector2i(x, y)] = id

static func find_tile_room_id(tile_coords: Vector2i) -> int:
	return tile_to_id_map.get(tile_coords, 0)

static func calculate_room_price(price: int, tile_count: int) -> int:
	return price * tile_count

static func calculate_tile_count(vector1: Vector2, vector2: Vector2) -> int:
	return (abs(vector2.x - vector1.x) + 1) * (abs(vector2.y - vector1.y) + 1)

func can_assign_crew() -> bool:
	return data.assigned_crew_ids.size() < data.hot_spots.size()

func assign_crew(crew: CrewMember) -> Vector2:
	data.assigned_crew_ids.append(crew.data.id)
	return data.hot_spots[data.assigned_crew_ids.size() - 1]

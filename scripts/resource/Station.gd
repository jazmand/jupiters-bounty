# Station.gd

class_name Station
extends Resource

signal hydrogen_updated(hydrogen: int)
signal max_hydrogen_updated(max_hydrogen: int)
signal power_updated(power: int)
signal currency_updated(currency: int)
signal crew_updated(crew: int)
signal time_updated(time: int)

@export var id: int
@export var hydrogen: int:
	set(h):
		if h <= max_hydrogen:
			hydrogen = h
			hydrogen_updated.emit(h)
@export var max_hydrogen: int = 100:
	set(mh):
		max_hydrogen = mh
		max_hydrogen_updated.emit(mh)
@export var power: int:
	set(p):
		power = p
		power_updated.emit(p)
@export var currency: int:
	set(c):
		currency = c
		currency_updated.emit(c)
@export var crew: int:
	set(c):
		crew = c
		crew_updated.emit(c)
@export var rooms: Array[Room]:
	set(r):
		rooms = r
		update_max_hydrogen()
		update_power()
@export var time: int:
	set(t):
		time = t
		time_updated.emit(t)

func _init(p_id: int = 0, p_hydrogen: int = 0, p_power: int = 0, p_currency: int = 0, p_crew: int = 0, p_rooms: Array[Room] = [], p_time: int = 0):
	id = p_id
	hydrogen = p_hydrogen
	power = p_power
	currency = p_currency
	crew = p_crew
	rooms = p_rooms
	time = p_time
	update_max_hydrogen()

func calculate_power_consumption_all_rooms() -> int:
	var total_consuming_tiles = 0
	var total_producing_tiles = 0
	for room in rooms:
		if room.roomType.id == 2: # 2 is the ID for generator rooms
			total_producing_tiles += room.calculate_tile_count(room.topLeft, room.bottomRight)
		else:
			total_consuming_tiles += room.calculate_tile_count(room.topLeft, room.bottomRight)
	return total_producing_tiles - total_consuming_tiles
	
func update_power() -> void:
	power = calculate_power_consumption_all_rooms() * 100

func update_hydrogen() -> void:
	hydrogen += 5

func update_max_hydrogen() -> void:
	var total_storage_tiles = 0
	for room in rooms:
		if room.roomType.id == 3: # 3 is the ID for storage bays
			total_storage_tiles += room.calculate_tile_count(room.topLeft, room.bottomRight)
	max_hydrogen = 100 + (total_storage_tiles * 10)
	
func add_room(room: Room) -> void:
	var new_rooms: Array[Room] = rooms.duplicate()
	new_rooms.append(room)
	rooms = new_rooms

func remove_room(room_id: int) -> void:
	var new_rooms: Array[Room] = []
	for room in rooms:
		if room.id != room_id:
			new_rooms.append(room)
	print(new_rooms)
	rooms = new_rooms

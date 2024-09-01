class_name Station extends Resource

signal hydrogen_updated(hydrogen: int)
signal max_hydrogen_updated(max_hydrogen: int)
signal power_updated(power: int)
signal currency_updated(currency: int)
signal crew_updated(crew: int)
signal rooms_updated

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

var crew: Array[CrewMember] = []

var rooms: Array[Room] = []

func _init(p_id: int = 0, p_hydrogen: int = 0, p_power: int = 0, p_currency: int = 0):
	id = p_id
	hydrogen = p_hydrogen
	power = p_power
	currency = p_currency

	update_max_hydrogen()

func calculate_power_consumption_all_rooms() -> int:
	var total_consumption = 0
	for room in rooms:
		total_consumption += room.data.calculate_tile_count(room.data.top_left, room.data.bottom_right) * room.data.type.power_consumption
	return -total_consumption
	
func update_power() -> void:
	power = calculate_power_consumption_all_rooms()

func update_hydrogen() -> void:
	hydrogen += 5

func update_max_hydrogen() -> void:
	var total_storage_tiles = 0
	for room in rooms:
		if room.data.type.id == Global.ROOMTYPE.STORAGE_BAY:
			total_storage_tiles += room.data.calculate_tile_count(room.data.top_left, room.data.bottom_right)
	max_hydrogen = 100 + (total_storage_tiles * 10)

func add_crew(crew_member: CrewMember) -> void:
	crew.append(crew_member)
	crew_updated.emit(crew.size())

func remove_crew(crew_member: CrewMember) -> void:
	crew.erase(crew_member)
	crew_updated.emit(crew.size())

func find_crew_by_id(crew_id: int) -> CrewMember:
	for crew_member in crew:
		if crew_member.data.id == crew_id:
			return crew_member
	return null
	
func add_room(room: Room) -> void:
	rooms.append(room)
	update_max_hydrogen()
	update_power()

func remove_room(room: Room) -> void:
	rooms.erase(room)
	room.queue_free()
	update_max_hydrogen()
	update_power()

func find_room_by_id(room_id: int) -> Room:
	for room in rooms:
		if room.data.id == room_id:
			return room
	return null

# Station.gd

class_name Station
extends Resource

@export var id: int
@export var hydrogen: int:
	set(h):
		hydrogen = h
		StationEvent.hydrogen_updated.emit(h)
@export var power: int:
	set(p):
		power = p
		StationEvent.power_updated.emit(p)
@export var currency: int:
	set(c):
		currency = c
		StationEvent.currency_updated.emit(c)
@export var crew: int:
	set(c):
		crew = c
		StationEvent.crew_updated.emit(c)
@export var rooms: Array[Room]
	
@export var time: int:
	set(t):
		time = t
		StationEvent.time_updated.emit(t)


func _init(p_id: int = 0, p_hydrogen: int = 0, p_power: int = 0, p_currency: int = 0, p_crew: int = 0, p_rooms: Array[Room] = [], p_time: int = 0):
	id = p_id
	hydrogen = p_hydrogen
	power = p_power
	currency = p_currency
	crew = p_crew
	rooms = p_rooms
	time = p_time

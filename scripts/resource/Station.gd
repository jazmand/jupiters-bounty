# Station.gd

class_name Station
extends Resource

signal hydrogen_updated(hydrogen: int)
signal power_updated(power: int)
signal currency_updated(currency: int)
signal crew_updated(crew: int)
signal time_updated(time: int)

@export var id: int
@export var hydrogen: int:
	set(h):
		hydrogen = h
		hydrogen_updated.emit(h)
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
@export var rooms: Array[Room]
	
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

# Station.gd

class_name Station
extends Resource

@export var id: int
@export var hydrogen: int
@export var power: int
@export var currency: int
@export var crew: int
@export var rooms: Array[Room]
@export var time: int


func _init(p_id: int = 0, p_hydrogen: int = 0, p_power: int = 0, p_currency: int = 0, p_crew: int = 0, p_rooms: Array[Room] = [], p_time: int = 0):
	id = p_id
	hydrogen = p_hydrogen
	power = p_power
	currency = p_currency
	crew = p_crew
	rooms = p_rooms
	time = p_time

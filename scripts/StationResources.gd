extends Resource

@export var id: int
@export var hydrogen: int
@export var power: int
@export var currency: int
@export var crew: int


func _init(p_id = 0, p_hydrogen = 0, p_power = 0, p_currency = 0, p_crew = 0):
	id = p_id
	hydrogen = p_hydrogen
	power = p_power
	currency = p_currency
	crew = p_crew

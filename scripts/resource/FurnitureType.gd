class_name FurnitureType extends Resource

@export var id: int
@export var name: String
@export var price: int
@export var power_consumption: int
@export var simultaneous_users: int
@export var tileset_id: int
@export var height: int
@export var width: int
@export var valid_room_types: Array

func _init(
	p_id: int = 0,
	p_name: String = "",
	p_price: int = 0,
	p_power_consumption: int = 0,
	p_simultaneous_users: int = 1,
	p_tileset_id: int = 0,
	p_height: int = 1,
	p_width: int = 1,
	p_valid_room_types = []
):
	id = p_id
	name = p_name
	price = p_price
	power_consumption = p_power_consumption
	simultaneous_users = p_simultaneous_users
	height = p_height
	width = p_width
	tileset_id = p_tileset_id
	valid_room_types = p_valid_room_types 
	

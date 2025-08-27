class_name FurnitureType extends Resource

@export var id: int
@export var name: String
@export var price: int
@export var power_consumption: int
@export var simultaneous_users: int
@export var tileset_id: int
@export var tileset_coords: Array[Vector2i]
@export var tileset_coords_rotated: Array[Vector2i]  # Rotated version of the furniture
@export var height: int
@export var width: int
@export var valid_room_types: Array
@export var supports_rotation: bool = false  # Whether this furniture can be rotated

func _init(
	p_id: int = 0,
	p_name: String = "",
	p_price: int = 0,
	p_power_consumption: int = 0,
	p_simultaneous_users: int = 1,
	p_tileset_id: int = 0,
	p_tileset_coords = [] as Array[Vector2i],
	p_tileset_coords_rotated = [] as Array[Vector2i],
	p_height: int = 1,
	p_width: int = 1,
	p_valid_room_types = [],
	p_supports_rotation: bool = false
):
	id = p_id
	name = p_name
	price = p_price
	power_consumption = p_power_consumption
	simultaneous_users = p_simultaneous_users
	height = p_height
	width = p_width
	tileset_id = p_tileset_id
	tileset_coords = p_tileset_coords
	tileset_coords_rotated = p_tileset_coords_rotated
	valid_room_types = p_valid_room_types
	supports_rotation = p_supports_rotation

func get_tileset_coords_for_rotation(is_rotated: bool) -> Array[Vector2i]:
	# Return the appropriate tileset coordinates based on rotation state
	if supports_rotation and is_rotated and tileset_coords_rotated.size() > 0:
		return tileset_coords_rotated
	else:
		return tileset_coords 
	

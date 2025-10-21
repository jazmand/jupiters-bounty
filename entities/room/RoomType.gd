class_name RoomType extends Resource

@export var id: int
@export var name: String
@export var price: int
@export var min_tiles: int
@export var max_tiles: int
@export var tileset_id: int

func _init(
	p_id: int = 0,
	p_name: String = "",
	p_price: int = 0,
	p_min_tiles: int = 0,
	p_max_tiles: int = 0,
	p_tileset_id: int = 0
):
	id = p_id
	name = p_name
	price = p_price
	min_tiles = p_min_tiles
	max_tiles = p_max_tiles
	tileset_id = p_tileset_id

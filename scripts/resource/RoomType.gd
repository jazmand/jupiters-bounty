# RoomType.gd

class_name RoomType
extends Resource

@export var id: int
@export var name: String
@export var price: int
@export var powerConsumption: int
@export var capacity: float
@export var minTiles: int
@export var maxTiles: int
@export var tilesetId: int

func _init(
	p_id: int = 0,
	p_name: String = "",
	p_price: int = 0,
	p_powerConsumption: int = 0,
	p_capacity: float = 0.0,
	p_minTiles: int = 0,
	p_maxTiles: int = 0,
	p_tilesetId: int = 0
):
	id = p_id
	name = p_name
	price = p_price
	powerConsumption = p_powerConsumption
	capacity = p_capacity
	minTiles = p_minTiles
	maxTiles = p_maxTiles
	tilesetId = p_tilesetId

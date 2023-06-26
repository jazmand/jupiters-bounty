# RoomType.gd

extends Resource

class_name RoomType

@export var id: int
@export var name: String
@export var initialPrice: int
@export var powerConsumption: int
@export var capacity: float
@export var minTiles: int
@export var maxTiles: int
@export var tileset: TileSet

func _init(
	p_id: int = 0,
	p_name: String = "",
	p_initialPrice: int = 0,
	p_powerConsumption: int = 0,
	p_capacity: float = 0.0,
	p_minTiles: int = 0,
	p_maxTiles: int = 0,
	p_tileset: TileSet = null
):
	id = p_id
	name = p_name
	initialPrice = p_initialPrice
	powerConsumption = p_powerConsumption
	capacity = p_capacity
	minTiles = p_minTiles
	maxTiles = p_maxTiles
	tileset = p_tileset

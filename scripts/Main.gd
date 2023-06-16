extends Node2D

var base_tile_map: TileMap
var building_tile_map: TileMap

func _ready():
	# Find the TileMap nodes
	base_tile_map = $BaseTileMap
	building_tile_map = $BaseTileMap/BuildingTileMap
	

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var tile_coords = base_tile_map.local_to_map(event.position)
		print(tile_coords)
		building_tile_map.set_cell(0, tile_coords, 0, Vector2i(0,0))
#		var tile_index = base_tile_map.get_cell_source_id(0, tile_pos)
#		print(tile_index)

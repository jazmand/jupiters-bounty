extends Node2D

var base_tile_map: TileMap
var build_tile_map: TileMap

var drafting_layer: int = 1
var building_layer: int = 0
var drafting_tileset_id: int = 1
var building_tileset_id: int = 0

var is_editing = false
var initial_tile_coords = Vector2i()
var transverse_tile_coords = Vector2i()
var blueprint = []

func _ready():
	# Find the TileMap nodes
	base_tile_map = $BaseTileMap
	build_tile_map = $BaseTileMap/BuildTileMap
	

func _input(event: InputEvent) -> void:
	# Click to initiate drafting
	if event is InputEventMouseButton and !is_editing:
		if event.pressed:
			is_editing = true
			initial_tile_coords = base_tile_map.local_to_map(event.position)
	# Move to resize room
	elif event is InputEventMouseMotion and is_editing:
		transverse_tile_coords = base_tile_map.local_to_map(event.position)
		draft_room(initial_tile_coords, transverse_tile_coords)
	# Click again to set
	elif event is InputEventMouseButton and is_editing:
		if event.pressed and event.button_index == 1:
			set_room()
			blueprint = []
			is_editing = false
		elif event.pressed and event.button_index == 2:
			build_tile_map.clear_layer(drafting_layer)
			blueprint = []
			is_editing = false

func draft_room(initial_corner: Vector2i, opposite_corner: Vector2i) -> void:
	# Clear previous selection
	build_tile_map.clear_layer(drafting_layer)
	blueprint = []
	
	var min_x = min(initial_corner.x, opposite_corner.x)
	var max_x = max(initial_corner.x, opposite_corner.x)
	var min_y = min(initial_corner.y, opposite_corner.y)
	var max_y = max(initial_corner.y, opposite_corner.y)
	
	# Redraw tile on all coordinates between inital and traverse corners
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			build_tile_map.set_cell(drafting_layer, Vector2(x, y), drafting_tileset_id, Vector2i(0, 0))
			blueprint.append(Vector2(x, y))
			
func set_room() -> void:
	# Clear drafting layer and apply draw the same tiles on the building layer
	build_tile_map.clear_layer(drafting_layer)
	for tile in blueprint:
		build_tile_map.set_cell(building_layer, Vector2(tile.x, tile.y), building_tileset_id, Vector2i(0, 0))

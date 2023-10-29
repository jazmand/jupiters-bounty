# RoomBuilder.gd

extends Node2D

class_name RoomBuilder

var building_layer: int = 0
var drafting_layer: int = 1

var selection_tileset_id: int = 0
var drafting_tileset_id: int = 1
var invalid_tileset_id: int = 2
var building_tileset_id: int = 3

var is_editing = false
var initial_tile_coords = Vector2i()
var transverse_tile_coords = Vector2i()
var blueprint = []
var any_invalid = false

var selected_room_type_id: int = 0

var base_tile_map: TileMap
var build_tile_map: TileMap

func _init(base_tile_map: TileMap, build_tile_map: TileMap):
	self.base_tile_map = base_tile_map
	self.build_tile_map = build_tile_map

func start_editing():
	is_editing = true

func stop_editing():
	is_editing = false
	selected_room_type_id = 0 # Deselect
	
func select_tile(coords: Vector2i):
	# Clear layer
	build_tile_map.clear_layer(drafting_layer)
	
	# Draw on tile
	if check_selection_valid(coords):
		build_tile_map.set_cell(drafting_layer, coords, selection_tileset_id, Vector2i(0, 0))
	else:
		build_tile_map.set_cell(drafting_layer, coords, invalid_tileset_id, Vector2i(0, 0))

func draft_room(initial_corner: Vector2i, opposite_corner: Vector2i):
	# Clear previous selection
	build_tile_map.clear_layer(drafting_layer)
	blueprint.clear()

	var min_x = min(initial_corner.x, opposite_corner.x)
	var max_x = max(initial_corner.x, opposite_corner.x)
	var min_y = min(initial_corner.y, opposite_corner.y)
	var max_y = max(initial_corner.y, opposite_corner.y)
	any_invalid = false

	# Redraw tile on all coordinates between initial and traverse corners
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var coords = Vector2(x, y)
			if check_selection_valid(coords):
				blueprint.append(coords)
			else:
				# If any tile is invalid use the invalid_tileset_id below
				any_invalid = true
				
	for coords in blueprint:
		if any_invalid:
			build_tile_map.set_cell(drafting_layer, coords, invalid_tileset_id, Vector2i(0, 0))
		else:
			build_tile_map.set_cell(drafting_layer, coords, drafting_tileset_id, Vector2i(0, 0))

func set_room():
	# Clear drafting layer and apply draw the same tiles on the building layer
	build_tile_map.clear_layer(drafting_layer)
	for tile in blueprint:
		build_tile_map.set_cell(building_layer, Vector2(tile.x, tile.y), building_tileset_id, Vector2i(0, 0))

func clear_all():
	is_editing = false
	selected_room_type_id = 0 # Deselect
	build_tile_map.clear_layer(drafting_layer)
	
func check_selection_valid(coords: Vector2i) -> bool:
	var is_valid = true 
	
	# Check if outside station bounds
	if !base_tile_map.get_cell_tile_data(0, coords) is TileData:
		is_valid = false
		
	# Check if overlapping an existing room
	elif build_tile_map.get_cell_tile_data(building_layer, coords) is TileData:
		is_valid = false
	
	return is_valid

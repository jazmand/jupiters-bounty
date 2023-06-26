# RoomBuilder.gd

extends Node2D

class_name RoomBuilder

var drafting_layer: int = 1
var building_layer: int = 0
var drafting_tileset_id: int = 1
var building_tileset_id: int = 0

var is_editing = false
var initial_tile_coords = Vector2i()
var transverse_tile_coords = Vector2i()
var blueprint = []

var base_tile_map: TileMap
var build_tile_map: TileMap

func _init(base_tile_map: TileMap, build_tile_map: TileMap):
	self.base_tile_map = base_tile_map
	self.build_tile_map = build_tile_map

func start_editing():
	is_editing = true

func stop_editing():
	is_editing = false

func draft_room(initial_corner: Vector2i, opposite_corner: Vector2i):
	# Clear previous selection
	build_tile_map.clear_layer(drafting_layer)
	blueprint.clear()

	var min_x = min(initial_corner.x, opposite_corner.x)
	var max_x = max(initial_corner.x, opposite_corner.x)
	var min_y = min(initial_corner.y, opposite_corner.y)
	var max_y = max(initial_corner.y, opposite_corner.y)

	# Redraw tile on all coordinates between initial and traverse corners
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			build_tile_map.set_cell(drafting_layer, Vector2(x, y), drafting_tileset_id, Vector2i(0, 0))
			blueprint.append(Vector2(x, y))

func set_room():
	# Clear drafting layer and apply draw the same tiles on the building layer
	build_tile_map.clear_layer(drafting_layer)
	for tile in blueprint:
		build_tile_map.set_cell(building_layer, Vector2(tile.x, tile.y), building_tileset_id, Vector2i(0, 0))

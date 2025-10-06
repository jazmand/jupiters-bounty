extends Node

# Tile map references - will be set via set_tile_maps
var base_tile_map: TileMap
var build_tile_map: TileMap
var furniture_tile_map: TileMap
var special_furniture_tile_map: TileMap

# Private tile map references for internal functions
var _base_tile_map: TileMap
var _build_tile_map: TileMap
var _furniture_tile_map: TileMap
var _special_furniture_tile_map: TileMap

# Layer constants - organized by TileMap
enum Layer {
	# BaseTileMap layers
	BASE = 0,           # Base station tiles (background)
	
	# BuildTileMap layers  
	BUILD_DRAFTING = 0, # Room drafting preview tiles (on BuildTileMap)
	BUILDING = 1,       # Room building tiles (on BuildTileMap)
	
	# FurnitureTileMap layers
	FURNITURE_DRAFTING = 0, # Furniture drafting preview tiles
	FURNISHING = 1,         # Furniture placement tiles
	NO_PLACEMENT = 2,       # Invalid placement overlay
	
	# SpecialFurnitureTileMap layers
	SPECIAL_FURNITURE = 0    # Special furniture like pumps
}

# Tileset constants - organized by TileMap with descriptive names
enum BaseTileset {
	STATION_BACKGROUND = 0  # Base station background tiles
}

enum BuildTileset {
	SELECTION = 0,    # Blue tiles for valid room placements
	DRAFTING = 1,     # Blue tiles for room drafting preview
	INVALID = 2,      # Red tiles for invalid room placements
	DOOR = 4,         # Door tiles for door placement
	MOCK_ROOM = 3,    # Generic room tileset (for all room types)
	CREW_QUARTERS = 6,    # Room type tilesets (for future use)
	GENERATOR_ROOM = 7,
	STORAGE_BAY = 8
}

enum FurnitureTileset {
	MOCK_FURNITURE = 0,  # Generic furniture tiles
	INVALID = 1,         # Red tiles for invalid furniture placement
	BED = 2              # Bed furniture tiles
}

enum SpecialFurnitureTileset {
	PUMP = 0             # Pump tiles
}

# Signal removed - no longer needed with simplified tile management


func _ready() -> void:
	# Don't save state immediately - wait for tile maps to be ready
	# The state will be saved when first accessed
	pass

## Initialization and Status

func set_tile_maps(base_tile_map: TileMap, build_tile_map: TileMap, furniture_tile_map: TileMap, special_furniture_tile_map: TileMap) -> void:
	# Set both public and private references
	self.base_tile_map = base_tile_map
	self.build_tile_map = build_tile_map
	self.furniture_tile_map = furniture_tile_map
	self.special_furniture_tile_map = special_furniture_tile_map
	
	_base_tile_map = base_tile_map
	_build_tile_map = build_tile_map
	_furniture_tile_map = furniture_tile_map
	_special_furniture_tile_map = special_furniture_tile_map
	

## Base Tile Map Operations - simplified since base layer stays intact

## Building Tile Map Operations

func clear_building_layer() -> void:
	if not build_tile_map:
		return
	build_tile_map.clear_layer(Layer.BUILDING)

func clear_drafting_layer() -> void:
	if not build_tile_map:
		return
	build_tile_map.clear_layer(Layer.BUILD_DRAFTING)

func set_building_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not build_tile_map:
		return
	build_tile_map.set_cell(Layer.BUILDING, coords, tileset_id, atlas_coords)

func set_building_drafting_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not build_tile_map:
		return
	build_tile_map.set_cell(Layer.BUILD_DRAFTING, coords, tileset_id, atlas_coords)

func set_drafting_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not build_tile_map:
		return
	build_tile_map.set_cell(Layer.BUILD_DRAFTING, coords, tileset_id, atlas_coords)

func get_building_cell_data(coords: Vector2i) -> TileData:
	if not build_tile_map:
		return null
	return build_tile_map.get_cell_tile_data(Layer.BUILDING, coords)

func is_building_cell_occupied(coords: Vector2i) -> bool:
	return get_building_cell_data(coords) != null

## Furniture Tile Map Operations

func clear_furniture_layer() -> void:
	if not furniture_tile_map:
		return
	furniture_tile_map.clear_layer(Layer.FURNISHING)

func clear_furniture_drafting_layer() -> void:
	if not furniture_tile_map:
		return
	furniture_tile_map.clear_layer(Layer.FURNITURE_DRAFTING)

func clear_furniture_overlay_layer() -> void:
	if not furniture_tile_map:
		return
	furniture_tile_map.clear_layer(Layer.NO_PLACEMENT)

func set_furniture_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not furniture_tile_map:
		return
	furniture_tile_map.set_cell(Layer.FURNISHING, coords, tileset_id, atlas_coords)

func set_furniture_drafting_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not furniture_tile_map:
		return
	
	furniture_tile_map.set_cell(Layer.FURNITURE_DRAFTING, coords, tileset_id, atlas_coords)

func set_furniture_overlay_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not furniture_tile_map:
		return
	furniture_tile_map.set_cell(Layer.NO_PLACEMENT, coords, tileset_id, atlas_coords)

func get_furniture_cell_source_id(coords: Vector2i) -> int:
	if not furniture_tile_map:
		return -1
	return furniture_tile_map.get_cell_source_id(Layer.FURNISHING, coords)

func is_furniture_cell_occupied(coords: Vector2i) -> bool:
	if not furniture_tile_map:
		return false
	return furniture_tile_map.get_cell_source_id(Layer.FURNISHING, coords) != -1

## Special Furniture Tile Map Operations

func clear_special_furniture_layer() -> void:
	if not special_furniture_tile_map:
		return
	special_furniture_tile_map.clear_layer(Layer.SPECIAL_FURNITURE)

func set_special_furniture_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not special_furniture_tile_map:
		return
	special_furniture_tile_map.set_cell(Layer.SPECIAL_FURNITURE, coords, tileset_id, atlas_coords)

func get_special_furniture_cell_source_id(coords: Vector2i) -> int:
	if not special_furniture_tile_map:
		return -1
	return special_furniture_tile_map.get_cell_source_id(Layer.SPECIAL_FURNITURE, coords)

func is_special_furniture_cell_occupied(coords: Vector2i) -> bool:
	if not special_furniture_tile_map:
		return false
	return special_furniture_tile_map.get_cell_source_id(Layer.SPECIAL_FURNITURE, coords) != -1





## Base Tile Map Operations

func get_base_cell_tile_data(coords: Vector2i) -> TileData:
	if not base_tile_map:
		return null
	return base_tile_map.get_cell_tile_data(Layer.BASE, coords)

# erase_base_cell removed - base layer stays intact

func set_base_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not base_tile_map:
		return
	base_tile_map.set_cell(Layer.BASE, coords, tileset_id, atlas_coords)

## Utility Operations

func get_global_mouse_position() -> Vector2i:
	# Get mouse position in the base tile map coordinates (accounting for canvas transforms)
	if not base_tile_map:
		return Vector2i.ZERO
	return base_tile_map.local_to_map(base_tile_map.get_local_mouse_position())

func get_global_mouse_position_for_tilemap(tilemap: TileMap) -> Vector2i:
	# Get mouse position in any tile map coordinates (accounting for canvas transforms)
	if not tilemap:
		return Vector2i.ZERO
	return tilemap.local_to_map(tilemap.get_local_mouse_position())

func get_used_cells(layer: int) -> Array[Vector2i]:
	# Get all used cells in a specific layer
	if not base_tile_map:
		return []
	return base_tile_map.get_used_cells(layer)

## Batch Operations for Performance

func batch_set_cells(tilemap: TileMap, layer: int, cells: Array[Dictionary]) -> void:
	# cells should be array of {coords: Vector2i, tileset_id: int, atlas_coords: Vector2i}
	for cell_data in cells:
		tilemap.set_cell(layer, cell_data.coords, cell_data.tileset_id, cell_data.atlas_coords)

func batch_clear_rect(tilemap: TileMap, layer: int, top_left: Vector2i, bottom_right: Vector2i) -> void:
	# Clear all cells in a rectangular area
	var min_x = min(top_left.x, bottom_right.x)
	var max_x = max(top_left.x, bottom_right.x)
	var min_y = min(top_left.y, bottom_right.y)
	var max_y = max(top_left.y, bottom_right.y)
	
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			tilemap.erase_cell(layer, Vector2i(x, y))

## Layer Management

func set_layer_modulate(tilemap: TileMap, layer: int, modulate: Color) -> void:
	tilemap.set_layer_modulate(layer, modulate)

func get_layer_modulate(tilemap: TileMap, layer: int) -> Color:
	return tilemap.get_layer_modulate(layer)



## Performance Monitoring

func get_tile_count(layer: int) -> int:
	if not base_tile_map:
		return 0
	return base_tile_map.get_used_cells(layer).size()

func get_total_tile_count() -> int:
	if not base_tile_map:
		return 0
	var total = 0
	for layer in range(base_tile_map.get_layers_count()):
		total += get_tile_count(layer)
	return total



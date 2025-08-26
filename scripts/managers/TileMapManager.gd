extends Node


# Tile map references
@onready var base_tile_map: TileMap = %BaseTileMap
@onready var build_tile_map: TileMap = %BuildTileMap
@onready var furniture_tile_map: TileMap = %FurnitureTileMap

# Layer constants
enum Layer {
	BASE = 0,           # Base station tiles (background)
	BUILDING = 1,       # Room building tiles (on BuildTileMap)
	DRAFTING = 0,       # Room drafting preview tiles (on BuildTileMap)
	FURNISHING = 1,     # Furniture placement tiles (on FurnitureTileMap)
	NO_PLACEMENT = 2,   # Invalid placement overlay (on FurnitureTileMap)
	OVERLAY = 2         # General overlay tiles (on FurnitureTileMap)
}

# Tileset constants - centralized for consistency
enum TilesetID {
	SELECTION = 0,
	INVALID = 2,
	MOCK_ROOM = 3,
	DOOR = 4,
	OVERLAY = 1
}

# Signal for when tile maps are updated
signal tile_maps_updated

# Cached tile data for performance
var _base_tile_map_data: Dictionary = {}
var _base_tile_map_saved: bool = false

func _ready() -> void:
	# Don't save state immediately - wait for tile maps to be ready
	# The state will be saved when first accessed
	pass

## Initialization and Status

func is_ready() -> bool:
	return base_tile_map != null and build_tile_map != null and furniture_tile_map != null

func initialise_when_ready() -> void:
	# Call this when you know the tile maps are ready
	if is_ready() and not _base_tile_map_saved:
		save_base_tile_map_state()
		print("TileMapManager: Successfully initialised")
	else:
		print("TileMapManager: Cannot initialise - tile maps not ready or already initialised")

func wait_for_ready() -> void:
	# Call this to wait for the manager to be ready
	if is_ready():
		initialise_when_ready()
	else:
		# Wait for the next frame and try again
		# Note: This function should be called from an async context
		print("TileMapManager: Not ready yet, call again next frame")

func set_tile_maps(base: TileMap, build: TileMap, furniture: TileMap) -> void:
	# Set the tile map references when they become available
	base_tile_map = base
	build_tile_map = build
	furniture_tile_map = furniture
	print("TileMapManager: Tile maps set successfully")
	
	# Now we can try to initialize
	if not _base_tile_map_saved:
		initialise_when_ready()

## Base Tile Map Operations

func save_base_tile_map_state() -> void:
	if _base_tile_map_saved:
		return
		
	# Check if tile maps are ready
	if not base_tile_map or not build_tile_map or not furniture_tile_map:
		print("TileMapManager: Tile maps not ready yet, deferring state save")
		return
		
	_base_tile_map_data.clear()
	var used_rect = base_tile_map.get_used_rect()
	
	if used_rect.size == Vector2i.ZERO:
		_base_tile_map_saved = true
		return
	
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var coords = Vector2i(x, y)
			var cell_atlas_data = base_tile_map.get_cell_atlas_coords(Layer.BASE, coords)
			if cell_atlas_data != Vector2i(-1, -1):
				_base_tile_map_data[coords] = cell_atlas_data
	
	_base_tile_map_saved = true
	print("Saved base tile map state with %d tiles" % _base_tile_map_data.size())

func restore_base_tile_map_state() -> void:
	if not _base_tile_map_saved:
		return
		
	if not base_tile_map:
		print("TileMapManager: Base tile map not ready")
		return
		
	base_tile_map.clear()
	for coords in _base_tile_map_data.keys():
		var atlas_coords = _base_tile_map_data[coords]
		base_tile_map.set_cell(Layer.BASE, coords, 0, atlas_coords)

## Building Tile Map Operations

func clear_building_layer() -> void:
	if not build_tile_map:
		print("TileMapManager: Build tile map not ready")
		return
	build_tile_map.clear_layer(Layer.BUILDING)

func clear_drafting_layer() -> void:
	if not build_tile_map:
		print("TileMapManager: Build tile map not ready")
		return
	build_tile_map.clear_layer(Layer.DRAFTING)

func set_building_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not build_tile_map:
		print("TileMapManager: Build tile map not ready")
		return
	build_tile_map.set_cell(Layer.BUILDING, coords, tileset_id, atlas_coords)

func set_drafting_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not build_tile_map:
		print("TileMapManager: Build tile map not ready")
		return
	build_tile_map.set_cell(Layer.DRAFTING, coords, tileset_id, atlas_coords)

func get_building_cell_data(coords: Vector2i) -> TileData:
	if not build_tile_map:
		print("TileMapManager: Build tile map not ready")
		return null
	return build_tile_map.get_cell_tile_data(Layer.BUILDING, coords)

func is_building_cell_occupied(coords: Vector2i) -> bool:
	return get_building_cell_data(coords) != null

## Furniture Tile Map Operations

func clear_furniture_layer() -> void:
	if not furniture_tile_map:
		print("TileMapManager: Furniture tile map not ready")
		return
	furniture_tile_map.clear_layer(Layer.FURNISHING)

func clear_furniture_drafting_layer() -> void:
	if not furniture_tile_map:
		print("TileMapManager: Furniture tile map not ready")
		return
	furniture_tile_map.clear_layer(Layer.DRAFTING)

func clear_furniture_overlay_layer() -> void:
	if not furniture_tile_map:
		print("TileMapManager: Furniture tile map not ready")
		return
	furniture_tile_map.clear_layer(Layer.OVERLAY)

func set_furniture_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not furniture_tile_map:
		print("TileMapManager: Furniture tile map not ready")
		return
	furniture_tile_map.set_cell(Layer.FURNISHING, coords, tileset_id, atlas_coords)

func set_furniture_drafting_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not furniture_tile_map:
		print("TileMapManager: Furniture tile map not ready")
		return
	furniture_tile_map.set_cell(Layer.DRAFTING, coords, tileset_id, atlas_coords)

func set_furniture_overlay_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not furniture_tile_map:
		print("TileMapManager: Furniture tile map not ready")
		return
	furniture_tile_map.set_cell(Layer.OVERLAY, coords, tileset_id, atlas_coords)

func get_furniture_cell_source_id(coords: Vector2i) -> int:
	if not furniture_tile_map:
		print("TileMapManager: Furniture tile map not ready")
		return -1
	return furniture_tile_map.get_cell_source_id(Layer.FURNISHING, coords)

func is_furniture_cell_occupied(coords: Vector2i) -> bool:
	return get_furniture_cell_source_id(coords) != -1

## Base Tile Map Operations

func get_base_cell_tile_data(coords: Vector2i) -> TileData:
	if not base_tile_map:
		print("TileMapManager: Base tile map not ready")
		return null
	return base_tile_map.get_cell_tile_data(Layer.BASE, coords)

func erase_base_cell(coords: Vector2i) -> void:
	if not base_tile_map:
		print("TileMapManager: Base tile map not ready")
		return
	base_tile_map.erase_cell(Layer.BASE, coords)

func set_base_cell(coords: Vector2i, tileset_id: int, atlas_coords: Vector2i) -> void:
	if not base_tile_map:
		print("TileMapManager: Base tile map not ready")
		return
	base_tile_map.set_cell(Layer.BASE, coords, tileset_id, atlas_coords)

## Utility Operations

func get_global_mouse_position() -> Vector2i:
	# Get mouse position in the base tile map coordinates
	if not base_tile_map:
		print("TileMapManager: Base tile map not ready")
		return Vector2i.ZERO
	return base_tile_map.local_to_map(base_tile_map.get_global_mouse_position())

func get_global_mouse_position_for_tilemap(tilemap: TileMap) -> Vector2i:
	# Get mouse position in any tile map coordinates
	if not tilemap:
		print("TileMapManager: Tile map parameter is null")
		return Vector2i.ZERO
	return tilemap.local_to_map(tilemap.get_global_mouse_position())

func get_used_cells(layer: int) -> Array[Vector2i]:
	# Get all used cells in a specific layer
	if not base_tile_map:
		print("TileMapManager: Base tile map not ready")
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
		print("TileMapManager: Base tile map not ready")
		return 0
	return base_tile_map.get_used_cells(layer).size()

func get_total_tile_count() -> int:
	if not base_tile_map:
		print("TileMapManager: Base tile map not ready")
		return 0
	var total = 0
	for layer in range(base_tile_map.get_layers_count()):
		total += get_tile_count(layer)
	return total

extends Node

# Tile map references - will be set via set_tile_maps
var base_tile_map: TileMap
var build_tile_map: TileMap
var furniture_tile_map: TileMap

# Private tile map references for internal functions
var _base_tile_map: TileMap
var _build_tile_map: TileMap
var _furniture_tile_map: TileMap

# Layer constants
enum Layer {
	BASE = 0,           # Base station tiles (background)
	BUILDING = 1,       # Room building tiles (on BuildTileMap)
	DRAFTING = 0,       # Room drafting preview tiles (on BuildTileMap) - WARNING: Same as BASE!
	FURNISHING = 1,     # Furniture placement tiles (on FurnitureTileMap)
	NO_PLACEMENT = 2,   # Invalid placement overlay (on FurnitureTileMap)
	OVERLAY = 2         # General overlay tiles (on FurnitureTileMap)
}

# Tileset constants
enum TilesetID {
	SELECTION = 0,
	INVALID = 1,      # Invalid tileset is at source index 1 in the scene
	BED = 2,          # Bed tileset is at source index 2 in the scene
	MOCK_ROOM = 3,
	DOOR = 4
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
	print("TileMapManager: Initialising when ready...")
	print("TileMapManager: Base tile map ready: ", base_tile_map != null)
	print("TileMapManager: Build tile map ready: ", build_tile_map != null)
	print("TileMapManager: Furniture tile map ready: ", furniture_tile_map != null)
	
	if furniture_tile_map and furniture_tile_map.tile_set:
		print("TileMapManager: Furniture tile map has tileset with ", furniture_tile_map.tile_set.get_source_count(), " sources")
		for i in range(furniture_tile_map.tile_set.get_source_count()):
			var source = furniture_tile_map.tile_set.get_source(i)
			if source and source is TileSetAtlasSource:
				var atlas_source = source as TileSetAtlasSource
				print("TileMapManager: Source ", i, " has texture: ", atlas_source.texture != null)
				if atlas_source.texture:
					print("TileMapManager: Source ", i, " texture size: ", atlas_source.texture.get_size())
	
	# Set up the bed tileset properly
	setup_bed_tileset_properly()
	
	# Verify the bed tileset is working
	verify_bed_tileset()
	
	print("TileMapManager: Initialisation complete")

func wait_for_ready() -> void:
	# Call this to wait for the manager to be ready
	if is_ready():
		initialise_when_ready()
	else:
		# Wait for the next frame and try again
		# Note: This function should be called from an async context
		print("TileMapManager: Not ready yet, call again next frame")

func set_tile_maps(base_tile_map: TileMap, build_tile_map: TileMap, furniture_tile_map: TileMap) -> void:
	# Set both public and private references
	self.base_tile_map = base_tile_map
	self.build_tile_map = build_tile_map
	self.furniture_tile_map = furniture_tile_map
	
	_base_tile_map = base_tile_map
	_build_tile_map = build_tile_map
	_furniture_tile_map = furniture_tile_map
	
	print("TileMapManager: Tile maps set successfully")
	
	# Initialise when ready
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
	print("Saved base tile map state with ", _base_tile_map_data.size(), " tiles")

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
	
	print("TileMapManager: Setting furniture drafting cell at ", coords, " with tileset_id ", tileset_id, " and atlas_coords ", atlas_coords)
	print("TileMapManager: Furniture tile map has tileset: ", furniture_tile_map.tile_set != null)
	if furniture_tile_map.tile_set:
		print("TileMapManager: Tileset has ", furniture_tile_map.tile_set.get_source_count(), " sources")
		print("TileMapManager: Requested tileset_id ", tileset_id, " available: ", furniture_tile_map.tile_set.has_source(tileset_id))
	
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
	if not furniture_tile_map:
		return false
	return furniture_tile_map.get_cell_source_id(Layer.FURNISHING, coords) != -1

## Tileset Setup Functions

func setup_bed_tileset() -> void:
	"""Set up the bed tileset programmatically"""
	if not furniture_tile_map:
		print("TileMapManager: Furniture tile map not ready for tileset setup")
		return
	
	# Get or create the current tileset
	var current_tileset = furniture_tile_map.tile_set
	if not current_tileset:
		current_tileset = TileSet.new()
		furniture_tile_map.tile_set = current_tileset
	
	# Create a new TileSetAtlasSource for the bed tileset
	var atlas_source = TileSetAtlasSource.new()
	
	# Load the bed tileset texture
	var bed_texture = load("res://assets/tilesets/bed_tileset.png")
	if not bed_texture:
		print("TileMapManager: Failed to load bed tileset texture")
		return
	
	# Set the texture for the atlas source
	atlas_source.texture = bed_texture
	
	# Detect tile size from the texture (assuming 1x4 horizontal layout)
	var texture_size = bed_texture.get_size()
	var tile_width = texture_size.x / 4  # 4 tiles horizontally
	var tile_height = texture_size.y     # 1 tile vertically
	
	atlas_source.texture_region_size = Vector2i(tile_width, tile_height)
	
	# Add the atlas source to the tileset
	current_tileset.add_source(atlas_source, TilesetID.BED)
	
	print("TileMapManager: Bed tileset set up successfully with tile size: %s" % Vector2i(tile_width, tile_height))

func setup_furniture_tileset(tileset_id: int, texture_path: String, tile_size: Vector2i = Vector2i.ZERO) -> bool:
	"""Generic function to set up any furniture tileset programmatically"""
	if not furniture_tile_map:
		print("TileMapManager: Furniture tile map not ready for tileset setup")
		return false
	
	print("TileMapManager: Setting up tileset %d with texture: %s" % [tileset_id, texture_path])
	
	# Get or create the current tileset
	var current_tileset = furniture_tile_map.tile_set
	if not current_tileset:
		current_tileset = TileSet.new()
		furniture_tile_map.tile_set = current_tileset
		print("TileMapManager: Created new tileset")
	else:
		print("TileMapManager: Using existing tileset")
	
	# Create a new TileSetAtlasSource
	var atlas_source = TileSetAtlasSource.new()
	
	# Load the texture
	var texture = load(texture_path)
	if not texture:
		print("TileMapManager: Failed to load texture: %s" % texture_path)
		return false
	
	print("TileMapManager: Successfully loaded texture: %s" % texture_path)
	
	# Set the texture for the atlas source
	atlas_source.texture = texture
	
	# Use provided tile size or detect from texture
	if tile_size == Vector2i.ZERO:
		atlas_source.texture_region_size = texture.get_size()
		print("TileMapManager: Using full texture size: %s" % texture.get_size())
	else:
		atlas_source.texture_region_size = tile_size
		print("TileMapManager: Using provided tile size: %s" % tile_size)
	
	# Add the atlas source to the tileset
	current_tileset.add_source(atlas_source, tileset_id)
	
	print("TileMapManager: Tileset %d set up successfully" % tileset_id)
	return true

func get_tileset_tile_size(tileset_id: int) -> Vector2i:
	"""Get the tile size for a specific tileset"""
	if not furniture_tile_map or not furniture_tile_map.tile_set:
		return Vector2i.ZERO
	
	var tileset = furniture_tile_map.tile_set
	var source = tileset.get_source(tileset_id)
	if source and source is TileSetAtlasSource:
		return source.texture_region_size
	
	return Vector2i.ZERO

func is_tileset_ready(tileset_id: int) -> bool:
	"""Check if a specific tileset is ready and available"""
	if not furniture_tile_map or not furniture_tile_map.tile_set:
		return false
	
	var tileset = furniture_tile_map.tile_set
	return tileset.has_source(tileset_id)

func get_bed_tileset_info() -> Dictionary:
	"""Get information about the bed tileset for debugging"""
	var info = {
		"is_ready": false,
		"tile_size": Vector2i.ZERO,
		"texture_path": "res://assets/tilesets/bed_tileset.png"
	}
	
	if is_tileset_ready(TilesetID.BED):
		info.is_ready = true
		info.tile_size = get_tileset_tile_size(TilesetID.BED)
	
	return info

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

func setup_bed_tileset_properly() -> void:
	print("TileMapManager: Setting up bed tileset properly...")
	
	if not furniture_tile_map or not furniture_tile_map.tile_set:
		print("TileMapManager: Furniture tile map or tile set not ready, skipping bed tileset setup")
		return
	
	var tileset = furniture_tile_map.tile_set
	print("TileMapManager: Current tileset has ", tileset.get_source_count(), " sources")
	
	# Since the scene file already has the bed tileset properly configured,
	# we don't need to reconfigure it. Just verify it's working.
	print("TileMapManager: Bed tileset should already be configured in scene file")
	
	# Check if we have the bed tileset source
	if tileset.get_source_count() > TilesetID.BED:
		var existing_source = tileset.get_source(TilesetID.BED)
		if existing_source and existing_source is TileSetAtlasSource:
			var atlas_source = existing_source as TileSetAtlasSource
			if atlas_source.texture:
				print("TileMapManager: Bed tileset source found with texture size: ", atlas_source.texture.get_size())
			else:
				print("TileMapManager: Bed tileset source found but has no texture")
		else:
			print("TileMapManager: Bed tileset source not found or wrong type")
	else:
		print("TileMapManager: Not enough sources in tileset for bed tileset")

func verify_bed_tileset() -> bool:
	"""Verify that the bed tileset is working correctly"""
	if not furniture_tile_map or not furniture_tile_map.tile_set:
		print("TileMapManager: Cannot verify bed tileset - furniture tile map not ready")
		return false
	
	var tileset = furniture_tile_map.tile_set
	if not tileset.has_source(TilesetID.BED):
		print("TileMapManager: Bed tileset source not found")
		return false
	
	var source = tileset.get_source(TilesetID.BED)
	if not source or not source is TileSetAtlasSource:
		print("TileMapManager: Bed tileset source is not a TileSetAtlasSource")
		return false
	
	var atlas_source = source as TileSetAtlasSource
	if not atlas_source.texture:
		print("TileMapManager: Bed tileset source has no texture")
		return false
	
	print("TileMapManager: Bed tileset verification successful")
	print("TileMapManager: Texture size: ", atlas_source.texture.get_size())
	print("TileMapManager: Tile region size: ", atlas_source.texture_region_size)
	return true

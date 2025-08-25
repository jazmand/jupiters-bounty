extends Node

## Centralized resource management for the game
## Eliminates duplicate resource loading code across managers

signal resources_loaded

# Resource collections
var room_types: Array[RoomType] = []
var furniture_types: Array[FurnitureType] = []

# Resource paths
const ROOM_TYPES_PATH = "res://assets/room_type/"
const FURNITURE_TYPES_PATH = "res://assets/furniture_type/"

# Resource loading status
var _room_types_loaded: bool = false
var _furniture_types_loaded: bool = false

func _ready() -> void:
	# Load all resources on startup
	load_all_resources()

func load_all_resources() -> void:
	load_room_types()
	load_furniture_types()
	
	# Emit signal when all resources are loaded
	if _room_types_loaded and _furniture_types_loaded:
		resources_loaded.emit()

func load_room_types() -> void:
	if _room_types_loaded:
		return
		
	room_types.clear()
	var room_type_files = DirAccess.open(ROOM_TYPES_PATH)
	
	if not room_type_files:
		push_error("Failed to open room types directory: " + ROOM_TYPES_PATH)
		return
	
	# Iterate over each file in the folder
	room_type_files.list_dir_begin()
	var file_name = room_type_files.get_next()
	
	while file_name != "":
		var file_path = ROOM_TYPES_PATH + file_name
		
		# Check if the file is a .tres resource
		if file_name.ends_with(".tres"):
			var room_type_resource = load(file_path)
			
			if room_type_resource:
				# Create an instance of the RoomType class
				var room_type_instance = RoomType.new()
				
				# Assign the property values to the instance
				room_type_instance.id = room_type_resource.id
				room_type_instance.name = room_type_resource.name
				room_type_instance.price = room_type_resource.price
				room_type_instance.power_consumption = room_type_resource.power_consumption
				room_type_instance.capacity = room_type_resource.capacity
				room_type_instance.min_tiles = room_type_resource.min_tiles
				room_type_instance.max_tiles = room_type_resource.max_tiles
				room_type_instance.tileset_id = room_type_resource.tileset_id
				
				# Add the room type instance to the list
				room_types.append(room_type_instance)
			else:
				push_warning("Failed to load room type resource: " + file_path)
		
		file_name = room_type_files.get_next()
	
	room_type_files.list_dir_end()
	_room_types_loaded = true
	print("Loaded %d room types" % room_types.size())

func load_furniture_types() -> void:
	if _furniture_types_loaded:
		return
		
	furniture_types.clear()
	var furniture_type_files = DirAccess.open(FURNITURE_TYPES_PATH)
	
	if not furniture_type_files:
		push_error("Failed to open furniture types directory: " + FURNITURE_TYPES_PATH)
		return
	
	# Iterate over each file in the folder
	furniture_type_files.list_dir_begin()
	var file_name = furniture_type_files.get_next()
	
	while file_name != "":
		var file_path = FURNITURE_TYPES_PATH + file_name
		
		# Check if the file is a .tres resource
		if file_name.ends_with(".tres"):
			var furniture_type_resource = load(file_path)
			
			if furniture_type_resource:
				# Create an instance of the FurnitureType class
				var furniture_type_instance = FurnitureType.new()
				
				# Assign the property values to the instance
				furniture_type_instance.id = furniture_type_resource.id
				furniture_type_instance.name = furniture_type_resource.name
				furniture_type_instance.price = furniture_type_resource.price
				furniture_type_instance.power_consumption = furniture_type_resource.power_consumption
				furniture_type_instance.simultaneous_users = furniture_type_resource.simultaneous_users
				furniture_type_instance.height = furniture_type_resource.height
				furniture_type_instance.width = furniture_type_resource.width
				furniture_type_instance.tileset_id = furniture_type_resource.tileset_id
				furniture_type_instance.tileset_coords = furniture_type_resource.tileset_coords
				furniture_type_instance.valid_room_types = furniture_type_resource.valid_room_types
				
				# Add the furniture type instance to the list
				furniture_types.append(furniture_type_instance)
			else:
				push_warning("Failed to load furniture type resource: " + file_path)
		
		file_name = furniture_type_files.get_next()
	
	furniture_type_files.list_dir_end()
	_furniture_types_loaded = true
	print("Loaded %d furniture types" % furniture_types.size())

## Utility methods for other managers

func get_room_type_by_id(id: int) -> RoomType:
	for room_type in room_types:
		if room_type.id == id:
			return room_type
	return null

func get_furniture_type_by_id(id: int) -> FurnitureType:
	for furniture_type in furniture_types:
		if furniture_type.id == id:
			return furniture_type
	return null

func get_valid_furniture_for_room(room_type: RoomType) -> Array[FurnitureType]:
	var valid_furniture: Array[FurnitureType] = []
	for furniture in furniture_types:
		if room_type.id in furniture.valid_room_types:
			valid_furniture.append(furniture)
	return valid_furniture

## Resource validation

func validate_resources() -> bool:
	var valid = true
	
	# Validate room types
	for room_type in room_types:
		if room_type.price < 0:
			push_error("Room type '%s' has negative price: %d" % [room_type.name, room_type.price])
			valid = false
		if room_type.min_tiles <= 0:
			push_error("Room type '%s' has invalid min_tiles: %d" % [room_type.name, room_type.min_tiles])
			valid = false
		if room_type.max_tiles < room_type.min_tiles:
			push_error("Room type '%s' has max_tiles < min_tiles: %d < %d" % [room_type.name, room_type.max_tiles, room_type.min_tiles])
			valid = false
	
	# Validate furniture types
	for furniture_type in furniture_types:
		if furniture_type.price < 0:
			push_error("Furniture type '%s' has negative price: %d" % [furniture_type.name, furniture_type.price])
			valid = false
		if furniture_type.width <= 0 or furniture_type.height <= 0:
			push_error("Furniture type '%s' has invalid dimensions: %dx%d" % [furniture_type.name, furniture_type.width, furniture_type.height])
			valid = false
	
	return valid

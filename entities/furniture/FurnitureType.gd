class_name FurnitureType extends Resource

@export var id: int
@export var name: String
@export var price: int
@export var power_consumption: int
@export var simultaneous_users: int
@export var tileset_id: int
@export var tileset_coords: Array[Vector2i]
@export var tileset_coords_rotated: Array[Vector2i]  # Rotated version of the furniture
@export var height: int
@export var width: int
@export var valid_room_types: Array
@export var supports_rotation: bool = false  # Whether this furniture can be rotated

# Collision Properties
@export var collision_width: int = 1  # Number of tiles wide for collision
@export var collision_height: int = 1  # Number of tiles tall for collision

# Sprite Positioning
@export var sprite_offset: Vector2 = Vector2.ZERO  # X/Y offset for sprite positioning
@export var sprite_offset_rotated: Vector2 = Vector2.ZERO  # Offset when rotated (for asymmetric furniture)

func _init(
	p_id: int = 0,
	p_name: String = "",
	p_price: int = 0,
	p_power_consumption: int = 0,
	p_simultaneous_users: int = 1,
	p_tileset_id: int = 0,
	p_tileset_coords = [] as Array[Vector2i],
	p_tileset_coords_rotated = [] as Array[Vector2i],
	p_height: int = 1,
	p_width: int = 1,
	p_valid_room_types = [],
	p_supports_rotation: bool = false,
	p_collision_width: int = 1,
	p_collision_height: int = 1,
	p_sprite_offset: Vector2 = Vector2.ZERO,
	p_sprite_offset_rotated: Vector2 = Vector2.ZERO
):
	id = p_id
	name = p_name
	price = p_price
	power_consumption = p_power_consumption
	simultaneous_users = p_simultaneous_users
	height = p_height
	width = p_width
	tileset_id = p_tileset_id
	tileset_coords = p_tileset_coords
	tileset_coords_rotated = p_tileset_coords_rotated
	valid_room_types = p_valid_room_types
	supports_rotation = p_supports_rotation
	collision_width = p_collision_width
	collision_height = p_collision_height
	sprite_offset = p_sprite_offset
	sprite_offset_rotated = p_sprite_offset_rotated

func get_tileset_coords_for_rotation(is_rotated: bool) -> Array[Vector2i]:
	# Return the appropriate tileset coordinates based on rotation state
	if supports_rotation and is_rotated and tileset_coords_rotated.size() > 0:
		return tileset_coords_rotated
	else:
		return tileset_coords 

func get_collision_dimensions() -> Vector2i:
	# Return collision dimensions, falling back to width/height if not set
	if collision_width > 0 and collision_height > 0:
		return Vector2i(collision_width, collision_height)
	else:
		return Vector2i(width, height)

func get_collision_dimensions_for_rotation(is_rotated: bool) -> Vector2i:
	# Return collision dimensions adjusted for rotation when applicable
	var dims = get_collision_dimensions()
	if supports_rotation and is_rotated:
		# Swap width/height when rotated 90 degrees
		return Vector2i(dims.y, dims.x)
	return dims

func get_sprite_offset_for_rotation(is_rotated: bool) -> Vector2:
	# Return the appropriate sprite offset based on rotation state
	if supports_rotation and is_rotated and sprite_offset_rotated != Vector2.ZERO:
		return sprite_offset_rotated
	else:
		return sprite_offset
	

# Main.gd

extends Node2D

var base_tile_map: TileMap
var build_tile_map: TileMap

var build_menu: Control

var room_builder: RoomBuilder
var room_types: Array


func _init():
	# Load and initialize room types
	loadRoomTypes()

func _ready():
	# Find the TileMap nodes
	base_tile_map = $BaseTileMap
	build_tile_map = $BaseTileMap/BuildTileMap
	
	# Find UI elements // TODO: Tie is_editing to open/close status of build menu
	build_menu = $CanvasLayer/GUI/Build 
	
	# Create an instance of the RoomBuilder class and pass the TileMap references
	room_builder = RoomBuilder.new(base_tile_map, build_tile_map)
	
#	# Connect input events to the appropriate functions // Necessary?
#	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func loadRoomTypes() -> void:
	
	var room_types_folder = "res://assets/room_type/"
	var room_type_files = DirAccess.open(room_types_folder)
	
	# Open the room types folder
	if room_type_files:
		# Iterate over each file in the folder
		room_type_files.list_dir_begin()
		var file_name = room_type_files.get_next()
		while file_name != "":
			var file_path = room_types_folder + file_name
			
			# Check if the file is a .tres resource
			if file_name.ends_with(".tres"):
				# Load the room type resource
				var room_type_resource = load(file_path)
				
				# Create an instance of the RoomType class
				var room_type_instance = RoomType.new()
				
				# Assign the property values to the instance
				room_type_instance.id = room_type_resource.id
				room_type_instance.name = room_type_resource.name
				room_type_instance.price = room_type_resource.price
				room_type_instance.powerConsumption = room_type_resource.powerConsumption
				room_type_instance.capacity = room_type_resource.capacity
				room_type_instance.minTiles = room_type_resource.minTiles
				room_type_instance.maxTiles = room_type_resource.maxTiles
				room_type_instance.tileset = room_type_resource.tileset
				
				# Add the room type instance to the list
				room_types.append(room_type_instance)
				
			file_name = room_type_files.get_next()
				
		room_type_files.list_dir_end()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and $CanvasLayer/GUI/Build.build_mode == true:
		# Start room building on left mouse button press
		if !room_builder.is_editing and event.pressed and event.button_index == 1:
			room_builder.start_editing()
			var initial_corner = base_tile_map.local_to_map(event.position)
			room_builder.initial_tile_coords = initial_corner

		# Set room on left mouse button release
		elif room_builder.is_editing and event.pressed and event.button_index == 1:
			room_builder.set_room()
			room_builder.blueprint.clear()
			room_builder.stop_editing()

		# Cancel room building on right mouse button press
		elif room_builder.is_editing and event.pressed and event.button_index == 2:
			build_tile_map.clear_layer(room_builder.drafting_layer)
			room_builder.blueprint.clear()
			room_builder.stop_editing()

	elif event is InputEventMouseMotion and $CanvasLayer/GUI/Build.build_mode == true:
		if room_builder.is_editing:
			room_builder.transverse_tile_coords = base_tile_map.local_to_map(event.position)
			room_builder.draft_room(room_builder.initial_tile_coords, room_builder.transverse_tile_coords)
		elif !room_builder.is_editing:
			room_builder.select_tile(base_tile_map.local_to_map(event.position))
			
	elif $CanvasLayer/GUI/Build.build_mode == false:
		room_builder.clear_all()
			


# Main.gd

extends Node2D

var base_tile_map: TileMap
var build_tile_map: TileMap

var build_menu: Control

var room_builder: RoomBuilder
var room_types: Array
var rooms: Array # TODO: Save & load on init

var elapsed_time: int # TODO: Save & load on init
var in_game_time: int
var one_in_game_day: int
var delta_time: float

func _init():
	# Load and initialize room types
	load_room_types()

func _ready():
	# Find the TileMap nodes
	base_tile_map = $BaseTileMap
	build_tile_map = $BaseTileMap/BuildTileMap
	
	# Find UI elements // TODO: Tie is_editing to open/close status of build menu
	build_menu = $CanvasLayer/GUI/Build 
	
	# Create an instance of the RoomBuilder class and pass the TileMap references & rooms array
	room_builder = RoomBuilder.new(base_tile_map, build_tile_map, rooms, room_types)
	
	delta_time = 0
	one_in_game_day = 36000 # 10 in game hours per in game day
	in_game_time = 7200 # Start at 02:00
		
	update_in_game_time()
	rotate_jupiter()
	
#	# Connect input events to the appropriate functions // Necessary?
#	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _process(delta):
	delta_time += delta
	
	# Update every 0.25 real-world seconds
	if delta_time >= 0.25:
		delta_time = 0
		update_in_game_time()
		update_clock()
		rotate_jupiter()

func load_room_types() -> void:
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
				room_type_instance.tilesetId = room_type_resource.tilesetId
				# Add the room type instance to the list
				room_types.append(room_type_instance)
				
			file_name = room_type_files.get_next()
				
		room_type_files.list_dir_end()
		

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and build_menu.build_mode == true:
		# Start room building on left mouse button press
		if !room_builder.is_editing and event.pressed and event.button_index == 1:
			if !room_builder.any_invalid:
				room_builder.selected_room_type_id = build_menu.selected_room_type_id
				room_builder.initial_tile_coords = base_tile_map.local_to_map(event.position)
				room_builder.start_editing()

		# Set room on left mouse button release 
		elif room_builder.is_editing and event.pressed and event.button_index == 1:
			if !room_builder.any_invalid:
				room_builder.set_room()
				room_builder.stop_editing()

		# Cancel room building on right mouse button press
		elif room_builder.is_editing and event.pressed and event.button_index == 2:
			build_tile_map.clear_layer(room_builder.drafting_layer)
			room_builder.stop_editing()

	elif event is InputEventMouseMotion and build_menu.build_mode == true:
		if room_builder.is_editing:
			room_builder.transverse_tile_coords = base_tile_map.local_to_map(event.position)
			room_builder.draft_room(room_builder.initial_tile_coords, room_builder.transverse_tile_coords)
		elif !room_builder.is_editing:
			room_builder.select_tile(base_tile_map.local_to_map(event.position))
			
	elif build_menu.build_mode == false:
		room_builder.clear_all()
			

func update_in_game_time():
	in_game_time += 5 # Add 5 in game seconds every 0.25 real world seconds
		
	if in_game_time >= one_in_game_day:  # 10 hours * 3600 seconds/hour
		in_game_time = 5 # Reset

func update_clock() -> void:
	var hours = int(in_game_time / 3600)
	var minutes = int((in_game_time % 3600) / 60)
	$CanvasLayer/GUI/TimeBar/Time.text = str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2)

func rotate_jupiter() -> void:
	var degree_rotation = (float(in_game_time) / float(one_in_game_day)) * 360.0
	print(degree_rotation, 'deg')
	$ColorRect/Jupiter.rotation_degrees = degree_rotation

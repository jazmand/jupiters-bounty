# Main.gd

extends Node2D

var station: Station = preload("res://assets/station/station_resources.tres")

var base_tile_map: TileMap
var build_tile_map: TileMap

@onready var state: StateChart = $StateManager

var build_menu: Control
var gui: Control
var background: Control
var camera: Camera2D

var room_builder: RoomBuilder
var room_selector: RoomSelector
var room_types: Array = []
var rooms: Array # TODO: Save & load on init

var elapsed_time: int # TODO: Save & load on init
var in_game_time: int
var one_in_game_day: int
var delta_time: float

var room_cost_total: int

func _init():
	# Load and initialize room types
	load_room_types()

func _ready():
	# Find the TileMap nodes
	base_tile_map = $BaseTileMap
	build_tile_map = $BaseTileMap/BuildTileMap
	
	# Find UI elements
	build_menu = $CanvasLayer/GUI/BuildMenu
	build_menu.action_pressed.connect(on_build_menu_action)
	gui = $CanvasLayer/GUI
	background = $Background
	camera = $Camera2D
	
	# Create an instance of the RoomBuilder class and pass the TileMap references & rooms array
	room_builder = RoomBuilder.new(gui, build_menu, station, base_tile_map, build_tile_map, rooms, room_types)
	room_builder.action_pressed.connect(on_room_builder_action)
	room_selector = RoomSelector.new(gui, station, build_tile_map, rooms, room_types)
	
	delta_time = 0
	one_in_game_day = 36000 # 10 in game hours per in game day
	in_game_time = 7200 # Start at 02:00
		
	update_in_game_time()
	background.rotate_jupiter(in_game_time, one_in_game_day)
	
#	# Connect input events to the appropriate functions // Necessary?
#	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _process(delta):
	delta_time += delta
	
	# Update every 0.25 real-world seconds
	if delta_time >= 0.25:
		delta_time = 0
		update_in_game_time()
		gui.update_clock(in_game_time)
		background.rotate_jupiter(in_game_time, one_in_game_day)

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

# --- Input functions ---

func _input(event: InputEvent) -> void:
	# temporary
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			$StateManager.send_event("stop_building")

func update_in_game_time():
	in_game_time += 5 # Add 5 in game seconds every 0.25 real world seconds
		
	if in_game_time >= one_in_game_day:  # 10 hours * 3600 seconds/hour
		in_game_time = 5 # Reset

# TODO: refactor action handlers
func on_build_menu_action(action: int) -> void:
	var event: String
	match action:
		build_menu.Action.STOP_BUILDING:
			event = "stop_building"
		build_menu.Action.START_BUILDING:
			event = "start_building"
		build_menu.Action.SELECT_ROOM:
			event = "building_forward"
	$StateManager.send_event(event)

func on_room_builder_action(state: int) -> void:
	var event: String
	match state:
		room_builder.Action.BACK:
			event = "building_back"
		room_builder.Action.FORWARD:
			event = "building_forward"
		room_builder.Action.COMPLETE:
			event = "stop_building"
	$StateManager.send_event(event)

func _on_selecting_room_state_entered() -> void:
	$CanvasLayer/GUI/BuildMenu/RoomPanel.visible = true

func _on_selecting_room_state_exited() -> void:
	$CanvasLayer/GUI/BuildMenu/RoomPanel.visible = false
	
func _on_selecting_tile_state_entered() -> void:
	build_menu.build_mode = true

# TODO: refactor state input handlers
func _on_selecting_tile_state_input(event: InputEvent):
	var offset = camera.position
	var zoom = camera.zoom
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				1: 
					room_selector.handle_select_input(event, offset, zoom)
					room_builder.selecting_tile(event, offset, zoom, build_menu.selected_room_type_id)
				2: pass
	elif event is InputEventMouseMotion:
		room_builder.selecting_tile_motion(event, offset, zoom)
	
func _on_drafting_room_state_input(event: InputEvent) -> void:
	var offset = camera.position
	var zoom = camera.zoom
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				1: room_builder.drafting_room()
				2: room_builder.stop_editing()
	elif event is InputEventMouseMotion:
		room_builder.drafting_room_motion(event, offset, zoom)

func _on_setting_door_state_input(event) -> void:
	var offset = camera.position
	var zoom = camera.zoom
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				1: room_builder.setting_door(event, offset, zoom)
				2: pass
	elif event is InputEventMouseMotion:
		room_builder.setting_door_motion(event, offset, zoom)

func _on_confirming_room_state_entered() -> void:
	$CanvasLayer/GUI/BuildMenu/PopupPanel.visible = true
	$CanvasLayer/GUI/BuildMenu/PopupPanel/Label.text = room_builder.popup_message
	# Connect the buttons to the confirmation functions in the GUI script
	$CanvasLayer/GUI/BuildMenu/PopupPanel/YesButton.pressed.connect(room_builder.confirm_build)
	$CanvasLayer/GUI/BuildMenu/PopupPanel/NoButton.pressed.connect(room_builder.cancel_build)

func _on_confirming_room_state_exited() -> void:
	$CanvasLayer/GUI/BuildMenu/PopupPanel.visible = false

func _on_building_state_entered() -> void:
	$CanvasLayer/GUI/BuildMenu/BuildButton.visible = false

func _on_building_state_exited() -> void:
	$CanvasLayer/GUI/BuildMenu/BuildButton.visible = true
	room_builder.stop_editing()

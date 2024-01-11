# BuildingManager.gd

class_name BuildingManager
extends Node

var station: Station = preload("res://assets/station/station_resources.tres")

@onready var base_tile_map: TileMap = $"../BaseTileMap"
@onready var build_tile_map: TileMap = $"../BaseTileMap/BuildTileMap"

@onready var gui: GUI = $"../CanvasLayer/GUI"
@onready var build_menu: BuildMenu = $"../CanvasLayer/GUI/BuildMenu"
@onready var camera: Camera2D = $"../Camera2D"

@onready var state_manager: StateChart = $"../StateManager"

var room_builder: RoomBuilder
var room_selector: RoomSelector
var room_types: Array[RoomType] = []
var rooms: Array[Room] = [] # TODO: Save & load on init
	
enum StateEvent {BUILDING_STOP, BUILDING_START, BUILDING_BACK, BUILDING_FORWARD}

const Events = [&"building_stop", &"building_start", &"building_back", &"building_forward"]

func _init() -> void:
	# Load and initialize room types
	load_room_types()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	build_menu.action_completed.connect(on_build_menu_action)
	room_builder = RoomBuilder.new(gui, station, base_tile_map, build_tile_map, rooms, room_types)
	room_builder.action_completed.connect(on_room_builder_action)
	room_selector = RoomSelector.new(gui, station, build_tile_map, rooms, room_types)	

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

# TODO: refactor action handlers
func on_build_menu_action(action: int) -> void:
	var event: String
	match action:
		build_menu.Action.CLOSE:
			event = Events[StateEvent.BUILDING_STOP]
		build_menu.Action.OPEN:
			event = Events[StateEvent.BUILDING_START]
		build_menu.Action.SELECT_ROOM:
			event = Events[StateEvent.BUILDING_FORWARD]
	state_manager.send_event(event)

func on_room_builder_action(action: int) -> void:
	var event: String
	match action:
		room_builder.Action.BACK:
			event = Events[StateEvent.BUILDING_BACK]
		room_builder.Action.FORWARD:
			event = Events[StateEvent.BUILDING_FORWARD]
		room_builder.Action.COMPLETE:
			event = Events[StateEvent.BUILDING_STOP]
	state_manager.send_event(event)

func _on_building_state_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			state_manager.send_event(Events[StateEvent.BUILDING_STOP])

func _on_selecting_room_state_entered() -> void:
	build_menu.show_room_panel()

func _on_selecting_room_state_exited() -> void:
	build_menu.hide_room_panel()

# TODO: refactor state input handlers
func _on_selecting_tile_state_input(event: InputEvent) -> void:
	var offset = camera.position
	var zoom = camera.zoom
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				1:
					room_selector.handle_select_input(event, offset, zoom)
					room_builder.selecting_tile(event, offset, zoom, build_menu.selected_room_type_id)
				2: 
					pass
	elif event is InputEventMouseMotion:
		room_builder.selecting_tile_motion(event, offset, zoom)

func _on_drafting_room_state_input(event: InputEvent) -> void:
	var offset = camera.position
	var zoom = camera.zoom
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				1: 
					room_builder.drafting_room()
				2: 
					room_builder.stop_editing()
	elif event is InputEventMouseMotion:
		room_builder.drafting_room_motion(event, offset, zoom)

func _on_setting_door_state_input(event: InputEvent) -> void:
	var offset = camera.position
	var zoom = camera.zoom
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				1: 
					room_builder.setting_door(event, offset, zoom)
				2: 
					pass
	elif event is InputEventMouseMotion:
		room_builder.setting_door_motion(event, offset, zoom)

func _on_confirming_room_state_entered() -> void:
	build_menu.show_popup()
	build_menu.set_popup_text(room_builder.popup_message)
	# Connect the buttons to the confirmation functions in the GUI script
	build_menu.connect_popup_yes(room_builder.confirm_build)
	build_menu.connect_popup_no(room_builder.cancel_build)

func _on_confirming_room_state_exited() -> void:
	build_menu.hide_popup()

func _on_building_state_entered() -> void:
	build_menu.hide_build_button()

func _on_building_state_exited() -> void:
	build_menu.show_build_button()
	room_builder.stop_editing()

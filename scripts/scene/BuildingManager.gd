class_name BuildingManager extends Node

@onready var GUI: StationGUI = %GUI

@onready var base_tile_map: TileMap = %BaseTileMap
@onready var build_tile_map: TileMap = %BuildTileMap
@onready var room_builder: RoomBuilder = %RoomBuilder

@onready var camera: Camera2D = %Camera

@onready var state_manager: StateChart = %StateManager

signal room_built(room_type: RoomType, room_area: Array[Vector2i])

var room_types: Array[RoomType] = []
var selected_roomtype: RoomType = null

var popup: GUIPopup
	
enum StateEvent {BUILDING_STOP, BUILDING_START, BUILDING_BACK, BUILDING_FORWARD}

const BUILD_EVENTS = [&"building_stop", &"building_start", &"building_back", &"building_forward"]

func _init() -> void:
	# Load and initialize room types
	load_room_types()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	room_builder.action_completed.connect(on_room_builder_action)
	# Connect the buttons to the confirmation functions in the GUI script
	GUI.build_menu.action_completed.connect(on_build_menu_action)
	popup = GUI.manager.new_popup(false, room_builder.confirm_build, room_builder.cancel_build)
	load_room_types()
	room_builder.room_types = room_types

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
				room_type_instance.power_consumption = room_type_resource.power_consumption
				room_type_instance.capacity = room_type_resource.capacity
				room_type_instance.min_tiles = room_type_resource.min_tiles
				room_type_instance.max_tiles = room_type_resource.max_tiles
				room_type_instance.tileset_id = room_type_resource.tileset_id
				# Add the room type instance to the list
				room_types.append(room_type_instance)
				
			file_name = room_type_files.get_next()
				
		room_type_files.list_dir_end()

# TODO: refactor action handlers
func on_build_menu_action(action: int, clicked_roomtype: RoomType) -> void:
	var event: String
	match action:
		GUI.build_menu.Action.CLOSE:
			event = BUILD_EVENTS[StateEvent.BUILDING_STOP]
		GUI.build_menu.Action.OPEN:
			event = BUILD_EVENTS[StateEvent.BUILDING_START]
		GUI.build_menu.Action.SELECT_ROOMTYPE:
			selected_roomtype = clicked_roomtype
			event = BUILD_EVENTS[StateEvent.BUILDING_FORWARD]
	state_manager.send_event(event)

func on_room_builder_action(action: int) -> void:
	var event: String
	match action:
		room_builder.Action.BACK:
			event = BUILD_EVENTS[StateEvent.BUILDING_BACK]
		room_builder.Action.FORWARD:
			event = BUILD_EVENTS[StateEvent.BUILDING_FORWARD]
		room_builder.Action.COMPLETE:
			event = BUILD_EVENTS[StateEvent.BUILDING_STOP]
			emit_signal("room_built", selected_roomtype, room_builder.get_selected_tiles()) # Trigger furnishing manager start
	state_manager.send_event(event)

func _on_building_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_STOP])

func _on_selecting_roomtype_state_entered() -> void:
	GUI.build_menu.show_room_panel(room_types)

func _on_selecting_roomtype_state_input(event: InputEvent):
	if event.is_action_pressed("cancel"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_STOP])

func _on_selecting_roomtype_state_exited() -> void:
	GUI.build_menu.hide_room_panel()

# TODO: refactor state input handlers
func _on_selecting_tile_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		room_builder.selecting_tile(event, camera.position, camera.zoom, selected_roomtype)
	elif event.is_action_pressed("cancel"):
		room_builder.clear_selected_roomtype()
	elif event is InputEventMouseMotion:
		room_builder.selecting_tile_motion(event, camera.position, camera.zoom)

func _on_drafting_room_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		room_builder.drafting_room()
	elif event.is_action_pressed("cancel"):
		room_builder.stop_drafting()
		room_builder.selecting_tile_motion(event, camera.position, camera.zoom)
	elif event is InputEventMouseMotion:
		room_builder.drafting_room_motion(event, camera.position, camera.zoom)

func _on_setting_door_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		room_builder.setting_door(event, camera.position, camera.zoom)
	elif event.is_action_pressed("cancel"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_BACK])
	elif event is InputEventMouseMotion:
		room_builder.setting_door_motion(event, camera.position, camera.zoom)

func _on_confirming_room_state_entered() -> void:
	popup.set_title(room_builder.popup_title).set_content(room_builder.popup_content).set_yes_text(room_builder.popup_yes_text).set_no_text(room_builder.popup_no_text).show()

func _on_confirming_room_state_exited() -> void:
	popup.hide()

func _on_confirming_room_state_input(event: InputEvent):
	if event.is_action_pressed("cancel"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_BACK])

func _on_building_state_entered() -> void:
	GUI.build_menu.hide_build_button()

func _on_building_state_exited() -> void:
	selected_roomtype = null
	GUI.build_menu.show_build_button()
	room_builder.stop_drafting()

# DISCUSS: Do we need this?
class_name EditingManager extends Node

@onready var GUI: StationGUI = %GUI

@onready var base_tile_map: TileMap = %BaseTileMap
@onready var build_tile_map: TileMap = %BuildTileMap

@onready var camera: Camera2D = %Camera

@onready var state_manager: StateChart = %StateManager

@onready var building_manager: BuildingManager = %BuildingManager

@onready var room_editor: RoomEditor = %RoomEditor

var room_types: Array[RoomType] = []
var selected_roomtype: RoomType = null

var popup: GUIPopup
	
enum StateEvent {EDITING_STOP, EDITING_START, EDITING_BACK, EDITING_FORWARD}

const EDIT_EVENTS = [&"editing_stop", &"editing_start", &"editing_back", &"editing_forward"]

func _init() -> void:
	# Load and initialize room types
	load_room_types()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	room_editor.action_completed.connect(on_room_editor_action)
	# Connect the buttons to the confirmation functions in the GUI script
	popup = GUI.manager.new_popup(false, room_editor.confirm_delete, room_editor.cancel_delete)

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

func on_room_editor_action(action: int) -> void:
	var event: String
	match action:
		room_editor.Action.START:
			event = EDIT_EVENTS[StateEvent.EDITING_START]
		room_editor.Action.BACK:
			event = EDIT_EVENTS[StateEvent.EDITING_BACK]
		room_editor.Action.FORWARD:
			event = EDIT_EVENTS[StateEvent.EDITING_FORWARD]
		room_editor.Action.COMPLETE:
			event = EDIT_EVENTS[StateEvent.EDITING_STOP]
	state_manager.send_event(event)
	
func _on_selecting_room_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		room_editor.on_left_mouse_button_press()
	if event.is_action_pressed("exit"):
		state_manager.send_event(EDIT_EVENTS[StateEvent.EDITING_STOP])

func _on_deleting_room_state_entered() -> void:
	popup.set_title(room_editor.popup_title).set_content(room_editor.popup_content).set_yes_text(room_editor.popup_yes_text).set_no_text(room_editor.popup_no_text).show()

func _on_deleting_room_state_exited() -> void:
	popup.hide()

func _on_deleting_room_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit") or event.is_action_pressed("cancel"):
		state_manager.send_event(EDIT_EVENTS[StateEvent.EDITING_STOP])

# EditingManager.gd

class_name EditingManager
extends Node

@onready var base_tile_map: TileMap = $"../BaseTileMap"
@onready var build_tile_map: TileMap = $"../BaseTileMap/BuildTileMap"

@onready var camera: Camera2D = $"../Camera2D"

@onready var state_manager: StateChart = $"../StateManager"

@onready var building_manager = get_parent().get_node("BuildingManager")

var room_editor: RoomEditor
var room_types: Array[RoomType] = []
var selected_roomtype: RoomType = null

var popup: GUIPopup
	
enum StateEvent {EDITING_STOP, EDITING_START, EDITING_BACK, EDITING_FORWARD}

const Events = [&"editing_stop", &"editing_start", &"editing_back", &"editing_forward"]

func _init() -> void:
	# Load and initialize room types
	load_room_types()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	room_editor = RoomEditor.new(build_tile_map, Global.station.rooms, room_types, building_manager.room_builder)
	room_editor.action_completed.connect(on_room_editor_action)
	# Connect the buttons to the confirmation functions in the GUI script
	popup = GUI.manager.new_popup(room_editor.popup_message, false, room_editor.confirm_delete, room_editor.cancel_delete)
	

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

func on_room_editor_action(action: int) -> void:
	var event: String
	match action:
		room_editor.Action.START:
			event = Events[StateEvent.EDITING_START]
		room_editor.Action.BACK:
			event = Events[StateEvent.EDITING_BACK]
		room_editor.Action.FORWARD:
			event = Events[StateEvent.EDITING_FORWARD]
		room_editor.Action.COMPLETE:
			event = Events[StateEvent.EDITING_STOP]
	state_manager.send_event(event)

func _on_editing_state_entered() -> void:
	pass

func _on_editing_state_exited() -> void:
	pass
	
func _on_editing_state_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			state_manager.send_event(Events[StateEvent.EDITING_STOP])
	elif event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				1: room_editor.handle_select_input(event, camera.offset, camera.zoom);
	
func _on_deleting_room_state_entered() -> void:
	popup.set_text(room_editor.popup_message).show()

func _on_deleting_room_state_exited() -> void:
	popup.hide()

func _on_deleting_room_state_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				1:
					pass
				2: 
					state_manager.send_event(Events[StateEvent.EDITING_STOP])

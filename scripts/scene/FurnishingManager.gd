class_name FurnishingManager extends Node

@onready var GUI: StationGUI = %GUI

@onready var furniture_tile_map: TileMap = %FurnitureTileMap

@onready var state_manager: StateChart = %StateManager

@onready var camera: Camera2D = %Camera

@onready var building_manager: BuildingManager = %BuildingManager

var furniture_types: Array[FurnitureType]
var selected_furnituretype: FurnitureType = null
var _current_room_area: Array[Vector2i] = []
var _current_room_type: RoomType = null

enum StateEvent {FURNISHING_STOP, FURNISHING_START, FURNISHING_BACK, FURNISHING_FORWARD}

const FURNISH_EVENTS = [&"furnishing_stop", &"furnishing_start", &"furnishing_back", &"furnishing_forward"]

func _init() -> void:
	load_furniture_types()
	
func _ready() -> void:
	building_manager.room_built.connect(start_furnishing)
	GUI.furniture_menu.action_completed.connect(on_furniture_menu_action)
	
func load_furniture_types() -> void:
	var furniture_types_folder = "res://assets/furniture_type/"
	var furniture_type_files = DirAccess.open(furniture_types_folder)
	
	# Open the furniture types folder
	if furniture_type_files:
		# Iterate over each file in the folder
		furniture_type_files.list_dir_begin()
		var file_name = furniture_type_files.get_next()
		while file_name != "":
			var file_path = furniture_types_folder + file_name
			
			# Check if the file is a .tres resource
			if file_name.ends_with(".tres"):
				# Load the furniture type resource
				var furniture_type_resource = load(file_path)
				
				# Create an instance of the RoomType class
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
				furniture_type_instance.valid_room_types = furniture_type_resource.valid_room_types
			
				# Add the furniture type instance to the list
				furniture_types.append(furniture_type_instance)
				
			file_name = furniture_type_files.get_next()
				
		furniture_type_files.list_dir_end()
	
func get_valid_furniture_for_room(room_type: RoomType) -> Array[FurnitureType]:
	var valid_furniture: Array[FurnitureType] = []
	for furniture in furniture_types:
		if room_type.id in furniture.valid_room_types:
			valid_furniture.append(furniture)
	return valid_furniture
		
func start_furnishing(room_type: RoomType, room_area: Array[Vector2i]) -> void:
	selected_furnituretype = null
	_current_room_area = room_area
	_current_room_type = room_type
	state_manager.send_event("furnishing_start")
	

func on_furniture_menu_action(action: int, clicked_furnituretype: FurnitureType) -> void:
	var event: String
	match action:
		GUI.furniture_menu.Action.CLOSE:
			event = FURNISH_EVENTS[StateEvent.FURNISHING_STOP]
		GUI.furniture_menu.Action.OPEN:
			event = FURNISH_EVENTS[StateEvent.FURNISHING_START]
		GUI.furniture_menu.Action.SELECT_FURNITURE:
			selected_furnituretype = clicked_furnituretype
			event = FURNISH_EVENTS[StateEvent.FURNISHING_FORWARD]
	state_manager.send_event(event)
			

func _on_selecting_furniture_state_entered():
	GUI.furniture_menu.show_furniture_panel(get_valid_furniture_for_room(_current_room_type))

func _on_selecting_furniture_state_input(event):
	if event.is_action_pressed("cancel"):
		state_manager.send_event(FURNISH_EVENTS[StateEvent.FURNISHING_STOP])

func _on_selecting_furniture_state_exited() -> void:
	GUI.furniture_menu.hide_furniture_panel()

func _on_placing_furniture_state_input(event):
	if event.is_action_pressed("select"):
		place_furniture(event)

# Discuss: This needs to be tied to the room.
func place_furniture(event: InputEvent) -> void:
	if selected_furnituretype == null:
		print("No furniture selected")
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var tile_pos = furniture_tile_map.local_to_map(furniture_tile_map.get_global_mouse_position())
		if not _current_room_area.has(tile_pos):
			print("Tile outside room area")
			return
		furniture_tile_map.set_cell(0, tile_pos, selected_furnituretype.tileset_id, Vector2i(0, 0))
		print("Placed %s at %s" % [selected_furnituretype.name, tile_pos])

#func rotate_selected_furniture() -> void:
	# Discuss: 4 directions or 2?

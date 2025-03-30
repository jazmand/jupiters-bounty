class_name FurnishingManager extends Node

@onready var GUI: StationGUI = %GUI

@onready var furniture_tile_map: TileMap = %FurnitureTileMap

@onready var state_manager: StateChart = %StateManager

@onready var camera: Camera2D = $Camera2D  # Adjust as needed

var furniture_types: Array[FurnitureType]
var selected_furniture_type: FurnitureType = null
var _current_room_area: Array[Vector2i] = []
var _current_room_type: RoomType = null

func _init() -> void:
	load_furniture_types()
	
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
#
## Called when the node enters the scene tree for the first time.
#func _ready():
	#pass # Replace with function body.
#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	#pass
	
func get_valid_furniture_for_room(room_type: RoomType) -> Array[FurnitureType]:
	var valid_furniture = []
	for furniture in furniture_types:
		if room_type.id in furniture.valid_room_types:
			valid_furniture.append(furniture)
	return valid_furniture
		
func start_furnishing(room_type: RoomType, room_area: Array[Vector2i]) -> void:
	selected_furniture_type = null
	_current_room_area = room_area
	_current_room_type = room_type
	GUI.furniture_menu.show_furniture_panel(get_valid_furniture_for_room(room_type))
	state_manager.send_event("furnishing_start")

func _on_furnishing_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		place_furniture(event, camera.position, camera.zoom)
	elif event.is_action_pressed("cancel"):
		state_manager.send_event("furnishing_cancel")
	elif event.is_action_pressed("rotate"):
		rotate_selected_furniture()

func _on_furniture_action_completed(action: int, furniture_type: FurnitureType) -> void:
	if action == GUI.furniture_menu.Action.SELECT_FURNITURE:
		selected_furniture_type = furniture_type
		print("Selected furniture for placement: %s" % furniture_type.name)
	elif action == GUI.furniture_menu.Action.CLOSE:
		state_manager.send_event("furnishing_cancel")

func place_furniture(event: InputEvent, cam_position: Vector2, zoom: Vector2) -> void:
	if selected_furniture_type == null:
		print("No furniture selected")
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos = (event.position / zoom) + cam_position
		var tile_pos = furniture_tile_map.local_to_map(world_pos)
		if not _current_room_area.has(tile_pos):
			print("Tile outside room area!")
			return
		furniture_tile_map.set_cell(0, tile_pos, selected_furniture_type.tileset_id)
		print("Placed %s at %s" % [selected_furniture_type.name, tile_pos])

func rotate_selected_furniture() -> void:
	pass
	#current_rotation = (current_rotation + 90) % 360
	#print("Rotated to %d degrees" % current_rotation)


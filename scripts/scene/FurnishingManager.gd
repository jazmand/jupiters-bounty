class_name FurnishingManager extends Node

@onready var GUI: StationGUI = %GUI

@onready var furniture_tile_map: TileMap = %FurnitureTileMap

@onready var state_manager: StateChart = %StateManager

var furniture_types: Array[FurnitureType]
var selected_furnituretype: RoomType = null

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

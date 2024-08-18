# RoomEditor.gd

class_name RoomEditor
extends Node

signal action_completed(action: int)

var selected_tile_coords = Vector2i()
var selected_room: Room
var building_layer: int = 0

var build_tile_map: TileMap
var rooms: Array[Room]
var room_types: Array[RoomType]
var room_builder: RoomBuilder
var nav_region: NavigationRegion2D

var popup_message: String = ""

enum Action {START, BACK, FORWARD, COMPLETE}

func _init(build_tile_map: TileMap, room_types: Array[RoomType], room_builder: RoomBuilder, navigation_region: NavigationRegion2D):
	self.build_tile_map = build_tile_map
	self.room_types = room_types
	self.room_builder = room_builder
	self.nav_region = navigation_region

func on_left_mouse_button_press(event: InputEvent, offset: Vector2, zoom: Vector2) -> void:
	selected_tile_coords = build_tile_map.local_to_map((event.position / zoom) + offset)
	select_room(selected_tile_coords)
	
func select_room(selected_tile_coords: Vector2i) -> void:
	for room in Global.station.rooms:
		var min_x = min(room.topLeft.x, room.bottomRight.x)
		var max_x = max(room.topLeft.x, room.bottomRight.x)
		var min_y = min(room.topLeft.y, room.bottomRight.y)
		var max_y = max(room.topLeft.y, room.bottomRight.y)
		
		if selected_tile_coords.x >= min_x and selected_tile_coords.x <= max_x and selected_tile_coords.y >= min_y and selected_tile_coords.y <= max_y:
			# The selected_tile_coords is within the room's range
			selected_room = room
			var room_details = get_room_details(room)
			popup_message = "You have selected " + room_details.name + " it's size is " + str(room_details.size) + " and it's power consumption is " + str(room_details.powerConsumption)
			action_completed.emit(Action.FORWARD)
			
func get_room_details(room: Room) -> Dictionary:
	# Create a JSON dictionary
	var room_details = {}
	for room_type in room_types:
		if room_type.id == room.roomType.id:
			room_details.name = room_type.name
			room_details.size = calculate_tile_count(room.topLeft, room.bottomRight)
			room_details.powerConsumption = room_type.powerConsumption * room_details.size
	return room_details

func confirm_delete() -> void:
	Global.station.remove_room(selected_room)
	room_builder.draw_rooms()
	nav_region.bake_navigation_polygon()
	action_completed.emit(Action.COMPLETE)

func cancel_delete() -> void:
	action_completed.emit(Action.COMPLETE)

func calculate_tile_count(vector1: Vector2, vector2: Vector2) -> int:
	var difference_x = abs(vector2.x - vector1.x) + 1
	var difference_y = abs(vector2.y - vector1.y) + 1
	return difference_x * difference_y

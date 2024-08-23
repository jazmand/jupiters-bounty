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
var navigation_region: NavigationRegion2D

var popup_title: String = ""
var popup_content: String = ""
var popup_yes_text: String = "Yes"
var popup_no_text: String = "No"

enum Action {START, BACK, FORWARD, COMPLETE}

func _init(build_tile_map: TileMap, room_types: Array[RoomType], room_builder: RoomBuilder, navigation_region: NavigationRegion2D):
	self.build_tile_map = build_tile_map
	self.room_types = room_types
	self.room_builder = room_builder
	self.navigation_region = navigation_region

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
			var room_size = calculate_tile_count(room.topLeft, room.bottomRight)
			var room_cost = room.roomType.price * room_size
			var room_consumption = room.roomType.powerConsumption * room_size
			var room_width = abs(room.bottomRight.x - room.topLeft.x) + 1
			var room_height = abs(room.bottomRight.y - room.topLeft.y) + 1
			var consumption_text = ""
			if room_consumption < 0:
				consumption_text = "[b]Generates: [/b]" + str(-room_consumption) + "KW"
			else:
				consumption_text = "[b]Consumes: [/b]" + str(room_consumption) + "KW"
			popup_title = room.roomType.name
			popup_content = "[b]Dimensions: [/b]" + str(room_width) + "x" + str(room_height) + " tiles\n" + consumption_text + "\n\n[b]Refund: [/b]" + str(room_cost / 3) 
			popup_yes_text = "Delete"
			popup_no_text = "Close"
			action_completed.emit(Action.FORWARD)

func confirm_delete() -> void:
	Global.station.remove_room(selected_room)
	room_builder.draw_rooms()
	navigation_region.bake_navigation_polygon()
	Global.station.currency += (calculate_room_price() / 3) # Refunds 1/3 the original cost
	action_completed.emit(Action.COMPLETE)

func cancel_delete() -> void:
	action_completed.emit(Action.COMPLETE)

func calculate_tile_count(vector1: Vector2, vector2: Vector2) -> int:
	var difference_x = abs(vector2.x - vector1.x) + 1
	var difference_y = abs(vector2.y - vector1.y) + 1
	return difference_x * difference_y

func calculate_room_price() -> int:
	return selected_room.roomType.price * calculate_tile_count(selected_room.topLeft, selected_room.bottomRight)

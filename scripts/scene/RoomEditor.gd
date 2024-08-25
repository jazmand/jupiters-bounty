class_name RoomEditor extends Node

signal action_completed(action: int)

var selected_tile_coords = Vector2i()
var selected_room: Room
var building_layer: int = 0

var build_tile_map: TileMap
var rooms: Array[Room]
var room_types: Array[RoomType]
var room_builder: RoomBuilder

var popup_title: String = ""
var popup_content: String = ""
var popup_yes_text: String = "Yes"
var popup_no_text: String = "No"

enum Action {START, BACK, FORWARD, COMPLETE}

func _init(build_map: TileMap, types: Array[RoomType], builder: RoomBuilder):
	build_tile_map = build_map
	room_types = types
	room_builder = builder

func on_left_mouse_button_press(event: InputEvent, offset: Vector2, zoom: Vector2) -> void:
	selected_tile_coords = build_tile_map.local_to_map((event.position / zoom) + offset)
	var room_id: int = Room.find_tile_room_id(selected_tile_coords)
	if room_id > 0:
		var room = Global.station.find_room_by_id(room_id)
		if not room:
			return
		selected_room = room
		var room_size = calculate_tile_count(room.data.top_left, room.data.bottom_right)
		var room_cost = room.data.type.price * room_size
		var room_consumption = room.data.type.power_consumption * room_size
		var room_width = abs(room.data.bottom_right.x - room.data.top_left.x) + 1
		var room_height = abs(room.data.bottom_right.y - room.data.top_left.y) + 1
		var consumption_text = ""
		if room_consumption < 0:
			consumption_text = "[b]Generates: [/b]" + str(-room_consumption) + "KW"
		else:
			consumption_text = "[b]Consumes: [/b]" + str(room_consumption) + "KW"
		popup_title = room.data.type.name
		popup_content = "[b]Dimensions: [/b]" + str(room_width) + "x" + str(room_height) + " tiles\n" + consumption_text + "\n\n[b]Refund: [/b]" + str(room_cost / 3)
		popup_yes_text = "Delete"
		popup_no_text = "Close"
		action_completed.emit(Action.FORWARD)


func confirm_delete() -> void:
	Global.station.remove_room(selected_room)
	room_builder.draw_rooms()
	Global.station.currency += (calculate_room_price() / 3) # Refunds 1/3 the original cost
	action_completed.emit(Action.COMPLETE)

func cancel_delete() -> void:
	action_completed.emit(Action.COMPLETE)

func calculate_tile_count(vector1: Vector2, vector2: Vector2) -> int:
	var difference_x = abs(vector2.x - vector1.x) + 1
	var difference_y = abs(vector2.y - vector1.y) + 1
	return difference_x * difference_y

func calculate_room_price() -> int:
	return selected_room.data.type.price * calculate_tile_count(selected_room.data.top_left, selected_room.data.bottom_right)

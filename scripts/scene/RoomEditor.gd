class_name RoomEditor extends Node
#
#signal action_completed(action: int)
#
#@onready var build_tile_map: TileMap = %BuildTileMap
#@onready var editing_manager: EditingManager = %EditingManager
#@onready var room_builder: RoomBuilder = %RoomBuilder
#
#var selected_tile_coords = Vector2i()
#var selected_room: Room
#var building_layer: int = 0
#
#var rooms: Array[Room]
#var room_types: Array[RoomType]
#
#var popup_title: String = ""
#var popup_content: String = ""
#var popup_yes_text: String = "Yes"
#var popup_no_text: String = "No"
#
#enum Action {START, BACK, FORWARD, COMPLETE}
#
#func _ready():
	#room_types = editing_manager.room_types
#
#func on_left_mouse_button_press() -> void:
	#selected_tile_coords = build_tile_map.local_to_map(build_tile_map.get_global_mouse_position())
	#var room_id: int = Room.find_tile_room_id(selected_tile_coords)
	#if room_id > 0:
		#var room = Global.station.find_room_by_id(room_id)
		#if not room:
			#return
		#selected_room = room
		#var room_size = Room.calculate_tile_count(room.data.top_left, room.data.bottom_right)
		#var room_cost = room.data.type.price * room_size
		#var room_consumption = room.data.type.power_consumption * room_size
		#var room_width = abs(room.data.bottom_right.x - room.data.top_left.x) + 1
		#var room_height = abs(room.data.bottom_right.y - room.data.top_left.y) + 1
		#var consumption_text = ""
		#if room_consumption < 0:
			#consumption_text = "[b]Generates: [/b]" + str(-room_consumption) + "KW"
		#else:
			#consumption_text = "[b]Consumes: [/b]" + str(room_consumption) + "KW"
		#popup_title = room.data.type.name
		#popup_content = "[b]Dimensions: [/b]" + str(room_width) + "x" + str(room_height) + " tiles\n" + consumption_text + "\n\n[b]Refund: [/b]" + str(room_cost / 3)
		#popup_yes_text = "Delete"
		#popup_no_text = "Close"
		#action_completed.emit(Action.FORWARD)
#
#
#func confirm_delete() -> void:
	#Global.station.remove_room(selected_room)
	#room_builder.draw_rooms()
	#var room_size = Room.calculate_tile_count(selected_room.data.top_left, selected_room.data.bottom_right)
	#var price = Room.calculate_room_price(selected_room.data.type.price, room_size)
	#Global.station.currency += (price / 3) # Refunds 1/3 the original cost
	#action_completed.emit(Action.COMPLETE)
#
#func cancel_delete() -> void:
	#action_completed.emit(Action.COMPLETE)

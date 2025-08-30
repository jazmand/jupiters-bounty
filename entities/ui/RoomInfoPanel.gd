class_name RoomInfoPanel extends PanelContainer

@onready var room_label: Label = $RoomInfoContainer/HeaderContainer/Label

@onready var previous_button: Button = $RoomInfoContainer/PortraitContainer/PreviousRoomButton
@onready var next_button: Button = $RoomInfoContainer/PortraitContainer/NextRoomButton
@onready var portrait: TextureRect = $RoomInfoContainer/PortraitContainer/TextureRect

@onready var tab_container: TabContainer = $RoomInfoContainer/TabContainer
@onready var info_container: VBoxContainer = $RoomInfoContainer/TabContainer/InfoContainer

@onready var info_list: ItemList = $RoomInfoContainer/TabContainer/InfoContainer/InfoList
@onready var worker_list: ItemList = $RoomInfoContainer/TabContainer/WorkersContainer/WorkerList

var portraits: Dictionary = {
	Global.ROOMTYPE.CREW_QUARTERS: preload("res://assets/tilesets/crew_quarters.png"),
	Global.ROOMTYPE.GENERATOR_ROOM: preload("res://assets/tilesets/generator_room.png"),
	Global.ROOMTYPE.STORAGE_BAY: preload("res://assets/tilesets/storage_bay.png")
}

var room: Room = null

func _ready() -> void:
	# Enable mouse filtering to consume mouse events and prevent them from reaching game world
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	previous_button.pressed.connect(cycle_rooms.bind(-1))
	next_button.pressed.connect(cycle_rooms.bind(1))
	tab_container.set_tab_title(0, "Info")
	tab_container.set_tab_title(1, "Workers")

func display_room_info(selected_room: Room) -> void:
	room_label.text = selected_room.data.type.name
	portrait.texture = portraits[selected_room.data.type.id]
	var display_data = {
		"Price" = Room.calculate_room_price(
			selected_room.data.type.price, 
			Room.calculate_tile_count(
				selected_room.data.top_left,
				selected_room.data.bottom_right
				)
			),
		"Power Consumption" = selected_room.data.calculate_power_consumption(),
	}
	for key in display_data:
		var display_text = "%s: %d" % [key, display_data[key]]
		info_list.add_item(display_text, null, false)

func display_worker_info(selected_room: Room) -> void:
	pass
	#for crew_id in selected_room.data.assigned_crew_ids:
		#var crew: CrewMember = Global.station.find_crew_by_id(crew_id)
		#var display_text = "%s (%d)" % [crew.data.name, crew.data.age]
		#worker_list.add_item(display_text, null, false)

func update_worker_info() -> void:
	worker_list.clear()
	display_worker_info(room)

func reset_panel() -> void:
	if room == null:
		return
	info_list.clear()
	worker_list.clear()
	room = null

func setup_new_panel(selected_room: Room) -> void:
	room = selected_room
	display_room_info(selected_room)
	display_worker_info(selected_room)

func open(selected_room: Room) -> void:
	reset_panel()
	setup_new_panel(selected_room)
	show()

func close() -> void:
	hide()
	reset_panel()

func cycle_rooms(diff: int) -> void:
	var all_rooms = Global.station.rooms
	var rooms_amount = all_rooms.size()
	var next_idx = all_rooms.find(room) + diff
	var idx = get_cycled_idx(next_idx, rooms_amount)
	reset_panel()
	setup_new_panel(all_rooms[idx])

func get_cycled_idx(next_idx: int, rooms_amount: int) -> int:
	if next_idx >= rooms_amount:
		next_idx -= rooms_amount
	elif next_idx < 0:
		next_idx += rooms_amount
	return next_idx

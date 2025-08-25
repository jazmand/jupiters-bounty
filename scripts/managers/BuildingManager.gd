class_name BuildingManager extends Node

@onready var GUI: GUI = %GUI

@onready var room_builder: RoomBuilder = %RoomBuilder

@onready var camera: Camera2D = %Camera

@onready var state_manager: StateChart = %StateManager

signal room_built(room_type: RoomType, room_area: Array[Vector2i])

var selected_roomtype: RoomType = null

var popup: GUIPopup
	
enum StateEvent {BUILDING_STOP, BUILDING_START, BUILDING_BACK, BUILDING_FORWARD}

const BUILD_EVENTS = [&"building_stop", &"building_start", &"building_back", &"building_forward"]

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	room_builder.action_completed.connect(on_room_builder_action)
	# Connect the buttons to the confirmation functions in the GUI script
	GUI.build_menu.action_completed.connect(on_build_menu_action)
	popup = GUI.manager.new_popup(false, room_builder.confirm_build, room_builder.cancel_build)
	
	# RoomBuilder now directly accesses ResourceManager.room_types
	# No initialization needed
	


# TODO: refactor action handlers
func on_build_menu_action(action: int, clicked_roomtype: RoomType) -> void:
	var event: String
	match action:
		GUI.build_menu.Action.CLOSE:
			event = BUILD_EVENTS[StateEvent.BUILDING_STOP]
		GUI.build_menu.Action.OPEN:
			event = BUILD_EVENTS[StateEvent.BUILDING_START]
		GUI.build_menu.Action.SELECT_ROOMTYPE:
			selected_roomtype = clicked_roomtype
			event = BUILD_EVENTS[StateEvent.BUILDING_FORWARD]
	state_manager.send_event(event)

func on_room_builder_action(action: int) -> void:
	var event: String
	match action:
		room_builder.Action.BACK:
			event = BUILD_EVENTS[StateEvent.BUILDING_BACK]
		room_builder.Action.FORWARD:
			event = BUILD_EVENTS[StateEvent.BUILDING_FORWARD]
		room_builder.Action.COMPLETE:
			event = BUILD_EVENTS[StateEvent.BUILDING_STOP]
			room_built.emit(selected_roomtype, room_builder.get_selected_tiles())
	state_manager.send_event(event)

func _on_building_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_STOP])

func _on_selecting_roomtype_state_entered() -> void:
	GUI.build_menu.show_room_panel(ResourceManager.room_types)

func _on_selecting_roomtype_state_input(event: InputEvent):
	if event.is_action_pressed("cancel"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_STOP])

func _on_selecting_roomtype_state_exited() -> void:
	GUI.build_menu.hide_room_panel()

# TODO: refactor state input handlers
func _on_selecting_tile_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		room_builder.selecting_tile(selected_roomtype)
	elif event.is_action_pressed("cancel"):
		room_builder.clear_selected_roomtype()
	elif event is InputEventMouseMotion:
		room_builder.selecting_tile_motion()
		

func _on_drafting_room_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		room_builder.drafting_room()
	elif event.is_action_pressed("cancel"):
		room_builder.stop_drafting()
		room_builder.selecting_tile_motion()
	elif event is InputEventMouseMotion:
		room_builder.drafting_room_motion()

func _on_setting_door_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		room_builder.setting_door()
	elif event.is_action_pressed("cancel"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_BACK])
	elif event is InputEventMouseMotion:
		room_builder.setting_door_motion()

func _on_confirming_room_state_entered() -> void:
	popup.set_title(room_builder.popup_title).set_content(room_builder.popup_content).set_yes_text(room_builder.popup_yes_text).set_no_text(room_builder.popup_no_text).show()

func _on_confirming_room_state_exited() -> void:
	popup.hide()

func _on_confirming_room_state_input(event: InputEvent):
	if event.is_action_pressed("cancel"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_BACK])

func _on_building_state_entered() -> void:
	GUI.build_menu.hide_build_button()

func _on_building_state_exited() -> void:
	selected_roomtype = null
	GUI.build_menu.show_build_button()
	room_builder.stop_drafting()

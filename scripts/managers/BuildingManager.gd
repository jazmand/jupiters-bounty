class_name BuildingManager extends Node

@onready var gui: GUI = %GUI

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
	gui.build_menu.action_completed.connect(on_build_menu_action)
	popup = gui.manager.new_popup(false, room_builder.confirm_build, room_builder.cancel_build)
	
	# RoomBuilder now directly accesses ResourceManager.room_types
	# No initialization needed
	


# TODO: refactor action handlers
func on_build_menu_action(action: int, clicked_roomtype: RoomType) -> void:
	var event: String
	match action:
		gui.build_menu.Action.CLOSE:
			event = BUILD_EVENTS[StateEvent.BUILDING_STOP]
		gui.build_menu.Action.OPEN:
			event = BUILD_EVENTS[StateEvent.BUILDING_START]
		gui.build_menu.Action.SELECT_ROOMTYPE:
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
			# Invalidate nav-related flow fields after room placement
			if Global and Global.flow_service:
				Global.flow_service.mark_nav_dirty()
	state_manager.send_event(event)

func _on_building_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_STOP])

func _on_selecting_roomtype_state_entered() -> void:
	gui.build_menu.show_room_panel(ResourceManager.room_types)

func _on_selecting_roomtype_state_input(event: InputEvent):
	if event.is_action_pressed("cancel"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_STOP])

func _on_selecting_roomtype_state_exited() -> void:
	gui.build_menu.hide_room_panel()

# TODO: refactor state input handlers
func _on_selecting_tile_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		room_builder.selecting_tile(selected_roomtype)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		room_builder.clear_selected_roomtype()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		room_builder.selecting_tile_motion()
		

func _on_drafting_room_state_input(event: InputEvent) -> void:
	# Don't react to clicks that are intended for the room tooltip UI
	if _is_mouse_over_room_tooltip():
		return
	if event.is_action_pressed("select"):
		room_builder.drafting_room()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		room_builder.stop_drafting()
		room_builder.selecting_tile_motion()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		room_builder.drafting_room_motion()
		# While drafting, keep the confirmation tooltip synced near the current corner
		_show_or_update_room_confirm_tooltip()

func _on_setting_door_state_input(event: InputEvent) -> void:
	# Don't react to clicks that are intended for the room tooltip UI
	if _is_mouse_over_room_tooltip():
		return
	if event.is_action_pressed("select"):
		room_builder.setting_door()
		get_viewport().set_input_as_handled()
		_show_or_update_room_confirm_tooltip()
	elif event.is_action_pressed("cancel"):
		# Ensure any temporary door placements are cleared when stepping back
		if room_builder and room_builder.has_method("clear_temp_doors"):
			room_builder.clear_temp_doors()
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_BACK])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):  # Enter key for force confirmation
		# Confirm immediately if at least one door
		if room_builder.get_temp_door_count() > 0:
			room_builder.confirm_build()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		room_builder.setting_door_motion()
		_show_or_update_room_confirm_tooltip()

func _is_mouse_over_room_tooltip() -> bool:
	if gui and gui.manager:
		var panel: Control = gui.manager.get_node_or_null("RoomConfirmTooltip")
		if panel and panel.visible:
			var rect := panel.get_global_rect()
			var mouse := get_viewport().get_mouse_position()
			return rect.has_point(mouse)
	return false

func _on_confirming_room_state_entered() -> void:
	# Keep the lightweight tooltip visible and updated
	_show_or_update_room_confirm_tooltip()

func _on_confirming_room_state_exited() -> void:
	popup.hide()
	gui.manager.hide_room_confirm_tooltip()

func _on_confirming_room_state_input(event: InputEvent):
	if event.is_action_pressed("cancel"):
		state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_BACK])
	elif event.is_action_pressed("ui_accept"):
		if room_builder.get_temp_door_count() > 0:
			room_builder.confirm_build()

func _on_building_state_entered() -> void:
	gui.build_menu.hide_build_button()

func _on_building_state_exited() -> void:
	selected_roomtype = null
	gui.build_menu.show_build_button()
	room_builder.stop_drafting()
	gui.manager.hide_room_confirm_tooltip()

func _show_or_update_room_confirm_tooltip() -> void:
	if room_builder == null:
		return
	var metrics := room_builder.get_current_metrics()
	if metrics.is_empty():
		return
	var screen_pos := room_builder.get_confirmation_anchor_screen_pos()
	var accept_fn := func(): room_builder.force_door_confirmation()
	var decline_fn := func(): state_manager.send_event(BUILD_EVENTS[StateEvent.BUILDING_BACK])
	if gui and gui.manager:
		gui.manager.show_room_confirm_tooltip(metrics, screen_pos, accept_fn, decline_fn)

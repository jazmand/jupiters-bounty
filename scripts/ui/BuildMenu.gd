class_name BuildMenu extends Control

signal action_completed(action: int, room_type: RoomType)

enum Action {CLOSE, OPEN, SELECT_ROOMTYPE}

@onready var build_button: Button = $BuildButton
@onready var room_panel: Panel = $RoomPanel
@onready var rooms_container: HBoxContainer = $RoomPanel/HBoxContainer

var room_buttons: Dictionary = {}

func _ready() -> void:
	Global.station.currency_updated.connect(on_currency_updated)

func show_build_button() -> void:
	build_button.show()

func hide_build_button() -> void:
	build_button.hide()

func show_room_panel(room_types: Array[RoomType]) -> void:
	for room_type in room_types:
		if room_type.name not in room_buttons:
			room_buttons[room_type.name] = room_type
			var button = Button.new()
			button.text = room_type.name
			button.pressed.connect(_on_room_selected.bind(room_type)) # Must "bind" to pass param to a connect callback
			rooms_container.add_child(button)
	room_panel.show()

func hide_room_panel() -> void:
	room_panel.hide()

func _on_build_button_pressed() -> void:
	action_completed.emit(Action.OPEN, null)

func _on_build_close_button_pressed() -> void:
	action_completed.emit(Action.CLOSE, null)

func _on_room_selected(room_type: RoomType) -> void:
	action_completed.emit(Action.SELECT_ROOMTYPE, room_type)

func on_currency_updated(currency: int) -> void:
	var children: Array[Node] = rooms_container.get_children()
	for child in children:
		if child is Button and room_buttons.has(child.text):
			var room: RoomType = room_buttons.get(child.text)
			var button: Button = child as Button
			if (room.price * room.min_tiles) > currency:
				button.disabled = true
			else:
				button.disabled = false

class_name FurnitureMenu extends Control

signal action_completed(action: int, furniture_type: FurnitureType)

enum Action {CLOSE, OPEN, SELECT_FURNITURE}

@onready var furniture_panel: Panel = $FurniturePanel
@onready var furniture_container: HBoxContainer = $FurniturePanel/HBoxContainer

var furniture_buttons: Dictionary = {}

func _ready() -> void:
	Global.station.currency_updated.connect(on_currency_updated)


func _on_room_edit_button_pressed():
	#show_furniture_panel()
	pass

func show_furniture_panel(furniture_types: Array[FurnitureType]) -> void:
	for furniture_type in furniture_types:
		if furniture_type.name not in furniture_buttons:
			furniture_buttons[furniture_type.name] = furniture_type
			var button = Button.new()
			button.text = furniture_type.name
			button.pressed.connect(_on_furniture_selected.bind(furniture_type)) # Must "bind" to pass param to a connect callback
			furniture_container.add_child(button)
	furniture_panel.show()

func hide_furniture_panel() -> void:
	furniture_panel.hide()

func _on_furniture_open_button_pressed() -> void:
	action_completed.emit(Action.OPEN, null)

func _on_furniture_close_button_pressed() -> void:
	action_completed.emit(Action.CLOSE, null)

func _on_furniture_selected(furniture_type: FurnitureType) -> void:
	action_completed.emit(Action.SELECT_FURNITURE, furniture_type)

func on_currency_updated(currency: int) -> void:
	var children: Array[Node] = furniture_container.get_children()
	for child in children:
		if child is Button and furniture_buttons.has(child.text):
			var furniture: FurnitureType = furniture_buttons.get(child.text)
			var button: Button = child as Button
			if furniture.price > currency:
				button.disabled = true
			else:
				button.disabled = false

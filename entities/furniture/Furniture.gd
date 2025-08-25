class_name Furniture extends Node2D

signal furniture_clicked

@onready var area = $Area2D

func _ready():
	area.connect("input_event", self._on_area_input_event)

func _on_area_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("furniture_clicked")
		print("Furniture clicked at ", position)

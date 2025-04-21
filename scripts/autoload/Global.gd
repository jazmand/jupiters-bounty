extends Node

signal crew_assigned(crew: CrewMember)
signal crew_selected(crew: CrewMember)

signal update_cursor_label(text: String, position: Vector2)
signal hide_cursor_label()

const ROOMTYPE: Dictionary = {
	CREW_QUARTERS = 1,
	GENERATOR_ROOM = 2,
	STORAGE_BAY = 3,
}

var station: Station = load("res://assets/station/station_resources.tres") as Station

var is_crew_input = false

var selected_room: Room = null

func _ready() -> void:
	GameTime.second.connect(station.update_hydrogen)

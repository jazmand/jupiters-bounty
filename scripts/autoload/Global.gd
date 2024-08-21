extends Node

signal crew_assigned(crew: CrewMember)
signal crew_selected(crew: CrewMember)

signal update_cursor_label(text: String, position: Vector2)
signal hide_cursor_label()

var station: Station = load("res://assets/station/station_resources.tres")

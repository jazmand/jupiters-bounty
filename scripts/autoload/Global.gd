extends Node

signal crew_assigned(crew: CrewMember)
signal crew_selected(crew: CrewMember)

var station: Station = preload ("res://assets/station/station_resources.tres")

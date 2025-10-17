extends Node

signal crew_assigned(crew: Node)
signal crew_selected(crew: Node)

signal update_cursor_label(text: String, position: Vector2)
signal hide_cursor_label()

const ROOMTYPE: Dictionary = {
	CREW_QUARTERS = 1,
	GENERATOR_ROOM = 2,
	STORAGE_BAY = 3,
}

# Shared UI colors
const COLOR_HOVER_HIGHLIGHT := Color(1.3, 1.3, 1.1, 1.0)
const COLOR_SELECTED_HIGHLIGHT := Color(1.2, 1.2, 1.0, 1.0)
const COLOR_PREVIEW_VALID := Color(1.0, 1.0, 1.0, 0.7)
const COLOR_PREVIEW_INVALID := Color(1.0, 0.0, 0.0, 0.5)

var station: Station = load("res://assets/resources/station_resources.tres") as Station

var is_crew_input = false

var selected_room: Room = null
var inspected_furniture: Furniture = null

# Shared services
const FlowFieldServiceScript = preload("res://scripts/utilities/FlowFieldManager.gd")
var flow_service = null
const WanderBeaconsScript = preload("res://scripts/utilities/WanderBeacons.gd")
var wander_beacons = null
const AssignmentBeaconsScript = preload("res://scripts/utilities/AssignmentBeacons.gd")
var assignment_beacons = null

func _ready() -> void:
	GameTime.second.connect(station.update_hydrogen)
	# Initialize shared flow field service
	flow_service = FlowFieldServiceScript.new()
	# Initialize wander beacons
	wander_beacons = WanderBeaconsScript.new()
	add_child(wander_beacons)
	wander_beacons.rebuild_from_nav()
	assignment_beacons = AssignmentBeaconsScript.new()
	add_child(assignment_beacons)

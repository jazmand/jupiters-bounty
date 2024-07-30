# GameManager.gd

class_name GameManager
extends Node

const crew_scene: PackedScene = preload ("res://crew.tscn")

@onready var camera: Camera2D = $Camera2D
@onready var state_manager: StateChart = $StateManager
@onready var build_tile_map: TileMap = $BaseTileMap/BuildTileMap

var selected_crew: CrewMember = null

func _ready():
	GUI.manager.connect("add_crew_pressed", Callable(self, "new_crew_member"))
	Global.crew_assign_crew_selected.connect(crew_selected)

func new_crew_member(positionVector: Vector2 = Vector2(5000, 3000)) -> CrewMember:
	var crew_member: CrewMember = crew_scene.instantiate()
	crew_member.position = positionVector # Adjust spawning position
	add_child(crew_member)
	return crew_member
	
func crew_selected(crew: CrewMember) -> void:
	state_manager.send_event("crew")
	selected_crew = crew

func _on_selecting_room_state_input(event: InputEvent) -> void:
	if event.is_action_pressed("do_action"):
		var selected_tile_coords = build_tile_map.local_to_map((event.position / camera.zoom) + camera.offset)
		select_room(selected_tile_coords, event.position)

func select_room(selected_tile_coords: Vector2i, mouse_position: Vector2) -> void:
	for room in Global.station.rooms:
		var min_x = min(room.topLeft.x, room.bottomRight.x)
		var max_x = max(room.topLeft.x, room.bottomRight.x)
		var min_y = min(room.topLeft.y, room.bottomRight.y)
		var max_y = max(room.topLeft.y, room.bottomRight.y)
		
		if selected_tile_coords.x >= min_x and selected_tile_coords.x <= max_x and selected_tile_coords.y >= min_y and selected_tile_coords.y <= max_y:
			selected_crew.assign(room, (mouse_position / camera.zoom) + camera.offset)
			state_manager.send_event("assigned")

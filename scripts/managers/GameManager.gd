class_name GameManager extends Node2D

const CREW_SCENE: PackedScene = preload("res://entities/crew/crew_scene.tscn")

@onready var camera: Camera2D = %Camera
@onready var state_manager: StateChart = %StateManager
@onready var base_tile_map: TileMap = %BaseTileMap
@onready var build_tile_map: TileMap = %BuildTileMap
@onready var furniture_tile_map: TileMap = %FurnitureTileMap

@onready var navigation_region: NavigationRegion2D = %NavigationRegion

var selected_crew: CrewMember = null

func _ready():
	Events.gui_add_crew_pressed.connect(new_crew_member)
	Global.crew_assigned.connect(crew_selected)
	Global.station.rooms_updated.connect(update_navigation_region)
	
	# Set the tile maps in TileMapManager and initialise it
	TileMapManager.set_tile_maps(base_tile_map, build_tile_map, furniture_tile_map)

func new_crew_member(position_vector: Vector2 = Vector2(5000, 3000)) -> CrewMember:
	var crew_member: CrewMember = CREW_SCENE.instantiate()
	crew_member.position = position_vector # Adjust spawning position
	add_child(crew_member)
	Global.station.add_crew(crew_member)
	return crew_member
	
func crew_selected(crew: CrewMember) -> void:
	state_manager.send_event("crew")
	selected_crew = crew

func _on_selecting_room_state_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"do_action"):
		var mouse_position: Vector2 = local_mouse_position(event.position, camera)
		var selected_tile: Vector2i = build_tile_map.local_to_map(mouse_position)
		var room_id: int = Room.find_tile_room_id(selected_tile)
		if room_id > 0:
			var room = Global.station.find_room_by_id(room_id)
			if room.can_assign_crew():
				var assigned_tile = room.assign_crew(selected_crew)
				selected_crew.assign(room, to_global(build_tile_map.map_to_local(assigned_tile)))
				state_manager.send_event("assigned")

func local_mouse_position(event_position: Vector2, game_camera: Camera2D) -> Vector2:
	return to_local((event_position / game_camera.zoom) + game_camera.offset)

func _on_default_state_unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"start_building"):
		state_manager.send_event(&"building_start")
	elif event.is_action_pressed(&"start_editing"):
		state_manager.send_event(&"editing_start")
	elif event.is_action_pressed(&"select") and not Global.is_crew_input:
		var mouse_position: Vector2 = local_mouse_position(event.position, camera)
		var selected_tile: Vector2i = build_tile_map.local_to_map(mouse_position)
		var room_id: int = Room.find_tile_room_id(selected_tile)
		var room = Global.station.find_room_by_id(room_id)
		if room:
			Global.selected_room = room
			state_manager.send_event(&"furnishing_start")

func update_navigation_region() -> void:
	navigation_region.bake_navigation_polygon()


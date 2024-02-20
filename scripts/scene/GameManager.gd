# GameManager.gd

class_name GameManager
extends Node

const crew_scene: PackedScene = preload("res://crew.tscn")

func _ready():
	GUI.manager.connect("add_crew_pressed", Callable(self, "new_crew_member"))

func new_crew_member() -> CrewMember:
	var crew_member: CrewMember = crew_scene.instantiate()
	crew_member.position = Vector2(3000,  2000) # Adjust spawning position
	add_child(crew_member)
	return crew_member
	
	

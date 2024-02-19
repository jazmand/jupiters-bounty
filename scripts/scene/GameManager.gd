# GameManager.gd

class_name GameManager
extends Node

const crew_scene: PackedScene = preload("res://crew.tscn")

func new_crew_member() -> CrewMember:
	var crew_member: CrewMember = crew_scene.instantiate()
	crew_member.position = Vector2(1500,  2500) # Adjust spawning position
	add_child(crew_member)
	return crew_member
	

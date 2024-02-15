# GameManager.gd

class_name GameManager
extends Node

const crew_scene: PackedScene = preload("res://crew.tscn")

func new_crew_member() -> CrewMember:
	var crew_member: CrewMember = crew_scene.instantiate()
	var image: Sprite2D = Sprite2D.new()
	var texture: Texture = ResourceLoader.load("res://assets/sprites/walk_agatha.png")
	image.texture = texture
	crew_member.add_child(image)
	add_child(crew_member)
	return crew_member
	

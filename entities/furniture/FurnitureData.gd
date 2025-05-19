class_name FurnitureData extends Resource

@export var id: int
@export var type: FurnitureType
@export var position: Vector2i
@export var rotation: int = 0 # 0 for x-axis alignment, 1 for y-axis
var assigned_crew_ids: Array[int] = []

#func can_assign_crew() -> bool:
	#return assigned_crew_ids.size() < use_limit

#func assign_crew(crew_id: int) -> bool:
	##if can_assign_crew():
		#assigned_crew_ids.append(crew_id)
		#return true
	##return false
#
#func remove_crew(crew_id: int) -> void:
	#assigned_crew_ids.erase(crew_id)

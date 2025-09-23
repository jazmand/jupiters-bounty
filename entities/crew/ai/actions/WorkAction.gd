class_name WorkAction extends UtilityAIAction

@onready var crew_member: CrewMember = owner as CrewMember

func execute() -> void:
	# Skip while following a fixed assignment path (door/furniture waypoints)
	if crew_member.has_method("has_pending_assignment_path") and crew_member.has_pending_assignment_path():
		return
	if crew_member.state == crew_member.STATE.WORK:
		return
		
	crew_member.go_to_work()

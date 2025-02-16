class_name WorkAction extends UtilityAIAction

@onready var crew_member: CrewMember = $"../.."

func execute() -> void:
	print(crew_member.data.name, ": work")
	if crew_member.state == crew_member.STATE.WORK:
		return
		
	crew_member.go_to_work()

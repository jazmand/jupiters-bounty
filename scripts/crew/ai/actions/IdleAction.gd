class_name IdleAction extends UtilityAIAction

@onready var crew_member: CrewMember = $"../.."

@onready var state_manager: StateChart = %CrewStateManager

func execute() -> void:
	print(crew_member.data.name, ": idle")
	if crew_member.state == crew_member.STATE.IDLE:
		return
	state_manager.send_event(&"idle")

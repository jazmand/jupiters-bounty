class_name IdleAction extends UtilityAIAction

@onready var crew_member: CrewMember = owner as CrewMember

@onready var state_manager: StateChart = %CrewStateManager as StateChart

func execute() -> void:
	if crew_member.state == crew_member.STATE.IDLE:
		return
	
	state_manager.send_event(&"idle")

class_name IdleAction extends UtilityAIAction

@onready var crew_member: CrewMember = owner as CrewMember

@onready var state_manager: StateChart = %CrewStateManager as StateChart

func execute() -> void:
	if crew_member.state == crew_member.STATE.IDLE:
		return
	# Don't interrupt an ongoing walk; let navigation finish first
	if crew_member.state == crew_member.STATE.WALK and not crew_member.navigation_agent.is_navigation_finished():
		return
	
	state_manager.send_event(&"idle")

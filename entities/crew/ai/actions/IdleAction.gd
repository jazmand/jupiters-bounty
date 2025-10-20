class_name IdleAction extends UtilityAIAction

@onready var crew_member: Node = owner

@onready var state_manager: StateChart = %CrewStateManager as StateChart

func execute() -> void:
	if crew_member.state == crew_member.STATE.IDLE:
		return
	
	# Don't interrupt crew members who are assigned to furniture and walking to their assignment
	if crew_member._is_on_assignment() and crew_member.state == crew_member.STATE.WALK:
		
		return
	
	# Don't interrupt an ongoing walk; let navigation finish first
	if crew_member.state == crew_member.STATE.WALK and not crew_member.navigation_agent.is_navigation_finished():
		return
	
	state_manager.send_event(&"idle")

class_name CrewInfoPanel
extends PanelContainer

@onready var name_edit = $CrewInfoContainer/HeaderContainer/NameEdit
@onready var close_button = $CrewInfoContainer/HeaderContainer/CloseButton

@onready var info_age = $CrewInfoContainer/InfoContainer/AgeLabel
@onready var info_hometown = $CrewInfoContainer/InfoContainer/HometownLabel

@onready var idle_button = $CrewInfoContainer/ActionContainer/IdleButton
@onready var assign_button = $CrewInfoContainer/ActionContainer/AssignButton

var crew: CrewMember = null

func _ready() -> void:
	hide()
	Global.crew_selected.connect(open)
	close_button.pressed.connect(close)

func display_crew_info(crew_member: CrewMember) -> void:
	idle_button.pressed.connect(start_idling.bind(crew_member))
	assign_button.pressed.connect(start_assigning.bind(crew_member))
	idle_button.disabled = crew_member.animation_state == crew_member.AnimationState.IDLE
	assign_button.disabled = false
	name_edit.text = crew_member.info.name
	info_age.text = "Age: %s" % crew_member.info.age
	info_hometown.text = "Hometown: %s" % crew_member.info.hometown

func reset_panel() -> void:
	if crew == null:
		return
	idle_button.pressed.disconnect(start_idling.bind(crew))
	assign_button.pressed.disconnect(start_assigning.bind(crew))
	crew.state_transitioned.disconnect(update_available_actions)
	crew = null

func open(crew_member: CrewMember) -> void:
	reset_panel()
	crew = crew_member
	crew.state_transitioned.connect(update_available_actions)
	display_crew_info(crew_member)
	show()

func close() -> void:
	hide()
	reset_panel()

func start_idling(crew_member: CrewMember) -> void:
	crew_member.state_manager.send_event(&"idle")
	idle_button.disabled = true
	assign_button.disabled = !no_rooms()
	hide()

func start_assigning(crew_member: CrewMember) -> void:
	Global.crew_assigned.emit(crew_member)
	idle_button.disabled = false
	crew_member.state_manager.send_event(&"assign")
	close()
	
func no_rooms() -> bool:
	return Global.station.rooms.size() == 0

func update_available_actions(state: StringName) -> void:
	match state:
		&"idling":
			idle_button.disabled = true
			assign_button.disabled = !no_rooms()
		_:
			idle_button.disabled = false
			assign_button.disabled = !no_rooms()


func _on_name_edit_text_changed() -> void:
	crew.info.name = name_edit.text

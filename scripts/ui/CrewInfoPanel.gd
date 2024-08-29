class_name CrewInfoPanel extends PanelContainer

@onready var name_edit: TextEdit = $CrewInfoContainer/HeaderContainer/NameEdit
@onready var close_button: Button = $CrewInfoContainer/HeaderContainer/CloseButton

@onready var previous_button: Button = $CrewInfoContainer/PortraitContainer/PreviousCrewButton
@onready var next_button: Button = $CrewInfoContainer/PortraitContainer/NextCrewButton

@onready var info_age: Label = $CrewInfoContainer/InfoContainer/AgeLabel
@onready var info_hometown: Label = $CrewInfoContainer/InfoContainer/HometownLabel

@onready var idle_button: Button = $CrewInfoContainer/ActionContainer/IdleButton
@onready var assign_button: Button = $CrewInfoContainer/ActionContainer/AssignButton

var crew: CrewMember = null

func _ready() -> void:
	hide()
	Global.crew_selected.connect(open)
	close_button.pressed.connect(close)
	previous_button.pressed.connect(cycle_crew_members.bind(-1))
	next_button.pressed.connect(cycle_crew_members.bind(1))

func display_crew_info(crew_member: CrewMember) -> void:
	idle_button.pressed.connect(start_idling)
	assign_button.pressed.connect(start_assigning)
	idle_button.disabled = crew_member.state == crew_member.STATE.IDLE
	assign_button.disabled = false
	name_edit.text = crew_member.data.name
	info_age.text = "Age: %s" % crew_member.data.age
	info_hometown.text = "Hometown: %s" % crew_member.data.hometown

func reset_panel() -> void:
	if crew == null:
		return
	idle_button.pressed.disconnect(start_idling)
	assign_button.pressed.disconnect(start_assigning)
	crew.state_transitioned.disconnect(update_available_actions)
	crew = null

func setup_new_panel(crew_member: CrewMember) -> void:
	crew = crew_member
	crew.state_transitioned.connect(update_available_actions)
	display_crew_info(crew_member)

func open(crew_member: CrewMember) -> void:
	reset_panel()
	setup_new_panel(crew_member)
	show()

func close() -> void:
	hide()
	reset_panel()

func start_idling() -> void:
	crew.state_manager.send_event(&"idle")
	idle_button.disabled = true
	assign_button.disabled = !crew.can_assign()
	hide()

func start_assigning() -> void:
	Global.crew_assigned.emit(crew)
	idle_button.disabled = false
	crew.state_manager.send_event(&"assign")
	close()

func update_available_actions(state: StringName) -> void:
	match state:
		crew.STATE.IDLE:
			idle_button.disabled = true
			assign_button.disabled = !crew.can_assign()
		crew.STATE.WORK:
			idle_button.disabled = false
			assign_button.disabled = true
		_:
			idle_button.disabled = false
			assign_button.disabled = !crew.can_assign()


func _on_name_edit_text_changed() -> void:
	crew.data.name = name_edit.text

func cycle_crew_members(diff: int) -> void:
	var all_crew = Global.station.crew
	var crew_size = all_crew.size()
	var next_idx = all_crew.find(crew) + diff
	var idx = get_cycled_idx(next_idx, crew_size)
	reset_panel()
	setup_new_panel(all_crew[idx])

func get_cycled_idx(next_idx: int, crew_size: int) -> int:
	if next_idx >= crew_size:
		next_idx -= crew_size
	elif next_idx < 0:
		next_idx += crew_size
	return next_idx

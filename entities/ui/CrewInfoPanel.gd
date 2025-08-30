class_name CrewInfoPanel extends PanelContainer

@onready var name_edit: TextEdit = $CrewInfoContainer/HeaderContainer/NameEdit
@onready var close_button: Button = $CrewInfoContainer/HeaderContainer/CloseButton

@onready var previous_button: Button = $CrewInfoContainer/PortraitContainer/PreviousCrewButton
@onready var next_button: Button = $CrewInfoContainer/PortraitContainer/NextCrewButton

@onready var info_age: Label = $CrewInfoContainer/InfoContainer/AgeLabel
@onready var info_hometown: Label = $CrewInfoContainer/InfoContainer/HometownLabel

@onready var status_label: Label = $CrewInfoContainer/ActionContainer/StatusLabel
@onready var assign_button: Button = $CrewInfoContainer/ActionContainer/AssignButton

var crew: CrewMember = null

func _ready() -> void:
	# Enable mouse filtering to consume mouse events and prevent them from reaching game world
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	# CrewInfoPanel should open when entering inspecting_crew state
	previous_button.pressed.connect(cycle_crew_members.bind(-1))
	next_button.pressed.connect(cycle_crew_members.bind(1))

func display_crew_info(crew_member: CrewMember) -> void:
	assign_button.pressed.connect(start_assigning)
	assign_button.disabled = false
	name_edit.text = crew_member.data.name
	info_age.text = "Age: %s" % crew_member.data.age
	info_hometown.text = "Hometown: %s" % crew_member.data.hometown
	update_status_display(crew_member.state)

func reset_panel() -> void:
	if crew == null:
		return
	assign_button.pressed.disconnect(start_assigning)
	crew.state_transitioned.disconnect(update_status_display)
	crew = null

func setup_new_panel(crew_member: CrewMember) -> void:
	crew = crew_member
	crew.state_transitioned.connect(update_status_display)
	display_crew_info(crew_member)

func open(crew_member: CrewMember) -> void:
	reset_panel()
	setup_new_panel(crew_member)
	show()

func close() -> void:
	hide()
	reset_panel()


func start_assigning() -> void:
	# Instead of emitting crew_assigned (which just re-opens the panel),
	# directly activate assignment mode in the GameManager
	var game_manager = get_node("/root/Main/GameManager")
	if game_manager and game_manager.has_method("activate_crew_assignment_mode"):
		game_manager.activate_crew_assignment_mode(crew)
		close()
	else:
		Global.crew_assigned.emit(crew)
		crew.state_manager.send_event(&"assign")
		close()
	
	# Consume the input event to prevent it from bubbling up to global handler
	get_viewport().set_input_as_handled()

func update_status_display(state: StringName) -> void:
	## Update the status label to show crew's current activity
	match state:
		crew.STATE.IDLE:
			status_label.text = "Status: Idle"
			assign_button.disabled = !crew.can_assign()
		crew.STATE.WORK:
			status_label.text = "Status: Working"
			assign_button.disabled = true
		crew.STATE.WALK:
			status_label.text = "Status: Moving"
			assign_button.disabled = !crew.can_assign()
		_:
			status_label.text = "Status: Unknown"
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

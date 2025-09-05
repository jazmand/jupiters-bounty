class_name CrewInfoPanel extends PanelContainer

@onready var name_edit: TextEdit = $CrewInfoContainer/HeaderContainer/NameEdit
@onready var close_button: Button = $CrewInfoContainer/HeaderContainer/CloseButton

@onready var previous_button: Button = $CrewInfoContainer/PortraitContainer/PreviousCrewButton
@onready var next_button: Button = $CrewInfoContainer/PortraitContainer/NextCrewButton

@onready var info_age: Label = $CrewInfoContainer/InfoContainer/AgeLabel
@onready var info_hometown: Label = $CrewInfoContainer/InfoContainer/HometownLabel

@onready var status_label: Label = $CrewInfoContainer/ActionContainer/StatusLabel
@onready var assign_button: Button = $CrewInfoContainer/ActionContainer/AssignButton

@onready var info_container: VBoxContainer = $CrewInfoContainer/InfoContainer

var _stats_built: bool = false
var _vigour_bar: ProgressBar
var _appetite_bar: ProgressBar
var _contentment_bar: ProgressBar

var crew: CrewMember = null

func _ready() -> void:
	# Enable mouse filtering to consume mouse events and prevent them from reaching game world
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	# CrewInfoPanel should open when entering inspecting_crew state
	previous_button.pressed.connect(cycle_crew_members.bind(-1))
	next_button.pressed.connect(cycle_crew_members.bind(1))
	set_process(true)

func display_crew_info(crew_member: CrewMember) -> void:
	assign_button.pressed.connect(start_assigning)
	assign_button.disabled = false
	name_edit.text = crew_member.data.name
	# Build stat rows once, then update values each time
	if not _stats_built:
		_build_stat_rows()
	_update_stat_rows(crew_member)
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
			status_label.text = "Status: Idle (Ready)"
			assign_button.disabled = !crew.can_assign()
		crew.STATE.WORK:
			status_label.text = "Status: Working"
			assign_button.disabled = true
		crew.STATE.WALK:
			status_label.text = "Status: Moving"
			assign_button.disabled = !crew.can_assign()
		crew.STATE.REST:
			if crew.data.vigour < 10:
				status_label.text = "Status: Resting (Recovering Energy)"
			else:
				status_label.text = "Status: Resting (Fully Recovered)"
			assign_button.disabled = true
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

func _process(_delta: float) -> void:
	# Live-update stat bars while panel is visible
	if visible and crew != null and _stats_built:
		_update_stat_rows(crew)

func _build_stat_rows() -> void:
	# Hide legacy labels used for age/hometown
	info_age.hide()
	info_hometown.hide()

	_vigour_bar = _make_stat_row("Vigour", Color(0.35, 0.8, 0.45))       # greenish
	_appetite_bar = _make_stat_row("Appetite", Color(0.95, 0.6, 0.2))    # orange
	_contentment_bar = _make_stat_row("Contentment", Color(0.45, 0.6, 0.95)) # blueish

	_stats_built = true

func _update_stat_rows(crew_member: CrewMember) -> void:
	if not _stats_built:
		return
	_vigour_bar.value = int(crew_member.data.vigour)
	_appetite_bar.value = int(crew_member.data.appetite)
	_contentment_bar.value = int(crew_member.data.contentment)

func _make_stat_row(label_text: String, fill_color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(140, 0)
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.max_value = 10
	bar.step = 1
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	info_container.add_child(row)
	return bar

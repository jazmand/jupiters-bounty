class_name FurnitureInfoPanel extends PanelContainer

signal crew_assigned(furniture: Furniture, crew_member: Node)
signal crew_unassigned(furniture: Furniture, crew_member: Node)
signal panel_closed

@onready var furniture_name_label: Label = $VBoxContainer/HeaderContainer/FurnitureName
@onready var close_button: Button = $VBoxContainer/HeaderContainer/CloseButton
@onready var furniture_info_container: VBoxContainer = $VBoxContainer/FurnitureInfoContainer
@onready var crew_assignment_container: VBoxContainer = $VBoxContainer/CrewAssignmentContainer
# Available crew list removed - no longer needed
@onready var assigned_crew_list: VBoxContainer = $VBoxContainer/CrewAssignmentContainer/AssignedCrewContainer/AssignedCrewList

var current_furniture: Furniture = null
var current_selected_crew: Node = null

func _ready() -> void:
	# Enable input processing to detect clicks outside
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func show_furniture_info(furniture: Furniture, selected_crew: Node = null) -> void:
	"""Show the panel with furniture information and crew assignment options"""
	current_furniture = furniture
	current_selected_crew = selected_crew
	_update_furniture_info()
	_update_crew_lists()
	show()

func _update_furniture_info() -> void:
	"""Update the furniture information display"""
	if not current_furniture:
		return
	
	var info = current_furniture.get_furniture_info()
	furniture_name_label.text = info.name
	
	# Clear existing info
	for child in furniture_info_container.get_children():
		child.queue_free()
	
	# Add furniture details (simplified)
	var details = [
		"Price: " + str(info.price),
		"Power: " + str(info.power_consumption)
	]
	
	for detail in details:
		var label = Label.new()
		label.text = detail
		furniture_info_container.add_child(label)

func _update_crew_lists() -> void:
	"""Update the crew slots display"""
	if not current_furniture:
		return
	
	# Clear existing lists
	for child in assigned_crew_list.get_children():
		child.queue_free()
	
	# Create crew slot blocks
	var assigned_crew = current_furniture.get_assigned_crew()
	var total_slots = current_furniture.max_crew_capacity
	
	# Create a container for the slot blocks
	var slots_container = HBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 10)
	assigned_crew_list.add_child(slots_container)
	
	# Create blocks for each potential slot
	for i in range(total_slots):
		var slot_block = _create_crew_slot_block(i, assigned_crew)
		slots_container.add_child(slot_block)
	
	# Show assignment mode indicator if we have a selected crew member
	if current_selected_crew:
		var mode_label = Label.new()
		mode_label.text = "ASSIGNMENT MODE: Click furniture to assign " + _get_crew_name(current_selected_crew)
		mode_label.add_theme_color_override("font_color", Color.YELLOW)
		mode_label.add_theme_font_size_override("font_size", 14)
		assigned_crew_list.add_child(mode_label)

func _get_crew_name(crew_member: Node) -> String:
	"""Get the display name for a crew member"""
	# Use the same approach that works in GameManager
	if crew_member.data and crew_member.data.name:
		return crew_member.data.name
	
	# Fallback to other methods
	if crew_member.has_method("get_name"):
		return crew_member.get_name()
	elif crew_member.name:
		return crew_member.name
	else:
		return "Unknown"

# Available crew function removed - no longer needed

func _create_crew_slot_block(slot_index: int, assigned_crew: Array[Node]) -> VBoxContainer:
	"""Create a visual block representing a crew slot"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	
	# Create the slot block background
	var slot_panel = PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(80, 60)
	
	# Style the slot block
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_box.border_color = Color(0.5, 0.5, 0.5, 1.0)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	slot_panel.add_theme_stylebox_override("panel", style_box)
	
	# Add content to the slot
	var content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 2)
	slot_panel.add_child(content_container)
	
	if slot_index < assigned_crew.size():
		# Slot is filled - show crew member name and unassign button
		var crew_member = assigned_crew[slot_index]
		var name_label = Label.new()
		name_label.text = _get_crew_name(crew_member)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_container.add_child(name_label)
		
		# Unassign button (small X button)
		var unassign_button = Button.new()
		unassign_button.text = "×"
		unassign_button.custom_minimum_size = Vector2(20, 20)
		unassign_button.pressed.connect(_on_unassign_crew_pressed.bind(crew_member))
		unassign_button.add_theme_font_size_override("font_size", 16)
		content_container.add_child(unassign_button)
	else:
		# Slot is empty - show empty indicator
		var empty_label = Label.new()
		empty_label.text = "Empty"
		empty_label.add_theme_color_override("font_color", Color.GRAY)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_container.add_child(empty_label)
	
	container.add_child(slot_panel)
	return container

# Crew assignment is now handled directly in GameManager, not through this panel

func _on_unassign_crew_pressed(crew_member: Node) -> void:
	"""Handle crew unassignment from furniture"""
	if current_furniture:
		var success = current_furniture.unassign_crew(crew_member)
		if success:
			emit_signal("crew_unassigned", current_furniture, crew_member)
			_update_crew_lists()
		else:
			print("Failed to unassign crew member from furniture")

func _on_close_button_pressed() -> void:
	"""Handle close button press"""
	hide_panel()
	emit_signal("panel_closed")

func hide_panel() -> void:
	"""Hide the panel and clear current furniture"""
	current_furniture = null
	hide()

func _gui_input(event: InputEvent) -> void:
	"""Handle input events to close panel when clicking outside"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if click is outside the panel content
		var panel_rect = get_rect()
		var click_pos = event.position
		
		if not panel_rect.has_point(click_pos):
			hide_panel()
			get_viewport().set_input_as_handled()

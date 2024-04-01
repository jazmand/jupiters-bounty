class_name CrewGUI
extends Control

@onready var crew: CrewMember = get_parent()
@onready var idle_button: Button = $PanelContainer/VBoxContainer/IdleButton
@onready var assign_button: Button = $PanelContainer/VBoxContainer/AssignButton

func _ready():
	idle_button.disabled = true
	assign_button.pressed.connect(assign_button_pressed)
	idle_button.pressed.connect(idle_button_pressed)
	hide()

func assign_button_pressed():
	Global.crew_assign_crew_selected.emit(crew)
	idle_button.disabled = false
	hide()

func idle_button_pressed():
	crew.state_manager.send_event("idle")
	idle_button.disabled = true
	hide()

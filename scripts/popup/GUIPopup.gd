# GUIPopup.gd

class_name GUIPopup
extends Panel

@onready var label: Label = $Label
@onready var yes: Button = $YesButton
@onready var no: Button = $NoButton

func set_visibility(visibility: bool) -> GUIPopup:
	visible = visibility
	return self

func set_text(text: String) -> GUIPopup:
	label.text = text
	return self
	
func connect_yes(f: Callable) -> GUIPopup:
	yes.pressed.connect(f)
	return self

func connect_no(f: Callable) -> GUIPopup:
	no.pressed.connect(f)
	return self

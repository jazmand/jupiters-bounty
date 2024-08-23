# GUIPopup.gd

class_name GUIPopup
extends Panel

@onready var title: Label = $Title
@onready var content: RichTextLabel = $Content
@onready var yes: Button = $YesButton
@onready var no: Button = $NoButton

func set_visibility(visibility: bool) -> GUIPopup:
	visible = visibility
	return self

func set_title(text: String) -> GUIPopup:
	title.text = text
	return self

func set_content(text: String) -> GUIPopup:
	content.text = text
	return self

func set_yes_text(text: String) -> GUIPopup:
	yes.text = text
	return self

func set_no_text(text: String) -> GUIPopup:
	no.text = text
	return self

func connect_yes(f: Callable) -> GUIPopup:
	yes.pressed.connect(f)
	return self

func connect_no(f: Callable) -> GUIPopup:
	no.pressed.connect(f)
	return self

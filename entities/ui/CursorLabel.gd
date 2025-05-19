class_name CursorLabel extends Label

func _ready():
	hide()
	Global.update_cursor_label.connect(_on_update_cursor_label)
	Global.hide_cursor_label.connect(_on_hide_cursor_label)

func _on_update_cursor_label(new_text: String, new_position: Vector2) -> void:
	update_text(new_text)
	update_position(new_position)
	show()

func _on_hide_cursor_label() -> void:
	hide()

func update_position(global_mouse_position: Vector2) -> void:
	position = global_mouse_position + Vector2(20, -20)

func update_text(updated_text: String) -> void:
	self.text = updated_text

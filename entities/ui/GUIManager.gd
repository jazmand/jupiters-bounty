class_name GUIManager extends Control

const POPUP_SCENE: PackedScene = preload("res://entities/ui/popup/popup.tscn")

func new_popup(default_visible: bool, accept_function: Callable, decline_function: Callable) -> GUIPopup:
	var popup: GUIPopup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.set_visibility(default_visible).connect_yes(accept_function).connect_no(decline_function)
	return popup

func _on_add_crew_pressed() -> void: # TEMPORARY
	Events.gui_add_crew_pressed.emit()

# --- Lightweight room confirmation tooltip ---

var _room_confirm_panel: PanelContainer = null
var _rc_cost_label: Label
var _rc_size_label: Label
var _rc_doors_label: Label
var _rc_confirm_btn: Button
var _rc_cancel_btn: Button
var _rc_accept: Callable = func(): pass
var _rc_decline: Callable = func(): pass

func show_room_confirm_tooltip(metrics: Dictionary, screen_pos: Vector2, accept_fn: Callable, decline_fn: Callable) -> void:
	_rc_accept = accept_fn
	_rc_decline = decline_fn
	_ensure_room_confirm_panel()
	_update_room_confirm_metrics(metrics)
	_position_panel_on_screen(screen_pos)
	_room_confirm_panel.show()
	# Raise input focus so buttons receive Enter/Space keys too
	_room_confirm_panel.grab_focus()

func update_room_confirm_tooltip(metrics: Dictionary, screen_pos: Vector2) -> void:
	if _room_confirm_panel == null:
		return
	_update_room_confirm_metrics(metrics)
	_position_panel_on_screen(screen_pos)

func hide_room_confirm_tooltip() -> void:
	if _room_confirm_panel:
		_room_confirm_panel.hide()

func _ensure_room_confirm_panel() -> void:
	if _room_confirm_panel:
		return
	var panel := PanelContainer.new()
	panel.name = "RoomConfirmTooltip"
	panel.visible = false
	# Allow buttons inside to receive clicks; buttons themselves will STOP events
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	# Keep this panel above other UI
	panel.z_index = 1000
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.add_theme_constant_override("margin_top", 12)
	vb.add_theme_constant_override("margin_bottom", 12)
	vb.add_theme_constant_override("margin_left", 16)
	vb.add_theme_constant_override("margin_right", 16)
	panel.add_child(vb)

	_rc_size_label = Label.new()
	_rc_cost_label = Label.new()
	_rc_doors_label = Label.new()
	_rc_size_label.add_theme_font_size_override("font_size", 12)
	_rc_cost_label.add_theme_font_size_override("font_size", 12)
	_rc_doors_label.add_theme_font_size_override("font_size", 12)
	vb.add_child(_rc_size_label)
	vb.add_child(_rc_cost_label)
	vb.add_child(_rc_doors_label)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)

	_rc_confirm_btn = Button.new()
	_rc_confirm_btn.text = "Confirm"
	_rc_confirm_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_rc_confirm_btn.connect("pressed", Callable(self, "_on_confirm_pressed"))
	hb.add_child(_rc_confirm_btn)

	_rc_cancel_btn = Button.new()
	_rc_cancel_btn.text = "Cancel"
	_rc_cancel_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_rc_cancel_btn.connect("pressed", Callable(self, "_on_cancel_pressed"))
	hb.add_child(_rc_cancel_btn)

	add_child(panel)
	_room_confirm_panel = panel

func _on_confirm_pressed() -> void:
	if _rc_confirm_btn and not _rc_confirm_btn.disabled and _rc_accept:
		_rc_accept.call()

func _on_cancel_pressed() -> void:
	if _rc_decline:
		_rc_decline.call()

func _update_room_confirm_metrics(metrics: Dictionary) -> void:
	# metrics: {width, height, cost, doors, max_doors}
	var width := int(metrics.get("width", 0))
	var height := int(metrics.get("height", 0))
	var cost := int(metrics.get("cost", 0))
	var doors := int(metrics.get("doors", 0))
	var max_doors := int(metrics.get("max_doors", 0))
	_rc_size_label.text = "Size: %dx%d" % [width, height]
	_rc_cost_label.text = "Cost: %d" % cost
	if doors <= 0:
		_rc_doors_label.text = "Door required"
		_rc_doors_label.add_theme_color_override("font_color", Color.RED)
		_rc_confirm_btn.disabled = true
	else:
		_rc_doors_label.text = "Doors: %d/%d" % [doors, max_doors]
		_rc_doors_label.add_theme_color_override("font_color", Color.WHITE)
		_rc_confirm_btn.disabled = false

func _position_panel_on_screen(screen_pos: Vector2) -> void:
	# Offset further from cursor to avoid overlap
	var pos := screen_pos + Vector2(32, -32)
	# Clamp in viewport bounds and set as global UI position
	var vp := get_viewport_rect().size
	var size := _room_confirm_panel.size
	pos.x = clamp(pos.x, 8.0, max(8.0, vp.x - size.x - 8.0))
	pos.y = clamp(pos.y, 8.0, max(8.0, vp.y - size.y - 8.0))
	_room_confirm_panel.global_position = pos

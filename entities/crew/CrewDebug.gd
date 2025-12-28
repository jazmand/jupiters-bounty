class_name CrewDebug
extends Node

# Handles per-crew assignment debug overlay drawing.

var debug_assignment_flow: bool = false
var assign_debug_enabled: bool = false
var nav_grid = null
var _debug_canvas: Node2D = null
var _debug_draw_node: Node2D = null
var _debug_flow_field = null
var _assignment_target_tile: Vector2i = Vector2i.ZERO

func initialize(params: Dictionary) -> void:
	debug_assignment_flow = params.get("debug_assignment_flow", false)
	assign_debug_enabled = params.get("assign_debug_enabled", false)
	nav_grid = params.get("nav_grid", null)

func set_debug_field(field) -> void:
	_debug_flow_field = field
	if assign_debug_enabled and debug_assignment_flow:
		_ensure_debug_canvas()

func set_assignment_target(tile: Vector2i) -> void:
	_assignment_target_tile = tile

func teardown() -> void:
	if _debug_canvas:
		_debug_canvas.queue_free()
		_debug_canvas = null
		_debug_draw_node = null

func _ensure_debug_canvas() -> void:
	if _debug_canvas:
		return
	var gm := get_tree().get_root().get_node_or_null("Main/GameManager")
	_debug_canvas = Node2D.new()
	_debug_canvas.name = "AssignmentDebug2D"
	_debug_canvas.top_level = true
	if gm:
		gm.add_child(_debug_canvas)
	else:
		get_tree().root.add_child(_debug_canvas)
	_debug_draw_node = _debug_canvas
	_debug_draw_node.draw.connect(_on_assignment_debug_draw)
	var redraw_timer := Timer.new()
	redraw_timer.name = "DebugRedrawTimer"
	redraw_timer.wait_time = 0.2
	redraw_timer.autostart = true
	redraw_timer.timeout.connect(func(): if _debug_draw_node: _debug_draw_node.queue_redraw())
	_debug_canvas.add_child(redraw_timer)

func _on_assignment_debug_draw() -> void:
	if not assign_debug_enabled or not debug_assignment_flow or not _debug_draw_node:
		return
	if _assignment_target_tile == Vector2i.ZERO:
		return
	if nav_grid == null:
		return
	var beacon_world: Vector2 = nav_grid.tile_center_world(_assignment_target_tile)
	var p := _debug_draw_node.to_local(beacon_world)
	_debug_draw_node.draw_circle(p, 8, Color.GREEN)
	var font := ThemeDB.fallback_font
	if font:
		_debug_draw_node.draw_string(font, p + Vector2(10, -10), "Beacon", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.GREEN)
	if _debug_flow_field != null and _debug_flow_field.distance:
		for tile_key in _debug_flow_field.distance.keys():
			var t: Vector2i = tile_key
			var world_pos: Vector2 = nav_grid.tile_center_world(t)
			var lp := _debug_draw_node.to_local(world_pos)
			var d_val: int = int(_debug_flow_field.distance[tile_key])
			var c := Color(0.2, 1.0, 0.2, 0.95)
			if font:
				_debug_draw_node.draw_string(font, lp + Vector2(-14, 10), str(d_val), HORIZONTAL_ALIGNMENT_CENTER, -1, 26, c)

extends Control
## Production overview panel toggled by F1. Shows all player production buildings,
## their current production status, and queue contents. Click a row to center camera.

var _stage: Node = null
var _visible_tab: bool = false
var _time: float = 0.0

# Cached building list (refreshed every frame when visible)
var _buildings: Array = []
const ROW_HEIGHT: float = 60.0
const PANEL_MARGIN_X: float = 80.0
const PANEL_TOP: float = 80.0

func setup(stage: Node) -> void:
	_stage = stage
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func toggle() -> void:
	_visible_tab = not _visible_tab
	visible = _visible_tab
	mouse_filter = Control.MOUSE_FILTER_STOP if _visible_tab else Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	if _visible_tab:
		_refresh_buildings()
		queue_redraw()

func _refresh_buildings() -> void:
	_buildings.clear()
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if not "faction_id" in building or building.faction_id != 0:
			continue
		if not "is_production" in building or not building.is_production:
			continue
		if not building.has_method("is_complete") or not building.is_complete():
			continue
		_buildings.append(building)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			toggle()
			get_viewport().set_input_as_handled()
			return
		if _visible_tab and event.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()
			return

	if _visible_tab and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp: Vector2 = get_viewport_rect().size
		var panel_w: float = vp.x - PANEL_MARGIN_X * 2.0
		var click_pos: Vector2 = event.position
		# Check if click is in a building row
		for i in range(_buildings.size()):
			var row_rect: Rect2 = _get_row_rect(vp, i)
			if row_rect.has_point(click_pos):
				var building: Node2D = _buildings[i]
				if is_instance_valid(building) and _stage and "_camera" in _stage:
					var cam: Camera2D = _stage._camera
					if cam and cam.has_method("focus_position"):
						cam.focus_position(building.global_position)
				toggle()  # Close after clicking
				get_viewport().set_input_as_handled()
				return

func _get_row_rect(vp: Vector2, idx: int) -> Rect2:
	var panel_w: float = vp.x - PANEL_MARGIN_X * 2.0
	var row_y: float = PANEL_TOP + 50.0 + idx * ROW_HEIGHT
	return Rect2(PANEL_MARGIN_X, row_y, panel_w, ROW_HEIGHT - 4.0)

func _draw() -> void:
	if not _visible_tab:
		return
	var vp: Vector2 = get_viewport_rect().size
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()

	# Full-screen dark backdrop
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.02, 0.05, 0.02, 0.85))

	var panel_w: float = vp.x - PANEL_MARGIN_X * 2.0

	# Title
	var title: String = "PRODUCTION OVERVIEW"
	var ts: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_HEADER)
	draw_string(font, Vector2((vp.x - ts.x) * 0.5, PANEL_TOP + 10), title, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_HEADER, Color(0.3, 0.9, 0.4))

	# Separator line
	draw_line(Vector2(PANEL_MARGIN_X, PANEL_TOP + 20), Vector2(vp.x - PANEL_MARGIN_X, PANEL_TOP + 20), Color(0.3, 0.7, 0.4, 0.3), 1.0)

	# Column headers
	var header_y: float = PANEL_TOP + 42
	draw_string(mono, Vector2(PANEL_MARGIN_X + 10, header_y), "BUILDING", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_DIM)
	draw_string(mono, Vector2(PANEL_MARGIN_X + 200, header_y), "STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_DIM)
	draw_string(mono, Vector2(PANEL_MARGIN_X + 450, header_y), "QUEUE", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_DIM)

	# Building rows
	var producing_count: int = 0
	var idle_count: int = 0
	var mouse_pos: Vector2 = get_local_mouse_position()

	for i in range(_buildings.size()):
		var building: Node2D = _buildings[i]
		if not is_instance_valid(building):
			continue
		var row_rect: Rect2 = _get_row_rect(vp, i)
		var hovered: bool = row_rect.has_point(mouse_pos)

		# Row background
		var row_bg: Color = Color(0.08, 0.15, 0.08, 0.6) if hovered else Color(0.04, 0.08, 0.04, 0.4)
		draw_rect(row_rect, row_bg)
		if hovered:
			draw_rect(row_rect, Color(0.3, 0.8, 0.4, 0.3), false, 1.0)

		var row_y_text: float = row_rect.position.y + 24.0
		var rx: float = row_rect.position.x + 10.0

		# Building type indicator (colored dot)
		var building_color: Color = _get_building_type_color(building.building_type)
		draw_circle(Vector2(rx + 5, row_y_text - 5), 5.0, building_color)
		rx += 18.0

		# Building name
		var bname: String = BuildingStats.get_building_name(building.building_type)
		draw_string(font, Vector2(rx, row_y_text), bname, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, UIConstants.TEXT_BRIGHT)

		# Status section
		var status_x: float = row_rect.position.x + 200.0
		var queue_size: int = building.get_queue_size()

		if queue_size > 0:
			producing_count += 1
			# Currently producing unit name
			var cur_unit: int = building._production_queue[0]
			var cur_name: String = UnitStats.get_unit_name(cur_unit)
			draw_string(font, Vector2(status_x, row_y_text), cur_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(0.3, 0.7, 1.0))

			# Progress bar
			var bar_x: float = status_x
			var bar_y: float = row_y_text + 8.0
			var bar_w: float = 180.0
			var bar_h: float = 6.0
			var pct: float = building.get_production_progress()
			draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.7))
			draw_rect(Rect2(bar_x, bar_y, bar_w * pct, bar_h), Color(0.3, 0.7, 1.0, 0.8))
			# Percentage text
			draw_string(mono, Vector2(bar_x + bar_w + 6, bar_y + 6), "%d%%" % int(pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.3, 0.7, 1.0, 0.7))
		else:
			idle_count += 1
			draw_string(font, Vector2(status_x, row_y_text), "Idle", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, UIConstants.TEXT_DIM)

		# Queue section (small colored circles for queued units)
		var queue_x: float = row_rect.position.x + 450.0
		if queue_size > 0:
			for qi in range(mini(queue_size, 6)):
				var qut: int = building._production_queue[qi]
				var q_color: Color = Color(0.3, 0.7, 1.0, 0.7) if qi == 0 else Color(0.5, 0.6, 0.7, 0.5)
				draw_circle(Vector2(queue_x + 8, row_y_text - 4), 7.0, Color(q_color.r, q_color.g, q_color.b, 0.2))
				draw_arc(Vector2(queue_x + 8, row_y_text - 4), 7.0, 0, TAU, 12, q_color, 1.0)
				var q_initial: String = UnitStats.get_unit_name(qut).substr(0, 1)
				draw_string(mono, Vector2(queue_x + 4, row_y_text), q_initial, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, q_color)
				queue_x += 18.0
			if queue_size > 6:
				draw_string(mono, Vector2(queue_x + 4, row_y_text), "+%d" % (queue_size - 6), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)

	# Bottom summary
	var summary_y: float = PANEL_TOP + 50.0 + _buildings.size() * ROW_HEIGHT + 20.0
	draw_line(Vector2(PANEL_MARGIN_X, summary_y - 8), Vector2(vp.x - PANEL_MARGIN_X, summary_y - 8), Color(0.3, 0.7, 0.4, 0.3), 1.0)
	var summary_text: String = "Total: %d buildings, %d producing, %d idle" % [_buildings.size(), producing_count, idle_count]
	draw_string(font, Vector2(PANEL_MARGIN_X + 10, summary_y + 10), summary_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, UIConstants.TEXT_NORMAL)

	# Hint text at bottom
	var hint: String = "F1 or ESC to close  |  Click a row to center camera"
	var hint_size: Vector2 = mono.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
	draw_string(mono, Vector2((vp.x - hint_size.x) * 0.5, vp.y - 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_DIM)

	# Empty state
	if _buildings.is_empty():
		var empty_text: String = "No completed production buildings"
		var empty_size: Vector2 = font.get_string_size(empty_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
		draw_string(font, Vector2((vp.x - empty_size.x) * 0.5, vp.y * 0.5), empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, UIConstants.TEXT_DIM)

func _get_building_type_color(btype: int) -> Color:
	match btype:
		BuildingStats.BuildingType.SPAWNING_POOL:
			return Color(0.3, 0.8, 0.5)
		BuildingStats.BuildingType.EVOLUTION_CHAMBER:
			return Color(0.5, 0.4, 0.9)
		_:
			return Color(0.5, 0.5, 0.5)

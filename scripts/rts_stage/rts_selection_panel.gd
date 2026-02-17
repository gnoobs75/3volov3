extends Control
## Selection panel: shows unit/building details in bottom-left, control groups bar at bottom-center.
## All procedural _draw() matching UIConstants style with bioluminescent organic aesthetics.

var _selection_mgr: Node
var _time: float = 0.0
var _hovered_unit_idx: int = -1
var _last_click_time: float = 0.0
var _last_click_group: int = -1

const PANEL_W: float = 320.0
const PANEL_H: float = 120.0
const GRID_COLS: int = 8
const GRID_ROWS: int = 3
const ICON_SIZE: float = 28.0
const ICON_PAD: float = 2.0

var _font: Font
var _mono: Font

func setup(selection_mgr: Node) -> void:
	_selection_mgr = selection_mgr
	mouse_filter = MOUSE_FILTER_PASS

func _ready() -> void:
	_font = UIConstants.get_display_font()
	_mono = UIConstants.get_mono_font()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var panel_x: float = 10.0
	var panel_y: float = vp.y - PANEL_H - 10.0
	_draw_membrane_panel(Vector2(panel_x, panel_y), Vector2(PANEL_W, PANEL_H))
	if not _selection_mgr:
		return
	var selected: Array = _selection_mgr.selected_units
	if selected.is_empty():
		_draw_no_selection(panel_x, panel_y)
	elif selected.size() == 1:
		var sel = selected[0]
		if is_instance_valid(sel) and sel.is_in_group("rts_buildings"):
			_draw_building_info(sel, panel_x, panel_y)
		else:
			_draw_single_unit(sel, panel_x, panel_y)
	else:
		_draw_multi_selection(selected, panel_x, panel_y)

	# Control groups bar at bottom-center
	_draw_control_groups(vp)

# === MEMBRANE PANEL ===

func _draw_membrane_panel(pos: Vector2, size: Vector2) -> void:
	# Semi-transparent organic background
	draw_rect(Rect2(pos, size), Color(0.04, 0.06, 0.12, 0.88))

	# Wobbly sine-wave border with bioluminescent glow
	var border_color: Color = Color(0.25, 0.65, 0.85, 0.6)
	var glow_color: Color = Color(0.3, 0.7, 1.0, 0.12)
	var amplitude: float = 2.0
	var segments: int = 40

	# Top edge
	for i in range(segments):
		var t0: float = float(i) / float(segments)
		var t1: float = float(i + 1) / float(segments)
		var x0: float = pos.x + size.x * t0
		var x1: float = pos.x + size.x * t1
		var y0: float = pos.y + sin(_time * 2.0 + t0 * 8.0) * amplitude
		var y1: float = pos.y + sin(_time * 2.0 + t1 * 8.0) * amplitude
		draw_line(Vector2(x0, y0), Vector2(x1, y1), border_color, 1.5)
	# Bottom edge
	for i in range(segments):
		var t0: float = float(i) / float(segments)
		var t1: float = float(i + 1) / float(segments)
		var x0: float = pos.x + size.x * t0
		var x1: float = pos.x + size.x * t1
		var y0: float = pos.y + size.y + sin(_time * 2.0 + t0 * 8.0 + 2.0) * amplitude
		var y1: float = pos.y + size.y + sin(_time * 2.0 + t1 * 8.0 + 2.0) * amplitude
		draw_line(Vector2(x0, y0), Vector2(x1, y1), border_color, 1.5)
	# Left edge
	for i in range(int(segments * 0.4)):
		var t0: float = float(i) / float(int(segments * 0.4))
		var t1: float = float(i + 1) / float(int(segments * 0.4))
		var y0: float = pos.y + size.y * t0
		var y1: float = pos.y + size.y * t1
		var x0: float = pos.x + sin(_time * 1.8 + t0 * 6.0 + 1.0) * amplitude
		var x1: float = pos.x + sin(_time * 1.8 + t1 * 6.0 + 1.0) * amplitude
		draw_line(Vector2(x0, y0), Vector2(x1, y1), border_color, 1.5)
	# Right edge
	for i in range(int(segments * 0.4)):
		var t0: float = float(i) / float(int(segments * 0.4))
		var t1: float = float(i + 1) / float(int(segments * 0.4))
		var y0: float = pos.y + size.y * t0
		var y1: float = pos.y + size.y * t1
		var x0: float = pos.x + size.x + sin(_time * 1.8 + t0 * 6.0 + 3.0) * amplitude
		var x1: float = pos.x + size.x + sin(_time * 1.8 + t1 * 6.0 + 3.0) * amplitude
		draw_line(Vector2(x0, y0), Vector2(x1, y1), border_color, 1.5)

	# Corner glow spots
	var corner_r: float = 8.0
	draw_circle(pos, corner_r, glow_color)
	draw_circle(pos + Vector2(size.x, 0), corner_r, glow_color)
	draw_circle(pos + Vector2(0, size.y), corner_r, glow_color)
	draw_circle(pos + size, corner_r, glow_color)

# === SINGLE UNIT ===

func _draw_single_unit(unit: Node2D, x: float, y: float) -> void:
	if not is_instance_valid(unit):
		return

	# Portrait area (colored circle with unit type initial)
	var portrait_cx: float = x + 36.0
	var portrait_cy: float = y + 50.0
	var portrait_r: float = 24.0

	var faction_color: Color = FactionData.get_faction_color(unit.faction_id if "faction_id" in unit else 0)
	# Glow behind portrait
	draw_circle(Vector2(portrait_cx, portrait_cy), portrait_r + 4.0, Color(faction_color.r, faction_color.g, faction_color.b, 0.15))
	# Portrait circle
	draw_circle(Vector2(portrait_cx, portrait_cy), portrait_r, Color(faction_color.r * 0.5, faction_color.g * 0.5, faction_color.b * 0.5, 0.9))
	draw_arc(Vector2(portrait_cx, portrait_cy), portrait_r, 0, TAU, 24, faction_color, 2.0)

	# Unit initial inside portrait
	var uname: String = ""
	if "unit_type" in unit:
		uname = UnitStats.get_unit_name(unit.unit_type)
	var initial: String = uname.substr(0, 1) if uname.length() > 0 else "?"
	draw_string(_font, Vector2(portrait_cx - 7, portrait_cy + 8), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_HEADER, UIConstants.TEXT_BRIGHT)

	# Unit name
	var name_x: float = x + 70.0
	draw_string(_font, Vector2(name_x, y + 22), uname, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, UIConstants.TEXT_BRIGHT)

	# HP bar (organic gradient)
	if "health" in unit and "max_health" in unit:
		var hp_bar_x: float = name_x
		var hp_bar_y: float = y + 30.0
		var hp_bar_w: float = 180.0
		var hp_bar_h: float = 10.0
		var hp_fill: float = clampf(unit.health / unit.max_health, 0.0, 1.0)

		# Background
		draw_rect(Rect2(hp_bar_x, hp_bar_y, hp_bar_w, hp_bar_h), Color(0.08, 0.08, 0.08, 0.8))
		# Fill with organic gradient (top lighter, bottom darker)
		var top_color: Color = Color(0.3, 0.95, 0.5) if hp_fill > 0.5 else Color(0.95, 0.85, 0.2) if hp_fill > 0.25 else Color(0.95, 0.3, 0.2)
		var bot_color: Color = top_color.darkened(0.4)
		var fill_w: float = hp_bar_w * hp_fill
		# Draw two halves for gradient effect
		draw_rect(Rect2(hp_bar_x, hp_bar_y, fill_w, hp_bar_h * 0.5), top_color)
		draw_rect(Rect2(hp_bar_x, hp_bar_y + hp_bar_h * 0.5, fill_w, hp_bar_h * 0.5), bot_color)
		# HP text
		var hp_text: String = "%d/%d" % [int(unit.health), int(unit.max_health)]
		draw_string(_mono, Vector2(hp_bar_x + hp_bar_w + 4, hp_bar_y + 9), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)

	# Stats row: ATK / ARM / SPD
	var stats_y: float = y + 56.0
	var stat_x: float = name_x
	if "damage" in unit:
		draw_string(_mono, Vector2(stat_x, stats_y), "ATK", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
		draw_string(_mono, Vector2(stat_x + 24, stats_y), str(int(unit.damage)), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.STAT_YELLOW)
		stat_x += 58.0
	if "armor" in unit:
		draw_string(_mono, Vector2(stat_x, stats_y), "ARM", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
		draw_string(_mono, Vector2(stat_x + 24, stats_y), str(int(unit.armor)), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.7, 0.7, 0.8))
		stat_x += 58.0
	if "speed" in unit:
		draw_string(_mono, Vector2(stat_x, stats_y), "SPD", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
		draw_string(_mono, Vector2(stat_x + 24, stats_y), str(int(unit.speed)), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.5, 0.8, 1.0))

	# Current order icon
	var order_y: float = y + 72.0
	if "state" in unit:
		var order_text: String = _get_state_name(unit.state)
		var order_color: Color = _get_state_color(unit.state)
		draw_circle(Vector2(name_x + 4, order_y - 3), 3.0, Color(order_color.r, order_color.g, order_color.b, 0.4))
		draw_string(_mono, Vector2(name_x + 12, order_y), order_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, order_color)

	# Veterancy stars
	if "_vet_level" in unit and unit._vet_level > 0:
		var star_x: float = name_x + 80.0
		for i in range(unit._vet_level):
			var star_center: Vector2 = Vector2(star_x + float(i) * 12.0, order_y - 3.0)
			_draw_star(star_center, 4.0, 5, Color(1.0, 0.85, 0.2, 0.9))

	# Ability cooldown indicator (radial sweep)
	if "_ability_cooldown_max" in unit and unit._ability_cooldown_max > 0:
		var ability_cx: float = x + 36.0
		var ability_cy: float = y + 90.0
		var ability_r: float = 10.0
		var cd_progress: float = 0.0
		if "_ability_cooldown_timer" in unit and unit._ability_cooldown_max > 0:
			cd_progress = 1.0 - (unit._ability_cooldown_timer / unit._ability_cooldown_max)
		# Background
		draw_circle(Vector2(ability_cx, ability_cy), ability_r, Color(0.1, 0.1, 0.15, 0.7))
		# Radial sweep
		if cd_progress > 0.01 and cd_progress < 1.0:
			var sweep_angle: float = cd_progress * TAU
			draw_arc(Vector2(ability_cx, ability_cy), ability_r - 2.0, -PI * 0.5, -PI * 0.5 + sweep_angle, 16, Color(0.3, 0.8, 1.0, 0.7), 3.0)
		elif cd_progress >= 1.0:
			# Ready - pulsing glow
			var pulse: float = 0.5 + 0.3 * sin(_time * 4.0)
			draw_arc(Vector2(ability_cx, ability_cy), ability_r, 0, TAU, 16, Color(0.3, 1.0, 0.5, pulse), 2.0)
		# Ability name
		var ability_name: String = ""
		if "unit_type" in unit:
			ability_name = UnitStats.get_ability_name(unit.unit_type)
		if ability_name.length() > 0:
			draw_string(_mono, Vector2(ability_cx + ability_r + 4, ability_cy + 4), ability_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)

# === MULTI SELECTION ===

func _draw_multi_selection(units: Array, x: float, y: float) -> void:
	# Header
	var valid_count: int = 0
	for u in units:
		if is_instance_valid(u):
			valid_count += 1
	draw_string(_font, Vector2(x + 8, y + 18), "%d units selected" % valid_count, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_BRIGHT)

	# 8x3 grid of unit icons
	var grid_x: float = x + 8.0
	var grid_y: float = y + 26.0
	var icon_total: float = ICON_SIZE + ICON_PAD
	var idx: int = 0
	_hovered_unit_idx = -1
	var mouse: Vector2 = get_local_mouse_position()

	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			if idx >= units.size():
				break
			var unit: Node2D = units[idx]
			if not is_instance_valid(unit):
				idx += 1
				continue

			var icon_x: float = grid_x + float(col) * icon_total
			var icon_y: float = grid_y + float(row) * icon_total
			var icon_rect: Rect2 = Rect2(icon_x, icon_y, ICON_SIZE, ICON_SIZE)
			var hovered: bool = icon_rect.has_point(mouse)
			if hovered:
				_hovered_unit_idx = idx

			# Icon background
			var faction_color: Color = FactionData.get_faction_color(unit.faction_id if "faction_id" in unit else 0)
			var type_hue: float = 0.0
			if "unit_type" in unit:
				type_hue = float(unit.unit_type) * 0.12
			var icon_color: Color = Color.from_hsv(
				fmod(faction_color.h + type_hue, 1.0),
				faction_color.s * 0.8,
				faction_color.v
			)
			var bg_alpha: float = 0.6 if hovered else 0.35
			draw_rect(icon_rect, Color(icon_color.r * 0.3, icon_color.g * 0.3, icon_color.b * 0.3, bg_alpha))

			# HP fill bar at bottom of icon
			if "health" in unit and "max_health" in unit:
				var fill: float = clampf(unit.health / unit.max_health, 0.0, 1.0)
				var bar_h: float = 2.0
				var bar_color: Color = Color(0.3, 0.9, 0.4) if fill > 0.5 else Color(0.9, 0.8, 0.2) if fill > 0.25 else Color(0.9, 0.2, 0.2)
				draw_rect(Rect2(icon_x, icon_y + ICON_SIZE - bar_h, ICON_SIZE * fill, bar_h), bar_color)

			# Unit type initial
			var uname: String = ""
			if "unit_type" in unit:
				uname = UnitStats.get_unit_name(unit.unit_type)
			var letter: String = uname.substr(0, 1) if uname.length() > 0 else "?"
			draw_string(_font, Vector2(icon_x + 8, icon_y + 18), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, icon_color)

			# Border
			var border_color: Color = Color(icon_color.r, icon_color.g, icon_color.b, 0.8) if hovered else Color(icon_color.r, icon_color.g, icon_color.b, 0.3)
			draw_rect(icon_rect, border_color, false, 1.0 if not hovered else 2.0)

			idx += 1

# === BUILDING INFO ===

func _draw_building_info(building: Node2D, x: float, y: float) -> void:
	if not is_instance_valid(building):
		return

	# Building name
	var bname: String = ""
	if "building_type" in building:
		bname = BuildingStats.get_building_name(building.building_type)
	draw_string(_font, Vector2(x + 12, y + 22), bname, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, UIConstants.TEXT_BRIGHT)

	# HP bar
	if "health" in building and "max_health" in building:
		var hp_bar_x: float = x + 12.0
		var hp_bar_y: float = y + 30.0
		var hp_bar_w: float = 200.0
		var hp_bar_h: float = 8.0
		var hp_fill: float = clampf(building.health / building.max_health, 0.0, 1.0)
		draw_rect(Rect2(hp_bar_x, hp_bar_y, hp_bar_w, hp_bar_h), Color(0.08, 0.08, 0.08, 0.8))
		var top_color: Color = Color(0.3, 0.95, 0.5) if hp_fill > 0.5 else Color(0.95, 0.85, 0.2) if hp_fill > 0.25 else Color(0.95, 0.3, 0.2)
		var bot_color: Color = top_color.darkened(0.4)
		draw_rect(Rect2(hp_bar_x, hp_bar_y, hp_bar_w * hp_fill, hp_bar_h * 0.5), top_color)
		draw_rect(Rect2(hp_bar_x, hp_bar_y + hp_bar_h * 0.5, hp_bar_w * hp_fill, hp_bar_h * 0.5), bot_color)
		var hp_text: String = "%d/%d" % [int(building.health), int(building.max_health)]
		draw_string(_mono, Vector2(hp_bar_x + hp_bar_w + 4, hp_bar_y + 7), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)

	# Construction progress (if not complete)
	if building.has_method("is_complete") and not building.is_complete():
		var pct: float = 0.0
		if "construction_progress" in building and "build_time" in building and building.build_time > 0:
			pct = clampf(building.construction_progress / building.build_time, 0.0, 1.0)
		var bar_x: float = x + 12.0
		var bar_y: float = y + 48.0
		draw_string(_mono, Vector2(bar_x, bar_y), "Building...", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.STAT_YELLOW)
		# Progress membrane
		var prog_bar_y: float = bar_y + 4.0
		draw_rect(Rect2(bar_x, prog_bar_y, 200.0, 6.0), Color(0.08, 0.08, 0.08, 0.6))
		draw_rect(Rect2(bar_x, prog_bar_y, 200.0 * pct, 6.0), Color(0.3, 0.7, 1.0, 0.7))
		draw_string(_mono, Vector2(bar_x + 204, prog_bar_y + 5), "%d%%" % int(pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
		return

	# Production queue as organic pods
	if "_production_queue" in building and not building._production_queue.is_empty():
		var pod_x: float = x + 12.0
		var pod_y: float = y + 52.0
		draw_string(_mono, Vector2(pod_x, pod_y), "Queue:", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
		pod_x += 40.0
		for i in range(mini(building._production_queue.size(), 6)):
			var ut: int = building._production_queue[i]
			var pod_r: float = 8.0
			var pod_cx: float = pod_x + float(i) * 22.0
			var pod_cy: float = pod_y - 3.0
			# Pod shape (organic circle)
			var pod_color: Color = Color(0.3, 0.6, 1.0, 0.5) if i == 0 else Color(0.2, 0.3, 0.5, 0.3)
			draw_circle(Vector2(pod_cx, pod_cy), pod_r, pod_color)
			draw_arc(Vector2(pod_cx, pod_cy), pod_r, 0, TAU, 12, Color(pod_color.r, pod_color.g, pod_color.b, 0.8), 1.0)
			# Unit initial
			var pod_letter: String = UnitStats.get_unit_name(ut).substr(0, 1)
			draw_string(_mono, Vector2(pod_cx - 3, pod_cy + 4), pod_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_BRIGHT)

		# Progress membrane on first pod
		if building.has_method("get_production_progress"):
			var pct: float = building.get_production_progress()
			var first_pod_cx: float = pod_x
			var first_pod_cy: float = pod_y - 3.0
			draw_arc(Vector2(first_pod_cx, first_pod_cy), 9.0, -PI * 0.5, -PI * 0.5 + TAU * pct, 16, Color(0.4, 0.9, 1.0, 0.8), 2.0)

	# Rally indicator
	if "has_rally_point" in building and building.has_rally_point:
		var rally_y: float = y + 74.0
		draw_circle(Vector2(x + 20, rally_y - 3), 3.0, Color(0.2, 1.0, 0.4, 0.5))
		draw_string(_mono, Vector2(x + 28, rally_y), "Rally set", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.3, 0.9, 0.5, 0.7))

	# Research info
	if building.has_method("is_researching") and building.is_researching():
		var res_y: float = y + 88.0
		var res_name: String = building.get_current_research_name() if building.has_method("get_current_research_name") else "Research"
		var res_pct: float = building.get_research_progress() if building.has_method("get_research_progress") else 0.0
		draw_string(_mono, Vector2(x + 12, res_y), res_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.6, 0.3, 1.0, 0.9))
		draw_rect(Rect2(x + 12, res_y + 4, 150.0, 4.0), Color(0.1, 0.05, 0.15, 0.5))
		draw_rect(Rect2(x + 12, res_y + 4, 150.0 * res_pct, 4.0), Color(0.55, 0.2, 0.85, 0.8))

# === NO SELECTION ===

func _draw_no_selection(x: float, y: float) -> void:
	var text: String = "Select units"
	var text_alpha: float = 0.2 + 0.05 * sin(_time * 2.0)
	draw_string(_font, Vector2(x + 80, y + 65), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(0.5, 0.7, 0.8, text_alpha))

# === CONTROL GROUPS BAR ===

func _draw_control_groups(vp: Vector2) -> void:
	if not _selection_mgr:
		return
	var strip_w: float = 9 * 42.0
	var strip_x: float = (vp.x - strip_w) * 0.5
	var strip_y: float = vp.y - 28.0
	for i in range(1, 10):
		var gx: float = strip_x + float(i - 1) * 42.0
		var group: Array = _selection_mgr.get_control_group(i)
		var valid: Array = group.filter(func(u): return is_instance_valid(u))
		if valid.is_empty():
			# Empty group - dim outline
			draw_rect(Rect2(gx, strip_y, 38, 24), Color(0.3, 0.3, 0.3, 0.2), false, 1.0)
			draw_string(_font, Vector2(gx + 4, strip_y + 16), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.4, 0.4, 0.3))
		else:
			# Active group - color-coded by composition
			var comp_color: Color = _get_composition_color(valid)
			var under_attack: bool = _is_group_under_attack(valid)
			var bg_alpha: float = (0.3 + 0.2 * sin(_time * 4.0)) if under_attack else 0.3
			draw_rect(Rect2(gx, strip_y, 38, 24), Color(comp_color.r, comp_color.g, comp_color.b, bg_alpha), true)
			# Membrane border
			var border_a: float = 0.8 if under_attack else 0.5
			draw_rect(Rect2(gx, strip_y, 38, 24), Color(comp_color.r, comp_color.g, comp_color.b, border_a), false, 1.0)
			# Group number
			draw_string(_font, Vector2(gx + 4, strip_y + 16), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
			# Unit count
			draw_string(_font, Vector2(gx + 16, strip_y + 16), str(valid.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.8))

# === CONTROL GROUP HELPERS ===

func _get_composition_color(units: Array) -> Color:
	## All workers = green, all military = red, mixed = blue.
	var has_workers: bool = false
	var has_military: bool = false
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if "unit_type" in unit:
			if unit.unit_type == UnitStats.UnitType.WORKER:
				has_workers = true
			else:
				has_military = true
	if has_workers and not has_military:
		return Color(0.3, 0.9, 0.4)  # Green
	elif has_military and not has_workers:
		return Color(0.9, 0.35, 0.3)  # Red
	else:
		return Color(0.3, 0.6, 1.0)  # Blue (mixed)

func _is_group_under_attack(units: Array) -> bool:
	## Check if any unit has taken damage recently (combat time < 3s) and is not idle.
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if "_last_combat_time" in unit and unit._last_combat_time < 3.0:
			if "state" in unit and unit.state != 0:  # Not IDLE
				return true
	return false

# === INPUT HANDLING ===

func _gui_input(event: InputEvent) -> void:
	if not _selection_mgr:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var vp: Vector2 = get_viewport_rect().size
		var mouse: Vector2 = event.position

		# Check multi-selection grid clicks
		var selected: Array = _selection_mgr.selected_units
		if selected.size() > 1 and _hovered_unit_idx >= 0 and _hovered_unit_idx < selected.size():
			var clicked_unit: Node2D = selected[_hovered_unit_idx]
			if is_instance_valid(clicked_unit):
				if event.shift_pressed:
					# Shift+click = remove from selection
					selected.erase(clicked_unit)
					if "is_selected" in clicked_unit:
						clicked_unit.is_selected = false
					_selection_mgr.selection_changed.emit(selected)
				else:
					# Click = select only this unit
					_selection_mgr.select_unit(clicked_unit, false)
				get_viewport().set_input_as_handled()
				return

		# Check control group clicks
		var strip_w: float = 9 * 42.0
		var strip_x: float = (vp.x - strip_w) * 0.5
		var strip_y: float = vp.y - 28.0
		for i in range(1, 10):
			var gx: float = strip_x + float(i - 1) * 42.0
			var group_rect: Rect2 = Rect2(gx, strip_y, 38, 24)
			if group_rect.has_point(mouse):
				var group: Array = _selection_mgr.get_control_group(i)
				var valid: Array = group.filter(func(u): return is_instance_valid(u))
				if valid.is_empty():
					break
				var now: float = _time
				if _last_click_group == i and (now - _last_click_time) < 0.4:
					# Double-click = center camera on group
					var avg_pos: Vector2 = Vector2.ZERO
					for u in valid:
						avg_pos += u.global_position
					avg_pos /= float(valid.size())
					var camera: Camera2D = get_viewport().get_camera_2d()
					if camera and camera.has_method("focus_position"):
						camera.focus_position(avg_pos)
					_last_click_group = -1
				else:
					# Single click = recall group
					_selection_mgr.recall_control_group(i)
					_last_click_time = now
					_last_click_group = i
				get_viewport().set_input_as_handled()
				return

# === DRAWING HELPERS ===

func _get_state_name(state_val: int) -> String:
	match state_val:
		0: return "Idle"
		1: return "Moving"
		2: return "Attacking"
		3: return "Gathering"
		4: return "Building"
		5: return "Patrolling"
		6: return "Returning"
		7: return "Fleeing"
		8: return "Holding"
		_: return "Unknown"

func _get_state_color(state_val: int) -> Color:
	match state_val:
		0: return Color(0.5, 0.7, 0.8, 0.6)  # Idle - dim
		1: return Color(0.3, 0.7, 1.0, 0.8)  # Move - blue
		2: return Color(1.0, 0.4, 0.3, 0.9)  # Attack - red
		3: return Color(0.3, 0.9, 0.4, 0.8)  # Gather - green
		4: return Color(0.9, 0.7, 0.2, 0.8)  # Build - yellow
		5: return Color(0.5, 0.5, 1.0, 0.8)  # Patrol - purple-blue
		6: return Color(0.3, 0.9, 0.5, 0.7)  # Return - green
		7: return Color(1.0, 0.6, 0.2, 0.8)  # Flee - orange
		8: return Color(0.7, 0.7, 0.3, 0.8)  # Hold - dark yellow
		_: return UIConstants.TEXT_DIM

func _draw_star(center: Vector2, radius: float, points: int, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var inner_r: float = radius * 0.4
	for i in range(points * 2):
		var angle: float = float(i) * PI / float(points) - PI * 0.5
		var r: float = radius if i % 2 == 0 else inner_r
		pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(pts, color)

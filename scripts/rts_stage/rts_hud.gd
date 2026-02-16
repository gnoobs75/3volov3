extends Control
## RTS HUD: resource bar, unit info panel, command buttons, build menu.
## All procedural _draw() matching UIConstants style.

var _stage: Node = null
var _selection_mgr: Node = null
var _command_sys: Node = null
var _time: float = 0.0
var _build_menu_open: bool = false
var _hover_btn: int = -1
var _hover_build: int = -1
var _hover_production: int = -1
var _game_speed: float = 1.0
var _dragging_speed_slider: bool = false
const SPEED_MIN: float = 0.25
const SPEED_MAX: float = 2.0

const BUILD_BUTTONS: Array = [
	{"type": BuildingStats.BuildingType.SPAWNING_POOL, "key": "Q"},
	{"type": BuildingStats.BuildingType.EVOLUTION_CHAMBER, "key": "W"},
	{"type": BuildingStats.BuildingType.MEMBRANE_TOWER, "key": "E"},
	{"type": BuildingStats.BuildingType.BIO_WALL, "key": "R"},
	{"type": BuildingStats.BuildingType.NUTRIENT_PROCESSOR, "key": "T"},
]

func setup(stage: Node, sel: Node, cmd: Node) -> void:
	_stage = stage
	_selection_mgr = sel
	_command_sys = cmd
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	# Hover detection
	var vp: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_local_mouse_position()
	_hover_btn = -1
	_hover_build = -1
	_hover_production = -1
	# Check command buttons
	for i in range(6):
		if _get_cmd_btn_rect(vp, i).has_point(mouse):
			_hover_btn = i
	# Check build menu
	if _build_menu_open:
		for i in range(BUILD_BUTTONS.size()):
			if _get_build_btn_rect(vp, i).has_point(mouse):
				_hover_build = i
	# Check production buttons on selected building
	var sel: Array = _selection_mgr.selected_units if _selection_mgr else []
	if sel.size() == 1:
		var selected: Node2D = sel[0]
		if selected.is_in_group("rts_buildings") and "can_produce" in selected:
			for i in range(selected.can_produce.size()):
				if _get_prod_btn_rect(vp, i).has_point(mouse):
					_hover_production = i
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var vp: Vector2 = get_viewport_rect().size
		var mouse: Vector2 = event.position
		if event.pressed:
			# Speed slider drag start
			var sr: Rect2 = _get_speed_slider_rect(vp)
			if sr.has_point(mouse):
				_dragging_speed_slider = true
				_update_speed_from_mouse(mouse, sr)
				get_viewport().set_input_as_handled()
				return
			# Command buttons
			if _hover_btn >= 0:
				_handle_cmd_button(_hover_btn)
				get_viewport().set_input_as_handled()
				return
			# Build menu
			if _hover_build >= 0:
				_handle_build_button(_hover_build)
				get_viewport().set_input_as_handled()
				return
			# Production
			if _hover_production >= 0:
				_handle_production_button(_hover_production)
				get_viewport().set_input_as_handled()
				return
		else:
			_dragging_speed_slider = false
	elif event is InputEventMouseMotion and _dragging_speed_slider:
		var vp: Vector2 = get_viewport_rect().size
		_update_speed_from_mouse(event.position, _get_speed_slider_rect(vp))
		get_viewport().set_input_as_handled()

func _handle_cmd_button(idx: int) -> void:
	if not _selection_mgr:
		return
	match idx:
		0: _command_sys.issue_stop(_selection_mgr.selected_units)
		1: _command_sys.issue_hold(_selection_mgr.selected_units)
		2: _command_sys.enter_attack_move_mode()
		3: _command_sys.enter_patrol_mode()
		4: _build_menu_open = not _build_menu_open
		5: pass  # Reserved

func _handle_build_button(idx: int) -> void:
	if idx < 0 or idx >= BUILD_BUTTONS.size():
		return
	var bt: int = BUILD_BUTTONS[idx].type
	# Get input handler from stage
	if _stage and _stage.has_method("get_input_handler"):
		var ih: Control = _stage.get_input_handler()
		if ih and ih.has_method("enter_build_mode"):
			ih.enter_build_mode(bt)
	_build_menu_open = false

func _handle_production_button(idx: int) -> void:
	if not _selection_mgr:
		return
	var sel: Array = _selection_mgr.selected_units
	if sel.size() != 1:
		return
	var building: Node2D = sel[0]
	if not building.is_in_group("rts_buildings") or not "can_produce" in building:
		return
	if idx >= 0 and idx < building.can_produce.size():
		building.queue_unit(building.can_produce[idx])

func _get_speed_slider_rect(vp: Vector2) -> Rect2:
	return Rect2(vp.x - 220, 8, 150, 24)

func _update_speed_from_mouse(mouse: Vector2, sr: Rect2) -> void:
	var t: float = clampf((mouse.x - sr.position.x) / sr.size.x, 0.0, 1.0)
	_game_speed = lerpf(SPEED_MIN, SPEED_MAX, t)
	Engine.time_scale = _game_speed

func _get_cmd_btn_rect(vp: Vector2, idx: int) -> Rect2:
	var bw: float = 60.0
	var bh: float = 40.0
	var sx: float = vp.x - 250.0 + (idx % 3) * (bw + 6)
	var sy: float = vp.y - 100.0 + (idx / 3) * (bh + 6)
	return Rect2(sx, sy, bw, bh)

func _get_build_btn_rect(vp: Vector2, idx: int) -> Rect2:
	var bw: float = 130.0
	var bh: float = 36.0
	var sx: float = vp.x - 350.0
	var sy: float = vp.y - 250.0 + idx * (bh + 4)
	return Rect2(sx, sy, bw, bh)

func _get_prod_btn_rect(vp: Vector2, idx: int) -> Rect2:
	var bw: float = 120.0
	var bh: float = 32.0
	var sx: float = vp.x * 0.5 - 150.0 + (idx % 2) * (bw + 6)
	var sy: float = vp.y - 90.0 + (idx / 2) * (bh + 4)
	return Rect2(sx, sy, bw, bh)

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()

	# === TOP BAR: Resources ===
	draw_rect(Rect2(0, 0, vp.x, 40), Color(UIConstants.BG_DARK.r, UIConstants.BG_DARK.g, UIConstants.BG_DARK.b, 0.85))
	draw_line(Vector2(0, 39), Vector2(vp.x, 39), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)

	if _stage and _stage.has_method("get_resource_manager"):
		var rm: Node = _stage.get_resource_manager()
		var biomass: int = rm.get_biomass(0)
		var genes: int = rm.get_genes(0)
		# Biomass
		draw_circle(Vector2(30, 20), 6, Color(0.2, 0.8, 0.4, 0.8))
		draw_string(font, Vector2(42, 27), "Biomass: %d" % biomass, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, UIConstants.STAT_GREEN)
		# Gene Fragments
		draw_circle(Vector2(220, 20), 6, Color(0.7, 0.3, 1.0, 0.8))
		draw_string(font, Vector2(232, 27), "Genes: %d" % genes, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(0.7, 0.4, 1.0))

	# Population
	if _stage and _stage.has_method("get_faction_manager"):
		var fm: Node = _stage.get_faction_manager()
		var used: int = fm.get_supply_used(0)
		var cap: int = fm.get_supply_cap(0)
		var pop_col: Color = UIConstants.STAT_GREEN if used < cap else UIConstants.STAT_RED
		draw_string(font, Vector2(400, 27), "Pop: %d/%d" % [used, cap], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, pop_col)

	# === GAME SPEED SLIDER (top right) ===
	_draw_speed_slider(vp, font)

	# === BOTTOM BAR ===
	draw_rect(Rect2(0, vp.y - 120, vp.x, 120), Color(UIConstants.BG_DARK.r, UIConstants.BG_DARK.g, UIConstants.BG_DARK.b, 0.85))
	draw_line(Vector2(0, vp.y - 120), Vector2(vp.x, vp.y - 120), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)

	# === UNIT INFO PANEL (center bottom) ===
	_draw_selection_info(vp, font, mono)

	# === COMMAND BUTTONS (bottom right) ===
	_draw_command_buttons(vp, font)

	# === BUILD MENU (if open) ===
	if _build_menu_open:
		_draw_build_menu(vp, font, mono)

	# === PRODUCTION PANEL (if building selected) ===
	_draw_production_panel(vp, font)

	# === COMMAND MODE INDICATOR ===
	if _command_sys and _command_sys.current_mode != _command_sys.CommandMode.NORMAL:
		var mode_text: String = ""
		match _command_sys.current_mode:
			_command_sys.CommandMode.ATTACK_MOVE: mode_text = "ATTACK MOVE - Click target"
			_command_sys.CommandMode.PATROL: mode_text = "PATROL - Click two points"
			_command_sys.CommandMode.BUILD: mode_text = "PLACE BUILDING - Click to build"
		var ts: Vector2 = font.get_string_size(mode_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
		draw_rect(Rect2(vp.x * 0.5 - ts.x * 0.5 - 10, 50, ts.x + 20, 30), Color(0.1, 0.1, 0.1, 0.8))
		draw_string(font, Vector2(vp.x * 0.5 - ts.x * 0.5, 72), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, UIConstants.STAT_YELLOW)

func _draw_selection_info(vp: Vector2, font: Font, mono: Font) -> void:
	if not _selection_mgr or _selection_mgr.selected_units.is_empty():
		return
	var sel: Array = _selection_mgr.selected_units
	var panel_x: float = 200.0
	var panel_y: float = vp.y - 110.0

	if sel.size() == 1:
		var unit: Node2D = sel[0]
		if not is_instance_valid(unit):
			return
		var uname: String = ""
		if unit.is_in_group("rts_units") and "unit_type" in unit:
			uname = UnitStats.get_unit_name(unit.unit_type)
		elif unit.is_in_group("rts_buildings") and "building_type" in unit:
			uname = BuildingStats.get_building_name(unit.building_type)
		draw_string(font, Vector2(panel_x, panel_y + 18), uname, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, UIConstants.TEXT_BRIGHT)
		if "health" in unit and "max_health" in unit:
			var hp_text: String = "HP: %d/%d" % [int(unit.health), int(unit.max_health)]
			draw_string(mono, Vector2(panel_x, panel_y + 38), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.STAT_GREEN)
		if "damage" in unit:
			draw_string(mono, Vector2(panel_x + 140, panel_y + 38), "ATK: %d" % int(unit.damage), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.STAT_YELLOW)
		if "armor" in unit:
			draw_string(mono, Vector2(panel_x + 240, panel_y + 38), "ARM: %d" % int(unit.armor), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_DIM)
	else:
		# Multiple selection
		draw_string(font, Vector2(panel_x, panel_y + 18), "%d units selected" % sel.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, UIConstants.TEXT_BRIGHT)
		# Count by type
		var type_counts: Dictionary = {}
		for unit in sel:
			if is_instance_valid(unit) and "unit_type" in unit:
				var ut: int = unit.unit_type
				type_counts[ut] = type_counts.get(ut, 0) + 1
		var ty: float = panel_y + 38
		for ut in type_counts:
			draw_string(mono, Vector2(panel_x, ty), "%s: %d" % [UnitStats.get_unit_name(ut), type_counts[ut]], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_DIM)
			ty += 16

func _draw_command_buttons(vp: Vector2, font: Font) -> void:
	var labels: Array = ["Stop", "Hold", "A-Move", "Patrol", "Build", "---"]
	for i in range(6):
		var rect: Rect2 = _get_cmd_btn_rect(vp, i)
		var hovered: bool = _hover_btn == i
		var bg: Color = UIConstants.BTN_BG_HOVER if hovered else UIConstants.BTN_BG
		draw_rect(rect, bg)
		draw_rect(rect, UIConstants.BTN_BORDER if not hovered else UIConstants.BTN_BORDER_HOVER, false, 1.0)
		var tc: Color = UIConstants.BTN_TEXT_HOVER if hovered else UIConstants.BTN_TEXT
		var ls: Vector2 = font.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
		draw_string(font, Vector2(rect.position.x + (rect.size.x - ls.x) * 0.5, rect.position.y + 26), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, tc)

func _draw_build_menu(vp: Vector2, font: Font, mono: Font) -> void:
	# Background panel
	var panel_rect: Rect2 = Rect2(vp.x - 360, vp.y - 260, 145, BUILD_BUTTONS.size() * 40 + 10)
	draw_rect(panel_rect, Color(UIConstants.BG_DARK.r, UIConstants.BG_DARK.g, UIConstants.BG_DARK.b, 0.95))
	draw_rect(panel_rect, UIConstants.BTN_BORDER, false, 1.5)
	draw_string(font, Vector2(panel_rect.position.x + 10, panel_rect.position.y - 4), "BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_TITLE)

	for i in range(BUILD_BUTTONS.size()):
		var rect: Rect2 = _get_build_btn_rect(vp, i)
		var hovered: bool = _hover_build == i
		var bg: Color = UIConstants.BTN_BG_HOVER if hovered else UIConstants.BTN_BG
		draw_rect(rect, bg)
		draw_rect(rect, UIConstants.BTN_BORDER if not hovered else UIConstants.BTN_BORDER_HOVER, false, 1.0)
		var bname: String = BuildingStats.get_building_name(BUILD_BUTTONS[i].type)
		var cost: Dictionary = BuildingStats.get_cost(BUILD_BUTTONS[i].type)
		var label: String = "[%s] %s" % [BUILD_BUTTONS[i].key, bname]
		var tc: Color = UIConstants.BTN_TEXT_HOVER if hovered else UIConstants.BTN_TEXT
		draw_string(font, Vector2(rect.position.x + 6, rect.position.y + 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, tc)
		var cost_str: String = "%dB %dG" % [cost.get("biomass", 0), cost.get("genes", 0)]
		draw_string(mono, Vector2(rect.position.x + 6, rect.position.y + 30), cost_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)

func _draw_production_panel(vp: Vector2, font: Font) -> void:
	if not _selection_mgr or _selection_mgr.selected_units.size() != 1:
		return
	var sel: Node2D = _selection_mgr.selected_units[0]
	if not is_instance_valid(sel) or not sel.is_in_group("rts_buildings"):
		return
	if not "can_produce" in sel or sel.can_produce.is_empty():
		return
	if not sel.has_method("is_complete") or not sel.is_complete():
		return

	# Draw production buttons
	for i in range(sel.can_produce.size()):
		var rect: Rect2 = _get_prod_btn_rect(vp, i)
		var hovered: bool = _hover_production == i
		var bg: Color = UIConstants.BTN_BG_HOVER if hovered else UIConstants.BTN_BG
		draw_rect(rect, bg)
		draw_rect(rect, UIConstants.BTN_BORDER if not hovered else UIConstants.BTN_BORDER_HOVER, false, 1.0)
		var utype: int = sel.can_produce[i]
		var uname: String = UnitStats.get_unit_name(utype)
		var cost: Dictionary = UnitStats.get_cost(utype)
		var tc: Color = UIConstants.BTN_TEXT_HOVER if hovered else UIConstants.BTN_TEXT
		draw_string(font, Vector2(rect.position.x + 4, rect.position.y + 15), uname, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, tc)
		var cost_str: String = "%dB %dG" % [cost.get("biomass", 0), cost.get("genes", 0)]
		draw_string(font, Vector2(rect.position.x + 4, rect.position.y + 28), cost_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)

	# Show production progress
	if sel.has_method("get_production_progress") and sel.get_queue_size() > 0:
		var pct: float = sel.get_production_progress()
		var bar_y: float = vp.y - 115.0
		var bar_x: float = vp.x * 0.5 - 100.0
		draw_rect(Rect2(bar_x, bar_y, 200, 8), Color(0.1, 0.1, 0.1, 0.7))
		draw_rect(Rect2(bar_x, bar_y, 200 * pct, 8), Color(0.3, 0.7, 1.0, 0.8))
		draw_string(font, Vector2(bar_x + 205, bar_y + 8), "Q:%d" % sel.get_queue_size(), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)

func _draw_speed_slider(vp: Vector2, font: Font) -> void:
	var sr: Rect2 = _get_speed_slider_rect(vp)
	# Label
	draw_string(font, Vector2(sr.position.x - 50, sr.position.y + 16), "Speed", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_DIM)
	# Track
	draw_rect(sr, Color(0.08, 0.1, 0.15, 0.9))
	draw_rect(sr, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), false, 1.0)
	# Fill
	var t: float = clampf((_game_speed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), 0.0, 1.0)
	var fill_w: float = sr.size.x * t
	var fill_color: Color = UIConstants.STAT_GREEN if _game_speed <= 1.1 else UIConstants.STAT_YELLOW if _game_speed <= 1.6 else UIConstants.STAT_RED
	draw_rect(Rect2(sr.position.x, sr.position.y, fill_w, sr.size.y), Color(fill_color.r, fill_color.g, fill_color.b, 0.4))
	# Thumb
	var thumb_x: float = sr.position.x + fill_w
	draw_rect(Rect2(thumb_x - 3, sr.position.y - 2, 6, sr.size.y + 4), fill_color)
	# Value text
	var speed_text: String = "%dx" % int(_game_speed) if is_equal_approx(_game_speed, roundf(_game_speed)) else "%.1fx" % _game_speed
	draw_string(font, Vector2(sr.position.x + sr.size.x + 8, sr.position.y + 16), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, fill_color)

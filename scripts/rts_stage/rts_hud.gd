extends Control
## RTS HUD: resource bar, unit info panel, command buttons, build menu,
## production panel, tooltips, idle-worker counter, income rate, game timer,
## difficulty indicator, hotkey labels, multi-selection icons.
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

# --- Tooltip ---
var _tooltip_text: String = ""
var _tooltip_pos: Vector2 = Vector2.ZERO

# --- Idle workers ---
var _idle_worker_count: int = 0
var _idle_worker_cycle_idx: int = 0

# --- Resource income ---
var _last_biomass: int = 0
var _last_genes: int = 0
var _income_biomass: int = 0
var _income_genes: int = 0
var _income_timer: float = 0.0
var _low_resource_pulse: float = 0.0  # For resource warning flash

# --- Game timer (fallback) ---
var _local_game_time: float = 0.0

# --- Difficulty ---
enum AIDifficulty { NOOB, EASY, MEDIUM, HARD, SWEATY }
var _ai_difficulty: int = AIDifficulty.MEDIUM
const DIFFICULTY_NAMES: Array = ["NOOB", "EASY", "MEDIUM", "HARD", "SWEATY"]
const DIFFICULTY_COLORS: Array = [
	Color(0.4, 0.9, 0.4),   # NOOB - green
	Color(0.5, 0.85, 0.5),  # EASY - green
	Color(1.0, 0.9, 0.3),   # MEDIUM - yellow
	Color(1.0, 0.55, 0.2),  # HARD - orange
	Color(0.95, 0.25, 0.2), # SWEATY - red
]

const BUILD_BUTTONS: Array = [
	{"type": BuildingStats.BuildingType.SPAWNING_POOL, "key": "Q"},
	{"type": BuildingStats.BuildingType.EVOLUTION_CHAMBER, "key": "W"},
	{"type": BuildingStats.BuildingType.MEMBRANE_TOWER, "key": "E"},
	{"type": BuildingStats.BuildingType.BIO_WALL, "key": "R"},
	{"type": BuildingStats.BuildingType.NUTRIENT_PROCESSOR, "key": "T"},
]

const BUILDING_DESCRIPTIONS: Dictionary = {
	0: "Main base. Produces workers. Drop-off for resources.",
	1: "Produces combat units: Warriors, Tanks, Scouts, Spitters.",
	2: "Defensive tower. Auto-attacks nearby enemies.",
	3: "Cheap wall segment. Blocks enemy movement.",
	4: "Secondary resource drop-off. Provides +5 supply.",
}

const UNIT_DESCRIPTIONS: Dictionary = {
	0: "Gathers resources and constructs buildings.",
	1: "Melee fighter. +50% charge damage after moving.",
	2: "Heavy tank. High HP and armor, slow.",
	3: "Fast scout. Double detection range.",
	4: "Ranged spitter. Fires acid projectiles.",
}

const CMD_LABELS: Array = ["[S] Stop", "[H] Hold", "[A] A-Move", "[P] Patrol", "[B] Build", "---"]
const CMD_HOTKEYS: Array = ["S", "H", "A", "P", "B", ""]
const CMD_TOOLTIPS: Array = [
	"Stop (S)", "Hold Position (H)", "Attack Move (A)",
	"Patrol (P)", "Build Menu (B)", "---",
]

func setup(stage: Node, sel: Node, cmd: Node) -> void:
	_stage = stage
	_selection_mgr = sel
	_command_sys = cmd
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	_local_game_time += delta

	var vp: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_local_mouse_position()

	# --- Hover detection ---
	_hover_btn = -1
	_hover_build = -1
	_hover_production = -1

	for i in range(6):
		if _get_cmd_btn_rect(vp, i).has_point(mouse):
			_hover_btn = i

	if _build_menu_open:
		for i in range(BUILD_BUTTONS.size()):
			if _get_build_btn_rect(vp, i).has_point(mouse):
				_hover_build = i

	var sel: Array = _selection_mgr.selected_units if _selection_mgr else []
	if sel.size() == 1:
		var selected: Node2D = sel[0]
		if is_instance_valid(selected) and selected.is_in_group("rts_buildings") and "can_produce" in selected:
			for i in range(selected.can_produce.size()):
				if _get_prod_btn_rect(vp, i).has_point(mouse):
					_hover_production = i

	# --- Tooltip ---
	_tooltip_text = ""
	_tooltip_pos = mouse
	if _hover_btn >= 0:
		_tooltip_text = CMD_TOOLTIPS[_hover_btn]
	elif _hover_build >= 0:
		var bt: int = BUILD_BUTTONS[_hover_build].type
		var bname: String = BuildingStats.get_building_name(bt)
		var cost: Dictionary = BuildingStats.get_cost(bt)
		var desc: String = BUILDING_DESCRIPTIONS.get(bt, "")
		_tooltip_text = "%s  (%dB / %dG)\n%s" % [bname, cost.get("biomass", 0), cost.get("genes", 0), desc]
	elif _hover_production >= 0 and sel.size() == 1:
		var selected: Node2D = sel[0]
		if is_instance_valid(selected) and "can_produce" in selected and _hover_production < selected.can_produce.size():
			var ut: int = selected.can_produce[_hover_production]
			var uname: String = UnitStats.get_unit_name(ut)
			var cost: Dictionary = UnitStats.get_cost(ut)
			var stats: Dictionary = UnitStats.get_stats(ut)
			var bt_time: float = stats.get("build_time", 0.0)
			var desc: String = UNIT_DESCRIPTIONS.get(ut, "")
			_tooltip_text = "%s  (%dB / %dG)  %.0fs\n%s" % [uname, cost.get("biomass", 0), cost.get("genes", 0), bt_time, desc]
	elif _get_speed_slider_rect(vp).grow(4).has_point(mouse):
		_tooltip_text = "Game Speed: drag to adjust (0.25x - 2.0x)"
	elif _get_difficulty_rect(vp).has_point(mouse):
		_tooltip_text = "Click to cycle AI difficulty"

	# --- Idle worker scan (every frame is cheap for faction_0 group) ---
	_idle_worker_count = 0
	if _stage:
		for unit in get_tree().get_nodes_in_group("faction_0"):
			if unit.is_in_group("rts_units") and is_instance_valid(unit):
				if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
					if "state" in unit and unit.state == 0:  # IDLE
						_idle_worker_count += 1

	# --- Low resource warning ---
	_low_resource_pulse += delta * 3.0

	# --- Resource income ---
	_income_timer += delta
	if _income_timer >= 2.0:
		if _stage and _stage.has_method("get_resource_manager"):
			var rm: Node = _stage.get_resource_manager()
			var cur_bio: int = rm.get_biomass(0)
			var cur_gen: int = rm.get_genes(0)
			_income_biomass = int((cur_bio - _last_biomass) / 2.0)
			_income_genes = int((cur_gen - _last_genes) / 2.0)
			_last_biomass = cur_bio
			_last_genes = cur_gen
		_income_timer = 0.0

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
			# Idle worker button
			if _get_idle_worker_rect(vp).has_point(mouse) and _idle_worker_count > 0:
				_cycle_idle_worker()
				get_viewport().set_input_as_handled()
				return
			# Difficulty button
			if _get_difficulty_rect(vp).has_point(mouse):
				_ai_difficulty = (_ai_difficulty + 1) % DIFFICULTY_NAMES.size()
				if _stage and _stage.has_method("set_ai_difficulty"):
					_stage.set_ai_difficulty(_ai_difficulty)
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

# === IDLE WORKER CYCLE ===

func _cycle_idle_worker() -> void:
	var idle_workers: Array = []
	for unit in get_tree().get_nodes_in_group("faction_0"):
		if unit.is_in_group("rts_units") and is_instance_valid(unit):
			if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
				if "state" in unit and unit.state == 0:
					idle_workers.append(unit)
	if idle_workers.is_empty():
		return
	_idle_worker_cycle_idx = _idle_worker_cycle_idx % idle_workers.size()
	var worker: Node2D = idle_workers[_idle_worker_cycle_idx]
	_idle_worker_cycle_idx = (_idle_worker_cycle_idx + 1) % idle_workers.size()
	# Select and center camera
	if _selection_mgr:
		_selection_mgr.select_unit(worker, false)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera and camera.has_method("focus_position"):
		camera.focus_position(worker.global_position)

# === RECT HELPERS ===

func _get_speed_slider_rect(vp: Vector2) -> Rect2:
	return Rect2(vp.x - 220, 8, 150, 24)

func _update_speed_from_mouse(mouse: Vector2, sr: Rect2) -> void:
	var t: float = clampf((mouse.x - sr.position.x) / sr.size.x, 0.0, 1.0)
	_game_speed = lerpf(SPEED_MIN, SPEED_MAX, t)
	Engine.time_scale = _game_speed

func _get_cmd_btn_rect(vp: Vector2, idx: int) -> Rect2:
	var bw: float = 68.0
	var bh: float = 40.0
	var sx: float = vp.x - 260.0 + (idx % 3) * (bw + 6)
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

func _get_idle_worker_rect(vp: Vector2) -> Rect2:
	return Rect2(510, 4, 80, 32)

func _get_difficulty_rect(vp: Vector2) -> Rect2:
	# Placed right after the game timer in the top-center area
	var label_w: float = 70.0
	return Rect2(vp.x * 0.5 + 50, 4, label_w, 32)

func _get_game_time() -> float:
	if _stage:
		for child in _stage.get_children():
			if child.has_method("get_game_time"):
				return child.get_game_time()
	return _local_game_time

# ====================== DRAW ======================

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
		var low_bio: bool = biomass < 50
		var low_gen: bool = genes < 10 and genes >= 0
		var warn_pulse: float = 0.5 + 0.5 * sin(_low_resource_pulse)
		# Biomass
		var bio_color: Color = UIConstants.STAT_GREEN
		if low_bio:
			bio_color = Color(1.0, 0.4, 0.3).lerp(UIConstants.STAT_GREEN, warn_pulse)
		draw_circle(Vector2(30, 20), 6, Color(0.2, 0.8, 0.4, 0.8))
		if low_bio:
			draw_arc(Vector2(30, 20), 8.0, 0, TAU, 12, Color(1.0, 0.3, 0.2, 0.5 * warn_pulse), 1.5)
		draw_string(font, Vector2(42, 27), "Biomass: %d" % biomass, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, bio_color)
		# Income rate (biomass)
		var inc_bio_text: String = "+%d/s" % _income_biomass if _income_biomass >= 0 else "%d/s" % _income_biomass
		var bio_w: float = font.get_string_size("Biomass: %d" % biomass, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY).x
		var inc_bio_color: Color = Color(0.25, 0.65, 0.4, 0.7) if _income_biomass >= 0 else Color(0.9, 0.3, 0.3, 0.7)
		draw_string(mono, Vector2(42 + bio_w + 6, 27), inc_bio_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, inc_bio_color)
		# Gene Fragments
		var gen_color: Color = Color(0.7, 0.4, 1.0)
		if low_gen:
			gen_color = Color(1.0, 0.4, 0.3).lerp(Color(0.7, 0.4, 1.0), warn_pulse)
		draw_circle(Vector2(220, 20), 6, Color(0.7, 0.3, 1.0, 0.8))
		if low_gen:
			draw_arc(Vector2(220, 20), 8.0, 0, TAU, 12, Color(1.0, 0.3, 0.2, 0.5 * warn_pulse), 1.5)
		draw_string(font, Vector2(232, 27), "Genes: %d" % genes, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, gen_color)
		# Income rate (genes)
		var inc_gen_text: String = "+%d/s" % _income_genes if _income_genes >= 0 else "%d/s" % _income_genes
		var inc_gen_color: Color = Color(0.55, 0.3, 0.75, 0.7) if _income_genes >= 0 else Color(0.9, 0.3, 0.3, 0.7)
		var gen_w: float = font.get_string_size("Genes: %d" % genes, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY).x
		draw_string(mono, Vector2(232 + gen_w + 6, 27), inc_gen_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, inc_gen_color)

	# Population
	if _stage and _stage.has_method("get_faction_manager"):
		var fm: Node = _stage.get_faction_manager()
		var used: int = fm.get_supply_used(0)
		var cap: int = fm.get_supply_cap(0)
		var pop_col: Color = UIConstants.STAT_GREEN if used < cap else UIConstants.STAT_RED
		draw_string(font, Vector2(400, 27), "Pop: %d/%d" % [used, cap], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, pop_col)

	# === IDLE WORKER COUNTER (after Population) ===
	_draw_idle_worker_counter(vp, font, mono)

	# === GAME TIMER (top center) ===
	_draw_game_timer(vp, font)

	# === DIFFICULTY INDICATOR (right of timer) ===
	_draw_difficulty_indicator(vp, font)

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

	# === TOOLTIP (always last - on top of everything) ===
	if _tooltip_text.length() > 0:
		_draw_tooltip(vp, font)

# === IDLE WORKER COUNTER ===

func _draw_idle_worker_counter(vp: Vector2, font: Font, mono: Font) -> void:
	var rect: Rect2 = _get_idle_worker_rect(vp)
	var hovered: bool = rect.has_point(get_local_mouse_position())
	# Background (subtle, clickable feel on hover)
	var bg_alpha: float = 0.5 if hovered else 0.3
	draw_rect(rect, Color(0.1, 0.12, 0.2, bg_alpha))
	if hovered:
		draw_rect(rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), false, 1.0)
	# Idle worker icon: small circle with "!" inside
	var icon_center: Vector2 = Vector2(rect.position.x + 14, rect.position.y + 16)
	var icon_color: Color = UIConstants.STAT_YELLOW if _idle_worker_count > 0 else UIConstants.TEXT_DIM
	draw_circle(icon_center, 8, Color(icon_color.r, icon_color.g, icon_color.b, 0.3))
	draw_arc(icon_center, 8, 0, TAU, 24, icon_color, 1.5)
	# "!" inside
	draw_string(mono, Vector2(icon_center.x - 3, icon_center.y + 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, icon_color)
	# Count text
	var count_color: Color = UIConstants.STAT_YELLOW if _idle_worker_count > 0 else UIConstants.TEXT_DIM
	draw_string(font, Vector2(rect.position.x + 28, rect.position.y + 22), "Idle: %d" % _idle_worker_count, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, count_color)

# === GAME TIMER ===

func _draw_game_timer(vp: Vector2, font: Font) -> void:
	var elapsed: float = _get_game_time()
	var minutes: int = int(elapsed) / 60
	var seconds: int = int(elapsed) % 60
	var timer_text: String = "%02d:%02d" % [minutes, seconds]
	var ts: Vector2 = font.get_string_size(timer_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	var tx: float = vp.x * 0.5 - ts.x * 0.5
	draw_string(font, Vector2(tx, 27), timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, UIConstants.TEXT_NORMAL)

# === DIFFICULTY INDICATOR ===

func _draw_difficulty_indicator(vp: Vector2, font: Font) -> void:
	var rect: Rect2 = _get_difficulty_rect(vp)
	var hovered: bool = rect.has_point(get_local_mouse_position())
	var diff_name: String = DIFFICULTY_NAMES[_ai_difficulty]
	var diff_color: Color = DIFFICULTY_COLORS[_ai_difficulty]
	# Background
	var bg_alpha: float = 0.5 if hovered else 0.3
	draw_rect(rect, Color(0.1, 0.12, 0.2, bg_alpha))
	if hovered:
		draw_rect(rect, Color(diff_color.r, diff_color.g, diff_color.b, 0.35), false, 1.0)
	# Label
	draw_string(font, Vector2(rect.position.x + 4, rect.position.y + 22), diff_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, diff_color)

# === SELECTION INFO ===

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
		# Multi-selection: header
		draw_string(font, Vector2(panel_x, panel_y + 18), "%d units selected" % sel.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, UIConstants.TEXT_BRIGHT)

		# Count by type with colored circles
		var type_counts: Dictionary = {}
		for unit in sel:
			if is_instance_valid(unit) and "unit_type" in unit:
				var ut: int = unit.unit_type
				type_counts[ut] = type_counts.get(ut, 0) + 1

		var icon_x: float = panel_x
		var icon_y: float = panel_y + 42
		for ut in type_counts:
			# Colored circle using player faction color
			var faction_color: Color = FactionData.get_faction_color(0)
			# Vary brightness slightly by unit type for differentiation
			var type_hue_shift: float = float(ut) * 0.12
			var circle_color: Color = Color.from_hsv(
				fmod(faction_color.h + type_hue_shift, 1.0),
				faction_color.s * 0.8,
				faction_color.v
			)
			draw_circle(Vector2(icon_x + 8, icon_y), 7, Color(circle_color.r, circle_color.g, circle_color.b, 0.5))
			draw_arc(Vector2(icon_x + 8, icon_y), 7, 0, TAU, 16, circle_color, 1.5)
			# Unit initial inside circle
			var uname_short: String = UnitStats.get_unit_name(ut).substr(0, 1)
			draw_string(mono, Vector2(icon_x + 4, icon_y + 4), uname_short, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_BRIGHT)
			# Count next to circle
			var count_text: String = "%d" % type_counts[ut]
			draw_string(mono, Vector2(icon_x + 18, icon_y + 5), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_DIM)
			var count_w: float = mono.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION).x
			icon_x += 22 + count_w + 10

# === COMMAND BUTTONS (with hotkey labels) ===

func _draw_command_buttons(vp: Vector2, font: Font) -> void:
	for i in range(6):
		var rect: Rect2 = _get_cmd_btn_rect(vp, i)
		var hovered: bool = _hover_btn == i
		var bg: Color = UIConstants.BTN_BG_HOVER if hovered else UIConstants.BTN_BG
		draw_rect(rect, bg)
		draw_rect(rect, UIConstants.BTN_BORDER if not hovered else UIConstants.BTN_BORDER_HOVER, false, 1.0)
		var tc: Color = UIConstants.BTN_TEXT_HOVER if hovered else UIConstants.BTN_TEXT
		var dim_tc: Color = Color(tc.r, tc.g, tc.b, tc.a * 0.5)

		var label: String = CMD_LABELS[i]
		var hotkey: String = CMD_HOTKEYS[i]

		if hotkey.length() > 0:
			# Draw hotkey part in dimmer color, then command name
			var hotkey_str: String = "[%s] " % hotkey
			var cmd_name: String = label.substr(hotkey_str.length())
			var hk_size: Vector2 = font.get_string_size(hotkey_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY)
			var cmd_size: Vector2 = font.get_string_size(cmd_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY)
			var total_w: float = hk_size.x + cmd_size.x
			var start_x: float = rect.position.x + (rect.size.x - total_w) * 0.5
			draw_string(font, Vector2(start_x, rect.position.y + 26), hotkey_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, dim_tc)
			draw_string(font, Vector2(start_x + hk_size.x, rect.position.y + 26), cmd_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, tc)
		else:
			# "---" or similar with no hotkey
			var ls: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
			draw_string(font, Vector2(rect.position.x + (rect.size.x - ls.x) * 0.5, rect.position.y + 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, dim_tc)

# === BUILD MENU ===

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

# === PRODUCTION PANEL ===

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

	# Show production progress with queue preview
	if sel.has_method("get_production_progress") and sel.get_queue_size() > 0:
		var pct: float = sel.get_production_progress()
		var bar_y: float = vp.y - 118.0
		var bar_x: float = vp.x * 0.5 - 100.0
		# Currently building label
		if "_production_queue" in sel and not sel._production_queue.is_empty():
			var cur_unit: int = sel._production_queue[0]
			var cur_name: String = UnitStats.get_unit_name(cur_unit)
			var mono_f: Font = UIConstants.get_mono_font()
			draw_string(mono_f, Vector2(bar_x, bar_y - 2), "Building: %s" % cur_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.3, 0.7, 1.0, 0.9))
		# Progress bar
		draw_rect(Rect2(bar_x, bar_y + 12, 200, 8), Color(0.1, 0.1, 0.1, 0.7))
		draw_rect(Rect2(bar_x, bar_y + 12, 200 * pct, 8), Color(0.3, 0.7, 1.0, 0.8))
		# Queue items preview (small icons for queued units)
		var q_x: float = bar_x + 205
		draw_string(font, Vector2(q_x, bar_y + 20), "Q:", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
		q_x += 18
		if "_production_queue" in sel:
			var mono_f: Font = UIConstants.get_mono_font()
			for qi in range(mini(sel._production_queue.size(), 6)):
				var qut: int = sel._production_queue[qi]
				var q_initial: String = UnitStats.get_unit_name(qut).substr(0, 1)
				var q_col: Color = Color(0.3, 0.7, 1.0, 0.7) if qi == 0 else UIConstants.TEXT_DIM
				draw_circle(Vector2(q_x + 6, bar_y + 16), 6, Color(q_col.r, q_col.g, q_col.b, 0.2))
				draw_string(mono_f, Vector2(q_x + 2, bar_y + 20), q_initial, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, q_col)
				q_x += 16

# === SPEED SLIDER ===

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

# === TOOLTIP ===

func _draw_tooltip(vp: Vector2, font: Font) -> void:
	var lines: PackedStringArray = _tooltip_text.split("\n")
	var max_w: float = 0.0
	for line in lines:
		var lw: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION).x
		if lw > max_w:
			max_w = lw
	var line_h: float = 16.0
	var pad: float = 8.0
	var tw: float = max_w + pad * 2
	var th: float = lines.size() * line_h + pad * 2
	var tx: float = _tooltip_pos.x + 15
	var ty: float = _tooltip_pos.y + 10
	# Clamp to screen edges
	if tx + tw > vp.x - 4:
		tx = vp.x - tw - 4
	if ty + th > vp.y - 4:
		ty = vp.y - th - 4
	if tx < 4:
		tx = 4
	if ty < 4:
		ty = 4
	var tooltip_rect: Rect2 = Rect2(tx, ty, tw, th)
	# Dark background
	draw_rect(tooltip_rect, Color(0.04, 0.05, 0.1, 0.95))
	# 1px border
	draw_rect(tooltip_rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.6), false, 1.0)
	# Text lines
	for i in range(lines.size()):
		draw_string(font, Vector2(tx + pad, ty + pad + (i + 1) * line_h - 2), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_BRIGHT)

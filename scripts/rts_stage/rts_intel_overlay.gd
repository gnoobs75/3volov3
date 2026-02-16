extends Control
## RTS Intel Science Disk: alien tablet overlay showing faction intelligence.
## Left panel: player faction detailed stats (troops, buildings, resources, upgrades).
## Right panel: enemy faction assessments with strength indicators.
## Bottom center: animated pie chart of faction strength probability.
## Toggle via TAB key. Matches organism_codex.gd alien aesthetic.

signal intel_closed

const HEADER_H: float = 60.0
const PANEL_PAD: float = 20.0
const PIE_RADIUS: float = 90.0
const PIE_Y_OFFSET: float = 120.0  # From bottom

# Faction strength cache (smoothed)
var _faction_strengths: Array[float] = [0.25, 0.25, 0.25, 0.25]
var _target_strengths: Array[float] = [0.25, 0.25, 0.25, 0.25]
var _pie_rotation: float = 0.0
var _strength_noise: Array[float] = [0.0, 0.0, 0.0, 0.0]  # Per-faction fluctuation

# State
var _active: bool = false
var _time: float = 0.0
var _glyph_columns: Array = []
var _scan_pulse: float = 0.0
var _stage: Node = null
var _hover_faction: int = -1  # Which enemy faction panel is hovered

# Cached data (updated periodically)
var _cache_timer: float = 0.0
const CACHE_INTERVAL: float = 0.5
var _player_units: Dictionary = {}  # unit_type -> count
var _player_buildings: Dictionary = {}  # building_type -> {count, complete}
var _player_supply: Vector2i = Vector2i.ZERO  # used, cap
var _player_biomass: int = 0
var _player_genes: int = 0
var _player_income_bio: int = 0
var _player_income_gen: int = 0
var _enemy_data: Array = []  # [{faction_id, name, color, unit_count, building_count, eliminated, biomass_est, strength}]
var _player_total_damage: float = 0.0
var _player_total_hp: float = 0.0
var _last_bio: int = 0
var _last_gen: int = 0
var _income_sample_timer: float = 0.0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	_glyph_columns = UIConstants.create_glyph_columns(8)

func setup(stage: Node) -> void:
	_stage = stage

func toggle() -> void:
	_active = not _active
	visible = _active
	set_process(_active)
	if _active:
		_refresh_cache()
		queue_redraw()
	else:
		intel_closed.emit()

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_scan_pulse = fmod(_time * 0.8, 1.0)
	_pie_rotation += delta * 0.15

	# Animate glyph columns
	for col in _glyph_columns:
		col.offset += col.speed * delta

	# Smooth strength values toward targets
	for i in range(4):
		_faction_strengths[i] = lerpf(_faction_strengths[i], _target_strengths[i], delta * 3.0)
		# Add subtle noise fluctuation
		_strength_noise[i] = sin(_time * (1.3 + i * 0.4) + i * 1.7) * 0.015

	# Periodic data refresh
	_cache_timer += delta
	_income_sample_timer += delta
	if _cache_timer >= CACHE_INTERVAL:
		_cache_timer = 0.0
		_refresh_cache()

	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			# Check close button
			var close_rect: Rect2 = Rect2(size.x - 54, 10, 44, 44)
			if close_rect.has_point(event.position):
				toggle()
	elif event is InputEventMouseMotion:
		_update_hover(event.position)
		accept_event()

func _update_hover(pos: Vector2) -> void:
	_hover_faction = -1
	var s: Vector2 = size
	var right_x: float = s.x * 0.52
	var right_w: float = s.x - right_x - PANEL_PAD
	var panel_h: float = 110.0
	var y: float = HEADER_H + 20.0
	for i in range(_enemy_data.size()):
		var rect: Rect2 = Rect2(right_x, y, right_w - 20, panel_h)
		if rect.has_point(pos):
			_hover_faction = i
			return
		y += panel_h + 10.0

# ======================== DATA ========================

func _refresh_cache() -> void:
	if not _stage:
		return

	# --- Player unit counts ---
	_player_units.clear()
	_player_total_damage = 0.0
	_player_total_hp = 0.0
	for ut in [0, 1, 2, 3, 4]:  # WORKER through RANGED
		_player_units[ut] = 0
	for unit in get_tree().get_nodes_in_group("faction_0"):
		if unit.is_in_group("rts_units") and is_instance_valid(unit):
			if "unit_type" in unit:
				_player_units[unit.unit_type] = _player_units.get(unit.unit_type, 0) + 1
			if "health" in unit:
				_player_total_hp += unit.health
			if "damage" in unit:
				_player_total_damage += unit.damage

	# --- Player buildings ---
	_player_buildings.clear()
	for bt in [0, 1, 2, 3, 4]:  # All building types
		_player_buildings[bt] = {"count": 0, "complete": 0}
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if "faction_id" in building and building.faction_id == 0:
			if "building_type" in building:
				var bt: int = building.building_type
				if bt not in _player_buildings:
					_player_buildings[bt] = {"count": 0, "complete": 0}
				_player_buildings[bt]["count"] += 1
				if building.has_method("is_complete") and building.is_complete():
					_player_buildings[bt]["complete"] += 1

	# --- Player resources and supply ---
	if _stage.has_method("get_resource_manager"):
		var rm: Node = _stage.get_resource_manager()
		_player_biomass = rm.get_biomass(0)
		_player_genes = rm.get_genes(0)
	if _stage.has_method("get_faction_manager"):
		var fm: Node = _stage.get_faction_manager()
		_player_supply = Vector2i(fm.get_supply_used(0), fm.get_supply_cap(0))

	# --- Income sampling ---
	if _income_sample_timer >= 2.0:
		_player_income_bio = int((_player_biomass - _last_bio) / _income_sample_timer)
		_player_income_gen = int((_player_genes - _last_gen) / _income_sample_timer)
		_last_bio = _player_biomass
		_last_gen = _player_genes
		_income_sample_timer = 0.0

	# --- Enemy factions ---
	_enemy_data.clear()
	for fid in [1, 2, 3]:
		var data: Dictionary = {
			"faction_id": fid,
			"name": FactionData.get_faction_name(fid),
			"color": FactionData.get_faction_color(fid),
			"unit_count": 0,
			"building_count": 0,
			"eliminated": false,
			"strength": 0.0,
			"total_hp": 0.0,
			"total_damage": 0.0,
			"worker_count": 0,
			"combat_count": 0,
		}
		if _stage.has_method("get_faction_manager"):
			var fm: Node = _stage.get_faction_manager()
			data["eliminated"] = fm.is_eliminated(fid)

		# Count units
		for unit in get_tree().get_nodes_in_group("faction_%d" % fid):
			if unit.is_in_group("rts_units") and is_instance_valid(unit):
				data["unit_count"] += 1
				if "health" in unit:
					data["total_hp"] += unit.health
				if "damage" in unit:
					data["total_damage"] += unit.damage
				if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
					data["worker_count"] += 1
				else:
					data["combat_count"] += 1
			elif unit.is_in_group("rts_buildings") and is_instance_valid(unit):
				data["building_count"] += 1

		_enemy_data.append(data)

	# --- Compute strength proportions ---
	var strengths: Array[float] = []
	for i in range(4):
		var s: float = 1.0  # Minimum baseline
		if i == 0:
			s += _player_total_hp * 0.5 + _player_total_damage * 2.0 + _player_biomass * 0.1
		else:
			var ed: Dictionary = _enemy_data[i - 1]
			if ed["eliminated"]:
				s = 0.0
			else:
				s += ed["total_hp"] * 0.5 + ed["total_damage"] * 2.0 + ed["building_count"] * 20.0
		strengths.append(s)

	var total: float = 0.0
	for s in strengths:
		total += s
	if total > 0:
		for i in range(4):
			_target_strengths[i] = strengths[i] / total

# ======================== DRAWING ========================

func _draw() -> void:
	if not _active:
		return
	var s: Vector2 = size

	# Background — dark tablet
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.05, 0.07, 0.13, 0.97))

	# Blueprint grid
	UIConstants.draw_blueprint_grid(self, s, 0.3)

	# Glyph columns (faint alien text in background)
	UIConstants.draw_glyph_columns(self, s, _glyph_columns, 0.2)

	# Scan line
	var scan_y: float = fmod(_time * 50.0, s.y)
	UIConstants.draw_scan_line(self, s, scan_y, _time, 0.4)

	# Vignette
	UIConstants.draw_vignette(self, s, 0.7)

	# Header
	_draw_header(s)

	# Left panel: Player faction intel
	_draw_player_panel(s)

	# Center divider
	var div_x: float = s.x * 0.50
	draw_line(Vector2(div_x, HEADER_H + 5), Vector2(div_x, s.y - PIE_Y_OFFSET - PIE_RADIUS - 30), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.2), 1.0)
	# Glow pulse on divider
	var glow_y: float = fmod(_time * 35.0, s.y - HEADER_H) + HEADER_H
	draw_line(Vector2(div_x, glow_y - 15), Vector2(div_x, glow_y + 15), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.35), 2.0)

	# Right panel: Enemy factions
	_draw_enemy_panel(s)

	# Bottom: Strength pie chart
	_draw_strength_pie(s)

	# Corner frame
	UIConstants.draw_corner_frame(self, Rect2(4, 4, s.x - 8, s.y - 8), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3))

	# Close button
	var close_col: Color = Color(0.9, 0.3, 0.3, 0.9) if false else Color(0.4, 0.25, 0.25, 0.7)
	var close_rect: Rect2 = Rect2(s.x - 54, 10, 44, 44)
	if close_rect.has_point(get_local_mouse_position()):
		close_col = Color(0.9, 0.3, 0.3, 0.9)
	draw_rect(close_rect, close_col * 0.2)
	draw_rect(close_rect, close_col, false, 1.5)
	var font: Font = UIConstants.get_display_font()
	draw_string(font, Vector2(s.x - 40, 40), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, close_col)

	# Keybind hint
	var mono: Font = UIConstants.get_mono_font()
	draw_string(mono, Vector2(16, s.y - 12), "[TAB] Close    [Hover] Details", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM * 0.6)

# === HEADER ===

func _draw_header(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()

	draw_rect(Rect2(0, 0, s.x, HEADER_H), Color(0.07, 0.09, 0.16, 0.95))
	draw_line(Vector2(0, HEADER_H - 1), Vector2(s.x, HEADER_H - 1), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)

	# Moving accent light
	var header_scan: float = fmod(_time * 90.0, s.x + 200.0) - 100.0
	draw_line(Vector2(header_scan, HEADER_H - 1), Vector2(header_scan + 120.0, HEADER_H - 1), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.5), 2.5)

	# Title with alien glyphs
	var gl: String = UIConstants.random_glyphs(2, _time, 0.0)
	var gr: String = UIConstants.random_glyphs(2, _time, 5.0)
	var title: String = gl + " COLONY INTELLIGENCE " + gr
	draw_string(font, Vector2(24, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_HEADER, UIConstants.TEXT_TITLE)

	# Status indicator
	var status_text: String = "ANALYZING..." if _scan_pulse < 0.5 else "LIVE FEED"
	var status_col: Color = UIConstants.ACCENT if _scan_pulse < 0.5 else UIConstants.STAT_GREEN
	draw_circle(Vector2(s.x - 140, 32), 4.0, status_col * (0.6 + 0.4 * sin(_time * 4.0)))
	draw_string(mono, Vector2(s.x - 128, 36), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, status_col * 0.8)

	# Game time
	var game_time: float = 0.0
	if _stage:
		for child in _stage.get_children():
			if child.has_method("get_game_time"):
				game_time = child.get_game_time()
				break
	var minutes: int = int(game_time) / 60
	var seconds: int = int(game_time) % 60
	draw_string(mono, Vector2(s.x - 280, 36), "T+%02d:%02d" % [minutes, seconds], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_NORMAL)

# === LEFT PANEL: Player Faction ===

func _draw_player_panel(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var px: float = PANEL_PAD
	var pw: float = s.x * 0.48 - PANEL_PAD
	var y: float = HEADER_H + 12.0
	var player_col: Color = FactionData.get_faction_color(0)

	# Section: COLONY STATUS
	var gl: String = UIConstants.random_glyphs(1, _time, 10.0)
	draw_string(mono, Vector2(px, y + 12), gl + " // COLONY STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)
	y += 20

	# Faction name + color indicator
	draw_circle(Vector2(px + 8, y + 8), 6, player_col)
	draw_arc(Vector2(px + 8, y + 8), 6, 0, TAU, 16, player_col * 1.2, 1.5)
	draw_string(font, Vector2(px + 22, y + 14), FactionData.get_faction_name(0) + " — ADAPTIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, UIConstants.TEXT_BRIGHT)
	y += 24

	# Resources bar
	draw_line(Vector2(px, y), Vector2(px + pw, y), Color(0.1, 0.18, 0.28, 0.5), 1.0)
	y += 8
	# Biomass
	draw_circle(Vector2(px + 8, y + 8), 5, Color(0.2, 0.8, 0.4, 0.7))
	draw_string(font, Vector2(px + 18, y + 13), "BIOMASS", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
	draw_string(font, Vector2(px + 90, y + 13), str(_player_biomass), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, UIConstants.STAT_GREEN)
	var inc_bio: String = ("+%d" % _player_income_bio) if _player_income_bio >= 0 else str(_player_income_bio)
	draw_string(mono, Vector2(px + 160, y + 13), "%s/s" % inc_bio, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.25, 0.6, 0.4, 0.7))

	# Genes (same row, offset)
	var gx: float = px + pw * 0.5
	draw_circle(Vector2(gx + 8, y + 8), 5, Color(0.7, 0.3, 1.0, 0.7))
	draw_string(font, Vector2(gx + 18, y + 13), "GENES", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
	draw_string(font, Vector2(gx + 70, y + 13), str(_player_genes), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(0.7, 0.4, 1.0))
	var inc_gen: String = ("+%d" % _player_income_gen) if _player_income_gen >= 0 else str(_player_income_gen)
	draw_string(mono, Vector2(gx + 120, y + 13), "%s/s" % inc_gen, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.5, 0.3, 0.7, 0.7))
	y += 22

	# Supply
	var sup_col: Color = UIConstants.STAT_GREEN if _player_supply.x < _player_supply.y else UIConstants.STAT_RED
	draw_string(font, Vector2(px + 18, y + 13), "SUPPLY", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
	draw_string(font, Vector2(px + 90, y + 13), "%d / %d" % [_player_supply.x, _player_supply.y], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, sup_col)
	# Supply bar
	var bar_x: float = px + 180
	var bar_w: float = pw - 200
	draw_rect(Rect2(bar_x, y + 5, bar_w, 8), Color(0.08, 0.08, 0.1))
	var fill: float = clampf(float(_player_supply.x) / maxf(_player_supply.y, 1), 0.0, 1.0)
	draw_rect(Rect2(bar_x, y + 5, bar_w * fill, 8), sup_col * 0.8)
	draw_rect(Rect2(bar_x, y + 5, bar_w, 8), Color(sup_col.r, sup_col.g, sup_col.b, 0.3), false, 1.0)
	y += 26

	# --- TROOP MANIFEST ---
	draw_line(Vector2(px, y), Vector2(px + pw, y), Color(0.1, 0.18, 0.28, 0.5), 1.0)
	y += 6
	var tgl: String = UIConstants.random_glyphs(1, _time, 20.0)
	draw_string(mono, Vector2(px, y + 12), tgl + " // TROOP MANIFEST", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)
	y += 20

	var unit_names: Array = ["Gatherer", "Warrior", "Tank", "Scout", "Spitter"]
	var unit_icons: Array = [
		Color(0.4, 0.8, 0.4),  # Worker - green
		Color(0.9, 0.4, 0.3),  # Fighter - red
		Color(0.7, 0.65, 0.3), # Defender - gold
		Color(0.3, 0.7, 0.9),  # Scout - cyan
		Color(0.8, 0.4, 0.8),  # Ranged - purple
	]
	var unit_stats: Array = [
		{"hp": 60, "dmg": 5, "spd": 100},
		{"hp": 120, "dmg": 15, "spd": 110},
		{"hp": 220, "dmg": 8, "spd": 70},
		{"hp": 50, "dmg": 6, "spd": 180},
		{"hp": 70, "dmg": 12, "spd": 90},
	]

	for ut in range(5):
		var count: int = _player_units.get(ut, 0)
		var uc: Color = unit_icons[ut]
		var alpha_mul: float = 1.0 if count > 0 else 0.35

		# Unit icon shape
		var icon_cx: float = px + 16
		var icon_cy: float = y + 12
		draw_circle(Vector2(icon_cx, icon_cy), 8, Color(uc.r, uc.g, uc.b, 0.2 * alpha_mul))
		draw_arc(Vector2(icon_cx, icon_cy), 8, 0, TAU, 12, Color(uc.r, uc.g, uc.b, 0.6 * alpha_mul), 1.5)
		# First letter inside
		var letter: String = unit_names[ut].substr(0, 1)
		draw_string(mono, Vector2(icon_cx - 4, icon_cy + 4), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(uc.r, uc.g, uc.b, alpha_mul))

		# Name
		draw_string(font, Vector2(px + 32, y + 16), unit_names[ut], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, alpha_mul))

		# Count (large)
		draw_string(font, Vector2(px + 130, y + 16), "x%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(uc.r, uc.g, uc.b, alpha_mul))

		# Micro stat bars (HP / DMG / SPD) - alien numeric readout style
		var stat_x: float = px + 180
		var us: Dictionary = unit_stats[ut]
		# HP micro bar
		var hp_pct: float = float(us["hp"]) / 220.0
		draw_rect(Rect2(stat_x, y + 6, 40, 4), Color(0.06, 0.06, 0.08))
		draw_rect(Rect2(stat_x, y + 6, 40 * hp_pct, 4), Color(UIConstants.STAT_GREEN.r, UIConstants.STAT_GREEN.g, UIConstants.STAT_GREEN.b, 0.6 * alpha_mul))
		# DMG micro bar
		draw_rect(Rect2(stat_x, y + 13, 40, 4), Color(0.06, 0.06, 0.08))
		var dmg_pct: float = float(us["dmg"]) / 20.0
		draw_rect(Rect2(stat_x, y + 13, 40 * dmg_pct, 4), Color(UIConstants.STAT_RED.r, UIConstants.STAT_RED.g, UIConstants.STAT_RED.b, 0.6 * alpha_mul))

		# Alien numeral readout
		var alien_num: String = UIConstants.random_glyphs(1, _time * 0.1, float(ut) * 3.0)
		draw_string(mono, Vector2(stat_x + 46, y + 16), alien_num + str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(uc.r, uc.g, uc.b, 0.5 * alpha_mul))

		y += 26

	# --- STRUCTURES ---
	y += 4
	draw_line(Vector2(px, y), Vector2(px + pw, y), Color(0.1, 0.18, 0.28, 0.5), 1.0)
	y += 6
	var bgl: String = UIConstants.random_glyphs(1, _time, 30.0)
	draw_string(mono, Vector2(px, y + 12), bgl + " // STRUCTURES", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)
	y += 20

	var bldg_names: Array = ["Spawning Pool", "Evolution Chamber", "Membrane Tower", "Bio-Wall", "Nutrient Processor"]
	var bldg_icons: Array = ["S", "E", "T", "W", "N"]
	var bldg_unlocked: Array = [true, false, false, true, false]  # Default unlock state

	# Determine what's unlocked (anything built at least once = unlocked)
	for bt in range(5):
		if _player_buildings.get(bt, {}).get("count", 0) > 0:
			bldg_unlocked[bt] = true
		# Spawning Pool and Bio-Wall always available
		if bt == 0 or bt == 3:
			bldg_unlocked[bt] = true

	for bt in range(5):
		var bd: Dictionary = _player_buildings.get(bt, {"count": 0, "complete": 0})
		var unlocked: bool = bldg_unlocked[bt]
		var alpha_mul: float = 1.0 if unlocked else 0.3

		# Building icon square
		var icon_rect: Rect2 = Rect2(px + 6, y, 18, 18)
		var ic: Color = player_col if unlocked else Color(0.2, 0.2, 0.25)
		draw_rect(icon_rect, Color(ic.r, ic.g, ic.b, 0.15))
		draw_rect(icon_rect, Color(ic.r, ic.g, ic.b, 0.4 * alpha_mul), false, 1.0)
		draw_string(mono, Vector2(px + 10, y + 13), bldg_icons[bt], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(ic.r, ic.g, ic.b, alpha_mul))

		# Name
		var name_text: String = bldg_names[bt] if unlocked else "??? LOCKED"
		draw_string(font, Vector2(px + 30, y + 14), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, alpha_mul))

		# Count
		if unlocked:
			var count_text: String = "%d" % bd["complete"]
			if bd["count"] > bd["complete"]:
				count_text += " (+%d)" % (bd["count"] - bd["complete"])
			draw_string(font, Vector2(px + 190, y + 14), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(player_col.r, player_col.g, player_col.b, alpha_mul))
		else:
			draw_string(mono, Vector2(px + 190, y + 14), UIConstants.random_glyphs(3, _time, float(bt)), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.25, 0.25, 0.3))

		y += 22

	# --- COMBAT READINESS ---
	y += 4
	draw_line(Vector2(px, y), Vector2(px + pw, y), Color(0.1, 0.18, 0.28, 0.5), 1.0)
	y += 6
	var cgl: String = UIConstants.random_glyphs(1, _time, 40.0)
	draw_string(mono, Vector2(px, y + 12), cgl + " // COMBAT READINESS", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)
	y += 22

	# Army power gauge
	var army_power: float = _player_total_damage * 2.0 + _player_total_hp * 0.3
	var power_max: float = 5000.0  # Rough scale
	var power_pct: float = clampf(army_power / power_max, 0.0, 1.0)
	draw_string(font, Vector2(px + 10, y + 14), "ARMY POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
	var power_bar_x: float = px + 110
	var power_bar_w: float = pw - 140
	draw_rect(Rect2(power_bar_x, y + 4, power_bar_w, 10), Color(0.06, 0.06, 0.08))
	# Gradient fill: green -> yellow -> red
	var power_col: Color = UIConstants.STAT_GREEN if power_pct < 0.4 else UIConstants.STAT_YELLOW if power_pct < 0.75 else Color(1.0, 0.5, 0.2)
	draw_rect(Rect2(power_bar_x, y + 4, power_bar_w * power_pct, 10), power_col * 0.8)
	draw_rect(Rect2(power_bar_x, y + 4, power_bar_w, 10), Color(power_col.r, power_col.g, power_col.b, 0.3), false, 1.0)
	# Numeric readout
	draw_string(mono, Vector2(power_bar_x + power_bar_w + 6, y + 14), "%d" % int(army_power), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, power_col)

	y += 20
	# Win probability
	var win_pct: float = _faction_strengths[0] * 100.0
	var win_col: Color = UIConstants.STAT_GREEN if win_pct > 35 else UIConstants.STAT_YELLOW if win_pct > 20 else UIConstants.STAT_RED
	draw_string(font, Vector2(px + 10, y + 14), "WIN PROBABILITY", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
	draw_string(font, Vector2(px + 140, y + 14), "%.0f%%" % win_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, win_col)
	# Fluctuation indicator
	var fluct: float = sin(_time * 2.3) * 2.0
	var fluct_text: String = ("+" if fluct >= 0 else "") + "%.1f" % fluct
	draw_string(mono, Vector2(px + 200, y + 14), fluct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(win_col.r, win_col.g, win_col.b, 0.5))

# === RIGHT PANEL: Enemy Factions ===

func _draw_enemy_panel(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var rx: float = s.x * 0.52
	var rw: float = s.x - rx - PANEL_PAD
	var y: float = HEADER_H + 12.0

	var egl: String = UIConstants.random_glyphs(1, _time, 50.0)
	draw_string(mono, Vector2(rx, y + 12), egl + " // RIVAL FACTIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)
	y += 22

	for i in range(_enemy_data.size()):
		var ed: Dictionary = _enemy_data[i]
		var fc: Color = ed["color"]
		var is_hovered: bool = _hover_faction == i
		var panel_h: float = 110.0
		var panel_rect: Rect2 = Rect2(rx, y, rw - 20, panel_h)

		# Panel background
		var bg_alpha: float = 0.12 if is_hovered else 0.06
		if ed["eliminated"]:
			bg_alpha *= 0.4
		draw_rect(panel_rect, Color(fc.r, fc.g, fc.b, bg_alpha))
		draw_rect(panel_rect, Color(fc.r, fc.g, fc.b, 0.25 if is_hovered else 0.12), false, 1.0)

		if ed["eliminated"]:
			# Big ELIMINATED stamp
			draw_string(font, Vector2(rx + 10, y + 20), ed["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, Color(fc.r, fc.g, fc.b, 0.3))
			draw_string(font, Vector2(rx + 10, y + 50), "ELIMINATED", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_HEADER, Color(0.9, 0.2, 0.2, 0.6))
			# Diagonal strikethrough
			draw_line(Vector2(rx, y), Vector2(rx + rw - 20, y + panel_h), Color(0.9, 0.2, 0.2, 0.15), 2.0)
			draw_line(Vector2(rx + rw - 20, y), Vector2(rx, y + panel_h), Color(0.9, 0.2, 0.2, 0.15), 2.0)
			y += panel_h + 10
			continue

		# Faction header
		draw_circle(Vector2(rx + 14, y + 16), 7, Color(fc.r, fc.g, fc.b, 0.4))
		draw_arc(Vector2(rx + 14, y + 16), 7, 0, TAU, 12, fc, 1.5)
		draw_string(font, Vector2(rx + 28, y + 21), ed["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, Color(fc.r, fc.g, fc.b, 0.95))

		# Alien designation text
		var designation: String = UIConstants.random_glyphs(4, _time * 0.05, float(ed["faction_id"]) * 7.0)
		draw_string(mono, Vector2(rx + rw - 80, y + 18), designation, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(fc.r, fc.g, fc.b, 0.25))

		# Unit counts
		var cy: float = y + 34
		draw_string(mono, Vector2(rx + 10, cy + 12), "UNITS", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
		draw_string(font, Vector2(rx + 60, cy + 12), str(ed["unit_count"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, fc)
		draw_string(mono, Vector2(rx + 90, cy + 12), "(%dW / %dC)" % [ed["worker_count"], ed["combat_count"]], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(fc.r, fc.g, fc.b, 0.5))
		cy += 18

		# Buildings
		draw_string(mono, Vector2(rx + 10, cy + 12), "BASES", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
		draw_string(font, Vector2(rx + 60, cy + 12), str(ed["building_count"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, fc)
		cy += 18

		# Strength bar
		draw_string(mono, Vector2(rx + 10, cy + 12), "POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
		var str_pct: float = _faction_strengths[ed["faction_id"]] + _strength_noise[ed["faction_id"]]
		var str_bar_x: float = rx + 60
		var str_bar_w: float = rw - 110
		draw_rect(Rect2(str_bar_x, cy + 4, str_bar_w, 8), Color(0.06, 0.06, 0.08))
		draw_rect(Rect2(str_bar_x, cy + 4, str_bar_w * clampf(str_pct * 3.0, 0.0, 1.0), 8), Color(fc.r, fc.g, fc.b, 0.7))
		draw_rect(Rect2(str_bar_x, cy + 4, str_bar_w, 8), Color(fc.r, fc.g, fc.b, 0.2), false, 1.0)
		draw_string(mono, Vector2(str_bar_x + str_bar_w + 6, cy + 13), "%.0f%%" % (str_pct * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, fc)

		# Threat assessment (if hovered)
		if is_hovered:
			cy += 18
			var threat: String = "MINIMAL" if str_pct < 0.15 else "LOW" if str_pct < 0.25 else "MODERATE" if str_pct < 0.35 else "HIGH"
			var threat_col: Color = UIConstants.STAT_GREEN if str_pct < 0.2 else UIConstants.STAT_YELLOW if str_pct < 0.3 else UIConstants.STAT_RED
			draw_string(mono, Vector2(rx + 10, cy + 12), "THREAT: ", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)
			draw_string(font, Vector2(rx + 70, cy + 12), threat, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, threat_col)

		y += panel_h + 10

# === BOTTOM: Strength Pie Chart ===

func _draw_strength_pie(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var cx: float = s.x * 0.5
	var cy: float = s.y - PIE_Y_OFFSET

	# Label
	var pgl: String = UIConstants.random_glyphs(1, _time, 60.0)
	draw_string(mono, Vector2(cx - 100, cy - PIE_RADIUS - 20), pgl + " // DOMINANCE INDEX", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)

	# Outer ring decorative
	draw_arc(Vector2(cx, cy), PIE_RADIUS + 12, 0, TAU, 48, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.12), 1.0)
	draw_arc(Vector2(cx, cy), PIE_RADIUS + 16, 0, TAU, 48, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.06), 1.0)

	# Rotating tick marks on outer ring
	for t in range(24):
		var tick_angle: float = TAU * float(t) / 24.0 + _pie_rotation
		var inner_r: float = PIE_RADIUS + 10
		var outer_r: float = PIE_RADIUS + (18 if t % 6 == 0 else 14)
		var tick_alpha: float = 0.15 if t % 6 == 0 else 0.08
		draw_line(
			Vector2(cx + cos(tick_angle) * inner_r, cy + sin(tick_angle) * inner_r),
			Vector2(cx + cos(tick_angle) * outer_r, cy + sin(tick_angle) * outer_r),
			Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, tick_alpha), 1.0
		)

	# Draw pie segments
	var faction_colors: Array = [
		FactionData.get_faction_color(0),
		FactionData.get_faction_color(1),
		FactionData.get_faction_color(2),
		FactionData.get_faction_color(3),
	]
	var faction_names: Array = [
		FactionData.get_faction_name(0),
		FactionData.get_faction_name(1),
		FactionData.get_faction_name(2),
		FactionData.get_faction_name(3),
	]

	var start_angle: float = -PI * 0.5 + _pie_rotation * 0.3  # Slow rotation
	for i in range(4):
		var pct: float = _faction_strengths[i] + _strength_noise[i]
		if pct <= 0.005:
			continue
		var sweep: float = pct * TAU
		var end_angle: float = start_angle + sweep
		var fc: Color = faction_colors[i]

		# Draw filled pie segment (using polygon approximation)
		var pts: PackedVector2Array = PackedVector2Array()
		pts.append(Vector2(cx, cy))
		var num_steps: int = maxi(int(sweep / 0.05), 3)
		for step in range(num_steps + 1):
			var a: float = start_angle + sweep * float(step) / float(num_steps)
			pts.append(Vector2(cx + cos(a) * PIE_RADIUS, cy + sin(a) * PIE_RADIUS))
		draw_colored_polygon(pts, Color(fc.r, fc.g, fc.b, 0.35))

		# Arc border
		draw_arc(Vector2(cx, cy), PIE_RADIUS, start_angle, end_angle, maxi(num_steps, 8), Color(fc.r, fc.g, fc.b, 0.8), 2.5)

		# Percentage label at midpoint of arc
		var mid_angle: float = start_angle + sweep * 0.5
		var label_r: float = PIE_RADIUS + 26
		var label_pos: Vector2 = Vector2(cx + cos(mid_angle) * label_r, cy + sin(mid_angle) * label_r)
		var pct_text: String = "%.0f%%" % (pct * 100.0)
		var name_short: String = faction_names[i].substr(0, 3).to_upper()
		var ts: Vector2 = font.get_string_size(pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY)
		draw_string(font, Vector2(label_pos.x - ts.x * 0.5, label_pos.y - 2), pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, fc)
		var ns: Vector2 = mono.get_string_size(name_short, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY)
		draw_string(mono, Vector2(label_pos.x - ns.x * 0.5, label_pos.y + 10), name_short, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(fc.r, fc.g, fc.b, 0.6))

		start_angle = end_angle

	# Center dot
	draw_circle(Vector2(cx, cy), 6, Color(0.06, 0.08, 0.14, 0.95))
	draw_arc(Vector2(cx, cy), 6, 0, TAU, 12, UIConstants.ACCENT_DIM, 1.5)

	# Pulsing scan ring
	var pulse_r: float = PIE_RADIUS * fmod(_time * 0.3, 1.0)
	var pulse_alpha: float = 0.08 * (1.0 - pulse_r / PIE_RADIUS)
	draw_arc(Vector2(cx, cy), pulse_r, 0, TAU, 32, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, pulse_alpha), 1.0)

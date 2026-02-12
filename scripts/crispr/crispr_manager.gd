extends Control
## CRISPR Mutation Workshop — Forge hybrids or Upgrade mutations using gene fragments.
## Fully procedural _draw() UI with sci-fi aesthetic. Two tabs: FORGE and UPGRADE.

signal workshop_closed

enum Tab { FORGE, UPGRADE }

const ALIEN_GLYPHS: Array = [
	"◊", "∆", "Ω", "Σ", "Φ", "Ψ", "λ", "π", "θ", "ξ",
	"╬", "╫", "╪", "┼", "╋", "╂", "╁", "╀", "┿", "┾",
	"⊕", "⊗", "⊙", "⊚", "⊛", "⊜", "⊝", "⊞", "⊟", "⊠",
]

# Layout constants
const TAB_HEIGHT: float = 44.0
const CARD_W: float = 260.0
const CARD_H: float = 72.0
const CARD_GAP: float = 6.0
const SLOT_SIZE: float = 80.0
const SIDEBAR_W: float = 300.0

# State
var _active: bool = false
var _tab: Tab = Tab.FORGE
var _time: float = 0.0
var _scroll_offset: float = 0.0
var _max_scroll: float = 0.0

# Forge state
var _forge_slot_a: Dictionary = {}  # Selected mutation A
var _forge_slot_b: Dictionary = {}  # Selected mutation B
var _forge_preview: Dictionary = {}  # Preview hybrid result
var _forge_viability: float = 0.0
var _forge_result_text: String = ""
var _forge_result_color: Color = Color.WHITE
var _forge_result_timer: float = 0.0
var _forge_flash: float = 0.0

# Upgrade state
var _upgrade_selected: Dictionary = {}  # Mutation selected for upgrade
var _upgrade_result_text: String = ""
var _upgrade_result_color: Color = Color.WHITE
var _upgrade_result_timer: float = 0.0

# Interaction
var _hover_card_idx: int = -1
var _hover_tab: int = -1  # 0=FORGE, 1=UPGRADE
var _hover_forge_btn: bool = false
var _hover_upgrade_btn: bool = false
var _hover_close_btn: bool = false
var _hover_slot: int = -1  # 0=slot_a, 1=slot_b (forge mode)

# Sci-fi animation
var _scan_line_y: float = 0.0
var _helix_phase: float = 0.0
var _glyph_columns: Array = []
var _scifi_initialized: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true  # Always visible within its CanvasLayer; layer toggles

func open() -> void:
	_active = true
	_scroll_offset = 0.0
	_forge_slot_a = {}
	_forge_slot_b = {}
	_forge_preview = {}
	_forge_result_text = ""
	_upgrade_selected = {}
	_upgrade_result_text = ""
	get_tree().paused = false  # Workshop doesn't pause, just overlays
	queue_redraw()

func close() -> void:
	_active = false
	# Hide the parent CanvasLayer
	var parent_layer := get_parent()
	if parent_layer is CanvasLayer:
		parent_layer.visible = false
	workshop_closed.emit()

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_scan_line_y = fmod(_scan_line_y + delta * 60.0, get_viewport_rect().size.y)
	_helix_phase += delta * 0.8
	if _forge_result_timer > 0:
		_forge_result_timer -= delta
	if _upgrade_result_timer > 0:
		_upgrade_result_timer -= delta
	if _forge_flash > 0:
		_forge_flash -= delta
	if not _scifi_initialized:
		_init_glyph_columns()
		_scifi_initialized = true
	for col in _glyph_columns:
		col["y"] += delta * col["speed"]
		if col["y"] > get_viewport_rect().size.y:
			col["y"] = -200.0
	queue_redraw()

func _draw() -> void:
	if not _active:
		return
	var vp := get_viewport_rect().size

	# Dark overlay
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.0, 0.02, 0.06, 0.88))

	# Sci-fi background layers
	_draw_grid(vp)
	_draw_glyph_columns(vp)
	_draw_scan_line(vp)
	_draw_helix_bg(vp)

	# Header bar
	_draw_header(vp)

	# Tab bar
	_draw_tabs(vp)

	# Fragment counter
	_draw_fragment_counter(vp)

	# Main content area
	var content_y: float = TAB_HEIGHT * 2 + 16.0
	if _tab == Tab.FORGE:
		_draw_forge_panel(vp, content_y)
	else:
		_draw_upgrade_panel(vp, content_y)

	# Close button
	_draw_close_button(vp)

	# Flash overlay
	if _forge_flash > 0:
		var flash_a: float = _forge_flash * 0.5
		draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.2, 1.0, 0.4, flash_a))

# --- Sci-Fi Background ---

func _draw_grid(vp: Vector2) -> void:
	var alpha: float = 0.035
	var spacing: int = 50
	for gx in range(0, int(vp.x), spacing):
		draw_line(Vector2(gx, 0), Vector2(gx, vp.y), Color(0.1, 0.4, 0.6, alpha), 0.5)
	for gy in range(0, int(vp.y), spacing):
		draw_line(Vector2(0, gy), Vector2(vp.x, gy), Color(0.1, 0.4, 0.6, alpha), 0.5)

func _draw_scan_line(vp: Vector2) -> void:
	var y: float = _scan_line_y
	draw_line(Vector2(0, y), Vector2(vp.x, y), Color(0.2, 0.7, 1.0, 0.08), 1.0)
	draw_rect(Rect2(0, y - 15, vp.x, 30), Color(0.1, 0.4, 0.8, 0.03))

func _draw_helix_bg(vp: Vector2) -> void:
	var cx: float = vp.x * 0.88
	var amp: float = 30.0
	for i in range(25):
		var y: float = i * (vp.y / 24.0)
		var phase: float = _helix_phase + float(i) * 0.35
		var sx: float = sin(phase) * amp
		var depth: float = cos(phase) * 0.5 + 0.5
		var alpha: float = 0.06 + 0.04 * depth
		var lx: float = cx + sx
		var rx: float = cx - sx
		if i < 24:
			var ny: float = (i + 1) * (vp.y / 24.0)
			var np: float = _helix_phase + float(i + 1) * 0.35
			draw_line(Vector2(lx, y), Vector2(cx + sin(np) * amp, ny), Color(0.2, 0.5, 0.8, alpha), 1.5)
			draw_line(Vector2(rx, y), Vector2(cx - sin(np) * amp, ny), Color(0.2, 0.5, 0.8, alpha), 1.5)
		if depth > 0.3:
			draw_line(Vector2(lx, y), Vector2(rx, y), Color(0.3, 0.7, 0.5, alpha * 0.6), 1.0)

func _init_glyph_columns() -> void:
	_glyph_columns.clear()
	var vp := get_viewport_rect().size
	for i in range(6):
		_glyph_columns.append({
			"x": randf_range(20, vp.x - 20),
			"y": randf_range(-200, vp.y),
			"speed": randf_range(15, 35),
			"glyphs": _random_glyph_string(8),
		})

func _draw_glyph_columns(vp: Vector2) -> void:
	var font := UIConstants.get_display_font()
	for col in _glyph_columns:
		var x: float = col["x"]
		var y: float = col["y"]
		var glyphs: String = col["glyphs"]
		for j in range(glyphs.length()):
			var cy: float = y + j * 18
			if cy < 0 or cy > vp.y:
				continue
			var alpha: float = 0.06 + 0.03 * sin(_time * 0.5 + float(j))
			draw_string(font, Vector2(x, cy), glyphs[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.6, 0.4, alpha))

func _random_glyph_string(length: int) -> String:
	var s: String = ""
	for i in range(length):
		s += str(ALIEN_GLYPHS[randi() % ALIEN_GLYPHS.size()])
	return s

# --- Header & Tabs ---

func _draw_header(vp: Vector2) -> void:
	var font := UIConstants.get_display_font()
	# Header bar
	draw_rect(Rect2(0, 0, vp.x, TAB_HEIGHT), Color(0.02, 0.06, 0.12, 0.95))
	draw_line(Vector2(0, TAB_HEIGHT), Vector2(vp.x, TAB_HEIGHT), Color(0.1, 0.5, 0.8, 0.4), 1.0)

	# Title with glyph
	var glyph: String = str(ALIEN_GLYPHS[int(fmod(_time * 0.3, ALIEN_GLYPHS.size()))])
	var title: String = glyph + " CRISPR MUTATION WORKSHOP " + glyph
	draw_string(font, Vector2(vp.x * 0.5 - 160, 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.3, 0.8, 1.0, 0.95))

func _draw_tabs(vp: Vector2) -> void:
	var font := UIConstants.get_display_font()
	var tab_y: float = TAB_HEIGHT
	var tab_w: float = 160.0

	# FORGE tab
	var forge_x: float = vp.x * 0.5 - tab_w - 4
	var forge_active: bool = _tab == Tab.FORGE
	var forge_bg := Color(0.05, 0.15, 0.25, 0.9) if forge_active else Color(0.03, 0.08, 0.14, 0.7)
	var forge_border := Color(0.2, 0.7, 1.0, 0.6) if forge_active else Color(0.15, 0.4, 0.6, 0.3)
	if _hover_tab == 0 and not forge_active:
		forge_bg = Color(0.04, 0.12, 0.2, 0.85)
	draw_rect(Rect2(forge_x, tab_y, tab_w, TAB_HEIGHT), forge_bg)
	draw_rect(Rect2(forge_x, tab_y, tab_w, 2), forge_border)
	draw_string(font, Vector2(forge_x + 30, tab_y + 28), "FORGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.3, 0.9, 1.0) if forge_active else Color(0.5, 0.6, 0.7))

	# UPGRADE tab
	var upgrade_x: float = vp.x * 0.5 + 4
	var upgrade_active: bool = _tab == Tab.UPGRADE
	var upgrade_bg := Color(0.05, 0.15, 0.25, 0.9) if upgrade_active else Color(0.03, 0.08, 0.14, 0.7)
	var upgrade_border := Color(0.2, 0.7, 1.0, 0.6) if upgrade_active else Color(0.15, 0.4, 0.6, 0.3)
	if _hover_tab == 1 and not upgrade_active:
		upgrade_bg = Color(0.04, 0.12, 0.2, 0.85)
	draw_rect(Rect2(upgrade_x, tab_y, tab_w, TAB_HEIGHT), upgrade_bg)
	draw_rect(Rect2(upgrade_x, tab_y, tab_w, 2), upgrade_border)
	draw_string(font, Vector2(upgrade_x + 22, tab_y + 28), "UPGRADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.3, 0.9, 1.0) if upgrade_active else Color(0.5, 0.6, 0.7))

func _draw_fragment_counter(vp: Vector2) -> void:
	var font := UIConstants.get_display_font()
	var text: String = str(ALIEN_GLYPHS[4]) + " GENE FRAGMENTS: %d" % GameManager.gene_fragments
	var tx: float = vp.x - 280
	draw_rect(Rect2(tx - 8, 8, 270, 28), Color(0.02, 0.08, 0.15, 0.85))
	draw_rect(Rect2(tx - 8, 8, 270, 1), Color(0.2, 0.8, 0.5, 0.4))
	draw_string(font, Vector2(tx, 28), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.9, 0.5, 0.95))

func _draw_close_button(vp: Vector2) -> void:
	var font := UIConstants.get_display_font()
	var bx: float = vp.x - 50
	var by: float = TAB_HEIGHT + 8
	var bg := Color(0.3, 0.1, 0.1, 0.8) if _hover_close_btn else Color(0.15, 0.05, 0.05, 0.7)
	draw_rect(Rect2(bx, by, 40, 28), bg)
	draw_rect(Rect2(bx, by, 40, 1), Color(0.8, 0.3, 0.3, 0.5))
	draw_string(font, Vector2(bx + 10, by + 20), "ESC", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.4, 0.4))

# --- FORGE Panel ---

func _draw_forge_panel(vp: Vector2, start_y: float) -> void:
	var font := UIConstants.get_display_font()
	var mutations: Array = _get_forgeable_mutations()

	# Left panel: mutation list
	var list_x: float = 40.0
	var list_w: float = CARD_W + 20
	var list_y: float = start_y + 8

	draw_string(font, Vector2(list_x, list_y + 14), "YOUR MUTATIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.7, 0.9, 0.8))
	draw_string(font, Vector2(list_x, list_y + 30), "Click to select for forge slots", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.5, 0.6, 0.6))
	list_y += 40

	# Draw mutation cards (scrollable)
	_max_scroll = maxf(0.0, mutations.size() * (CARD_H + CARD_GAP) - (vp.y - list_y - 20))
	for i in range(mutations.size()):
		var cy: float = list_y + i * (CARD_H + CARD_GAP) - _scroll_offset
		if cy < start_y - CARD_H or cy > vp.y:
			continue
		var m: Dictionary = mutations[i]
		var is_hovered: bool = _hover_card_idx == i
		var is_selected_a: bool = not _forge_slot_a.is_empty() and _forge_slot_a.get("id", "") == m.get("id", "")
		var is_selected_b: bool = not _forge_slot_b.is_empty() and _forge_slot_b.get("id", "") == m.get("id", "")
		_draw_mutation_card(Vector2(list_x, cy), m, is_hovered, is_selected_a or is_selected_b, i)

	# Right panel: forge slots + preview
	var panel_x: float = list_x + list_w + 40
	var panel_y: float = start_y + 20

	# Forge slots
	draw_string(font, Vector2(panel_x + 60, panel_y + 14), "FORGE CHAMBER", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.3, 0.8, 1.0, 0.9))
	panel_y += 30

	# Slot A
	_draw_forge_slot(Vector2(panel_x, panel_y), _forge_slot_a, "SLOT A", _hover_slot == 0)
	# "+" symbol
	draw_string(font, Vector2(panel_x + SLOT_SIZE + 18, panel_y + 45), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.3, 0.7, 0.9, 0.7))
	# Slot B
	_draw_forge_slot(Vector2(panel_x + SLOT_SIZE + 50, panel_y), _forge_slot_b, "SLOT B", _hover_slot == 1)

	panel_y += SLOT_SIZE + 20

	# Viability bar
	if not _forge_slot_a.is_empty() and not _forge_slot_b.is_empty():
		_draw_viability_bar(Vector2(panel_x, panel_y), _forge_viability)
		panel_y += 40

		# Preview hybrid
		if not _forge_preview.is_empty():
			draw_string(font, Vector2(panel_x, panel_y + 14), "HYBRID PREVIEW:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.7, 0.9, 0.8))
			panel_y += 20
			_draw_mutation_card(Vector2(panel_x, panel_y), _forge_preview, false, false, -1)
			panel_y += CARD_H + 12

		# Forge button
		var btn_w: float = 200.0
		var btn_h: float = 40.0
		var btn_bg := Color(0.1, 0.3, 0.15, 0.9) if _hover_forge_btn else Color(0.05, 0.2, 0.1, 0.85)
		draw_rect(Rect2(panel_x, panel_y, btn_w, btn_h), btn_bg)
		draw_rect(Rect2(panel_x, panel_y, btn_w, 2), Color(0.2, 0.9, 0.4, 0.6))
		draw_rect(Rect2(panel_x, panel_y + btn_h - 1, btn_w, 1), Color(0.2, 0.9, 0.4, 0.3))
		var btn_glyph: String = str(ALIEN_GLYPHS[int(fmod(_time * 2.0, ALIEN_GLYPHS.size()))])
		draw_string(font, Vector2(panel_x + 20, panel_y + 26), btn_glyph + " INITIATE FORGE " + btn_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 1.0, 0.5, 0.95))

	# Result text
	if _forge_result_timer > 0 and _forge_result_text != "":
		var result_y: float = vp.y - 80
		var result_alpha: float = minf(1.0, _forge_result_timer)
		draw_string(font, Vector2(panel_x, result_y), _forge_result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(_forge_result_color.r, _forge_result_color.g, _forge_result_color.b, result_alpha))

func _draw_forge_slot(pos: Vector2, mutation: Dictionary, label: String, hovered: bool) -> void:
	var font := UIConstants.get_display_font()
	var bg := Color(0.06, 0.12, 0.2, 0.9) if not hovered else Color(0.08, 0.16, 0.25, 0.95)
	draw_rect(Rect2(pos.x, pos.y, SLOT_SIZE, SLOT_SIZE), bg)
	# Border
	var border := Color(0.2, 0.6, 0.9, 0.5) if mutation.is_empty() else Color(0.3, 0.9, 0.5, 0.7)
	draw_rect(Rect2(pos.x, pos.y, SLOT_SIZE, 1), border)
	draw_rect(Rect2(pos.x, pos.y + SLOT_SIZE - 1, SLOT_SIZE, 1), border)
	draw_rect(Rect2(pos.x, pos.y, 1, SLOT_SIZE), border)
	draw_rect(Rect2(pos.x + SLOT_SIZE - 1, pos.y, 1, SLOT_SIZE), border)
	# Label
	draw_string(font, Vector2(pos.x + 4, pos.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.6, 0.8, 0.6))
	if mutation.is_empty():
		draw_string(font, Vector2(pos.x + 14, pos.y + 45), "EMPTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.4, 0.5, 0.5))
	else:
		# Show mutation name
		var name: String = mutation.get("name", "?")
		var tier: int = GameManager.get_mutation_tier(mutation.get("id", ""))
		var tier_color := _tier_color(tier)
		draw_string(font, Vector2(pos.x + 4, pos.y + 20), name, HORIZONTAL_ALIGNMENT_LEFT, int(SLOT_SIZE - 8), 10, Color(0.9, 0.95, 1.0))
		draw_string(font, Vector2(pos.x + 4, pos.y + 36), "T%d" % tier, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tier_color)
		# Stat summary
		var stats: Dictionary = mutation.get("stat", {})
		var sy: float = pos.y + 48
		for key in stats:
			if sy > pos.y + SLOT_SIZE - 8:
				break
			draw_string(font, Vector2(pos.x + 4, sy), "%s: %+.0f%%" % [key.substr(0, 5).to_upper(), stats[key] * 100], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.8, 0.7, 0.7))
			sy += 10

func _draw_viability_bar(pos: Vector2, viability: float) -> void:
	var font := UIConstants.get_display_font()
	var bar_w: float = 200.0
	var bar_h: float = 16.0
	# Background
	draw_rect(Rect2(pos.x, pos.y, bar_w, bar_h), Color(0.08, 0.1, 0.15, 0.8))
	# Fill
	var fill_color: Color
	if viability >= 0.7:
		fill_color = Color(0.2, 0.9, 0.3, 0.8)
	elif viability >= 0.4:
		fill_color = Color(0.9, 0.8, 0.2, 0.8)
	else:
		fill_color = Color(0.9, 0.3, 0.2, 0.8)
	draw_rect(Rect2(pos.x + 1, pos.y + 1, (bar_w - 2) * viability, bar_h - 2), fill_color)
	# Label
	var label: String = "VIABILITY: %.0f%%" % (viability * 100)
	if viability < 0.4:
		label += " [HIGH RISK]"
	draw_string(font, Vector2(pos.x + bar_w + 8, pos.y + 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, fill_color)

# --- UPGRADE Panel ---

func _draw_upgrade_panel(vp: Vector2, start_y: float) -> void:
	var font := UIConstants.get_display_font()
	var mutations: Array = _get_upgradeable_mutations()

	# Left panel: mutation list
	var list_x: float = 40.0
	var list_y: float = start_y + 8

	draw_string(font, Vector2(list_x, list_y + 14), "SELECT MUTATION TO UPGRADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.7, 0.9, 0.8))
	draw_string(font, Vector2(list_x, list_y + 30), "Spend gene fragments to increase tier", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.5, 0.6, 0.6))
	list_y += 40

	_max_scroll = maxf(0.0, mutations.size() * (CARD_H + CARD_GAP) - (vp.y - list_y - 20))
	for i in range(mutations.size()):
		var cy: float = list_y + i * (CARD_H + CARD_GAP) - _scroll_offset
		if cy < start_y - CARD_H or cy > vp.y:
			continue
		var m: Dictionary = mutations[i]
		var is_hovered: bool = _hover_card_idx == i
		var is_selected: bool = not _upgrade_selected.is_empty() and _upgrade_selected.get("id", "") == m.get("id", "")
		_draw_mutation_card(Vector2(list_x, cy), m, is_hovered, is_selected, i)

	# Right panel: upgrade details
	var panel_x: float = list_x + CARD_W + 60
	var panel_y: float = start_y + 20

	if _upgrade_selected.is_empty():
		draw_string(font, Vector2(panel_x + 20, panel_y + 60), "Select a mutation to upgrade", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.5, 0.6, 0.6))
		return

	var mid: String = _upgrade_selected.get("id", "")
	var current_tier: int = GameManager.get_mutation_tier(mid)
	var current_stats: Dictionary = _upgrade_selected.get("stat", {})

	draw_string(font, Vector2(panel_x, panel_y + 14), "MUTATION UPGRADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.3, 0.8, 1.0, 0.9))
	panel_y += 30

	# Current state
	draw_string(font, Vector2(panel_x, panel_y + 14), _upgrade_selected.get("name", "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.95, 1.0))
	panel_y += 20

	# Tier display with stars
	var tier_text: String = "CURRENT TIER: "
	for t in range(3):
		if t < current_tier:
			tier_text += str(ALIEN_GLYPHS[4]) + " "  # Filled
		else:
			tier_text += "- "
	draw_string(font, Vector2(panel_x, panel_y + 14), tier_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, _tier_color(current_tier))
	panel_y += 24

	# Current stats
	draw_string(font, Vector2(panel_x, panel_y + 12), "CURRENT STATS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.6, 0.7, 0.7))
	panel_y += 16
	for key in current_stats:
		draw_string(font, Vector2(panel_x + 8, panel_y + 12), "%s: %+.1f%%" % [key.to_upper(), current_stats[key] * 100], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.8, 0.6, 0.8))
		panel_y += 14
	panel_y += 8

	if current_tier >= 3:
		draw_string(font, Vector2(panel_x, panel_y + 14), "MAX TIER REACHED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.8, 0.2, 0.9))
		return

	# Upgrade preview
	var next_tier: int = current_tier + 1
	var cost: int = ForgeCalculator.get_upgrade_cost(current_tier)
	var next_mult: float = ForgeCalculator.get_tier_multiplier(next_tier)
	var can_afford: bool = GameManager.gene_fragments >= cost

	draw_string(font, Vector2(panel_x, panel_y + 14), "UPGRADE TO TIER %d:" % next_tier, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.7, 0.9, 0.8))
	panel_y += 20

	# Preview upgraded stats
	var base_mut: Dictionary = ForgeCalculator.find_base_mutation(mid)
	var base_stat: Dictionary = base_mut.get("stat", {}) if not base_mut.is_empty() else current_stats
	for key in base_stat:
		var new_val: float = base_stat[key] * next_mult
		var old_val: float = current_stats.get(key, 0.0)
		var diff: float = new_val - old_val
		draw_string(font, Vector2(panel_x + 8, panel_y + 12),
			"%s: %+.1f%% -> %+.1f%% (+%.1f%%)" % [key.to_upper(), old_val * 100, new_val * 100, diff * 100],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.9, 0.5, 0.8))
		panel_y += 14
	panel_y += 12

	# Cost
	var cost_color := Color(0.3, 0.9, 0.5) if can_afford else Color(0.9, 0.3, 0.3)
	draw_string(font, Vector2(panel_x, panel_y + 14), "COST: %d fragments (you have %d)" % [cost, GameManager.gene_fragments],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cost_color)
	panel_y += 24

	# Upgrade button
	if can_afford:
		var btn_w: float = 200.0
		var btn_h: float = 40.0
		var btn_bg := Color(0.1, 0.15, 0.3, 0.9) if _hover_upgrade_btn else Color(0.05, 0.1, 0.2, 0.85)
		draw_rect(Rect2(panel_x, panel_y, btn_w, btn_h), btn_bg)
		draw_rect(Rect2(panel_x, panel_y, btn_w, 2), Color(0.3, 0.5, 1.0, 0.6))
		draw_rect(Rect2(panel_x, panel_y + btn_h - 1, btn_w, 1), Color(0.3, 0.5, 1.0, 0.3))
		var btn_glyph: String = str(ALIEN_GLYPHS[int(fmod(_time * 1.5, ALIEN_GLYPHS.size()))])
		draw_string(font, Vector2(panel_x + 14, panel_y + 26), btn_glyph + " APPLY UPGRADE " + btn_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.7, 1.0, 0.95))
	else:
		draw_string(font, Vector2(panel_x, panel_y + 14), "Insufficient fragments", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.3, 0.3, 0.7))

	# Result text
	if _upgrade_result_timer > 0 and _upgrade_result_text != "":
		panel_y += 50
		var result_alpha: float = minf(1.0, _upgrade_result_timer)
		draw_string(font, Vector2(panel_x, panel_y), _upgrade_result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(_upgrade_result_color.r, _upgrade_result_color.g, _upgrade_result_color.b, result_alpha))

# --- Mutation Card Drawing ---

func _draw_mutation_card(pos: Vector2, mutation: Dictionary, hovered: bool, selected: bool, _idx: int) -> void:
	var font := UIConstants.get_display_font()
	var bg := Color(0.05, 0.1, 0.18, 0.9)
	if selected:
		bg = Color(0.08, 0.18, 0.3, 0.95)
	elif hovered:
		bg = Color(0.06, 0.14, 0.24, 0.92)
	draw_rect(Rect2(pos.x, pos.y, CARD_W, CARD_H), bg)

	# Tier stripe on left
	var tier: int = GameManager.get_mutation_tier(mutation.get("id", ""))
	var forged: bool = mutation.get("forged", false)
	var stripe_color := _tier_color(tier)
	if forged:
		stripe_color = Color(0.9, 0.6, 0.2)  # Gold for forged
	draw_rect(Rect2(pos.x, pos.y, 4, CARD_H), stripe_color)

	# Selection border
	if selected:
		draw_rect(Rect2(pos.x, pos.y, CARD_W, 1), stripe_color.lightened(0.3))
		draw_rect(Rect2(pos.x, pos.y + CARD_H - 1, CARD_W, 1), stripe_color.lightened(0.3))

	# Name
	var name: String = mutation.get("name", "Unknown")
	draw_string(font, Vector2(pos.x + 10, pos.y + 18), name, HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W * 0.6), 13, Color(0.9, 0.95, 1.0, 0.95))

	# Tier badge
	var badge: String = "T%d" % tier
	if forged:
		badge = "FORGED"
	draw_rect(Rect2(pos.x + CARD_W - 50, pos.y + 4, 44, 18), Color(stripe_color.r, stripe_color.g, stripe_color.b, 0.3))
	draw_string(font, Vector2(pos.x + CARD_W - 46, pos.y + 17), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, stripe_color)

	# Description
	var desc: String = mutation.get("desc", "")
	draw_string(font, Vector2(pos.x + 10, pos.y + 34), desc, HORIZONTAL_ALIGNMENT_LEFT, int(CARD_W - 16), 10, Color(0.5, 0.6, 0.7, 0.7))

	# Stats
	var stats: Dictionary = mutation.get("stat", {})
	var sx: float = pos.x + 10
	var sy: float = pos.y + 48
	for key in stats:
		if sx > pos.x + CARD_W - 60:
			break
		var val_text: String = "%s:%+.0f%%" % [key.substr(0, 4).to_upper(), stats[key] * 100]
		draw_string(font, Vector2(sx, sy), val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.8, 0.6, 0.8))
		sx += font.get_string_size(val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 12

	# Affinities
	var affinities: Array = mutation.get("affinities", [])
	if not affinities.is_empty():
		var aff_text: String = ""
		for a in affinities:
			if aff_text != "":
				aff_text += " "
			aff_text += str(a).substr(0, 4).to_upper()
		draw_string(font, Vector2(pos.x + 10, pos.y + CARD_H - 6), aff_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 0.5, 0.7, 0.5))

# --- Data Helpers ---

func _get_forgeable_mutations() -> Array:
	## All active mutations available for forging (need at least 2)
	var result: Array = []
	for m in GameManager.active_mutations:
		result.append(m)
	return result

func _get_upgradeable_mutations() -> Array:
	## All active mutations that can be upgraded (tier < 3)
	var result: Array = []
	for m in GameManager.active_mutations:
		var tier: int = GameManager.get_mutation_tier(m.get("id", ""))
		result.append(m)  # Show all, button disabled if maxed
	return result

func _tier_color(tier: int) -> Color:
	match tier:
		1: return Color(0.4, 0.6, 0.8)
		2: return Color(0.5, 0.8, 1.0)
		3: return Color(1.0, 0.8, 0.2)
		_: return Color(0.5, 0.5, 0.5)

# --- Input Handling ---

func _gui_input(event: InputEvent) -> void:
	if not _active:
		return

	var vp := get_viewport_rect().size

	if event is InputEventMouseMotion:
		_update_hover(event.position, vp)
		accept_event()

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position, vp)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_offset = maxf(0.0, _scroll_offset - 40.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_offset = minf(_max_scroll, _scroll_offset + 40.0)
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("toggle_crispr") or event.is_action_pressed("ui_cancel"):
		close()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()

func _update_hover(mouse_pos: Vector2, vp: Vector2) -> void:
	_hover_card_idx = -1
	_hover_tab = -1
	_hover_forge_btn = false
	_hover_upgrade_btn = false
	_hover_close_btn = false
	_hover_slot = -1

	# Tab hover
	var tab_y: float = TAB_HEIGHT
	var tab_w: float = 160.0
	var forge_x: float = vp.x * 0.5 - tab_w - 4
	var upgrade_x: float = vp.x * 0.5 + 4
	if mouse_pos.y >= tab_y and mouse_pos.y <= tab_y + TAB_HEIGHT:
		if mouse_pos.x >= forge_x and mouse_pos.x <= forge_x + tab_w:
			_hover_tab = 0
		elif mouse_pos.x >= upgrade_x and mouse_pos.x <= upgrade_x + tab_w:
			_hover_tab = 1

	# Close button hover
	var close_x: float = vp.x - 50
	var close_y: float = TAB_HEIGHT + 8
	if mouse_pos.x >= close_x and mouse_pos.x <= close_x + 40 and mouse_pos.y >= close_y and mouse_pos.y <= close_y + 28:
		_hover_close_btn = true

	# Card hover
	var content_y: float = TAB_HEIGHT * 2 + 16.0
	var list_x: float = 40.0
	var list_y: float = content_y + 48
	var mutations: Array = _get_forgeable_mutations() if _tab == Tab.FORGE else _get_upgradeable_mutations()
	for i in range(mutations.size()):
		var cy: float = list_y + i * (CARD_H + CARD_GAP) - _scroll_offset
		if mouse_pos.x >= list_x and mouse_pos.x <= list_x + CARD_W and mouse_pos.y >= cy and mouse_pos.y <= cy + CARD_H:
			_hover_card_idx = i
			break

	# Forge-specific hovers
	if _tab == Tab.FORGE:
		var panel_x: float = list_x + CARD_W + 60
		var panel_y: float = content_y + 50
		# Slot hovers
		if mouse_pos.x >= panel_x and mouse_pos.x <= panel_x + SLOT_SIZE:
			if mouse_pos.y >= panel_y and mouse_pos.y <= panel_y + SLOT_SIZE:
				_hover_slot = 0
		var slot_b_x: float = panel_x + SLOT_SIZE + 50
		if mouse_pos.x >= slot_b_x and mouse_pos.x <= slot_b_x + SLOT_SIZE:
			if mouse_pos.y >= panel_y and mouse_pos.y <= panel_y + SLOT_SIZE:
				_hover_slot = 1
		# Forge button hover (approximate location)
		if not _forge_slot_a.is_empty() and not _forge_slot_b.is_empty():
			var btn_y: float = panel_y + SLOT_SIZE + 20
			if not _forge_preview.is_empty():
				btn_y += 40 + CARD_H + 12
			if mouse_pos.x >= panel_x and mouse_pos.x <= panel_x + 200 and mouse_pos.y >= btn_y and mouse_pos.y <= btn_y + 40:
				_hover_forge_btn = true

	# Upgrade button hover
	if _tab == Tab.UPGRADE and not _upgrade_selected.is_empty():
		var mid: String = _upgrade_selected.get("id", "")
		var current_tier: int = GameManager.get_mutation_tier(mid)
		if current_tier < 3 and GameManager.gene_fragments >= ForgeCalculator.get_upgrade_cost(current_tier):
			var panel_x: float = list_x + CARD_W + 60
			# Approximate button Y based on content
			var approx_btn_y: float = content_y + 280
			if mouse_pos.x >= panel_x and mouse_pos.x <= panel_x + 200 and mouse_pos.y >= approx_btn_y and mouse_pos.y <= approx_btn_y + 60:
				_hover_upgrade_btn = true

func _handle_click(mouse_pos: Vector2, vp: Vector2) -> void:
	# Tab click
	if _hover_tab == 0:
		_tab = Tab.FORGE
		_scroll_offset = 0.0
		_hover_card_idx = -1
		AudioManager.play_ui_select()
		return
	elif _hover_tab == 1:
		_tab = Tab.UPGRADE
		_scroll_offset = 0.0
		_hover_card_idx = -1
		AudioManager.play_ui_select()
		return

	# Close button
	if _hover_close_btn:
		close()
		return

	# Card click
	if _hover_card_idx >= 0:
		var mutations: Array = _get_forgeable_mutations() if _tab == Tab.FORGE else _get_upgradeable_mutations()
		if _hover_card_idx < mutations.size():
			var clicked: Dictionary = mutations[_hover_card_idx]
			if _tab == Tab.FORGE:
				_handle_forge_card_click(clicked)
			else:
				_handle_upgrade_card_click(clicked)
			AudioManager.play_ui_select()
		return

	# Forge slot click (clear)
	if _tab == Tab.FORGE:
		if _hover_slot == 0 and not _forge_slot_a.is_empty():
			_forge_slot_a = {}
			_update_forge_preview()
			AudioManager.play_ui_hover()
			return
		elif _hover_slot == 1 and not _forge_slot_b.is_empty():
			_forge_slot_b = {}
			_update_forge_preview()
			AudioManager.play_ui_hover()
			return

	# Forge button click
	if _tab == Tab.FORGE and _hover_forge_btn:
		_execute_forge()
		return

	# Upgrade button click
	if _tab == Tab.UPGRADE and _hover_upgrade_btn:
		_execute_upgrade()
		return

func _handle_forge_card_click(mutation: Dictionary) -> void:
	var mid: String = mutation.get("id", "")
	# Don't allow same mutation in both slots
	if not _forge_slot_a.is_empty() and _forge_slot_a.get("id", "") == mid:
		_forge_slot_a = {}
		_update_forge_preview()
		return
	if not _forge_slot_b.is_empty() and _forge_slot_b.get("id", "") == mid:
		_forge_slot_b = {}
		_update_forge_preview()
		return

	if _forge_slot_a.is_empty():
		_forge_slot_a = mutation
	elif _forge_slot_b.is_empty():
		_forge_slot_b = mutation
	else:
		# Replace slot A, clear B
		_forge_slot_a = mutation
		_forge_slot_b = {}
	_update_forge_preview()

func _handle_upgrade_card_click(mutation: Dictionary) -> void:
	var mid: String = mutation.get("id", "")
	if not _upgrade_selected.is_empty() and _upgrade_selected.get("id", "") == mid:
		_upgrade_selected = {}  # Deselect
	else:
		_upgrade_selected = mutation

func _update_forge_preview() -> void:
	if _forge_slot_a.is_empty() or _forge_slot_b.is_empty():
		_forge_preview = {}
		_forge_viability = 0.0
		return
	var preview: Dictionary = ForgeCalculator.get_forge_preview(_forge_slot_a, _forge_slot_b)
	_forge_viability = preview.get("viability", 0.0)
	_forge_preview = preview.get("hybrid", {})

func _execute_forge() -> void:
	if _forge_slot_a.is_empty() or _forge_slot_b.is_empty():
		return
	var hybrid: Dictionary = GameManager.forge_mutations(_forge_slot_a, _forge_slot_b)
	if hybrid.is_empty():
		# Forge failed
		_forge_result_text = "FORGE FAILED! Molecular incompatibility caused rejection."
		_forge_result_color = Color(1.0, 0.3, 0.3)
		_forge_result_timer = 3.0
		AudioManager.play_splice_fail()
	else:
		# Forge succeeded
		_forge_result_text = "FORGE SUCCESS! Created: %s" % hybrid.get("name", "?")
		_forge_result_color = Color(0.3, 1.0, 0.5)
		_forge_result_timer = 4.0
		_forge_flash = 0.5
		AudioManager.play_splice_success()
	# Clear slots
	_forge_slot_a = {}
	_forge_slot_b = {}
	_forge_preview = {}
	_forge_viability = 0.0

func _execute_upgrade() -> void:
	if _upgrade_selected.is_empty():
		return
	var mid: String = _upgrade_selected.get("id", "")
	if GameManager.upgrade_mutation(mid):
		var new_tier: int = GameManager.get_mutation_tier(mid)
		_upgrade_result_text = "UPGRADE SUCCESS! %s is now Tier %d" % [_upgrade_selected.get("name", "?"), new_tier]
		_upgrade_result_color = Color(0.4, 0.7, 1.0)
		_upgrade_result_timer = 3.0
		# Refresh selection to show updated stats
		for m in GameManager.active_mutations:
			if m.get("id", "") == mid:
				_upgrade_selected = m
				break
		AudioManager.play_sensory_upgrade()
	else:
		_upgrade_result_text = "UPGRADE FAILED! Insufficient gene fragments."
		_upgrade_result_color = Color(0.9, 0.3, 0.3)
		_upgrade_result_timer = 2.0

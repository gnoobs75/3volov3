extends Control
## Organism Codex: cell stage encyclopedia of all organisms.
## Procedural _draw() UI with alien tablet / blueprint / scanner readout aesthetic.
## Toggle via C key. Shows discovered organisms with descriptions, habits, traits, aggression, abilities.

signal codex_closed

enum Category { ALL, PREY, PREDATOR, HAZARD, BOSS, UTILITY }

const SIDEBAR_W: float = 340.0
const ENTRY_H: float = 60.0
const ENTRY_GAP: float = 3.0
const HEADER_H: float = 60.0
const TAB_H: float = 38.0
const ICON_SIZE: float = 42.0
const DETAIL_PAD: float = 30.0

# All cell stage organisms
const ORGANISM_DATA: Array = [
	# --- PREY ---
	{"id": "food_particle", "name": "Biomolecule", "category": "PREY", "hp": 0, "damage": 0, "speed": 0.0,
	 "aggression": "None", "traits": ["Passive", "Collectible"],
	 "abilities": ["Absorbed by tractor beam", "Provides nutrients"],
	 "habits": "Drifts passively through the cellular soup. The primary food source for all organisms.",
	 "icon_color": [0.3, 0.7, 1.0],
	 "description": "Free-floating biomolecular clusters — amino acids, lipids, and nucleotides. The building blocks of evolution."},

	{"id": "snake_prey", "name": "Flagellate Prey", "category": "PREY", "hp": 10, "damage": 0, "speed": 3.5,
	 "aggression": "None — flees", "traits": ["Evasive", "Fast"],
	 "abilities": ["Schooling behavior", "Sprint when threatened", "Drops nutrients on death"],
	 "habits": "Schools together in loose groups. Scatters explosively when a predator approaches.",
	 "icon_color": [0.2, 0.8, 0.4],
	 "description": "Small flagellated organisms that travel in schools. Quick and evasive, but nutritious when caught."},

	# --- PREDATORS ---
	{"id": "enemy_cell", "name": "Predator Cell", "category": "PREDATOR", "hp": 25, "damage": 10, "speed": 3.0,
	 "aggression": "Moderate — chases on sight", "traits": ["Territorial", "Persistent"],
	 "abilities": ["Chase player on detection", "Contact damage", "Drops nutrients on death"],
	 "habits": "Patrols territory and chases anything smaller. Relentless but not particularly fast.",
	 "icon_color": [0.8, 0.3, 0.2],
	 "description": "Standard predatory cell with a voracious appetite. The most common threat in the primordial soup."},

	{"id": "dart_predator", "name": "Dart Predator", "category": "PREDATOR", "hp": 20, "damage": 15, "speed": 6.0,
	 "aggression": "High — ambush strikes", "traits": ["Fast", "Hit-and-run", "Glass cannon"],
	 "abilities": ["High-speed dart attack", "Retreat after strike", "Very fast movement"],
	 "habits": "Lurks at distance, then rockets forward in a lethal dart. Retreats to recharge after each strike.",
	 "icon_color": [1.0, 0.4, 0.2],
	 "description": "Needle-shaped predator built for speed. Its dart attack is devastating but leaves it vulnerable during cooldown."},

	{"id": "siren_cell", "name": "Siren Cell", "category": "PREDATOR", "hp": 30, "damage": 18, "speed": 4.0,
	 "aggression": "Deceptive — mimics food", "traits": ["Mimic", "Ambush", "Deceptive"],
	 "abilities": ["Disguises as golden food", "Reveals and lunges when close", "Contact damage"],
	 "habits": "Shapeshifts to resemble a valuable food particle. Waits motionless until prey is lured close enough to strike.",
	 "icon_color": [1.0, 0.85, 0.2],
	 "description": "A devious mimic that disguises itself as a golden biomolecule. By the time you notice the deception, it's already lunging."},

	{"id": "splitter_cell", "name": "Splitter Cell", "category": "PREDATOR", "hp": 20, "damage": 8, "speed": 3.5,
	 "aggression": "Moderate — multiplies on death", "traits": ["Resilient", "Self-replicating"],
	 "abilities": ["Splits into 2 on death", "Up to 3 generations", "Each gen smaller and faster"],
	 "habits": "Appears ordinary until killed. Its death triggers binary fission, creating two smaller but faster copies.",
	 "icon_color": [0.6, 0.9, 0.3],
	 "description": "A cell that weaponizes its own death. Each kill spawns two smaller copies, quickly overwhelming careless attackers."},

	{"id": "electric_eel", "name": "Electric Eel", "category": "PREDATOR", "hp": 22, "damage": 12, "speed": 4.5,
	 "aggression": "High — area denial", "traits": ["Electrogenic", "Chain attack"],
	 "abilities": ["Charges bioelectric field", "Chain lightning to 3 targets", "Stuns hit organisms", "Death discharge"],
	 "habits": "Patrols in sinusoidal waves. Charges up crackling electricity before unleashing chain lightning across nearby organisms.",
	 "icon_color": [0.3, 0.7, 1.0],
	 "description": "Serpentine predator with bioelectric organelles. Its chain lightning arcs between multiple targets, making groups especially vulnerable."},

	{"id": "ink_bomber", "name": "Ink Bomber", "category": "PREDATOR", "hp": 18, "damage": 5, "speed": 2.5,
	 "aggression": "Defensive — area denial", "traits": ["Defensive", "Area denial", "Evasive"],
	 "abilities": ["Deploys ink clouds (50% slow)", "Puffs up when alarmed", "Panic ink on hit", "Death ink burst"],
	 "habits": "Drifts serenely until threatened, then puffs up and releases thick ink clouds before fleeing.",
	 "icon_color": [0.15, 0.1, 0.3],
	 "description": "Bulbous organism that expels viscous ink clouds. The ink drastically slows anything caught within it."},

	{"id": "leviathan", "name": "Leviathan", "category": "PREDATOR", "hp": 80, "damage": 20, "speed": 2.0,
	 "aggression": "Extreme — apex predator", "traits": ["Massive", "Vacuum attack", "Slow"],
	 "abilities": ["Vacuum pull attack", "Massive contact damage", "Very high HP", "Drops rare loot"],
	 "habits": "The apex predator of the cell stage. Slowly roams, creating devastating vacuum currents that pull everything toward its maw.",
	 "icon_color": [0.5, 0.2, 0.4],
	 "description": "Enormous, terrifying predator. Its vacuum attack sucks in everything nearby. Best avoided until you've evolved significantly."},

	# --- HAZARDS ---
	{"id": "parasite_organism", "name": "Parasite", "category": "HAZARD", "hp": 15, "damage": 5, "speed": 5.0,
	 "aggression": "Parasitic — attaches", "traits": ["Parasitic", "Adaptive", "Draining"],
	 "abilities": ["Latches onto host", "Drains energy over time", "Adapts to host mutations"],
	 "habits": "Seeks larger organisms to parasitize. Once attached, it drains resources and is difficult to remove.",
	 "icon_color": [0.7, 0.2, 0.5],
	 "description": "Adaptive parasite that latches onto hosts and siphons their energy. Evolves countermeasures against host defenses."},

	{"id": "danger_zone", "name": "Danger Zone", "category": "HAZARD", "hp": 0, "damage": 8, "speed": 0.0,
	 "aggression": "Environmental", "traits": ["Static", "Area damage", "Periodic"],
	 "abilities": ["Pulsing damage field", "Visual warning glow", "Cannot be destroyed"],
	 "habits": "A fixed hazardous region of concentrated toxins. Pulses with damaging energy at regular intervals.",
	 "icon_color": [0.9, 0.3, 0.1],
	 "description": "Toxic environmental hazard zone. The pulsing red glow warns of periodic bursts of cellular damage."},

	# --- UTILITY ---
	{"id": "repeller", "name": "Anemone", "category": "UTILITY", "hp": 0, "damage": 0, "speed": 0.0,
	 "aggression": "None — defensive aura", "traits": ["Stationary", "Repulsive field", "Parasite cleanse"],
	 "abilities": ["Repels nearby organisms", "Strips parasites on contact", "Cannot be destroyed"],
	 "habits": "A stationary organism that projects a powerful repulsive field, pushing away anything that approaches.",
	 "icon_color": [0.4, 0.8, 0.7],
	 "description": "Sessile anemone-like organism with a repulsive force field. Useful for shaking off parasites and deflecting enemies."},

	{"id": "kin_organism", "name": "Kin Cell", "category": "UTILITY", "hp": 20, "damage": 5, "speed": 3.0,
	 "aggression": "Friendly — allies", "traits": ["Allied", "Supportive", "Social"],
	 "abilities": ["Follows player loosely", "Attacks nearby enemies", "Slows Juggernaut boss"],
	 "habits": "Friendly organisms of the same species. Loosely follow the player and harass nearby threats.",
	 "icon_color": [0.3, 0.9, 0.7],
	 "description": "Friendly kin organisms that recognize you as their own. They'll follow you and help attack threats."},

	# --- BOSSES ---
	{"id": "oculus_titan", "name": "Oculus Titan", "category": "BOSS", "hp": 200, "damage": 10, "speed": 1.5,
	 "aggression": "Passive until provoked", "traits": ["Multi-eyed", "Beam-vulnerable", "Massive"],
	 "abilities": ["Covered in beamable eyes", "Invincible to normal damage", "Thrashes when 50% eyes removed", "Each eye drops nutrients"],
	 "habits": "A colossal all-seeing organism. Its many eyes are its weakness — each can be ripped off with the tractor beam.",
	 "icon_color": [0.9, 0.3, 0.3],
	 "description": "Towering boss covered in watchful eyes. Immune to direct attacks — you must use your tractor beam to peel off each eye one by one. Spawns after 3rd evolution."},

	{"id": "juggernaut", "name": "Juggernaut", "category": "BOSS", "hp": 300, "damage": 25, "speed": 4.0,
	 "aggression": "Berserk — relentless charger", "traits": ["Armored", "Unstoppable", "Charge attack"],
	 "abilities": ["8 armor plates", "Immune to direct damage", "Relentless charge", "Armor stripped by anemones", "Slowed by kin"],
	 "habits": "An armored juggernaut that charges relentlessly. Its armor can only be stripped by kiting it through anemone fields.",
	 "icon_color": [0.6, 0.4, 0.2],
	 "description": "Heavily armored berserker. Cannot be damaged directly — lure it through anemones to strip its plates, and call kin allies for help. Spawns after 6th evolution."},

	{"id": "basilisk", "name": "Basilisk", "category": "BOSS", "hp": 150, "damage": 15, "speed": 1.0,
	 "aggression": "Calculated — ranged attacker", "traits": ["Armored front", "Rear vulnerable", "Ranged"],
	 "abilities": ["Front shield deflects damage", "Fires toxic spine bursts", "Vulnerable only from behind", "Slow turner"],
	 "habits": "A calculating sniper with an impenetrable front shield. Circles slowly, firing spine volleys. Attack from behind.",
	 "icon_color": [0.5, 0.2, 0.6],
	 "description": "Slow but deadly ranged boss. Its front is completely armored — you must circle behind it and strike its vulnerable rear with jets or spikes. Spawns after 9th evolution."},
]

# State
var _active: bool = false
var _time: float = 0.0
var _scroll_offset: float = 0.0
var _max_scroll: float = 0.0
var _selected_idx: int = -1
var _category: Category = Category.ALL
var _hover_entry: int = -1
var _hover_tab: int = -1
var _hover_close: bool = false
var _filtered_entries: Array = []
var _glyph_columns: Array = []
var _detail_scroll: float = 0.0
var _scan_pulse: float = 0.0  # Animated scanner pulse

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	_glyph_columns = UIConstants.create_glyph_columns(6)

func toggle() -> void:
	_active = not _active
	visible = _active
	set_process(_active)
	if _active:
		_rebuild_filtered()
		_selected_idx = -1
		_scroll_offset = 0.0
		_detail_scroll = 0.0
		queue_redraw()
	else:
		codex_closed.emit()

func _rebuild_filtered() -> void:
	_filtered_entries.clear()
	for i in range(ORGANISM_DATA.size()):
		var entry: Dictionary = ORGANISM_DATA[i]
		if _category != Category.ALL:
			var cat_name: String = Category.keys()[_category]
			if entry.category != cat_name:
				continue
		_filtered_entries.append(i)
	_max_scroll = maxf(0.0, _filtered_entries.size() * (ENTRY_H + ENTRY_GAP) - (size.y - HEADER_H - TAB_H - 80.0))

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_scan_pulse = fmod(_time * 0.8, 1.0)
	# Animate glyph columns
	for col in _glyph_columns:
		col.offset += col.speed * delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_offset = maxf(_scroll_offset - 35.0, 0.0)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_offset = minf(_scroll_offset + 35.0, _max_scroll)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				accept_event()
				_handle_click(mb.position)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_handle_hover(mm.position)
		accept_event()

func _handle_click(pos: Vector2) -> void:
	if _hover_close:
		toggle()
		return
	if _hover_tab >= 0:
		_category = _hover_tab as Category
		_scroll_offset = 0.0
		_selected_idx = -1
		_rebuild_filtered()
		return
	if _hover_entry >= 0 and _hover_entry < _filtered_entries.size():
		var data_idx: int = _filtered_entries[_hover_entry]
		var entry: Dictionary = ORGANISM_DATA[data_idx]
		if GameManager.is_creature_discovered(entry.id):
			_selected_idx = data_idx
			_detail_scroll = 0.0

func _handle_hover(pos: Vector2) -> void:
	_hover_entry = -1
	_hover_tab = -1
	_hover_close = false

	var close_rect: Rect2 = Rect2(size.x - 54, 10, 44, 44)
	if close_rect.has_point(pos):
		_hover_close = true
		return

	var tab_y: float = HEADER_H
	var tab_w: float = SIDEBAR_W / Category.size()
	for i in range(Category.size()):
		var tab_rect: Rect2 = Rect2(16 + i * tab_w, tab_y, tab_w - 2, TAB_H)
		if tab_rect.has_point(pos):
			_hover_tab = i
			return

	var list_y_start: float = HEADER_H + TAB_H + 10.0
	if pos.x >= 16 and pos.x <= 16 + SIDEBAR_W:
		var rel_y: float = pos.y - list_y_start + _scroll_offset
		if rel_y >= 0:
			var idx: int = int(rel_y / (ENTRY_H + ENTRY_GAP))
			if idx >= 0 and idx < _filtered_entries.size():
				var entry_top: float = idx * (ENTRY_H + ENTRY_GAP)
				if rel_y - entry_top < ENTRY_H:
					_hover_entry = idx

# ======================== DRAWING ========================

func _draw() -> void:
	if not _active:
		return
	var s: Vector2 = size

	# Background — dark tablet
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.01, 0.02, 0.04, 0.96))

	# Blueprint grid
	UIConstants.draw_blueprint_grid(self, s, 0.4)

	# Glyph columns (faint alien text in background)
	UIConstants.draw_glyph_columns(self, s, _glyph_columns, 0.3)

	# Scan line (horizontal sweep)
	var scan_y: float = fmod(_time * 60.0, s.y)
	UIConstants.draw_scan_line(self, s, scan_y, _time, 0.5)

	# Vignette
	UIConstants.draw_vignette(self, s, 0.8)

	# Header bar
	_draw_header(s)

	# Category tabs
	_draw_tabs(s)

	# Sidebar: organism list
	_draw_sidebar(s)

	# Separator
	var sep_x: float = SIDEBAR_W + 26
	draw_line(Vector2(sep_x, HEADER_H + 5), Vector2(sep_x, s.y - 5), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.25), 1.0)
	# Separator glow pulse
	var glow_y: float = fmod(_time * 40.0, s.y - HEADER_H) + HEADER_H
	draw_line(Vector2(sep_x, glow_y - 20), Vector2(sep_x, glow_y + 20), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.4), 2.0)

	# Detail panel
	_draw_detail_panel(sep_x + DETAIL_PAD)

	# Corner frame
	UIConstants.draw_corner_frame(self, Rect2(4, 4, s.x - 8, s.y - 8), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.35))

	# Close button
	var close_col: Color = Color(0.9, 0.3, 0.3, 0.9) if _hover_close else Color(0.4, 0.25, 0.25, 0.7)
	draw_rect(Rect2(s.x - 54, 10, 44, 44), close_col * 0.2)
	draw_rect(Rect2(s.x - 54, 10, 44, 44), close_col, false, 1.5)
	var font: Font = UIConstants.get_display_font()
	draw_string(font, Vector2(s.x - 40, 40), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, close_col)

	# Keybind hint
	var mono: Font = UIConstants.get_mono_font()
	draw_string(mono, Vector2(16, s.y - 12), "[C] Close    [Scroll] Navigate    [Click] Select", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM * 0.6)

func _draw_header(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()

	# Header background
	draw_rect(Rect2(0, 0, s.x, HEADER_H), Color(0.02, 0.04, 0.08, 0.92))
	draw_line(Vector2(0, HEADER_H - 1), Vector2(s.x, HEADER_H - 1), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)

	# Moving accent light on header bottom
	var header_scan: float = fmod(_time * 100.0, s.x + 200.0) - 100.0
	draw_line(Vector2(header_scan, HEADER_H - 1), Vector2(header_scan + 140.0, HEADER_H - 1), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.6), 2.5)

	# Title with alien glyph accents
	var gl: String = UIConstants.random_glyphs(2, _time, 0.0)
	var gr: String = UIConstants.random_glyphs(2, _time, 5.0)
	var title: String = gl + " ORGANISM CODEX " + gr
	draw_string(font, Vector2(24, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_HEADER, UIConstants.TEXT_TITLE)

	# Scanner status indicator
	var status_text: String = "SCANNING..." if _scan_pulse < 0.5 else "READY"
	var status_col: Color = UIConstants.ACCENT if _scan_pulse < 0.5 else UIConstants.STAT_GREEN
	draw_circle(Vector2(s.x - 120, 32), 4.0, status_col * (0.6 + 0.4 * sin(_time * 4.0)))
	draw_string(mono, Vector2(s.x - 110, 36), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, status_col * 0.8)

	# Discovered count
	var total: int = ORGANISM_DATA.size()
	var found: int = 0
	for entry in ORGANISM_DATA:
		if GameManager.is_creature_discovered(entry.id):
			found += 1
	var count_text: String = "%d/%d CATALOGED" % [found, total]
	draw_string(mono, Vector2(s.x - 280, 36), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_NORMAL)

func _draw_tabs(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var tab_y: float = HEADER_H
	var tab_w: float = SIDEBAR_W / Category.size()

	for i in range(Category.size()):
		var tab_name: String = Category.keys()[i]
		var tab_rect: Rect2 = Rect2(16 + i * tab_w, tab_y, tab_w - 2, TAB_H)
		var is_active: bool = i == _category
		var is_hovered: bool = _hover_tab == i

		var tab_bg: Color = Color(0.08, 0.18, 0.28) if is_active else Color(0.02, 0.05, 0.08)
		if is_hovered and not is_active:
			tab_bg = tab_bg.lightened(0.12)
		draw_rect(tab_rect, tab_bg)

		# Active tab accent line
		if is_active:
			draw_line(Vector2(tab_rect.position.x, tab_rect.end.y - 1), Vector2(tab_rect.end.x, tab_rect.end.y - 1), UIConstants.ACCENT, 2.0)

		draw_rect(tab_rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.2), false, 1.0)

		var text_col: Color = UIConstants.TEXT_BRIGHT if is_active else UIConstants.TEXT_DIM
		draw_string(font, Vector2(tab_rect.position.x + 6, tab_rect.position.y + 26), tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_col)

func _draw_sidebar(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var list_y: float = HEADER_H + TAB_H + 10.0

	for fi in range(_filtered_entries.size()):
		var data_idx: int = _filtered_entries[fi]
		var entry: Dictionary = ORGANISM_DATA[data_idx]
		var ey: float = list_y + fi * (ENTRY_H + ENTRY_GAP) - _scroll_offset

		if ey + ENTRY_H < list_y or ey > s.y:
			continue

		var discovered: bool = GameManager.is_creature_discovered(entry.id)
		var is_selected: bool = data_idx == _selected_idx
		var is_hovered: bool = fi == _hover_entry

		# Entry background
		var bg_col: Color = Color(0.03, 0.06, 0.1)
		if is_selected:
			bg_col = Color(0.06, 0.14, 0.22)
		elif is_hovered and discovered:
			bg_col = Color(0.05, 0.1, 0.16)
		draw_rect(Rect2(16, ey, SIDEBAR_W, ENTRY_H), bg_col)

		# Selection indicator bar
		if is_selected:
			draw_rect(Rect2(16, ey, 3, ENTRY_H), UIConstants.ACCENT)

		# Border
		var border_col: Color = UIConstants.ACCENT_DIM if is_selected else Color(0.1, 0.18, 0.25)
		draw_rect(Rect2(16, ey, SIDEBAR_W, ENTRY_H), Color(border_col.r, border_col.g, border_col.b, 0.35), false, 1.0)

		# Icon
		var icon_col: Color
		if discovered:
			var ic: Array = entry.icon_color
			icon_col = Color(ic[0], ic[1], ic[2])
		else:
			icon_col = Color(0.15, 0.15, 0.15)
		var icon_center: Vector2 = Vector2(46, ey + ENTRY_H * 0.5)
		_draw_organism_icon(icon_center, ICON_SIZE * 0.4, icon_col, entry.category, discovered)

		# Name
		var name_text: String = entry.name if discovered else "??? UNKNOWN ???"
		var name_col: Color = Color(0.75, 0.92, 1.0) if discovered else Color(0.25, 0.25, 0.3)
		draw_string(font, Vector2(74, ey + 24), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, name_col)

		# Category + aggression preview
		var cat_col: Color = _category_color(entry.category)
		if discovered:
			draw_string(mono, Vector2(74, ey + 42), entry.category, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, cat_col * 0.7)
			# Threat level dots
			var threat: int = _get_threat_level(entry)
			for t in range(5):
				var dot_col: Color = UIConstants.STAT_RED if t < threat else Color(0.12, 0.12, 0.12)
				draw_circle(Vector2(140 + t * 12, ey + 39), 3.0, dot_col)
		else:
			draw_string(mono, Vector2(74, ey + 42), "UNSCANNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.2, 0.2, 0.2))

		# HP bar (if has HP and discovered)
		if discovered and entry.hp > 0:
			var bar_x: float = 220.0
			var bar_w: float = 110.0
			var bar_h: float = 5.0
			var bar_y: float = ey + ENTRY_H * 0.5 - bar_h * 0.5
			draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.06, 0.06, 0.06))
			var hp_ratio: float = clampf(float(entry.hp) / 300.0, 0.0, 1.0)
			var hp_col: Color = UIConstants.STAT_GREEN.lerp(UIConstants.STAT_RED, 1.0 - hp_ratio)
			draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, bar_h), hp_col)
			draw_string(mono, Vector2(bar_x + bar_w + 6, bar_y + 7), str(entry.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIConstants.TEXT_DIM)

func _draw_detail_panel(x: float) -> void:
	var s: Vector2 = size
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var panel_w: float = s.x - x - DETAIL_PAD

	if _selected_idx < 0 or _selected_idx >= ORGANISM_DATA.size():
		# No selection — show scanner idle
		_draw_idle_scanner(x, panel_w, s)
		return

	var entry: Dictionary = ORGANISM_DATA[_selected_idx]
	var discovered: bool = GameManager.is_creature_discovered(entry.id)
	if not discovered:
		draw_string(font, Vector2(x + 40, s.y * 0.4), "??? — ORGANISM NOT YET SCANNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.35, 0.25, 0.25, 0.6))
		return

	var ic: Array = entry.icon_color
	var icon_col: Color = Color(ic[0], ic[1], ic[2])
	var y: float = HEADER_H + 20.0

	# --- Scanner readout header ---
	# Blueprint box around organism icon
	var icon_box: Rect2 = Rect2(x + 10, y, 70, 70)
	draw_rect(icon_box, Color(0.02, 0.04, 0.08))
	draw_rect(icon_box, Color(icon_col.r, icon_col.g, icon_col.b, 0.3), false, 1.5)
	_draw_organism_icon(Vector2(x + 45, y + 35), 22.0, icon_col, entry.category, true)
	# Corner ticks on icon box
	UIConstants.draw_corner_frame(self, Rect2(icon_box.position.x - 2, icon_box.position.y - 2, icon_box.size.x + 4, icon_box.size.y + 4), Color(icon_col.r, icon_col.g, icon_col.b, 0.5))

	# Name + category
	draw_string(font, Vector2(x + 95, y + 22), entry.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIConstants.TEXT_BRIGHT)
	var cat_col: Color = _category_color(entry.category)
	draw_string(font, Vector2(x + 95, y + 42), entry.category, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cat_col)

	# Aggression badge
	var aggr_text: String = "AGGRESSION: " + entry.aggression
	draw_string(mono, Vector2(x + 95, y + 60), aggr_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.8, 0.5, 0.3))

	y += 80

	# --- Stats section ---
	draw_line(Vector2(x + 5, y), Vector2(x + panel_w - 5, y), Color(0.12, 0.2, 0.3, 0.5), 1.0)
	y += 8
	draw_string(mono, Vector2(x + 10, y + 12), "// BIOMETRIC DATA", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)
	y += 22

	# Stats grid
	var col1_x: float = x + 20
	var col2_x: float = x + panel_w * 0.5

	# HP
	draw_string(mono, Vector2(col1_x, y + 12), "HEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIConstants.TEXT_DIM)
	if entry.hp > 0:
		draw_string(font, Vector2(col1_x, y + 28), str(entry.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIConstants.STAT_GREEN)
		# HP bar
		var hp_bar_w: float = panel_w * 0.35
		draw_rect(Rect2(col1_x, y + 32, hp_bar_w, 4), Color(0.06, 0.06, 0.06))
		var hp_r: float = clampf(float(entry.hp) / 300.0, 0.0, 1.0)
		draw_rect(Rect2(col1_x, y + 32, hp_bar_w * hp_r, 4), UIConstants.STAT_GREEN * 0.8)
	else:
		draw_string(font, Vector2(col1_x, y + 28), "N/A", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIConstants.TEXT_DIM)

	# Damage
	draw_string(mono, Vector2(col2_x, y + 12), "DAMAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIConstants.TEXT_DIM)
	draw_string(font, Vector2(col2_x, y + 28), str(entry.damage), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIConstants.STAT_RED if entry.damage > 0 else UIConstants.TEXT_DIM)

	y += 44

	# Speed
	draw_string(mono, Vector2(col1_x, y + 12), "SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIConstants.TEXT_DIM)
	draw_string(font, Vector2(col1_x, y + 28), "%.1f" % entry.speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.7, 0.9))
	# Speed gauge
	var spd_bar_w: float = panel_w * 0.35
	draw_rect(Rect2(col1_x, y + 32, spd_bar_w, 4), Color(0.06, 0.06, 0.06))
	var spd_r: float = clampf(entry.speed / 8.0, 0.0, 1.0)
	draw_rect(Rect2(col1_x, y + 32, spd_bar_w * spd_r, 4), Color(0.4, 0.7, 0.9, 0.7))

	# Threat level
	draw_string(mono, Vector2(col2_x, y + 12), "THREAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UIConstants.TEXT_DIM)
	var threat: int = _get_threat_level(entry)
	for t in range(5):
		var dot_col: Color = UIConstants.STAT_RED if t < threat else Color(0.1, 0.1, 0.1)
		var dot_r: float = 5.0
		draw_circle(Vector2(col2_x + t * 16 + dot_r, y + 26), dot_r, dot_col)

	y += 48

	# --- Traits section ---
	draw_line(Vector2(x + 5, y), Vector2(x + panel_w - 5, y), Color(0.12, 0.2, 0.3, 0.5), 1.0)
	y += 8
	draw_string(mono, Vector2(x + 10, y + 12), "// TRAIT MARKERS", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)
	y += 22

	var trait_x: float = x + 20
	for trait_name in entry.traits:
		var tw: float = font.get_string_size(trait_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16
		if trait_x + tw > x + panel_w - 10:
			trait_x = x + 20
			y += 26
		# Trait tag pill
		draw_rect(Rect2(trait_x, y, tw, 20), Color(icon_col.r, icon_col.g, icon_col.b, 0.12))
		draw_rect(Rect2(trait_x, y, tw, 20), Color(icon_col.r, icon_col.g, icon_col.b, 0.35), false, 1.0)
		draw_string(font, Vector2(trait_x + 8, y + 14), trait_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(icon_col.r, icon_col.g, icon_col.b, 0.9))
		trait_x += tw + 6

	y += 32

	# --- Abilities section ---
	draw_line(Vector2(x + 5, y), Vector2(x + panel_w - 5, y), Color(0.12, 0.2, 0.3, 0.5), 1.0)
	y += 8
	draw_string(mono, Vector2(x + 10, y + 12), "// ABILITIES", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)
	y += 22

	for ability in entry.abilities:
		# Bullet point
		draw_rect(Rect2(x + 22, y + 4, 6, 6), icon_col * 0.7)
		draw_string(font, Vector2(x + 36, y + 13), ability, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIConstants.TEXT_NORMAL)
		y += 20

	y += 12

	# --- Behavior/Habits section ---
	draw_line(Vector2(x + 5, y), Vector2(x + panel_w - 5, y), Color(0.12, 0.2, 0.3, 0.5), 1.0)
	y += 8
	draw_string(mono, Vector2(x + 10, y + 12), "// BEHAVIORAL ANALYSIS", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)
	y += 22

	var habits_lines: Array = _wrap_text(entry.habits, int(panel_w / 7.5))
	for line in habits_lines:
		draw_string(font, Vector2(x + 20, y + 12), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIConstants.TEXT_NORMAL * 0.9)
		y += 16

	y += 12

	# --- Description section ---
	draw_line(Vector2(x + 5, y), Vector2(x + panel_w - 5, y), Color(0.12, 0.2, 0.3, 0.5), 1.0)
	y += 8
	draw_string(mono, Vector2(x + 10, y + 12), "// FIELD NOTES", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT_DIM)
	y += 22

	var desc_lines: Array = _wrap_text(entry.description, int(panel_w / 7.5))
	for line in desc_lines:
		draw_string(font, Vector2(x + 20, y + 12), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.9))
		y += 16

func _draw_idle_scanner(x: float, panel_w: float, s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var cx: float = x + panel_w * 0.5
	var cy: float = s.y * 0.4

	# Scanner reticle
	var r: float = 60.0 + sin(_time * 2.0) * 5.0
	draw_arc(Vector2(cx, cy), r, 0, TAU, 32, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.15), 1.5)
	draw_arc(Vector2(cx, cy), r * 0.6, 0, TAU, 24, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.1), 1.0)
	# Cross hairs
	var ch_len: float = r * 1.3
	draw_line(Vector2(cx - ch_len, cy), Vector2(cx - r * 0.3, cy), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.12), 1.0)
	draw_line(Vector2(cx + r * 0.3, cy), Vector2(cx + ch_len, cy), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.12), 1.0)
	draw_line(Vector2(cx, cy - ch_len), Vector2(cx, cy - r * 0.3), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.12), 1.0)
	draw_line(Vector2(cx, cy + r * 0.3), Vector2(cx, cy + ch_len), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.12), 1.0)
	# Rotating sweep line
	var sweep_angle: float = fmod(_time * 1.5, TAU)
	var sweep_end: Vector2 = Vector2(cx + cos(sweep_angle) * r, cy + sin(sweep_angle) * r)
	draw_line(Vector2(cx, cy), sweep_end, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.2), 1.5)
	draw_circle(sweep_end, 3.0, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.4))

	draw_string(font, Vector2(cx - 100, cy + r + 30), "SELECT AN ORGANISM", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.5))
	draw_string(mono, Vector2(cx - 80, cy + r + 48), "to view scanner readout", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.3))

	# DNA helix
	_draw_helix(Vector2(cx, cy + r + 100), 70.0)

func _draw_organism_icon(center: Vector2, radius: float, col: Color, category: String, discovered: bool) -> void:
	if not discovered:
		draw_circle(center, radius, Color(0.1, 0.1, 0.1))
		draw_arc(center, radius, 0, TAU, 16, Color(0.2, 0.2, 0.2), 1.0)
		var font: Font = UIConstants.get_display_font()
		draw_string(font, Vector2(center.x - 4, center.y + 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.25, 0.25, 0.25))
		return

	match category:
		"PREY":
			# Diamond
			var pts: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius * 0.7, 0),
				center + Vector2(0, radius),
				center + Vector2(-radius * 0.7, 0),
			])
			draw_colored_polygon(pts, col * 0.3)
			pts.append(pts[0])
			draw_polyline(pts, col * 0.8, 1.5)
		"PREDATOR":
			# Spiky hexagon
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var angle: float = TAU * i / 6.0 - PI * 0.5
				var r: float = radius * (1.0 + 0.25 * float(i % 2))
				pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
			pts.append(pts[0])
			draw_colored_polygon(pts, col * 0.3)
			draw_polyline(pts, col * 0.8, 1.5)
		"HAZARD":
			# Warning triangle
			var pts: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius * 0.9, radius * 0.7),
				center + Vector2(-radius * 0.9, radius * 0.7),
			])
			draw_colored_polygon(pts, col * 0.3)
			pts.append(pts[0])
			draw_polyline(pts, col * 0.8, 1.5)
			draw_string(UIConstants.get_display_font(), Vector2(center.x - 3, center.y + 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
		"BOSS":
			# Crown/star
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var angle: float = TAU * i / 10.0 - PI * 0.5
				var r: float = radius * (1.0 if i % 2 == 0 else 0.5)
				pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
			pts.append(pts[0])
			draw_colored_polygon(pts, col * 0.4)
			draw_polyline(pts, col, 2.0)
		"UTILITY":
			# Peaceful circle with inner ring
			draw_circle(center, radius, col * 0.25)
			draw_arc(center, radius, 0, TAU, 16, col * 0.7, 1.5)
			draw_arc(center, radius * 0.5, 0, TAU, 12, col * 0.4, 1.0)
		_:
			draw_circle(center, radius, col * 0.3)
			draw_arc(center, radius, 0, TAU, 16, col * 0.7, 1.5)

func _draw_helix(center: Vector2, height: float) -> void:
	var steps: int = 28
	for i in range(steps):
		var t: float = float(i) / steps
		var y: float = center.y - height * 0.5 + t * height
		var x1: float = center.x + sin(t * TAU * 2.0 + _time) * 18.0
		var x2: float = center.x - sin(t * TAU * 2.0 + _time) * 18.0
		var alpha: float = 0.12 + sin(t * PI) * 0.12
		draw_circle(Vector2(x1, y), 1.5, Color(0.2, 0.6, 0.4, alpha))
		draw_circle(Vector2(x2, y), 1.5, Color(0.4, 0.6, 0.2, alpha))
		if i % 4 == 0:
			draw_line(Vector2(x1, y), Vector2(x2, y), Color(0.3, 0.5, 0.3, alpha * 0.5), 1.0)

# ======================== HELPERS ========================

func _category_color(cat: String) -> Color:
	match cat:
		"PREY": return Color(0.3, 0.8, 0.4)
		"PREDATOR": return Color(0.8, 0.35, 0.25)
		"HAZARD": return Color(0.9, 0.6, 0.15)
		"BOSS": return Color(0.8, 0.3, 0.8)
		"UTILITY": return Color(0.3, 0.8, 0.7)
	return Color(0.5, 0.5, 0.5)

func _get_threat_level(entry: Dictionary) -> int:
	# 0-5 dots based on combined danger
	var score: float = 0.0
	score += entry.damage * 0.15
	score += entry.speed * 0.2
	if entry.category == "BOSS":
		score += 2.0
	elif entry.category == "HAZARD":
		score += 1.0
	return clampi(int(score), 0, 5)

func _wrap_text(text: String, max_chars: int) -> Array:
	var words: PackedStringArray = text.split(" ")
	var lines: Array = []
	var current_line: String = ""
	for word in words:
		if current_line.length() + word.length() + 1 > max_chars:
			lines.append(current_line)
			current_line = word
		else:
			if current_line.length() > 0:
				current_line += " "
			current_line += word
	if current_line.length() > 0:
		lines.append(current_line)
	return lines

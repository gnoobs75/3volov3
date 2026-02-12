extends Control
## Creature Codex: encyclopedia of all snake stage creatures.
## Procedural _draw() UI. Toggle via TAB. Shows discovered creatures with stats/abilities.
## Categories: Ambient, Enemies, Bosses, Prey.

signal codex_closed

enum Category { ALL, AMBIENT, ENEMIES, BOSSES, PREY, TRAITS }

const SIDEBAR_W: float = 320.0
const ENTRY_H: float = 56.0
const ENTRY_GAP: float = 4.0
const HEADER_H: float = 50.0
const TAB_H: float = 40.0
const ICON_SIZE: float = 40.0

# All creature entries: id, name, category, hp, damage, speed, abilities, biomes, icon_color, description
const CREATURE_DATA: Array = [
	# --- Ambient ---
	{"id": "red_blood_cell", "name": "Red Blood Cell", "category": "AMBIENT", "hp": 0, "damage": 0, "speed": 1.5,
	 "abilities": ["Drift in streams"], "biomes": ["Stomach", "Heart Chamber"],
	 "icon_color": [0.8, 0.15, 0.1], "description": "Disc-shaped cells that drift passively through the bloodstream. Harmless oxygen carriers."},
	{"id": "platelet", "name": "Platelet", "category": "AMBIENT", "hp": 0, "damage": 0, "speed": 0.5,
	 "abilities": ["Float slowly", "Cluster together"], "biomes": ["All biomes"],
	 "icon_color": [0.9, 0.85, 0.6], "description": "Tiny irregular cell fragments. Involved in clotting, but pose no threat."},
	{"id": "microbiome_bacteria", "name": "Microbiome Bacteria", "category": "AMBIENT", "hp": 0, "damage": 0, "speed": 1.0,
	 "abilities": ["Wiggle randomly"], "biomes": ["Stomach", "Intestinal Tract"],
	 "icon_color": [0.4, 0.7, 0.3], "description": "Rod-shaped commensal bacteria. Part of the gut flora, non-threatening."},
	{"id": "cilia_plankton", "name": "Cilia Plankton", "category": "AMBIENT", "hp": 0, "damage": 0, "speed": 0.8,
	 "abilities": ["Pulse upward", "Feathery tendrils"], "biomes": ["Lung Tissue"],
	 "icon_color": [0.6, 0.8, 0.85], "description": "Delicate feathery organisms that float through the alveolar spaces."},

	# --- Prey ---
	{"id": "prey_bug", "name": "Prey Bug", "category": "PREY", "hp": 10, "damage": 0, "speed": 3.0,
	 "abilities": ["Flee from player", "Drop nutrients on death"], "biomes": ["All biomes"],
	 "icon_color": [0.2, 0.8, 0.4], "description": "Small scurrying organisms. Easy prey that flee when approached."},
	{"id": "land_nutrient", "name": "Nutrient Orb", "category": "PREY", "hp": 0, "damage": 0, "speed": 0.0,
	 "abilities": ["Collectible", "Heals on pickup"], "biomes": ["All biomes"],
	 "icon_color": [0.4, 0.7, 0.9], "description": "Glowing biomolecule clusters. Collect to restore health and energy."},
	{"id": "golden_nutrient", "name": "Golden Nutrient", "category": "PREY", "hp": 0, "damage": 0, "speed": 2.0,
	 "abilities": ["3x value", "Flees from player"], "biomes": ["All biomes"],
	 "icon_color": [1.0, 0.85, 0.2], "description": "Rare shimmering orb worth triple. Tries to escape when approached."},

	# --- Enemies ---
	{"id": "white_blood_cell", "name": "White Blood Cell", "category": "ENEMIES", "hp": 40, "damage": 8, "speed": 4.0,
	 "abilities": ["Patrol", "Chase on detection", "Melee attack"], "biomes": ["All biomes"],
	 "icon_color": [0.9, 0.9, 0.85], "description": "The host's primary immune defender. Patrols caves and attacks foreign organisms on sight."},
	{"id": "antibody_flyer", "name": "Antibody Flyer", "category": "ENEMIES", "hp": 25, "damage": 12, "speed": 6.0,
	 "abilities": ["Airborne", "Dive attacks", "Hard to reach"], "biomes": ["All biomes"],
	 "icon_color": [0.7, 0.5, 0.9], "description": "Y-shaped flying antibodies. Circle overhead and dive-bomb with sharp protein tips."},
	{"id": "phagocyte", "name": "Phagocyte", "category": "ENEMIES", "hp": 60, "damage": 5, "speed": 2.5,
	 "abilities": ["Engulf attack", "Damage over time", "High HP"], "biomes": ["Stomach", "Intestinal Tract"],
	 "icon_color": [0.5, 0.7, 0.3], "description": "Massive blob-like cell that engulfs prey. Hard to kill, locks you in place during digestion."},
	{"id": "killer_t_cell", "name": "Killer T-Cell", "category": "ENEMIES", "hp": 25, "damage": 18, "speed": 8.0,
	 "abilities": ["Stealth", "Fast lunge", "High damage", "Retreat"], "biomes": ["Bone Marrow", "Liver"],
	 "icon_color": [0.6, 0.3, 0.7], "description": "Semi-transparent assassin. Stalks in stealth, then lunges with devastating force."},
	{"id": "mast_cell", "name": "Mast Cell", "category": "ENEMIES", "hp": 30, "damage": 10, "speed": 3.0,
	 "abilities": ["Ranged histamine shots", "Keeps distance", "Retreats when close"], "biomes": ["Lung Tissue", "Heart Chamber"],
	 "icon_color": [0.9, 0.5, 0.2], "description": "Round granular cell that fires histamine projectiles from range. Retreats if you close in."},

	# --- Bosses ---
	{"id": "macrophage_queen", "name": "Macrophage Queen", "category": "BOSSES", "hp": 200, "damage": 20, "speed": 5.0,
	 "abilities": ["Ground slam", "Summon minions", "Enrage at 25% HP", "Pseudopod strikes"], "biomes": ["Brain"],
	 "icon_color": [0.9, 0.2, 0.8], "description": "The apex predator of the immune system. Rules the Brain hub with devastating slams and endless minion waves."},
	{"id": "cardiac_colossus", "name": "Cardiac Colossus", "category": "BOSSES", "hp": 250, "damage": 15, "speed": 6.0,
	 "abilities": ["Rhythmic pulse AoE", "Blood wave knockback", "Summon RBC swarms", "Rage mode"], "biomes": ["Heart Chamber"],
	 "icon_color": [0.7, 0.15, 0.12], "description": "Massive pulsing heart creature. Its rhythmic shockwaves push you back relentlessly."},
	{"id": "gut_warden", "name": "Gut Warden", "category": "BOSSES", "hp": 280, "damage": 12, "speed": 5.5,
	 "abilities": ["Acid pools", "Tentacle vines", "Acid spray cone", "Rage mode"], "biomes": ["Intestinal Tract"],
	 "icon_color": [0.45, 0.3, 0.2], "description": "Tentacle-covered guardian that spews acid and drops corrosive pools. Watch where you step."},
	{"id": "alveolar_titan", "name": "Alveolar Titan", "category": "BOSSES", "hp": 220, "damage": 10, "speed": 7.0,
	 "abilities": ["Wind gust knockback", "Oxygen bubble traps", "Inflate/deflate", "Rage mode"], "biomes": ["Lung Tissue"],
	 "icon_color": [0.75, 0.65, 0.7], "description": "Spongy inflatable creature. Powerful wind gusts send you flying, and bubble traps slow your escape."},
	{"id": "marrow_sentinel", "name": "Marrow Sentinel", "category": "BOSSES", "hp": 300, "damage": 20, "speed": 5.0,
	 "abilities": ["Bone spike eruption", "Calcium shield", "Summon T-cells", "Rage mode"], "biomes": ["Bone Marrow"],
	 "icon_color": [0.85, 0.8, 0.65], "description": "Armored bone construct. The hardest boss — temporarily invulnerable behind its calcium shield."},
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

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

func toggle() -> void:
	_active = not _active
	visible = _active
	set_process(_active)
	if _active:
		_rebuild_filtered()
		_selected_idx = -1
		_scroll_offset = 0.0
		queue_redraw()
	else:
		codex_closed.emit()

func _rebuild_filtered() -> void:
	_filtered_entries.clear()
	if _category == Category.TRAITS:
		# TRAITS tab uses its own layout, no creature list needed
		_max_scroll = 0.0
		return
	for i in range(CREATURE_DATA.size()):
		var entry: Dictionary = CREATURE_DATA[i]
		if _category != Category.ALL:
			var cat_name: String = Category.keys()[_category]
			if entry.category != cat_name:
				continue
		_filtered_entries.append(i)
	_max_scroll = maxf(0.0, _filtered_entries.size() * (ENTRY_H + ENTRY_GAP) - (size.y - HEADER_H - TAB_H - 60.0))

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_offset = maxf(_scroll_offset - 30.0, 0.0)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_offset = minf(_scroll_offset + 30.0, _max_scroll)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				accept_event()
				_handle_click(mb.position)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_handle_hover(mm.position)
		accept_event()

func _handle_click(pos: Vector2) -> void:
	# Close button
	if _hover_close:
		toggle()
		return
	# Category tabs
	if _hover_tab >= 0:
		_category = _hover_tab as Category
		_scroll_offset = 0.0
		_selected_idx = -1
		_rebuild_filtered()
		return
	# Trait upgrade buttons (TRAITS tab)
	if _category == Category.TRAITS:
		for trait_id in _trait_upgrade_rects:
			var rect: Rect2 = _trait_upgrade_rects[trait_id]
			if rect.has_point(pos):
				GameManager.upgrade_trait(trait_id)
				return
		return
	# Entry list
	if _hover_entry >= 0 and _hover_entry < _filtered_entries.size():
		var data_idx: int = _filtered_entries[_hover_entry]
		var entry: Dictionary = CREATURE_DATA[data_idx]
		if GameManager.is_creature_discovered(entry.id):
			_selected_idx = data_idx

func _handle_hover(pos: Vector2) -> void:
	_hover_entry = -1
	_hover_tab = -1
	_hover_close = false

	# Close button (top right)
	var close_rect: Rect2 = Rect2(size.x - 50, 5, 40, 40)
	if close_rect.has_point(pos):
		_hover_close = true
		return

	# Category tabs
	var tab_y: float = HEADER_H
	var tab_w: float = SIDEBAR_W / Category.size()
	for i in range(Category.size()):
		var tab_rect: Rect2 = Rect2(20 + i * tab_w, tab_y, tab_w - 2, TAB_H)
		if tab_rect.has_point(pos):
			_hover_tab = i
			return

	# Entry list
	var list_y_start: float = HEADER_H + TAB_H + 10.0
	var list_x: float = 20.0
	if pos.x >= list_x and pos.x <= list_x + SIDEBAR_W - 10.0:
		var rel_y: float = pos.y - list_y_start + _scroll_offset
		if rel_y >= 0:
			var idx: int = int(rel_y / (ENTRY_H + ENTRY_GAP))
			if idx >= 0 and idx < _filtered_entries.size():
				var entry_top: float = idx * (ENTRY_H + ENTRY_GAP)
				if rel_y - entry_top < ENTRY_H:
					_hover_entry = idx

func _draw() -> void:
	if not _active:
		return
	var s: Vector2 = size

	# Background
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.02, 0.03, 0.05, 0.95))

	# Header
	draw_rect(Rect2(0, 0, s.x, HEADER_H), Color(0.05, 0.08, 0.12, 0.9))
	var title_font: Font = UIConstants.get_display_font()
	draw_string(title_font, Vector2(30, 34), "CREATURE CODEX", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIConstants.TEXT_TITLE)

	# Close button
	var close_col: Color = Color(0.9, 0.3, 0.3) if _hover_close else Color(0.5, 0.3, 0.3)
	draw_rect(Rect2(s.x - 50, 5, 40, 40), close_col * 0.3)
	draw_string(title_font, Vector2(s.x - 40, 33), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, close_col)

	# Scan line
	var scan_y: float = fmod(_time * 80.0, s.y)
	draw_line(Vector2(0, scan_y), Vector2(s.x, scan_y), Color(UIConstants.SCAN_LINE_COLOR.r, UIConstants.SCAN_LINE_COLOR.g, UIConstants.SCAN_LINE_COLOR.b, 0.08), 1.0)

	# Category tabs
	var tab_y: float = HEADER_H
	var tab_w: float = SIDEBAR_W / Category.size()
	for i in range(Category.size()):
		var tab_name: String = Category.keys()[i]
		var tab_rect: Rect2 = Rect2(20 + i * tab_w, tab_y, tab_w - 2, TAB_H)
		var tab_col: Color = Color(0.1, 0.2, 0.3) if i == _category else Color(0.04, 0.08, 0.12)
		if _hover_tab == i:
			tab_col = tab_col.lightened(0.15)
		draw_rect(tab_rect, tab_col)
		draw_rect(tab_rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3), false, 1.0)
		draw_string(title_font, Vector2(tab_rect.position.x + 8, tab_rect.position.y + 27), tab_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIConstants.TEXT_NORMAL)

	# --- TRAITS tab: special full-page layout ---
	if _category == Category.TRAITS:
		_draw_traits_panel(title_font)
		return

	# Sidebar: creature list
	var list_y: float = HEADER_H + TAB_H + 10.0
	var clip_rect: Rect2 = Rect2(10, list_y, SIDEBAR_W, s.y - list_y - 10)

	for fi in range(_filtered_entries.size()):
		var data_idx: int = _filtered_entries[fi]
		var entry: Dictionary = CREATURE_DATA[data_idx]
		var ey: float = list_y + fi * (ENTRY_H + ENTRY_GAP) - _scroll_offset
		if ey + ENTRY_H < list_y or ey > s.y:
			continue

		var discovered: bool = GameManager.is_creature_discovered(entry.id)
		var is_selected: bool = data_idx == _selected_idx
		var is_hovered: bool = fi == _hover_entry

		# Entry background
		var bg_col: Color = Color(0.06, 0.1, 0.15)
		if is_selected:
			bg_col = Color(0.1, 0.18, 0.26)
		elif is_hovered:
			bg_col = Color(0.08, 0.14, 0.2)
		draw_rect(Rect2(20, ey, SIDEBAR_W - 10, ENTRY_H), bg_col)
		draw_rect(Rect2(20, ey, SIDEBAR_W - 10, ENTRY_H), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3), false, 1.0)

		# Icon
		var icon_col: Color
		if discovered:
			var ic: Array = entry.icon_color
			icon_col = Color(ic[0], ic[1], ic[2])
		else:
			icon_col = Color(0.2, 0.2, 0.2)
		var icon_center: Vector2 = Vector2(48, ey + ENTRY_H * 0.5)
		_draw_creature_icon(icon_center, ICON_SIZE * 0.4, icon_col, entry.category, discovered)

		# Name
		var name_text: String = entry.name if discovered else "???"
		var name_col: Color = Color(0.7, 0.9, 1.0) if discovered else Color(0.3, 0.3, 0.3)
		draw_string(title_font, Vector2(75, ey + 24), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, name_col)

		# Category tag
		var cat_col: Color = _category_color(entry.category)
		draw_string(title_font, Vector2(75, ey + 44), entry.category, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cat_col * 0.7)

		# HP bar if enemy/boss and discovered
		if discovered and entry.hp > 0:
			var bar_x: float = 200.0
			var bar_w: float = 100.0
			var bar_h: float = 6.0
			var bar_y: float = ey + ENTRY_H * 0.5 - 3
			draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1))
			var hp_ratio: float = clampf(entry.hp / 300.0, 0.0, 1.0)
			var hp_col: Color = Color(0.2, 0.7, 0.3).lerp(Color(0.8, 0.2, 0.1), 1.0 - hp_ratio)
			draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, bar_h), hp_col)

	# Vertical separator
	var sep_x: float = SIDEBAR_W + 30
	draw_line(Vector2(sep_x, HEADER_H + 10), Vector2(sep_x, s.y - 10), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3), 1.0)

	# Detail panel (right side)
	_draw_detail_panel(sep_x + 20, title_font)

func _draw_detail_panel(x: float, font: Font) -> void:
	var s: Vector2 = size
	var panel_w: float = s.x - x - 30

	if _selected_idx < 0 or _selected_idx >= CREATURE_DATA.size():
		# No selection
		draw_string(font, Vector2(x + 40, s.y * 0.4), "Select a creature to view details", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.5))
		# Draw decorative DNA helix
		_draw_helix(Vector2(x + panel_w * 0.5, s.y * 0.5 + 30), 80.0)
		return

	var entry: Dictionary = CREATURE_DATA[_selected_idx]
	var discovered: bool = GameManager.is_creature_discovered(entry.id)
	if not discovered:
		draw_string(font, Vector2(x + 40, s.y * 0.4), "??? — Not yet discovered", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 0.3, 0.3, 0.5))
		return

	var y: float = HEADER_H + 30.0

	# Large icon
	var ic: Array = entry.icon_color
	var icon_col: Color = Color(ic[0], ic[1], ic[2])
	_draw_creature_icon(Vector2(x + 40, y + 20), 25.0, icon_col, entry.category, true)

	# Name
	draw_string(font, Vector2(x + 80, y + 10), entry.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIConstants.TEXT_BRIGHT)
	y += 20

	# Category
	var cat_col: Color = _category_color(entry.category)
	draw_string(font, Vector2(x + 80, y + 16), entry.category, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cat_col)
	y += 35

	# Biomes
	draw_string(font, Vector2(x + 20, y + 16), "BIOMES:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIConstants.TEXT_DIM)
	var biome_str: String = ", ".join(entry.biomes)
	draw_string(font, Vector2(x + 100, y + 16), biome_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIConstants.TEXT_NORMAL)
	y += 30

	# Separator
	draw_line(Vector2(x + 10, y), Vector2(x + panel_w - 10, y), Color(0.15, 0.25, 0.35, 0.4), 1.0)
	y += 15

	# Stats
	draw_string(font, Vector2(x + 20, y + 16), "STATS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIConstants.TEXT_NORMAL)
	y += 28

	# HP
	if entry.hp > 0:
		draw_string(font, Vector2(x + 30, y + 14), "HP: %d" % entry.hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIConstants.TEXT_NORMAL)
		var bar_x: float = x + 120.0
		var bar_w: float = 180.0
		draw_rect(Rect2(bar_x, y + 4, bar_w, 10), Color(0.08, 0.08, 0.08))
		var hp_ratio: float = clampf(entry.hp / 300.0, 0.0, 1.0)
		draw_rect(Rect2(bar_x, y + 4, bar_w * hp_ratio, 10), Color(0.2, 0.7, 0.3))
		y += 22
	else:
		draw_string(font, Vector2(x + 30, y + 14), "HP: N/A", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIConstants.TEXT_DIM)
		y += 22

	# Damage
	draw_string(font, Vector2(x + 30, y + 14), "DMG: %d" % entry.damage, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.5, 0.4))
	y += 22

	# Speed
	draw_string(font, Vector2(x + 30, y + 14), "SPD: %.1f" % entry.speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.7, 0.8))
	y += 30

	# Separator
	draw_line(Vector2(x + 10, y), Vector2(x + panel_w - 10, y), Color(0.15, 0.25, 0.35, 0.4), 1.0)
	y += 15

	# Abilities
	draw_string(font, Vector2(x + 20, y + 16), "ABILITIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIConstants.TEXT_NORMAL)
	y += 28

	for ability in entry.abilities:
		draw_circle(Vector2(x + 35, y + 8), 3.0, icon_col * 0.8)
		draw_string(font, Vector2(x + 48, y + 14), ability, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIConstants.TEXT_NORMAL)
		y += 22

	y += 15

	# Description
	draw_line(Vector2(x + 10, y), Vector2(x + panel_w - 10, y), Color(0.15, 0.25, 0.35, 0.4), 1.0)
	y += 18

	# Word wrap description manually
	var desc: String = entry.description
	var max_chars: int = int(panel_w / 8.0)  # Approximate chars per line
	var lines: Array = _wrap_text(desc, max_chars)
	for line in lines:
		draw_string(font, Vector2(x + 20, y + 14), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.85))
		y += 18

func _draw_creature_icon(center: Vector2, radius: float, col: Color, category: String, discovered: bool) -> void:
	if not discovered:
		draw_circle(center, radius, Color(0.15, 0.15, 0.15))
		draw_arc(center, radius, 0, TAU, 16, Color(0.25, 0.25, 0.25), 1.0)
		return

	match category:
		"AMBIENT":
			# Peaceful circle
			draw_circle(center, radius, col * 0.3)
			draw_arc(center, radius, 0, TAU, 16, col * 0.7, 1.5)
		"PREY":
			# Small diamond
			var pts: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius * 0.7, 0),
				center + Vector2(0, radius),
				center + Vector2(-radius * 0.7, 0),
			])
			draw_colored_polygon(pts, col * 0.4)
			draw_polyline(pts, col * 0.8, 1.5)
		"ENEMIES":
			# Spiky hexagon
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var angle: float = TAU * i / 6.0 - PI * 0.5
				var r: float = radius * (1.0 + 0.2 * float(i % 2))
				pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
			pts.append(pts[0])
			draw_colored_polygon(pts, col * 0.3)
			draw_polyline(pts, col * 0.8, 1.5)
		"BOSSES":
			# Crown/star shape
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var angle: float = TAU * i / 10.0 - PI * 0.5
				var r: float = radius * (1.0 if i % 2 == 0 else 0.5)
				pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
			pts.append(pts[0])
			draw_colored_polygon(pts, col * 0.4)
			draw_polyline(pts, col, 2.0)

func _draw_helix(center: Vector2, height: float) -> void:
	var steps: int = 30
	for i in range(steps):
		var t: float = float(i) / steps
		var y: float = center.y - height * 0.5 + t * height
		var x1: float = center.x + sin(t * TAU * 2.0 + _time) * 20.0
		var x2: float = center.x - sin(t * TAU * 2.0 + _time) * 20.0
		var alpha: float = 0.15 + sin(t * PI) * 0.15
		draw_circle(Vector2(x1, y), 2.0, Color(0.2, 0.6, 0.4, alpha))
		draw_circle(Vector2(x2, y), 2.0, Color(0.4, 0.6, 0.2, alpha))
		if i % 4 == 0:
			draw_line(Vector2(x1, y), Vector2(x2, y), Color(0.3, 0.5, 0.3, alpha * 0.5), 1.0)

func _category_color(cat: String) -> Color:
	match cat:
		"AMBIENT": return Color(0.4, 0.7, 0.8)
		"PREY": return Color(0.3, 0.8, 0.4)
		"ENEMIES": return Color(0.8, 0.4, 0.3)
		"BOSSES": return Color(0.9, 0.6, 0.2)
	return Color(0.5, 0.5, 0.5)

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

# --- TRAITS PANEL ---

var _trait_upgrade_rects: Dictionary = {}  # trait_id -> Rect2 for click handling

func _draw_traits_panel(font: Font) -> void:
	var s: Vector2 = size
	var panel_x: float = 30.0
	var panel_w: float = s.x - 60.0
	var y: float = HEADER_H + TAB_H + 20.0

	# Gene fragments display
	var frag_text: String = "Gene Fragments: %d" % GameManager.gene_fragments
	draw_string(font, Vector2(panel_x, y + 16), frag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIConstants.ACCENT)

	# Equipped trait indicator
	if GameManager.equipped_trait != "":
		var eq_data: Dictionary = BossTraitSystem.get_trait(GameManager.equipped_trait)
		if not eq_data.is_empty():
			var eq_text: String = "Equipped: %s" % eq_data.name
			draw_string(font, Vector2(panel_x + 300, y + 16), eq_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, eq_data.icon_color)
	y += 35.0

	# Separator
	draw_line(Vector2(panel_x, y), Vector2(panel_x + panel_w, y), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)
	y += 15.0

	_trait_upgrade_rects.clear()
	var all_traits: Array = BossTraitSystem.get_all_trait_ids()
	var card_h: float = 130.0
	var card_gap: float = 12.0

	for trait_id in all_traits:
		var tdata: Dictionary = BossTraitSystem.get_trait(trait_id)
		if tdata.is_empty():
			continue

		var unlocked: bool = GameManager.has_trait(trait_id)
		var tier: int = GameManager.get_trait_tier(trait_id)
		var icon_col: Color = tdata.icon_color if unlocked else Color(0.2, 0.2, 0.2)

		# Card background
		var card_rect: Rect2 = Rect2(panel_x, y, panel_w, card_h)
		var bg_col: Color = Color(0.04, 0.08, 0.14) if unlocked else Color(0.04, 0.04, 0.04)
		draw_rect(card_rect, bg_col)
		draw_rect(card_rect, Color(icon_col.r, icon_col.g, icon_col.b, 0.3), false, 1.5)

		# Left: icon shape (boss star)
		var icon_center: Vector2 = Vector2(panel_x + 40, y + card_h * 0.5)
		var icon_r: float = 22.0
		if unlocked:
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var angle: float = TAU * i / 10.0 - PI * 0.5
				var r: float = icon_r * (1.0 if i % 2 == 0 else 0.5)
				pts.append(icon_center + Vector2(cos(angle) * r, sin(angle) * r))
			pts.append(pts[0])
			draw_colored_polygon(pts, icon_col * 0.4)
			draw_polyline(pts, icon_col, 2.0)
		else:
			draw_circle(icon_center, icon_r, Color(0.1, 0.1, 0.1))
			draw_arc(icon_center, icon_r, 0, TAU, 16, Color(0.2, 0.2, 0.2), 1.5)
			draw_string(font, Vector2(panel_x + 30, y + card_h * 0.5 + 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.3, 0.3, 0.3))

		# Trait name + boss source
		var name_x: float = panel_x + 80.0
		var name_col: Color = UIConstants.TEXT_BRIGHT if unlocked else Color(0.35, 0.35, 0.35)
		var display_name: String = tdata.name if unlocked else "???"
		draw_string(font, Vector2(name_x, y + 24), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, name_col)

		var boss_text: String = ("Looted from: %s (%s)" % [tdata.boss, tdata.biome]) if unlocked else "Defeat the boss to unlock"
		var boss_col: Color = UIConstants.TEXT_DIM if unlocked else Color(0.25, 0.25, 0.25)
		draw_string(font, Vector2(name_x, y + 42), boss_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, boss_col)

		if unlocked:
			# Tier pips
			var pip_x: float = name_x
			var pip_y: float = y + 54.0
			draw_string(font, Vector2(pip_x, pip_y + 12), "Tier:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIConstants.TEXT_DIM)
			pip_x += 40.0
			for t in range(1, 4):
				var pip_col: Color = icon_col if t <= tier else Color(0.15, 0.15, 0.15)
				draw_rect(Rect2(pip_x, pip_y + 2, 16, 10), pip_col)
				draw_rect(Rect2(pip_x, pip_y + 2, 16, 10), icon_col * 0.5, false, 1.0)
				pip_x += 22.0

			# Description
			draw_string(font, Vector2(name_x, y + 82), tdata.desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIConstants.TEXT_NORMAL)

			# Stats row
			var stat_y: float = y + 100.0
			var energy_cost: float = BossTraitSystem.get_energy_cost(trait_id)
			var cooldown: float = BossTraitSystem.get_cooldown(trait_id)
			var dmg: float = BossTraitSystem.get_damage(trait_id)

			draw_string(font, Vector2(name_x, stat_y + 12), "Energy: %.0f" % energy_cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.7, 0.9))
			draw_string(font, Vector2(name_x + 110, stat_y + 12), "CD: %.0fs" % cooldown, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.6, 0.3))
			draw_string(font, Vector2(name_x + 200, stat_y + 12), "DMG: %.0f" % dmg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.4, 0.3))

			# Multiplier display
			var mult: float = GameManager.get_trait_multiplier(trait_id)
			if mult > 1.0:
				draw_string(font, Vector2(name_x + 290, stat_y + 12), "x%.1f" % mult, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.8, 0.2))

			# Upgrade button (right side)
			if tier < 3:
				var cost: int = 20 if tier == 1 else 40
				var can_afford: bool = GameManager.gene_fragments >= cost
				var btn_w: float = 140.0
				var btn_h: float = 32.0
				var btn_x: float = panel_x + panel_w - btn_w - 20.0
				var btn_y: float = y + card_h * 0.5 - btn_h * 0.5
				var btn_rect: Rect2 = Rect2(btn_x, btn_y, btn_w, btn_h)

				var btn_col: Color = Color(0.1, 0.3, 0.15) if can_afford else Color(0.08, 0.08, 0.08)
				draw_rect(btn_rect, btn_col)
				var border_col: Color = Color(0.3, 0.8, 0.4, 0.6) if can_afford else Color(0.2, 0.2, 0.2, 0.4)
				draw_rect(btn_rect, border_col, false, 1.5)

				var btn_text: String = "Upgrade T%d (%d)" % [tier + 1, cost]
				var text_col: Color = Color(0.4, 0.9, 0.5) if can_afford else Color(0.3, 0.3, 0.3)
				draw_string(font, Vector2(btn_x + 10, btn_y + 21), btn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_col)

				_trait_upgrade_rects[trait_id] = btn_rect
			else:
				# Max tier indicator
				var max_x: float = panel_x + panel_w - 100.0
				var max_y: float = y + card_h * 0.5
				draw_string(font, Vector2(max_x, max_y + 5), "MAX TIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, icon_col * 0.8)

		y += card_h + card_gap

	# Hint text at bottom
	y += 10.0
	draw_string(font, Vector2(panel_x, y + 14), "Hold Q to open trait radial menu in-game. Press 1-5 to quick-activate.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIConstants.TEXT_DIM)

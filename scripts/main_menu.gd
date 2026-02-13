extends Control
## Main menu — fully procedural _draw() with alien research lab aesthetic.
## Blueprint grid, scan lines, floating cells, DNA helix, tech diagrams.

var _time: float = 0.0
var _bg_cells: Array[Dictionary] = []
var _hover_button: int = -1
var _glyph_columns: Array = []
var _scan_line_y: float = 0.0
var _diagram_rot: Array = [0.0, 0.0]
var _helix_phase: float = 0.0
var _appear_t: float = 0.0
var _title_glitch_t: float = 0.0
var _music_on: bool = false

const BUTTONS: Array = [
	{"label": "BEGIN OBSERVATION", "action": "cell"},
	{"label": "PARASITE STAGE", "action": "snake"},
	{"label": "XENOBIOLOGY DATABASE", "action": "database"},
	{"label": "QUIT", "action": "quit"},
]

var _database: Control = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_music_on = AudioManager.is_using_music_files()
	# Generate background decorative cells
	for i in range(25):
		_bg_cells.append({
			"pos": Vector2(randf_range(0, 1920), randf_range(0, 1080)),
			"radius": randf_range(5.0, 30.0),
			"speed": Vector2(randf_range(-12, 12), randf_range(-8, 8)),
			"color": Color(randf_range(0.1, 0.3), randf_range(0.3, 0.7), randf_range(0.5, 1.0), randf_range(0.04, 0.12)),
			"phase": randf() * TAU,
		})
	_glyph_columns = UIConstants.create_glyph_columns(8)
	# Load Xenobiology Database
	var db_scene: PackedScene = load("res://scenes/xenobiology_database.tscn")
	if db_scene:
		var db_instance: Node = db_scene.instantiate()
		add_child(db_instance)
		_database = db_instance.get_node_or_null("XenobiologyDatabase")
		if _database:
			_database.database_closed.connect(_on_database_closed)

func _process(delta: float) -> void:
	_time += delta
	_appear_t = minf(_appear_t + delta * 2.0, 1.0)
	# Animate cells
	for c in _bg_cells:
		c.pos += c.speed * delta
		if c.pos.x < -40: c.pos.x = 1960
		if c.pos.x > 1960: c.pos.x = -40
		if c.pos.y < -40: c.pos.y = 1120
		if c.pos.y > 1120: c.pos.y = -40
	# Animate background elements
	var vp := get_viewport_rect().size
	_scan_line_y = fmod(_scan_line_y + delta * 40.0, vp.y + 40.0)
	_diagram_rot[0] += delta * 0.3
	_diagram_rot[1] -= delta * 0.2
	_helix_phase += delta * 1.2
	for col in _glyph_columns:
		col.offset += delta * col.speed
	# Occasional title glitch
	if randf() < 0.003:
		_title_glitch_t = 0.15
	_title_glitch_t = maxf(_title_glitch_t - delta, 0.0)
	# Hover detection
	var mouse := get_local_mouse_position()
	_hover_button = -1
	for i in range(BUTTONS.size()):
		if _get_button_rect(vp, i).has_point(mouse):
			_hover_button = i
	# Music toggle
	if _get_music_toggle_rect(vp).has_point(mouse):
		_hover_button = 10  # special id for music toggle
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover_button == 10:
			_music_on = not _music_on
			AudioManager.set_use_music_files(_music_on)
			AudioManager.play_ui_select()
		elif _hover_button == 0:
			AudioManager.play_ui_select()
			GameManager.reset_stats()
			GameManager.go_to_cell_stage()
		elif _hover_button == 1:
			AudioManager.play_ui_select()
			GameManager.reset_stats()
			GameManager.go_to_snake_stage()
		elif _hover_button == 2:
			AudioManager.play_ui_select()
			if _database:
				_database.toggle()
		elif _hover_button == 3:
			AudioManager.play_ui_select()
			get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_X:
			if _database:
				AudioManager.play_ui_select()
				_database.toggle()
				get_viewport().set_input_as_handled()

func _on_database_closed() -> void:
	pass

func _get_button_rect(vp: Vector2, index: int) -> Rect2:
	var cx: float = vp.x * 0.5
	var base_y: float = vp.y * 0.52
	var by: float = base_y + index * (UIConstants.BTN_H + UIConstants.BTN_SPACING)
	return Rect2(cx - UIConstants.BTN_W * 0.5, by, UIConstants.BTN_W, UIConstants.BTN_H)

func _get_music_toggle_rect(vp: Vector2) -> Rect2:
	var cx: float = vp.x * 0.5
	var base_y: float = vp.y * 0.52 + BUTTONS.size() * (UIConstants.BTN_H + UIConstants.BTN_SPACING) + 20
	return Rect2(cx - 120, base_y, 240, 32)

func _draw() -> void:
	var vp := get_viewport_rect().size
	var a: float = _appear_t

	# 1. Dark base
	draw_rect(Rect2(0, 0, vp.x, vp.y), UIConstants.BG_DARK)

	# 2. Blueprint grid
	UIConstants.draw_blueprint_grid(self, vp, a)

	# 3. Floating cells (behind everything else)
	for c in _bg_cells:
		var r: float = c.radius + sin(_time * 1.5 + c.phase) * 2.0
		var col: Color = c.color
		col.a *= a
		# Outer glow
		draw_circle(c.pos, r * 2.0, Color(col.r, col.g, col.b, col.a * 0.3))
		# Body
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(12):
			var angle: float = TAU * i / 12.0
			var wobble: float = sin(_time * 2.0 + c.phase + i * 0.8) * 1.5
			pts.append(c.pos + Vector2(cos(angle) * (r + wobble), sin(angle) * (r + wobble)))
		draw_colored_polygon(pts, col)

	# 4. Scan line
	UIConstants.draw_scan_line(self, vp, _scan_line_y, _time, a)

	# 5. Glyph columns
	UIConstants.draw_glyph_columns(self, vp, _glyph_columns, a)

	# 6. Tech diagrams (corners)
	_draw_tech_diagram(Vector2(vp.x * 0.12, vp.y * 0.25), 90.0, _diagram_rot[0], a * 0.18)
	_draw_tech_diagram(Vector2(vp.x * 0.88, vp.y * 0.75), 80.0, _diagram_rot[1], a * 0.15)

	# 7. DNA helix (right edge)
	_draw_dna_helix(vp)

	# 8. Corner frame
	UIConstants.draw_corner_frame(self, Rect2(6, 6, vp.x - 12, vp.y - 12), Color(UIConstants.FRAME_COLOR.r, UIConstants.FRAME_COLOR.g, UIConstants.FRAME_COLOR.b, 0.3 * a))

	# 9. Vignette
	UIConstants.draw_vignette(self, vp, a)

	# 10. Title — "3 V O L V 3" with glitch effect
	_draw_title(vp, a)

	# 11. Subtitle
	var font := UIConstants.get_display_font()
	var subtitle := "Alien Xenobiology Research Terminal"
	var ss := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
	draw_string(font, Vector2((vp.x - ss.x) * 0.5, vp.y * 0.4), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.7 * a))

	# 12. Decorative line under subtitle
	var line_w: float = 300.0 * a
	var line_y: float = vp.y * 0.4 + 14
	draw_line(Vector2(vp.x * 0.5 - line_w * 0.5, line_y), Vector2(vp.x * 0.5 + line_w * 0.5, line_y), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4 * a), 1.0)
	# Accent dot at center
	draw_circle(Vector2(vp.x * 0.5, line_y), 2.5, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.6 * a))

	# 13. System status readouts (bottom corners)
	_draw_readouts(vp, a)

	# 14. Buttons
	for i in range(BUTTONS.size()):
		var rect := _get_button_rect(vp, i)
		var hovered: bool = _hover_button == i
		UIConstants.draw_scifi_button(self, rect, BUTTONS[i].label, hovered, _time)

	# 15. Music toggle
	_draw_music_toggle(vp, a)

	# 16. Version / alien timestamp (bottom right)
	var mono := UIConstants.get_mono_font()
	var alien_ts: String = UIConstants.random_glyphs(10, _time)
	draw_string(mono, Vector2(vp.x - 160, vp.y - 20), alien_ts, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.3 * a))

func _draw_title(vp: Vector2, a: float) -> void:
	var font := UIConstants.get_display_font()
	var title := "3 V O L V 3"
	var title_size: int = 52
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size)
	var tx: float = (vp.x - ts.x) * 0.5
	var ty: float = vp.y * 0.32

	# Glitch offset
	var gx: float = 0.0
	var gy: float = 0.0
	if _title_glitch_t > 0:
		gx = randf_range(-4, 4)
		gy = randf_range(-2, 2)

	# Glow behind title
	draw_circle(Vector2(vp.x * 0.5, ty - 8), 120.0, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.03 * a))

	# Shadow
	draw_string(font, Vector2(tx + 2 + gx, ty + 2 + gy), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.0, 0.1, 0.2, 0.5 * a))

	# Main title
	var title_col := Color(UIConstants.TEXT_TITLE.r, UIConstants.TEXT_TITLE.g, UIConstants.TEXT_TITLE.b, a)
	draw_string(font, Vector2(tx + gx, ty + gy), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_col)

	# Glitch echo (chromatic aberration during glitch)
	if _title_glitch_t > 0:
		draw_string(font, Vector2(tx + gx + 3, ty + gy), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(1.0, 0.2, 0.2, _title_glitch_t * 2.0))
		draw_string(font, Vector2(tx + gx - 3, ty + gy), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.2, 0.2, 1.0, _title_glitch_t * 2.0))

	# Alien glyph accents flanking the title
	var mono := UIConstants.get_mono_font()
	var gl: String = UIConstants.random_glyphs(3, _time, 0.0)
	var gr: String = UIConstants.random_glyphs(3, _time, 5.0)
	draw_string(mono, Vector2(tx - 60, ty), gl, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.4 * a))
	draw_string(mono, Vector2(tx + ts.x + 20, ty), gr, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.4 * a))

func _draw_music_toggle(vp: Vector2, a: float) -> void:
	var rect := _get_music_toggle_rect(vp)
	var hovered: bool = _hover_button == 10
	var font := UIConstants.get_display_font()

	var bg: Color = Color(0.06, 0.15, 0.08, 0.7) if _music_on else Color(0.04, 0.06, 0.1, 0.5)
	if hovered:
		bg = bg.lightened(0.1)
	draw_rect(rect, bg)

	var border_col: Color = Color(UIConstants.STAT_GREEN.r, UIConstants.STAT_GREEN.g, UIConstants.STAT_GREEN.b, 0.5) if _music_on else Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.3)
	draw_rect(rect, border_col, false, 1.0)

	var label: String = "MUSIC FILES: ON" if _music_on else "MUSIC FILES: OFF"
	var label_col: Color = Color(UIConstants.STAT_GREEN.r, UIConstants.STAT_GREEN.g, UIConstants.STAT_GREEN.b, 0.9 * a) if _music_on else Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.6 * a)
	var ls := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - ls.x) * 0.5, rect.position.y + 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, label_col)

func _draw_readouts(vp: Vector2, a: float) -> void:
	var mono := UIConstants.get_mono_font()
	# Bottom-left: system status
	var lx: float = 20.0
	var ly: float = vp.y - 40.0
	draw_string(mono, Vector2(lx, ly), "SYS.STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.5 * a))
	draw_string(mono, Vector2(lx + 70, ly), "ACTIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(UIConstants.STAT_GREEN.r, UIConstants.STAT_GREEN.g, UIConstants.STAT_GREEN.b, 0.7 * a))
	ly += 14
	draw_string(mono, Vector2(lx, ly), "BIO.LINK", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.5 * a))
	var val: String = "%.2f" % fmod(_time * 7.3, 99.99)
	draw_string(mono, Vector2(lx + 60, ly), val, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(UIConstants.STAT_GREEN.r, UIConstants.STAT_GREEN.g, UIConstants.STAT_GREEN.b, 0.7 * a))

	# Bottom-right alien readout
	var alien_bl: String = UIConstants.random_glyphs(12, _time, 2.3)
	draw_string(mono, Vector2(vp.x - 200, vp.y - 26), alien_bl, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.25 * a))

func _draw_tech_diagram(center: Vector2, radius: float, angle: float, alpha: float) -> void:
	if alpha < 0.005:
		return
	draw_arc(center, radius, 0, TAU, 32, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, alpha), 1.0, true)
	draw_arc(center, radius * 0.7, 0, TAU, 24, Color(0.15, 0.4, 0.6, alpha * 0.7), 0.8, true)
	draw_arc(center, radius * 0.4, 0, TAU, 16, Color(0.12, 0.3, 0.5, alpha * 0.5), 0.5, true)
	for i in range(12):
		var tick_a: float = angle + TAU * float(i) / 12.0
		var p1: Vector2 = center + Vector2(cos(tick_a), sin(tick_a)) * radius
		var p2: Vector2 = center + Vector2(cos(tick_a), sin(tick_a)) * (radius - 8.0)
		draw_line(p1, p2, Color(0.3, 0.6, 0.8, alpha), 1.0, true)
	for i in range(4):
		var ch_a: float = angle * 0.5 + TAU * float(i) / 4.0
		var p1: Vector2 = center + Vector2(cos(ch_a), sin(ch_a)) * radius * 0.15
		var p2: Vector2 = center + Vector2(cos(ch_a), sin(ch_a)) * radius * 0.65
		draw_line(p1, p2, Color(0.2, 0.4, 0.6, alpha * 0.5), 0.5, true)
	var arc_start: float = fmod(angle * 1.5, TAU)
	draw_arc(center, radius * 0.85, arc_start, arc_start + PI * 0.6, 12, Color(0.3, 0.7, 0.9, alpha * 0.7), 2.0, true)
	draw_circle(center, 2.5, Color(0.3, 0.7, 0.9, alpha))
	var orbit_pos: Vector2 = center + Vector2(cos(angle * 2.0), sin(angle * 2.0)) * radius * 0.55
	draw_circle(orbit_pos, 2.0, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, alpha * 0.8))

func _draw_dna_helix(vp: Vector2) -> void:
	var x_base: float = vp.x * 0.97
	var helix_width: float = 12.0
	var a: float = _appear_t * 0.15
	var strand1 := PackedVector2Array()
	var strand2 := PackedVector2Array()
	var num_pts: int = 30
	for i in range(num_pts):
		var t: float = float(i) / float(num_pts - 1)
		var y: float = t * vp.y
		var phase: float = _helix_phase + t * 8.0
		var x1: float = x_base + sin(phase) * helix_width
		var x2: float = x_base + sin(phase + PI) * helix_width
		strand1.append(Vector2(x1, y))
		strand2.append(Vector2(x2, y))
		if i % 3 == 0 and i > 0:
			draw_line(Vector2(x1, y), Vector2(x2, y), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, a * 0.7), 1.0, true)
	if strand1.size() >= 2:
		draw_polyline(strand1, Color(UIConstants.ACCENT_GLOW.r, UIConstants.ACCENT_GLOW.g, UIConstants.ACCENT_GLOW.b, a), 2.5, true)
		draw_polyline(strand2, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, a), 2.5, true)

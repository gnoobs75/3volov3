extends Control
## Science Desk frame for RTS Colony Stage.
## Draws dark panels on left and right sides of the screen, matching
## the cell stage ThreePaneLayout aesthetic. Creates a "lab bench viewport"
## feel where the petri dish game view is framed by science desk instruments.
## Existing HUD elements (minimap, selection panel, command card) render on top.

const LEFT_W: float = 280.0
const RIGHT_W: float = 280.0

# Match cell stage panel colors exactly
const PANEL_BG: Color = Color(0.015, 0.025, 0.04, 1.0)
const BORDER_COLOR: Color = Color(0.12, 0.25, 0.35, 0.7)
const BORDER_W: float = 2.0

var _time: float = 0.0
var _redraw_timer: float = 0.0
var _scratches_l: Array = []
var _scratches_r: Array = []
var _glyph_cols_l: Array = []
var _glyph_cols_r: Array = []
var _circuit_segs_l: Array = []
var _circuit_segs_r: Array = []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_gen_scratches()
	_gen_glyph_columns()
	_gen_circuit_traces()

# --- Generation ---

func _gen_scratches() -> void:
	for i in range(18):
		_scratches_l.append({
			"s": Vector2(randf() * LEFT_W, randf() * 1200),
			"e": Vector2(randf() * LEFT_W, randf() * 1200),
			"a": randf_range(0.02, 0.05),
		})
	for i in range(18):
		_scratches_r.append({
			"s": Vector2(randf() * RIGHT_W, randf() * 1200),
			"e": Vector2(randf() * RIGHT_W, randf() * 1200),
			"a": randf_range(0.02, 0.05),
		})

func _gen_glyph_columns() -> void:
	for i in range(3):
		_glyph_cols_l.append(_make_glyph_col(LEFT_W))
	for i in range(3):
		_glyph_cols_r.append(_make_glyph_col(RIGHT_W))

func _make_glyph_col(panel_w: float) -> Dictionary:
	var col := {
		"x": randf_range(15, panel_w - 15),
		"offset": randf() * 500.0,
		"speed": randf_range(5.0, 10.0),
		"alpha": randf_range(0.04, 0.09),
		"glyphs": [],
	}
	for j in range(40):
		col.glyphs.append(str(UIConstants.ALIEN_GLYPHS[randi() % UIConstants.ALIEN_GLYPHS.size()]))
	return col

func _gen_circuit_traces() -> void:
	for i in range(8):
		_circuit_segs_l.append(_make_circuit_seg(LEFT_W))
	for i in range(8):
		_circuit_segs_r.append(_make_circuit_seg(RIGHT_W))

func _make_circuit_seg(panel_w: float) -> Dictionary:
	var horiz: bool = randf() < 0.5
	var y1: float = randf_range(60, 1000)
	var x1: float = randf_range(10, panel_w - 10)
	var length: float = randf_range(30, 100)
	if horiz:
		return {"s": Vector2(x1, y1), "e": Vector2(minf(x1 + length, panel_w - 5), y1), "a": randf_range(0.03, 0.08)}
	else:
		return {"s": Vector2(x1, y1), "e": Vector2(x1, y1 + length), "a": randf_range(0.03, 0.08)}

# --- Process ---

func _process(delta: float) -> void:
	_time += delta
	for col in _glyph_cols_l:
		col.offset += col.speed * delta
	for col in _glyph_cols_r:
		col.offset += col.speed * delta
	_redraw_timer -= delta
	if _redraw_timer <= 0:
		_redraw_timer = 0.08
		queue_redraw()

# --- Draw ---

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_draw_panel_left(vp)
	_draw_panel_right(vp)

func _draw_panel_left(vp: Vector2) -> void:
	# Solid dark background
	draw_rect(Rect2(0, 0, LEFT_W, vp.y), PANEL_BG)
	# Right border with glow
	draw_line(Vector2(LEFT_W, 0), Vector2(LEFT_W, vp.y), BORDER_COLOR, BORDER_W)
	draw_line(Vector2(LEFT_W - 1, 0), Vector2(LEFT_W - 1, vp.y),
		Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.15), 4.0)

	# Tablet scratches
	for s in _scratches_l:
		draw_line(s.s, s.e, Color(0.25, 0.35, 0.45, s.a), 0.5)

	# Blueprint grid
	_draw_grid(0, 0, LEFT_W, vp.y)

	# Circuit traces
	for seg in _circuit_segs_l:
		draw_line(seg.s, seg.e, Color(0.15, 0.30, 0.42, seg.a), 1.0)
		draw_circle(seg.s, 1.5, Color(0.2, 0.4, 0.55, seg.a * 1.5))
		draw_circle(seg.e, 1.5, Color(0.2, 0.4, 0.55, seg.a * 1.5))

	# Corner frame
	UIConstants.draw_corner_frame(self, Rect2(3, 3, LEFT_W - 6, vp.y - 6),
		Color(UIConstants.FRAME_COLOR.r, UIConstants.FRAME_COLOR.g, UIConstants.FRAME_COLOR.b, 0.12))

	# Header (below HUD top bar at y=40)
	var font := UIConstants.get_display_font()
	var mono := UIConstants.get_mono_font()
	draw_string(font, Vector2(12, 56), "RESEARCH STATION", HORIZONTAL_ALIGNMENT_LEFT, -1,
		UIConstants.FONT_CAPTION, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.45))
	draw_line(Vector2(12, 63), Vector2(LEFT_W - 12, 63),
		Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.25), 1.0)
	var scan_hx: float = fmod(_time * 60.0, LEFT_W)
	draw_line(Vector2(scan_hx, 63), Vector2(minf(scan_hx + 40.0, LEFT_W - 5), 63),
		Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.25), 1.5)

	# Vertical scan line
	var scan_y: float = fmod(_time * 25.0, vp.y)
	draw_line(Vector2(8, scan_y), Vector2(LEFT_W - 8, scan_y),
		Color(UIConstants.SCAN_LINE_COLOR.r, UIConstants.SCAN_LINE_COLOR.g, UIConstants.SCAN_LINE_COLOR.b, 0.06), 1.0)

	# Scrolling glyph columns
	_draw_glyphs(_glyph_cols_l, 0.0, vp.y)

	# Decorative oscilloscope (mid-panel, above minimap/selection area)
	_draw_oscilloscope(15, vp.y * 0.3, LEFT_W - 30, 40)

	# Decorative section divider
	var div_y: float = vp.y * 0.52
	draw_line(Vector2(20, div_y), Vector2(LEFT_W - 20, div_y),
		Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.15), 1.0)
	var div_glyph: String = UIConstants.random_glyphs(3, _time * 0.3, 1.0)
	draw_string(mono, Vector2(LEFT_W * 0.5 - 15, div_y - 3), div_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UIConstants.FONT_TINY, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.2))

	# Status dots at bottom
	_draw_status_dots(14, vp.y - 16, 4)

	# Bottom alien text
	var glyphs: String = UIConstants.random_glyphs(10, _time, 0.0)
	draw_string(mono, Vector2(12, vp.y - 26), glyphs, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UIConstants.FONT_TINY, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.15))

func _draw_panel_right(vp: Vector2) -> void:
	var rx: float = vp.x - RIGHT_W
	# Solid dark background
	draw_rect(Rect2(rx, 0, RIGHT_W, vp.y), PANEL_BG)
	# Left border with glow
	draw_line(Vector2(rx, 0), Vector2(rx, vp.y), BORDER_COLOR, BORDER_W)
	draw_line(Vector2(rx + 1, 0), Vector2(rx + 1, vp.y),
		Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.15), 4.0)

	# Tablet scratches (offset to right panel)
	for s in _scratches_r:
		draw_line(s.s + Vector2(rx, 0), s.e + Vector2(rx, 0), Color(0.25, 0.35, 0.45, s.a), 0.5)

	# Blueprint grid
	_draw_grid(rx, 0, RIGHT_W, vp.y)

	# Circuit traces (offset)
	for seg in _circuit_segs_r:
		draw_line(seg.s + Vector2(rx, 0), seg.e + Vector2(rx, 0), Color(0.15, 0.30, 0.42, seg.a), 1.0)
		draw_circle(seg.s + Vector2(rx, 0), 1.5, Color(0.2, 0.4, 0.55, seg.a * 1.5))
		draw_circle(seg.e + Vector2(rx, 0), 1.5, Color(0.2, 0.4, 0.55, seg.a * 1.5))

	# Corner frame
	UIConstants.draw_corner_frame(self, Rect2(rx + 3, 3, RIGHT_W - 6, vp.y - 6),
		Color(UIConstants.FRAME_COLOR.r, UIConstants.FRAME_COLOR.g, UIConstants.FRAME_COLOR.b, 0.12))

	# Header (below HUD top bar at y=40)
	var font := UIConstants.get_display_font()
	var mono := UIConstants.get_mono_font()
	draw_string(font, Vector2(rx + 12, 56), "COMMAND CENTER", HORIZONTAL_ALIGNMENT_LEFT, -1,
		UIConstants.FONT_CAPTION, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.45))
	draw_line(Vector2(rx + 12, 63), Vector2(vp.x - 12, 63),
		Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.25), 1.0)
	var scan_hx: float = fmod(_time * 50.0 + RIGHT_W * 0.5, RIGHT_W)
	draw_line(Vector2(rx + scan_hx, 63), Vector2(rx + minf(scan_hx + 40.0, RIGHT_W - 5), 63),
		Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.25), 1.5)

	# Vertical scan line
	var scan_y: float = fmod(_time * 20.0 + vp.y * 0.4, vp.y)
	draw_line(Vector2(rx + 8, scan_y), Vector2(vp.x - 8, scan_y),
		Color(UIConstants.SCAN_LINE_COLOR.r, UIConstants.SCAN_LINE_COLOR.g, UIConstants.SCAN_LINE_COLOR.b, 0.06), 1.0)

	# Scrolling glyph columns (offset)
	_draw_glyphs(_glyph_cols_r, rx, vp.y)

	# Decorative data readout bars (mid-panel)
	_draw_data_bars(rx + 15, vp.y * 0.28, RIGHT_W - 30, 65)

	# Section divider
	var div_y: float = vp.y * 0.50
	draw_line(Vector2(rx + 20, div_y), Vector2(vp.x - 20, div_y),
		Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.15), 1.0)
	var div_glyph: String = UIConstants.random_glyphs(3, _time * 0.3, 3.5)
	draw_string(mono, Vector2(rx + RIGHT_W * 0.5 - 15, div_y - 3), div_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UIConstants.FONT_TINY, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.2))

	# Status dots at bottom
	_draw_status_dots(rx + 14, vp.y - 16, 4)

	# Bottom alien text
	var glyphs: String = UIConstants.random_glyphs(10, _time, 4.7)
	draw_string(mono, Vector2(rx + 12, vp.y - 26), glyphs, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UIConstants.FONT_TINY, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.15))

# --- Helpers ---

func _draw_grid(x: float, y: float, w: float, h: float) -> void:
	var sp: float = 40.0
	var gc := Color(UIConstants.GRID_COLOR.r, UIConstants.GRID_COLOR.g, UIConstants.GRID_COLOR.b, 0.035)
	for i in range(int(w / sp) + 1):
		draw_line(Vector2(x + float(i) * sp, y), Vector2(x + float(i) * sp, y + h), gc, 0.5)
	for i in range(int(h / sp) + 1):
		draw_line(Vector2(x, y + float(i) * sp), Vector2(x + w, y + float(i) * sp), gc, 0.5)

func _draw_glyphs(columns: Array, offset_x: float, panel_h: float) -> void:
	var font := UIConstants.get_mono_font()
	for col in columns:
		var total: float = float(col.glyphs.size()) * 18.0
		for i in range(col.glyphs.size()):
			var y: float = fmod(col.offset + float(i) * 18.0, total + panel_h) - 36.0
			if y < 70.0 or y > panel_h - 35.0:
				continue
			var fade: float = 1.0
			if y < 100.0:
				fade = (y - 70.0) / 30.0
			elif y > panel_h - 70.0:
				fade = (panel_h - 35.0 - y) / 35.0
			draw_string(font, Vector2(offset_x + col.x, y), str(col.glyphs[i]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_GLYPH,
				Color(0.18, 0.38, 0.52, col.alpha * clampf(fade, 0.0, 1.0)))

func _draw_status_dots(x: float, y: float, count: int) -> void:
	for i in range(count):
		var p: float = 0.25 + 0.35 * sin(_time * (1.8 + float(i) * 0.4) + float(i) * 2.1)
		var dx: float = x + float(i) * 16.0
		draw_circle(Vector2(dx, y), 2.5,
			Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, p))
		draw_circle(Vector2(dx, y), 1.2,
			Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, p * 1.4))

func _draw_oscilloscope(x: float, y: float, w: float, h: float) -> void:
	# Frame
	draw_rect(Rect2(x, y, w, h), Color(0.02, 0.04, 0.06, 0.5))
	draw_rect(Rect2(x, y, w, h), Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.2), false, 1.0)
	# Center line
	draw_line(Vector2(x + 2, y + h * 0.5), Vector2(x + w - 2, y + h * 0.5),
		Color(UIConstants.GRID_COLOR.r, UIConstants.GRID_COLOR.g, UIConstants.GRID_COLOR.b, 0.1), 0.5)
	# Waveform
	var prev := Vector2(x + 2, y + h * 0.5)
	var steps: int = int(w / 3.0)
	for i in range(1, steps):
		var px: float = x + 2 + float(i) * 3.0
		var wave: float = sin(_time * 2.5 + float(i) * 0.15) * 0.35
		wave += sin(_time * 4.2 + float(i) * 0.08) * 0.15
		var py: float = y + h * (0.5 + wave * 0.8)
		var pt := Vector2(px, py)
		draw_line(prev, pt,
			Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.25), 1.0)
		prev = pt

func _draw_data_bars(x: float, y: float, w: float, h: float) -> void:
	# Frame
	draw_rect(Rect2(x, y, w, h), Color(0.02, 0.04, 0.06, 0.5))
	draw_rect(Rect2(x, y, w, h), Color(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.2), false, 1.0)
	# Label
	var font := UIConstants.get_mono_font()
	draw_string(font, Vector2(x + 4, y + 12), "ANALYSIS", HORIZONTAL_ALIGNMENT_LEFT, -1,
		UIConstants.FONT_TINY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.3))
	# Bars
	var bar_count: int = 5
	var bar_h: float = 6.0
	var bar_spacing: float = (h - 20.0) / float(bar_count)
	for i in range(bar_count):
		var by: float = y + 18.0 + float(i) * bar_spacing
		var fill: float = 0.3 + 0.5 * sin(_time * (0.8 + float(i) * 0.3) + float(i) * 1.5)
		fill = clampf(fill, 0.1, 0.95)
		draw_rect(Rect2(x + 4, by, w - 8, bar_h), Color(0.08, 0.12, 0.18, 0.5))
		var bar_w: float = (w - 8) * fill
		var bar_col := Color(
			lerpf(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT.r, fill),
			lerpf(UIConstants.ACCENT_DIM.g, UIConstants.ACCENT.g, fill),
			lerpf(UIConstants.ACCENT_DIM.b, UIConstants.ACCENT.b, fill),
			0.35)
		draw_rect(Rect2(x + 4, by, bar_w, bar_h), bar_col)

# --- Public API ---

static func get_left_width() -> float:
	return LEFT_W

static func get_right_width() -> float:
	return RIGHT_W

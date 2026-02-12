class_name UIConstants
## Unified design system for all UI surfaces.
## Usage: UIConstants.ACCENT_COLOR, UIConstants.draw_scifi_button(target, ...)
## No autoload needed — class_name provides global access.

# ====================== COLORS ======================

# Base palette
const BG_DARK: Color = Color(0.01, 0.02, 0.05, 0.96)
const BG_PANEL: Color = Color(0.02, 0.04, 0.08, 0.85)
const BG_DIM: Color = Color(0.0, 0.02, 0.05, 0.75)

# Accent (cyan)
const ACCENT: Color = Color(0.4, 0.9, 1.0)
const ACCENT_DIM: Color = Color(0.2, 0.5, 0.7)
const ACCENT_GLOW: Color = Color(0.3, 0.8, 1.0)

# Text
const TEXT_BRIGHT: Color = Color(0.8, 1.0, 1.0)
const TEXT_NORMAL: Color = Color(0.5, 0.75, 0.85)
const TEXT_DIM: Color = Color(0.3, 0.5, 0.6)
const TEXT_TITLE: Color = Color(0.3, 0.9, 1.0)

# Buttons
const BTN_BG: Color = Color(0.03, 0.08, 0.18, 0.85)
const BTN_BG_HOVER: Color = Color(0.06, 0.2, 0.35, 0.9)
const BTN_BORDER: Color = Color(0.2, 0.4, 0.6, 0.5)
const BTN_BORDER_HOVER: Color = Color(0.4, 0.8, 1.0, 0.8)
const BTN_TEXT: Color = Color(0.5, 0.8, 0.9, 0.9)
const BTN_TEXT_HOVER: Color = Color(0.8, 1.0, 1.0, 1.0)

# Grid / structural
const GRID_COLOR: Color = Color(0.12, 0.25, 0.35)
const SCAN_LINE_COLOR: Color = Color(0.3, 0.8, 1.0)
const FRAME_COLOR: Color = Color(0.2, 0.5, 0.7)

# Stats
const STAT_GREEN: Color = Color(0.3, 0.9, 0.5)
const STAT_RED: Color = Color(0.9, 0.3, 0.3)
const STAT_YELLOW: Color = Color(1.0, 0.9, 0.3)

# ====================== FONT SIZES ======================

const FONT_TITLE: int = 32
const FONT_HEADER: int = 22
const FONT_SUBHEADER: int = 16
const FONT_BODY: int = 14
const FONT_CAPTION: int = 11
const FONT_TINY: int = 9
const FONT_GLYPH: int = 12

# ====================== LAYOUT ======================

const GRID_SPACING: float = 40.0
const CORNER_LEN: float = 30.0
const BTN_W: float = 260.0
const BTN_H: float = 48.0
const BTN_SPACING: float = 16.0

# ====================== ALIEN GLYPHS ======================

const ALIEN_GLYPHS: Array = [
	"◊", "∆", "Ω", "Σ", "Φ", "Ψ", "λ", "π", "θ", "ξ",
	"╬", "╫", "╪", "┼", "╋", "╂", "╁", "╀", "┿", "┾",
	"⊕", "⊗", "⊙", "⊚", "⊛", "⊜", "⊝", "⊞", "⊟", "⊠",
]

# ====================== FONTS ======================

static var _display_font: Font = null
static var _mono_font: Font = null

static func get_display_font() -> Font:
	if _display_font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Segoe UI Semibold", "Helvetica Neue", "Arial", "sans-serif"])
		sf.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		_display_font = sf
	return _display_font

static func get_mono_font() -> Font:
	if _mono_font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Consolas", "SF Mono", "Monaco", "Courier New", "monospace"])
		sf.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		_mono_font = sf
	return _mono_font

# ====================== DRAWING HELPERS ======================

## Draw a blueprint grid background
static func draw_blueprint_grid(target: CanvasItem, vp: Vector2, alpha: float = 1.0) -> void:
	var grid_alpha: float = 0.09 * alpha
	var gx_count: int = int(vp.x / GRID_SPACING) + 1
	var gy_count: int = int(vp.y / GRID_SPACING) + 1
	for i in range(gx_count):
		var x: float = float(i) * GRID_SPACING
		var is_major: bool = (i % 4 == 0)
		var ga: float = grid_alpha * (1.55 if is_major else 1.0)
		var gw: float = 1.5 if is_major else 1.0
		target.draw_line(Vector2(x, 0), Vector2(x, vp.y), Color(GRID_COLOR.r, GRID_COLOR.g, GRID_COLOR.b, ga), gw)
	for i in range(gy_count):
		var y: float = float(i) * GRID_SPACING
		var is_major: bool = (i % 4 == 0)
		var ga: float = grid_alpha * (1.55 if is_major else 1.0)
		var gw: float = 1.5 if is_major else 1.0
		target.draw_line(Vector2(0, y), Vector2(vp.x, y), Color(GRID_COLOR.r, GRID_COLOR.g, GRID_COLOR.b, ga), gw)

## Draw a horizontal scan line with glow band
static func draw_scan_line(target: CanvasItem, vp: Vector2, scan_y: float, time: float, alpha: float = 1.0) -> void:
	var scan_alpha: float = (0.25 + 0.12 * sin(time * 3.0)) * alpha
	target.draw_line(Vector2(0, scan_y), Vector2(vp.x, scan_y), Color(SCAN_LINE_COLOR.r, SCAN_LINE_COLOR.g, SCAN_LINE_COLOR.b, scan_alpha), 2.5)
	for i in range(6):
		var off: float = float(i + 1) * 3.0
		var band_a: float = scan_alpha * (1.0 - float(i) / 6.0) * 0.3
		target.draw_line(Vector2(0, scan_y + off), Vector2(vp.x, scan_y + off), Color(0.2, 0.6, 0.8, band_a), 1.5)

## Draw corner bracket frame
static func draw_corner_frame(target: CanvasItem, rect: Rect2, color: Color) -> void:
	var cl: float = CORNER_LEN
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	target.draw_line(Vector2(x, y), Vector2(x + cl, y), color, 2.0)
	target.draw_line(Vector2(x, y), Vector2(x, y + cl), color, 2.0)
	target.draw_line(Vector2(x + w, y), Vector2(x + w - cl, y), color, 2.0)
	target.draw_line(Vector2(x + w, y), Vector2(x + w, y + cl), color, 2.0)
	target.draw_line(Vector2(x, y + h), Vector2(x + cl, y + h), color, 2.0)
	target.draw_line(Vector2(x, y + h), Vector2(x, y + h - cl), color, 2.0)
	target.draw_line(Vector2(x + w, y + h), Vector2(x + w - cl, y + h), color, 2.0)
	target.draw_line(Vector2(x + w, y + h), Vector2(x + w, y + h - cl), color, 2.0)

## Draw a sci-fi styled button. Returns true if hovered.
static func draw_scifi_button(target: CanvasItem, rect: Rect2, label: String, hovered: bool, time: float, font: Font = null, font_size: int = FONT_SUBHEADER) -> void:
	if font == null:
		font = get_display_font()
	var bg: Color = BTN_BG_HOVER if hovered else BTN_BG
	var border: Color = BTN_BORDER_HOVER if hovered else BTN_BORDER
	var text_col: Color = BTN_TEXT_HOVER if hovered else BTN_TEXT

	target.draw_rect(rect, bg)

	# Corner bracket frame
	draw_corner_frame(target, Rect2(rect.position.x - 2, rect.position.y - 2, rect.size.x + 4, rect.size.y + 4),
		Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7 if hovered else 0.2))

	# Border
	target.draw_rect(rect, border, false, 1.5)

	# Hover scan effect
	if hovered:
		var glow_rect: Rect2 = Rect2(rect.position.x - 4, rect.position.y - 4, rect.size.x + 8, rect.size.y + 8)
		target.draw_rect(glow_rect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.06))
		var scan_x: float = fmod(time * 80.0, rect.size.x)
		target.draw_line(
			Vector2(rect.position.x + scan_x, rect.position.y + 2),
			Vector2(rect.position.x + scan_x, rect.position.y + rect.size.y - 2),
			Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.15), 2.0)

	# Alien glyph accents
	var glyph: String = str(ALIEN_GLYPHS[int(fmod(time * 0.6, ALIEN_GLYPHS.size()))])
	var full_label: String = glyph + " " + label + " " + glyph
	var ls: Vector2 = font.get_string_size(full_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	target.draw_string(font, Vector2(rect.position.x + (rect.size.x - ls.x) * 0.5, rect.position.y + rect.size.y * 0.5 + font_size * 0.35), full_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

## Draw a vignette around edges
static func draw_vignette(target: CanvasItem, vp: Vector2, alpha: float = 1.0) -> void:
	for i in range(4):
		var t: float = float(i) / 4.0
		var edge_a: float = 0.06 * (1.0 - t) * alpha
		target.draw_rect(Rect2(0, 0, vp.x, 30 - i * 6), Color(0.0, 0.0, 0.0, edge_a))
		target.draw_rect(Rect2(0, vp.y - 30 + i * 6, vp.x, 30 - i * 6), Color(0.0, 0.0, 0.0, edge_a))

## Draw scrolling alien glyph columns
static func draw_glyph_columns(target: CanvasItem, vp: Vector2, columns: Array, alpha: float = 1.0) -> void:
	var font: Font = get_mono_font()
	for col in columns:
		var x: float = col.x
		if x > vp.x:
			continue
		for i in range(col.glyphs.size()):
			var y: float = fmod(col.offset + float(i) * 18.0, float(col.glyphs.size()) * 18.0 + vp.y) - 36.0
			if y < -18.0 or y > vp.y + 18.0:
				continue
			var edge_fade: float = 1.0
			if y < 80.0:
				edge_fade = clampf(y / 80.0, 0.0, 1.0)
			elif y > vp.y - 60.0:
				edge_fade = clampf((vp.y - y) / 60.0, 0.0, 1.0)
			target.draw_string(font, Vector2(x, y), str(col.glyphs[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_GLYPH, Color(0.2, 0.5, 0.6, col.alpha * edge_fade * alpha))

## Generate glyph column data (call once at init)
static func create_glyph_columns(num_cols: int = 10) -> Array:
	var columns: Array = []
	for i in range(num_cols):
		var col := {
			"x": 30.0 + float(i) * 120.0 + randf_range(-20, 20),
			"offset": randf() * 400.0,
			"speed": randf_range(8.0, 18.0),
			"alpha": randf_range(0.08, 0.16),
			"glyphs": [],
		}
		for j in range(24):
			col.glyphs.append(str(ALIEN_GLYPHS[randi() % ALIEN_GLYPHS.size()]))
		columns.append(col)
	return columns

## Get a random glyph string of given length
static func random_glyphs(length: int, time: float = 0.0, offset: float = 0.0) -> String:
	var result: String = ""
	for i in range(length):
		result += str(ALIEN_GLYPHS[int(fmod(time * 0.3 + i * 1.7 + offset, ALIEN_GLYPHS.size()))])
	return result

## Draw header bar with scan accent (reusable across screens)
static func draw_header_bar(target: CanvasItem, vp: Vector2, title: String, time: float, alpha: float = 1.0) -> void:
	var font: Font = get_display_font()
	target.draw_rect(Rect2(0, 0, vp.x, 60), Color(0.02, 0.04, 0.08, 0.85 * alpha))
	target.draw_line(Vector2(0, 59), Vector2(vp.x, 59), Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.35 * alpha), 1.0)
	# Moving accent light
	var header_scan: float = fmod(time * 120.0, vp.x + 200.0) - 100.0
	target.draw_line(Vector2(header_scan, 59), Vector2(header_scan + 120.0, 59), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7 * alpha), 3.0)
	# Title
	var ts: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_HEADER)
	target.draw_string(font, Vector2((vp.x - ts.x) * 0.5, 38), title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_HEADER, Color(TEXT_TITLE.r, TEXT_TITLE.g, TEXT_TITLE.b, alpha))

## Draw a mini stats row (for pause menus)
static func draw_stat_row(target: CanvasItem, pos: Vector2, label: String, value: String, color: Color) -> void:
	var font: Font = get_mono_font()
	target.draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_CAPTION, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.7))
	var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_CAPTION).x
	target.draw_string(font, Vector2(pos.x + lw + 8, pos.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_CAPTION, color)

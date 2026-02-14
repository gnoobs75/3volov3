extends Control
## Creature customization dashboard: HSV color picker, eye style selector,
## body shape, preview zoom/rotation, stats summary. Full right-side panel with sci-fi styling.

signal color_changed(target: String, color: Color)
signal style_changed(target: String, style: String)
signal eye_size_changed(new_size: float)
signal elongation_offset_changed(value: float)
signal bulge_changed(value: float)

var _active_target: String = "membrane_color"
var _current_hue: float = 0.6
var _current_sat: float = 0.5
var _current_val: float = 0.8

var _dragging_hue: bool = false
var _dragging_sv: bool = false

var _selected_eye: String = "anime"
var _eye_size: float = 3.5

# Body shape
var _elongation_offset: float = 0.0
var _bulge: float = 1.0

# Preview controls (local state, read by evolution_ui)
var preview_zoom: float = 3.5
var preview_rotation: float = 0.0

var _time: float = 0.0
var _hover_target: String = ""
var _hover_eye: int = -1
var _scroll_y: float = 0.0  # Vertical scroll offset for the panel

# Dragging state for sliders
var _dragging_zoom: bool = false
var _dragging_rotation: bool = false
var _dragging_elongation: bool = false
var _dragging_bulge: bool = false

# Layout constants — scaled to fit 1080px height comfortably
const PANEL_PAD: float = 16.0
const SECTION_GAP: float = 14.0
const HUE_RING_OUTER: float = 68.0
const HUE_RING_INNER: float = 52.0
const SV_BOX_SIZE: float = 105.0

const SLIDER_W: float = 220.0
const SLIDER_THUMB_R: float = 12.0
const ROTATION_DIAL_R: float = 40.0

const EYE_STYLES: Array = ["round", "anime", "compound", "googly", "slit", "lashed", "fierce", "dot", "star", "hypnotize", "x_eyes", "heart", "spiral", "alien"]

const TARGET_LABELS: Dictionary = {
	"membrane_color": "Membrane",
	"iris_color": "Iris",
	"glow_color": "Glow",
	"interior_color": "Interior",
	"cilia_color": "Cilia",
	"organelle_tint": "Organelles",
}

const TARGET_ORDER: Array = ["membrane_color", "iris_color", "glow_color", "interior_color", "cilia_color", "organelle_tint"]

const ALIEN_GLYPHS: Array = [
	"◊", "∆", "Ω", "Σ", "Φ", "Ψ", "λ", "π", "θ", "ξ",
	"╬", "╫", "╪", "┼", "╋", "╂", "╁", "╀", "┿", "┾",
	"⊕", "⊗", "⊙", "⊚", "⊛", "⊜", "⊝", "⊞", "⊟", "⊠",
]

func setup(custom: Dictionary) -> void:
	var col: Color = custom.get(_active_target, Color(0.3, 0.6, 1.0))
	_current_hue = col.h
	_current_sat = col.s
	_current_val = col.v
	_selected_eye = custom.get("eye_style", "anime")
	_eye_size = custom.get("eye_size", 3.5)
	_elongation_offset = custom.get("body_elongation_offset", 0.0)
	_bulge = custom.get("body_bulge", 1.0)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var pos: Vector2 = event.position
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check hue ring
			var hue_center: Vector2 = _get_hue_center()
			var dist_to_center: float = pos.distance_to(hue_center)
			if dist_to_center >= HUE_RING_INNER and dist_to_center <= HUE_RING_OUTER:
				_dragging_hue = true
				_update_hue_from_mouse(pos, hue_center)
				accept_event()
			elif _is_in_sv_box(pos):
				_dragging_sv = true
				_update_sv_from_mouse(pos)
				accept_event()
			elif _check_target_buttons(pos):
				accept_event()
			elif _check_eye_buttons(pos):
				accept_event()
			# Check slider thumb clicks
			elif _check_slider_click(pos, _get_elongation_slider_y(), (_elongation_offset + 0.5) / 1.0):
				_dragging_elongation = true
				accept_event()
			elif _check_slider_click(pos, _get_bulge_slider_y(), (_bulge - 0.5) / 1.5):
				_dragging_bulge = true
				accept_event()
			elif _check_slider_click(pos, _get_zoom_slider_y(), (preview_zoom - 2.0) / 4.0):
				_dragging_zoom = true
				accept_event()
			elif _check_rotation_click(pos):
				_dragging_rotation = true
				_update_rotation_from_mouse(pos)
				accept_event()
			# Click on slider track (jump thumb there)
			elif _check_slider_track_click(pos):
				accept_event()

		elif not event.pressed:
			_dragging_hue = false
			_dragging_sv = false
			_dragging_zoom = false
			_dragging_rotation = false
			_dragging_elongation = false
			_dragging_bulge = false

		# Mouse wheel
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var delta_val: float = 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				var small_delta: float = 0.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.5
				var handled: bool = false

				# Hue ring: scroll to rotate hue
				var hue_center: Vector2 = _get_hue_center()
				if pos.distance_to(hue_center) <= HUE_RING_OUTER:
					_current_hue = fmod(_current_hue + 0.03 * delta_val + 1.0, 1.0)
					_emit_color()
					handled = true
					accept_event()

				# SV box: scroll to adjust brightness
				if not handled and _is_in_sv_box(pos):
					_current_val = clampf(_current_val + 0.05 * delta_val, 0.0, 1.0)
					_emit_color()
					handled = true
					accept_event()

				# Elongation slider area
				if not handled and _is_in_slider_area(pos, _get_elongation_slider_y()):
					_elongation_offset = clampf(_elongation_offset + 0.05 * delta_val, -0.5, 0.5)
					elongation_offset_changed.emit(_elongation_offset)
					handled = true
					accept_event()

				# Bulge slider area
				if not handled and _is_in_slider_area(pos, _get_bulge_slider_y()):
					_bulge = clampf(_bulge + 0.1 * delta_val, 0.5, 2.0)
					bulge_changed.emit(_bulge)
					handled = true
					accept_event()

				# Zoom slider area
				if not handled and _is_in_slider_area(pos, _get_zoom_slider_y()):
					preview_zoom = clampf(preview_zoom + 0.25 * delta_val, 2.0, 6.0)
					handled = true
					accept_event()

	elif event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		if _dragging_hue:
			_update_hue_from_mouse(pos, _get_hue_center())
			accept_event()
		elif _dragging_sv:
			_update_sv_from_mouse(pos)
			accept_event()
		elif _dragging_elongation:
			_update_slider_from_mouse(pos, _get_elongation_slider_y(), "elongation")
			accept_event()
		elif _dragging_bulge:
			_update_slider_from_mouse(pos, _get_bulge_slider_y(), "bulge")
			accept_event()
		elif _dragging_zoom:
			_update_slider_from_mouse(pos, _get_zoom_slider_y(), "zoom")
			accept_event()
		elif _dragging_rotation:
			_update_rotation_from_mouse(pos)
			accept_event()

		# Track hover for visual feedback
		_hover_target = ""
		_hover_eye = -1
		for i in range(TARGET_ORDER.size()):
			var rect: Rect2 = _get_target_rect(i)
			if rect.has_point(pos):
				_hover_target = TARGET_ORDER[i]
				break
		for i in range(EYE_STYLES.size()):
			var rect: Rect2 = _get_eye_rect(i)
			if rect.has_point(pos):
				_hover_eye = i
				break

# --- Layout position helpers ---

func _get_hue_center() -> Vector2:
	return Vector2(PANEL_PAD + HUE_RING_OUTER, PANEL_PAD + 36.0 + HUE_RING_OUTER)

func _get_sv_origin() -> Vector2:
	var hc := _get_hue_center()
	# SV box below hue ring
	return Vector2(PANEL_PAD, hc.y + HUE_RING_OUTER + 14.0)

func _get_target_section_y() -> float:
	return _get_sv_origin().y + SV_BOX_SIZE + SECTION_GAP

func _get_eye_section_y() -> float:
	return _get_target_section_y() + 62.0 + SECTION_GAP

func _get_shape_section_y() -> float:
	return _get_eye_section_y() + 20.0 + (ceili(EYE_STYLES.size() / 5.0)) * 46.0 + SECTION_GAP

func _get_elongation_slider_y() -> float:
	return _get_shape_section_y() + 28.0

func _get_bulge_slider_y() -> float:
	return _get_elongation_slider_y() + 38.0

func _get_zoom_slider_y() -> float:
	return _get_bulge_slider_y() + 42.0

func _get_rotation_dial_y() -> float:
	return _get_zoom_slider_y() + 36.0

func _get_stats_section_y() -> float:
	return _get_rotation_dial_y() + 52.0

func _get_target_rect(index: int) -> Rect2:
	var sy: float = _get_target_section_y() + 24.0
	var col: int = index % 3
	var row: int = index / 3
	var bx: float = PANEL_PAD + col * 78.0
	var by: float = sy + row * 32.0
	return Rect2(bx, by, 72.0, 28.0)

func _get_eye_rect(index: int) -> Rect2:
	var sy: float = _get_eye_section_y() + 22.0
	var col: int = index % 5
	var row: int = index / 5
	var bx: float = PANEL_PAD + col * 46.0
	var by: float = sy + row * 46.0
	return Rect2(bx, by, 40.0, 40.0)

# --- Slider hit-test helpers ---

func _get_slider_x() -> float:
	return PANEL_PAD

func _check_slider_click(pos: Vector2, slider_cy: float, t: float) -> bool:
	var thumb_x: float = _get_slider_x() + t * SLIDER_W
	return pos.distance_to(Vector2(thumb_x, slider_cy)) < SLIDER_THUMB_R + 6.0

func _check_slider_track_click(pos: Vector2) -> bool:
	var sx := _get_slider_x()
	# Check each slider track
	for slider_y in [_get_elongation_slider_y(), _get_bulge_slider_y(), _get_zoom_slider_y()]:
		if pos.y >= slider_y - 10 and pos.y <= slider_y + 10 and pos.x >= sx - 4 and pos.x <= sx + SLIDER_W + 4:
			var t: float = clampf((pos.x - sx) / SLIDER_W, 0.0, 1.0)
			if slider_y == _get_elongation_slider_y():
				_elongation_offset = -0.5 + t * 1.0
				elongation_offset_changed.emit(_elongation_offset)
			elif slider_y == _get_bulge_slider_y():
				_bulge = 0.5 + t * 1.5
				bulge_changed.emit(_bulge)
			elif slider_y == _get_zoom_slider_y():
				preview_zoom = 2.0 + t * 4.0
			return true
	return false

func _is_in_slider_area(pos: Vector2, slider_cy: float) -> bool:
	return pos.y >= slider_cy - 15 and pos.y <= slider_cy + 15 and pos.x >= _get_slider_x() - 10 and pos.x <= _get_slider_x() + SLIDER_W + 40

func _update_slider_from_mouse(pos: Vector2, slider_cy: float, which: String) -> void:
	var t: float = clampf((pos.x - _get_slider_x()) / SLIDER_W, 0.0, 1.0)
	match which:
		"elongation":
			_elongation_offset = -0.5 + t * 1.0
			elongation_offset_changed.emit(_elongation_offset)
		"bulge":
			_bulge = 0.5 + t * 1.5
			bulge_changed.emit(_bulge)
		"zoom":
			preview_zoom = 2.0 + t * 4.0

func _check_rotation_click(pos: Vector2) -> bool:
	var dial_center := Vector2(PANEL_PAD + ROTATION_DIAL_R, _get_rotation_dial_y())
	return pos.distance_to(dial_center) <= ROTATION_DIAL_R + 4.0

func _update_rotation_from_mouse(pos: Vector2) -> void:
	var dial_center := Vector2(PANEL_PAD + ROTATION_DIAL_R, _get_rotation_dial_y())
	preview_rotation = fmod(atan2(pos.y - dial_center.y, pos.x - dial_center.x) + TAU, TAU)

# --- Core update functions ---

func _update_hue_from_mouse(pos: Vector2, center: Vector2) -> void:
	_current_hue = fmod(atan2(pos.y - center.y, pos.x - center.x) / TAU + 1.0, 1.0)
	_emit_color()

func _update_sv_from_mouse(pos: Vector2) -> void:
	var origin: Vector2 = _get_sv_origin()
	_current_sat = clampf((pos.x - origin.x) / SV_BOX_SIZE, 0.0, 1.0)
	_current_val = 1.0 - clampf((pos.y - origin.y) / SV_BOX_SIZE, 0.0, 1.0)
	_emit_color()

func _is_in_sv_box(pos: Vector2) -> bool:
	var origin: Vector2 = _get_sv_origin()
	return pos.x >= origin.x and pos.x <= origin.x + SV_BOX_SIZE and pos.y >= origin.y and pos.y <= origin.y + SV_BOX_SIZE

func _emit_color() -> void:
	var col: Color = Color.from_hsv(_current_hue, _current_sat, _current_val)
	color_changed.emit(_active_target, col)

func _check_target_buttons(pos: Vector2) -> bool:
	for i in range(TARGET_ORDER.size()):
		if _get_target_rect(i).has_point(pos):
			_active_target = TARGET_ORDER[i]
			var custom: Dictionary = GameManager.creature_customization
			var col: Color = custom.get(_active_target, Color(0.5, 0.5, 0.5))
			_current_hue = col.h
			_current_sat = col.s
			_current_val = col.v
			AudioManager.play_ui_hover()
			return true
	return false

func _check_eye_buttons(pos: Vector2) -> bool:
	for i in range(EYE_STYLES.size()):
		if _get_eye_rect(i).has_point(pos):
			_selected_eye = EYE_STYLES[i]
			style_changed.emit("eye_style", _selected_eye)
			AudioManager.play_ui_select()
			return true
	return false

# --- Drawing ---

func _draw() -> void:
	var font := UIConstants.get_display_font()
	var panel_w: float = size.x if size.x > 10 else 300.0
	var panel_h: float = size.y if size.y > 10 else 700.0

	# === PANEL BACKGROUND ===
	draw_rect(Rect2(0, 0, panel_w, panel_h), Color(UIConstants.BG_PANEL.r, UIConstants.BG_PANEL.g, UIConstants.BG_PANEL.b, 0.92))
	# Left border accent line
	draw_rect(Rect2(0, 0, 2, panel_h), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.5))
	# Top border
	draw_rect(Rect2(0, 0, panel_w, 1), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4))

	# === SECTION: COLOR PICKER ===
	_draw_section_header(font, "COLOR PICKER", PANEL_PAD, PANEL_PAD + 18.0, panel_w)

	# === HUE RING ===
	var hue_center: Vector2 = _get_hue_center()
	var segments: int = 48
	for i in range(segments):
		var a1: float = TAU * i / segments
		var a2: float = TAU * (i + 1) / segments
		var hue: float = float(i) / segments
		var col: Color = Color.from_hsv(hue, 1.0, 1.0)
		var pts := PackedVector2Array([
			hue_center + Vector2(cos(a1), sin(a1)) * HUE_RING_INNER,
			hue_center + Vector2(cos(a1), sin(a1)) * HUE_RING_OUTER,
			hue_center + Vector2(cos(a2), sin(a2)) * HUE_RING_OUTER,
			hue_center + Vector2(cos(a2), sin(a2)) * HUE_RING_INNER,
		])
		draw_colored_polygon(pts, col)

	# Hue indicator
	var hue_angle: float = _current_hue * TAU
	var hue_pos: Vector2 = hue_center + Vector2(cos(hue_angle), sin(hue_angle)) * (HUE_RING_INNER + HUE_RING_OUTER) * 0.5
	draw_circle(hue_pos, 8.0, Color(1, 1, 1, 0.95))
	draw_arc(hue_pos, 8.0, 0, TAU, 12, Color(0, 0, 0, 0.8), 2.0)

	# Current color preview swatch inside hue ring
	var preview_col: Color = Color.from_hsv(_current_hue, _current_sat, _current_val)
	draw_circle(hue_center, HUE_RING_INNER * 0.6, preview_col)
	draw_arc(hue_center, HUE_RING_INNER * 0.6, 0, TAU, 16, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.5), 1.5)

	# === SV BOX (beside hue ring) ===
	var sv_org: Vector2 = _get_sv_origin()
	var sv_steps: int = 20
	for row in range(sv_steps):
		for col_idx in range(sv_steps):
			var s: float = float(col_idx) / sv_steps
			var v: float = 1.0 - float(row) / sv_steps
			var px: float = sv_org.x + col_idx * SV_BOX_SIZE / sv_steps
			var py: float = sv_org.y + row * SV_BOX_SIZE / sv_steps
			var cell_w: float = SV_BOX_SIZE / sv_steps + 1.0
			draw_rect(Rect2(px, py, cell_w, cell_w), Color.from_hsv(_current_hue, s, v))

	# SV indicator
	var sv_px: float = sv_org.x + _current_sat * SV_BOX_SIZE
	var sv_py: float = sv_org.y + (1.0 - _current_val) * SV_BOX_SIZE
	draw_circle(Vector2(sv_px, sv_py), 7.0, Color(1, 1, 1, 0.95))
	draw_arc(Vector2(sv_px, sv_py), 7.0, 0, TAU, 12, Color(0, 0, 0, 0.7), 2.0)

	# SV box border
	draw_rect(Rect2(sv_org.x - 1, sv_org.y - 1, SV_BOX_SIZE + 2, SV_BOX_SIZE + 2), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), false, 1.0)

	# === COLOR TARGET BUTTONS (2 rows of 3) ===
	var target_y: float = _get_target_section_y()
	_draw_section_header(font, "COLOR TARGET", PANEL_PAD, target_y, panel_w)

	for i in range(TARGET_ORDER.size()):
		var rect: Rect2 = _get_target_rect(i)
		var is_active: bool = TARGET_ORDER[i] == _active_target
		var is_hover: bool = TARGET_ORDER[i] == _hover_target
		var bg: Color = Color(0.15, 0.28, 0.48, 0.88) if is_active else (Color(0.10, 0.18, 0.34, 0.65) if is_hover else Color(0.07, 0.12, 0.22, 0.55))
		draw_rect(rect, bg)
		var brd: Color = Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.85) if is_active else Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4)
		draw_rect(rect, brd, false, 1.0)
		# Color swatch dot
		var swatch_col: Color = GameManager.creature_customization.get(TARGET_ORDER[i], Color(0.5, 0.5, 0.5))
		draw_circle(Vector2(rect.position.x + 12, rect.position.y + 14), 5.0, swatch_col)
		# Label
		var label: String = TARGET_LABELS[TARGET_ORDER[i]]
		var tc: Color = Color(UIConstants.TEXT_BRIGHT.r, UIConstants.TEXT_BRIGHT.g, UIConstants.TEXT_BRIGHT.b, 0.97) if is_active else Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.8)
		draw_string(font, Vector2(rect.position.x + 24, rect.position.y + 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tc)

	# === EYE STYLE SELECTOR ===
	var eye_y: float = _get_eye_section_y()
	_draw_section_header(font, "EYE STYLE", PANEL_PAD, eye_y, panel_w)

	for i in range(EYE_STYLES.size()):
		var rect: Rect2 = _get_eye_rect(i)
		var is_sel: bool = EYE_STYLES[i] == _selected_eye
		var is_hov: bool = i == _hover_eye
		var bg: Color = Color(0.15, 0.28, 0.48, 0.88) if is_sel else (Color(0.10, 0.18, 0.34, 0.65) if is_hov else Color(0.07, 0.12, 0.22, 0.45))
		draw_rect(rect, bg)
		if is_sel:
			draw_rect(rect, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.75), false, 1.5)
		var ec: Vector2 = rect.position + rect.size * 0.5
		_draw_eye_icon(EYE_STYLES[i], ec)

	# === BODY SHAPE ===
	var shape_y: float = _get_shape_section_y()
	_draw_section_header(font, "BODY SHAPE", PANEL_PAD, shape_y, panel_w)

	var elong_cy: float = _get_elongation_slider_y()
	draw_string(font, Vector2(PANEL_PAD, elong_cy - 10), "STRETCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.9))
	_draw_slider(elong_cy, (_elongation_offset + 0.5) / 1.0, "%+.2f" % _elongation_offset, _dragging_elongation)

	var bulge_cy: float = _get_bulge_slider_y()
	draw_string(font, Vector2(PANEL_PAD, bulge_cy - 10), "WIDTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.9))
	_draw_slider(bulge_cy, (_bulge - 0.5) / 1.5, "%.1fx" % _bulge, _dragging_bulge)

	# === PREVIEW CONTROLS ===
	var zoom_cy: float = _get_zoom_slider_y()
	_draw_section_header(font, "PREVIEW", PANEL_PAD, zoom_cy - 20.0, panel_w)
	draw_string(font, Vector2(PANEL_PAD, zoom_cy - 6), "ZOOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.9))
	_draw_slider(zoom_cy + 4, (preview_zoom - 2.0) / 4.0, "%.1fx" % preview_zoom, _dragging_zoom)

	# Preview Rotation dial
	var rot_cy: float = _get_rotation_dial_y()
	draw_string(font, Vector2(PANEL_PAD, rot_cy - 16), "ROTATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.9))
	var dial_cx: float = PANEL_PAD + ROTATION_DIAL_R
	draw_arc(Vector2(dial_cx, rot_cy), ROTATION_DIAL_R, 0, TAU, 32, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.6), 1.5)
	draw_arc(Vector2(dial_cx, rot_cy), ROTATION_DIAL_R - 4.0, 0, TAU, 28, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3), 1.0)
	var rot_dir: Vector2 = Vector2(cos(preview_rotation), sin(preview_rotation))
	draw_line(Vector2(dial_cx, rot_cy), Vector2(dial_cx, rot_cy) + rot_dir * (ROTATION_DIAL_R - 2.0), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.95), 2.5)
	draw_circle(Vector2(dial_cx, rot_cy) + rot_dir * (ROTATION_DIAL_R - 2.0), 4.0, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.95))
	var deg_str: String = "%d°" % int(rad_to_deg(preview_rotation))
	draw_string(font, Vector2(dial_cx + ROTATION_DIAL_R + 10, rot_cy + 6), deg_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.9))

	# === STATS SUMMARY ===
	var stats_y: float = _get_stats_section_y()
	if stats_y + 20.0 < panel_h:
		_draw_stats_summary(font, stats_y, panel_w, panel_h)

func _draw_section_header(font: Font, label: String, x: float, y: float, panel_w: float) -> void:
	# Alternating section tint band
	draw_rect(Rect2(0, y - 12, panel_w, 26), Color(0.08, 0.12, 0.22, 0.45))
	# Alien glyph prefix
	var glyph: String = str(ALIEN_GLYPHS[int(fmod(_time * 0.3 + float(label.hash() % 20), float(ALIEN_GLYPHS.size())))])
	draw_string(font, Vector2(x, y), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.6))
	# Label
	draw_string(font, Vector2(x + 14, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.95))
	# Underline
	var label_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_line(Vector2(x + 14, y + 4), Vector2(x + 14 + label_w + 10, y + 4), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.45), 1.0)
	# Tech bracket accents
	draw_line(Vector2(x - 2, y - 8), Vector2(x - 2, y + 6), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.5)
	draw_line(Vector2(x - 2, y - 8), Vector2(x + 8, y - 8), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.5)

func _draw_slider(cy: float, t: float, value_str: String, is_dragging: bool) -> void:
	var font := UIConstants.get_display_font()
	var sx: float = _get_slider_x()
	# Track background
	draw_line(Vector2(sx, cy), Vector2(sx + SLIDER_W, cy), Color(0.18, 0.30, 0.42, 0.7), 4.0)
	# Filled portion
	draw_line(Vector2(sx, cy), Vector2(sx + t * SLIDER_W, cy), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.8), 4.0)
	# Thumb
	var thumb_x: float = sx + t * SLIDER_W
	var thumb_col: Color = Color(0.55, 0.95, 1.0, 1.0) if is_dragging else Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.95)
	var thumb_r: float = SLIDER_THUMB_R + (2.0 if is_dragging else 0.0)
	draw_circle(Vector2(thumb_x, cy), thumb_r, thumb_col)
	draw_arc(Vector2(thumb_x, cy), thumb_r, 0, TAU, 12, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.7), 1.5)
	# Value text
	draw_string(font, Vector2(sx + SLIDER_W + 8, cy + 5), value_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.9))

func _draw_stats_summary(font: Font, stats_y: float, panel_w: float, panel_h: float) -> void:
	_draw_section_header(font, "MUTATION STATS", PANEL_PAD, stats_y, panel_w)

	# Sum all active mutation bonuses
	var stat_totals: Dictionary = {}
	for m in GameManager.active_mutations:
		var stat: Dictionary = m.get("stat", {})
		var mid: String = m.get("id", "")
		var mult: float = GameManager.get_tier_multiplier(mid)
		for key in stat:
			if key not in stat_totals:
				stat_totals[key] = 0.0
			stat_totals[key] += stat[key] * mult

	var row_y: float = stats_y + 28.0
	if stat_totals.is_empty():
		draw_string(font, Vector2(PANEL_PAD + 4, row_y), "No mutations yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.6))
		return

	var stat_labels: Dictionary = {
		"speed": "Speed", "attack": "Attack", "max_health": "Health",
		"armor": "Armor", "stealth": "Stealth", "detection": "Detection",
		"beam_range": "Beam Range", "energy_efficiency": "Efficiency",
		"health_regen": "Regen",
	}
	var stat_colors: Dictionary = {
		"speed": Color(0.3, 0.9, 0.5), "attack": Color(0.9, 0.4, 0.3),
		"max_health": Color(0.9, 0.3, 0.5), "armor": Color(0.5, 0.6, 0.7),
		"stealth": Color(0.5, 0.4, 0.8), "detection": Color(0.3, 0.7, 0.9),
		"beam_range": Color(0.8, 0.7, 0.2), "energy_efficiency": Color(0.3, 0.8, 0.6),
		"health_regen": Color(0.4, 0.9, 0.4),
	}

	for key in stat_totals:
		if row_y > panel_h - 20:
			break
		var val: float = stat_totals[key]
		var sign: String = "+" if val > 0 else ""
		var label: String = stat_labels.get(key, key.capitalize())
		var col: Color = stat_colors.get(key, Color(0.5, 0.7, 0.8))
		# Bar background
		draw_rect(Rect2(PANEL_PAD, row_y - 14, panel_w - PANEL_PAD * 2, 22), Color(0.07, 0.11, 0.20, 0.55))
		# Bar fill
		var bar_t: float = clampf(absf(val), 0.0, 1.0)
		var bar_w: float = (panel_w - PANEL_PAD * 2 - 110) * bar_t
		draw_rect(Rect2(PANEL_PAD + 100, row_y - 12, bar_w, 20), Color(col.r, col.g, col.b, 0.3))
		# Label + value
		draw_string(font, Vector2(PANEL_PAD + 4, row_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col.r, col.g, col.b, 0.9))
		draw_string(font, Vector2(PANEL_PAD + 100, row_y), "%s%.0f%%" % [sign, val * 100.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col.r, col.g, col.b, 1.0))
		row_y += 26.0

func _draw_eye_icon(style: String, center: Vector2) -> void:
	# Scaled icons for 40×40 grid cells
	match style:
		"round":
			draw_circle(center, 12.0, Color(1, 1, 1, 0.8))
			draw_circle(center, 6.0, Color(0.02, 0.02, 0.08, 0.9))
		"anime":
			draw_circle(center, 13.0, Color(1, 1, 1, 0.8))
			draw_circle(center, 8.0, Color(0.2, 0.5, 0.9, 0.9))
			draw_circle(center, 4.0, Color(0.02, 0.02, 0.08, 0.9))
			draw_circle(center + Vector2(-2.5, -2.5), 2.0, Color(1, 1, 1, 0.6))
		"compound":
			for r in range(2):
				for c in range(2):
					var p: Vector2 = center + Vector2((c - 0.5) * 10, (r - 0.5) * 10)
					draw_circle(p, 6.0, Color(0.3, 0.6, 0.9, 0.7))
					draw_circle(p, 2.5, Color(0.02, 0.02, 0.08, 0.8))
		"googly":
			draw_circle(center, 14.0, Color(1, 1, 1, 0.8))
			var wobble: Vector2 = Vector2(sin(_time * 5.0), cos(_time * 4.0)) * 5.0
			draw_circle(center + wobble, 6.0, Color(0.02, 0.02, 0.08, 0.9))
		"slit":
			draw_circle(center, 12.0, Color(0.8, 0.7, 0.2, 0.7))
			draw_line(center + Vector2(0, -7.0), center + Vector2(0, 7.0), Color(0.02, 0.02, 0.08, 0.9), 3.0, true)
		"lashed":
			draw_circle(center, 13.0, Color(1, 1, 1, 0.85))
			draw_circle(center, 8.0, Color(0.5, 0.2, 0.7, 0.9))
			draw_circle(center, 3.5, Color(0.02, 0.02, 0.08, 0.9))
			draw_circle(center + Vector2(-2.5, -2.5), 2.0, Color(1, 1, 1, 0.7))
			for i in range(3):
				var a: float = -PI * 0.6 + i * PI * 0.3
				var tip: Vector2 = center + Vector2(cos(a), sin(a)) * 17.0
				var base: Vector2 = center + Vector2(cos(a), sin(a)) * 12.0
				draw_line(base, tip, Color(0.1, 0.1, 0.15, 0.9), 1.8, true)
		"fierce":
			var pts: PackedVector2Array = PackedVector2Array([
				center + Vector2(-12, 0),
				center + Vector2(-5, -9),
				center + Vector2(10, -5),
				center + Vector2(12, 0),
				center + Vector2(7, 7),
				center + Vector2(-7, 5),
			])
			draw_colored_polygon(pts, Color(1, 1, 1, 0.85))
			draw_circle(center + Vector2(2, 0), 5.0, Color(0.8, 0.3, 0.1, 0.9))
			draw_circle(center + Vector2(2, 0), 2.5, Color(0.02, 0.02, 0.08, 0.9))
			draw_line(center + Vector2(-12, -7), center + Vector2(12, -9), Color(0.15, 0.15, 0.2, 0.8), 2.5, true)
		"dot":
			draw_circle(center, 8.0, Color(0.02, 0.02, 0.1, 0.95))
			draw_circle(center + Vector2(-1.2, -1.2), 2.5, Color(1, 1, 1, 0.4))
		"star":
			draw_circle(center, 12.0, Color(1, 1, 1, 0.8))
			var star_pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var a: float = -PI * 0.5 + TAU * i / 10.0
				var r: float = 8.5 if i % 2 == 0 else 3.5
				star_pts.append(center + Vector2(cos(a) * r, sin(a) * r))
			draw_colored_polygon(star_pts, Color(0.9, 0.6, 0.1, 0.9))
			draw_circle(center, 2.5, Color(0.02, 0.02, 0.08, 0.9))
		"hypnotize":
			for ring_i in range(4):
				var r: float = 3.0 + ring_i * 3.0
				var ring_col: Color = Color(0.6, 0.2, 0.9, 0.8) if ring_i % 2 == 0 else Color(0.1, 0.05, 0.2, 0.7)
				draw_arc(center, r, 0, TAU, 16, ring_col, 2.0, true)
			draw_circle(center, 2.0, Color(1, 1, 1, 0.9))
		"x_eyes":
			draw_circle(center, 12.0, Color(1, 1, 1, 0.7))
			draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), Color(0.1, 0.1, 0.15, 0.9), 3.0, true)
			draw_line(center + Vector2(6, -6), center + Vector2(-6, 6), Color(0.1, 0.1, 0.15, 0.9), 3.0, true)
		"heart":
			draw_circle(center, 12.0, Color(1, 1, 1, 0.8))
			# Heart shape
			var hpts: PackedVector2Array = PackedVector2Array()
			for i in range(20):
				var t: float = float(i) / 20.0 * TAU
				var hx: float = 6.0 * (sin(t) * sin(t) * sin(t))
				var hy: float = -(5.0 * cos(t) - 2.0 * cos(2.0 * t) - cos(3.0 * t) - 0.5 * cos(4.0 * t))
				hpts.append(center + Vector2(hx, hy * 0.6 - 1.0))
			draw_colored_polygon(hpts, Color(0.95, 0.2, 0.4, 0.9))
		"spiral":
			draw_circle(center, 12.0, Color(0.2, 0.7, 0.9, 0.6))
			var prev_pt: Vector2 = center
			for i in range(20):
				var t: float = float(i + 1) / 20.0
				var a: float = t * TAU * 2.0 + _time * 2.0
				var r: float = t * 9.0
				var pt: Vector2 = center + Vector2(cos(a) * r, sin(a) * r)
				draw_line(prev_pt, pt, Color(0.02, 0.02, 0.1, 0.85), 1.8, true)
				prev_pt = pt
		"alien":
			# Tall almond-shaped eye
			var alien_pts: PackedVector2Array = PackedVector2Array()
			for i in range(16):
				var t: float = float(i) / 16.0 * TAU
				var ax: float = cos(t) * 6.0
				var ay: float = sin(t) * 14.0
				alien_pts.append(center + Vector2(ax, ay))
			draw_colored_polygon(alien_pts, Color(0.05, 0.15, 0.1, 0.95))
			draw_circle(center, 3.0, Color(0.1, 0.8, 0.6, 0.6))

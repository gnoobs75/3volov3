extends Control
## Pre-game setup screen for RTS Colony Wars.
## Procedural _draw() UI — map selection, difficulty, AI count, then START.

signal pregame_start_pressed
signal pregame_back_pressed

var _time: float = 0.0
var _appear_t: float = 0.0

# Selection state
var _selected_map: int = 0  # 0=petri_dish, 1=blood_vessel, 2=brain_cortex
var _selected_difficulty: int = 2  # 0-4
var _selected_ai_count: int = 3  # 1-3
var _hover_map: int = -1
var _hover_diff: int = -1
var _hover_ai: int = -1
var _hover_start: bool = false
var _hover_back: bool = false
var _hover_replay: bool = false

# Replay browser state
var _replay_browser_open: bool = false
var _replay_list: Array = []
var _hover_replay_item: int = -1
var _hover_replay_close: bool = false
var _replay_scroll_offset: int = 0
const REPLAY_ITEM_H: float = 44.0
const REPLAY_VISIBLE_COUNT: int = 6
const REPLAY_BTN_W: float = 180.0
const REPLAY_BTN_H: float = 44.0

const MAP_IDS: Array = ["petri_dish", "blood_vessel", "brain_cortex"]
const MAP_NAMES: Array = ["Petri Dish", "Blood Vessel", "Brain Cortex"]
const MAP_DESCS: Array = [
	"Circular arena, open terrain",
	"Rectangular lanes, choke points",
	"Irregular blob, organic edges",
]
const DIFF_NAMES: Array = ["NOOB", "EASY", "MEDIUM", "HARD", "SWEATY"]
const DIFF_COLORS: Array = [
	Color(0.3, 0.9, 0.5),  # green
	Color(0.5, 0.9, 0.3),  # yellow-green
	Color(1.0, 0.9, 0.3),  # yellow
	Color(1.0, 0.5, 0.2),  # orange
	Color(1.0, 0.25, 0.2),  # red
]

# Colors — bioluminescent organic theme
const BG_COLOR: Color = Color(0.02, 0.03, 0.05, 0.95)
const ACCENT: Color = Color(0.2, 0.9, 0.6)
const ACCENT_DIM: Color = Color(0.1, 0.5, 0.35)
const TEXT_LIGHT: Color = Color(0.9, 0.95, 1.0)
const TEXT_DIM: Color = Color(0.5, 0.55, 0.6)
const CARD_BG: Color = Color(0.04, 0.06, 0.1, 0.9)
const CARD_SELECTED: Color = Color(0.2, 0.9, 0.6, 0.8)
const CARD_UNSELECTED: Color = Color(0.3, 0.35, 0.4, 0.5)
const BTN_BG: Color = Color(0.04, 0.08, 0.14, 0.9)
const BTN_HOVER: Color = Color(0.08, 0.16, 0.28, 0.95)

# Layout constants
const MAP_CARD_W: float = 210.0
const MAP_CARD_H: float = 160.0
const MAP_CARD_GAP: float = 24.0
const DIFF_BTN_W: float = 100.0
const DIFF_BTN_H: float = 40.0
const DIFF_BTN_GAP: float = 12.0
const AI_BTN_W: float = 70.0
const AI_BTN_H: float = 40.0
const AI_BTN_GAP: float = 12.0
const START_BTN_W: float = 240.0
const START_BTN_H: float = 56.0
const BACK_BTN_W: float = 140.0
const BACK_BTN_H: float = 44.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Sync from GameManager
	_selected_map = MAP_IDS.find(GameManager.rts_map_id)
	if _selected_map < 0:
		_selected_map = 0
	_selected_difficulty = clampi(GameManager.rts_difficulty, 0, 4)
	_selected_ai_count = clampi(GameManager.rts_ai_count, 1, 3)

func _process(delta: float) -> void:
	_time += delta
	_appear_t = minf(_appear_t + delta * 3.0, 1.0)
	# Hover detection
	var mouse := get_local_mouse_position()
	var vp := get_viewport_rect().size
	_hover_map = -1
	_hover_diff = -1
	_hover_ai = -1
	_hover_start = false
	_hover_back = false
	_hover_replay = false
	_hover_replay_item = -1
	_hover_replay_close = false

	if _replay_browser_open:
		# Replay browser hover detection
		var panel_rect: Rect2 = _get_replay_panel_rect(vp)
		var close_rect: Rect2 = _get_replay_close_rect(vp)
		_hover_replay_close = close_rect.has_point(mouse)
		var visible_items: int = maxi(mini(_replay_list.size() - _replay_scroll_offset, REPLAY_VISIBLE_COUNT), 0)
		for i in range(visible_items):
			var item_rect: Rect2 = _get_replay_item_rect(vp, i)
			if item_rect.has_point(mouse):
				_hover_replay_item = i + _replay_scroll_offset
		queue_redraw()
		return

	# Map cards
	for i in range(3):
		if _get_map_card_rect(vp, i).has_point(mouse):
			_hover_map = i
	# Difficulty buttons
	for i in range(5):
		if _get_diff_btn_rect(vp, i).has_point(mouse):
			_hover_diff = i
	# AI count buttons
	for i in range(3):
		if _get_ai_btn_rect(vp, i).has_point(mouse):
			_hover_ai = i
	# Start / Back / Replay
	if _get_start_rect(vp).has_point(mouse):
		_hover_start = true
	if _get_back_rect(vp).has_point(mouse):
		_hover_back = true
	if _get_replay_btn_rect(vp).has_point(mouse):
		_hover_replay = true
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Replay browser clicks take priority when open
		if _replay_browser_open:
			if _hover_replay_close:
				AudioManager.play_ui_select()
				_replay_browser_open = false
			elif _hover_replay_item >= 0 and _hover_replay_item < _replay_list.size():
				AudioManager.play_ui_select()
				_watch_replay(_replay_list[_hover_replay_item])
			return
		if _hover_map >= 0:
			_selected_map = _hover_map
			GameManager.rts_map_id = MAP_IDS[_selected_map]
			AudioManager.play_ui_select()
		elif _hover_diff >= 0:
			_selected_difficulty = _hover_diff
			GameManager.rts_difficulty = _selected_difficulty
			AudioManager.play_ui_select()
		elif _hover_ai >= 0:
			_selected_ai_count = _hover_ai + 1
			GameManager.rts_ai_count = _selected_ai_count
			AudioManager.play_ui_select()
		elif _hover_start:
			AudioManager.play_ui_select()
			_start_game()
		elif _hover_back:
			AudioManager.play_ui_select()
			_go_back()
		elif _hover_replay:
			AudioManager.play_ui_select()
			_open_replay_browser()
	# Scroll wheel for replay list
	elif _replay_browser_open and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_replay_scroll_offset = maxi(_replay_scroll_offset - 1, 0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_replay_scroll_offset = mini(_replay_scroll_offset + 1, maxi(_replay_list.size() - REPLAY_VISIBLE_COUNT, 0))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _replay_browser_open:
				_replay_browser_open = false
				AudioManager.play_ui_select()
			else:
				AudioManager.play_ui_select()
				_go_back()
			get_viewport().set_input_as_handled()

func _start_game() -> void:
	pregame_start_pressed.emit()
	GameManager.go_to_rts_stage()

func _go_back() -> void:
	pregame_back_pressed.emit()
	visible = false

func _open_replay_browser() -> void:
	# Load replay list from the recorder's static helper
	var ReplayRecorder = preload("res://scripts/rts_stage/rts_replay_recorder.gd")
	_replay_list = ReplayRecorder.list_replays()
	_replay_scroll_offset = 0
	_replay_browser_open = true

func _watch_replay(replay_info: Dictionary) -> void:
	var path: String = replay_info.get("path", "")
	if path.is_empty():
		return
	GameManager.rts_replay_file = path
	# Load map/difficulty from replay initial state
	GameManager.rts_map_id = replay_info.get("map_id", "petri_dish")
	GameManager.rts_difficulty = replay_info.get("difficulty", 2)
	GameManager.go_to_rts_stage()

# === RECT HELPERS ===

func _get_map_card_rect(vp: Vector2, index: int) -> Rect2:
	var total_w: float = MAP_CARD_W * 3.0 + MAP_CARD_GAP * 2.0
	var start_x: float = (vp.x - total_w) * 0.5
	var y: float = vp.y * 0.28
	return Rect2(start_x + index * (MAP_CARD_W + MAP_CARD_GAP), y, MAP_CARD_W, MAP_CARD_H)

func _get_diff_btn_rect(vp: Vector2, index: int) -> Rect2:
	var total_w: float = DIFF_BTN_W * 5.0 + DIFF_BTN_GAP * 4.0
	var start_x: float = (vp.x - total_w) * 0.5
	var y: float = vp.y * 0.60
	return Rect2(start_x + index * (DIFF_BTN_W + DIFF_BTN_GAP), y, DIFF_BTN_W, DIFF_BTN_H)

func _get_ai_btn_rect(vp: Vector2, index: int) -> Rect2:
	var total_w: float = AI_BTN_W * 3.0 + AI_BTN_GAP * 2.0
	var start_x: float = (vp.x - total_w) * 0.5
	var y: float = vp.y * 0.72
	return Rect2(start_x + index * (AI_BTN_W + AI_BTN_GAP), y, AI_BTN_W, AI_BTN_H)

func _get_start_rect(vp: Vector2) -> Rect2:
	return Rect2((vp.x - START_BTN_W) * 0.5, vp.y * 0.84, START_BTN_W, START_BTN_H)

func _get_back_rect(vp: Vector2) -> Rect2:
	return Rect2(40.0, vp.y * 0.87, BACK_BTN_W, BACK_BTN_H)

func _get_replay_btn_rect(vp: Vector2) -> Rect2:
	return Rect2(vp.x - REPLAY_BTN_W - 40.0, vp.y * 0.87, REPLAY_BTN_W, REPLAY_BTN_H)

func _get_replay_panel_rect(vp: Vector2) -> Rect2:
	var panel_w: float = 480.0
	var panel_h: float = REPLAY_ITEM_H * REPLAY_VISIBLE_COUNT + 80.0
	return Rect2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5, panel_w, panel_h)

func _get_replay_close_rect(vp: Vector2) -> Rect2:
	var panel: Rect2 = _get_replay_panel_rect(vp)
	return Rect2(panel.position.x + panel.size.x - 40.0, panel.position.y + 8.0, 32.0, 32.0)

func _get_replay_item_rect(vp: Vector2, visual_index: int) -> Rect2:
	var panel: Rect2 = _get_replay_panel_rect(vp)
	var items_y: float = panel.position.y + 55.0
	return Rect2(panel.position.x + 16.0, items_y + visual_index * REPLAY_ITEM_H, panel.size.x - 32.0, REPLAY_ITEM_H - 4.0)

# === DRAWING ===

func _draw() -> void:
	var vp := get_viewport_rect().size
	var a: float = _appear_t
	var font := UIConstants.get_display_font()
	var mono := UIConstants.get_mono_font()

	# 1. Dark background overlay
	draw_rect(Rect2(0, 0, vp.x, vp.y), BG_COLOR)

	# 2. Subtle grid
	_draw_subtle_grid(vp, a)

	# 3. Title: "COLONY WARS"
	var title := "COLONY WARS"
	var title_size: int = 44
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size)
	var tx: float = (vp.x - ts.x) * 0.5
	var ty: float = vp.y * 0.12
	# Glow
	draw_circle(Vector2(vp.x * 0.5, ty - 6), 100.0, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.04 * a))
	# Shadow
	draw_string(font, Vector2(tx + 2, ty + 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.0, 0.05, 0.1, 0.6 * a))
	# Main
	draw_string(font, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(ACCENT.r, ACCENT.g, ACCENT.b, a))
	# Subtitle
	var sub := "Pre-Game Setup"
	var sub_s := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
	draw_string(font, Vector2((vp.x - sub_s.x) * 0.5, ty + 30), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.7 * a))
	# Divider
	var line_w: float = 260.0 * a
	var line_y: float = ty + 44
	draw_line(Vector2(vp.x * 0.5 - line_w * 0.5, line_y), Vector2(vp.x * 0.5 + line_w * 0.5, line_y), Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.5 * a), 1.0)

	# 4. Section label: "MAP"
	var map_label := "MAP"
	var map_ls := font.get_string_size(map_label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	draw_string(font, Vector2((vp.x - map_ls.x) * 0.5, vp.y * 0.24), map_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.8 * a))

	# 5. Map cards
	for i in range(3):
		_draw_map_card(vp, i, a)

	# 6. Section label: "DIFFICULTY"
	var diff_label := "DIFFICULTY"
	var diff_ls := font.get_string_size(diff_label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	draw_string(font, Vector2((vp.x - diff_ls.x) * 0.5, vp.y * 0.56), diff_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.8 * a))

	# 7. Difficulty buttons
	for i in range(5):
		_draw_diff_btn(vp, i, a)

	# 8. Section label: "OPPONENTS"
	var ai_label := "OPPONENTS"
	var ai_ls := font.get_string_size(ai_label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	draw_string(font, Vector2((vp.x - ai_ls.x) * 0.5, vp.y * 0.68), ai_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.8 * a))

	# 9. AI count buttons
	for i in range(3):
		_draw_ai_btn(vp, i, a)

	# 10. START button (pulsing green)
	_draw_start_button(vp, a)

	# 11. BACK button
	_draw_back_button(vp, a)

	# 12. WATCH REPLAY button (bottom right)
	_draw_replay_button(vp, a)

	# 13. Corner frame
	UIConstants.draw_corner_frame(self, Rect2(8, 8, vp.x - 16, vp.y - 16), Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.25 * a))

	# 14. Match stats summary (bottom right, shifted up for replay button)
	_draw_stats_summary(vp, a)

	# 15. Replay browser overlay (drawn last, on top)
	if _replay_browser_open:
		_draw_replay_browser(vp, a)

func _draw_subtle_grid(vp: Vector2, a: float) -> void:
	var spacing: float = 50.0
	var grid_a: float = 0.04 * a
	var col := Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, grid_a)
	var gx: int = int(vp.x / spacing) + 1
	var gy: int = int(vp.y / spacing) + 1
	for i in range(gx):
		draw_line(Vector2(i * spacing, 0), Vector2(i * spacing, vp.y), col, 0.5)
	for i in range(gy):
		draw_line(Vector2(0, i * spacing), Vector2(vp.x, i * spacing), col, 0.5)

func _draw_map_card(vp: Vector2, index: int, a: float) -> void:
	var rect := _get_map_card_rect(vp, index)
	var is_selected: bool = index == _selected_map
	var is_hovered: bool = index == _hover_map
	var font := UIConstants.get_display_font()

	# Background
	var bg: Color = CARD_BG
	if is_hovered:
		bg = Color(0.06, 0.10, 0.16, 0.95)
	draw_rect(rect, bg)

	# Border
	var border_col: Color = CARD_SELECTED if is_selected else CARD_UNSELECTED
	if is_hovered and not is_selected:
		border_col = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	var border_w: float = 2.5 if is_selected else 1.5
	draw_rect(rect, border_col, false, border_w)

	# Selection indicator glow
	if is_selected:
		draw_rect(Rect2(rect.position.x - 3, rect.position.y - 3, rect.size.x + 6, rect.size.y + 6), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.08 * a))

	# Procedural thumbnail centered in top portion
	var thumb_center := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 55.0)
	_draw_map_thumbnail(index, thumb_center, a)

	# Map name (bold)
	var name_str: String = MAP_NAMES[index]
	var name_s := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
	var name_col: Color = TEXT_LIGHT if is_selected else TEXT_DIM
	draw_string(font, Vector2(rect.position.x + (rect.size.x - name_s.x) * 0.5, rect.position.y + 110.0), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, Color(name_col.r, name_col.g, name_col.b, a))

	# Description
	var desc_str: String = MAP_DESCS[index]
	var desc_s := font.get_string_size(desc_str, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - desc_s.x) * 0.5, rect.position.y + 132.0), desc_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.8 * a))

	# "SELECTED" badge
	if is_selected:
		var badge := "SELECTED"
		var badge_s := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_TINY)
		var badge_x: float = rect.position.x + (rect.size.x - badge_s.x) * 0.5
		var badge_y: float = rect.position.y + 150.0
		draw_string(font, Vector2(badge_x, badge_y), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7 * a))

func _draw_map_thumbnail(index: int, center: Vector2, a: float) -> void:
	var outline_col := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5 * a)
	var fill_col := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.08 * a)
	match index:
		0:
			# Petri Dish: circle
			draw_arc(center, 32.0, 0, TAU, 32, outline_col, 1.5, true)
			draw_circle(center, 30.0, fill_col)
			# Inner ring
			draw_arc(center, 18.0, 0, TAU, 20, Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.3 * a), 0.8, true)
			# Cross mark at center
			draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3 * a), 0.8)
			draw_line(center + Vector2(0, -6), center + Vector2(0, 6), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3 * a), 0.8)
		1:
			# Blood Vessel: horizontal oval / rectangle with rounded feel
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(24):
				var angle: float = TAU * float(i) / 24.0
				pts.append(center + Vector2(cos(angle) * 44.0, sin(angle) * 22.0))
			draw_colored_polygon(pts, fill_col)
			draw_polyline(pts, outline_col, 1.5, true)
			# Lane lines
			draw_line(center + Vector2(-38, -7), center + Vector2(38, -7), Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.25 * a), 0.8)
			draw_line(center + Vector2(-38, 7), center + Vector2(38, 7), Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.25 * a), 0.8)
		2:
			# Brain Cortex: irregular blob
			var pts: PackedVector2Array = PackedVector2Array()
			var blob_offsets: Array = [1.2, 0.85, 1.1, 0.75, 1.3, 0.9, 1.15, 0.8, 1.25, 0.95, 1.0, 0.88]
			for i in range(blob_offsets.size()):
				var angle: float = TAU * float(i) / float(blob_offsets.size())
				var r: float = 28.0 * blob_offsets[i]
				pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
			draw_colored_polygon(pts, fill_col)
			draw_polyline(pts, outline_col, 1.5, true)
			# Close the blob outline
			if pts.size() > 1:
				draw_line(pts[pts.size() - 1], pts[0], outline_col, 1.5)
			# Fold lines
			draw_line(center + Vector2(-10, -15), center + Vector2(5, 10), Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.2 * a), 0.8)
			draw_line(center + Vector2(8, -12), center + Vector2(-3, 14), Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.2 * a), 0.8)

func _draw_diff_btn(vp: Vector2, index: int, a: float) -> void:
	var rect := _get_diff_btn_rect(vp, index)
	var is_selected: bool = index == _selected_difficulty
	var is_hovered: bool = index == _hover_diff
	var font := UIConstants.get_display_font()

	# Background
	var bg: Color = BTN_BG
	if is_selected:
		bg = Color(DIFF_COLORS[index].r * 0.15, DIFF_COLORS[index].g * 0.15, DIFF_COLORS[index].b * 0.1, 0.9)
	elif is_hovered:
		bg = BTN_HOVER
	draw_rect(rect, bg)

	# Border
	var border_col: Color
	if is_selected:
		border_col = Color(DIFF_COLORS[index].r, DIFF_COLORS[index].g, DIFF_COLORS[index].b, 0.9)
	elif is_hovered:
		border_col = Color(DIFF_COLORS[index].r, DIFF_COLORS[index].g, DIFF_COLORS[index].b, 0.5)
	else:
		border_col = Color(0.3, 0.35, 0.4, 0.4)
	draw_rect(rect, border_col, false, 1.5 if is_selected else 1.0)

	# Label
	var label_str: String = DIFF_NAMES[index]
	var label_s := font.get_string_size(label_str, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
	var text_col: Color
	if is_selected:
		text_col = Color(DIFF_COLORS[index].r, DIFF_COLORS[index].g, DIFF_COLORS[index].b, a)
	elif is_hovered:
		text_col = Color(TEXT_LIGHT.r, TEXT_LIGHT.g, TEXT_LIGHT.b, 0.9 * a)
	else:
		text_col = Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.7 * a)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - label_s.x) * 0.5, rect.position.y + rect.size.y * 0.5 + UIConstants.FONT_CAPTION * 0.35), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, text_col)

func _draw_ai_btn(vp: Vector2, index: int, a: float) -> void:
	var rect := _get_ai_btn_rect(vp, index)
	var count: int = index + 1
	var is_selected: bool = count == _selected_ai_count
	var is_hovered: bool = index == _hover_ai
	var font := UIConstants.get_display_font()

	# Background
	var bg: Color = BTN_BG
	if is_selected:
		bg = Color(ACCENT.r * 0.12, ACCENT.g * 0.12, ACCENT.b * 0.08, 0.9)
	elif is_hovered:
		bg = BTN_HOVER
	draw_rect(rect, bg)

	# Border
	var border_col: Color
	if is_selected:
		border_col = CARD_SELECTED
	elif is_hovered:
		border_col = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	else:
		border_col = Color(0.3, 0.35, 0.4, 0.4)
	draw_rect(rect, border_col, false, 1.5 if is_selected else 1.0)

	# Label
	var label_str: String = str(count)
	var label_s := font.get_string_size(label_str, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
	var text_col: Color
	if is_selected:
		text_col = Color(ACCENT.r, ACCENT.g, ACCENT.b, a)
	elif is_hovered:
		text_col = Color(TEXT_LIGHT.r, TEXT_LIGHT.g, TEXT_LIGHT.b, 0.9 * a)
	else:
		text_col = Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.7 * a)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - label_s.x) * 0.5, rect.position.y + rect.size.y * 0.5 + UIConstants.FONT_SUBHEADER * 0.35), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, text_col)

func _draw_start_button(vp: Vector2, a: float) -> void:
	var rect := _get_start_rect(vp)
	var font := UIConstants.get_display_font()

	# Pulsing alpha via sine wave
	var pulse: float = 0.7 + 0.3 * sin(_time * 2.5)

	# Background with pulse
	var bg := Color(ACCENT.r * 0.08, ACCENT.g * 0.08, ACCENT.b * 0.06, 0.9 * pulse)
	if _hover_start:
		bg = Color(ACCENT.r * 0.15, ACCENT.g * 0.15, ACCENT.b * 0.1, 0.95)
	draw_rect(rect, bg)

	# Outer glow when hovered
	if _hover_start:
		draw_rect(Rect2(rect.position.x - 4, rect.position.y - 4, rect.size.x + 8, rect.size.y + 8), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.1 * a))

	# Border
	var border_col := Color(ACCENT.r, ACCENT.g, ACCENT.b, (0.8 if _hover_start else 0.5) * pulse * a)
	draw_rect(rect, border_col, false, 2.5 if _hover_start else 2.0)

	# Corner brackets
	UIConstants.draw_corner_frame(self, Rect2(rect.position.x - 3, rect.position.y - 3, rect.size.x + 6, rect.size.y + 6), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4 * pulse * a))

	# Label
	var label := "START"
	var label_s := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_HEADER)
	var text_col := Color(ACCENT.r, ACCENT.g, ACCENT.b, pulse * a)
	if _hover_start:
		text_col = Color(TEXT_LIGHT.r, TEXT_LIGHT.g, TEXT_LIGHT.b, a)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - label_s.x) * 0.5, rect.position.y + rect.size.y * 0.5 + UIConstants.FONT_HEADER * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_HEADER, text_col)

	# Scan line on hover
	if _hover_start:
		var scan_x: float = fmod(_time * 100.0, rect.size.x)
		draw_line(Vector2(rect.position.x + scan_x, rect.position.y + 2), Vector2(rect.position.x + scan_x, rect.position.y + rect.size.y - 2), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2), 2.0)

func _draw_back_button(vp: Vector2, a: float) -> void:
	var rect := _get_back_rect(vp)
	var font := UIConstants.get_display_font()

	# Background
	var bg := Color(0.08, 0.08, 0.10, 0.8)
	if _hover_back:
		bg = Color(0.12, 0.12, 0.16, 0.9)
	draw_rect(rect, bg)

	# Border
	var border_col := Color(0.4, 0.42, 0.45, 0.5 if _hover_back else 0.3)
	draw_rect(rect, border_col, false, 1.0)

	# Label
	var label := "BACK"
	var label_s := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	var text_col := Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, (0.9 if _hover_back else 0.6) * a)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - label_s.x) * 0.5, rect.position.y + rect.size.y * 0.5 + UIConstants.FONT_BODY * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, text_col)

func _draw_replay_button(vp: Vector2, a: float) -> void:
	var rect := _get_replay_btn_rect(vp)
	var font := UIConstants.get_display_font()

	# Background
	var bg := Color(0.06, 0.08, 0.14, 0.8)
	if _hover_replay:
		bg = Color(0.10, 0.14, 0.22, 0.9)
	draw_rect(rect, bg)

	# Border
	var border_col := Color(UIConstants.STAT_YELLOW.r, UIConstants.STAT_YELLOW.g, UIConstants.STAT_YELLOW.b, 0.4 if _hover_replay else 0.25)
	draw_rect(rect, border_col, false, 1.0)

	# Label
	var label := "WATCH REPLAY"
	var label_s := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
	var text_col := Color(UIConstants.STAT_YELLOW.r, UIConstants.STAT_YELLOW.g, UIConstants.STAT_YELLOW.b, (0.9 if _hover_replay else 0.6) * a)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - label_s.x) * 0.5, rect.position.y + rect.size.y * 0.5 + UIConstants.FONT_CAPTION * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, text_col)

func _draw_replay_browser(vp: Vector2, a: float) -> void:
	var font := UIConstants.get_display_font()
	var mono := UIConstants.get_mono_font()

	# Dim background
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.0, 0.0, 0.0, 0.6 * a))

	# Panel
	var panel := _get_replay_panel_rect(vp)
	draw_rect(panel, Color(0.04, 0.06, 0.12, 0.96))
	draw_rect(panel, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.5 * a), false, 1.5)
	UIConstants.draw_corner_frame(self, panel.grow(3), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.3 * a))

	# Title
	var title := "REPLAY BROWSER"
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
	draw_string(font, Vector2(panel.position.x + (panel.size.x - ts.x) * 0.5, panel.position.y + 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, a))

	# Separator
	draw_line(Vector2(panel.position.x + 16, panel.position.y + 45), Vector2(panel.position.x + panel.size.x - 16, panel.position.y + 45), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3 * a), 1.0)

	# Close button (X)
	var close_rect := _get_replay_close_rect(vp)
	var close_col := Color(UIConstants.STAT_RED.r, UIConstants.STAT_RED.g, UIConstants.STAT_RED.b, 0.8 if _hover_replay_close else 0.4)
	draw_string(font, Vector2(close_rect.position.x + 8, close_rect.position.y + 22), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, close_col)

	# Replay items
	if _replay_list.is_empty():
		var empty_text := "No replays found"
		var empty_s := mono.get_string_size(empty_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
		draw_string(mono, Vector2(panel.position.x + (panel.size.x - empty_s.x) * 0.5, panel.position.y + panel.size.y * 0.5), empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.6 * a))
		return

	var visible_count: int = mini(_replay_list.size() - _replay_scroll_offset, REPLAY_VISIBLE_COUNT)
	for i in range(visible_count):
		var real_index: int = i + _replay_scroll_offset
		var item_rect: Rect2 = _get_replay_item_rect(vp, i)
		var info: Dictionary = _replay_list[real_index]
		var is_hovered: bool = real_index == _hover_replay_item

		# Item background
		var item_bg: Color = Color(0.08, 0.12, 0.20, 0.8) if is_hovered else Color(0.05, 0.07, 0.12, 0.6)
		draw_rect(item_rect, item_bg)
		if is_hovered:
			draw_rect(item_rect, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.3), false, 1.0)

		# Replay name
		var replay_name: String = info.get("name", "unknown")
		draw_string(mono, Vector2(item_rect.position.x + 10, item_rect.position.y + 18), replay_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(TEXT_LIGHT.r, TEXT_LIGHT.g, TEXT_LIGHT.b, 0.9 * a))

		# Map + time info on second line
		var map_id: String = info.get("map_id", "petri_dish")
		var total_time: float = info.get("total_time", 0.0)
		var mins: int = int(total_time) / 60
		var secs: int = int(total_time) % 60
		var detail_text: String = "%s  |  %02d:%02d  |  %d events" % [map_id, mins, secs, info.get("event_count", 0)]
		draw_string(mono, Vector2(item_rect.position.x + 10, item_rect.position.y + 34), detail_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.7 * a))

	# Scroll indicator
	if _replay_list.size() > REPLAY_VISIBLE_COUNT:
		var indicator_text: String = "%d-%d of %d" % [_replay_scroll_offset + 1, _replay_scroll_offset + visible_count, _replay_list.size()]
		var ind_s := mono.get_string_size(indicator_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_TINY)
		draw_string(mono, Vector2(panel.position.x + (panel.size.x - ind_s.x) * 0.5, panel.position.y + panel.size.y - 12), indicator_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.5 * a))

func _draw_stats_summary(vp: Vector2, a: float) -> void:
	var font := UIConstants.get_mono_font()
	var stats: Dictionary = GameManager.get_rts_stats()
	var wins: int = stats.get("total_wins", 0)
	var losses: int = stats.get("total_losses", 0)
	var total: int = wins + losses
	if total == 0:
		return
	var x: float = vp.x - 200.0
	var y: float = vp.y * 0.80
	draw_string(font, Vector2(x, y), "RECORD", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.5 * a))
	y += 16.0
	var record_str := "%dW / %dL" % [wins, losses]
	draw_string(font, Vector2(x, y), record_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7 * a))
	var best_time: float = stats.get("best_time", 0.0)
	if best_time > 0.0:
		y += 16.0
		var mins: int = int(best_time) / 60
		var secs: int = int(best_time) % 60
		draw_string(font, Vector2(x, y), "BEST: %d:%02d" % [mins, secs], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.5 * a))

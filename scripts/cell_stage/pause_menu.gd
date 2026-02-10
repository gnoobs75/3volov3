extends Control
## Pause menu: ESC toggles. Has two views: main (resume/quit) and help (controls + survival tips).
## Draws procedurally — no scene file needed.

signal resumed
signal quit_to_menu

var _time: float = 0.0
var _hover_button: int = -1  # 0=Resume, 1=Help, 2=Quit (main) or 0=Back (help)
var _showing_help: bool = false

const MAIN_BUTTONS: Array = [
	{"label": "RESUME", "action": "resume"},
	{"label": "HELP", "action": "help"},
	{"label": "QUIT TO MENU", "action": "quit"},
]

# Controls reference for help screen
const CONTROLS: Array = [
	{"keys": "WASD", "label": "Move / Thrust"},
	{"keys": "SHIFT", "label": "Sprint (costs energy)"},
	{"keys": "LMB", "label": "Tractor Beam (auto-pulls to you)"},
	{"keys": "RMB", "label": "Jet Stream (push enemies)"},
	{"keys": "E", "label": "Fire Toxin (attack)"},
	{"keys": "Q", "label": "Reproduce (costs energy)"},
	{"keys": "F", "label": "Metabolize (restore energy)"},
	{"keys": "TAB", "label": "CRISPR Gene Editor"},
]

# Survival tips for help screen
const TIPS: Array = [
	{"icon": "!", "label": "Parasites latch on and drain you", "color_r": 0.9, "color_g": 0.3, "color_b": 0.3},
	{"icon": "~", "label": "Evade parasites — outrun or dodge them", "color_r": 1.0, "color_g": 0.8, "color_b": 0.3},
	{"icon": "*", "label": "Purple anemones cleanse parasites on contact", "color_r": 0.7, "color_g": 0.3, "color_b": 0.9},
	{"icon": "+", "label": "Some creatures eat parasites off you (symbiosis)", "color_r": 0.3, "color_g": 0.9, "color_b": 0.5},
	{"icon": "o", "label": "Collect biomolecules to grow and evolve", "color_r": 0.4, "color_g": 0.8, "color_b": 1.0},
	{"icon": "x", "label": "Avoid poison clouds and hazard creatures", "color_r": 0.9, "color_g": 0.6, "color_b": 0.2},
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	_time += delta
	var vp := get_viewport_rect().size
	var mouse := get_local_mouse_position()
	_hover_button = -1

	if _showing_help:
		# Only a "Back" button at the bottom
		var back_rect := _get_help_back_rect(vp)
		if back_rect.has_point(mouse):
			_hover_button = 0
	else:
		for i in range(MAIN_BUTTONS.size()):
			var btn_rect := _get_button_rect(vp, i)
			if btn_rect.has_point(mouse):
				_hover_button = i
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _showing_help:
			if _hover_button == 0:
				AudioManager.play_ui_select()
				_showing_help = false
		else:
			if _hover_button == 0:
				AudioManager.play_ui_select()
				resumed.emit()
			elif _hover_button == 1:
				AudioManager.play_ui_select()
				_showing_help = true
			elif _hover_button == 2:
				AudioManager.play_ui_select()
				quit_to_menu.emit()

func _get_button_rect(vp: Vector2, index: int) -> Rect2:
	var bw: float = 200.0
	var bh: float = 40.0
	var cx: float = vp.x * 0.5
	var by: float = vp.y * 0.45 + index * 55.0
	return Rect2(cx - bw * 0.5, by, bw, bh)

func _get_help_back_rect(vp: Vector2) -> Rect2:
	var bw: float = 160.0
	var bh: float = 36.0
	return Rect2((vp.x - bw) * 0.5, vp.y * 0.88, bw, bh)

func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	# Dim background
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.0, 0.02, 0.05, 0.75))

	if _showing_help:
		_draw_help_screen(vp, font)
	else:
		_draw_main_screen(vp, font)

func _draw_main_screen(vp: Vector2, font: Font) -> void:
	# Title
	var title := "PAUSED"
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	draw_string(font, Vector2((vp.x - ts.x) * 0.5, vp.y * 0.3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.5, 0.85, 1.0, 0.95))

	# Decorative line under title
	var line_w: float = 200.0
	var line_y: float = vp.y * 0.3 + 12.0
	draw_line(Vector2(vp.x * 0.5 - line_w * 0.5, line_y), Vector2(vp.x * 0.5 + line_w * 0.5, line_y), Color(0.3, 0.6, 0.8, 0.5), 1.0)

	# Quick controls reference
	var controls: Array = [
		"WASD - Move    SHIFT - Sprint",
		"LMB - Beam    RMB - Jet",
		"E - Toxin    Q - Reproduce",
		"F - Metabolize    TAB - CRISPR",
	]
	var cy: float = vp.y * 0.36
	for line in controls:
		var ls := font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, Vector2((vp.x - ls.x) * 0.5, cy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.65, 0.75, 0.6))
		cy += 20.0

	# Buttons
	for i in range(MAIN_BUTTONS.size()):
		var rect := _get_button_rect(vp, i)
		var hover: bool = (_hover_button == i)
		var bg_color := Color(0.1, 0.25, 0.4, 0.8) if hover else Color(0.06, 0.12, 0.2, 0.7)
		var border_color := Color(0.4, 0.8, 1.0, 0.8) if hover else Color(0.2, 0.4, 0.6, 0.5)
		var text_color := Color(0.7, 0.95, 1.0, 1.0) if hover else Color(0.5, 0.75, 0.85, 0.9)

		draw_rect(rect, bg_color)
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 1), border_color)
		draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - 1, rect.size.x, 1), border_color)
		draw_rect(Rect2(rect.position.x, rect.position.y, 1, rect.size.y), border_color)
		draw_rect(Rect2(rect.position.x + rect.size.x - 1, rect.position.y, 1, rect.size.y), border_color)

		var label: String = MAIN_BUTTONS[i].label
		var label_s := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		draw_string(font, Vector2(rect.position.x + (rect.size.x - label_s.x) * 0.5, rect.position.y + 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)

	# Hint
	var hint := "ESC to resume"
	var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	draw_string(font, Vector2((vp.x - hs.x) * 0.5, vp.y * 0.72), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.5, 0.6, 0.4))

func _draw_help_screen(vp: Vector2, font: Font) -> void:
	# Title
	var title := "HELP"
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font, Vector2((vp.x - ts.x) * 0.5, vp.y * 0.08), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.5, 0.85, 1.0, 0.95))
	var line_w: float = 160.0
	var line_y: float = vp.y * 0.08 + 10.0
	draw_line(Vector2(vp.x * 0.5 - line_w * 0.5, line_y), Vector2(vp.x * 0.5 + line_w * 0.5, line_y), Color(0.3, 0.6, 0.8, 0.4), 1.0)

	# --- Left panel: Controls ---
	var left_w: float = 360.0
	var line_h: float = 28.0
	var left_h: float = CONTROLS.size() * line_h + 48.0
	var left_x: float = vp.x * 0.5 - left_w - 20.0
	var left_y: float = vp.y * 0.14

	# Background
	draw_rect(Rect2(left_x, left_y, left_w, left_h), Color(0.02, 0.04, 0.08, 0.5))
	draw_rect(Rect2(left_x, left_y, left_w, 1), Color(0.4, 0.7, 1.0, 0.3))
	draw_rect(Rect2(left_x, left_y + left_h - 1, left_w, 1), Color(0.4, 0.7, 1.0, 0.3))

	# Section title
	draw_string(font, Vector2(left_x + 12, left_y + 26), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.4, 0.8, 1.0, 0.9))

	# Control rows
	var key_fs: int = 14
	var label_fs: int = 13
	for i in range(CONTROLS.size()):
		var p: Dictionary = CONTROLS[i]
		var ry: float = left_y + 42.0 + i * line_h
		var key_text: String = p.keys
		var key_w: float = font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs).x + 12.0
		draw_rect(Rect2(left_x + 12, ry - 14, key_w, 22), Color(0.15, 0.3, 0.5, 0.6))
		draw_string(font, Vector2(left_x + 18, ry + 2), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs, Color(0.7, 0.95, 1.0, 0.95))
		draw_string(font, Vector2(left_x + 18 + key_w + 8, ry + 2), p.label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs, Color(0.5, 0.75, 0.85, 0.8))

	# --- Right panel: Survival Tips ---
	var right_w: float = 360.0
	var right_h: float = TIPS.size() * line_h + 48.0
	var right_x: float = vp.x * 0.5 + 20.0
	var right_y: float = vp.y * 0.14

	# Background
	draw_rect(Rect2(right_x, right_y, right_w, right_h), Color(0.06, 0.03, 0.08, 0.5))
	draw_rect(Rect2(right_x, right_y, right_w, 1), Color(0.7, 0.4, 0.9, 0.3))
	draw_rect(Rect2(right_x, right_y + right_h - 1, right_w, 1), Color(0.7, 0.4, 0.9, 0.3))

	# Section title
	draw_string(font, Vector2(right_x + 12, right_y + 26), "SURVIVAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.6, 0.9, 0.9))

	# Tip rows
	for i in range(TIPS.size()):
		var tip: Dictionary = TIPS[i]
		var ry: float = right_y + 42.0 + i * line_h
		var icon_col := Color(tip.color_r, tip.color_g, tip.color_b)
		draw_circle(Vector2(right_x + 20, ry - 3), 8.0, Color(icon_col.r, icon_col.g, icon_col.b, 0.2))
		draw_string(font, Vector2(right_x + 15, ry + 3), tip.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(icon_col.r, icon_col.g, icon_col.b, 0.9))
		draw_string(font, Vector2(right_x + 36, ry + 2), tip.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.7, 0.8, 0.85))

	# Back button
	var back_rect := _get_help_back_rect(vp)
	var hover: bool = (_hover_button == 0)
	var bg_color := Color(0.1, 0.25, 0.4, 0.8) if hover else Color(0.06, 0.12, 0.2, 0.7)
	var border_color := Color(0.4, 0.8, 1.0, 0.8) if hover else Color(0.2, 0.4, 0.6, 0.5)
	var text_color := Color(0.7, 0.95, 1.0, 1.0) if hover else Color(0.5, 0.75, 0.85, 0.9)

	draw_rect(back_rect, bg_color)
	draw_rect(Rect2(back_rect.position.x, back_rect.position.y, back_rect.size.x, 1), border_color)
	draw_rect(Rect2(back_rect.position.x, back_rect.position.y + back_rect.size.y - 1, back_rect.size.x, 1), border_color)
	draw_rect(Rect2(back_rect.position.x, back_rect.position.y, 1, back_rect.size.y), border_color)
	draw_rect(Rect2(back_rect.position.x + back_rect.size.x - 1, back_rect.position.y, 1, back_rect.size.y), border_color)

	var back_label := "BACK"
	var bls := font.get_string_size(back_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, Vector2(back_rect.position.x + (back_rect.size.x - bls.x) * 0.5, back_rect.position.y + 24), back_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)

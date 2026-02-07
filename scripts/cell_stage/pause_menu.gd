extends Control
## Pause menu: ESC toggles, shows controls, resume/quit buttons.
## Draws procedurally — no scene file needed.

signal resumed
signal quit_to_menu

var _time: float = 0.0
var _hover_button: int = -1  # 0=Resume, 1=Quit

const BUTTONS: Array = [
	{"label": "RESUME", "action": "resume"},
	{"label": "QUIT TO MENU", "action": "quit"},
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	_time += delta
	# Check hover
	var vp := get_viewport_rect().size
	var mouse := get_local_mouse_position()
	_hover_button = -1
	for i in range(BUTTONS.size()):
		var btn_rect := _get_button_rect(vp, i)
		if btn_rect.has_point(mouse):
			_hover_button = i
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover_button == 0:
			AudioManager.play_ui_select()
			resumed.emit()
		elif _hover_button == 1:
			AudioManager.play_ui_select()
			quit_to_menu.emit()

func _get_button_rect(vp: Vector2, index: int) -> Rect2:
	var bw: float = 200.0
	var bh: float = 40.0
	var cx: float = vp.x * 0.5
	var by: float = vp.y * 0.52 + index * 55.0
	return Rect2(cx - bw * 0.5, by, bw, bh)

func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	# Dim background
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.0, 0.02, 0.05, 0.75))

	# Title
	var title := "PAUSED"
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	draw_string(font, Vector2((vp.x - ts.x) * 0.5, vp.y * 0.3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.5, 0.85, 1.0, 0.95))

	# Decorative line under title
	var line_w: float = 200.0
	var line_y: float = vp.y * 0.3 + 12.0
	draw_line(Vector2(vp.x * 0.5 - line_w * 0.5, line_y), Vector2(vp.x * 0.5 + line_w * 0.5, line_y), Color(0.3, 0.6, 0.8, 0.5), 1.0)

	# Controls reference
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
	for i in range(BUTTONS.size()):
		var rect := _get_button_rect(vp, i)
		var hover: bool = (_hover_button == i)
		var bg_color := Color(0.1, 0.25, 0.4, 0.8) if hover else Color(0.06, 0.12, 0.2, 0.7)
		var border_color := Color(0.4, 0.8, 1.0, 0.8) if hover else Color(0.2, 0.4, 0.6, 0.5)
		var text_color := Color(0.7, 0.95, 1.0, 1.0) if hover else Color(0.5, 0.75, 0.85, 0.9)

		draw_rect(rect, bg_color)
		# Border
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 1), border_color)
		draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - 1, rect.size.x, 1), border_color)
		draw_rect(Rect2(rect.position.x, rect.position.y, 1, rect.size.y), border_color)
		draw_rect(Rect2(rect.position.x + rect.size.x - 1, rect.position.y, 1, rect.size.y), border_color)

		var label: String = BUTTONS[i].label
		var label_s := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		draw_string(font, Vector2(rect.position.x + (rect.size.x - label_s.x) * 0.5, rect.position.y + 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)

	# Version / hint at bottom
	var hint := "ESC to resume"
	var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	draw_string(font, Vector2((vp.x - hs.x) * 0.5, vp.y * 0.72), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.5, 0.6, 0.4))

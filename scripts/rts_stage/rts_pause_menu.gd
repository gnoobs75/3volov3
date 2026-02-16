extends Control
## RTS pause menu. ESC to toggle, Resume / Quit buttons.
## process_mode ALWAYS so it works while paused.

var _visible_menu: bool = false
var _appear_t: float = 0.0
var _hover_btn: int = -1
const BTN_LABELS: Array = ["Resume", "Quit to Menu"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true

func show_menu() -> void:
	_visible_menu = true
	_appear_t = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true

func hide_menu() -> void:
	_visible_menu = false
	_appear_t = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false

func is_showing() -> bool:
	return _visible_menu

func toggle() -> void:
	if _visible_menu:
		hide_menu()
	else:
		show_menu()

func _process(delta: float) -> void:
	if _visible_menu:
		_appear_t = minf(_appear_t + delta * 4.0, 1.0)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not _visible_menu:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp: Vector2 = get_viewport_rect().size
		for i in range(BTN_LABELS.size()):
			if _get_btn_rect(vp, i).has_point(event.position):
				_handle_btn(i)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion:
		var vp: Vector2 = get_viewport_rect().size
		_hover_btn = -1
		for i in range(BTN_LABELS.size()):
			if _get_btn_rect(vp, i).has_point(event.position):
				_hover_btn = i

func _handle_btn(idx: int) -> void:
	match idx:
		0: hide_menu()
		1:
			get_tree().paused = false
			GameManager.go_to_menu()

func _get_btn_rect(vp: Vector2, idx: int) -> Rect2:
	var bw: float = 200.0
	var bh: float = 44.0
	var gap: float = 12.0
	var total_h: float = BTN_LABELS.size() * bh + (BTN_LABELS.size() - 1) * gap
	var sx: float = vp.x * 0.5 - bw * 0.5
	var sy: float = vp.y * 0.5 - total_h * 0.5 + idx * (bh + gap)
	return Rect2(sx, sy, bw, bh)

func _draw() -> void:
	if not _visible_menu:
		return
	var vp: Vector2 = get_viewport_rect().size
	var font: Font = UIConstants.get_display_font()
	var a: float = _appear_t

	# Dark overlay
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.0, 0.0, 0.0, 0.6 * a))

	# Blueprint grid
	UIConstants.draw_blueprint_grid(self, vp, a * 0.2)

	# Title
	var title: String = "PAUSED"
	var title_size: int = 42
	var ts: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size)
	draw_string(font, Vector2((vp.x - ts.x) * 0.5, vp.y * 0.32), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(UIConstants.TEXT_TITLE.r, UIConstants.TEXT_TITLE.g, UIConstants.TEXT_TITLE.b, a))

	# Buttons
	for i in range(BTN_LABELS.size()):
		var rect: Rect2 = _get_btn_rect(vp, i)
		var hovered: bool = _hover_btn == i
		var bg: Color = UIConstants.BTN_BG_HOVER if hovered else UIConstants.BTN_BG
		var border: Color = UIConstants.BTN_BORDER_HOVER if hovered else UIConstants.BTN_BORDER
		draw_rect(rect, Color(bg.r, bg.g, bg.b, bg.a * a))
		draw_rect(rect, Color(border.r, border.g, border.b, border.a * a), false, 1.5)
		var label: String = BTN_LABELS[i]
		var ls: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
		var tc: Color = UIConstants.BTN_TEXT_HOVER if hovered else UIConstants.BTN_TEXT
		draw_string(font, Vector2(rect.position.x + (rect.size.x - ls.x) * 0.5, rect.position.y + 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, Color(tc.r, tc.g, tc.b, tc.a * a))

	# Corner frame
	var frame_rect: Rect2 = Rect2(vp.x * 0.25, vp.y * 0.25, vp.x * 0.5, vp.y * 0.5)
	UIConstants.draw_corner_frame(self, frame_rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3 * a))

extends Control
## RTS pause menu. ESC to toggle, Resume / Save / Load / Quit buttons.
## process_mode ALWAYS so it works while paused.

var _visible_menu: bool = false
var _appear_t: float = 0.0
var _hover_btn: int = -1
const BTN_LABELS: Array = ["Resume", "Save Game", "Load Game", "Quit to Menu"]

# Load sub-menu state
var _load_view: bool = false
var _save_list: Array = []  # [{name, timestamp_str, game_time, ...}]
var _hover_save: int = -1
var _scroll_offset: int = 0
const MAX_VISIBLE_SAVES: int = 6

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true

func show_menu() -> void:
	_visible_menu = true
	_appear_t = 0.0
	_load_view = false
	_hover_save = -1
	_scroll_offset = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true

func hide_menu() -> void:
	_visible_menu = false
	_appear_t = 0.0
	_load_view = false
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
		if _load_view:
			_load_view = false
		else:
			hide_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp: Vector2 = get_viewport_rect().size
		if _load_view:
			# Check back button
			if _get_back_btn_rect(vp).has_point(event.position):
				_load_view = false
				get_viewport().set_input_as_handled()
				return
			# Check save slot clicks
			for i in range(mini(MAX_VISIBLE_SAVES, _save_list.size() - _scroll_offset)):
				if _get_save_slot_rect(vp, i).has_point(event.position):
					_handle_load_slot(_scroll_offset + i)
					get_viewport().set_input_as_handled()
					return
		else:
			for i in range(BTN_LABELS.size()):
				if _get_btn_rect(vp, i).has_point(event.position):
					_handle_btn(i)
					get_viewport().set_input_as_handled()
					return

	# Scroll in load view
	if _load_view and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_offset = maxi(_scroll_offset - 1, 0)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_offset = mini(_scroll_offset + 1, maxi(_save_list.size() - MAX_VISIBLE_SAVES, 0))
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		var vp: Vector2 = get_viewport_rect().size
		_hover_btn = -1
		_hover_save = -1
		if _load_view:
			for i in range(mini(MAX_VISIBLE_SAVES, _save_list.size() - _scroll_offset)):
				if _get_save_slot_rect(vp, i).has_point(event.position):
					_hover_save = i
		else:
			for i in range(BTN_LABELS.size()):
				if _get_btn_rect(vp, i).has_point(event.position):
					_hover_btn = i

func _handle_btn(idx: int) -> void:
	match idx:
		0: hide_menu()  # Resume
		1: _do_save()   # Save Game
		2: _enter_load_view()  # Load Game
		3:                     # Quit to Menu
			get_tree().paused = false
			GameManager.go_to_menu()

func _do_save() -> void:
	var sm: Node = _get_save_manager()
	if not sm:
		return
	if sm.save_game("manual_save"):
		sm._show_toast("Game Saved")
	hide_menu()

func _enter_load_view() -> void:
	var sm: Node = _get_save_manager()
	if not sm:
		return
	_save_list = sm.get_save_list()
	_load_view = true
	_scroll_offset = 0
	_hover_save = -1

func _handle_load_slot(save_idx: int) -> void:
	if save_idx < 0 or save_idx >= _save_list.size():
		return
	var sm: Node = _get_save_manager()
	if not sm:
		return
	var slot_name: String = _save_list[save_idx].get("name", "")
	if sm.load_game(slot_name):
		sm._show_toast("Game Loaded")
	hide_menu()

func _get_save_manager() -> Node:
	var stage: Node = get_tree().get_first_node_in_group("rts_stage")
	if stage and stage.has_method("get_save_manager"):
		return stage.get_save_manager()
	return null

func _get_btn_rect(vp: Vector2, idx: int) -> Rect2:
	var bw: float = 200.0
	var bh: float = 44.0
	var gap: float = 12.0
	var total_h: float = BTN_LABELS.size() * bh + (BTN_LABELS.size() - 1) * gap
	var sx: float = vp.x * 0.5 - bw * 0.5
	var sy: float = vp.y * 0.5 - total_h * 0.5 + idx * (bh + gap)
	return Rect2(sx, sy, bw, bh)

func _get_save_slot_rect(vp: Vector2, visible_idx: int) -> Rect2:
	var sw: float = 340.0
	var sh: float = 50.0
	var gap: float = 6.0
	var sx: float = vp.x * 0.5 - sw * 0.5
	var sy: float = vp.y * 0.34 + visible_idx * (sh + gap)
	return Rect2(sx, sy, sw, sh)

func _get_back_btn_rect(vp: Vector2) -> Rect2:
	var bw: float = 120.0
	var bh: float = 36.0
	return Rect2(vp.x * 0.5 - bw * 0.5, vp.y * 0.78, bw, bh)

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

	if _load_view:
		_draw_load_view(vp, font, a)
	else:
		_draw_main_menu(vp, font, a)

	# Corner frame
	var frame_rect: Rect2 = Rect2(vp.x * 0.25, vp.y * 0.2, vp.x * 0.5, vp.y * 0.6)
	UIConstants.draw_corner_frame(self, frame_rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3 * a))

func _draw_main_menu(vp: Vector2, font: Font, a: float) -> void:
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

func _draw_load_view(vp: Vector2, font: Font, a: float) -> void:
	# Title
	var title: String = "LOAD GAME"
	var title_size: int = 36
	var ts: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size)
	draw_string(font, Vector2((vp.x - ts.x) * 0.5, vp.y * 0.28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(UIConstants.TEXT_TITLE.r, UIConstants.TEXT_TITLE.g, UIConstants.TEXT_TITLE.b, a))

	if _save_list.is_empty():
		var no_saves: String = "No saved games found"
		var ns_size: Vector2 = font.get_string_size(no_saves, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		draw_string(font, Vector2((vp.x - ns_size.x) * 0.5, vp.y * 0.5), no_saves, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.6, 0.7, a))
	else:
		# Draw save slots
		var visible_count: int = mini(MAX_VISIBLE_SAVES, _save_list.size() - _scroll_offset)
		for i in range(visible_count):
			var save_idx: int = _scroll_offset + i
			var save: Dictionary = _save_list[save_idx]
			var rect: Rect2 = _get_save_slot_rect(vp, i)
			var hovered: bool = _hover_save == i
			var bg: Color = UIConstants.BTN_BG_HOVER if hovered else UIConstants.BTN_BG
			var border: Color = UIConstants.BTN_BORDER_HOVER if hovered else UIConstants.BTN_BORDER
			draw_rect(rect, Color(bg.r, bg.g, bg.b, bg.a * a))
			draw_rect(rect, Color(border.r, border.g, border.b, border.a * a), false, 1.5)

			# Slot name
			var slot_name: String = save.get("name", "unknown")
			var tc: Color = UIConstants.BTN_TEXT_HOVER if hovered else UIConstants.BTN_TEXT
			draw_string(font, Vector2(rect.position.x + 12, rect.position.y + 20), slot_name, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x * 0.5), 14, Color(tc.r, tc.g, tc.b, tc.a * a))

			# Timestamp and game time
			var time_str: String = save.get("timestamp_str", "")
			var game_time: float = save.get("game_time", 0.0)
			var game_min: int = int(game_time) / 60
			var game_sec: int = int(game_time) % 60
			var detail: String = "%s  |  %d:%02d" % [time_str, game_min, game_sec]
			draw_string(font, Vector2(rect.position.x + 12, rect.position.y + 40), detail, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 24), 11, Color(0.5, 0.6, 0.7, 0.8 * a))

		# Scroll indicators
		if _scroll_offset > 0:
			draw_string(font, Vector2(vp.x * 0.5 - 10, vp.y * 0.33), "^", HORIZONTAL_ALIGNMENT_CENTER, 20, 16, Color(0.7, 0.8, 1.0, a * 0.6))
		if _scroll_offset + MAX_VISIBLE_SAVES < _save_list.size():
			var bottom_y: float = vp.y * 0.34 + MAX_VISIBLE_SAVES * 56.0 + 4.0
			draw_string(font, Vector2(vp.x * 0.5 - 10, bottom_y), "v", HORIZONTAL_ALIGNMENT_CENTER, 20, 16, Color(0.7, 0.8, 1.0, a * 0.6))

	# Back button
	var back_rect: Rect2 = _get_back_btn_rect(vp)
	draw_rect(back_rect, Color(UIConstants.BTN_BG.r, UIConstants.BTN_BG.g, UIConstants.BTN_BG.b, UIConstants.BTN_BG.a * a))
	draw_rect(back_rect, Color(UIConstants.BTN_BORDER.r, UIConstants.BTN_BORDER.g, UIConstants.BTN_BORDER.b, UIConstants.BTN_BORDER.a * a), false, 1.5)
	var back_label: String = "Back"
	var bls: Vector2 = font.get_string_size(back_label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
	draw_string(font, Vector2(back_rect.position.x + (back_rect.size.x - bls.x) * 0.5, back_rect.position.y + 24), back_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, Color(UIConstants.BTN_TEXT.r, UIConstants.BTN_TEXT.g, UIConstants.BTN_TEXT.b, UIConstants.BTN_TEXT.a * a))

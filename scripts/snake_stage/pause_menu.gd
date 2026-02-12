extends Control
## Pause menu for Snake Stage: ESC toggles, shows controls, resume/quit buttons.
## Draws procedurally with sci-fi lab aesthetic — blueprint grid, scan lines, stats.
## Has MAIN and SETTINGS views.

signal resumed
signal quit_to_menu

enum View { MAIN, SETTINGS }

var _time: float = 0.0
var _hover_button: int = -1  # MAIN: 0=Resume, 1=Settings, 2=Quit  |  SETTINGS: 0=Back
var _view: View = View.MAIN
var _scan_line_y: float = 0.0
var _dragging_slider: String = ""  # "master", "sfx", "music", or ""

const MAIN_BUTTONS: Array = [
	{"label": "RESUME", "action": "resume"},
	{"label": "SETTINGS", "action": "settings"},
	{"label": "QUIT TO MENU", "action": "quit"},
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var vp := get_viewport_rect().size
	_scan_line_y = fmod(_scan_line_y + delta * 40.0, vp.y + 40.0)
	var mouse := get_local_mouse_position()
	_hover_button = -1

	if _view == View.SETTINGS:
		var back_rect := _get_back_rect(vp)
		if back_rect.has_point(mouse):
			_hover_button = 0
	else:
		for i in range(MAIN_BUTTONS.size()):
			var btn_rect := _get_button_rect(vp, i)
			if btn_rect.has_point(mouse):
				_hover_button = i
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var vp_node := get_viewport()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		AudioManager.play_ui_select()
		if _view == View.SETTINGS:
			_view = View.MAIN
		else:
			resumed.emit()
		if vp_node:
			vp_node.set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _view == View.SETTINGS:
				# Check slider clicks
				var vp := get_viewport_rect().size
				for slider_id in ["master", "sfx", "music"]:
					var sr := _get_slider_rect(vp, slider_id)
					var mouse := get_local_mouse_position()
					if sr.has_point(mouse):
						_dragging_slider = slider_id
						_update_slider_value(mouse, vp, slider_id)
						if vp_node:
							vp_node.set_input_as_handled()
						return
				# Music mode toggle
				var vp2 := get_viewport_rect().size
				var toggle_rect := _get_music_mode_rect(vp2)
				var mouse2 := get_local_mouse_position()
				if toggle_rect.has_point(mouse2):
					AudioManager.set_use_music_files(not AudioManager.is_using_music_files())
					AudioManager.play_ui_select()
					if vp_node:
						vp_node.set_input_as_handled()
					return
				# Back button
				if _hover_button == 0:
					AudioManager.play_ui_select()
					_view = View.MAIN
					if vp_node:
						vp_node.set_input_as_handled()
			else:
				if _hover_button == 0:
					AudioManager.play_ui_select()
					resumed.emit()
					if vp_node:
						vp_node.set_input_as_handled()
				elif _hover_button == 1:
					AudioManager.play_ui_select()
					_view = View.SETTINGS
					if vp_node:
						vp_node.set_input_as_handled()
				elif _hover_button == 2:
					AudioManager.play_ui_select()
					quit_to_menu.emit()
					if vp_node:
						vp_node.set_input_as_handled()
		else:
			_dragging_slider = ""
	elif event is InputEventMouseMotion and _dragging_slider != "":
		var vp := get_viewport_rect().size
		_update_slider_value(get_local_mouse_position(), vp, _dragging_slider)
		if vp_node:
			vp_node.set_input_as_handled()

func _update_slider_value(pos: Vector2, vp: Vector2, slider_id: String) -> void:
	var sr := _get_slider_rect(vp, slider_id)
	var ratio: float = clampf((pos.x - sr.position.x) / sr.size.x, 0.0, 1.0)
	match slider_id:
		"master": AudioManager.set_master_volume(ratio)
		"sfx": AudioManager.set_sfx_volume(ratio)
		"music": AudioManager.set_music_volume(ratio)

func _get_slider_rect(vp: Vector2, slider_id: String) -> Rect2:
	var cx: float = vp.x * 0.5
	var slider_w: float = 300.0
	var sx: float = cx - slider_w * 0.5 + 100  # offset right for label
	var sy: float = vp.y * 0.3
	match slider_id:
		"master": sy = vp.y * 0.32
		"sfx": sy = vp.y * 0.40
		"music": sy = vp.y * 0.48
	return Rect2(sx, sy, slider_w - 100, 16)

func _get_music_mode_rect(vp: Vector2) -> Rect2:
	var cx: float = vp.x * 0.5
	return Rect2(cx - 120, vp.y * 0.58, 240, 32)

func _get_button_rect(vp: Vector2, index: int) -> Rect2:
	var cx: float = vp.x * 0.5
	var by: float = vp.y * 0.55 + index * (UIConstants.BTN_H + UIConstants.BTN_SPACING)
	return Rect2(cx - UIConstants.BTN_W * 0.5, by, UIConstants.BTN_W, UIConstants.BTN_H)

func _get_back_rect(vp: Vector2) -> Rect2:
	return Rect2((vp.x - UIConstants.BTN_W) * 0.5, vp.y * 0.88, UIConstants.BTN_W, UIConstants.BTN_H)

func _draw() -> void:
	var vp := get_viewport_rect().size

	# Dim background
	draw_rect(Rect2(0, 0, vp.x, vp.y), UIConstants.BG_DIM)

	# Blueprint grid
	UIConstants.draw_blueprint_grid(self, vp, 0.5)

	# Scan line
	UIConstants.draw_scan_line(self, vp, _scan_line_y, _time, 0.4)

	# Corner frame
	UIConstants.draw_corner_frame(self, Rect2(vp.x * 0.25, vp.y * 0.12, vp.x * 0.5, vp.y * 0.76), Color(UIConstants.FRAME_COLOR.r, UIConstants.FRAME_COLOR.g, UIConstants.FRAME_COLOR.b, 0.2))

	match _view:
		View.SETTINGS:
			_draw_settings_screen(vp)
		_:
			_draw_main_screen(vp)

func _draw_main_screen(vp: Vector2) -> void:
	var font := UIConstants.get_display_font()
	var mono := UIConstants.get_mono_font()

	# Title
	var title := "PAUSED"
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_TITLE)
	draw_string(font, Vector2((vp.x - ts.x) * 0.5, vp.y * 0.22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TITLE, UIConstants.TEXT_TITLE)

	# Decorative line
	var line_w: float = 260.0
	var line_y: float = vp.y * 0.22 + 14.0
	draw_line(Vector2(vp.x * 0.5 - line_w * 0.5, line_y), Vector2(vp.x * 0.5 + line_w * 0.5, line_y), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)
	draw_circle(Vector2(vp.x * 0.5, line_y), 2.0, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.5))

	# Mini stats summary (snake stage specific)
	var stats_y: float = vp.y * 0.3
	var cx: float = vp.x * 0.5
	UIConstants.draw_stat_row(self, Vector2(cx - 140, stats_y), "EVOLUTION:", "Lv.%d" % GameManager.evolution_level, UIConstants.ACCENT)
	UIConstants.draw_stat_row(self, Vector2(cx + 20, stats_y), "FRAGMENTS:", "%d" % GameManager.gene_fragments, UIConstants.STAT_YELLOW)
	stats_y += 18
	UIConstants.draw_stat_row(self, Vector2(cx - 140, stats_y), "MUTATIONS:", "%d" % GameManager.active_mutations.size(), UIConstants.STAT_GREEN)
	UIConstants.draw_stat_row(self, Vector2(cx + 20, stats_y), "TRAIT:", GameManager.equipped_trait if GameManager.equipped_trait != "" else "None", UIConstants.ACCENT)

	# Controls reference
	stats_y += 26
	var controls: Array = [
		"WASD - Move    SHIFT - Sprint    SPACE - Creep",
		"RMB - Bite    LMB - Pull    F - Tail Whip    C - Camouflage",
		"TAB - Creature Codex    Q (Hold) - Trait Menu",
	]
	for line in controls:
		var ls := mono.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
		draw_string(mono, Vector2((vp.x - ls.x) * 0.5, stats_y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.6))
		stats_y += 16.0

	# Buttons
	for i in range(MAIN_BUTTONS.size()):
		var rect := _get_button_rect(vp, i)
		UIConstants.draw_scifi_button(self, rect, MAIN_BUTTONS[i].label, _hover_button == i, _time)

	# Hint
	var hint := "ESC to resume"
	var hs := mono.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
	draw_string(mono, Vector2((vp.x - hs.x) * 0.5, vp.y * 0.82), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.4))

	# Alien timestamp bottom-right
	var alien_ts: String = UIConstants.random_glyphs(8, _time)
	draw_string(mono, Vector2(vp.x - 130, vp.y - 20), alien_ts, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.25))

func _draw_settings_screen(vp: Vector2) -> void:
	var font := UIConstants.get_display_font()
	var mono := UIConstants.get_mono_font()

	# Title
	var title := "SETTINGS"
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font, Vector2((vp.x - ts.x) * 0.5, vp.y * 0.18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIConstants.TEXT_TITLE)
	var line_w: float = 200.0
	draw_line(Vector2(vp.x * 0.5 - line_w * 0.5, vp.y * 0.18 + 10), Vector2(vp.x * 0.5 + line_w * 0.5, vp.y * 0.18 + 10), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)

	# Settings panel background
	var panel_rect := Rect2(vp.x * 0.25, vp.y * 0.24, vp.x * 0.5, vp.y * 0.5)
	draw_rect(panel_rect, UIConstants.BG_PANEL)
	UIConstants.draw_corner_frame(self, Rect2(panel_rect.position.x - 2, panel_rect.position.y - 2, panel_rect.size.x + 4, panel_rect.size.y + 4), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.2))

	# Volume sliders
	_draw_volume_slider(vp, font, mono, "MASTER", "master", AudioManager.get_master_volume(), vp.y * 0.28)
	_draw_volume_slider(vp, font, mono, "SFX", "sfx", AudioManager.get_sfx_volume(), vp.y * 0.36)
	_draw_volume_slider(vp, font, mono, "MUSIC", "music", AudioManager.get_music_volume(), vp.y * 0.44)

	# Music mode toggle
	var toggle_rect := _get_music_mode_rect(vp)
	var music_on: bool = AudioManager.is_using_music_files()
	var toggle_bg: Color = Color(0.06, 0.15, 0.08, 0.7) if music_on else Color(0.04, 0.06, 0.1, 0.5)
	draw_rect(toggle_rect, toggle_bg)
	var toggle_border: Color = Color(UIConstants.STAT_GREEN.r, UIConstants.STAT_GREEN.g, UIConstants.STAT_GREEN.b, 0.5) if music_on else Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.3)
	draw_rect(toggle_rect, toggle_border, false, 1.0)
	var toggle_label: String = "MUSIC FILES: ON" if music_on else "MUSIC FILES: OFF"
	var toggle_col: Color = UIConstants.STAT_GREEN if music_on else UIConstants.TEXT_DIM
	var tls := font.get_string_size(toggle_label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	draw_string(font, Vector2(toggle_rect.position.x + (toggle_rect.size.x - tls.x) * 0.5, toggle_rect.position.y + 22), toggle_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, toggle_col)

	# Description
	var desc := "Toggle between procedural audio and music file playback"
	var ds := mono.get_string_size(desc, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_TINY)
	draw_string(mono, Vector2((vp.x - ds.x) * 0.5, vp.y * 0.66), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.5))

	# Hint
	var hint := "ESC to go back"
	var hs := mono.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
	draw_string(mono, Vector2((vp.x - hs.x) * 0.5, vp.y * 0.82), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.4))

	# Back button
	var back_rect := _get_back_rect(vp)
	UIConstants.draw_scifi_button(self, back_rect, "BACK", _hover_button == 0, _time)

func _draw_volume_slider(vp: Vector2, font: Font, mono: Font, label: String, slider_id: String, value: float, y: float) -> void:
	var cx: float = vp.x * 0.5
	var label_x: float = cx - 160.0

	# Label
	draw_string(font, Vector2(label_x, y + 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, UIConstants.TEXT_NORMAL)

	# Slider track
	var sr := _get_slider_rect(vp, slider_id)
	draw_rect(sr, Color(0.08, 0.12, 0.2, 0.8))
	draw_rect(sr, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3), false, 1.0)

	# Filled portion
	var fill_w: float = sr.size.x * value
	if fill_w > 1.0:
		draw_rect(Rect2(sr.position.x, sr.position.y, fill_w, sr.size.y), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.5))
		# Bright edge
		draw_rect(Rect2(sr.position.x + fill_w - 2, sr.position.y, 2, sr.size.y), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.8))

	# Handle
	var handle_x: float = sr.position.x + fill_w
	draw_circle(Vector2(handle_x, sr.position.y + sr.size.y * 0.5), 8.0, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.9))
	draw_circle(Vector2(handle_x, sr.position.y + sr.size.y * 0.5), 4.0, UIConstants.TEXT_BRIGHT)

	# Value text
	var pct_str: String = "%d%%" % int(value * 100)
	draw_string(mono, Vector2(sr.position.x + sr.size.x + 12, y + 12), pct_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.ACCENT)

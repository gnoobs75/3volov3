extends CanvasLayer
## Post-game statistics screen shown on win or loss.
## Procedural _draw() on a Control child, organic membrane borders, slide-up animation.

var _result: String = "VICTORY"  # or "DEFEAT"
var _stats: Dictionary = {}
var _game_time: float = 0.0
var _entrance_progress: float = 0.0  # 0->1 for slide-up animation
var _visible_screen: bool = false
var _continue_hovered: bool = false
var _time: float = 0.0

var _draw_control: Control = null

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_control = Control.new()
	_draw_control.name = "StatsDrawControl"
	_draw_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_draw_control.draw.connect(_on_draw)
	_draw_control.gui_input.connect(_on_gui_input)
	add_child(_draw_control)
	_draw_control.visible = false

func show_stats(result: String, stats: Dictionary, game_time: float) -> void:
	_result = result
	_stats = stats
	_game_time = game_time
	_visible_screen = true
	_entrance_progress = 0.0
	_draw_control.visible = true
	# Pause game
	get_tree().paused = true

func _process(delta: float) -> void:
	if not _visible_screen:
		return
	_time += delta
	if _entrance_progress < 1.0:
		_entrance_progress = minf(_entrance_progress + delta * 2.0, 1.0)  # 0.5s
	# Update hover state
	var vp: Vector2 = _draw_control.get_viewport_rect().size
	var mouse: Vector2 = _draw_control.get_local_mouse_position()
	var btn_rect: Rect2 = _get_continue_rect(vp)
	_continue_hovered = btn_rect.has_point(mouse)
	_draw_control.queue_redraw()

func _get_continue_rect(vp: Vector2) -> Rect2:
	var panel_w: float = 700.0
	var panel_h: float = 450.0
	var panel_x: float = (vp.x - panel_w) * 0.5
	var panel_y_target: float = (vp.y - panel_h) * 0.5
	var panel_y: float = lerpf(vp.y, panel_y_target, _ease_out(_entrance_progress))
	var btn_w: float = 160.0
	var btn_h: float = 40.0
	var btn_x: float = panel_x + (panel_w - btn_w) * 0.5
	var btn_y: float = panel_y + panel_h - 60.0
	return Rect2(btn_x, btn_y, btn_w, btn_h)

func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func _on_gui_input(event: InputEvent) -> void:
	if not _visible_screen:
		return
	if _entrance_progress < 0.8:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp: Vector2 = _draw_control.get_viewport_rect().size
		var btn_rect: Rect2 = _get_continue_rect(vp)
		if btn_rect.has_point(event.position):
			get_tree().paused = false
			GameManager.go_to_menu()
			_draw_control.accept_event()

func _on_draw() -> void:
	if not _visible_screen:
		return

	var vp: Vector2 = _draw_control.get_viewport_rect().size
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var a: float = _ease_out(_entrance_progress)

	# Semi-transparent dark background
	_draw_control.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.02, 0.03, 0.05, 0.85 * a))

	# Panel dimensions
	var panel_w: float = 700.0
	var panel_h: float = 450.0
	var panel_x: float = (vp.x - panel_w) * 0.5
	var panel_y_target: float = (vp.y - panel_h) * 0.5
	var panel_y: float = lerpf(vp.y, panel_y_target, a)

	# Panel background
	var panel_rect: Rect2 = Rect2(panel_x, panel_y, panel_w, panel_h)
	_draw_control.draw_rect(panel_rect, Color(0.04, 0.06, 0.12, 0.95))

	# Organic membrane border
	_draw_membrane_border(panel_rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.6 * a), 2.5, 8.0)

	# Inner glow line at top
	_draw_control.draw_line(
		Vector2(panel_x + 20, panel_y + 2),
		Vector2(panel_x + panel_w - 20, panel_y + 2),
		Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.15 * a), 1.0)

	# Corner frame
	UIConstants.draw_corner_frame(_draw_control, panel_rect.grow(4),
		Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.4 * a))

	# Header: result text
	var is_victory: bool = _result == "VICTORY"
	var title_color: Color = Color(0.3, 1.0, 0.5) if is_victory else Color(1.0, 0.3, 0.3)
	var title_size: int = 34
	var title_ts: Vector2 = font.get_string_size(_result, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size)
	var title_x: float = panel_x + (panel_w - title_ts.x) * 0.5
	var title_y: float = panel_y + 55.0

	# Title glow
	_draw_control.draw_circle(Vector2(panel_x + panel_w * 0.5, title_y - 10), 60.0,
		Color(title_color.r, title_color.g, title_color.b, 0.06 * a))

	# Title shadow
	_draw_control.draw_string(font, Vector2(title_x + 2, title_y + 2), _result,
		HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0, 0, 0, 0.5 * a))
	# Title main
	_draw_control.draw_string(font, Vector2(title_x, title_y), _result,
		HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(title_color.r, title_color.g, title_color.b, a))

	# Subtitle
	var subtitle: String = "All enemies eliminated!" if is_victory else "Your colony has been destroyed."
	var sub_ts: Vector2 = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	_draw_control.draw_string(font, Vector2(panel_x + (panel_w - sub_ts.x) * 0.5, title_y + 28),
		subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY,
		Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.8 * a))

	# Separator
	var sep_y: float = title_y + 45.0
	_draw_control.draw_line(Vector2(panel_x + 40, sep_y), Vector2(panel_x + panel_w - 40, sep_y),
		Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3 * a), 1.0)

	# Game time
	var minutes: int = int(_game_time) / 60
	var seconds: int = int(_game_time) % 60
	var time_text: String = "Game Time: %02d:%02d" % [minutes, seconds]
	var time_ts: Vector2 = mono.get_string_size(time_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	_draw_control.draw_string(mono, Vector2(panel_x + (panel_w - time_ts.x) * 0.5, sep_y + 28),
		time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY,
		Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.9 * a))

	# Stats in two columns
	var stats_start_y: float = sep_y + 55.0
	var left_x: float = panel_x + 60.0
	var right_x: float = panel_x + panel_w * 0.5 + 30.0
	var line_spacing: float = 30.0
	var stat_fade: float = clampf((_entrance_progress - 0.3) / 0.5, 0.0, 1.0)

	var left_stats: Array = [
		["Units Produced:", str(_stats.get("units_produced", 0))],
		["Units Lost:", str(_stats.get("units_lost", 0))],
		["Buildings Built:", str(_stats.get("buildings_built", 0))],
		["Buildings Lost:", str(_stats.get("buildings_lost", 0))],
	]
	var right_stats: Array = [
		["Enemies Killed:", str(_stats.get("enemies_killed", 0))],
		["Resources Gathered:", str(_stats.get("resources_gathered", 0))],
		["Factions Eliminated:", str(_stats.get("factions_eliminated", 0))],
		["Total Biomass:", str(_stats.get("total_biomass", 0))],
	]

	var label_color: Color = Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.8 * stat_fade)
	var value_color: Color = Color(UIConstants.TEXT_BRIGHT.r, UIConstants.TEXT_BRIGHT.g, UIConstants.TEXT_BRIGHT.b, 0.95 * stat_fade)

	for i in range(left_stats.size()):
		var y: float = stats_start_y + i * line_spacing
		_draw_control.draw_string(mono, Vector2(left_x, y), left_stats[i][0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, label_color)
		var lw: float = mono.get_string_size(left_stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION).x
		_draw_control.draw_string(mono, Vector2(left_x + lw + 8, y), left_stats[i][1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, value_color)

	for i in range(right_stats.size()):
		var y: float = stats_start_y + i * line_spacing
		_draw_control.draw_string(mono, Vector2(right_x, y), right_stats[i][0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, label_color)
		var lw: float = mono.get_string_size(right_stats[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION).x
		_draw_control.draw_string(mono, Vector2(right_x + lw + 8, y), right_stats[i][1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, value_color)

	# Army timeline label (if data exists)
	var timeline: Array = _stats.get("army_timeline", [])
	if not timeline.is_empty() and stat_fade > 0.2:
		var tl_y: float = stats_start_y + left_stats.size() * line_spacing + 15.0
		_draw_control.draw_line(
			Vector2(panel_x + 40, tl_y),
			Vector2(panel_x + panel_w - 40, tl_y),
			Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.2 * stat_fade), 1.0)
		tl_y += 18.0
		_draw_control.draw_string(mono, Vector2(left_x, tl_y), "Army Size Over Time:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, label_color)

		# Draw mini sparkline
		var spark_x: float = left_x
		var spark_y: float = tl_y + 10.0
		var spark_w: float = panel_w - 120.0
		var spark_h: float = 35.0
		var max_val: int = 1
		for val in timeline:
			if val > max_val:
				max_val = val

		_draw_control.draw_rect(Rect2(spark_x, spark_y, spark_w, spark_h), Color(0.03, 0.05, 0.08, 0.5))
		if timeline.size() > 1:
			for i in range(timeline.size() - 1):
				var t0: float = float(i) / float(timeline.size() - 1)
				var t1: float = float(i + 1) / float(timeline.size() - 1)
				var v0: float = float(timeline[i]) / float(max_val)
				var v1: float = float(timeline[i + 1]) / float(max_val)
				var p0: Vector2 = Vector2(spark_x + t0 * spark_w, spark_y + spark_h - v0 * spark_h)
				var p1: Vector2 = Vector2(spark_x + t1 * spark_w, spark_y + spark_h - v1 * spark_h)
				var line_color: Color = Color(UIConstants.STAT_GREEN.r, UIConstants.STAT_GREEN.g, UIConstants.STAT_GREEN.b, 0.8 * stat_fade)
				_draw_control.draw_line(p0, p1, line_color, 1.5, true)

	# Match history summary (above continue button)
	if stat_fade > 0.3:
		var rts_stats: Dictionary = GameManager.get_rts_stats()
		var wins: int = rts_stats.get("total_wins", 0)
		var losses: int = rts_stats.get("total_losses", 0)
		var history_text: String = "Match History: %d W / %d L" % [wins, losses]
		var best: float = rts_stats.get("best_time", 0.0)
		if best > 0.0:
			var bm: int = int(best) / 60
			var bs: int = int(best) % 60
			history_text += "  |  Best: %02d:%02d" % [bm, bs]
		var ht_size: Vector2 = mono.get_string_size(history_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
		var ht_x: float = panel_x + (panel_w - ht_size.x) * 0.5
		var ht_y: float = panel_y + panel_h - 80.0
		_draw_control.draw_string(mono, Vector2(ht_x, ht_y), history_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION,
			Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.7 * stat_fade))

	# Continue button
	var btn_rect: Rect2 = _get_continue_rect(vp)
	var btn_bg: Color = Color(0.12, 0.26, 0.42, 0.95) if _continue_hovered else Color(0.08, 0.14, 0.26, 0.9)
	var btn_border: Color = Color(0.5, 0.88, 1.0, 0.9) if _continue_hovered else Color(0.28, 0.50, 0.68, 0.6)
	var btn_text_c: Color = UIConstants.BTN_TEXT_HOVER if _continue_hovered else UIConstants.BTN_TEXT

	if _entrance_progress >= 0.8:
		_draw_control.draw_rect(btn_rect, btn_bg)
		_draw_control.draw_rect(btn_rect, btn_border, false, 1.5)
		if _continue_hovered:
			_draw_control.draw_rect(btn_rect.grow(3), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.06))
		var continue_text: String = "Continue"
		var cts: Vector2 = font.get_string_size(continue_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
		_draw_control.draw_string(font,
			Vector2(btn_rect.position.x + (btn_rect.size.x - cts.x) * 0.5, btn_rect.position.y + btn_rect.size.y * 0.5 + 6),
			continue_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, btn_text_c)

func _draw_membrane_border(rect: Rect2, color: Color, amplitude: float = 2.0, freq: float = 8.0) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 80
	for i in range(segments + 1):
		var t: float = float(i) / segments
		var total_len: float = 2.0 * (rect.size.x + rect.size.y)
		var dist: float = t * total_len
		var perimeter_pos: Vector2
		if dist < rect.size.x:
			perimeter_pos = rect.position + Vector2(dist, 0)
			perimeter_pos.y += sin(_time * 2.0 + dist * freq * 0.01) * amplitude
		elif dist < rect.size.x + rect.size.y:
			var d: float = dist - rect.size.x
			perimeter_pos = rect.position + Vector2(rect.size.x, d)
			perimeter_pos.x += sin(_time * 2.0 + d * freq * 0.01) * amplitude
		elif dist < 2.0 * rect.size.x + rect.size.y:
			var d: float = dist - rect.size.x - rect.size.y
			perimeter_pos = rect.position + Vector2(rect.size.x - d, rect.size.y)
			perimeter_pos.y += sin(_time * 2.0 + d * freq * 0.01) * amplitude
		else:
			var d: float = dist - 2.0 * rect.size.x - rect.size.y
			perimeter_pos = rect.position + Vector2(0, rect.size.y - d)
			perimeter_pos.x += sin(_time * 2.0 + d * freq * 0.01) * amplitude
		points.append(perimeter_pos)
	for i in range(points.size() - 1):
		_draw_control.draw_line(points[i], points[i + 1], color, 1.5, true)

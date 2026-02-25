extends Control
## Game over overlay — victory, defeat, and elimination announcements.
## Enhanced with particle effects, pulsing titles, buttons, and detailed stats.

var _time: float = 0.0
var _show_victory: bool = false
var _show_defeat: bool = false
var _game_time: float = 0.0
var _elimination_text: String = ""
var _elimination_timer: float = 0.0
var _appear_t: float = 0.0
var _stats: Dictionary = {}  # Game stats for end screen

# Particle burst (victory only)
var _particles: Array = []  # [{pos: Vector2, vel: Vector2, color: Color, life: float}]
const PARTICLE_COUNT: int = 60

# Buttons
var _hover_btn: int = -1  # 0=View Stats, 1=Save Replay, 2=Return to Menu
var _show_stats_detail: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_victory(game_time: float) -> void:
	_show_victory = true
	_game_time = game_time
	_appear_t = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_collect_stats()
	_spawn_particles()
	AudioManager.play_rts_victory()

func show_defeat(game_time: float) -> void:
	_show_defeat = true
	_game_time = game_time
	_appear_t = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_collect_stats()
	AudioManager.play_rts_defeat()

func _collect_stats() -> void:
	var stage: Node = get_tree().get_first_node_in_group("rts_stage")
	if not stage:
		return
	for child in stage.get_children():
		if child.has_method("get_stats_summary"):
			_stats = child.get_stats_summary()
			break
		elif child.has_method("get_game_time") and "stats_units_produced" in child:
			_stats = {
				"units_produced": child.stats_units_produced,
				"units_lost": child.stats_units_lost,
				"enemies_killed": child.stats_enemies_killed,
				"buildings_built": child.get("stats_buildings_built", 0),
				"buildings_lost": child.get("stats_buildings_lost", 0),
				"resources_gathered": child.get("stats_resources_gathered", 0),
			}
			break

func show_elimination(faction_name: String) -> void:
	_elimination_text = "%s ELIMINATED" % faction_name.to_upper()
	_elimination_timer = 4.0

func _spawn_particles() -> void:
	_particles.clear()
	var vp: Vector2 = get_viewport_rect().size
	var center: Vector2 = Vector2(vp.x * 0.5, vp.y * 0.35)
	for i in range(PARTICLE_COUNT):
		var angle: float = randf() * TAU
		var speed: float = randf_range(80.0, 250.0)
		var green_variants: Array = [
			Color(0.3, 1.0, 0.5, 1.0),
			Color(0.5, 1.0, 0.3, 1.0),
			Color(0.2, 0.9, 0.6, 1.0),
			Color(0.8, 1.0, 0.4, 1.0),
			Color(1.0, 1.0, 0.5, 1.0),
		]
		_particles.append({
			"pos": center,
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed - 30.0),
			"color": green_variants[randi() % green_variants.size()],
			"life": randf_range(1.5, 3.0),
			"max_life": 3.0,
			"size": randf_range(2.0, 5.0),
		})

func _process(delta: float) -> void:
	_time += delta
	if _show_victory or _show_defeat:
		_appear_t = minf(_appear_t + delta * 1.5, 1.0)
	if _elimination_timer > 0:
		_elimination_timer -= delta
	# Update particles
	var i: int = _particles.size() - 1
	while i >= 0:
		_particles[i]["life"] -= delta
		if _particles[i]["life"] <= 0:
			_particles.remove_at(i)
		else:
			_particles[i]["pos"] += _particles[i]["vel"] * delta
			_particles[i]["vel"].y += 50.0 * delta  # Gravity
		i -= 1
	queue_redraw()

func _get_btn_rect(index: int) -> Rect2:
	var vp: Vector2 = get_viewport_rect().size
	var btn_w: float = 140.0
	var btn_h: float = 28.0
	var btn_gap: float = 15.0
	var total_w: float = btn_w * 3 + btn_gap * 2
	var start_x: float = (vp.x - total_w) * 0.5
	var btn_y: float = vp.y * 0.78
	return Rect2(start_x + (btn_w + btn_gap) * index, btn_y, btn_w, btn_h)

func _gui_input(event: InputEvent) -> void:
	if not (_show_victory or _show_defeat) or _appear_t < 0.8:
		return
	if event is InputEventMouseMotion:
		_hover_btn = -1
		for i in range(3):
			if _get_btn_rect(i).has_point(event.position):
				_hover_btn = i
				break
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			for i in range(3):
				if _get_btn_rect(i).has_point(event.position):
					match i:
						0:  # View Stats
							_show_stats_detail = not _show_stats_detail
						1:  # Save Replay (placeholder)
							pass
						2:  # Return to Menu
							GameManager.go_to_menu()
					return
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			GameManager.go_to_menu()

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var font: Font = UIConstants.get_display_font()

	# Elimination announcement (temporary banner)
	if _elimination_timer > 0 and not _show_victory and not _show_defeat:
		var alpha: float = clampf(_elimination_timer, 0.0, 1.0)
		var banner_y: float = vp.y * 0.15
		draw_rect(Rect2(0, banner_y - 25, vp.x, 50), Color(0.1, 0.0, 0.0, 0.7 * alpha))
		var elim_ts: Vector2 = font.get_string_size(_elimination_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_HEADER)
		draw_string(font, Vector2((vp.x - elim_ts.x) * 0.5, banner_y + 10), _elimination_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_HEADER, Color(1.0, 0.3, 0.3, alpha))

	# Victory/Defeat overlay
	if not _show_victory and not _show_defeat:
		return

	var a: float = _appear_t

	# Dark overlay — defeat is darker
	var bg_alpha: float = 0.85 * a if _show_defeat else 0.7 * a
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.0, 0.0, 0.0, bg_alpha))

	# Blueprint grid
	UIConstants.draw_blueprint_grid(self, vp, a * 0.3)

	# === Particles (victory only) ===
	for p in _particles:
		var pa: float = clampf(p["life"] / p["max_life"], 0.0, 1.0)
		var col: Color = p["color"]
		col.a = pa * a
		draw_circle(p["pos"], p["size"] * pa, col)

	# Title
	var title: String = "VICTORY" if _show_victory else "DEFEATED"
	var title_color: Color = Color(0.3, 1.0, 0.5) if _show_victory else Color(1.0, 0.3, 0.3)
	var title_size: int = 52

	if _show_victory:
		# Pulsing green glow for victory
		var pulse: float = 0.8 + 0.2 * sin(_time * 3.0)
		var glow_r: float = 120.0 + 20.0 * sin(_time * 2.0)
		draw_circle(Vector2(vp.x * 0.5, vp.y * 0.35), glow_r, Color(0.2, 0.9, 0.4, 0.06 * a * pulse))
		draw_circle(Vector2(vp.x * 0.5, vp.y * 0.35), glow_r * 0.6, Color(0.3, 1.0, 0.5, 0.04 * a * pulse))
		title_color = Color(0.3, 1.0, 0.5).lerp(Color(0.5, 1.0, 0.7), 0.3 * sin(_time * 2.5))
	else:
		# Defeat: dim red, no pulse — just fading vignette effect
		var vig_size: float = maxf(vp.x, vp.y) * 0.4
		draw_circle(Vector2(vp.x * 0.5, vp.y * 0.35), vig_size, Color(0.15, 0.0, 0.0, 0.15 * a))
		title_color = Color(0.8, 0.2, 0.2, 0.9)

	var ts: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size)
	# Shadow
	draw_string(font, Vector2((vp.x - ts.x) * 0.5 + 2, vp.y * 0.35 + 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0, 0, 0, 0.6 * a))
	# Main
	draw_string(font, Vector2((vp.x - ts.x) * 0.5, vp.y * 0.35), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(title_color.r, title_color.g, title_color.b, a))

	# Subtitle
	var subtitle: String = "All enemies eliminated!" if _show_victory else "Your colony has been destroyed."
	var sts: Vector2 = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
	draw_string(font, Vector2((vp.x - sts.x) * 0.5, vp.y * 0.45), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, Color(UIConstants.TEXT_BRIGHT.r, UIConstants.TEXT_BRIGHT.g, UIConstants.TEXT_BRIGHT.b, 0.8 * a))

	# Game time
	var minutes: int = int(_game_time) / 60
	var seconds: int = int(_game_time) % 60
	var time_text: String = "Time: %02d:%02d" % [minutes, seconds]
	var tts: Vector2 = font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	draw_string(font, Vector2((vp.x - tts.x) * 0.5, vp.y * 0.52), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.7 * a))

	# Stats summary (always shown: compact army stats)
	if not _stats.is_empty() and a > 0.3:
		var mono: Font = UIConstants.get_mono_font()
		var stat_a: float = clampf((a - 0.3) / 0.5, 0.0, 1.0)
		var stat_y: float = vp.y * 0.57
		var stat_x: float = vp.x * 0.5
		var stat_lines: Array = [
			["Units Produced", str(_stats.get("units_produced", 0))],
			["Units Lost", str(_stats.get("units_lost", 0))],
			["Enemies Killed", str(_stats.get("enemies_killed", 0))],
		]
		# Extended stats when "View Stats" toggled
		if _show_stats_detail:
			stat_lines.append(["Buildings Built", str(_stats.get("buildings_built", 0))])
			stat_lines.append(["Buildings Lost", str(_stats.get("buildings_lost", 0))])
			stat_lines.append(["Resources Gathered", str(_stats.get("resources_gathered", 0))])

		# Separator line
		draw_line(Vector2(stat_x - 100, stat_y), Vector2(stat_x + 100, stat_y), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3 * stat_a), 1.0)
		stat_y += 8
		for sl in stat_lines:
			var label: String = sl[0]
			var value: String = sl[1]
			var label_w: float = mono.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION).x
			draw_string(mono, Vector2(stat_x - label_w - 15, stat_y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.7 * stat_a))
			draw_string(mono, Vector2(stat_x + 15, stat_y + 14), value, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(UIConstants.TEXT_BRIGHT.r, UIConstants.TEXT_BRIGHT.g, UIConstants.TEXT_BRIGHT.b, 0.9 * stat_a))
			stat_y += 18

	# === BUTTONS (appear after fade-in) ===
	if a >= 0.8:
		var btn_labels: Array = ["View Stats", "Save Replay", "Return to Menu"]
		var btn_colors: Array = [
			Color(0.3, 0.6, 1.0),   # Blue
			Color(0.5, 0.5, 0.5),   # Gray (placeholder)
			Color(0.9, 0.6, 0.2),   # Orange
		]
		for i in range(3):
			var rect: Rect2 = _get_btn_rect(i)
			var hovered: bool = (_hover_btn == i)
			var bg_col: Color = Color(0.1, 0.14, 0.2, 0.8) if not hovered else Color(0.15, 0.2, 0.3, 0.9)
			draw_rect(rect, bg_col)
			var border_col: Color = btn_colors[i]
			if i == 1:
				border_col.a = 0.4  # Dimmed for placeholder
			draw_rect(rect, Color(border_col.r, border_col.g, border_col.b, 0.6 if hovered else 0.35), false, 1.0)
			var label_col: Color = btn_colors[i] if i != 1 else Color(0.5, 0.5, 0.5, 0.6)
			var lbl_ts: Vector2 = font.get_string_size(btn_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION)
			draw_string(font, Vector2(rect.position.x + (rect.size.x - lbl_ts.x) * 0.5, rect.position.y + 19), btn_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, label_col)

	# Corner frame
	UIConstants.draw_corner_frame(self, Rect2(vp.x * 0.2, vp.y * 0.2, vp.x * 0.6, vp.y * 0.65), Color(title_color.r, title_color.g, title_color.b, 0.3 * a))

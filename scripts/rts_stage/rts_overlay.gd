extends Control
## Game over overlay — victory, defeat, and elimination announcements.

var _time: float = 0.0
var _show_victory: bool = false
var _show_defeat: bool = false
var _game_time: float = 0.0
var _elimination_text: String = ""
var _elimination_timer: float = 0.0
var _appear_t: float = 0.0

func show_victory(game_time: float) -> void:
	_show_victory = true
	_game_time = game_time
	_appear_t = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_defeat(game_time: float) -> void:
	_show_defeat = true
	_game_time = game_time
	_appear_t = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_elimination(faction_name: String) -> void:
	_elimination_text = "%s ELIMINATED" % faction_name.to_upper()
	_elimination_timer = 4.0

func _process(delta: float) -> void:
	_time += delta
	if _show_victory or _show_defeat:
		_appear_t = minf(_appear_t + delta * 1.5, 1.0)
	if _elimination_timer > 0:
		_elimination_timer -= delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if (_show_victory or _show_defeat) and _appear_t >= 0.8:
		if event is InputEventMouseButton and event.pressed:
			GameManager.go_to_menu()
		elif event is InputEventKey and event.pressed:
			GameManager.go_to_menu()

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var font: Font = UIConstants.get_display_font()

	# Elimination announcement (temporary banner)
	if _elimination_timer > 0 and not _show_victory and not _show_defeat:
		var alpha: float = clampf(_elimination_timer, 0.0, 1.0)
		var banner_y: float = vp.y * 0.15
		draw_rect(Rect2(0, banner_y - 25, vp.x, 50), Color(0.1, 0.0, 0.0, 0.7 * alpha))
		var ts: Vector2 = font.get_string_size(_elimination_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_HEADER)
		draw_string(font, Vector2((vp.x - ts.x) * 0.5, banner_y + 10), _elimination_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_HEADER, Color(1.0, 0.3, 0.3, alpha))

	# Victory/Defeat overlay
	if not _show_victory and not _show_defeat:
		return

	var a: float = _appear_t

	# Dark overlay
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.0, 0.0, 0.0, 0.7 * a))

	# Blueprint grid
	UIConstants.draw_blueprint_grid(self, vp, a * 0.3)

	# Title
	var title: String = "VICTORY" if _show_victory else "DEFEAT"
	var title_color: Color = Color(0.3, 1.0, 0.5) if _show_victory else Color(1.0, 0.3, 0.3)
	var title_size: int = 52
	var ts: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size)
	# Glow
	draw_circle(Vector2(vp.x * 0.5, vp.y * 0.35), 100.0, Color(title_color.r, title_color.g, title_color.b, 0.05 * a))
	# Shadow
	draw_string(font, Vector2((vp.x - ts.x) * 0.5 + 2, vp.y * 0.35 + 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0, 0, 0, 0.5 * a))
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
	draw_string(font, Vector2((vp.x - tts.x) * 0.5, vp.y * 0.55), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.7 * a))

	# Press any key
	if a >= 0.8:
		var blink: float = 0.5 + 0.5 * sin(_time * 2.0)
		var prompt: String = "Click or press any key to return to menu"
		var pts: Vector2 = font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
		draw_string(font, Vector2((vp.x - pts.x) * 0.5, vp.y * 0.7), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, blink * a))

	# Corner frame
	UIConstants.draw_corner_frame(self, Rect2(vp.x * 0.2, vp.y * 0.2, vp.x * 0.6, vp.y * 0.6), Color(title_color.r, title_color.g, title_color.b, 0.3 * a))

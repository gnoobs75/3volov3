extends Control
## Guided tutorial: step-by-step onboarding after creature creation.
## Steps: Movement → Tractor Beam → Spray → Sprint → Vitals explanation → Collect 3 → Go!
## Each step is action-gated: player must perform the action to advance.

var _time: float = 0.0
var _alpha: float = 0.0
var _step: int = 0
var _step_time: float = 0.0  # Time spent on current step
var _step_complete: bool = false  # Current step's action detected
var _complete_flash: float = 0.0  # Flash when step completes
var _total_distance: float = 0.0  # Movement tracking for step 0
var _last_pos: Vector2 = Vector2.ZERO
var _pos_initialized: bool = false
var _beam_used: bool = false
var _spray_used: bool = false
var _sprint_used: bool = false
var _items_collected: int = 0
var _finished: bool = false
var _fade_out_timer: float = 0.0

# Step definitions: key prompt, instruction text, subtitle text
const STEPS: Array = [
	{
		"key": "WASD",
		"title": "MOVEMENT",
		"text": "Use WASD to swim around",
		"sub": "Your organism glides through the fluid with inertia",
	},
	{
		"key": "LMB",
		"title": "TRACTOR BEAM",
		"text": "Click a nearby building block to collect it",
		"sub": "Hover near a glowing particle and click to pull it in",
	},
	{
		"key": "RMB",
		"title": "JET SPRAY",
		"text": "Hold Right Click to spray",
		"sub": "Pushes enemies away and consumes collected nutrients",
	},
	{
		"key": "SHIFT",
		"title": "SPRINT",
		"text": "Hold Shift while moving to sprint",
		"sub": "Faster movement at the cost of extra energy drain",
	},
	{
		"key": "",
		"title": "VITALS",
		"text": "",
		"sub": "",
	},
	{
		"key": "",
		"title": "READY",
		"text": "Collect 3 building blocks to begin",
		"sub": "",
	},
]

# Vitals explanation has its own sub-steps for readability
const VITALS_LINES: Array = [
	{"icon": "RED ARC", "color": Color(0.9, 0.2, 0.15), "text": "HEALTH  -  Left arc. Take damage from enemies and hazards."},
	{"icon": "GREEN ARC", "color": Color(0.15, 0.75, 0.4), "text": "ENERGY  -  Right arc. Drains while moving, sprinting costs more."},
	{"icon": "", "color": Color(0.5, 0.7, 0.9), "text": "Energy regenerates when you stop moving."},
]
const VITALS_READ_TIME: float = 6.0  # Auto-advance after 6s

func _process(delta: float) -> void:
	_time += delta
	_step_time += delta

	# Fade in (skip during fade-out so alpha can reach 0)
	if not _finished:
		if _time < 0.8:
			_alpha = move_toward(_alpha, 1.0, delta * 3.0)
		else:
			_alpha = 1.0

	# Fade out after finishing
	if _finished:
		_fade_out_timer += delta
		_alpha = move_toward(_alpha, 0.0, delta * 1.5)
		if _alpha <= 0.01:
			queue_free()
			return
		queue_redraw()
		return

	# Complete flash decay
	_complete_flash = move_toward(_complete_flash, 0.0, delta * 3.0)

	# Check step completion
	if not _step_complete:
		_check_step_action(delta)

	# Auto-advance after action detected (brief pause to show checkmark)
	if _step_complete and _step_time > 0.6:
		_advance_step()

	queue_redraw()

func _check_step_action(delta: float) -> void:
	match _step:
		0:  # Movement — must move at least 80 units total
			var player := _get_player()
			if player:
				if not _pos_initialized:
					_last_pos = player.global_position
					_pos_initialized = true
				var moved: float = player.global_position.distance_to(_last_pos)
				_last_pos = player.global_position
				_total_distance += moved
				if _total_distance > 80.0:
					_mark_complete()

		1:  # Tractor beam — detect LMB or beam active
			var player := _get_player()
			if player and player.get("_beam_active"):
				_mark_complete()
			elif Input.is_action_just_pressed("beam_collect"):
				# Even if no target, count the attempt
				_beam_used = true
				# Give them a moment to actually beam something
			if _beam_used and _step_time > 3.0:
				_mark_complete()  # Advance even if no target nearby

		2:  # Spray — detect RMB
			if Input.is_action_pressed("jet_stream"):
				_spray_used = true
			if _spray_used:
				_mark_complete()

		3:  # Sprint — detect Shift while moving
			if Input.is_action_pressed("sprint"):
				var player := _get_player()
				if player and player.velocity.length() > 30.0:
					_sprint_used = true
			if _sprint_used:
				_mark_complete()

		4:  # Vitals — auto-advance after read time
			if _step_time >= VITALS_READ_TIME:
				_mark_complete()

		5:  # Collect 3 — check GameManager total collected
			_items_collected = GameManager.get_total_collected()
			if _items_collected >= 3:
				_mark_complete()

func _mark_complete() -> void:
	_step_complete = true
	_complete_flash = 1.0
	_step_time = 0.0  # Reset for the brief pause before advancing
	AudioManager.play_ui_select()

func _advance_step() -> void:
	_step += 1
	_step_time = 0.0
	_step_complete = false
	if _step >= STEPS.size():
		_finished = true
		# Signal that tutorial is done — safe zone will end naturally via GameManager
		AudioManager.play_sensory_upgrade()

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

# ======================== DRAWING ========================

func _draw() -> void:
	if _alpha <= 0.01:
		return

	var vp := get_viewport_rect().size
	var font := UIConstants.get_display_font()

	if _step >= STEPS.size():
		# Final "GO!" flash
		_draw_go_message(vp, font)
		return

	var step_data: Dictionary = STEPS[_step]

	if _step == 4:
		# Special vitals explanation layout
		_draw_vitals_step(vp, font)
	elif _step == 5:
		# Collection counter
		_draw_collect_step(vp, font)
	else:
		# Standard action prompt
		_draw_action_step(vp, font, step_data)

	# Step progress dots at bottom
	_draw_progress_dots(vp)

func _draw_action_step(vp: Vector2, font: Font, step_data: Dictionary) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.72  # Lower third of screen

	# Background pill
	var pill_w: float = 420.0
	var pill_h: float = 90.0
	var pill_x: float = cx - pill_w * 0.5
	var pill_y: float = cy - pill_h * 0.5
	var bg_alpha: float = 0.6 * _alpha
	if _complete_flash > 0:
		bg_alpha = lerpf(bg_alpha, 0.8, _complete_flash)
	draw_rect(Rect2(pill_x, pill_y, pill_w, pill_h), Color(0.08, 0.10, 0.18, bg_alpha))

	# Accent lines
	var accent := Color(0.4, 0.8, 1.0, 0.5 * _alpha)
	if _complete_flash > 0:
		accent = accent.lerp(Color(0.3, 1.0, 0.4, 0.8), _complete_flash)
	draw_rect(Rect2(pill_x, pill_y, pill_w, 1), accent)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 1, pill_w, 1), accent)

	# Key badge (left side)
	var key_text: String = step_data.key
	var key_fs: int = 22
	var key_size := font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs)
	var badge_w: float = key_size.x + 20.0
	var badge_h: float = 32.0
	var badge_x: float = pill_x + 16.0
	var badge_y: float = cy - badge_h * 0.5 - 6.0
	var badge_col := Color(0.12, 0.25, 0.45, 0.85 * _alpha)
	if _step_complete:
		badge_col = Color(0.1, 0.35, 0.15, 0.85 * _alpha)
	draw_rect(Rect2(badge_x, badge_y, badge_w, badge_h), badge_col)
	draw_rect(Rect2(badge_x, badge_y, badge_w, badge_h), Color(0.5, 0.8, 1.0, 0.4 * _alpha), false, 1.0)
	draw_string(font, Vector2(badge_x + 10, badge_y + 22), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs, Color(0.8, 0.95, 1.0, _alpha))

	# Title + instruction (right of badge)
	var text_x: float = badge_x + badge_w + 16.0
	var title_text: String = step_data.title
	if _step_complete:
		title_text += "  OK"
	draw_string(font, Vector2(text_x, cy - 4), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.95, 1.0, _alpha))

	# Instruction text below
	var inst_text: String = step_data.text
	draw_string(font, Vector2(text_x, cy + 16), inst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.7, 0.8, 0.8 * _alpha))

	# Subtitle hint below pill
	if step_data.sub != "":
		var sub_size := font.get_string_size(step_data.sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
		var sub_x: float = cx - sub_size.x * 0.5
		draw_string(font, Vector2(sub_x, pill_y + pill_h + 16), step_data.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.55, 0.65, 0.6 * _alpha))

	# Pulsing arrow pointing at key during active step
	if not _step_complete:
		var pulse: float = 0.6 + 0.4 * sin(_time * 4.0)
		var arrow_x: float = badge_x + badge_w * 0.5
		var arrow_y: float = badge_y - 6.0
		var arrow_col := Color(0.4, 0.8, 1.0, pulse * _alpha)
		# Small triangle pointing down
		draw_colored_polygon(PackedVector2Array([
			Vector2(arrow_x - 5, arrow_y - 8),
			Vector2(arrow_x + 5, arrow_y - 8),
			Vector2(arrow_x, arrow_y),
		]), arrow_col)

func _draw_vitals_step(vp: Vector2, font: Font) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.65

	# Wider pill for vitals info
	var pill_w: float = 480.0
	var pill_h: float = 120.0
	var pill_x: float = cx - pill_w * 0.5
	var pill_y: float = cy - pill_h * 0.5
	draw_rect(Rect2(pill_x, pill_y, pill_w, pill_h), Color(0.08, 0.10, 0.18, 0.65 * _alpha))

	# Accent lines
	var accent := Color(0.4, 0.8, 1.0, 0.5 * _alpha)
	draw_rect(Rect2(pill_x, pill_y, pill_w, 1), accent)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 1, pill_w, 1), accent)

	# Title
	draw_string(font, Vector2(pill_x + 16, pill_y + 24), "YOUR VITALS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.95, 1.0, _alpha))

	# Stagger each line
	for i in range(VITALS_LINES.size()):
		var line: Dictionary = VITALS_LINES[i]
		var line_alpha: float = clampf((_step_time - 0.3 - i * 0.6) / 0.5, 0.0, 1.0) * _alpha
		if line_alpha <= 0.01:
			continue
		var ly: float = pill_y + 50.0 + i * 24.0
		var lx: float = pill_x + 20.0

		# Color indicator dot
		if line.icon != "":
			draw_circle(Vector2(lx + 4, ly - 4), 5.0, Color(line.color.r, line.color.g, line.color.b, 0.8 * line_alpha))
			lx += 18.0

		draw_string(font, Vector2(lx, ly), line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(line.color.r, line.color.g, line.color.b, 0.9 * line_alpha))

	# Progress timer — subtle bar at bottom of pill
	var progress: float = clampf(_step_time / VITALS_READ_TIME, 0.0, 1.0)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 3, pill_w * progress, 3), Color(0.4, 0.8, 1.0, 0.3 * _alpha))

	# "Reading..." text
	if not _step_complete:
		var read_text: String = "..." if fmod(_time, 1.0) < 0.5 else ""
		draw_string(font, Vector2(pill_x + pill_w - 60, pill_y + pill_h + 14), read_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.6, 0.7, 0.5 * _alpha))

func _draw_collect_step(vp: Vector2, font: Font) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.72

	# Pill
	var pill_w: float = 400.0
	var pill_h: float = 80.0
	var pill_x: float = cx - pill_w * 0.5
	var pill_y: float = cy - pill_h * 0.5
	var bg_alpha: float = 0.6 * _alpha
	if _complete_flash > 0:
		bg_alpha = lerpf(bg_alpha, 0.9, _complete_flash)
	draw_rect(Rect2(pill_x, pill_y, pill_w, pill_h), Color(0.08, 0.10, 0.18, bg_alpha))

	var accent := Color(0.3, 0.8, 0.5, 0.5 * _alpha)
	draw_rect(Rect2(pill_x, pill_y, pill_w, 1), accent)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 1, pill_w, 1), accent)

	# Title
	draw_string(font, Vector2(pill_x + 16, pill_y + 28), "COLLECT BUILDING BLOCKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.95, 1.0, _alpha))

	# Counter: 3 circles showing progress
	var dot_y: float = pill_y + 55.0
	var dot_start_x: float = pill_x + 20.0
	_items_collected = GameManager.get_total_collected()
	for i in range(3):
		var dx: float = dot_start_x + i * 36.0
		var filled: bool = i < _items_collected
		if filled:
			draw_circle(Vector2(dx + 12, dot_y), 10.0, Color(0.3, 0.9, 0.5, 0.8 * _alpha))
			# Checkmark
			draw_line(Vector2(dx + 7, dot_y), Vector2(dx + 11, dot_y + 4), Color(1, 1, 1, _alpha), 2.0, true)
			draw_line(Vector2(dx + 11, dot_y + 4), Vector2(dx + 17, dot_y - 4), Color(1, 1, 1, _alpha), 2.0, true)
		else:
			draw_arc(Vector2(dx + 12, dot_y), 10.0, 0, TAU, 16, Color(0.3, 0.5, 0.4, 0.4 * _alpha), 1.5, true)

	# Instruction
	var hint: String = "Click glowing particles with LMB to collect"
	draw_string(font, Vector2(dot_start_x + 120, dot_y + 5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.7, 0.6, 0.7 * _alpha))

func _draw_go_message(vp: Vector2, font: Font) -> void:
	# "GO!" message that fades out
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.45
	var go_text: String = "SAFE ZONE ACTIVE - EXPLORE!"
	var go_fs: int = 28
	var go_size := font.get_string_size(go_text, HORIZONTAL_ALIGNMENT_CENTER, -1, go_fs)
	var gx: float = cx - go_size.x * 0.5

	# Background pill
	var pw: float = go_size.x + 40.0
	var ph: float = 50.0
	draw_rect(Rect2(gx - 20, cy - 30, pw, ph), Color(0.02, 0.06, 0.03, 0.6 * _alpha))
	var accent := Color(0.3, 1.0, 0.5, 0.5 * _alpha)
	draw_rect(Rect2(gx - 20, cy - 30, pw, 1), accent)
	draw_rect(Rect2(gx - 20, cy + 19, pw, 1), accent)

	draw_string(font, Vector2(gx, cy), go_text, HORIZONTAL_ALIGNMENT_LEFT, -1, go_fs, Color(0.4, 1.0, 0.6, _alpha))

	var sub: String = "Enemies will appear after you collect enough resources"
	var sub_size := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_string(font, Vector2(cx - sub_size.x * 0.5, cy + 30), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.7, 0.5, 0.6 * _alpha))

func _draw_progress_dots(vp: Vector2) -> void:
	var cx: float = vp.x * 0.5
	var dy: float = vp.y * 0.82
	var total: int = STEPS.size()
	var dot_spacing: float = 14.0
	var start_x: float = cx - (total - 1) * dot_spacing * 0.5

	for i in range(total):
		var dx: float = start_x + i * dot_spacing
		if i < _step:
			# Completed — filled
			draw_circle(Vector2(dx, dy), 3.5, Color(0.3, 0.9, 0.5, 0.7 * _alpha))
		elif i == _step:
			# Current — pulsing
			var pulse: float = 0.6 + 0.4 * sin(_time * 3.0)
			draw_circle(Vector2(dx, dy), 4.0, Color(0.4, 0.8, 1.0, pulse * _alpha))
		else:
			# Future — dim outline
			draw_arc(Vector2(dx, dy), 3.0, 0, TAU, 12, Color(0.3, 0.4, 0.5, 0.3 * _alpha), 1.0, true)

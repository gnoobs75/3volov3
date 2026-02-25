extends Control
## Snake/Parasite stage tutorial: 12-step action-gated onboarding.
## Steps: Movement → Look → Tractor Beam → Vitals → Bite → Tail Whip →
##        Sprint → Creep → Flashlight → Camouflage → Codex → The Hunt Begins
## Each step requires player action (or timed auto-advance) to proceed.
## Safe zone: enemies suppressed until tutorial completes.

signal tutorial_completed

var _time: float = 0.0
var _alpha: float = 0.0
var _step: int = 0
var _step_time: float = 0.0
var _step_complete: bool = false
var _complete_flash: float = 0.0
var _finished: bool = false
var _fade_out_timer: float = 0.0

# Tracking vars for action detection
var _total_distance: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _pos_initialized: bool = false
var _initial_heading: float = 0.0
var _heading_initialized: bool = false
var _total_yaw_change: float = 0.0
var _sprint_distance: float = 0.0
var _sprint_last_pos: Vector3 = Vector3.ZERO
var _creep_time: float = 0.0
var _camo_time: float = 0.0

# External notification flags (set by stage manager)
var _bite_notified: bool = false
var _tail_whip_notified: bool = false
var _tractor_notified: bool = false
var _codex_opened: bool = false

# Bioluminescent teal accent (cave aesthetic)
const ACCENT_COLOR := Color(0.2, 0.9, 0.8)
const ACCENT_DIM := Color(0.15, 0.6, 0.55)
const BG_COLOR := Color(0.04, 0.08, 0.12)
const AUTO_ADVANCE_FALLBACK: float = 15.0  # Seconds before auto-advancing any step

const STEPS: Array = [
	{
		"key": "WASD",
		"title": "MOVEMENT",
		"text": "Use WASD to slither forward and turn",
		"sub": "You are a parasite — a worm burrowing through living tissue",
	},
	{
		"key": "MOUSE",
		"title": "LOOK AROUND",
		"text": "Move your mouse to aim your head",
		"sub": "Your head tracks the cursor — look where you want to bite",
	},
	{
		"key": "LMB",
		"title": "TRACTOR BEAM",
		"text": "Hold Left Click near a glowing nutrient to pull it in",
		"sub": "Nutrients restore energy and fuel your evolution",
	},
	{
		"key": "",
		"title": "YOUR VITALS",
		"text": "",
		"sub": "",
	},
	{
		"key": "LMB",
		"title": "BITE",
		"text": "Get close to the prey creature and click to bite",
		"sub": "Your jaws lunge forward automatically at close range",
	},
	{
		"key": "F",
		"title": "TAIL WHIP",
		"text": "Press F to sweep your tail in a wide arc",
		"sub": "Hits all nearby enemies — 8 second cooldown",
	},
	{
		"key": "SHIFT",
		"title": "SPRINT",
		"text": "Hold Shift while moving to sprint",
		"sub": "Faster but drains energy — use it to chase or escape",
	},
	{
		"key": "SPACE",
		"title": "CREEP",
		"text": "Hold Space to move silently",
		"sub": "Enemies can't hear you — sneak up for surprise attacks",
	},
	{
		"key": "MMB",
		"title": "FLASHLIGHT",
		"text": "Press Middle Mouse to toggle your light beam",
		"sub": "Illuminates the cave but attracts attention — drains energy",
	},
	{
		"key": "C",
		"title": "CAMOUFLAGE",
		"text": "Hold C to turn nearly invisible",
		"sub": "Drains energy slowly — enemies lose sight of you",
	},
	{
		"key": "TAB",
		"title": "CREATURE CODEX",
		"text": "Press TAB to open your creature encyclopedia",
		"sub": "Get close to creatures to scan and learn about them",
	},
	{
		"key": "",
		"title": "THE HUNT BEGINS",
		"text": "",
		"sub": "",
	},
]

const VITALS_LINES: Array = [
	{"icon": "RED", "color": Color(0.9, 0.2, 0.15), "text": "HEALTH  —  Left arc. Damage from enemies and hazards."},
	{"icon": "BLUE", "color": Color(0.3, 0.6, 1.0), "text": "ENERGY  —  Right arc. Powers sprint, abilities, and flashlight."},
	{"icon": "", "color": Color(0.2, 0.9, 0.8), "text": "Energy regenerates passively. Health regenerates slowly."},
]
const VITALS_READ_TIME: float = 7.0

# Final step: biome/boss overview lines (staggered reveal)
const HUNT_LINES: Array = [
	{"icon": "", "color": Color(0.9, 0.4, 0.3), "text": "Six organ biomes surround you — each guarded by a boss."},
	{"icon": "", "color": Color(0.9, 0.75, 0.3), "text": "Defeat the guardians to unlock new abilities and evolve."},
	{"icon": "", "color": Color(0.2, 0.9, 0.8), "text": "Explore the caves. Hunt prey. Grow stronger."},
]
const HUNT_READ_TIME: float = 8.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_time += delta
	_step_time += delta

	if not _finished:
		if _time < 0.8:
			_alpha = move_toward(_alpha, 1.0, delta * 3.0)
		else:
			_alpha = 1.0

	if _finished:
		_fade_out_timer += delta
		_alpha = move_toward(_alpha, 0.0, delta * 1.5)
		if _alpha <= 0.01:
			queue_free()
			return
		queue_redraw()
		return

	_complete_flash = move_toward(_complete_flash, 0.0, delta * 3.0)

	if not _step_complete:
		_check_step_action(delta)
		# Fallback auto-advance
		if not _step_complete and _step_time > AUTO_ADVANCE_FALLBACK:
			_mark_complete()

	if _step_complete and _step_time > 0.6:
		_advance_step()

	queue_redraw()

func _check_step_action(delta: float) -> void:
	match _step:
		0:  # Movement — must move 80+ units
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

		1:  # Look around — must rotate head 90+ degrees total
			var player := _get_player()
			if player and "_head_yaw_offset" in player:
				if not _heading_initialized:
					_initial_heading = player._head_yaw_offset
					_heading_initialized = true
				var yaw_delta: float = absf(player._head_yaw_offset - _initial_heading)
				if yaw_delta > PI:
					yaw_delta = TAU - yaw_delta
				_total_yaw_change = maxf(_total_yaw_change, yaw_delta)
				if _total_yaw_change > PI * 0.5:  # 90 degrees
					_mark_complete()

		2:  # Tractor beam — hold LMB or notify from manager
			if _tractor_notified:
				_mark_complete()
			var player := _get_player()
			if player and "_tractor_active" in player and player._tractor_active:
				_mark_complete()

		3:  # Vitals — auto-advance after read time
			if _step_time >= VITALS_READ_TIME:
				_mark_complete()

		4:  # Bite — detect bite performed
			if _bite_notified:
				_mark_complete()
			var player := _get_player()
			if player and "_jaw_state" in player and player._jaw_state == 2:
				_mark_complete()

		5:  # Tail whip — detect F press or whip active
			if _tail_whip_notified:
				_mark_complete()
			var player := _get_player()
			if player and "_tail_whip_active" in player and player._tail_whip_active:
				_mark_complete()

		6:  # Sprint — must sprint 40+ units
			var player := _get_player()
			if player:
				if "_is_sprinting" in player and player._is_sprinting:
					if _sprint_last_pos == Vector3.ZERO:
						_sprint_last_pos = player.global_position
					var moved: float = player.global_position.distance_to(_sprint_last_pos)
					_sprint_last_pos = player.global_position
					_sprint_distance += moved
				else:
					_sprint_last_pos = player.global_position
				if _sprint_distance > 40.0:
					_mark_complete()

		7:  # Creep — hold SPACE for 2+ seconds
			var player := _get_player()
			if player and "_is_creeping" in player and player._is_creeping:
				_creep_time += delta
				if _creep_time >= 2.0:
					_mark_complete()
			else:
				_creep_time = maxf(_creep_time - delta * 0.5, 0.0)

		8:  # Flashlight — toggle on
			var player := _get_player()
			if player and "_flashlight_on" in player and player._flashlight_on:
				_mark_complete()

		9:  # Camouflage — hold C for 1.5s
			var player := _get_player()
			if player and "_is_camouflaged" in player and player._is_camouflaged:
				_camo_time += delta
				if _camo_time >= 1.5:
					_mark_complete()
			else:
				_camo_time = maxf(_camo_time - delta * 0.5, 0.0)

		10:  # Codex — open it
			if _codex_opened:
				_mark_complete()

		11:  # The Hunt Begins — auto-advance
			if _step_time >= HUNT_READ_TIME:
				_mark_complete()

func _mark_complete() -> void:
	_step_complete = true
	_complete_flash = 1.0
	_step_time = 0.0
	AudioManager.play_ui_select()

func _advance_step() -> void:
	_step += 1
	_step_time = 0.0
	_step_complete = false
	# Reset per-step trackers
	_sprint_distance = 0.0
	_sprint_last_pos = Vector3.ZERO
	_creep_time = 0.0
	_camo_time = 0.0
	if _step >= STEPS.size():
		_finished = true
		AudioManager.play_sensory_upgrade()
		tutorial_completed.emit()

# --- Notification hooks (called by snake_stage_manager) ---

func notify_bite() -> void:
	_bite_notified = true

func notify_tail_whip() -> void:
	_tail_whip_notified = true

func notify_tractor_beam() -> void:
	_tractor_notified = true

func notify_codex_opened() -> void:
	_codex_opened = true

# --- Helpers ---

func _get_player() -> Node3D:
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
		_draw_go_message(vp, font)
		return

	if _step == 3:
		_draw_vitals_step(vp, font)
	elif _step == 11:
		_draw_hunt_step(vp, font)
	else:
		_draw_action_step(vp, font, STEPS[_step])

	_draw_progress_dots(vp)

func _draw_action_step(vp: Vector2, font: Font, step_data: Dictionary) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.72

	# Background pill
	var pill_w: float = 460.0
	var pill_h: float = 94.0
	var pill_x: float = cx - pill_w * 0.5
	var pill_y: float = cy - pill_h * 0.5
	var bg_alpha: float = 0.65 * _alpha
	if _complete_flash > 0:
		bg_alpha = lerpf(bg_alpha, 0.85, _complete_flash)
	draw_rect(Rect2(pill_x, pill_y, pill_w, pill_h), Color(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, bg_alpha))

	# Accent lines (teal, flashes green on complete)
	var accent := Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.5 * _alpha)
	if _complete_flash > 0:
		accent = accent.lerp(Color(0.3, 1.0, 0.4, 0.8), _complete_flash)
	draw_rect(Rect2(pill_x, pill_y, pill_w, 1), accent)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 1, pill_w, 1), accent)

	# Subtle bioluminescent glow behind pill
	var glow_col := Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.04 * _alpha)
	draw_rect(Rect2(pill_x - 4, pill_y - 4, pill_w + 8, pill_h + 8), glow_col)

	# Key badge (left side)
	var key_text: String = step_data.key
	if key_text != "":
		var key_fs: int = 22
		var key_size := font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs)
		var badge_w: float = key_size.x + 20.0
		var badge_h: float = 32.0
		var badge_x: float = pill_x + 16.0
		var badge_y: float = cy - badge_h * 0.5 - 6.0
		var badge_col := Color(0.08, 0.2, 0.22, 0.85 * _alpha)
		if _step_complete:
			badge_col = Color(0.08, 0.3, 0.15, 0.85 * _alpha)
		draw_rect(Rect2(badge_x, badge_y, badge_w, badge_h), badge_col)
		draw_rect(Rect2(badge_x, badge_y, badge_w, badge_h), Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.4 * _alpha), false, 1.0)
		draw_string(font, Vector2(badge_x + 10, badge_y + 22), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs, Color(0.8, 1.0, 0.95, _alpha))

		# Title + instruction (right of badge)
		var text_x: float = badge_x + badge_w + 16.0
		var title_text: String = step_data.title
		if _step_complete:
			title_text += "  OK"
		draw_string(font, Vector2(text_x, cy - 4), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 1.0, 0.98, _alpha))
		draw_string(font, Vector2(text_x, cy + 16), step_data.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.8, 0.75, 0.8 * _alpha))

		# Pulsing arrow
		if not _step_complete:
			var pulse: float = 0.6 + 0.4 * sin(_time * 4.0)
			var arrow_x: float = badge_x + badge_w * 0.5
			var arrow_y: float = badge_y - 6.0
			var arrow_col := Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, pulse * _alpha)
			draw_colored_polygon(PackedVector2Array([
				Vector2(arrow_x - 5, arrow_y - 8),
				Vector2(arrow_x + 5, arrow_y - 8),
				Vector2(arrow_x, arrow_y),
			]), arrow_col)
	else:
		# No key badge — center-aligned title
		var title_text: String = step_data.title
		if _step_complete:
			title_text += "  OK"
		draw_string(font, Vector2(pill_x + 20, cy - 4), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 1.0, 0.98, _alpha))
		draw_string(font, Vector2(pill_x + 20, cy + 16), step_data.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.8, 0.75, 0.8 * _alpha))

	# Subtitle hint below pill
	if step_data.sub != "":
		var sub_size := font.get_string_size(step_data.sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
		var sub_x: float = cx - sub_size.x * 0.5
		draw_string(font, Vector2(sub_x, pill_y + pill_h + 16), step_data.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.6 * _alpha))

func _draw_vitals_step(vp: Vector2, font: Font) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.65

	var pill_w: float = 500.0
	var pill_h: float = 120.0
	var pill_x: float = cx - pill_w * 0.5
	var pill_y: float = cy - pill_h * 0.5
	draw_rect(Rect2(pill_x, pill_y, pill_w, pill_h), Color(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, 0.7 * _alpha))

	var accent := Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.5 * _alpha)
	draw_rect(Rect2(pill_x, pill_y, pill_w, 1), accent)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 1, pill_w, 1), accent)

	# Title
	draw_string(font, Vector2(pill_x + 16, pill_y + 24), "YOUR VITALS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 1.0, 0.98, _alpha))

	# Stagger each line
	for i in range(VITALS_LINES.size()):
		var line: Dictionary = VITALS_LINES[i]
		var line_alpha: float = clampf((_step_time - 0.3 - i * 0.7) / 0.5, 0.0, 1.0) * _alpha
		if line_alpha <= 0.01:
			continue
		var ly: float = pill_y + 50.0 + i * 24.0
		var lx: float = pill_x + 20.0

		if line.icon != "":
			draw_circle(Vector2(lx + 4, ly - 4), 5.0, Color(line.color.r, line.color.g, line.color.b, 0.8 * line_alpha))
			lx += 18.0

		draw_string(font, Vector2(lx, ly), line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(line.color.r, line.color.g, line.color.b, 0.9 * line_alpha))

	# Progress bar
	var progress: float = clampf(_step_time / VITALS_READ_TIME, 0.0, 1.0)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 3, pill_w * progress, 3), Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.3 * _alpha))

func _draw_hunt_step(vp: Vector2, font: Font) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.65

	var pill_w: float = 520.0
	var pill_h: float = 130.0
	var pill_x: float = cx - pill_w * 0.5
	var pill_y: float = cy - pill_h * 0.5
	draw_rect(Rect2(pill_x, pill_y, pill_w, pill_h), Color(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, 0.7 * _alpha))

	var accent := Color(0.9, 0.4, 0.3, 0.5 * _alpha)
	draw_rect(Rect2(pill_x, pill_y, pill_w, 1), accent)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 1, pill_w, 1), accent)

	# Title
	draw_string(font, Vector2(pill_x + 16, pill_y + 26), "THE HUNT BEGINS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.5, 0.3, _alpha))

	# Staggered objective lines
	for i in range(HUNT_LINES.size()):
		var line: Dictionary = HUNT_LINES[i]
		var line_alpha: float = clampf((_step_time - 0.5 - i * 1.0) / 0.6, 0.0, 1.0) * _alpha
		if line_alpha <= 0.01:
			continue
		var ly: float = pill_y + 56.0 + i * 24.0
		draw_string(font, Vector2(pill_x + 24, ly), line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(line.color.r, line.color.g, line.color.b, 0.9 * line_alpha))

	# Progress bar
	var progress: float = clampf(_step_time / HUNT_READ_TIME, 0.0, 1.0)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 3, pill_w * progress, 3), Color(0.9, 0.4, 0.3, 0.3 * _alpha))

func _draw_go_message(vp: Vector2, font: Font) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.45
	var go_text: String = "YOU ARE THE PARASITE — EXPLORE, HUNT, EVOLVE"
	var go_fs: int = 26
	var go_size := font.get_string_size(go_text, HORIZONTAL_ALIGNMENT_CENTER, -1, go_fs)
	var gx: float = cx - go_size.x * 0.5

	var pw: float = go_size.x + 40.0
	var ph: float = 55.0
	draw_rect(Rect2(gx - 20, cy - 32, pw, ph), Color(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, 0.65 * _alpha))
	var accent := Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.5 * _alpha)
	draw_rect(Rect2(gx - 20, cy - 32, pw, 1), accent)
	draw_rect(Rect2(gx - 20, cy + 22, pw, 1), accent)

	draw_string(font, Vector2(gx, cy), go_text, HORIZONTAL_ALIGNMENT_LEFT, -1, go_fs, Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, _alpha))

	var sub: String = "Defeat the guardians of each organ to complete your evolution"
	var sub_size := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_string(font, Vector2(cx - sub_size.x * 0.5, cy + 32), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.6 * _alpha))

func _draw_progress_dots(vp: Vector2) -> void:
	var cx: float = vp.x * 0.5
	var dy: float = vp.y * 0.82
	var total: int = STEPS.size()
	var dot_spacing: float = 14.0
	var start_x: float = cx - (total - 1) * dot_spacing * 0.5

	for i in range(total):
		var dx: float = start_x + i * dot_spacing
		if i < _step:
			draw_circle(Vector2(dx, dy), 3.5, Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.7 * _alpha))
		elif i == _step:
			var pulse: float = 0.6 + 0.4 * sin(_time * 3.0)
			draw_circle(Vector2(dx, dy), 4.0, Color(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, pulse * _alpha))
		else:
			draw_arc(Vector2(dx, dy), 3.0, 0, TAU, 12, Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.3 * _alpha), 1.0, true)

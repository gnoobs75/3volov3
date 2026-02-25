extends Control
## Post-tutorial contextual tips for the snake/parasite stage.
## Shows brief hint pills at screen bottom that auto-dismiss after a few seconds.
## Each tip only shows once per session.

var _time: float = 0.0
var _active_tip: int = -1
var _tip_alpha: float = 0.0
var _tip_timer: float = 0.0
var _shown_tips: Dictionary = {}
var _stage: Node = null
var _check_timer: float = 0.0
var _tutorial_done: bool = false

const TIP_DURATION: float = 7.0
const CHECK_INTERVAL: float = 2.0

const ACCENT_COLOR := Color(0.2, 0.9, 0.8)

enum TipID { SONAR, VENOM, DANGER_ARROW, BOSS_HINT }

const TIPS: Array = [
	{
		"id": TipID.SONAR,
		"key": "",
		"title": "ECHOLOCATION",
		"text": "Sonar maps the terrain around you automatically — the cave reveals itself as you move",
	},
	{
		"id": TipID.VENOM,
		"key": "LMB",
		"title": "VENOM BITE",
		"text": "Your bites apply venom — enemies take damage over time after being bitten",
	},
	{
		"id": TipID.DANGER_ARROW,
		"key": "",
		"title": "THREAT DETECTED",
		"text": "The red arrow at the screen edge points toward nearby threats",
	},
	{
		"id": TipID.BOSS_HINT,
		"key": "",
		"title": "GUARDIAN NEARBY",
		"text": "A powerful creature guards this organ — defeat all guardians to evolve",
	},
]

func setup(stage: Node) -> void:
	_stage = stage
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func on_tutorial_complete() -> void:
	_tutorial_done = true

# --- External notification hooks ---

func notify_first_bite() -> void:
	if _tutorial_done and not _shown_tips.has(TipID.VENOM):
		_show_tip(TipID.VENOM)

func notify_threat_indicator() -> void:
	if _tutorial_done and not _shown_tips.has(TipID.DANGER_ARROW):
		_show_tip(TipID.DANGER_ARROW)

func notify_entered_wing_hub() -> void:
	if _tutorial_done and not _shown_tips.has(TipID.BOSS_HINT):
		_show_tip(TipID.BOSS_HINT)

func _process(delta: float) -> void:
	_time += delta

	# Active tip display
	if _active_tip >= 0:
		_tip_timer += delta
		if _tip_timer < 0.4:
			_tip_alpha = move_toward(_tip_alpha, 1.0, delta * 4.0)
		elif _tip_timer > TIP_DURATION - 0.8:
			_tip_alpha = move_toward(_tip_alpha, 0.0, delta * 2.0)
			if _tip_alpha <= 0.01:
				_active_tip = -1
				_tip_alpha = 0.0
		queue_redraw()
		return

	if not _tutorial_done:
		return

	# Periodic situation checks
	_check_timer += delta
	if _check_timer < CHECK_INTERVAL:
		return
	_check_timer = 0.0

	_check_situations()

func _check_situations() -> void:
	# Tip 0: Sonar — player has been in the cave for 30+ seconds without seeing this tip
	# Triggers when sensory level is low (dark cave, sonar is their primary sense)
	if not _shown_tips.has(TipID.SONAR):
		if _time > 30.0:
			var player := _get_player()
			if player:
				_show_tip(TipID.SONAR)
				return

	# Venom and Danger Arrow are triggered externally via notify methods
	# Boss Hint is triggered externally when entering wing hub

func _show_tip(tip_id: int) -> void:
	if _active_tip >= 0:
		return  # Don't interrupt an active tip
	_shown_tips[tip_id] = true
	_active_tip = tip_id
	_tip_timer = 0.0
	_tip_alpha = 0.0

func _get_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

# ======================== DRAWING ========================

func _draw() -> void:
	if _active_tip < 0 or _tip_alpha <= 0.01:
		return

	var tip_data: Dictionary = TIPS[_active_tip]
	var vp := get_viewport_rect().size
	var font := UIConstants.get_display_font()

	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.88

	# Background pill
	var pill_w: float = 480.0
	var pill_h: float = 50.0
	var pill_x: float = cx - pill_w * 0.5
	var pill_y: float = cy - pill_h * 0.5
	draw_rect(Rect2(pill_x, pill_y, pill_w, pill_h), Color(0.04, 0.08, 0.12, 0.6 * _tip_alpha))

	# Accent lines — amber/gold for tips
	var accent := Color(0.9, 0.7, 0.3, 0.4 * _tip_alpha)
	draw_rect(Rect2(pill_x, pill_y, pill_w, 1), accent)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 1, pill_w, 1), accent)

	# "TIP" label
	draw_string(font, Vector2(pill_x + 10, cy - 2), "TIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.7, 0.3, 0.6 * _tip_alpha))

	# Key badge (if key exists)
	var text_start_x: float = pill_x + 42.0
	var key_text: String = tip_data.key
	if key_text != "":
		var key_fs: int = 18
		var key_size := font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs)
		var badge_w: float = key_size.x + 16.0
		var badge_h: float = 26.0
		var badge_x: float = pill_x + 42.0
		var badge_y: float = cy - badge_h * 0.5
		draw_rect(Rect2(badge_x, badge_y, badge_w, badge_h), Color(0.1, 0.15, 0.25, 0.75 * _tip_alpha))
		draw_rect(Rect2(badge_x, badge_y, badge_w, badge_h), Color(0.9, 0.7, 0.3, 0.3 * _tip_alpha), false, 1.0)
		draw_string(font, Vector2(badge_x + 8, badge_y + 18), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs, Color(0.9, 0.85, 0.7, _tip_alpha))
		text_start_x = badge_x + badge_w + 12.0

	# Tip text
	draw_string(font, Vector2(text_start_x, cy + 5), tip_data.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.85, 0.8, 0.85 * _tip_alpha))

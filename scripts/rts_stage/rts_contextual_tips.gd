extends Control
## Post-tutorial contextual tips that appear when relevant situations arise.
## Shows brief hint pills at screen bottom that auto-dismiss after a few seconds.
## Each tip only shows once per session.

var _time: float = 0.0
var _active_tip: int = -1
var _tip_alpha: float = 0.0
var _tip_timer: float = 0.0
var _shown_tips: Dictionary = {}  # tip_id -> true
var _stage: Node = null
var _check_timer: float = 0.0

const TIP_DURATION: float = 6.0
const CHECK_INTERVAL: float = 2.0

enum TipID { IDLE_WORKERS, CONTROL_GROUPS, HOME_KEY, SHIFT_SELECT }

const TIPS: Array = [
	{
		"id": TipID.IDLE_WORKERS,
		"key": ".",
		"title": "IDLE WORKERS",
		"text": "Press Period (.) to find and select idle workers",
	},
	{
		"id": TipID.CONTROL_GROUPS,
		"key": "Ctrl+1",
		"title": "CONTROL GROUPS",
		"text": "Ctrl+1-5 to assign groups, 1-5 to recall them",
	},
	{
		"id": TipID.HOME_KEY,
		"key": "HOME",
		"title": "BASE CAMERA",
		"text": "Press HOME to snap the camera to your base",
	},
	{
		"id": TipID.SHIFT_SELECT,
		"key": "Shift",
		"title": "ADD TO SELECTION",
		"text": "Hold Shift and click to add units to your selection",
	},
]

func setup(stage: Node) -> void:
	_stage = stage
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	# Periodic situation checks
	_check_timer += delta
	if _check_timer < CHECK_INTERVAL:
		return
	_check_timer = 0.0

	_check_situations()

func _check_situations() -> void:
	# Tip 0: Idle workers — trigger when 2+ workers are idle
	if not _shown_tips.has(TipID.IDLE_WORKERS):
		var idle_count: int = 0
		for unit in get_tree().get_nodes_in_group("rts_units"):
			if is_instance_valid(unit) and "faction_id" in unit and unit.faction_id == 0:
				if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
					if "state" in unit and unit.state == 0:  # IDLE
						idle_count += 1
		if idle_count >= 2:
			_show_tip(TipID.IDLE_WORKERS)
			return

	# Tip 1: Control groups — trigger when player has 6+ selected units
	if not _shown_tips.has(TipID.CONTROL_GROUPS):
		if _stage and "_selection_manager" in _stage:
			var sel: Node = _stage._selection_manager
			if "selected_units" in sel and sel.selected_units.size() >= 6:
				_show_tip(TipID.CONTROL_GROUPS)
				return

	# Tip 2: HOME key — trigger when camera is far from base (>2000 units)
	if not _shown_tips.has(TipID.HOME_KEY):
		var camera: Camera2D = get_viewport().get_camera_2d()
		if camera:
			var base_pos: Vector2 = _get_player_base_pos()
			if base_pos != Vector2.ZERO and camera.global_position.distance_to(base_pos) > 2000.0:
				_show_tip(TipID.HOME_KEY)
				return

	# Tip 3: Shift select — trigger first time player deselects to select a different unit
	if not _shown_tips.has(TipID.SHIFT_SELECT):
		if _stage and "_selection_manager" in _stage:
			var sel: Node = _stage._selection_manager
			if "selected_units" in sel and sel.selected_units.size() == 1:
				# They've selected exactly one unit — they might want to add more
				var nearby_count: int = 0
				var selected_unit: Node2D = sel.selected_units[0]
				if is_instance_valid(selected_unit):
					for unit in get_tree().get_nodes_in_group("rts_units"):
						if unit != selected_unit and is_instance_valid(unit) and "faction_id" in unit and unit.faction_id == 0:
							if selected_unit.global_position.distance_to(unit.global_position) < 200.0:
								nearby_count += 1
					if nearby_count >= 3:
						_show_tip(TipID.SHIFT_SELECT)
						return

func _show_tip(tip_id: int) -> void:
	_shown_tips[tip_id] = true
	_active_tip = tip_id
	_tip_timer = 0.0
	_tip_alpha = 0.0

func _get_player_base_pos() -> Vector2:
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if is_instance_valid(building) and "faction_id" in building and building.faction_id == 0:
			if "is_main_base" in building and building.is_main_base:
				return building.global_position
	return Vector2.ZERO

# ======================== DRAWING ========================

func _draw() -> void:
	if _active_tip < 0 or _tip_alpha <= 0.01:
		return

	var tip_data: Dictionary = TIPS[_active_tip]
	var vp := get_viewport_rect().size
	var font := UIConstants.get_display_font()

	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.88  # Very bottom of screen

	# Background pill
	var pill_w: float = 420.0
	var pill_h: float = 50.0
	var pill_x: float = cx - pill_w * 0.5
	var pill_y: float = cy - pill_h * 0.5
	draw_rect(Rect2(pill_x, pill_y, pill_w, pill_h), Color(0.06, 0.08, 0.14, 0.55 * _tip_alpha))

	# Accent lines — gold/amber for tips vs blue for tutorial
	var accent := Color(0.9, 0.7, 0.3, 0.4 * _tip_alpha)
	draw_rect(Rect2(pill_x, pill_y, pill_w, 1), accent)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 1, pill_w, 1), accent)

	# "TIP" label
	draw_string(font, Vector2(pill_x + 10, cy - 2), "TIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.7, 0.3, 0.6 * _tip_alpha))

	# Key badge
	var key_text: String = tip_data.key
	var key_fs: int = 18
	var key_size := font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs)
	var badge_w: float = key_size.x + 16.0
	var badge_h: float = 26.0
	var badge_x: float = pill_x + 42.0
	var badge_y: float = cy - badge_h * 0.5
	draw_rect(Rect2(badge_x, badge_y, badge_w, badge_h), Color(0.15, 0.20, 0.35, 0.75 * _tip_alpha))
	draw_rect(Rect2(badge_x, badge_y, badge_w, badge_h), Color(0.9, 0.7, 0.3, 0.3 * _tip_alpha), false, 1.0)
	draw_string(font, Vector2(badge_x + 8, badge_y + 18), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs, Color(0.9, 0.85, 0.7, _tip_alpha))

	# Tip text
	var text_x: float = badge_x + badge_w + 12.0
	draw_string(font, Vector2(text_x, cy + 5), tip_data.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.8, 0.85, 0.85 * _tip_alpha))

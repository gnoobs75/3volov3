extends Control
## RTS stage tutorial: step-by-step onboarding covering all key gameplay.
## Steps: Camera → Select Worker → Gather → Build → Produce Unit → Attack → Attack Move → Intel Overlay
## Each step is action-gated: player must perform the action to advance.
## Mirrors the cell-stage tutorial_overlay.gd pattern exactly.

signal tutorial_completed

var _time: float = 0.0
var _alpha: float = 0.0
var _step: int = 0
var _step_time: float = 0.0
var _step_complete: bool = false
var _complete_flash: float = 0.0
var _finished: bool = false
var _fade_out_timer: float = 0.0

# Step-specific tracking
var _total_camera_move: float = 0.0
var _last_cam_pos: Vector2 = Vector2.ZERO
var _cam_pos_initialized: bool = false
var _selected_worker: bool = false
var _gather_issued: bool = false
var _building_placed: bool = false
var _unit_produced: bool = false
var _attack_issued: bool = false
var _attack_move_used: bool = false
var _intel_toggled: bool = false

# Step definitions
const STEPS: Array = [
	{
		"key": "WASD",
		"title": "CAMERA",
		"text": "Move the camera with WASD or screen edges",
		"sub": "Scroll wheel to zoom in/out. HOME key snaps to your base.",
	},
	{
		"key": "LMB",
		"title": "SELECT WORKER",
		"text": "Click on one of your worker units",
		"sub": "Workers are the small organisms near your Spawning Pool.",
	},
	{
		"key": "RMB",
		"title": "GATHER",
		"text": "Right-click a resource node to gather biomass",
		"sub": "Workers automatically return resources to the nearest depot.",
	},
	{
		"key": "Q",
		"title": "BUILD",
		"text": "Press Q to place a Spawning Pool (or any building key)",
		"sub": "Q/W/E/R/T = building hotkeys. Right-click or ESC to cancel.",
	},
	{
		"key": "",
		"title": "PRODUCE A UNIT",
		"text": "Click your Spawning Pool, then click a unit button on the HUD",
		"sub": "Units cost biomass and genes. Fighters are a good first choice.",
	},
	{
		"key": "RMB",
		"title": "ATTACK",
		"text": "Select combat units and right-click an enemy to attack",
		"sub": "Units auto-retaliate when attacked. S = Stop, H = Hold position.",
	},
	{
		"key": "A",
		"title": "ATTACK MOVE",
		"text": "Press A then left-click to attack-move to a location",
		"sub": "Units will engage enemies encountered along the way.",
	},
	{
		"key": "TAB",
		"title": "INTEL OVERLAY",
		"text": "Press TAB to open the intelligence overlay",
		"sub": "Shows faction strengths, your economy, and enemy assessments.",
	},
]


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
			tutorial_completed.emit()
			queue_free()
			return
		queue_redraw()
		return

	_complete_flash = move_toward(_complete_flash, 0.0, delta * 3.0)

	if not _step_complete:
		_check_step_action(delta)

	if _step_complete and _step_time > 0.6:
		_advance_step()

	queue_redraw()

func _check_step_action(delta: float) -> void:
	match _step:
		0:  # Camera — must pan at least 120 units
			var camera: Camera2D = get_viewport().get_camera_2d()
			if camera:
				if not _cam_pos_initialized:
					_last_cam_pos = camera.global_position
					_cam_pos_initialized = true
				var moved: float = camera.global_position.distance_to(_last_cam_pos)
				_last_cam_pos = camera.global_position
				_total_camera_move += moved
				if _total_camera_move > 120.0:
					_mark_complete()

		1:  # Select worker — check selection manager
			var sel_mgr: Node = _find_selection_manager()
			if sel_mgr and "selected_units" in sel_mgr:
				for unit in sel_mgr.selected_units:
					if is_instance_valid(unit) and "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
						_selected_worker = true
						_mark_complete()
						break
			# Fallback: if they select any unit after 10s, accept it
			if not _selected_worker and _step_time > 10.0 and sel_mgr and "selected_units" in sel_mgr:
				for unit in sel_mgr.selected_units:
					if is_instance_valid(unit) and unit.is_in_group("rts_units"):
						_mark_complete()
						break

		2:  # Gather — detect any worker in GATHER state
			if _gather_issued:
				_mark_complete()
			else:
				for unit in get_tree().get_nodes_in_group("rts_units"):
					if is_instance_valid(unit) and "faction_id" in unit and unit.faction_id == 0:
						if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
							if "state" in unit and unit.state == 3:  # GATHER
								_gather_issued = true
								_mark_complete()
								break

		3:  # Build — detect building placed
			if _building_placed:
				_mark_complete()
			else:
				# Fallback: check if player has more than 1 building (started with just Spawning Pool)
				var player_buildings: int = 0
				for building in get_tree().get_nodes_in_group("rts_buildings"):
					if is_instance_valid(building) and "faction_id" in building and building.faction_id == 0:
						player_buildings += 1
				if player_buildings > 1:
					_building_placed = true
					_mark_complete()

		4:  # Produce unit — detect any unit produced
			if _unit_produced:
				_mark_complete()
			else:
				# Check for queued units in any player building
				for building in get_tree().get_nodes_in_group("rts_buildings"):
					if is_instance_valid(building) and "faction_id" in building and building.faction_id == 0:
						if building.has_method("get_queue_size") and building.get_queue_size() > 0:
							_unit_produced = true
							_mark_complete()
							break

		5:  # Attack — detect attack command
			if _attack_issued:
				_mark_complete()
			else:
				for unit in get_tree().get_nodes_in_group("rts_units"):
					if is_instance_valid(unit) and "faction_id" in unit and unit.faction_id == 0:
						if "unit_type" in unit and unit.unit_type != UnitStats.UnitType.WORKER:
							if "state" in unit and unit.state == 2:  # ATTACK
								_attack_issued = true
								_mark_complete()
								break

		6:  # Attack move — detect A key press or command mode change
			if _attack_move_used:
				_mark_complete()
			else:
				# Fallback: detect command system in ATTACK_MOVE mode
				var stage: Node = get_tree().get_first_node_in_group("rts_stage")
				if stage and "_command_system" in stage:
					var cmd: Node = stage._command_system
					if "current_mode" in cmd and cmd.current_mode == 1:  # ATTACK_MOVE
						_attack_move_used = true
						_mark_complete()

		7:  # Intel overlay — detect TAB press
			if _intel_toggled:
				_mark_complete()
			else:
				# Fallback: detect intel overlay is visible
				var stage2: Node = get_tree().get_first_node_in_group("rts_stage")
				if stage2 and "_intel_overlay" in stage2:
					var intel: Control = stage2._intel_overlay
					if intel and intel.visible and intel.get("_active"):
						_intel_toggled = true
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
	if _step >= STEPS.size():
		_finished = true
		AudioManager.play_sensory_upgrade()

# === EXTERNAL HOOKS (called by stage manager / other systems) ===

func notify_building_placed() -> void:
	_building_placed = true

func notify_unit_produced() -> void:
	_unit_produced = true

func notify_attack_issued() -> void:
	_attack_issued = true

func notify_attack_move() -> void:
	_attack_move_used = true

func notify_intel_toggled() -> void:
	_intel_toggled = true

# === HELPERS ===

func _find_selection_manager() -> Node:
	var stage: Node = get_tree().get_first_node_in_group("rts_stage")
	if stage and "_selection_manager" in stage:
		return stage._selection_manager
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

	var step_data: Dictionary = STEPS[_step]

	# Standard action prompt
	_draw_action_step(vp, font, step_data)

	# Step progress dots at bottom
	_draw_progress_dots(vp)

func _draw_action_step(vp: Vector2, font: Font, step_data: Dictionary) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.72

	# Background pill
	var pill_w: float = 460.0
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

	# Key badge (left side) — only if key is specified
	var text_x: float = pill_x + 16.0
	if step_data.key != "":
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
		text_x = badge_x + badge_w + 16.0

		# Pulsing arrow pointing at key badge during active step
		if not _step_complete:
			var pulse: float = 0.6 + 0.4 * sin(_time * 4.0)
			var arrow_x: float = badge_x + badge_w * 0.5
			var arrow_y: float = badge_y - 6.0
			var arrow_col := Color(0.4, 0.8, 1.0, pulse * _alpha)
			draw_colored_polygon(PackedVector2Array([
				Vector2(arrow_x - 5, arrow_y - 8),
				Vector2(arrow_x + 5, arrow_y - 8),
				Vector2(arrow_x, arrow_y),
			]), arrow_col)

	# Title + instruction
	var title_text: String = step_data.title
	if _step_complete:
		title_text += "  OK"
	draw_string(font, Vector2(text_x, cy - 4), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.95, 1.0, _alpha))

	# Instruction text below
	draw_string(font, Vector2(text_x, cy + 16), step_data.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.7, 0.8, 0.8 * _alpha))

	# Subtitle hint below pill
	if step_data.sub != "":
		var sub_size := font.get_string_size(step_data.sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
		var sub_x: float = cx - sub_size.x * 0.5
		draw_string(font, Vector2(sub_x, pill_y + pill_h + 16), step_data.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.55, 0.65, 0.6 * _alpha))

	# Step counter label
	var counter_text: String = "Step %d / %d" % [_step + 1, STEPS.size()]
	var counter_size := font.get_string_size(counter_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11)
	draw_string(font, Vector2(pill_x + pill_w - counter_size.x - 8, pill_y - 6), counter_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.6, 0.7, 0.5 * _alpha))

func _draw_go_message(vp: Vector2, font: Font) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.45
	var go_text: String = "AI GRACE ACTIVE - BUILD YOUR BASE!"
	var go_fs: int = 28
	var go_size := font.get_string_size(go_text, HORIZONTAL_ALIGNMENT_CENTER, -1, go_fs)
	var gx: float = cx - go_size.x * 0.5

	var pw: float = go_size.x + 40.0
	var ph: float = 50.0
	draw_rect(Rect2(gx - 20, cy - 30, pw, ph), Color(0.02, 0.06, 0.03, 0.6 * _alpha))
	var accent := Color(0.3, 1.0, 0.5, 0.5 * _alpha)
	draw_rect(Rect2(gx - 20, cy - 30, pw, 1), accent)
	draw_rect(Rect2(gx - 20, cy + 19, pw, 1), accent)

	draw_string(font, Vector2(gx, cy), go_text, HORIZONTAL_ALIGNMENT_LEFT, -1, go_fs, Color(0.4, 1.0, 0.6, _alpha))

	var sub: String = "Enemies will not attack for 3 minutes — use this time to expand"
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
			draw_circle(Vector2(dx, dy), 3.5, Color(0.3, 0.9, 0.5, 0.7 * _alpha))
		elif i == _step:
			var pulse: float = 0.6 + 0.4 * sin(_time * 3.0)
			draw_circle(Vector2(dx, dy), 4.0, Color(0.4, 0.8, 1.0, pulse * _alpha))
		else:
			draw_arc(Vector2(dx, dy), 3.0, 0, TAU, 12, Color(0.3, 0.4, 0.5, 0.3 * _alpha), 1.0, true)

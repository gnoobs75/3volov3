extends Control
## RTS stage tutorial: comprehensive 17-step onboarding covering all key gameplay.
## Steps: Camera → Select Worker → Gather → Resources Info → Build → Rally Point →
##        Produce Unit → Unit Roles Info → Attack → Attack Move → Control Groups →
##        Shift-Queue → Formations → Tech Tree → Abilities → Intel Overlay → Victory Info
## Each step is action-gated: player must perform the action to advance.
## Info steps (Resources, Unit Roles, Victory) auto-advance with staggered line reveals.

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
var _rally_point_set: bool = false
var _unit_produced: bool = false
var _attack_issued: bool = false
var _attack_move_used: bool = false
var _control_group_assigned: bool = false
var _shift_queue_used: bool = false
var _formation_changed: bool = false
var _research_started: bool = false
var _ability_used: bool = false
var _intel_toggled: bool = false

const AUTO_ADVANCE_FALLBACK: float = 20.0

# Step definitions: key, title, text, sub
const STEPS: Array = [
	{  # 0
		"key": "WASD",
		"title": "CAMERA",
		"text": "Move the camera with WASD or screen edges",
		"sub": "Scroll wheel to zoom in/out. HOME key snaps to your base.",
	},
	{  # 1
		"key": "LMB",
		"title": "SELECT WORKER",
		"text": "Click on one of your worker units",
		"sub": "Workers are the small organisms near your Spawning Pool.",
	},
	{  # 2
		"key": "RMB",
		"title": "GATHER",
		"text": "Right-click a resource node to gather biomass",
		"sub": "Workers automatically return resources to the nearest depot.",
	},
	{  # 3 — INFO: Resources
		"key": "",
		"title": "YOUR RESOURCES",
		"text": "",
		"sub": "",
	},
	{  # 4
		"key": "Q",
		"title": "BUILD",
		"text": "Press Q to place a Spawning Pool (or any building key)",
		"sub": "Q/W/E/R/T/Y = building hotkeys. Right-click or ESC to cancel.",
	},
	{  # 5
		"key": "RMB",
		"title": "RALLY POINT",
		"text": "Select your building, then right-click the ground",
		"sub": "New units will automatically move to the rally point when produced.",
	},
	{  # 6
		"key": "",
		"title": "PRODUCE A UNIT",
		"text": "Click your Spawning Pool, then click a unit button",
		"sub": "Units cost biomass and genes. Fighters are a good first choice.",
	},
	{  # 7 — INFO: Unit Roles
		"key": "",
		"title": "UNIT ROLES",
		"text": "",
		"sub": "",
	},
	{  # 8
		"key": "RMB",
		"title": "ATTACK",
		"text": "Select combat units and right-click an enemy to attack",
		"sub": "Units auto-retaliate when attacked. Right-click = smart command.",
	},
	{  # 9
		"key": "A",
		"title": "ATTACK MOVE",
		"text": "Press A then left-click to attack-move to a location",
		"sub": "Units will engage enemies encountered along the way.",
	},
	{  # 10
		"key": "Ctrl+1",
		"title": "CONTROL GROUPS",
		"text": "Select units, then press Ctrl+1 to assign group 1",
		"sub": "Press 1 to recall. Shift+1 adds to group. Use 1-9 for different groups.",
	},
	{  # 11
		"key": "Shift+RMB",
		"title": "SHIFT-QUEUE",
		"text": "Hold Shift and right-click to queue waypoints",
		"sub": "Units execute commands in order. Great for patrol routes and multi-drops.",
	},
	{  # 12
		"key": "F",
		"title": "FORMATIONS",
		"text": "Select 3+ military units and press F to cycle formations",
		"sub": "Spread / Line / Box / Wedge — units hold formation while moving.",
	},
	{  # 13
		"key": "",
		"title": "TECH TREE",
		"text": "Select an Evolution Chamber and click a research button",
		"sub": "Upgrades boost all your units. Higher tiers unlock stronger bonuses.",
	},
	{  # 14
		"key": "V",
		"title": "ABILITIES",
		"text": "Select a military unit and press V to toggle its ability",
		"sub": "Fighters charge, Defenders fortify, Scouts reveal, Ranged volley.",
	},
	{  # 15
		"key": "TAB",
		"title": "INTEL OVERLAY",
		"text": "Press TAB to open the intelligence overlay",
		"sub": "Shows faction strengths, your economy, and enemy assessments.",
	},
	{  # 16 — INFO: Victory
		"key": "",
		"title": "VICTORY CONDITION",
		"text": "",
		"sub": "",
	},
]

# Info panel line definitions
const RESOURCE_LINES: Array = [
	{"icon": "BIO", "color": Color(0.3, 0.9, 0.4), "text": "BIOMASS  —  Primary resource. Gathered by workers from nodes."},
	{"icon": "GEN", "color": Color(0.5, 0.4, 1.0), "text": "GENES  —  Secondary resource. Needed for advanced units and research."},
	{"icon": "SUP", "color": Color(0.9, 0.8, 0.3), "text": "SUPPLY  —  Unit cap. Build Supply Depots (Y) to increase your limit."},
]
const RESOURCE_READ_TIME: float = 8.0

const UNIT_ROLE_LINES: Array = [
	{"icon": "", "color": Color(0.8, 0.3, 0.3), "text": "FIGHTER  —  Melee damage dealer. Charge ability dashes through enemies."},
	{"icon": "", "color": Color(0.3, 0.6, 0.9), "text": "DEFENDER  —  Heavy tank. Fortify ability absorbs damage, taunts enemies."},
	{"icon": "", "color": Color(0.3, 0.9, 0.6), "text": "SCOUT  —  Fast recon. Spores ability reveals fog of war in a huge area."},
	{"icon": "", "color": Color(0.9, 0.6, 0.3), "text": "RANGED  —  Projectile attacker. Acid Volley fires a spread of shots."},
]
const UNIT_ROLE_READ_TIME: float = 9.0

const VICTORY_LINES: Array = [
	{"icon": "", "color": Color(0.9, 0.4, 0.3), "text": "Eliminate all 3 enemy factions to win — destroy their buildings and units."},
	{"icon": "", "color": Color(0.3, 0.7, 0.9), "text": "Map events (blooms, quakes, surges) appear periodically — use them!"},
	{"icon": "", "color": Color(0.9, 0.8, 0.3), "text": "R = Repair damaged buildings. F1 = Production overview. F10 = Surrender."},
	{"icon": "", "color": Color(0.5, 1.0, 0.6), "text": "You have a 3-minute grace period — build your economy and army now!"},
]
const VICTORY_READ_TIME: float = 10.0


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
		# Fallback auto-advance
		if not _step_complete and _step_time > AUTO_ADVANCE_FALLBACK:
			_mark_complete()

	if _step_complete and _step_time > 0.6:
		_advance_step()

	queue_redraw()

func _check_step_action(_delta: float) -> void:
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

		1:  # Select worker
			var sel_mgr: Node = _find_selection_manager()
			if sel_mgr and "selected_units" in sel_mgr:
				for unit in sel_mgr.selected_units:
					if is_instance_valid(unit) and "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
						_selected_worker = true
						_mark_complete()
						break
			if not _selected_worker and _step_time > 10.0 and sel_mgr and "selected_units" in sel_mgr:
				for unit in sel_mgr.selected_units:
					if is_instance_valid(unit) and unit.is_in_group("rts_units"):
						_mark_complete()
						break

		2:  # Gather
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

		3:  # Resources info — auto-advance
			if _step_time >= RESOURCE_READ_TIME:
				_mark_complete()

		4:  # Build
			if _building_placed:
				_mark_complete()
			else:
				var player_buildings: int = 0
				for building in get_tree().get_nodes_in_group("rts_buildings"):
					if is_instance_valid(building) and "faction_id" in building and building.faction_id == 0:
						player_buildings += 1
				if player_buildings > 1:
					_building_placed = true
					_mark_complete()

		5:  # Rally point
			if _rally_point_set:
				_mark_complete()
			else:
				# Fallback: check if any building has a rally point set
				for building in get_tree().get_nodes_in_group("rts_buildings"):
					if is_instance_valid(building) and "faction_id" in building and building.faction_id == 0:
						if "has_rally_point" in building and building.has_rally_point:
							_rally_point_set = true
							_mark_complete()
							break

		6:  # Produce unit
			if _unit_produced:
				_mark_complete()
			else:
				for building in get_tree().get_nodes_in_group("rts_buildings"):
					if is_instance_valid(building) and "faction_id" in building and building.faction_id == 0:
						if building.has_method("get_queue_size") and building.get_queue_size() > 0:
							_unit_produced = true
							_mark_complete()
							break

		7:  # Unit roles info — auto-advance
			if _step_time >= UNIT_ROLE_READ_TIME:
				_mark_complete()

		8:  # Attack
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

		9:  # Attack move — requires actual attack-move command (A + click)
			if _attack_move_used:
				_mark_complete()

		10:  # Control groups
			if _control_group_assigned:
				_mark_complete()

		11:  # Shift-queue
			if _shift_queue_used:
				_mark_complete()

		12:  # Formations
			if _formation_changed:
				_mark_complete()

		13:  # Tech tree — detect research queued at Evolution Chamber
			if _research_started:
				_mark_complete()
			else:
				for building in get_tree().get_nodes_in_group("rts_buildings"):
					if is_instance_valid(building) and "faction_id" in building and building.faction_id == 0:
						if building.has_method("get_research_queue_size"):
							if building.get_research_queue_size() > 0:
								_research_started = true
								_mark_complete()
								break
						# Fallback: check if researching property exists
						if "_is_researching" in building and building._is_researching:
							_research_started = true
							_mark_complete()
							break

		14:  # Abilities
			if _ability_used:
				_mark_complete()

		15:  # Intel overlay
			if _intel_toggled:
				_mark_complete()
			else:
				var stage2: Node = get_tree().get_first_node_in_group("rts_stage")
				if stage2 and "_intel_overlay" in stage2:
					var intel: Control = stage2._intel_overlay
					if intel and intel.visible and intel.get("_active"):
						_intel_toggled = true
						_mark_complete()

		16:  # Victory info — auto-advance
			if _step_time >= VICTORY_READ_TIME:
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

func notify_rally_point_set() -> void:
	_rally_point_set = true

func notify_unit_produced() -> void:
	_unit_produced = true

func notify_attack_issued() -> void:
	_attack_issued = true

func notify_attack_move() -> void:
	_attack_move_used = true

func notify_control_group_assigned() -> void:
	_control_group_assigned = true

func notify_shift_queue_used() -> void:
	_shift_queue_used = true

func notify_formation_changed() -> void:
	_formation_changed = true

func notify_research_started() -> void:
	_research_started = true

func notify_ability_used() -> void:
	_ability_used = true

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

	# Info panel steps get special rendering
	match _step:
		3: _draw_info_panel(vp, font, "YOUR RESOURCES", RESOURCE_LINES, RESOURCE_READ_TIME, Color(0.3, 0.9, 0.4))
		7: _draw_info_panel(vp, font, "UNIT ROLES", UNIT_ROLE_LINES, UNIT_ROLE_READ_TIME, Color(0.4, 0.7, 1.0))
		16: _draw_info_panel(vp, font, "VICTORY CONDITION", VICTORY_LINES, VICTORY_READ_TIME, Color(0.9, 0.5, 0.3))
		_: _draw_action_step(vp, font, STEPS[_step])

	_draw_progress_dots(vp)

func _draw_action_step(vp: Vector2, font: Font, step_data: Dictionary) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.72

	# Background pill
	var pill_w: float = 480.0
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

		# Pulsing arrow pointing at key badge
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
	draw_string(font, Vector2(text_x, cy + 16), step_data.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.7, 0.8, 0.8 * _alpha))

	# Subtitle hint below pill
	if step_data.sub != "":
		var sub_size := font.get_string_size(step_data.sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
		var sub_x: float = cx - sub_size.x * 0.5
		draw_string(font, Vector2(sub_x, pill_y + pill_h + 16), step_data.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.55, 0.65, 0.6 * _alpha))

	# Step counter
	var counter_text: String = "Step %d / %d" % [_step + 1, STEPS.size()]
	var counter_size := font.get_string_size(counter_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11)
	draw_string(font, Vector2(pill_x + pill_w - counter_size.x - 8, pill_y - 6), counter_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.6, 0.7, 0.5 * _alpha))

func _draw_info_panel(vp: Vector2, font: Font, title: String, lines: Array, read_time: float, accent_color: Color) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.65

	var line_count: int = lines.size()
	var pill_w: float = 540.0
	var pill_h: float = 50.0 + line_count * 24.0
	var pill_x: float = cx - pill_w * 0.5
	var pill_y: float = cy - pill_h * 0.5
	draw_rect(Rect2(pill_x, pill_y, pill_w, pill_h), Color(0.08, 0.10, 0.18, 0.7 * _alpha))

	var accent := Color(accent_color.r, accent_color.g, accent_color.b, 0.5 * _alpha)
	draw_rect(Rect2(pill_x, pill_y, pill_w, 1), accent)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 1, pill_w, 1), accent)

	# Title
	draw_string(font, Vector2(pill_x + 16, pill_y + 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.95, 1.0, _alpha))

	# Stagger each line
	for i in range(line_count):
		var line: Dictionary = lines[i]
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
	var progress: float = clampf(_step_time / read_time, 0.0, 1.0)
	draw_rect(Rect2(pill_x, pill_y + pill_h - 3, pill_w * progress, 3), Color(accent_color.r, accent_color.g, accent_color.b, 0.3 * _alpha))

	# Step counter
	var counter_text: String = "Step %d / %d" % [_step + 1, STEPS.size()]
	var counter_size := font.get_string_size(counter_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11)
	draw_string(font, Vector2(pill_x + pill_w - counter_size.x - 8, pill_y - 6), counter_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.6, 0.7, 0.5 * _alpha))

func _draw_go_message(vp: Vector2, font: Font) -> void:
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.45
	var go_text: String = "AI GRACE ACTIVE — BUILD YOUR BASE!"
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

	var sub: String = "Enemies will not attack for 3 minutes — expand your colony!"
	var sub_size := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	draw_string(font, Vector2(cx - sub_size.x * 0.5, cy + 30), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.7, 0.5, 0.6 * _alpha))

func _draw_progress_dots(vp: Vector2) -> void:
	var cx: float = vp.x * 0.5
	var dy: float = vp.y * 0.82
	var total: int = STEPS.size()
	var dot_spacing: float = 12.0
	var start_x: float = cx - (total - 1) * dot_spacing * 0.5

	for i in range(total):
		var dx: float = start_x + i * dot_spacing
		if i < _step:
			draw_circle(Vector2(dx, dy), 3.0, Color(0.3, 0.9, 0.5, 0.7 * _alpha))
		elif i == _step:
			var pulse: float = 0.6 + 0.4 * sin(_time * 3.0)
			draw_circle(Vector2(dx, dy), 3.5, Color(0.4, 0.8, 1.0, pulse * _alpha))
		else:
			draw_arc(Vector2(dx, dy), 2.5, 0, TAU, 12, Color(0.3, 0.4, 0.5, 0.3 * _alpha), 1.0, true)

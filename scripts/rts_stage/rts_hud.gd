extends Control
## RTS HUD: resource bar, unit info panel, command buttons, build menu,
## production panel, tooltips, idle-worker counter, income rate, game timer,
## difficulty indicator, hotkey labels, multi-selection icons.
## All procedural _draw() matching UIConstants style.

var _stage: Node = null
var _selection_mgr: Node = null
var _command_sys: Node = null
var _time: float = 0.0
var _build_menu_open: bool = false
var _hover_btn: int = -1
var _hover_build: int = -1
var _hover_production: int = -1  # Legacy, kept for compatibility
var _game_speed: float = 1.0
var _dragging_speed_slider: bool = false
const SPEED_MIN: float = 0.25
const SPEED_MAX: float = 2.0

# --- Tooltip ---
var _tooltip_text: String = ""
var _tooltip_pos: Vector2 = Vector2.ZERO

# --- Idle workers ---
var _idle_worker_count: int = 0
var _idle_worker_cycle_idx: int = 0

# --- Resource income ---
var _last_biomass: int = 0
var _last_genes: int = 0
var _income_biomass: int = 0
var _income_genes: int = 0
var _income_timer: float = 0.0
var _low_resource_pulse: float = 0.0  # For resource warning flash

# --- Threat detector ---
var _threat_detector: Node = null
var _income_changed_pulse: float = 0.0

# --- Income sparkline graph ---
var _income_history_bio: Array = []  # Last 12 income samples (biomass)
var _income_history_gen: Array = []  # Last 12 income samples (genes)
var _income_history_timer: float = 0.0
const INCOME_HISTORY_INTERVAL: float = 5.0
const INCOME_HISTORY_MAX: int = 12

# --- Unit stack indicators ---
var _unit_clusters: Array = []  # [{center: Vector2, count: int}]
var _cluster_update_frame: int = 0
const CLUSTER_RADIUS: float = 15.0
const CLUSTER_MIN_SIZE: int = 3

# --- Map pings (typed: 0=danger, 1=assist, 2=omw) ---
var _map_pings: Array = []  # [{pos: Vector2, time: float, type: int}]
const PING_LIFE: float = 4.0
const PING_MAX: int = 5
const PING_DANGER: int = 0
const PING_ASSIST: int = 1
const PING_OMW: int = 2
const PING_COLORS: Array = [
	Color(1.0, 0.3, 0.2),   # Danger - red
	Color(1.0, 0.85, 0.2),  # Assist - yellow
	Color(0.2, 1.0, 0.4),   # On My Way - green
]

# --- Surrender confirmation ---
var _surrender_confirm: bool = false
var _surrender_blink: float = 0.0

# --- Victory manager ref (for surrender) ---
var _victory_manager: Node = null

# --- Event announcements ---
var _event_announcement: String = ""
var _event_announce_timer: float = 0.0
var _event_announce_color: Color = Color.WHITE

# --- Threat alert edge positions (for click detection) ---
var _threat_edge_positions: Array = []  # [{pos: Vector2, threat_pos: Vector2}]

# --- Game timer (fallback) ---
var _local_game_time: float = 0.0

# --- Difficulty ---
enum AIDifficulty { NOOB, EASY, MEDIUM, HARD, SWEATY }
var _ai_difficulty: int = AIDifficulty.MEDIUM
const DIFFICULTY_NAMES: Array = ["NOOB", "EASY", "MEDIUM", "HARD", "SWEATY"]
const DIFFICULTY_COLORS: Array = [
	Color(0.4, 0.9, 0.4),   # NOOB - green
	Color(0.5, 0.85, 0.5),  # EASY - green
	Color(1.0, 0.9, 0.3),   # MEDIUM - yellow
	Color(1.0, 0.55, 0.2),  # HARD - orange
	Color(0.95, 0.25, 0.2), # SWEATY - red
]

const BUILD_BUTTONS: Array = [
	{"type": BuildingStats.BuildingType.SPAWNING_POOL, "key": "Q"},
	{"type": BuildingStats.BuildingType.EVOLUTION_CHAMBER, "key": "W"},
	{"type": BuildingStats.BuildingType.MEMBRANE_TOWER, "key": "E"},
	{"type": BuildingStats.BuildingType.BIO_WALL, "key": "R"},
	{"type": BuildingStats.BuildingType.NUTRIENT_PROCESSOR, "key": "T"},
	{"type": BuildingStats.BuildingType.SUPPLY_DEPOT, "key": "Y"},
	{"type": BuildingStats.BuildingType.SINGULARITY_CORE, "key": "U"},
]

const BUILDING_DESCRIPTIONS: Dictionary = {
	0: "Main base. Produces workers. Drop-off for resources.",
	1: "Produces combat units: Warriors, Tanks, Scouts, Spitters, Siege Worms, Psi-Casters.",
	2: "Defensive tower. Auto-attacks nearby enemies.",
	3: "Cheap wall segment. Blocks enemy movement.",
	4: "Secondary resource drop-off. Provides +5 supply.",
	5: "Organic storage sac. +10 unit supply cap.",
	6: "Superweapon. Charges 60s, then fires pulse dealing 80 damage to all enemies.",
}

const UNIT_DESCRIPTIONS: Dictionary = {
	0: "Gathers resources and constructs buildings.",
	1: "Melee fighter. +50% charge damage after moving.",
	2: "Heavy tank. High HP and armor, slow.",
	3: "Fast scout. Double detection range.",
	4: "Ranged spitter. Fires acid projectiles.",
	5: "Healer. Auto-heals wounded allies. Regen Aura ability.",
	6: "Artillery. Must deploy to attack. Splash damage.",
	7: "Debuffer. Psi Field reduces enemy armor. Neural Disruption slows.",
}

# Evolved 3x4 Command Card — context-sensitive buttons
const WORKER_CMD: Array = [
	{"label": "Move", "hotkey": "M", "tooltip": "Move (M)", "action": "move"},
	{"label": "Stop", "hotkey": "S", "tooltip": "Stop (S)", "action": "stop"},
	{"label": "Hold", "hotkey": "H", "tooltip": "Hold Position (H)", "action": "hold"},
	{"label": "Attack", "hotkey": "A", "tooltip": "Attack Move (A)", "action": "attack_move"},
	{"label": "Patrol", "hotkey": "P", "tooltip": "Patrol (P)", "action": "patrol"},
	{"label": "Build", "hotkey": "B", "tooltip": "Build Menu (B)", "action": "build"},
	{"label": "Gather", "hotkey": "G", "tooltip": "Right-click resource to gather", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "Burst", "hotkey": "V", "tooltip": "Burst Gather: 3x gather for 5s (V)", "action": "ability"},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
]
const MILITARY_CMD: Array = [
	{"label": "Move", "hotkey": "M", "tooltip": "Move (M)", "action": "move"},
	{"label": "Stop", "hotkey": "S", "tooltip": "Stop (S)", "action": "stop"},
	{"label": "Hold", "hotkey": "H", "tooltip": "Hold Position (H)", "action": "hold"},
	{"label": "Attack", "hotkey": "A", "tooltip": "Attack Move (A)", "action": "attack_move"},
	{"label": "Patrol", "hotkey": "P", "tooltip": "Patrol (P)", "action": "patrol"},
	{"label": "Formation", "hotkey": "F", "tooltip": "Cycle Formation (F)", "action": "formation"},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "Ability", "hotkey": "V", "tooltip": "Use unit ability (V)", "action": "ability"},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
]
const BUILDING_CMD: Array = [
	{"label": "Rally", "hotkey": "R", "tooltip": "Set Rally Point (R)", "action": "rally"},
	{"label": "Cancel", "hotkey": "X", "tooltip": "Cancel last queue item (X)", "action": "cancel_queue"},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
	{"label": "", "hotkey": "", "tooltip": "", "action": ""},
]
const CMD_GRID_COLS: int = 3
const CMD_GRID_ROWS: int = 4

func setup(stage: Node, sel: Node, cmd: Node) -> void:
	_stage = stage
	_selection_mgr = sel
	_command_sys = cmd
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_threat_detector(detector: Node) -> void:
	_threat_detector = detector

func set_victory_manager(vm: Node) -> void:
	_victory_manager = vm

func add_map_ping(pos: Vector2, ping_type: int) -> void:
	_map_pings.append({"pos": pos, "time": 0.0, "type": clampi(ping_type, 0, 2)})
	if _map_pings.size() > PING_MAX:
		_map_pings.pop_front()

func show_event_announcement(text: String, color: Color) -> void:
	_event_announcement = text
	_event_announce_timer = 3.0
	_event_announce_color = color

func _process(delta: float) -> void:
	_time += delta
	_local_game_time += delta

	var vp: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_local_mouse_position()

	# --- Hover detection ---
	_hover_btn = -1
	_hover_build = -1
	_hover_production = -1

	var active_cmds: Array = _get_active_command_set()
	for i in range(CMD_GRID_COLS * CMD_GRID_ROWS):
		if _get_cmd_btn_rect(vp, i).has_point(mouse):
			if i < active_cmds.size() and active_cmds[i].get("label", "") != "":
				_hover_btn = i

	if _build_menu_open:
		for i in range(BUILD_BUTTONS.size()):
			if _get_build_btn_rect(vp, i).has_point(mouse):
				_hover_build = i

	var sel: Array = _selection_mgr.selected_units if _selection_mgr else []

	# --- Tooltip ---
	_tooltip_text = ""
	_tooltip_pos = mouse
	if _hover_btn >= 0 and _hover_btn < active_cmds.size():
		_tooltip_text = active_cmds[_hover_btn].get("tooltip", "")
	elif _hover_build >= 0:
		var bt: int = BUILD_BUTTONS[_hover_build].type
		var bname: String = BuildingStats.get_building_name(bt)
		var cost: Dictionary = BuildingStats.get_cost(bt)
		var desc: String = BUILDING_DESCRIPTIONS.get(bt, "")
		_tooltip_text = "%s  (%dB / %dG)\n%s" % [bname, cost.get("biomass", 0), cost.get("genes", 0), desc]
	elif _get_speed_slider_rect(vp).grow(4).has_point(mouse):
		_tooltip_text = "Game Speed: drag to adjust (0.25x - 2.0x)"
	elif _get_difficulty_rect(vp).has_point(mouse):
		_tooltip_text = "Click to cycle AI difficulty"

	# --- Idle worker scan (every frame is cheap for faction_0 group) ---
	_idle_worker_count = 0
	if _stage:
		for unit in get_tree().get_nodes_in_group("faction_0"):
			if unit.is_in_group("rts_units") and is_instance_valid(unit):
				if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
					if "state" in unit and unit.state == 0:  # IDLE
						_idle_worker_count += 1

	# --- Low resource warning ---
	_low_resource_pulse += delta * 3.0

	# --- Resource income ---
	_income_timer += delta
	if _income_timer >= 2.0:
		if _stage and _stage.has_method("get_resource_manager"):
			var rm: Node = _stage.get_resource_manager()
			var cur_bio: int = rm.get_biomass(0)
			var cur_gen: int = rm.get_genes(0)
			var new_income_bio: int = int((cur_bio - _last_biomass) / 2.0)
			var new_income_gen: int = int((cur_gen - _last_genes) / 2.0)
			if new_income_bio != _income_biomass or new_income_gen != _income_genes:
				_income_changed_pulse = 1.0
			_income_biomass = new_income_bio
			_income_genes = new_income_gen
			_last_biomass = cur_bio
			_last_genes = cur_gen
		_income_timer = 0.0

	# --- Income sparkline history ---
	_income_history_timer += delta
	if _income_history_timer >= INCOME_HISTORY_INTERVAL:
		_income_history_timer = 0.0
		_income_history_bio.append(_income_biomass)
		_income_history_gen.append(_income_genes)
		if _income_history_bio.size() > INCOME_HISTORY_MAX:
			_income_history_bio.pop_front()
		if _income_history_gen.size() > INCOME_HISTORY_MAX:
			_income_history_gen.pop_front()

	# --- Unit stack indicator (update every 10 frames) ---
	_cluster_update_frame += 1
	if _cluster_update_frame >= 10:
		_cluster_update_frame = 0
		_compute_unit_clusters()

	# --- Income pulse decay ---
	if _income_changed_pulse > 0.0:
		_income_changed_pulse = maxf(0.0, _income_changed_pulse - delta * 2.0)

	# --- Event announcement timer ---
	if _event_announce_timer > 0.0:
		_event_announce_timer -= delta

	# --- Map pings update ---
	var pi: int = _map_pings.size() - 1
	while pi >= 0:
		_map_pings[pi]["time"] += delta
		if _map_pings[pi]["time"] >= PING_LIFE:
			_map_pings.remove_at(pi)
		pi -= 1

	# --- Surrender blink ---
	if _surrender_confirm:
		_surrender_blink += delta * 4.0

	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var vp: Vector2 = get_viewport_rect().size
		var mouse: Vector2 = event.position
		if event.pressed:
			# Threat alert click-to-snap
			for ta in _threat_edge_positions:
				if mouse.distance_to(ta["pos"]) < 20.0:
					var camera: Camera2D = get_viewport().get_camera_2d()
					if camera and camera.has_method("focus_position"):
						camera.focus_position(ta["threat_pos"])
					get_viewport().set_input_as_handled()
					return
			# Speed slider drag start
			var sr: Rect2 = _get_speed_slider_rect(vp)
			if sr.has_point(mouse):
				_dragging_speed_slider = true
				_update_speed_from_mouse(mouse, sr)
				get_viewport().set_input_as_handled()
				return
			# Idle worker button
			if _get_idle_worker_rect(vp).has_point(mouse) and _idle_worker_count > 0:
				_cycle_idle_worker()
				get_viewport().set_input_as_handled()
				return
			# Difficulty button
			if _get_difficulty_rect(vp).has_point(mouse):
				_ai_difficulty = (_ai_difficulty + 1) % DIFFICULTY_NAMES.size()
				if _stage and _stage.has_method("set_ai_difficulty"):
					_stage.set_ai_difficulty(_ai_difficulty)
				get_viewport().set_input_as_handled()
				return
			# Command buttons
			if _hover_btn >= 0:
				_handle_cmd_button(_hover_btn)
				get_viewport().set_input_as_handled()
				return
			# Build menu
			if _hover_build >= 0:
				_handle_build_button(_hover_build)
				get_viewport().set_input_as_handled()
				return
		else:
			_dragging_speed_slider = false
	elif event is InputEventMouseMotion and _dragging_speed_slider:
		var vp: Vector2 = get_viewport_rect().size
		_update_speed_from_mouse(event.position, _get_speed_slider_rect(vp))
		get_viewport().set_input_as_handled()
	# --- Surrender key handling ---
	elif event is InputEventKey and event.pressed:
		if _surrender_confirm:
			if event.keycode == KEY_Y:
				_surrender_confirm = false
				if _victory_manager and _victory_manager.has_method("force_loss"):
					_victory_manager.force_loss()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_N or event.keycode == KEY_ESCAPE:
				_surrender_confirm = false
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_F10:
			_surrender_confirm = true
			_surrender_blink = 0.0
			get_viewport().set_input_as_handled()
			return

func _handle_cmd_button(idx: int) -> void:
	if not _selection_mgr or not _command_sys:
		return
	var cmds: Array = _get_active_command_set()
	if idx < 0 or idx >= cmds.size():
		return
	var action: String = cmds[idx].get("action", "")
	if action == "":
		return
	var units: Array = _selection_mgr.selected_units
	match action:
		"move":
			pass  # Move requires a target position (right-click)
		"stop":
			_command_sys.issue_stop(units)
		"hold":
			_command_sys.issue_hold(units)
		"attack_move":
			_command_sys.enter_attack_move_mode()
		"patrol":
			_command_sys.enter_patrol_mode()
		"build":
			_build_menu_open = not _build_menu_open
		"formation":
			if _command_sys.has_method("cycle_formation"):
				_command_sys.cycle_formation()
		"ability":
			if _command_sys.has_method("issue_ability"):
				# Ability needs a target position; use current mouse world pos as fallback
				var camera: Camera2D = get_viewport().get_camera_2d()
				var mouse_world: Vector2 = Vector2.ZERO
				if camera:
					mouse_world = camera.get_global_mouse_position()
				_command_sys.issue_ability(units, mouse_world)
		"rally":
			pass  # Rally requires right-click on map
		"cancel_queue":
			# Cancel last item in production queue with 75% refund
			if units.size() == 1 and is_instance_valid(units[0]):
				var building: Node2D = units[0]
				if building.is_in_group("rts_buildings") and building.has_method("cancel_last_queue_item"):
					building.cancel_last_queue_item()
		"produce":
			# Production button — slot idx maps to can_produce index stored in meta
			var produce_idx: int = cmds[idx].get("produce_idx", -1)
			if produce_idx >= 0 and units.size() == 1:
				var building: Node2D = units[0]
				if is_instance_valid(building) and building.is_in_group("rts_buildings"):
					if "can_produce" in building and produce_idx < building.can_produce.size():
						building.queue_unit(building.can_produce[produce_idx])

func _handle_build_button(idx: int) -> void:
	if idx < 0 or idx >= BUILD_BUTTONS.size():
		return
	var bt: int = BUILD_BUTTONS[idx].type
	if _stage and _stage.has_method("get_input_handler"):
		var ih: Control = _stage.get_input_handler()
		if ih and ih.has_method("enter_build_mode"):
			ih.enter_build_mode(bt)
	_build_menu_open = false

# === IDLE WORKER CYCLE ===

func _cycle_idle_worker() -> void:
	var idle_workers: Array = []
	for unit in get_tree().get_nodes_in_group("faction_0"):
		if unit.is_in_group("rts_units") and is_instance_valid(unit):
			if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
				if "state" in unit and unit.state == 0:
					idle_workers.append(unit)
	if idle_workers.is_empty():
		return
	_idle_worker_cycle_idx = _idle_worker_cycle_idx % idle_workers.size()
	var worker: Node2D = idle_workers[_idle_worker_cycle_idx]
	_idle_worker_cycle_idx = (_idle_worker_cycle_idx + 1) % idle_workers.size()
	# Select and center camera
	if _selection_mgr:
		_selection_mgr.select_unit(worker, false)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera and camera.has_method("focus_position"):
		camera.focus_position(worker.global_position)

# === RECT HELPERS ===

func _get_speed_slider_rect(vp: Vector2) -> Rect2:
	return Rect2(vp.x - 220, 8, 150, 24)

func _update_speed_from_mouse(mouse: Vector2, sr: Rect2) -> void:
	var t: float = clampf((mouse.x - sr.position.x) / sr.size.x, 0.0, 1.0)
	_game_speed = lerpf(SPEED_MIN, SPEED_MAX, t)
	Engine.time_scale = _game_speed

func _get_cmd_btn_rect(vp: Vector2, idx: int) -> Rect2:
	var bw: float = 68.0
	var bh: float = 28.0
	var col: int = idx % CMD_GRID_COLS
	var row: int = idx / CMD_GRID_COLS
	var grid_w: float = float(CMD_GRID_COLS) * (bw + 4)
	var sx: float = vp.x - grid_w - 10.0 + float(col) * (bw + 4)
	var sy: float = vp.y - 118.0 + float(row) * (bh + 3)
	return Rect2(sx, sy, bw, bh)

func _get_build_btn_rect(vp: Vector2, idx: int) -> Rect2:
	var bw: float = 130.0
	var bh: float = 36.0
	var sx: float = vp.x - 350.0
	var sy: float = vp.y - 250.0 + idx * (bh + 4)
	return Rect2(sx, sy, bw, bh)

func _get_idle_worker_rect(vp: Vector2) -> Rect2:
	return Rect2(510, 4, 80, 32)

func _get_difficulty_rect(vp: Vector2) -> Rect2:
	# Placed right after the game timer in the top-center area
	var label_w: float = 70.0
	return Rect2(vp.x * 0.5 + 50, 4, label_w, 32)

func _get_game_time() -> float:
	if _stage:
		for child in _stage.get_children():
			if child.has_method("get_game_time"):
				return child.get_game_time()
	return _local_game_time

# === UNIT CLUSTER COMPUTATION ===

func _compute_unit_clusters() -> void:
	_unit_clusters.clear()
	if not _stage:
		return
	var player_units: Array = []
	for unit in get_tree().get_nodes_in_group("faction_0"):
		if unit.is_in_group("rts_units") and is_instance_valid(unit):
			player_units.append(unit)
	if player_units.is_empty():
		return
	# Simple greedy clustering: iterate units, assign to nearby cluster or create new
	var assigned: Array = []
	assigned.resize(player_units.size())
	assigned.fill(false)
	var clusters: Array = []  # [{positions: [Vector2], center: Vector2}]
	for i in range(player_units.size()):
		if assigned[i]:
			continue
		var cluster_positions: Array = [player_units[i].global_position]
		assigned[i] = true
		# Find all nearby unassigned units
		for j in range(i + 1, player_units.size()):
			if assigned[j]:
				continue
			# Check distance to any unit already in this cluster
			var pos_j: Vector2 = player_units[j].global_position
			var close: bool = false
			for cp in cluster_positions:
				if cp.distance_to(pos_j) <= CLUSTER_RADIUS:
					close = true
					break
			if close:
				cluster_positions.append(pos_j)
				assigned[j] = true
		if cluster_positions.size() >= CLUSTER_MIN_SIZE:
			var center: Vector2 = Vector2.ZERO
			for cp in cluster_positions:
				center += cp
			center /= float(cluster_positions.size())
			clusters.append({"center": center, "count": cluster_positions.size()})
	_unit_clusters = clusters

# ====================== DRAW ======================

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()

	# === TOP BAR: Resources ===
	draw_rect(Rect2(0, 0, vp.x, 40), Color(UIConstants.BG_DARK.r, UIConstants.BG_DARK.g, UIConstants.BG_DARK.b, 0.85))
	draw_line(Vector2(0, 39), Vector2(vp.x, 39), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)
	# Membrane border around resource panel area
	var _res_panel_rect: Rect2 = Rect2(8, 2, 490, 36)
	_draw_membrane_border(_res_panel_rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.25), 1.5, 10.0)
	# Income change pulse glow
	if _income_changed_pulse > 0.0:
		draw_rect(Rect2(8, 2, 490, 36), Color(0.3, 0.9, 0.5, 0.06 * _income_changed_pulse))

	if _stage and _stage.has_method("get_resource_manager"):
		var rm: Node = _stage.get_resource_manager()
		var biomass: int = rm.get_biomass(0)
		var genes: int = rm.get_genes(0)
		var low_bio: bool = biomass < 50
		var low_gen: bool = genes < 10 and genes >= 0
		var warn_pulse: float = 0.5 + 0.5 * sin(_low_resource_pulse)
		# Biomass icon: bioluminescent circle with inner glow
		var bio_color: Color = UIConstants.STAT_GREEN
		if low_bio:
			bio_color = Color(1.0, 0.4, 0.3).lerp(UIConstants.STAT_GREEN, warn_pulse)
		draw_circle(Vector2(30, 20), 8, Color(0.1, 0.3, 0.15, 0.5))
		draw_circle(Vector2(30, 20), 6, Color(0.2, 0.8, 0.4, 0.8))
		draw_circle(Vector2(30, 20), 3, Color(0.5, 1.0, 0.6, 0.3 + 0.15 * sin(_time * 3.0)))
		if low_bio:
			draw_arc(Vector2(30, 20), 10.0, 0, TAU, 16, Color(1.0, 0.3, 0.2, 0.5 * warn_pulse), 1.5)
		draw_string(font, Vector2(42, 27), "Biomass: %d" % biomass, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, bio_color)
		# Income rate (biomass)
		var inc_bio_text: String = "+%d/s" % _income_biomass if _income_biomass >= 0 else "%d/s" % _income_biomass
		var bio_w: float = font.get_string_size("Biomass: %d" % biomass, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY).x
		var inc_bio_color: Color = Color(0.25, 0.65, 0.4, 0.7) if _income_biomass >= 0 else Color(0.9, 0.3, 0.3, 0.7)
		draw_string(mono, Vector2(42 + bio_w + 6, 27), inc_bio_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, inc_bio_color)
		# Gene Fragments icon: bioluminescent circle with inner glow
		var gen_color: Color = Color(0.7, 0.4, 1.0)
		if low_gen:
			gen_color = Color(1.0, 0.4, 0.3).lerp(Color(0.7, 0.4, 1.0), warn_pulse)
		draw_circle(Vector2(220, 20), 8, Color(0.25, 0.1, 0.35, 0.5))
		draw_circle(Vector2(220, 20), 6, Color(0.7, 0.3, 1.0, 0.8))
		draw_circle(Vector2(220, 20), 3, Color(0.85, 0.5, 1.0, 0.3 + 0.15 * sin(_time * 3.0 + 1.0)))
		if low_gen:
			draw_arc(Vector2(220, 20), 10.0, 0, TAU, 16, Color(1.0, 0.3, 0.2, 0.5 * warn_pulse), 1.5)
		draw_string(font, Vector2(232, 27), "Genes: %d" % genes, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, gen_color)
		# Income rate (genes)
		var inc_gen_text: String = "+%d/s" % _income_genes if _income_genes >= 0 else "%d/s" % _income_genes
		var inc_gen_color: Color = Color(0.55, 0.3, 0.75, 0.7) if _income_genes >= 0 else Color(0.9, 0.3, 0.3, 0.7)
		var gen_w: float = font.get_string_size("Genes: %d" % genes, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY).x
		draw_string(mono, Vector2(232 + gen_w + 6, 27), inc_gen_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, inc_gen_color)

	# Population - organic supply tube visualization
	if _stage and _stage.has_method("get_faction_manager"):
		var fm: Node = _stage.get_faction_manager()
		var used: int = fm.get_supply_used(0)
		var cap: int = fm.get_supply_cap(0)
		var pop_col: Color = UIConstants.STAT_GREEN if used < cap else UIConstants.STAT_RED
		# Draw organic tube (vertical fluid level)
		var tube_x: float = 400.0
		var tube_w: float = 12.0
		var tube_h: float = 28.0
		var tube_y: float = 6.0
		var fill_ratio: float = float(used) / maxf(float(cap), 1.0)
		# Tube background
		draw_rect(Rect2(tube_x, tube_y, tube_w, tube_h), Color(0.05, 0.08, 0.05, 0.6))
		# Fluid fill (bottom-up)
		var fill_h: float = tube_h * clampf(fill_ratio, 0.0, 1.0)
		if fill_h > 0:
			var fluid_top: Color = pop_col.lightened(0.3)
			var fluid_bot: Color = pop_col.darkened(0.2)
			draw_rect(Rect2(tube_x, tube_y + tube_h - fill_h, tube_w, fill_h * 0.5), fluid_top, true)
			draw_rect(Rect2(tube_x, tube_y + tube_h - fill_h * 0.5, tube_w, fill_h * 0.5), fluid_bot, true)
			# Bubble at top of fluid
			var bubble_y: float = tube_y + tube_h - fill_h + 2.0
			if bubble_y > tube_y + 2.0:
				draw_circle(Vector2(tube_x + tube_w * 0.5, bubble_y), 1.5, Color(1, 1, 1, 0.25 + 0.1 * sin(_time * 4.0)))
		# Tube border
		_draw_membrane_border(Rect2(tube_x - 1, tube_y - 1, tube_w + 2, tube_h + 2), pop_col.darkened(0.3), 0.5, 16.0)
		# Pop text next to tube
		draw_string(font, Vector2(tube_x + tube_w + 6, 27), "Pop: %d/%d" % [used, cap], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, pop_col)

	# === INCOME SPARKLINE GRAPH (next to income rates) ===
	_draw_income_sparkline(vp, mono)

	# === IDLE WORKER COUNTER (after Population) ===
	_draw_idle_worker_counter(vp, font, mono)

	# === GAME TIMER (top center) ===
	_draw_game_timer(vp, font)

	# === DIFFICULTY INDICATOR (right of timer) ===
	_draw_difficulty_indicator(vp, font)

	# === GAME SPEED SLIDER (top right) ===
	_draw_speed_slider(vp, font)

	# === BOTTOM BAR ===
	draw_rect(Rect2(0, vp.y - 120, vp.x, 120), Color(UIConstants.BG_DARK.r, UIConstants.BG_DARK.g, UIConstants.BG_DARK.b, 0.85))
	draw_line(Vector2(0, vp.y - 120), Vector2(vp.x, vp.y - 120), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)

	# === COMMAND BUTTONS (bottom right, evolved 3x4 grid) ===
	_draw_command_buttons(vp, font)

	# === BUILD MENU (if open) ===
	if _build_menu_open:
		_draw_build_menu(vp, font, mono)

	# === COMMAND MODE INDICATOR ===
	if _command_sys and _command_sys.current_mode != _command_sys.CommandMode.NORMAL:
		var mode_text: String = ""
		match _command_sys.current_mode:
			_command_sys.CommandMode.ATTACK_MOVE: mode_text = "ATTACK MOVE - Click target"
			_command_sys.CommandMode.PATROL: mode_text = "PATROL - Click two points"
			_command_sys.CommandMode.BUILD: mode_text = "PLACE BUILDING - Click to build"
		var ts: Vector2 = font.get_string_size(mode_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
		draw_rect(Rect2(vp.x * 0.5 - ts.x * 0.5 - 10, 50, ts.x + 20, 30), Color(0.1, 0.1, 0.1, 0.8))
		draw_string(font, Vector2(vp.x * 0.5 - ts.x * 0.5, 72), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, UIConstants.STAT_YELLOW)

	# === THREAT ALERTS (screen-edge indicators) ===
	_draw_threat_alerts(vp, font)

	# === EVENT ANNOUNCEMENT (center screen) ===
	_draw_event_announcement(vp, font)

	# === SURRENDER BUTTON (top-right) ===
	_draw_surrender_button(vp, font)

	# === MAP PINGS (screen-space indicators) ===
	_draw_map_pings(vp, font)

	# === UNIT STACK COUNTS (world-space badges) ===
	_draw_unit_stack_counts(vp, font)

	# === TOOLTIP (always last - on top of everything) ===
	if _tooltip_text.length() > 0:
		_draw_tooltip(vp, font)

# === IDLE WORKER COUNTER ===

func _draw_idle_worker_counter(vp: Vector2, font: Font, mono: Font) -> void:
	var rect: Rect2 = _get_idle_worker_rect(vp)
	var hovered: bool = rect.has_point(get_local_mouse_position())
	# Background (subtle, clickable feel on hover)
	var bg_alpha: float = 0.5 if hovered else 0.3
	draw_rect(rect, Color(0.1, 0.12, 0.2, bg_alpha))
	if hovered:
		draw_rect(rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), false, 1.0)
	# Idle worker icon: small circle with "!" inside
	var icon_center: Vector2 = Vector2(rect.position.x + 14, rect.position.y + 16)
	var icon_color: Color = UIConstants.STAT_YELLOW if _idle_worker_count > 0 else UIConstants.TEXT_DIM
	draw_circle(icon_center, 8, Color(icon_color.r, icon_color.g, icon_color.b, 0.3))
	draw_arc(icon_center, 8, 0, TAU, 24, icon_color, 1.5)
	# "!" inside
	draw_string(mono, Vector2(icon_center.x - 3, icon_center.y + 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, icon_color)
	# Count text
	var count_color: Color = UIConstants.STAT_YELLOW if _idle_worker_count > 0 else UIConstants.TEXT_DIM
	draw_string(font, Vector2(rect.position.x + 28, rect.position.y + 22), "Idle: %d" % _idle_worker_count, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, count_color)

# === GAME TIMER ===

func _draw_game_timer(vp: Vector2, font: Font) -> void:
	var elapsed: float = _get_game_time()
	var minutes: int = int(elapsed) / 60
	var seconds: int = int(elapsed) % 60
	var timer_text: String = "%02d:%02d" % [minutes, seconds]
	var ts: Vector2 = font.get_string_size(timer_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_BODY)
	var tx: float = vp.x * 0.5 - ts.x * 0.5
	draw_string(font, Vector2(tx, 27), timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY, UIConstants.TEXT_NORMAL)

# === DIFFICULTY INDICATOR ===

func _draw_difficulty_indicator(vp: Vector2, font: Font) -> void:
	var rect: Rect2 = _get_difficulty_rect(vp)
	var hovered: bool = rect.has_point(get_local_mouse_position())
	var diff_name: String = DIFFICULTY_NAMES[_ai_difficulty]
	var diff_color: Color = DIFFICULTY_COLORS[_ai_difficulty]
	# Background
	var bg_alpha: float = 0.5 if hovered else 0.3
	draw_rect(rect, Color(0.1, 0.12, 0.2, bg_alpha))
	if hovered:
		draw_rect(rect, Color(diff_color.r, diff_color.g, diff_color.b, 0.35), false, 1.0)
	# Label
	draw_string(font, Vector2(rect.position.x + 4, rect.position.y + 22), diff_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, diff_color)

# === SELECTION INFO (now handled by rts_selection_panel.gd) ===

# === EVOLVED COMMAND CARD (3x4 context-sensitive grid) ===

func _get_active_command_set() -> Array:
	## Returns the correct command set based on current selection context.
	if not _selection_mgr:
		return MILITARY_CMD
	var sel: Array = _selection_mgr.selected_units
	if sel.is_empty():
		return MILITARY_CMD

	# Single building selected — show building commands with production buttons
	if sel.size() == 1:
		var unit: Node2D = sel[0]
		if is_instance_valid(unit) and unit.is_in_group("rts_buildings"):
			return _get_building_command_set(unit)

	# Check if selection is all workers
	var all_workers: bool = true
	var all_military: bool = true
	for unit in sel:
		if not is_instance_valid(unit):
			continue
		if "unit_type" in unit:
			if unit.unit_type == UnitStats.UnitType.WORKER:
				all_military = false
			else:
				all_workers = false
	if all_workers:
		return WORKER_CMD
	return MILITARY_CMD

func _get_building_command_set(building: Node2D) -> Array:
	## Build a dynamic command set for a selected building, with production slots.
	var cmds: Array = BUILDING_CMD.duplicate(true)
	if not is_instance_valid(building):
		return cmds
	# Show construction status if building is incomplete
	if building.has_method("is_complete") and not building.is_complete():
		var pct: float = 0.0
		if "construction_progress" in building and "build_time" in building and building.build_time > 0:
			pct = clampf(building.construction_progress / building.build_time, 0.0, 1.0)
		cmds[2] = {
			"label": "Building...",
			"hotkey": "",
			"tooltip": "Under construction (%d%%). Send a worker to build." % int(pct * 100),
			"action": "",
			"research_progress": pct,
		}
		return cmds
	# Fill production slots starting at index 2
	if "can_produce" in building and building.has_method("is_complete") and building.is_complete():
		var produce_keys: Array = ["1", "2", "3", "4", "5"]
		for i in range(building.can_produce.size()):
			var slot_idx: int = 2 + i
			if slot_idx >= 12:
				break
			var ut: int = building.can_produce[i]
			var uname: String = UnitStats.get_unit_name(ut)
			var cost: Dictionary = UnitStats.get_cost(ut)
			var hotkey: String = produce_keys[i] if i < produce_keys.size() else ""
			cmds[slot_idx] = {
				"label": uname,
				"hotkey": hotkey,
				"tooltip": "%s (%dB / %dG)" % [uname, cost.get("biomass", 0), cost.get("genes", 0)],
				"action": "produce",
				"produce_idx": i,
			}
	# Research slot (if Evolution Chamber)
	if "building_type" in building and building.building_type == BuildingStats.BuildingType.EVOLUTION_CHAMBER:
		if building.has_method("is_researching") and building.is_researching():
			var res_name: String = building.get_current_research_name() if building.has_method("get_current_research_name") else "Research"
			var res_pct: float = building.get_research_progress() if building.has_method("get_research_progress") else 0.0
			cmds[9] = {
				"label": res_name,
				"hotkey": "",
				"tooltip": "Researching: %s (%d%%)" % [res_name, int(res_pct * 100)],
				"action": "",
				"research_progress": res_pct,
			}
	return cmds

func _draw_command_buttons(vp: Vector2, font: Font) -> void:
	var active_cmds: Array = _get_active_command_set()
	for i in range(CMD_GRID_COLS * CMD_GRID_ROWS):
		var rect: Rect2 = _get_cmd_btn_rect(vp, i)
		var cmd: Dictionary = active_cmds[i] if i < active_cmds.size() else {}
		var label: String = cmd.get("label", "")
		var hotkey: String = cmd.get("hotkey", "")
		var action: String = cmd.get("action", "")
		var hovered: bool = _hover_btn == i

		if label == "" and action == "":
			# Empty slot — very dim outline
			draw_rect(rect, Color(0.06, 0.08, 0.14, 0.4))
			draw_rect(rect, Color(0.15, 0.2, 0.3, 0.15), false, 0.5)
			continue

		# Dark organic background
		var bg: Color = Color(0.10, 0.18, 0.30, 0.92) if hovered else Color(0.06, 0.10, 0.20, 0.88)
		draw_rect(rect, bg)

		# Membrane border
		var border_color: Color = Color(0.4, 0.85, 1.0, 0.8) if hovered else Color(0.2, 0.45, 0.6, 0.45)
		draw_rect(rect, border_color, false, 1.0)

		# Bioluminescent glow on hover
		if hovered:
			draw_rect(rect.grow(2), Color(0.3, 0.8, 1.0, 0.08))
			# Animated scan line
			var scan_x: float = fmod(_time * 60.0, rect.size.x)
			draw_line(Vector2(rect.position.x + scan_x, rect.position.y + 1), Vector2(rect.position.x + scan_x, rect.position.y + rect.size.y - 1), Color(0.4, 0.9, 1.0, 0.12), 1.0)

		# Hotkey letter (small, top-left, cyan)
		if hotkey.length() > 0:
			draw_string(font, Vector2(rect.position.x + 3, rect.position.y + 11), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.3, 0.9, 1.0, 0.7))

		# Command name (center)
		var tc: Color = UIConstants.BTN_TEXT_HOVER if hovered else UIConstants.BTN_TEXT
		var label_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY)
		var label_x: float = rect.position.x + (rect.size.x - label_size.x) * 0.5
		var label_y: float = rect.position.y + rect.size.y * 0.5 + 4.0
		draw_string(font, Vector2(label_x, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, tc)

		# Ability cooldown radial sweep overlay
		if action == "ability" and _selection_mgr:
			_draw_ability_cooldown_overlay(rect)

		# Research progress bar overlay
		if cmd.has("research_progress"):
			var rpct: float = cmd.get("research_progress", 0.0)
			var fill_w: float = rect.size.x * rpct
			draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - 3, fill_w, 3), Color(0.55, 0.2, 0.85, 0.7))

func _draw_ability_cooldown_overlay(rect: Rect2) -> void:
	## Draw a radial cooldown sweep on the command button for the selected unit's ability.
	var sel: Array = _selection_mgr.selected_units
	if sel.is_empty():
		return
	# Use the first selected unit's cooldown
	var unit: Node2D = sel[0]
	if not is_instance_valid(unit):
		return
	if not "_ability_cooldown_timer" in unit or not "_ability_cooldown_max" in unit:
		return
	if unit._ability_cooldown_max <= 0:
		return
	var cd_progress: float = 1.0 - (unit._ability_cooldown_timer / unit._ability_cooldown_max)
	if cd_progress >= 1.0:
		# Ready - pulsing border
		var pulse: float = 0.3 + 0.2 * sin(_time * 4.0)
		draw_rect(rect, Color(0.3, 1.0, 0.5, pulse), false, 1.5)
		return
	if cd_progress < 0.01:
		return
	# Draw dark overlay on the cooldown portion
	var overlay_h: float = rect.size.y * (1.0 - cd_progress)
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, overlay_h), Color(0.0, 0.0, 0.0, 0.45))

# === BUILD MENU ===

func _draw_build_menu(vp: Vector2, font: Font, mono: Font) -> void:
	# Background panel
	var panel_rect: Rect2 = Rect2(vp.x - 360, vp.y - 260, 145, BUILD_BUTTONS.size() * 40 + 10)
	draw_rect(panel_rect, Color(UIConstants.BG_DARK.r, UIConstants.BG_DARK.g, UIConstants.BG_DARK.b, 0.95))
	draw_rect(panel_rect, UIConstants.BTN_BORDER, false, 1.5)
	draw_string(font, Vector2(panel_rect.position.x + 10, panel_rect.position.y - 4), "BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_TITLE)

	for i in range(BUILD_BUTTONS.size()):
		var rect: Rect2 = _get_build_btn_rect(vp, i)
		var hovered: bool = _hover_build == i
		var bg: Color = UIConstants.BTN_BG_HOVER if hovered else UIConstants.BTN_BG
		draw_rect(rect, bg)
		draw_rect(rect, UIConstants.BTN_BORDER if not hovered else UIConstants.BTN_BORDER_HOVER, false, 1.0)
		var bname: String = BuildingStats.get_building_name(BUILD_BUTTONS[i].type)
		var cost: Dictionary = BuildingStats.get_cost(BUILD_BUTTONS[i].type)
		var label: String = "[%s] %s" % [BUILD_BUTTONS[i].key, bname]
		var tc: Color = UIConstants.BTN_TEXT_HOVER if hovered else UIConstants.BTN_TEXT
		draw_string(font, Vector2(rect.position.x + 6, rect.position.y + 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, tc)
		var cost_str: String = "%dB %dG" % [cost.get("biomass", 0), cost.get("genes", 0)]
		draw_string(mono, Vector2(rect.position.x + 6, rect.position.y + 30), cost_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, UIConstants.TEXT_DIM)

# === SPEED SLIDER ===

func _draw_speed_slider(vp: Vector2, font: Font) -> void:
	var sr: Rect2 = _get_speed_slider_rect(vp)
	# Label
	draw_string(font, Vector2(sr.position.x - 50, sr.position.y + 16), "Speed", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_DIM)
	# Track
	draw_rect(sr, Color(0.08, 0.1, 0.15, 0.9))
	draw_rect(sr, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), false, 1.0)
	# Fill
	var t: float = clampf((_game_speed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), 0.0, 1.0)
	var fill_w: float = sr.size.x * t
	var fill_color: Color = UIConstants.STAT_GREEN if _game_speed <= 1.1 else UIConstants.STAT_YELLOW if _game_speed <= 1.6 else UIConstants.STAT_RED
	draw_rect(Rect2(sr.position.x, sr.position.y, fill_w, sr.size.y), Color(fill_color.r, fill_color.g, fill_color.b, 0.4))
	# Thumb
	var thumb_x: float = sr.position.x + fill_w
	draw_rect(Rect2(thumb_x - 3, sr.position.y - 2, 6, sr.size.y + 4), fill_color)
	# Value text
	var speed_text: String = "%dx" % int(_game_speed) if is_equal_approx(_game_speed, roundf(_game_speed)) else "%.1fx" % _game_speed
	draw_string(font, Vector2(sr.position.x + sr.size.x + 8, sr.position.y + 16), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, fill_color)

# === TOOLTIP ===

func _draw_tooltip(vp: Vector2, font: Font) -> void:
	var lines: PackedStringArray = _tooltip_text.split("\n")
	var max_w: float = 0.0
	for line in lines:
		var lw: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION).x
		if lw > max_w:
			max_w = lw
	var line_h: float = 16.0
	var pad: float = 8.0
	var tw: float = max_w + pad * 2
	var th: float = lines.size() * line_h + pad * 2
	var tx: float = _tooltip_pos.x + 15
	var ty: float = _tooltip_pos.y + 10
	# Clamp to screen edges
	if tx + tw > vp.x - 4:
		tx = vp.x - tw - 4
	if ty + th > vp.y - 4:
		ty = vp.y - th - 4
	if tx < 4:
		tx = 4
	if ty < 4:
		ty = 4
	var tooltip_rect: Rect2 = Rect2(tx, ty, tw, th)
	# Dark background
	draw_rect(tooltip_rect, Color(0.04, 0.05, 0.1, 0.95))
	# 1px border
	draw_rect(tooltip_rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.6), false, 1.0)
	# Text lines
	for i in range(lines.size()):
		draw_string(font, Vector2(tx + pad, ty + pad + (i + 1) * line_h - 2), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_BRIGHT)

# === MEMBRANE BORDER UTILITY ===

func _draw_membrane_border(rect: Rect2, color: Color, amplitude: float = 2.0, freq: float = 8.0) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 60
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
		draw_line(points[i], points[i + 1], color, 1.5, true)

# === ORGANIC RESOURCE BAR ===

func _draw_organic_bar(pos: Vector2, width: float, height: float, fill: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(width, height)), Color(0.05, 0.08, 0.05, 0.6), true)
	var fill_w: float = width * clampf(fill, 0.0, 1.0)
	if fill_w > 0:
		var top_color: Color = color.lightened(0.3)
		var bot_color: Color = color.darkened(0.2)
		draw_rect(Rect2(pos, Vector2(fill_w, height * 0.5)), top_color, true)
		draw_rect(Rect2(pos + Vector2(0, height * 0.5), Vector2(fill_w, height * 0.5)), bot_color, true)
		var bubble_x: float = pos.x + fill_w - 3.0
		if bubble_x > pos.x:
			draw_circle(Vector2(bubble_x, pos.y + height * 0.3), 1.5, Color(1, 1, 1, 0.3 + 0.1 * sin(_time * 5.0)))
	_draw_membrane_border(Rect2(pos - Vector2(1, 1), Vector2(width + 2, height + 2)), color.darkened(0.3), 1.0, 12.0)

# === THREAT ALERTS ===

func _draw_threat_alerts(vp: Vector2, font: Font) -> void:
	_threat_edge_positions.clear()
	if not _threat_detector:
		return
	var threats: Array = _threat_detector.get_active_threats()
	for threat in threats:
		var screen_center: Vector2 = vp * 0.5
		var camera: Camera2D = get_viewport().get_camera_2d()
		if not camera:
			continue
		var cam_pos: Vector2 = camera.global_position
		var dir: Vector2 = (threat["pos"] - cam_pos).normalized()
		var edge_pos: Vector2 = _clamp_to_screen_edge(screen_center, dir, vp, 60.0)
		_threat_edge_positions.append({"pos": edge_pos, "threat_pos": threat["pos"]})
		var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
		var alert_color: Color = Color(0.9, 0.15, 0.1, 0.6 + 0.3 * pulse)
		_draw_threat_vein(edge_pos, dir, alert_color)
		draw_circle(edge_pos, 12.0 + 2.0 * pulse, Color(0.8, 0.1, 0.05, 0.4))
		draw_circle(edge_pos, 8.0, alert_color)
		draw_string(font, edge_pos + Vector2(-3, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		if threat["count"] > 1:
			var count_str: String = "%d" % threat["count"]
			draw_string(font, edge_pos + Vector2(10, -4), count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(1, 0.8, 0.7, 0.9))

func _clamp_to_screen_edge(center: Vector2, dir: Vector2, vp: Vector2, margin: float) -> Vector2:
	if dir.length_squared() < 0.001:
		return center
	var half_w: float = vp.x * 0.5 - margin
	var half_h: float = vp.y * 0.5 - margin
	var scale_x: float = absf(half_w / dir.x) if absf(dir.x) > 0.001 else 99999.0
	var scale_y: float = absf(half_h / dir.y) if absf(dir.y) > 0.001 else 99999.0
	var s: float = minf(scale_x, scale_y)
	return center + dir * s

func _draw_threat_vein(pos: Vector2, dir: Vector2, color: Color) -> void:
	var inward: Vector2 = -dir
	var perp: Vector2 = Vector2(-inward.y, inward.x)
	for i in range(3):
		var offset: float = (float(i) - 1.0) * 8.0
		var start: Vector2 = pos + perp * offset
		var length: float = 25.0 + 10.0 * sin(_time * 3.0 + float(i) * 1.5)
		var end_pt: Vector2 = start + inward * length
		var ctrl: Vector2 = (start + end_pt) * 0.5 + perp * sin(_time * 2.0 + float(i)) * 6.0
		var mid: Vector2 = ctrl
		var vein_alpha: float = color.a * (0.7 - float(i) * 0.15)
		var vein_color: Color = Color(color.r, color.g, color.b, vein_alpha)
		draw_line(start, mid, vein_color, 2.0 - float(i) * 0.4, true)
		draw_line(mid, end_pt, Color(vein_color.r, vein_color.g, vein_color.b, vein_alpha * 0.5), 1.5 - float(i) * 0.3, true)

# === EVENT ANNOUNCEMENT ===

func _draw_event_announcement(vp: Vector2, font: Font) -> void:
	if _event_announce_timer <= 0.0 or _event_announcement.is_empty():
		return
	var alpha: float = clampf(_event_announce_timer, 0.0, 1.0)
	var text_size: Vector2 = font.get_string_size(_event_announcement, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_HEADER)
	var box_w: float = text_size.x + 60
	var box_h: float = 50.0
	var box_x: float = vp.x * 0.5 - box_w * 0.5
	var box_y: float = vp.y * 0.35 - box_h * 0.5
	var box_rect: Rect2 = Rect2(box_x, box_y, box_w, box_h)
	draw_rect(box_rect, Color(0.04, 0.05, 0.08, 0.85 * alpha))
	var border_color: Color = Color(_event_announce_color.r, _event_announce_color.g, _event_announce_color.b, 0.6 * alpha)
	_draw_membrane_border(box_rect, border_color, 2.0, 8.0)
	var text_x: float = vp.x * 0.5 - text_size.x * 0.5
	var text_y: float = box_y + box_h * 0.5 + UIConstants.FONT_HEADER * 0.35
	var text_color: Color = Color(_event_announce_color.r, _event_announce_color.g, _event_announce_color.b, alpha)
	draw_string(font, Vector2(text_x, text_y), _event_announcement, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_HEADER, text_color)

# === SURRENDER BUTTON ===

func _draw_surrender_button(vp: Vector2, font: Font) -> void:
	if _surrender_confirm:
		# Draw confirmation dialog in center
		var box_w: float = 300.0
		var box_h: float = 80.0
		var box_x: float = (vp.x - box_w) * 0.5
		var box_y: float = vp.y * 0.4 - box_h * 0.5
		var box_rect: Rect2 = Rect2(box_x, box_y, box_w, box_h)
		draw_rect(box_rect, Color(0.06, 0.04, 0.04, 0.95))
		draw_rect(box_rect, Color(0.9, 0.25, 0.2, 0.6), false, 1.5)
		# Confirmation text
		var confirm_text: String = "Surrender?"
		var cts: Vector2 = font.get_string_size(confirm_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_SUBHEADER)
		draw_string(font, Vector2(box_x + (box_w - cts.x) * 0.5, box_y + 30),
			confirm_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_SUBHEADER, Color(1.0, 0.4, 0.3))
		# Y/N prompt with blink
		var blink: float = 0.6 + 0.4 * sin(_surrender_blink)
		var yn_text: String = "[Y] Yes   [N] No"
		var yns: Vector2 = font.get_string_size(yn_text, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
		draw_string(font, Vector2(box_x + (box_w - yns.x) * 0.5, box_y + 58),
			yn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION,
			Color(UIConstants.TEXT_BRIGHT.r, UIConstants.TEXT_BRIGHT.g, UIConstants.TEXT_BRIGHT.b, blink))
	else:
		# Small surrender label in top-right
		var surr_text: String = "F10: Surrender"
		var surr_x: float = vp.x - 120.0
		var surr_y: float = 55.0
		draw_string(font, Vector2(surr_x, surr_y), surr_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UIConstants.FONT_TINY, Color(0.7, 0.3, 0.3, 0.5))

# === MAP PINGS (screen-space) ===

func _draw_map_pings(vp: Vector2, font: Font) -> void:
	if _map_pings.is_empty():
		return
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return
	var cam_pos: Vector2 = camera.global_position
	var screen_center: Vector2 = vp * 0.5

	for ping in _map_pings:
		var world_pos: Vector2 = ping["pos"]
		var ping_type: int = ping["type"]
		var elapsed: float = ping["time"]
		var alpha: float = 1.0 - (elapsed / PING_LIFE)
		if alpha <= 0.0:
			continue
		var ping_color: Color = PING_COLORS[ping_type]

		# Convert world pos to screen pos
		var zoom: float = camera.zoom.x if camera.zoom.x > 0 else 1.0
		var screen_pos: Vector2 = (world_pos - cam_pos) * zoom + screen_center

		# Clamp to screen edge if off screen (with margin)
		var margin: float = 50.0
		var on_screen: bool = (screen_pos.x > margin and screen_pos.x < vp.x - margin and
			screen_pos.y > margin and screen_pos.y < vp.y - margin)

		var draw_pos: Vector2 = screen_pos
		if not on_screen:
			var dir: Vector2 = (screen_pos - screen_center).normalized()
			draw_pos = _clamp_to_screen_edge(screen_center, dir, vp, margin)

		# Expanding ring animation
		var ring_phase: float = fmod(elapsed * 2.0, 1.0)
		var ring_r: float = 8.0 + ring_phase * 20.0
		var ring_alpha: float = alpha * (1.0 - ring_phase)
		draw_arc(draw_pos, ring_r, 0, TAU, 16,
			Color(ping_color.r, ping_color.g, ping_color.b, ring_alpha * 0.7), 1.5)

		# Second ring offset
		var ring_phase2: float = fmod(elapsed * 2.0 + 0.5, 1.0)
		var ring_r2: float = 8.0 + ring_phase2 * 20.0
		var ring_alpha2: float = alpha * (1.0 - ring_phase2)
		draw_arc(draw_pos, ring_r2, 0, TAU, 16,
			Color(ping_color.r, ping_color.g, ping_color.b, ring_alpha2 * 0.4), 1.0)

		# Core dot
		draw_circle(draw_pos, 4.0, Color(ping_color.r, ping_color.g, ping_color.b, alpha * 0.8))

		# Type-specific icon
		match ping_type:
			PING_DANGER:
				# X shape
				var sz: float = 5.0
				draw_line(draw_pos + Vector2(-sz, -sz), draw_pos + Vector2(sz, sz),
					Color(ping_color.r, ping_color.g, ping_color.b, alpha), 2.0)
				draw_line(draw_pos + Vector2(sz, -sz), draw_pos + Vector2(-sz, sz),
					Color(ping_color.r, ping_color.g, ping_color.b, alpha), 2.0)
			PING_ASSIST:
				# ! exclamation
				draw_string(font, draw_pos + Vector2(-3, -8), "!",
					HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_BODY,
					Color(ping_color.r, ping_color.g, ping_color.b, alpha))
			PING_OMW:
				# > arrow pointing right-ish toward center
				var arr_dir: Vector2 = (screen_center - draw_pos).normalized() if not on_screen else Vector2(1, 0)
				var perp: Vector2 = Vector2(-arr_dir.y, arr_dir.x)
				var tip: Vector2 = draw_pos + arr_dir * 8.0
				var base1: Vector2 = draw_pos - arr_dir * 4.0 + perp * 5.0
				var base2: Vector2 = draw_pos - arr_dir * 4.0 - perp * 5.0
				draw_line(base1, tip, Color(ping_color.r, ping_color.g, ping_color.b, alpha), 1.5)
				draw_line(base2, tip, Color(ping_color.r, ping_color.g, ping_color.b, alpha), 1.5)

# === UNIT STACK COUNTS ===

func _draw_unit_stack_counts(vp: Vector2, font: Font) -> void:
	if _unit_clusters.is_empty():
		return
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return
	var cam_pos: Vector2 = camera.global_position
	var screen_center: Vector2 = vp * 0.5
	var zoom: float = camera.zoom.x if camera.zoom.x > 0 else 1.0

	for cluster in _unit_clusters:
		var world_pos: Vector2 = cluster["center"]
		var count: int = cluster["count"]
		# Convert world to screen
		var screen_pos: Vector2 = (world_pos - cam_pos) * zoom + screen_center
		# Skip if off-screen
		if screen_pos.x < -20.0 or screen_pos.x > vp.x + 20.0 or screen_pos.y < -20.0 or screen_pos.y > vp.y + 20.0:
			continue
		# Offset badge above cluster center
		var badge_pos: Vector2 = screen_pos + Vector2(0, -18.0)
		var badge_r: float = 9.0
		var count_text: String = str(count)
		# Background circle
		draw_circle(badge_pos, badge_r, Color(0.1, 0.15, 0.25, 0.85))
		# Border
		draw_arc(badge_pos, badge_r, 0, TAU, 16, Color(0.6, 0.85, 1.0, 0.7), 1.0)
		# Number
		var text_size: Vector2 = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY)
		draw_string(font, Vector2(badge_pos.x - text_size.x * 0.5, badge_pos.y + 4), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color.WHITE)

# === INCOME SPARKLINE GRAPH ===

func _draw_income_sparkline(vp: Vector2, mono: Font) -> void:
	if _income_history_bio.size() < 2 and _income_history_gen.size() < 2:
		return
	# Position: below top bar, right-aligned to resource panel
	var graph_x: float = 200.0
	var graph_y: float = 42.0
	var graph_w: float = 80.0
	var graph_h: float = 20.0

	# Background
	draw_rect(Rect2(graph_x, graph_y, graph_w, graph_h), Color(0.04, 0.06, 0.1, 0.7))
	draw_rect(Rect2(graph_x, graph_y, graph_w, graph_h), Color(0.2, 0.3, 0.4, 0.3), false, 0.5)

	# Draw biomass sparkline (green)
	if _income_history_bio.size() >= 2:
		_draw_sparkline(_income_history_bio, graph_x, graph_y, graph_w, graph_h, Color(0.3, 0.9, 0.4, 0.8))
	# Draw genes sparkline (cyan)
	if _income_history_gen.size() >= 2:
		_draw_sparkline(_income_history_gen, graph_x, graph_y, graph_w, graph_h, Color(0.5, 0.7, 1.0, 0.8))

func _draw_sparkline(data: Array, x: float, y: float, w: float, h: float, color: Color) -> void:
	if data.size() < 2:
		return
	# Find value range
	var min_val: float = 0.0
	var max_val: float = 1.0
	for val in data:
		if val < min_val:
			min_val = val
		if val > max_val:
			max_val = val
	var val_range: float = maxf(max_val - min_val, 1.0)
	# Draw line segments
	var step_x: float = w / float(data.size() - 1)
	var prev_point: Vector2 = Vector2.ZERO
	for i in range(data.size()):
		var px: float = x + float(i) * step_x
		var normalized: float = clampf((float(data[i]) - min_val) / val_range, 0.0, 1.0)
		var py: float = y + h - normalized * (h - 2.0) - 1.0
		var point: Vector2 = Vector2(px, py)
		if i > 0:
			draw_line(prev_point, point, color, 1.0, true)
		prev_point = point
	# End dot
	draw_circle(prev_point, 1.5, color)

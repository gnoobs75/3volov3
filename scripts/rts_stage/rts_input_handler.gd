extends Control
## Routes mouse/keyboard input to selection and commands.
## Draws drag selection rectangle.

var _selection_mgr: Node = null
var _command_sys: Node = null
var _camera: Camera2D = null
var _stage: Node = null
var _build_ghost: Node2D = null

var _drag_rect_visible: bool = false
var _drag_rect: Rect2 = Rect2()

# Camera bookmarks (Ctrl+F5..F8 to save, F5..F8 to recall)
var _camera_bookmarks: Dictionary = {}  # KEY_F5..F8 -> Vector2

# Formation notification
var _formation_notification: String = ""
var _formation_notify_timer: float = 0.0
const FORMATION_NOTIFY_DURATION: float = 1.5

# Double-click tracking
var _last_click_time: float = 0.0
var _last_click_pos: Vector2 = Vector2.ZERO
const DOUBLE_CLICK_TIME: float = 0.35
const DOUBLE_CLICK_DIST: float = 20.0

func setup(sel: Node, cmd: Node, cam: Camera2D, stage: Node) -> void:
	_selection_mgr = sel
	_command_sys = cmd
	_camera = cam
	_stage = stage
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if _formation_notify_timer > 0:
		_formation_notify_timer -= delta
		queue_redraw()

func _get_world_mouse_pos() -> Vector2:
	if not _camera:
		return Vector2.ZERO
	return _camera.get_global_mouse_position()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _command_sys.current_mode == _command_sys.CommandMode.BUILD:
				_try_place_building()
			elif _command_sys.current_mode == _command_sys.CommandMode.PATROL:
				var world_pos: Vector2 = _get_world_mouse_pos()
				_command_sys.handle_patrol_click(world_pos, _selection_mgr.selected_units)
			else:
				# Check for double-click before starting drag
				var now: float = Time.get_ticks_msec() / 1000.0
				var dt: float = now - _last_click_time
				if dt < DOUBLE_CLICK_TIME and event.position.distance_to(_last_click_pos) < DOUBLE_CLICK_DIST:
					# Double-click: select all units of same type on screen
					_handle_double_click()
					_last_click_time = 0.0  # Reset to prevent triple-click
				else:
					_last_click_time = now
					_last_click_pos = event.position
					_selection_mgr.start_drag(event.position)
		else:
			# Release
			if _selection_mgr.is_dragging():
				_selection_mgr.end_drag(_camera)
				_drag_rect_visible = false
				queue_redraw()
			else:
				# Single click select
				_try_select_at_mouse(event.shift_pressed)

	# Scroll wheel during build mode — rotate build ghost
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if _build_ghost and is_instance_valid(_build_ghost) and _build_ghost.has_method("rotate_ghost"):
			_build_ghost.rotate_ghost()
			return

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if _command_sys.current_mode != _command_sys.CommandMode.NORMAL:
				_command_sys.exit_special_mode()
				_remove_build_ghost()
			else:
				_handle_right_click(event.shift_pressed)

func _handle_double_click() -> void:
	## Select all player units/buildings of the same type as the one under cursor (on screen)
	if not _selection_mgr or not _camera:
		return
	var world_pos: Vector2 = _get_world_mouse_pos()

	# Check units first
	var best_unit: Node2D = null
	var best_dist: float = 25.0
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id != 0:
			continue
		var dist: float = world_pos.distance_to(unit.global_position)
		if dist < best_dist:
			best_dist = dist
			best_unit = unit
	if best_unit and "unit_type" in best_unit:
		_selection_mgr.select_all_of_type(best_unit.unit_type, _camera)
		return

	# Check buildings if no unit found
	var best_building: Node2D = null
	var best_building_dist: float = 40.0
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if "faction_id" in building and building.faction_id != 0:
			continue
		var dist: float = world_pos.distance_to(building.global_position)
		if dist < best_building_dist:
			best_building_dist = dist
			best_building = building
	if best_building and "building_type" in best_building:
		_selection_mgr.select_all_buildings_of_type(best_building.building_type, _camera)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _command_sys.current_mode == _command_sys.CommandMode.NORMAL:
		_selection_mgr.update_drag(event.position)
		if _selection_mgr.is_dragging():
			_drag_rect_visible = true
			_drag_rect = _selection_mgr.get_drag_rect()
			queue_redraw()

	# Update build ghost position (grid snap unless Shift held)
	if _build_ghost and is_instance_valid(_build_ghost):
		var ghost_pos: Vector2 = _get_world_mouse_pos()
		if not Input.is_key_pressed(KEY_SHIFT):
			ghost_pos = Vector2(roundf(ghost_pos.x / 40.0) * 40.0, roundf(ghost_pos.y / 40.0) * 40.0)
		_build_ghost.global_position = ghost_pos

func _try_select_at_mouse(add_to_selection: bool) -> void:
	var world_pos: Vector2 = _get_world_mouse_pos()
	var best_unit: Node2D = null
	var best_dist: float = 25.0  # Click radius

	# Check player units first
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id != 0:
			continue
		var dist: float = world_pos.distance_to(unit.global_position)
		if dist < best_dist:
			best_dist = dist
			best_unit = unit

	if best_unit:
		_selection_mgr.select_unit(best_unit, add_to_selection)
		return

	# Check player buildings if no unit found
	var best_building: Node2D = null
	var best_building_dist: float = 40.0  # Larger click radius for buildings
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if "faction_id" in building and building.faction_id != 0:
			continue
		var dist: float = world_pos.distance_to(building.global_position)
		if dist < best_building_dist:
			best_building_dist = dist
			best_building = building

	if best_building:
		_selection_mgr.select_unit(best_building, add_to_selection)
	elif not add_to_selection:
		_selection_mgr.deselect_all()

func _handle_right_click(shift_held: bool = false) -> void:
	# Block commands in spectator mode
	if _stage and _stage.has_method("is_spectator_mode") and _stage.is_spectator_mode():
		return
	if _selection_mgr.selected_units.is_empty():
		return

	var world_pos: Vector2 = _get_world_mouse_pos()

	# Check if clicking on an enemy unit (attack)
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id == 0:
			continue
		if world_pos.distance_to(unit.global_position) < 25.0:
			if shift_held:
				_queue_command_to_selected({"type": "attack", "target_node": unit})
			else:
				_command_sys.issue_attack(_selection_mgr.selected_units, unit)
			return

	# Check if clicking on enemy building (attack)
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if "faction_id" in building and building.faction_id == 0:
			continue
		if world_pos.distance_to(building.global_position) < 40.0:
			if shift_held:
				_queue_command_to_selected({"type": "attack", "target_node": building})
			else:
				_command_sys.issue_attack(_selection_mgr.selected_units, building)
			return

	# Check if clicking on own building (select production / deposit at depot)
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if not ("faction_id" in building and building.faction_id == 0):
			continue
		if world_pos.distance_to(building.global_position) < 40.0:
			# Own building clicked
			# Repair: if workers selected and building is damaged, send workers to repair
			if _selection_mgr.has_selected_workers() and "health" in building and "max_health" in building and building.health < building.max_health:
				var repair_workers: Array = _selection_mgr.get_selected_workers()
				if shift_held:
					for worker in repair_workers:
						if is_instance_valid(worker) and worker.has_method("queue_command"):
							worker.queue_command({"type": "repair", "target_node": building})
				else:
					_command_sys.issue_repair(repair_workers, building)
				return
			if "is_depot" in building and building.is_depot and _selection_mgr.has_selected_workers():
				# Send selected workers to deposit at this depot
				var workers: Array = _selection_mgr.get_selected_workers()
				if shift_held:
					for worker in workers:
						if is_instance_valid(worker) and worker.has_method("queue_command"):
							worker.queue_command({"type": "move", "target_pos": building.global_position})
				else:
					for i in range(workers.size()):
						var worker: Node2D = workers[i]
						if is_instance_valid(worker) and worker.has_method("command_move"):
							# Slight offset so workers don't stack
							var angle: float = TAU * float(i) / float(maxi(workers.size(), 1))
							var offset: Vector2 = Vector2(cos(angle), sin(angle)) * 15.0
							worker.command_move(building.global_position + offset)
				AudioManager.play_rts_command()
				return
			elif "is_production" in building and building.is_production:
				# Select the production building (so player can queue units via HUD)
				_selection_mgr.deselect_all()
				# Buildings aren't in rts_units, but we can still let the HUD know
				# For now, set rally point if a rally point command is pending
				# Otherwise just select the building for the HUD
				if building.has_method("queue_unit"):
					_command_sys.issue_set_rally_point(building, world_pos)
				return
			return

	# Check if clicking on a resource (gather with workers)
	if _selection_mgr.has_selected_workers():
		for res in get_tree().get_nodes_in_group("rts_resources"):
			if not is_instance_valid(res):
				continue
			if res.has_method("is_depleted") and res.is_depleted():
				continue
			if world_pos.distance_to(res.global_position) < 50.0:
				var workers: Array = _selection_mgr.get_selected_workers()
				if shift_held:
					for worker in workers:
						if is_instance_valid(worker) and worker.has_method("queue_command"):
							worker.queue_command({"type": "gather", "target_node": res})
				else:
					# Send ALL selected workers with slight position offsets
					_command_sys.issue_gather(workers, res)
				AudioManager.play_rts_command()
				return

	# If selection contains buildings, set rally point on all selected buildings
	var selected_buildings: Array = _selection_mgr.selected_units.filter(func(u):
		return is_instance_valid(u) and u.is_in_group("rts_buildings")
	)
	if not selected_buildings.is_empty():
		for bld in selected_buildings:
			if bld.has_method("set_rally_point"):
				bld.set_rally_point(world_pos)
		AudioManager.play_rts_command()
		return

	# Default: move
	if _command_sys.current_mode == _command_sys.CommandMode.ATTACK_MOVE:
		if shift_held:
			_queue_command_to_selected({"type": "attack_move", "target_pos": world_pos}, true)
		else:
			_command_sys.issue_attack_move(_selection_mgr.selected_units, world_pos)
			_command_sys.exit_special_mode()
	else:
		if shift_held:
			_queue_command_to_selected({"type": "move", "target_pos": world_pos}, false)
		else:
			_command_sys.issue_move(_selection_mgr.selected_units, world_pos)

func _queue_command_to_selected(cmd: Dictionary, is_attack_move: bool = false) -> void:
	## Queue a command to all selected units (shift-queue).
	for unit in _selection_mgr.selected_units:
		if is_instance_valid(unit) and unit.has_method("queue_command"):
			unit.queue_command(cmd.duplicate())
	AudioManager.play_rts_command()
	# Update waypoint chain VFX
	_update_waypoint_chains(is_attack_move)

func _update_waypoint_chains(is_attack_move: bool) -> void:
	## Build waypoint position arrays from unit command queues and send to VFX.
	var vfx: Node2D = _stage.get_command_vfx() if _stage and _stage.has_method("get_command_vfx") else null
	if not vfx:
		return
	for unit in _selection_mgr.selected_units:
		if not is_instance_valid(unit) or not "_command_queue" in unit:
			continue
		var positions: Array = []
		for cmd in unit._command_queue:
			if cmd.has("target_pos"):
				positions.append(cmd["target_pos"])
			elif cmd.has("target_node") and is_instance_valid(cmd["target_node"]):
				positions.append(cmd["target_node"].global_position)
		if not positions.is_empty():
			vfx.add_waypoint_chain(unit, positions, is_attack_move)

func _try_place_building() -> void:
	if not _build_ghost or not is_instance_valid(_build_ghost):
		_command_sys.exit_special_mode()
		return
	if not _build_ghost.is_valid_placement():
		return
	# Create the actual building
	if _stage and _stage.has_method("place_building"):
		_stage.place_building(_build_ghost.building_type, _build_ghost.global_position)
	_remove_build_ghost()
	_command_sys.exit_special_mode()

func _remove_build_ghost() -> void:
	if _build_ghost and is_instance_valid(_build_ghost):
		_build_ghost.queue_free()
		_build_ghost = null

func enter_build_mode(building_type: int) -> void:
	_remove_build_ghost()
	_command_sys.enter_build_mode(building_type)
	_build_ghost = preload("res://scripts/rts_stage/build_ghost.gd").new()
	_build_ghost.setup(building_type, 0)
	_build_ghost.global_position = _get_world_mouse_pos()
	# Add to world layer, not HUD
	if _stage:
		_stage.add_child(_build_ghost)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Hotkeys
		if event.keycode == KEY_ESCAPE:
			if _command_sys.current_mode != _command_sys.CommandMode.NORMAL:
				_command_sys.exit_special_mode()
				_remove_build_ghost()
				get_viewport().set_input_as_handled()
			elif not _selection_mgr.selected_units.is_empty():
				_selection_mgr.deselect_all()
				get_viewport().set_input_as_handled()
			# else: let ESC fall through to stage manager for pause menu
			return

		# Period key (.) — find and select next idle worker
		if event.keycode == KEY_PERIOD:
			var idle_worker: Node2D = _selection_mgr.find_next_idle_worker()
			if idle_worker:
				_selection_mgr.select_unit(idle_worker, false)
				# Center camera on the idle worker
				if _camera and _camera.has_method("focus_position"):
					_camera.focus_position(idle_worker.global_position)
			get_viewport().set_input_as_handled()
			return

		# Comma key (,) — find and select next idle military unit
		if event.keycode == KEY_COMMA:
			_selection_mgr.select_idle_military()
			# Center camera on selected unit
			if not _selection_mgr.selected_units.is_empty():
				var sel: Node2D = _selection_mgr.selected_units[0]
				if is_instance_valid(sel) and _camera and _camera.has_method("focus_position"):
					_camera.focus_position(sel.global_position)
			get_viewport().set_input_as_handled()
			return

		# Ctrl+Shift+A — select ALL player units (including workers)
		if event.keycode == KEY_A and event.ctrl_pressed and event.shift_pressed:
			_selection_mgr.select_all_on_screen(_camera)
			get_viewport().set_input_as_handled()
			return

		# Ctrl+A — select all military (non-worker) units
		if event.keycode == KEY_A and event.ctrl_pressed:
			_selection_mgr.select_all_military()
			get_viewport().set_input_as_handled()
			return

		# Control groups (Ctrl+1-5 assign, Shift+1-5 add, Alt+1-5 steal, 1-5 recall)
		var group_keys: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
		for i in range(group_keys.size()):
			if event.keycode == group_keys[i]:
				if event.ctrl_pressed:
					_selection_mgr.assign_control_group(i + 1)
				elif event.shift_pressed:
					_selection_mgr.add_to_control_group(i + 1)
				elif event.alt_pressed:
					_selection_mgr.steal_control_group(i + 1)
				else:
					_selection_mgr.recall_control_group(i + 1)
				get_viewport().set_input_as_handled()
				return

		# TAB — toggle intel overlay
		if event.keycode == KEY_TAB:
			if _stage and _stage.has_method("toggle_intel_overlay"):
				_stage.toggle_intel_overlay()
			get_viewport().set_input_as_handled()
			return

		# HOME key — snap camera to player base
		if event.keycode == KEY_HOME:
			if _stage and _camera:
				var base_pos: Vector2 = Vector2.ZERO
				for building in get_tree().get_nodes_in_group("rts_buildings"):
					if is_instance_valid(building) and "faction_id" in building and building.faction_id == 0:
						if "is_main_base" in building and building.is_main_base:
							base_pos = building.global_position
							break
				_camera.focus_position(base_pos)
			get_viewport().set_input_as_handled()
			return

		# Camera bookmarks: Ctrl+F5..F8 save, F5..F8 recall
		var bookmark_keys: Array = [KEY_F5, KEY_F6, KEY_F7, KEY_F8]
		for bk in range(bookmark_keys.size()):
			if event.keycode == bookmark_keys[bk]:
				if event.ctrl_pressed:
					# Save current camera position as bookmark
					if _camera:
						_camera_bookmarks[bookmark_keys[bk]] = _camera.global_position
					get_viewport().set_input_as_handled()
					return
				else:
					# Recall saved bookmark
					if bookmark_keys[bk] in _camera_bookmarks and _camera and _camera.has_method("focus_position"):
						_camera.focus_position(_camera_bookmarks[bookmark_keys[bk]])
					get_viewport().set_input_as_handled()
					return

		# Building hotkeys (Q/W/E/R/T/Y) — only when build menu is contextually valid
		# Skip in spectator mode
		if _stage and _stage.has_method("is_spectator_mode") and _stage.is_spectator_mode():
			return
		var build_keys: Array = [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]
		for bi in range(build_keys.size()):
			if event.keycode == build_keys[bi] and not event.ctrl_pressed:
				var bt: int = [BuildingStats.BuildingType.SPAWNING_POOL, BuildingStats.BuildingType.EVOLUTION_CHAMBER, BuildingStats.BuildingType.MEMBRANE_TOWER, BuildingStats.BuildingType.BIO_WALL, BuildingStats.BuildingType.NUTRIENT_PROCESSOR, BuildingStats.BuildingType.SUPPLY_DEPOT][bi]
				enter_build_mode(bt)
				get_viewport().set_input_as_handled()
				return

		# F key — cycle formation (requires 3+ military units selected)
		if event.keycode == KEY_F:
			var military: Array = _selection_mgr.selected_units.filter(func(u):
				return is_instance_valid(u) and "unit_type" in u and u.unit_type != UnitStats.UnitType.WORKER
			)
			if military.size() >= 3:
				var new_formation: int = _command_sys.cycle_formation()
				_formation_notification = "Formation: %s" % RtsFormation.get_formation_name(new_formation)
				_formation_notify_timer = FORMATION_NOTIFY_DURATION
			get_viewport().set_input_as_handled()
			return

		# G key — cycle unit stance (Aggressive=0 → Defensive=1 → Passive=2)
		if event.keycode == KEY_G:
			for unit in _selection_mgr.selected_units:
				if is_instance_valid(unit) and "stance" in unit:
					unit.stance = (unit.stance + 1) % 3
			get_viewport().set_input_as_handled()
			return

		# Ctrl+R or Backspace — retreat selected units
		if event.keycode == KEY_BACKSPACE or (event.keycode == KEY_R and event.ctrl_pressed):
			if _stage and _stage.has_method("is_spectator_mode") and _stage.is_spectator_mode():
				return
			if _command_sys.has_method("issue_retreat"):
				_command_sys.issue_retreat(_selection_mgr.selected_units)
			else:
				# Fallback: set each unit to FLEE state (7)
				for unit in _selection_mgr.selected_units:
					if is_instance_valid(unit) and "state" in unit:
						unit.state = 7  # FLEE
			get_viewport().set_input_as_handled()
			return

		# Delete — salvage selected building
		if event.keycode == KEY_DELETE:
			if _stage and _stage.has_method("is_spectator_mode") and _stage.is_spectator_mode():
				return
			if _selection_mgr.selected_units.size() == 1:
				var sel: Node = _selection_mgr.selected_units[0]
				if is_instance_valid(sel) and sel.is_in_group("rts_buildings"):
					if sel.has_method("salvage"):
						sel.salvage()
						_selection_mgr.deselect_all()
			get_viewport().set_input_as_handled()
			return

		# Command hotkeys (only when not in build mode)
		if _command_sys.current_mode != _command_sys.CommandMode.BUILD:
			if event.keycode == KEY_A and not event.ctrl_pressed:
				_command_sys.enter_attack_move_mode()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_P:
				_command_sys.enter_patrol_mode()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_H:
				_command_sys.issue_hold(_selection_mgr.selected_units)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_S:
				_command_sys.issue_stop(_selection_mgr.selected_units)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_V:
				# Ability hotkey — use selected units' abilities at mouse position
				var world_pos: Vector2 = _get_world_mouse_pos()
				_command_sys.issue_ability(_selection_mgr.selected_units, world_pos)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_B:
				if _selection_mgr.has_selected_workers():
					# Build menu handled by HUD
					pass

func _draw() -> void:
	# Draw drag selection rectangle
	if _drag_rect_visible and _drag_rect.size.length() > 0:
		draw_rect(_drag_rect, Color(0.2, 1.0, 0.3, 0.15))
		draw_rect(_drag_rect, Color(0.2, 1.0, 0.3, 0.6), false, 1.5)

	# Draw formation notification
	if _formation_notify_timer > 0 and _formation_notification.length() > 0:
		var vp: Vector2 = get_viewport_rect().size
		var alpha: float = clampf(_formation_notify_timer / 0.3, 0.0, 1.0)  # Fade out last 0.3s
		var font: Font = ThemeDB.fallback_font
		var cx: float = vp.x * 0.5
		var cy: float = vp.y * 0.82
		var pill_w: float = 200.0
		var pill_h: float = 32.0
		draw_rect(Rect2(cx - pill_w * 0.5, cy - pill_h * 0.5, pill_w, pill_h), Color(0.06, 0.1, 0.18, 0.7 * alpha))
		draw_rect(Rect2(cx - pill_w * 0.5, cy - pill_h * 0.5, pill_w, pill_h), Color(0.3, 0.7, 1.0, 0.4 * alpha), false, 1.0)
		if font:
			draw_string(font, Vector2(cx - pill_w * 0.5 + 10, cy + 5), _formation_notification, HORIZONTAL_ALIGNMENT_CENTER, int(pill_w - 20), 13, Color(0.7, 0.9, 1.0, 0.9 * alpha))

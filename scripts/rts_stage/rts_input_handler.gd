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

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if _command_sys.current_mode != _command_sys.CommandMode.NORMAL:
				_command_sys.exit_special_mode()
				_remove_build_ghost()
			else:
				_handle_right_click()

func _handle_double_click() -> void:
	## Select all player units of the same type as the unit under cursor (on screen)
	if not _selection_mgr or not _camera:
		return
	# Find unit under cursor
	var world_pos: Vector2 = _get_world_mouse_pos()
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

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _command_sys.current_mode == _command_sys.CommandMode.NORMAL:
		_selection_mgr.update_drag(event.position)
		if _selection_mgr.is_dragging():
			_drag_rect_visible = true
			_drag_rect = _selection_mgr.get_drag_rect()
			queue_redraw()

	# Update build ghost position
	if _build_ghost and is_instance_valid(_build_ghost):
		_build_ghost.global_position = _get_world_mouse_pos()

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
	elif not add_to_selection:
		_selection_mgr.deselect_all()

func _handle_right_click() -> void:
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
			_command_sys.issue_attack(_selection_mgr.selected_units, unit)
			return

	# Check if clicking on enemy building (attack)
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if "faction_id" in building and building.faction_id == 0:
			continue
		if world_pos.distance_to(building.global_position) < 40.0:
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
			if "is_depot" in building and building.is_depot and _selection_mgr.has_selected_workers():
				# Send selected workers to deposit at this depot
				var workers: Array = _selection_mgr.get_selected_workers()
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
				# Send ALL selected workers with slight position offsets
				_command_sys.issue_gather(workers, res)
				return

	# Default: move
	if _command_sys.current_mode == _command_sys.CommandMode.ATTACK_MOVE:
		_command_sys.issue_attack_move(_selection_mgr.selected_units, world_pos)
		_command_sys.exit_special_mode()
	else:
		_command_sys.issue_move(_selection_mgr.selected_units, world_pos)

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

		# Ctrl+A — select all military (non-worker) units
		if event.keycode == KEY_A and event.ctrl_pressed:
			_selection_mgr.select_all_military()
			get_viewport().set_input_as_handled()
			return

		# Control groups (Ctrl+1-5 to assign, 1-5 to recall)
		var group_keys: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
		for i in range(group_keys.size()):
			if event.keycode == group_keys[i]:
				if event.ctrl_pressed:
					_selection_mgr.assign_control_group(i + 1)
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

		# Building hotkeys (Q/W/E/R/T) — only when build menu is contextually valid
		var build_keys: Array = [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T]
		for bi in range(build_keys.size()):
			if event.keycode == build_keys[bi]:
				var bt: int = [BuildingStats.BuildingType.SPAWNING_POOL, BuildingStats.BuildingType.EVOLUTION_CHAMBER, BuildingStats.BuildingType.MEMBRANE_TOWER, BuildingStats.BuildingType.BIO_WALL, BuildingStats.BuildingType.NUTRIENT_PROCESSOR][bi]
				enter_build_mode(bt)
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
			elif event.keycode == KEY_B:
				if _selection_mgr.has_selected_workers():
					# Build menu handled by HUD
					pass

func _draw() -> void:
	# Draw drag selection rectangle
	if _drag_rect_visible and _drag_rect.size.length() > 0:
		draw_rect(_drag_rect, Color(0.2, 1.0, 0.3, 0.15))
		draw_rect(_drag_rect, Color(0.2, 1.0, 0.3, 0.6), false, 1.5)

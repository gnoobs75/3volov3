extends Node
## Manages unit selection: click, shift-click, drag-box, control groups.

signal selection_changed(selected_units: Array)

var selected_units: Array = []
var _control_groups: Dictionary = {}  # int -> Array of units
var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_rect: Rect2 = Rect2()

const DRAG_THRESHOLD: float = 8.0

func select_unit(unit: Node2D, add_to_selection: bool = false) -> void:
	if not add_to_selection:
		_deselect_all()
	if unit not in selected_units:
		selected_units.append(unit)
		if "is_selected" in unit:
			unit.is_selected = true
	selection_changed.emit(selected_units)
	AudioManager.play_rts_select()

func select_units(units: Array) -> void:
	_deselect_all()
	for unit in units:
		if "faction_id" in unit and unit.faction_id == 0:  # Only player units
			selected_units.append(unit)
			if "is_selected" in unit:
				unit.is_selected = true
	if not selected_units.is_empty():
		selection_changed.emit(selected_units)
		AudioManager.play_rts_select()

func _deselect_all() -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and "is_selected" in unit:
			unit.is_selected = false
	selected_units.clear()

func deselect_all() -> void:
	_deselect_all()
	selection_changed.emit(selected_units)

func remove_unit(unit: Node2D) -> void:
	## Call when a unit dies to clean up references
	selected_units.erase(unit)
	for key in _control_groups:
		_control_groups[key].erase(unit)

# === DRAG BOX ===

func start_drag(screen_pos: Vector2) -> void:
	_drag_start = screen_pos
	_is_dragging = false

func update_drag(screen_pos: Vector2) -> void:
	if screen_pos.distance_to(_drag_start) > DRAG_THRESHOLD:
		_is_dragging = true
		_drag_rect = Rect2(
			Vector2(minf(_drag_start.x, screen_pos.x), minf(_drag_start.y, screen_pos.y)),
			Vector2(absf(screen_pos.x - _drag_start.x), absf(screen_pos.y - _drag_start.y))
		)

func end_drag(camera: Camera2D) -> bool:
	## Returns true if this was a drag-box selection
	if not _is_dragging:
		return false
	_is_dragging = false
	# Convert screen rect to world rect
	var vp: Viewport = camera.get_viewport()
	var canvas_xform: Transform2D = camera.get_canvas_transform()
	var units_in_box: Array = []
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id != 0:
			continue
		# Convert unit world pos to screen pos
		var screen_pos: Vector2 = canvas_xform * unit.global_position
		if _drag_rect.has_point(screen_pos):
			units_in_box.append(unit)
	if not units_in_box.is_empty():
		select_units(units_in_box)
	return true

func is_dragging() -> bool:
	return _is_dragging

func get_drag_rect() -> Rect2:
	return _drag_rect

# === CONTROL GROUPS ===

func assign_control_group(group_num: int) -> void:
	if selected_units.is_empty():
		return
	_control_groups[group_num] = selected_units.duplicate()

func recall_control_group(group_num: int) -> void:
	if group_num not in _control_groups:
		return
	var group: Array = _control_groups[group_num]
	# Remove dead units
	group = group.filter(func(u): return is_instance_valid(u))
	_control_groups[group_num] = group
	if group.is_empty():
		return
	select_units(group)

# === HELPERS ===

func get_selected_workers() -> Array:
	return selected_units.filter(func(u): return is_instance_valid(u) and "unit_type" in u and u.unit_type == UnitStats.UnitType.WORKER)

func has_selected_workers() -> bool:
	return not get_selected_workers().is_empty()

func get_selected_of_type(unit_type: int) -> Array:
	return selected_units.filter(func(u): return is_instance_valid(u) and "unit_type" in u and u.unit_type == unit_type)

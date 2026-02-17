class_name RtsFormation
## Static utility class for calculating unit formation positions.
## Supports 4 formation types: Spread (default), Line, Box, Wedge.

enum FormationType { SPREAD, LINE, BOX, WEDGE }

const SPACING: float = 30.0

static func get_formation_name(type: int) -> String:
	match type:
		FormationType.SPREAD: return "Spread"
		FormationType.LINE: return "Line"
		FormationType.BOX: return "Box"
		FormationType.WEDGE: return "Wedge"
	return "Unknown"

static func calculate_positions(units: Array, center: Vector2, direction: Vector2, formation: int) -> Array:
	if units.is_empty():
		return []
	if units.size() == 1:
		return [center]
	var dir: Vector2 = direction.normalized() if direction.length() > 0.01 else Vector2(1, 0)
	match formation:
		FormationType.LINE:
			return _calc_line(units, center, dir)
		FormationType.BOX:
			return _calc_box(units, center, dir)
		FormationType.WEDGE:
			return _calc_wedge(units, center, dir)
		_:
			return _calc_spread(units, center)

static func _calc_spread(units: Array, center: Vector2) -> Array:
	## Returns center for all units — natural navigation avoidance handles spacing.
	var positions: Array = []
	for i in range(units.size()):
		positions.append(center)
	return positions

static func _calc_line(units: Array, center: Vector2, dir: Vector2) -> Array:
	## Perpendicular to movement direction. Melee front row, ranged back row.
	var perp: Vector2 = Vector2(-dir.y, dir.x)  # Perpendicular to direction
	# Sort: melee units first, ranged units second
	var melee: Array = []
	var ranged: Array = []
	for unit in units:
		if is_instance_valid(unit) and "unit_type" in unit and unit.unit_type == UnitStats.UnitType.RANGED:
			ranged.append(unit)
		else:
			melee.append(unit)
	var positions: Array = []
	positions.resize(units.size())
	# Place melee in front row (perpendicular line centered on target)
	var melee_count: int = melee.size()
	var melee_offset: float = -float(melee_count - 1) * 0.5 * SPACING
	for i in range(melee_count):
		var idx: int = units.find(melee[i])
		if idx >= 0:
			positions[idx] = center + perp * (melee_offset + float(i) * SPACING)
	# Place ranged in back row (1.5x spacing behind front)
	var ranged_count: int = ranged.size()
	var ranged_offset: float = -float(ranged_count - 1) * 0.5 * SPACING
	var back_offset: Vector2 = -dir * SPACING * 1.5
	for i in range(ranged_count):
		var idx: int = units.find(ranged[i])
		if idx >= 0:
			positions[idx] = center + back_offset + perp * (ranged_offset + float(i) * SPACING)
	return positions

static func _calc_box(units: Array, center: Vector2, dir: Vector2) -> Array:
	## Square grid formation centered on target.
	var count: int = units.size()
	var side: int = ceili(sqrt(float(count)))
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var positions: Array = []
	positions.resize(count)
	var box_spacing: float = 28.0
	var half_w: float = float(side - 1) * 0.5 * box_spacing
	var half_h: float = float(ceili(float(count) / float(side)) - 1) * 0.5 * box_spacing
	for i in range(count):
		var col: int = i % side
		var row: int = i / side
		var x_off: float = float(col) * box_spacing - half_w
		var y_off: float = float(row) * box_spacing - half_h
		positions[i] = center + perp * x_off - dir * y_off
	return positions

static func _calc_wedge(units: Array, center: Vector2, dir: Vector2) -> Array:
	## V-shape with fastest unit at tip. Alternates left/right behind leader.
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	# Sort by speed descending (fastest at tip)
	var sorted_units: Array = units.duplicate()
	sorted_units.sort_custom(func(a, b):
		var sa: float = a.speed if is_instance_valid(a) and "speed" in a else 100.0
		var sb: float = b.speed if is_instance_valid(b) and "speed" in b else 100.0
		return sa > sb
	)
	var positions: Array = []
	positions.resize(units.size())
	var row_spacing: float = SPACING
	var lateral_spacing: float = SPACING * 0.7
	for i in range(sorted_units.size()):
		var idx: int = units.find(sorted_units[i])
		if idx < 0:
			continue
		if i == 0:
			# Tip of the wedge
			positions[idx] = center
		else:
			# Alternate left/right, each row further back
			var row: int = ceili(float(i) / 2.0)  # Row number (1-based)
			var side_sign: float = 1.0 if (i % 2 == 1) else -1.0  # Alternate
			var back: Vector2 = -dir * row_spacing * float(row)
			var lateral: Vector2 = perp * lateral_spacing * float(row) * side_sign
			positions[idx] = center + back + lateral
	return positions

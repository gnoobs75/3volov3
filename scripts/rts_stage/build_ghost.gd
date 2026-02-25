extends Node2D
## Placement preview for building construction. Shows green (valid) or red (invalid).

var building_type: int = BuildingStats.BuildingType.BIO_WALL
var faction_id: int = 0
var _is_valid: bool = true
var _size_radius: float = 30.0
var _time: float = 0.0
var _rotation_angle: float = 0.0

func setup(p_building_type: int, p_faction_id: int) -> void:
	building_type = p_building_type
	faction_id = p_faction_id
	var stats: Dictionary = BuildingStats.get_stats(building_type)
	_size_radius = stats.get("size_radius", 30.0)

func _process(delta: float) -> void:
	_time += delta
	_check_validity()
	queue_redraw()

func _check_validity() -> void:
	_is_valid = true
	# Check resource affordability
	var stage: Node = get_tree().get_first_node_in_group("rts_stage") if get_tree() else null
	if stage and "_resource_manager" in stage:
		var cost: Dictionary = BuildingStats.get_cost(building_type)
		if not stage._resource_manager.can_afford(faction_id, cost.get("biomass", 0), cost.get("genes", 0)):
			_is_valid = false
			return
	# Check map edge (must be > 100u from edge)
	var map_radius: float = 8000.0
	if global_position.length() > map_radius - 100.0:
		_is_valid = false
		return
	# Check map bounds (fallback)
	var map: Node2D = get_tree().get_first_node_in_group("rts_map") if get_tree() else null
	if map and map.has_method("is_within_bounds"):
		if not map.is_within_bounds(global_position):
			_is_valid = false
			return
	# Check overlap with existing buildings (minimum 60u separation)
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		var dist: float = global_position.distance_to(building.global_position)
		var other_radius: float = building.size_radius if "size_radius" in building else 30.0
		var min_dist: float = maxf(_size_radius + other_radius + 5.0, 60.0)
		if dist < min_dist:
			_is_valid = false
			return
	# Check overlap with resource nodes
	for res in get_tree().get_nodes_in_group("rts_resources"):
		if not is_instance_valid(res):
			continue
		var dist: float = global_position.distance_to(res.global_position)
		if dist < _size_radius + 25.0:
			_is_valid = false
			return
	# Check overlap with obstacles
	for obs in get_tree().get_nodes_in_group("rts_obstacles"):
		if not is_instance_valid(obs):
			continue
		var dist: float = global_position.distance_to(obs.global_position)
		if dist < _size_radius + 40.0:
			_is_valid = false
			return
	# Singularity Core: tech gate + max 1 per player
	if building_type == BuildingStats.BuildingType.SINGULARITY_CORE:
		var rts_stage: Node = get_tree().get_first_node_in_group("rts_stage") if get_tree() else null
		if rts_stage and "_tech_tree" in rts_stage and rts_stage._tech_tree:
			if not rts_stage._tech_tree.can_build_singularity(faction_id):
				_is_valid = false
				return
		else:
			_is_valid = false
			return
		# Max 1 per player check
		var core_count: int = 0
		for building in get_tree().get_nodes_in_group("rts_buildings"):
			if not is_instance_valid(building):
				continue
			if "faction_id" in building and building.faction_id == faction_id:
				if "building_type" in building and building.building_type == BuildingStats.BuildingType.SINGULARITY_CORE:
					core_count += 1
		if core_count >= 1:
			_is_valid = false
			return

func is_valid_placement() -> bool:
	return _is_valid

func rotate_ghost() -> void:
	_rotation_angle += PI / 4.0
	if _rotation_angle >= TAU:
		_rotation_angle -= TAU

func get_rotation_angle() -> float:
	return _rotation_angle

func _draw() -> void:
	var color: Color = Color(0.2, 0.9, 0.3, 0.3) if _is_valid else Color(0.9, 0.2, 0.2, 0.3)
	var border_color: Color = Color(0.2, 0.9, 0.3, 0.6) if _is_valid else Color(0.9, 0.2, 0.2, 0.6)

	# Grid lines (5x5 area around cursor, faint) — only when grid snap is active (Shift not held)
	if not Input.is_key_pressed(KEY_SHIFT):
		var grid_size: float = 40.0
		var grid_color: Color = Color(0.5, 0.8, 0.5, 0.08)
		# Offset: since position is snapped, grid lines align with the snapped grid
		for gx in range(-2, 3):
			var lx: float = float(gx) * grid_size
			draw_line(Vector2(lx, -2.0 * grid_size), Vector2(lx, 2.0 * grid_size), grid_color, 1.0)
		for gy in range(-2, 3):
			var ly: float = float(gy) * grid_size
			draw_line(Vector2(-2.0 * grid_size, ly), Vector2(2.0 * grid_size, ly), grid_color, 1.0)

	# Tower range circle for Membrane Tower
	if building_type == BuildingStats.BuildingType.MEMBRANE_TOWER:
		var stats: Dictionary = BuildingStats.get_stats(building_type)
		var tower_range: float = stats.get("attack_range", 0.0)
		if tower_range > 0:
			var range_color: Color = Color(border_color.r, border_color.g, border_color.b, 0.08)
			draw_circle(Vector2.ZERO, tower_range, range_color)
			# Dashed range ring
			var dash_count: int = 24
			var dash_arc: float = TAU / float(dash_count) * 0.5
			for di in range(dash_count):
				var a_start: float = float(di) * TAU / float(dash_count) + _time * 0.3
				draw_arc(Vector2.ZERO, tower_range, a_start, a_start + dash_arc, 4, Color(border_color.r, border_color.g, border_color.b, 0.15), 1.0)

	# Building shape preview
	draw_circle(Vector2.ZERO, _size_radius, color)
	draw_arc(Vector2.ZERO, _size_radius, 0, TAU, 32, border_color, 2.0)

	# Rotation indicator — decorative spines showing current rotation
	if _rotation_angle != 0.0:
		var spine_color: Color = Color(border_color.r, border_color.g, border_color.b, 0.5)
		for i in range(4):
			var sa: float = _rotation_angle + TAU * float(i) / 4.0
			var inner: Vector2 = Vector2(cos(sa), sin(sa)) * _size_radius * 0.6
			var outer: Vector2 = Vector2(cos(sa), sin(sa)) * _size_radius
			draw_line(inner, outer, spine_color, 1.5)
	# Forward direction tick (always visible to show rotation)
	var fwd: Vector2 = Vector2(cos(_rotation_angle - PI * 0.5), sin(_rotation_angle - PI * 0.5))
	draw_line(fwd * _size_radius, fwd * (_size_radius + 6.0), border_color, 2.0)

	# Pulsing indicator
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	draw_arc(Vector2.ZERO, _size_radius + 4.0 + pulse * 3.0, 0, TAU, 32, Color(border_color.r, border_color.g, border_color.b, 0.2 * pulse), 1.0)

	# Building name
	var font: Font = UIConstants.get_mono_font()
	var bname: String = BuildingStats.get_building_name(building_type)
	var ls: Vector2 = font.get_string_size(bname, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_TINY)
	draw_string(font, Vector2(-ls.x * 0.5, _size_radius + 18.0), bname, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, border_color)
	# Cost preview
	var cost: Dictionary = BuildingStats.get_cost(building_type)
	var cost_str: String = "%dB / %dG" % [cost.get("biomass", 0), cost.get("genes", 0)]
	var cs: Vector2 = font.get_string_size(cost_str, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_TINY)
	draw_string(font, Vector2(-cs.x * 0.5, _size_radius + 30.0), cost_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(border_color.r, border_color.g, border_color.b, 0.7))
	# Supply preview
	var stats_for_supply: Dictionary = BuildingStats.get_stats(building_type)
	var supply_val: int = stats_for_supply.get("supply_provided", 0)
	if supply_val > 0:
		var supply_str: String = "+%d supply" % supply_val
		var supply_color: Color = Color(0.7, 0.5, 1.0, 0.8) if _is_valid else Color(0.9, 0.4, 0.4, 0.6)
		var ss: Vector2 = font.get_string_size(supply_str, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_TINY)
		draw_string(font, Vector2(-ss.x * 0.5, _size_radius + 42.0), supply_str, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, supply_color)

extends Node2D
## Placement preview for building construction. Shows green (valid) or red (invalid).

var building_type: int = BuildingStats.BuildingType.BIO_WALL
var faction_id: int = 0
var _is_valid: bool = true
var _size_radius: float = 30.0
var _time: float = 0.0

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
	# Check map bounds
	var map: Node2D = get_tree().get_first_node_in_group("rts_map") if get_tree() else null
	if map and map.has_method("is_within_bounds"):
		if not map.is_within_bounds(global_position):
			_is_valid = false
			return
	# Check overlap with existing buildings
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		var dist: float = global_position.distance_to(building.global_position)
		var other_radius: float = building.size_radius if "size_radius" in building else 30.0
		if dist < _size_radius + other_radius + 5.0:
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

func is_valid_placement() -> bool:
	return _is_valid

func _draw() -> void:
	var color: Color = Color(0.2, 0.9, 0.3, 0.3) if _is_valid else Color(0.9, 0.2, 0.2, 0.3)
	var border_color: Color = Color(0.2, 0.9, 0.3, 0.6) if _is_valid else Color(0.9, 0.2, 0.2, 0.6)

	# Building shape preview
	draw_circle(Vector2.ZERO, _size_radius, color)
	draw_arc(Vector2.ZERO, _size_radius, 0, TAU, 32, border_color, 2.0)

	# Pulsing indicator
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	draw_arc(Vector2.ZERO, _size_radius + 4.0 + pulse * 3.0, 0, TAU, 32, Color(border_color.r, border_color.g, border_color.b, 0.2 * pulse), 1.0)

	# Building name
	var font: Font = UIConstants.get_mono_font()
	var bname: String = BuildingStats.get_name(building_type)
	var ls: Vector2 = font.get_string_size(bname, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_TINY)
	draw_string(font, Vector2(-ls.x * 0.5, _size_radius + 18.0), bname, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, border_color)

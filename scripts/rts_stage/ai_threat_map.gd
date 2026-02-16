extends RefCounted
## Evaluates enemy positions and strengths for AI target prioritization.

var _faction_id: int = 0

func setup(fid: int) -> void:
	_faction_id = fid

func get_weakest_enemy(tree: SceneTree) -> int:
	## Returns faction_id of the weakest alive enemy
	var best_fid: int = -1
	var best_strength: float = INF
	for fid in range(4):
		if fid == _faction_id:
			continue
		var fm: Node = tree.get_first_node_in_group("rts_stage")
		if fm and fm.has_method("get_faction_manager"):
			var fmgr: Node = fm.get_faction_manager()
			if fmgr.is_eliminated(fid):
				continue
		var strength: float = _evaluate_faction_strength(tree, fid)
		if strength < best_strength:
			best_strength = strength
			best_fid = fid
	return best_fid

func _evaluate_faction_strength(tree: SceneTree, fid: int) -> float:
	var total: float = 0.0
	for unit in tree.get_nodes_in_group("faction_%d" % fid):
		if not unit.is_in_group("rts_units"):
			continue
		if "health" in unit:
			total += unit.health
		if "damage" in unit:
			total += unit.damage * 5.0
	for building in tree.get_nodes_in_group("faction_%d" % fid):
		if not building.is_in_group("rts_buildings"):
			continue
		if "health" in building:
			total += building.health * 0.5
	return total

func is_base_threatened(tree: SceneTree) -> bool:
	## Check if enemy units are near our base
	var base_pos: Vector2 = _get_base_position(tree)
	if base_pos == Vector2.ZERO:
		return false
	for unit in tree.get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id == _faction_id:
			continue
		if unit.global_position.distance_to(base_pos) < 400.0:
			return true
	return false

func _get_base_position(tree: SceneTree) -> Vector2:
	for building in tree.get_nodes_in_group("faction_%d" % _faction_id):
		if building.is_in_group("rts_buildings") and "is_main_base" in building and building.is_main_base:
			return building.global_position
	return Vector2.ZERO

func get_nearest_enemy_unit(tree: SceneTree, from_pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for unit in tree.get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id == _faction_id:
			continue
		var dist: float = from_pos.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit
	return nearest

func get_nearest_enemy_building(tree: SceneTree, from_pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for building in tree.get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if "faction_id" in building and building.faction_id == _faction_id:
			continue
		var dist: float = from_pos.distance_to(building.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = building
	return nearest

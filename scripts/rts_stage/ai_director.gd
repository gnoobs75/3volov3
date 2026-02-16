extends Node
## Per-faction AI controller. Manages build orders, unit production, and attack/defense decisions.

enum AIPhase { OPENING, EXPANSION, AGGRESSION, DEFENSE, ENDGAME }

var faction_id: int = 1
var _phase: AIPhase = AIPhase.OPENING
var _decision_timer: float = 0.0
var _threat_map: RefCounted = null
var _stage: Node = null
var _time: float = 0.0

# AI state tracking
var _workers_built: int = 0
var _combat_units_built: int = 0
var _buildings_built: int = 0
var _has_evolution_chamber: bool = false
var _has_nutrient_processor: bool = false
var _attack_rally_point: Vector2 = Vector2.ZERO
var _army_group: Array = []

const DECISION_INTERVAL: float = 2.0

func setup(fid: int, stage: Node) -> void:
	faction_id = fid
	_stage = stage
	_threat_map = preload("res://scripts/rts_stage/ai_threat_map.gd").new()
	_threat_map.setup(faction_id)

func _process(delta: float) -> void:
	_time += delta
	_decision_timer += delta
	if _decision_timer >= DECISION_INTERVAL:
		_decision_timer = 0.0
		_make_decision()

func _make_decision() -> void:
	# Update phase
	_update_phase()
	# Execute phase logic
	match _phase:
		AIPhase.OPENING:
			_do_opening()
		AIPhase.EXPANSION:
			_do_expansion()
		AIPhase.AGGRESSION:
			_do_aggression()
		AIPhase.DEFENSE:
			_do_defense()
		AIPhase.ENDGAME:
			_do_endgame()

func _update_phase() -> void:
	var worker_count: int = _count_units_of_type(UnitStats.UnitType.WORKER)
	var combat_count: int = _count_combat_units()
	var threatened: bool = _threat_map.is_base_threatened(get_tree())

	if threatened and combat_count > 0:
		_phase = AIPhase.DEFENSE
	elif worker_count < 3 and not _has_evolution_chamber:
		_phase = AIPhase.OPENING
	elif combat_count < 5:
		_phase = AIPhase.EXPANSION
	elif _get_alive_enemies() <= 1:
		_phase = AIPhase.ENDGAME
	else:
		_phase = AIPhase.AGGRESSION

# === PHASE IMPLEMENTATIONS ===

func _do_opening() -> void:
	# Build workers first, then expand
	var worker_count: int = _count_units_of_type(UnitStats.UnitType.WORKER)
	if worker_count < 3:
		_try_produce_unit(UnitStats.UnitType.WORKER)
	# Send workers to nearest resource
	_assign_idle_workers_to_gather()
	# Build Nutrient Processor if affordable
	if worker_count >= 2 and not _has_nutrient_processor:
		_try_build(BuildingStats.BuildingType.NUTRIENT_PROCESSOR)
	# Build Evolution Chamber
	if worker_count >= 3 and not _has_evolution_chamber:
		_try_build(BuildingStats.BuildingType.EVOLUTION_CHAMBER)

func _do_expansion() -> void:
	# More workers, first combat units
	var worker_count: int = _count_units_of_type(UnitStats.UnitType.WORKER)
	if worker_count < 5:
		_try_produce_unit(UnitStats.UnitType.WORKER)
	_assign_idle_workers_to_gather()
	# Build combat units based on faction personality
	_produce_combat_units_by_personality()
	# Build towers near base
	if _buildings_built < 8 and randf() < 0.3:
		_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)

func _do_aggression() -> void:
	# Keep producing
	_produce_combat_units_by_personality()
	_assign_idle_workers_to_gather()
	# Group army and attack weakest faction
	var army: Array = _get_combat_units()
	if army.size() >= 5:
		var target_fid: int = _threat_map.get_weakest_enemy(get_tree())
		if target_fid >= 0:
			var target: Node2D = _threat_map.get_nearest_enemy_building(get_tree(), _get_base_pos())
			if not target:
				target = _threat_map.get_nearest_enemy_unit(get_tree(), _get_base_pos())
			if target:
				for unit in army:
					if is_instance_valid(unit) and unit.has_method("command_attack"):
						unit.command_attack(target)

func _do_defense() -> void:
	# Rally units home, build towers
	var base_pos: Vector2 = _get_base_pos()
	var army: Array = _get_combat_units()
	for unit in army:
		if is_instance_valid(unit):
			var dist: float = unit.global_position.distance_to(base_pos)
			if dist > 300.0 and unit.has_method("command_move"):
				unit.command_move(base_pos + Vector2(randf_range(-80, 80), randf_range(-80, 80)))
	# Build towers
	if randf() < 0.5:
		_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)
	# Keep producing
	_produce_combat_units_by_personality()

func _do_endgame() -> void:
	# All-in: send everything at remaining enemy
	_produce_combat_units_by_personality()
	var army: Array = _get_combat_units()
	var target_fid: int = _threat_map.get_weakest_enemy(get_tree())
	if target_fid >= 0 and army.size() >= 3:
		var target: Node2D = _threat_map.get_nearest_enemy_building(get_tree(), _get_base_pos())
		if not target:
			target = _threat_map.get_nearest_enemy_unit(get_tree(), _get_base_pos())
		if target:
			for unit in army:
				if is_instance_valid(unit) and unit.has_method("command_attack"):
					unit.command_attack(target)

# === FACTION PERSONALITY ===

func _produce_combat_units_by_personality() -> void:
	var fd: Dictionary = FactionData.get_faction(faction_id)
	match faction_id:
		FactionData.FactionID.SWARM:
			# Flood with cheap fighters
			_try_produce_unit(UnitStats.UnitType.FIGHTER)
			if randf() < 0.3:
				_try_produce_unit(UnitStats.UnitType.SCOUT)
		FactionData.FactionID.BULWARK:
			# Heavy defenders + towers
			_try_produce_unit(UnitStats.UnitType.DEFENDER)
			if randf() < 0.4:
				_try_produce_unit(UnitStats.UnitType.RANGED)
		FactionData.FactionID.PREDATOR:
			# Fast fighters + scouts
			_try_produce_unit(UnitStats.UnitType.FIGHTER)
			if randf() < 0.5:
				_try_produce_unit(UnitStats.UnitType.FIGHTER)
			if randf() < 0.3:
				_try_produce_unit(UnitStats.UnitType.SCOUT)
		_:
			# Balanced
			if randf() < 0.5:
				_try_produce_unit(UnitStats.UnitType.FIGHTER)
			elif randf() < 0.3:
				_try_produce_unit(UnitStats.UnitType.RANGED)
			else:
				_try_produce_unit(UnitStats.UnitType.DEFENDER)

# === HELPERS ===

func _try_produce_unit(unit_type: int) -> void:
	if not _stage or not _stage.has_method("get_faction_manager"):
		return
	var fm: Node = _stage.get_faction_manager()
	if not fm.can_afford_supply(faction_id, unit_type):
		return
	# Find production building
	for building in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if not building.is_in_group("rts_buildings"):
			continue
		if not is_instance_valid(building):
			continue
		if building.has_method("queue_unit") and building.has_method("is_complete") and building.is_complete():
			if "can_produce" in building and unit_type in building.can_produce:
				if building.get_queue_size() < 3:  # Don't over-queue
					building.queue_unit(unit_type)
					return

func _try_build(building_type: int) -> void:
	if not _stage or not _stage.has_method("ai_place_building"):
		return
	_stage.ai_place_building(faction_id, building_type)

func _assign_idle_workers_to_gather() -> void:
	for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if not unit.is_in_group("rts_units"):
			continue
		if not is_instance_valid(unit):
			continue
		if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
			if "state" in unit and unit.state == 0:  # IDLE
				# Find nearest resource
				var nearest: Node2D = _find_nearest_resource(unit.global_position)
				if nearest and unit.has_method("command_gather"):
					unit.command_gather(nearest)

func _find_nearest_resource(from_pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	# Prefer titans (more resources)
	for res in get_tree().get_nodes_in_group("titan_corpses"):
		if not is_instance_valid(res) or res.is_depleted():
			continue
		if res.has_method("can_add_worker") and not res.can_add_worker():
			continue
		var dist: float = from_pos.distance_to(res.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = res
	if nearest:
		return nearest
	# Fall back to resource nodes
	for res in get_tree().get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(res) or res.is_depleted():
			continue
		var dist: float = from_pos.distance_to(res.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = res
	return nearest

func _count_units_of_type(unit_type: int) -> int:
	var count: int = 0
	for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if unit.is_in_group("rts_units") and "unit_type" in unit and unit.unit_type == unit_type:
			count += 1
	return count

func _count_combat_units() -> int:
	var count: int = 0
	for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if unit.is_in_group("rts_units") and "unit_type" in unit and unit.unit_type != UnitStats.UnitType.WORKER:
			count += 1
	return count

func _get_combat_units() -> Array:
	var result: Array = []
	for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if unit.is_in_group("rts_units") and is_instance_valid(unit) and "unit_type" in unit and unit.unit_type != UnitStats.UnitType.WORKER:
			result.append(unit)
	return result

func _get_base_pos() -> Vector2:
	for building in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if building.is_in_group("rts_buildings") and "is_main_base" in building and building.is_main_base:
			return building.global_position
	return Vector2.ZERO

func _get_alive_enemies() -> int:
	if not _stage or not _stage.has_method("get_faction_manager"):
		return 3
	return _stage.get_faction_manager().get_alive_enemy_factions().size()

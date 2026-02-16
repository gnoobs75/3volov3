extends Node
## Per-faction AI controller. Manages build orders, unit production, and attack/defense decisions.

enum AIPhase { OPENING, EXPANSION, AGGRESSION, DEFENSE, ENDGAME }
enum Difficulty { NOOB, EASY, MEDIUM, HARD, SWEATY }

var faction_id: int = 1
var difficulty: Difficulty = Difficulty.MEDIUM
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

# SWEATY micro state
var _rally_in_progress: bool = false
var _rally_target: Node2D = null
var _rally_timer: float = 0.0
const RALLY_TIMEOUT: float = 6.0

# Difficulty configuration
var _difficulty_config: Dictionary = {
	Difficulty.NOOB: {
		"decision_interval": 5.0,
		"resource_bonus_per_tick": 0,
		"max_queue_size": 1,
		"aggression_threshold": 8,
		"worker_cap": 3,
		"expansion_buildings": 4,
		"tower_chance": 0.1,
		"multi_produce": false,
	},
	Difficulty.EASY: {
		"decision_interval": 3.5,
		"resource_bonus_per_tick": 0,
		"max_queue_size": 2,
		"aggression_threshold": 6,
		"worker_cap": 4,
		"expansion_buildings": 6,
		"tower_chance": 0.2,
		"multi_produce": false,
	},
	Difficulty.MEDIUM: {
		"decision_interval": 2.0,
		"resource_bonus_per_tick": 1,
		"max_queue_size": 3,
		"aggression_threshold": 5,
		"worker_cap": 5,
		"expansion_buildings": 8,
		"tower_chance": 0.3,
		"multi_produce": false,
	},
	Difficulty.HARD: {
		"decision_interval": 1.2,
		"resource_bonus_per_tick": 3,
		"max_queue_size": 4,
		"aggression_threshold": 4,
		"worker_cap": 6,
		"expansion_buildings": 10,
		"tower_chance": 0.5,
		"multi_produce": true,
	},
	Difficulty.SWEATY: {
		"decision_interval": 0.7,
		"resource_bonus_per_tick": 6,
		"max_queue_size": 5,
		"aggression_threshold": 3,
		"worker_cap": 8,
		"expansion_buildings": 14,
		"tower_chance": 0.6,
		"multi_produce": true,
	},
}

func _get_cfg() -> Dictionary:
	return _difficulty_config.get(difficulty, _difficulty_config[Difficulty.MEDIUM])

func setup(fid: int, stage: Node, diff: int = Difficulty.MEDIUM) -> void:
	faction_id = fid
	_stage = stage
	difficulty = diff as Difficulty
	_threat_map = preload("res://scripts/rts_stage/ai_threat_map.gd").new()
	_threat_map.setup(faction_id)

func set_difficulty(diff: int) -> void:
	difficulty = diff as Difficulty

func _process(delta: float) -> void:
	_time += delta
	_decision_timer += delta
	var cfg: Dictionary = _get_cfg()
	if _decision_timer >= cfg["decision_interval"]:
		_decision_timer = 0.0
		_make_decision()
	# SWEATY rally timeout
	if _rally_in_progress:
		_rally_timer += delta
		if _rally_timer >= RALLY_TIMEOUT:
			_rally_in_progress = false
			_execute_attack()

func _make_decision() -> void:
	var cfg: Dictionary = _get_cfg()
	# Scan existing buildings to track what we have
	_has_evolution_chamber = false
	_has_nutrient_processor = false
	for building in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if not building.is_in_group("rts_buildings") or not is_instance_valid(building):
			continue
		if "building_type" in building:
			if building.building_type == BuildingStats.BuildingType.EVOLUTION_CHAMBER:
				_has_evolution_chamber = true
			elif building.building_type == BuildingStats.BuildingType.NUTRIENT_PROCESSOR:
				_has_nutrient_processor = true
	# Give free resources for HARD/SWEATY
	var bonus: int = cfg["resource_bonus_per_tick"]
	if bonus > 0 and _stage and _stage.has_method("get_resource_manager"):
		var rm: Node = _stage.get_resource_manager()
		rm.add_biomass(faction_id, bonus)
		if bonus >= 3:
			rm.add_genes(faction_id, maxi(bonus / 3, 1))
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
	var cfg: Dictionary = _get_cfg()
	var worker_count: int = _count_units_of_type(UnitStats.UnitType.WORKER)
	var combat_count: int = _count_combat_units()
	var threatened: bool = _threat_map.is_base_threatened(get_tree())

	if threatened and combat_count > 0:
		_phase = AIPhase.DEFENSE
	elif worker_count < mini(3, cfg["worker_cap"]) and not _has_evolution_chamber:
		_phase = AIPhase.OPENING
	elif combat_count < cfg["aggression_threshold"]:
		_phase = AIPhase.EXPANSION
	elif _get_alive_enemies() <= 1:
		_phase = AIPhase.ENDGAME
	else:
		_phase = AIPhase.AGGRESSION

# === PHASE IMPLEMENTATIONS ===

func _do_opening() -> void:
	var cfg: Dictionary = _get_cfg()
	# Build workers first, then expand
	var worker_count: int = _count_units_of_type(UnitStats.UnitType.WORKER)
	if worker_count < mini(3, cfg["worker_cap"]):
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
	var cfg: Dictionary = _get_cfg()
	# More workers, first combat units
	var worker_count: int = _count_units_of_type(UnitStats.UnitType.WORKER)
	if worker_count < cfg["worker_cap"]:
		_try_produce_unit(UnitStats.UnitType.WORKER)
	_assign_idle_workers_to_gather()
	# Build combat units based on faction personality
	_produce_combat_units_by_personality()
	# Build towers near base
	if _buildings_built < cfg["expansion_buildings"] and randf() < cfg["tower_chance"]:
		_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)

func _do_aggression() -> void:
	var cfg: Dictionary = _get_cfg()
	# Keep producing
	_produce_combat_units_by_personality()
	_assign_idle_workers_to_gather()
	# Group army and attack weakest faction
	var army: Array = _get_combat_units()
	if army.size() >= cfg["aggression_threshold"]:
		# SWEATY: rally army together before attacking
		if difficulty == Difficulty.SWEATY and not _rally_in_progress:
			_rally_army_before_attack(army)
		else:
			_execute_attack()

func _rally_army_before_attack(army: Array) -> void:
	## SWEATY micro: gather units at a midpoint before engaging
	if army.is_empty():
		return
	var target_fid: int = _threat_map.get_weakest_enemy(get_tree())
	if target_fid < 0:
		return
	var enemy_target: Node2D = _threat_map.get_nearest_enemy_building(get_tree(), _get_base_pos())
	if not enemy_target:
		enemy_target = _threat_map.get_nearest_enemy_unit(get_tree(), _get_base_pos())
	if not enemy_target:
		return
	_rally_target = enemy_target
	# Rally at midpoint between base and target
	var base_pos: Vector2 = _get_base_pos()
	_attack_rally_point = base_pos.lerp(enemy_target.global_position, 0.6)
	_rally_in_progress = true
	_rally_timer = 0.0
	# Command all combat units to move to rally
	for unit in army:
		if is_instance_valid(unit) and unit.has_method("command_move"):
			unit.command_move(_attack_rally_point + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
	# Check if most units have arrived
	var arrived: int = 0
	for unit in army:
		if is_instance_valid(unit) and unit.global_position.distance_to(_attack_rally_point) < 120.0:
			arrived += 1
	if arrived >= army.size() * 0.7:
		_rally_in_progress = false
		_execute_attack()

func _execute_attack() -> void:
	var army: Array = _get_combat_units()
	var target_fid: int = _threat_map.get_weakest_enemy(get_tree())
	if target_fid < 0:
		return
	var target: Node2D = null
	if is_instance_valid(_rally_target):
		target = _rally_target
	else:
		target = _threat_map.get_nearest_enemy_building(get_tree(), _get_base_pos())
		if not target:
			target = _threat_map.get_nearest_enemy_unit(get_tree(), _get_base_pos())
	if target:
		for unit in army:
			if is_instance_valid(unit) and unit.has_method("command_attack"):
				# SWEATY: retreat wounded units
				if difficulty == Difficulty.SWEATY and "health" in unit and "max_health" in unit:
					if unit.health < unit.max_health * 0.25:
						if unit.has_method("command_move"):
							unit.command_move(_get_base_pos() + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
							continue
				unit.command_attack(target)
	_rally_in_progress = false

func _do_defense() -> void:
	var cfg: Dictionary = _get_cfg()
	# Rally units home, build towers
	var base_pos: Vector2 = _get_base_pos()
	var army: Array = _get_combat_units()
	for unit in army:
		if is_instance_valid(unit):
			var dist: float = unit.global_position.distance_to(base_pos)
			if dist > 300.0 and unit.has_method("command_move"):
				unit.command_move(base_pos + Vector2(randf_range(-80, 80), randf_range(-80, 80)))
	# Build towers
	if randf() < cfg["tower_chance"]:
		_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)
	# Keep producing
	_produce_combat_units_by_personality()

func _do_endgame() -> void:
	var cfg: Dictionary = _get_cfg()
	# All-in: send everything at remaining enemy
	_produce_combat_units_by_personality()
	var army: Array = _get_combat_units()
	var target_fid: int = _threat_map.get_weakest_enemy(get_tree())
	if target_fid >= 0 and army.size() >= mini(3, cfg["aggression_threshold"]):
		if difficulty == Difficulty.SWEATY and not _rally_in_progress:
			_rally_army_before_attack(army)
		else:
			var target: Node2D = _threat_map.get_nearest_enemy_building(get_tree(), _get_base_pos())
			if not target:
				target = _threat_map.get_nearest_enemy_unit(get_tree(), _get_base_pos())
			if target:
				for unit in army:
					if is_instance_valid(unit) and unit.has_method("command_attack"):
						unit.command_attack(target)

# === FACTION PERSONALITY ===

func _produce_combat_units_by_personality() -> void:
	var cfg: Dictionary = _get_cfg()
	var fd: Dictionary = FactionData.get_faction(faction_id)
	var produced_from: Array = []  # Track buildings already used this tick
	match faction_id:
		FactionData.FactionID.SWARM:
			# Flood with cheap fighters
			_try_produce_unit(UnitStats.UnitType.FIGHTER, produced_from)
			if cfg["multi_produce"]:
				_try_produce_unit(UnitStats.UnitType.FIGHTER, produced_from)
			if randf() < 0.3:
				_try_produce_unit(UnitStats.UnitType.SCOUT, produced_from)
		FactionData.FactionID.BULWARK:
			# Heavy defenders + towers
			_try_produce_unit(UnitStats.UnitType.DEFENDER, produced_from)
			if cfg["multi_produce"]:
				_try_produce_unit(UnitStats.UnitType.DEFENDER, produced_from)
			if randf() < 0.4:
				_try_produce_unit(UnitStats.UnitType.RANGED, produced_from)
		FactionData.FactionID.PREDATOR:
			# Fast fighters + scouts
			_try_produce_unit(UnitStats.UnitType.FIGHTER, produced_from)
			if randf() < 0.5 or cfg["multi_produce"]:
				_try_produce_unit(UnitStats.UnitType.FIGHTER, produced_from)
			if randf() < 0.3:
				_try_produce_unit(UnitStats.UnitType.SCOUT, produced_from)
		_:
			# Balanced
			if randf() < 0.5:
				_try_produce_unit(UnitStats.UnitType.FIGHTER, produced_from)
			elif randf() < 0.3:
				_try_produce_unit(UnitStats.UnitType.RANGED, produced_from)
			else:
				_try_produce_unit(UnitStats.UnitType.DEFENDER, produced_from)
			if cfg["multi_produce"]:
				_try_produce_unit(UnitStats.UnitType.FIGHTER, produced_from)

# === HELPERS ===

func _try_produce_unit(unit_type: int, produced_from: Array = []) -> void:
	if not _stage or not _stage.has_method("get_faction_manager"):
		return
	var fm: Node = _stage.get_faction_manager()
	if not fm.can_afford_supply(faction_id, unit_type):
		return
	var cfg: Dictionary = _get_cfg()
	# Find production building
	for building in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if not building.is_in_group("rts_buildings"):
			continue
		if not is_instance_valid(building):
			continue
		# Skip buildings already used this tick (unless multi_produce)
		if not cfg["multi_produce"] and building in produced_from:
			continue
		if building.has_method("queue_unit") and building.has_method("is_complete") and building.is_complete():
			if "can_produce" in building and unit_type in building.can_produce:
				if building.get_queue_size() < cfg["max_queue_size"]:
					building.queue_unit(unit_type)
					produced_from.append(building)
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

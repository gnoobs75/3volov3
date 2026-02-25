extends Node
## Per-faction AI controller. Manages build orders, unit production, and attack/defense decisions.

signal ai_taunt(faction_id: int, message: String)

enum AIPhase { OPENING, EXPANSION, AGGRESSION, DEFENSE, ENDGAME }
enum Difficulty { NOOB, EASY, MEDIUM, HARD, SWEATY }
enum Personality { ADAPTIVE, SWARM, BULWARK, PREDATOR }

var faction_id: int = 1
var difficulty: Difficulty = Difficulty.MEDIUM
var _personality: Personality = Personality.ADAPTIVE
var _phase: AIPhase = AIPhase.OPENING
var _decision_timer: float = 0.0
var _threat_map: RefCounted = null
var _stage: Node = null
var _time: float = 0.0

# Personality-driven army composition targets
const PERSONALITY_COMPOSITION: Dictionary = {
	Personality.SWARM: {
		UnitStats.UnitType.FIGHTER: 0.70, UnitStats.UnitType.SCOUT: 0.20,
		UnitStats.UnitType.RANGED: 0.10,
	},
	Personality.BULWARK: {
		UnitStats.UnitType.DEFENDER: 0.40, UnitStats.UnitType.SIEGE_WORM: 0.25,
		UnitStats.UnitType.RANGED: 0.20, UnitStats.UnitType.MEDIC: 0.10,
		UnitStats.UnitType.FIGHTER: 0.05,
	},
	Personality.PREDATOR: {
		UnitStats.UnitType.SCOUT: 0.30, UnitStats.UnitType.RANGED: 0.25,
		UnitStats.UnitType.PSI_CASTER: 0.20, UnitStats.UnitType.FIGHTER: 0.15,
		UnitStats.UnitType.SIEGE_WORM: 0.10,
	},
}

# Personality-driven attack intervals
const PERSONALITY_ATTACK_INTERVAL: Dictionary = {
	Personality.ADAPTIVE: 180.0,
	Personality.SWARM: 90.0,
	Personality.BULWARK: 300.0,
	Personality.PREDATOR: 60.0,
}

# Personality-driven minimum army sizes for attack
const PERSONALITY_ATTACK_THRESHOLD: Dictionary = {
	Personality.ADAPTIVE: 6,
	Personality.SWARM: 4,
	Personality.BULWARK: 12,
	Personality.PREDATOR: 3,
}

# Personality-driven tech priorities (ordered list of UpgradeId to research)
const PERSONALITY_TECH_PRIORITY: Dictionary = {
	Personality.SWARM: [1, 2, 6, 4, 5, 0, 3, 7, 8],  # Metabolic Boost, Sharpened Cilia, Berserker Enzymes, ...
	Personality.BULWARK: [0, 3, 7, 4, 5, 1, 2, 6, 8],  # Hardened Membranes, Regen Tissue, Hive Mind, ...
	Personality.PREDATOR: [4, 8, 5, 1, 2, 0, 3, 6, 7],  # Extended Pseudopods, Apex Predator, Rapid Mitosis, ...
}

# Raid group tracking for Predator personality
var _raid_groups: Array = []  # Array of {units: Array, target: Node2D, timer: float}
var _raid_cooldown: float = 0.0

# AI taunts
var _taunt_timer: float = 0.0
const TAUNT_INTERVAL: float = 120.0  # Every 2 minutes
var _taunt_messages: Dictionary = {
	AIPhase.OPENING: [
		"We are awakening...",
		"Your colony will be absorbed.",
		"The substrate trembles beneath us.",
		"Our cells divide. Our hunger grows.",
		"We sense your weakness, little colony.",
		"Soon we will spread across this dish.",
		"Do you feel us stirring?",
		"Every moment, we grow stronger.",
	],
	AIPhase.EXPANSION: [
		"Our tendrils reach further.",
		"We claim these nutrients as our own.",
		"Your borders shrink while ours expand.",
		"This petri dish belongs to us.",
		"Build your walls. They will not hold.",
		"We are everywhere. We are patient.",
		"Your workers look so... fragile.",
		"Our colony swells with purpose.",
	],
	AIPhase.AGGRESSION: [
		"Your defenses crumble!",
		"We feast on your workers!",
		"Submit now and be consumed painlessly.",
		"Our swarm descends upon you!",
		"Flee, little colony. Run while you can.",
		"We will dissolve your membranes!",
		"Your structures weaken. We smell fear.",
		"Resistance only delays the inevitable.",
	],
	AIPhase.DEFENSE: [
		"You cannot break us.",
		"We endure.",
		"Strike all you want. We regenerate.",
		"Our walls are living tissue. They heal.",
		"A temporary setback. Nothing more.",
		"You mistake our patience for weakness.",
		"We have weathered worse than you.",
		"Press your attack. We dare you.",
	],
	AIPhase.ENDGAME: [
		"This ends now!",
		"Submit or be consumed!",
		"There is no escape from this dish.",
		"Only one colony survives. It will be us.",
		"Your final moments have arrived.",
		"We are the apex organism!",
		"Brace yourself for extinction.",
		"The petri dish will remember only us.",
	],
}

# Personality-specific taunts (override phase taunts when personality is set)
var _personality_taunts: Dictionary = {
	Personality.SWARM: {
		AIPhase.OPENING: ["Our numbers swell...", "Division begins. You cannot stop mitosis."],
		AIPhase.EXPANSION: ["SWARM! CONSUME!", "We multiply beyond counting."],
		AIPhase.AGGRESSION: ["Your walls crumble before our numbers!", "Drown in the tide of our bodies!"],
		AIPhase.DEFENSE: ["Cut one down, ten more arise.", "You thin us, but never empty us."],
		AIPhase.ENDGAME: ["The swarm devours all!", "There is only the swarm now."],
	},
	Personality.BULWARK: {
		AIPhase.OPENING: ["Our foundations are laid.", "Stone upon stone, we rise."],
		AIPhase.EXPANSION: ["Our fortress is complete.", "Your time grows short."],
		AIPhase.AGGRESSION: ["Our walls march forward!", "The fortress moves. Tremble."],
		AIPhase.DEFENSE: ["Break upon our walls like water.", "We are the immovable."],
		AIPhase.ENDGAME: ["The fortress consumes all!", "Nothing withstands our calcified might."],
	},
	Personality.PREDATOR: {
		AIPhase.OPENING: ["We taste the air... prey is near.", "The hunt begins."],
		AIPhase.EXPANSION: ["Your workers scatter like prey.", "We mark our hunting grounds."],
		AIPhase.AGGRESSION: ["We strike from every shadow!", "No corner is safe from us."],
		AIPhase.DEFENSE: ["A predator cornered is most dangerous.", "We lick our wounds and sharpen our fangs."],
		AIPhase.ENDGAME: ["The final hunt!", "You are the last prey."],
	},
}

# AI state tracking
var _workers_built: int = 0
var _combat_units_built: int = 0
var _buildings_built: int = 0
var _has_evolution_chamber: bool = false
var _has_nutrient_processor: bool = false
var _attack_rally_point: Vector2 = Vector2.ZERO
var _army_group: Array = []

# Tech tree integration
var _tech_tree: Node = null

# Grace period — AI won't attack during this window
var _grace_period: float = 0.0
var _grace_active: bool = false

# Map awareness
var _map_id: String = "petri_dish"

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
	# Set personality based on faction
	match faction_id:
		FactionData.FactionID.SWARM:
			_personality = Personality.SWARM
		FactionData.FactionID.BULWARK:
			_personality = Personality.BULWARK
		FactionData.FactionID.PREDATOR:
			_personality = Personality.PREDATOR
		_:
			_personality = Personality.ADAPTIVE
	# Read map ID for map-specific AI behavior
	if _stage.has_method("get_map_id"):
		_map_id = _stage.get_map_id()
	_apply_map_personality()

func set_difficulty(diff: int) -> void:
	difficulty = diff as Difficulty

func set_grace_period(seconds: float) -> void:
	_grace_period = seconds
	_grace_active = seconds > 0

func _process(delta: float) -> void:
	_time += delta
	# Grace period countdown
	if _grace_active:
		_grace_period -= delta
		if _grace_period <= 0:
			_grace_active = false
			_grace_period = 0.0
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
	# Raid group timers (Predator personality)
	if _personality == Personality.PREDATOR:
		_update_raid_groups(delta)
	if _raid_cooldown > 0.0:
		_raid_cooldown -= delta
	# AI taunts
	_taunt_timer += delta
	if _taunt_timer >= TAUNT_INTERVAL:
		_taunt_timer = 0.0
		_emit_taunt()

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
	var worker_count: int = _count_units_of_type(UnitStats.UnitType.WORKER)
	_assign_idle_workers_to_gather()

	match _personality:
		Personality.SWARM:
			# Rush workers fast, skip Nutrient Processor, get Evolution Chamber early
			if worker_count < mini(4, cfg["worker_cap"]):
				_try_produce_unit(UnitStats.UnitType.WORKER)
			if worker_count >= 2 and not _has_evolution_chamber:
				_try_build(BuildingStats.BuildingType.EVOLUTION_CHAMBER)
			# Start combat production early
			if _has_evolution_chamber:
				_try_produce_unit(UnitStats.UnitType.FIGHTER)

		Personality.BULWARK:
			# Workers first, early Nutrient Processor, then Bio-Wall ring
			if worker_count < mini(3, cfg["worker_cap"]):
				_try_produce_unit(UnitStats.UnitType.WORKER)
			if worker_count >= 2 and not _has_nutrient_processor:
				_try_build(BuildingStats.BuildingType.NUTRIENT_PROCESSOR)
			# Build Bio-Walls around base early
			if worker_count >= 2:
				_try_build(BuildingStats.BuildingType.BIO_WALL)
			# Build towers before Evolution Chamber
			if worker_count >= 3 and _count_buildings_of_type(BuildingStats.BuildingType.MEMBRANE_TOWER) < 3:
				_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)
			elif worker_count >= 3 and not _has_evolution_chamber:
				_try_build(BuildingStats.BuildingType.EVOLUTION_CHAMBER)

		Personality.PREDATOR:
			# Fast Scout production
			if worker_count < mini(2, cfg["worker_cap"]):
				_try_produce_unit(UnitStats.UnitType.WORKER)
			if worker_count >= 2 and not _has_evolution_chamber:
				_try_build(BuildingStats.BuildingType.EVOLUTION_CHAMBER)
			# Start scouting immediately
			if _has_evolution_chamber:
				_try_produce_unit(UnitStats.UnitType.SCOUT)

		_:
			# Default / ADAPTIVE behavior
			if worker_count < mini(3, cfg["worker_cap"]):
				_try_produce_unit(UnitStats.UnitType.WORKER)
			if worker_count >= 2 and not _has_nutrient_processor:
				_try_build(BuildingStats.BuildingType.NUTRIENT_PROCESSOR)
			if worker_count >= 3 and not _has_evolution_chamber:
				_try_build(BuildingStats.BuildingType.EVOLUTION_CHAMBER)

func _do_expansion() -> void:
	var cfg: Dictionary = _get_cfg()
	var worker_count: int = _count_units_of_type(UnitStats.UnitType.WORKER)
	if worker_count < cfg["worker_cap"]:
		_try_produce_unit(UnitStats.UnitType.WORKER)
	_assign_idle_workers_to_gather()
	# Build combat units via composition-weighted selection
	_produce_combat_unit_weighted()

	match _personality:
		Personality.SWARM:
			# Extra production, minimal towers, never Bio-Walls
			if cfg["multi_produce"]:
				_produce_combat_unit_weighted()
			# Swarm rarely builds towers
			if _buildings_built < cfg["expansion_buildings"] and randf() < cfg["tower_chance"] * 0.3:
				_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)

		Personality.BULWARK:
			# Bio-Walls at every expansion, towers heavily
			_try_build(BuildingStats.BuildingType.BIO_WALL)
			if _buildings_built < cfg["expansion_buildings"] and randf() < cfg["tower_chance"] * 1.5:
				_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)

		Personality.PREDATOR:
			# Minimal towers, maximum mobility, extra combat unit
			if cfg["multi_produce"]:
				_produce_combat_unit_weighted()
			# Predator almost never builds static defense
			if _buildings_built < cfg["expansion_buildings"] and randf() < cfg["tower_chance"] * 0.15:
				_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)

		_:
			# Default tower building
			if _buildings_built < cfg["expansion_buildings"] and randf() < cfg["tower_chance"]:
				_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)

	# Try to research upgrades (30% chance, personality-prioritized)
	if randf() < 0.3:
		_try_research_upgrade()

func _do_aggression() -> void:
	var cfg: Dictionary = _get_cfg()
	# Keep producing
	_produce_combat_unit_weighted()
	_assign_idle_workers_to_gather()
	# Try to research upgrades (50% chance)
	if randf() < 0.5:
		_try_research_upgrade()
	# Try to use unit abilities
	_try_use_abilities()
	# Don't attack during grace period
	if _grace_active:
		return
	# Execute personality-driven attack
	_execute_personality_attack()

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
	var base_pos: Vector2 = _get_base_pos()
	var army: Array = _get_combat_units()
	# Keep producing
	_produce_combat_unit_weighted()
	# Try to use unit abilities (defensive)
	_try_use_abilities()

	match _personality:
		Personality.SWARM:
			# Swarm defends by counter-attacking: rally and rush the attacker
			for unit in army:
				if is_instance_valid(unit):
					var dist: float = unit.global_position.distance_to(base_pos)
					if dist > 500.0 and unit.has_method("command_move"):
						unit.command_move(base_pos + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
			# Try to counter-attack nearby enemies
			var nearest_enemy: Node2D = _threat_map.get_nearest_enemy_unit(get_tree(), base_pos)
			if nearest_enemy and nearest_enemy.global_position.distance_to(base_pos) < 400.0:
				for unit in army:
					if is_instance_valid(unit) and unit.has_method("command_attack"):
						unit.command_attack(nearest_enemy)

		Personality.BULWARK:
			# Tight defense: rally close to base, spam towers and walls
			for unit in army:
				if is_instance_valid(unit):
					var dist: float = unit.global_position.distance_to(base_pos)
					if dist > 200.0 and unit.has_method("command_move"):
						unit.command_move(base_pos + Vector2(randf_range(-50, 50), randf_range(-50, 50)))
			# Heavy static defense
			_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)
			_try_build(BuildingStats.BuildingType.BIO_WALL)

		Personality.PREDATOR:
			# Predator retreats loosely, prepares raid groups to hit back
			for unit in army:
				if is_instance_valid(unit):
					var dist: float = unit.global_position.distance_to(base_pos)
					if dist > 400.0 and unit.has_method("command_move"):
						unit.command_move(base_pos + Vector2(randf_range(-100, 100), randf_range(-100, 100)))

		_:
			# Default defense
			for unit in army:
				if is_instance_valid(unit):
					var dist: float = unit.global_position.distance_to(base_pos)
					if dist > 300.0 and unit.has_method("command_move"):
						unit.command_move(base_pos + Vector2(randf_range(-80, 80), randf_range(-80, 80)))
			if randf() < cfg["tower_chance"]:
				_try_build(BuildingStats.BuildingType.MEMBRANE_TOWER)

func _do_endgame() -> void:
	var cfg: Dictionary = _get_cfg()
	# All personalities go all-in during endgame
	_produce_combat_unit_weighted()
	# Research every decision in endgame
	_try_research_upgrade()
	# Try to use unit abilities
	_try_use_abilities()
	if _grace_active:
		return
	var army: Array = _get_combat_units()
	var threshold: int = PERSONALITY_ATTACK_THRESHOLD.get(_personality, cfg["aggression_threshold"])
	var target_fid: int = _threat_map.get_weakest_enemy(get_tree())
	if target_fid >= 0 and army.size() >= mini(3, threshold):
		if difficulty == Difficulty.SWEATY and not _rally_in_progress:
			_rally_army_before_attack(army)
		else:
			# All personalities converge on remaining enemy base in endgame
			var target: Node2D = _threat_map.get_nearest_enemy_building(get_tree(), _get_base_pos())
			if not target:
				target = _threat_map.get_nearest_enemy_unit(get_tree(), _get_base_pos())
			if target:
				for unit in army:
					if is_instance_valid(unit) and unit.has_method("command_attack"):
						unit.command_attack(target)

# === FACTION PERSONALITY ===

func _produce_combat_unit_weighted() -> void:
	## Produce the combat unit type most underrepresented vs personality composition target.
	var composition: Dictionary = PERSONALITY_COMPOSITION.get(_personality, {})
	if composition.is_empty():
		# ADAPTIVE: balanced fallback
		composition = {
			UnitStats.UnitType.FIGHTER: 0.40, UnitStats.UnitType.DEFENDER: 0.25,
			UnitStats.UnitType.RANGED: 0.20, UnitStats.UnitType.SCOUT: 0.15,
		}

	# Count current army by type
	var army_counts: Dictionary = {}
	var total_combat: int = 0
	for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if not unit.is_in_group("rts_units") or not is_instance_valid(unit):
			continue
		if not "unit_type" in unit or unit.unit_type == UnitStats.UnitType.WORKER:
			continue
		var ut: int = unit.unit_type
		army_counts[ut] = army_counts.get(ut, 0) + 1
		total_combat += 1

	# Find which unit type is most underrepresented vs target ratio
	var best_type: int = UnitStats.UnitType.FIGHTER
	var best_deficit: float = -INF
	for unit_type in composition:
		var target_ratio: float = composition[unit_type]
		var current_ratio: float = 0.0
		if total_combat > 0:
			current_ratio = float(army_counts.get(unit_type, 0)) / float(total_combat)
		var deficit: float = target_ratio - current_ratio
		if deficit > best_deficit:
			best_deficit = deficit
			best_type = unit_type

	_try_produce_unit(best_type)

func _get_tech_priority() -> Array:
	## Returns ordered list of UpgradeId to research based on personality.
	if _personality in PERSONALITY_TECH_PRIORITY:
		return PERSONALITY_TECH_PRIORITY[_personality]
	# ADAPTIVE: default order (balanced)
	return [1, 0, 2, 5, 4, 3, 6, 7, 8]

# === PERSONALITY-DRIVEN ATTACK PATTERNS ===

func _execute_personality_attack() -> void:
	## Branch attack behavior based on personality.
	var army: Array = _get_combat_units()
	var threshold: int = PERSONALITY_ATTACK_THRESHOLD.get(_personality, _get_cfg()["aggression_threshold"])

	match _personality:
		Personality.SWARM:
			_execute_swarm_attack(army, threshold)
		Personality.BULWARK:
			_execute_bulwark_attack(army, threshold)
		Personality.PREDATOR:
			_execute_predator_attack(army, threshold)
		_:
			_execute_adaptive_attack(army, threshold)

func _execute_swarm_attack(army: Array, threshold: int) -> void:
	## SWARM: All-in as soon as threshold met. Never retreats. Targets closest buildings.
	if army.size() < threshold:
		return
	var base_pos: Vector2 = _get_base_pos()
	var target: Node2D = _threat_map.get_nearest_enemy_building(get_tree(), base_pos)
	if not target:
		target = _threat_map.get_nearest_enemy_unit(get_tree(), base_pos)
	if target:
		for unit in army:
			if is_instance_valid(unit) and unit.has_method("command_attack"):
				unit.command_attack(target)

func _execute_bulwark_attack(army: Array, threshold: int) -> void:
	## BULWARK: Only attacks with massive deathball AND T3 research. Targets main base.
	## Retreats if army drops below 50%.
	if army.size() < threshold:
		return
	# Require at least T2 research (T3 if available)
	if _tech_tree and _tech_tree.has_method("get_faction_tier"):
		var tier: int = _tech_tree.get_faction_tier(faction_id)
		if tier < 2:
			return  # Wait for tech
	# Check if we should retreat (below 50% of peak army)
	var alive_ratio: float = float(army.size()) / float(maxi(threshold, 1))
	if alive_ratio < 0.5 and _rally_in_progress:
		# Retreat to base
		var base_pos: Vector2 = _get_base_pos()
		for unit in army:
			if is_instance_valid(unit) and unit.has_method("command_move"):
				unit.command_move(base_pos + Vector2(randf_range(-80, 80), randf_range(-80, 80)))
		_rally_in_progress = false
		return
	# SWEATY: rally first
	if difficulty == Difficulty.SWEATY and not _rally_in_progress:
		_rally_army_before_attack(army)
	else:
		# Target enemy main base directly
		var target: Node2D = _find_enemy_main_base()
		if not target:
			target = _threat_map.get_nearest_enemy_building(get_tree(), _get_base_pos())
		if not target:
			target = _threat_map.get_nearest_enemy_unit(get_tree(), _get_base_pos())
		if target:
			for unit in army:
				if is_instance_valid(unit) and unit.has_method("command_attack"):
					# SWEATY: retreat wounded
					if difficulty == Difficulty.SWEATY and "health" in unit and "max_health" in unit:
						if unit.health < unit.max_health * 0.25:
							if unit.has_method("command_move"):
								unit.command_move(_get_base_pos() + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
								continue
					unit.command_attack(target)

func _execute_predator_attack(army: Array, threshold: int) -> void:
	## PREDATOR: Splits army into 2-3 raid groups of 3-5 units.
	## Targets workers and resource depots. Each group retreats after 10s.
	if army.size() < threshold:
		return
	if _raid_cooldown > 0.0:
		return
	_split_army_into_raids(army)
	_raid_cooldown = PERSONALITY_ATTACK_INTERVAL.get(Personality.PREDATOR, 60.0)

func _execute_adaptive_attack(army: Array, threshold: int) -> void:
	## ADAPTIVE: Standard attack behavior (original logic).
	if army.size() < threshold:
		return
	if difficulty == Difficulty.SWEATY and not _rally_in_progress:
		_rally_army_before_attack(army)
	else:
		_execute_attack()

func _split_army_into_raids(army: Array) -> void:
	## Split the army into 2-3 raid groups of 3-5 units targeting different objectives.
	_raid_groups.clear()
	# Shuffle army for random assignment
	var shuffled: Array = army.duplicate()
	shuffled.shuffle()
	# Determine number of groups (2-3 based on army size)
	var num_groups: int = 2
	if shuffled.size() >= 10:
		num_groups = 3
	var group_size: int = clampi(shuffled.size() / num_groups, 3, 5)

	# Find raid targets: prioritize workers and resource buildings
	var raid_targets: Array = _find_raid_targets()
	if raid_targets.is_empty():
		# Fallback to standard attack
		_execute_attack()
		return

	for i in range(num_groups):
		var start_idx: int = i * group_size
		if start_idx >= shuffled.size():
			break
		var end_idx: int = mini(start_idx + group_size, shuffled.size())
		var group_units: Array = shuffled.slice(start_idx, end_idx)
		var target: Node2D = raid_targets[i % raid_targets.size()]

		# Send group to raid target
		for unit in group_units:
			if is_instance_valid(unit) and unit.has_method("command_attack"):
				unit.command_attack(target)

		_raid_groups.append({
			"units": group_units,
			"target": target,
			"timer": 0.0,
		})

func _find_raid_targets() -> Array:
	## Find high-value raid targets: enemy workers, resource depots, undefended buildings.
	var targets: Array = []
	var base_pos: Vector2 = _get_base_pos()

	# Priority 1: Enemy workers
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id == faction_id:
			continue
		if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
			targets.append(unit)
			if targets.size() >= 3:
				break

	# Priority 2: Nutrient Processors / Supply Depots (economic targets)
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if "faction_id" in building and building.faction_id == faction_id:
			continue
		if "building_type" in building:
			if building.building_type == BuildingStats.BuildingType.NUTRIENT_PROCESSOR or \
				building.building_type == BuildingStats.BuildingType.SUPPLY_DEPOT:
				targets.append(building)

	# Fallback: nearest enemy building
	if targets.is_empty():
		var nearest: Node2D = _threat_map.get_nearest_enemy_building(get_tree(), base_pos)
		if nearest:
			targets.append(nearest)

	return targets

func _update_raid_groups(delta: float) -> void:
	## Update active raid groups: retreat after 10s of combat.
	var base_pos: Vector2 = _get_base_pos()
	var expired: Array = []
	for i in range(_raid_groups.size()):
		var group: Dictionary = _raid_groups[i]
		group["timer"] += delta
		# Retreat after 10 seconds
		if group["timer"] >= 10.0:
			for unit in group["units"]:
				if is_instance_valid(unit) and unit.has_method("command_move"):
					unit.command_move(base_pos + Vector2(randf_range(-100, 100), randf_range(-100, 100)))
			expired.append(i)
		else:
			# Clean dead units from group
			var alive: Array = []
			for unit in group["units"]:
				if is_instance_valid(unit):
					alive.append(unit)
			group["units"] = alive
			# If group is wiped, remove it
			if alive.is_empty():
				expired.append(i)
	# Remove expired groups (reverse order)
	expired.reverse()
	for idx in expired:
		_raid_groups.remove_at(idx)

func _find_enemy_main_base() -> Node2D:
	## Find an enemy main base building (Spawning Pool with is_main_base).
	var target_fid: int = _threat_map.get_weakest_enemy(get_tree())
	if target_fid < 0:
		return null
	for building in get_tree().get_nodes_in_group("faction_%d" % target_fid):
		if building.is_in_group("rts_buildings") and "is_main_base" in building and building.is_main_base:
			return building
	return null

# === HELPERS ===

func _try_produce_unit(unit_type: int, produced_from: Array = []) -> void:
	if not _stage or not _stage.has_method("get_faction_manager"):
		return
	var fm: Node = _stage.get_faction_manager()
	if not fm.can_afford_supply(faction_id, unit_type):
		# At supply cap — try building a Supply Depot
		_try_build(BuildingStats.BuildingType.SUPPLY_DEPOT)
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

func _count_buildings_of_type(building_type: int) -> int:
	var count: int = 0
	for building in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if building.is_in_group("rts_buildings") and "building_type" in building and building.building_type == building_type:
			count += 1
	return count

func _get_base_pos() -> Vector2:
	for building in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if building.is_in_group("rts_buildings") and "is_main_base" in building and building.is_main_base:
			return building.global_position
	return Vector2.ZERO

func _get_alive_enemies() -> int:
	if not _stage or not _stage.has_method("get_faction_manager"):
		return 3
	return _stage.get_faction_manager().get_alive_enemy_factions().size()

# === TECH TREE INTEGRATION ===

func set_tech_tree(tree: Node) -> void:
	_tech_tree = tree

func _try_spend(biomass_cost: int, genes_cost: int) -> bool:
	if not _stage or not _stage.has_method("get_resource_manager"):
		return false
	var rm: Node = _stage.get_resource_manager()
	return rm.spend(faction_id, biomass_cost, genes_cost)

func _try_research_upgrade() -> void:
	if not _tech_tree or not _tech_tree.has_method("get_available_upgrades"):
		return
	var available: Array = _tech_tree.get_available_upgrades(faction_id)
	if available.is_empty():
		# Try to unlock next tier
		if _tech_tree.has_method("get_faction_tier"):
			var current_tier: int = _tech_tree.get_faction_tier(faction_id)
			if current_tier < 3 and _tech_tree.has_method("can_unlock_tier") and _tech_tree.can_unlock_tier(faction_id, current_tier + 1):
				var tier_costs: Dictionary = {2: {"biomass": 200, "genes": 50}, 3: {"biomass": 400, "genes": 100}}
				var cost: Dictionary = tier_costs.get(current_tier + 1, {})
				if _try_spend(cost.get("biomass", 0), cost.get("genes", 0)):
					_tech_tree.unlock_tier(faction_id, current_tier + 1)
		return
	# Pick random available upgrade
	var pick: int = available[randi() % available.size()]
	# Let the building handle resource spending via queue_research()
	for b in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if b is StaticBody2D and "building_type" in b and b.building_type == BuildingStats.BuildingType.EVOLUTION_CHAMBER:
			if b.has_method("is_complete") and b.is_complete() and b.has_method("queue_research"):
				if b.queue_research(pick):
					break

# === ABILITY USAGE ===

func _try_use_abilities() -> void:
	if difficulty == Difficulty.NOOB:
		return
	var chance: float = [0.0, 0.2, 0.5, 0.8, 1.0][difficulty]
	if randf() > chance:
		return
	for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if not (unit is CharacterBody2D) or not is_instance_valid(unit):
			continue
		if not unit.has_method("can_use_ability") or not unit.has_method("use_ability"):
			continue
		if not unit.can_use_ability():
			continue
		if not "unit_type" in unit:
			continue
		match unit.unit_type:
			UnitStats.UnitType.FIGHTER:
				# Charge if target is far away
				if "_attack_target" in unit and is_instance_valid(unit._attack_target):
					if unit.global_position.distance_to(unit._attack_target.global_position) > 100.0:
						unit.use_ability(unit._attack_target.global_position)
			UnitStats.UnitType.DEFENDER:
				# Fortify when low HP and enemies nearby
				if "health" in unit and "max_health" in unit and unit.health < unit.max_health * 0.5:
					unit.use_ability(Vector2.ZERO)
			UnitStats.UnitType.SCOUT:
				# Spores when exploring
				unit.use_ability(Vector2.ZERO)
			UnitStats.UnitType.RANGED:
				# Acid volley when attacking
				if "_attack_target" in unit and is_instance_valid(unit._attack_target):
					unit.use_ability(Vector2.ZERO)
			UnitStats.UnitType.WORKER:
				# Burst gather (HARD+ only)
				if difficulty >= Difficulty.HARD and "state" in unit and unit.state == 3:  # GATHER
					unit.use_ability(Vector2.ZERO)

# === MAP EVENT REACTIONS ===

func on_map_event(event_type: int, event_pos: Vector2) -> void:
	match event_type:
		0:  # NUTRIENT_BLOOM
			if difficulty >= Difficulty.MEDIUM:
				# Send 2 workers to harvest
				var workers: Array = _get_idle_workers()
				var sent: int = 0
				for w in workers:
					if sent >= 2:
						break
					if is_instance_valid(w) and w.has_method("command_move"):
						w.command_move(event_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
						sent += 1
		1:  # TOXIC_TIDE
			if difficulty >= Difficulty.EASY:
				# Move units away
				for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
					if unit is CharacterBody2D and is_instance_valid(unit):
						if unit.global_position.distance_to(event_pos) < 600.0:
							var away: Vector2 = (unit.global_position - event_pos).normalized() * 300.0
							if unit.has_method("command_move"):
								unit.command_move(unit.global_position + away)
		2:  # EVOLUTIONARY_SURGE
			if difficulty >= Difficulty.HARD:
				_do_aggression()  # Push attack timing
		3:  # PETRI_QUAKE
			pass  # Buildings auto-repair handled elsewhere

func _get_idle_workers() -> Array:
	var workers: Array = []
	for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if unit is CharacterBody2D and is_instance_valid(unit):
			if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
				if "state" in unit and unit.state == 0:  # IDLE
					workers.append(unit)
	return workers

# === MAP-SPECIFIC AI PERSONALITY ===

func _apply_map_personality() -> void:
	## Adjust AI behavior based on which map is being played.
	## Called once during setup. Map-specific adjustments to aggression thresholds,
	## expansion patterns, and attack routing would go here.
	match _map_id:
		"blood_vessel":
			# Blood Vessel: lane-based map favors lane control and chokepoint defense
			# TODO: Prefer building towers at capillary entrances
			# TODO: Route attacks along lanes rather than direct paths
			# TODO: Contest center lane resources more aggressively
			pass
		"brain_cortex":
			# Brain Cortex: irregular terrain favors holding gyri and central plateau
			# TODO: Prioritize capturing high-ground gyri
			# TODO: Use sulci for flanking maneuvers
			# TODO: Build defenses around central plateau
			pass
		_:  # petri_dish
			# Default circular map — existing behavior is tuned for this
			pass

# === SERIALIZATION ===

func serialize() -> Dictionary:
	return {
		"faction_id": faction_id,
		"difficulty": difficulty,
		"phase": _phase,
		"decision_timer": _decision_timer,
		"time": _time,
		"taunt_timer": _taunt_timer,
		"grace_period": _grace_period,
		"grace_active": _grace_active,
		"workers_built": _workers_built,
		"combat_units_built": _combat_units_built,
		"buildings_built": _buildings_built,
		"map_id": _map_id,
	}

func deserialize(data: Dictionary) -> void:
	difficulty = data.get("difficulty", Difficulty.MEDIUM) as Difficulty
	_phase = data.get("phase", AIPhase.OPENING) as AIPhase
	_decision_timer = data.get("decision_timer", 0.0)
	_time = data.get("time", 0.0)
	_taunt_timer = data.get("taunt_timer", 0.0)
	_grace_period = data.get("grace_period", 0.0)
	_grace_active = data.get("grace_active", false)
	_workers_built = data.get("workers_built", 0)
	_combat_units_built = data.get("combat_units_built", 0)
	_buildings_built = data.get("buildings_built", 0)
	_map_id = data.get("map_id", "petri_dish")

# === AI TAUNTS ===

func _emit_taunt() -> void:
	## Pick a random phase-appropriate taunt and emit it.
	var messages: Array = _taunt_messages.get(_phase, [])
	if messages.is_empty():
		return
	var msg: String = messages[randi() % messages.size()]
	ai_taunt.emit(faction_id, msg)

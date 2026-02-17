extends Node
## Per-faction tech tree tracking upgrades, tier unlocks, and stat modifiers.
## Researched from Evolution Chamber (unit upgrades) and specific buildings (building upgrades).

signal upgrade_completed(faction_id: int, upgrade_id: int)
signal building_upgrade_completed(faction_id: int, upgrade_id: int)
signal tier_unlocked(faction_id: int, tier: int)

enum UpgradeId {
	HARDENED_MEMBRANES = 0,
	METABOLIC_BOOST = 1,
	SHARPENED_CILIA = 2,
	REGENERATIVE_TISSUE = 3,
	EXTENDED_PSEUDOPODS = 4,
	RAPID_MITOSIS = 5,
	BERSERKER_ENZYMES = 6,
	HIVE_MIND = 7,
	APEX_PREDATOR = 8,
}

enum BuildingUpgradeId {
	HATCHERY = 0,
	SPINE_TOWER = 1,
	REFINERY = 2,
}

# === UPGRADE DATA ===

const UPGRADE_DATA: Dictionary = {
	# --- Tier 1 ---
	UpgradeId.HARDENED_MEMBRANES: {
		"name": "Hardened Membranes",
		"description": "+2 armor to all units",
		"tier": 1,
		"cost_biomass": 100,
		"cost_genes": 25,
		"research_time": 20.0,
		"icon_color": Color(0.6, 0.7, 0.9),
	},
	UpgradeId.METABOLIC_BOOST: {
		"name": "Metabolic Boost",
		"description": "+15% movement speed",
		"tier": 1,
		"cost_biomass": 100,
		"cost_genes": 25,
		"research_time": 20.0,
		"icon_color": Color(0.4, 0.9, 0.5),
	},
	UpgradeId.SHARPENED_CILIA: {
		"name": "Sharpened Cilia",
		"description": "+3 damage to all units",
		"tier": 1,
		"cost_biomass": 100,
		"cost_genes": 25,
		"research_time": 20.0,
		"icon_color": Color(0.9, 0.4, 0.4),
	},
	# --- Tier 2 ---
	UpgradeId.REGENERATIVE_TISSUE: {
		"name": "Regenerative Tissue",
		"description": "1 HP/s regen out of combat",
		"tier": 2,
		"cost_biomass": 200,
		"cost_genes": 50,
		"research_time": 30.0,
		"icon_color": Color(0.3, 0.9, 0.7),
	},
	UpgradeId.EXTENDED_PSEUDOPODS: {
		"name": "Extended Pseudopods",
		"description": "Melee +20 range, Ranged +50 range",
		"tier": 2,
		"cost_biomass": 200,
		"cost_genes": 50,
		"research_time": 30.0,
		"icon_color": Color(0.8, 0.6, 0.9),
	},
	UpgradeId.RAPID_MITOSIS: {
		"name": "Rapid Mitosis",
		"description": "25% faster unit production",
		"tier": 2,
		"cost_biomass": 200,
		"cost_genes": 50,
		"research_time": 30.0,
		"icon_color": Color(0.9, 0.9, 0.3),
	},
	# --- Tier 3 ---
	UpgradeId.BERSERKER_ENZYMES: {
		"name": "Berserker Enzymes",
		"description": "2x damage below 30% HP",
		"tier": 3,
		"cost_biomass": 350,
		"cost_genes": 100,
		"research_time": 45.0,
		"icon_color": Color(1.0, 0.3, 0.2),
	},
	UpgradeId.HIVE_MIND: {
		"name": "Hive Mind",
		"description": "+2 armor per ally within 80u (max +6)",
		"tier": 3,
		"cost_biomass": 350,
		"cost_genes": 100,
		"research_time": 45.0,
		"icon_color": Color(0.5, 0.5, 1.0),
	},
	UpgradeId.APEX_PREDATOR: {
		"name": "Apex Predator",
		"description": "2x veterancy XP gain",
		"tier": 3,
		"cost_biomass": 350,
		"cost_genes": 100,
		"research_time": 45.0,
		"icon_color": Color(1.0, 0.8, 0.2),
	},
}

const BUILDING_UPGRADE_DATA: Dictionary = {
	BuildingUpgradeId.HATCHERY: {
		"name": "Hatchery",
		"description": "+10 supply, +1 queue slot",
		"target_building": BuildingStats.BuildingType.SPAWNING_POOL,
		"cost_biomass": 250,
		"cost_genes": 50,
		"research_time": 20.0,
		"icon_color": Color(0.5, 0.8, 0.6),
	},
	BuildingUpgradeId.SPINE_TOWER: {
		"name": "Spine Tower",
		"description": "1.5x damage, +50 range",
		"target_building": BuildingStats.BuildingType.MEMBRANE_TOWER,
		"cost_biomass": 150,
		"cost_genes": 30,
		"research_time": 15.0,
		"icon_color": Color(0.9, 0.5, 0.4),
	},
	BuildingUpgradeId.REFINERY: {
		"name": "Refinery",
		"description": "1.5x gather rate in 200u",
		"target_building": BuildingStats.BuildingType.NUTRIENT_PROCESSOR,
		"cost_biomass": 200,
		"cost_genes": 40,
		"research_time": 18.0,
		"icon_color": Color(0.6, 0.9, 0.4),
	},
}

# Tier requirements: how many upgrades needed + cost to unlock
const TIER_REQUIREMENTS: Dictionary = {
	1: {"upgrades_needed": 0, "cost_biomass": 0, "cost_genes": 0},
	2: {"upgrades_needed": 1, "cost_biomass": 200, "cost_genes": 50},
	3: {"upgrades_needed": 3, "cost_biomass": 400, "cost_genes": 100},
}

# === PER-FACTION STATE ===

# faction_id -> Array of UpgradeId that have been completed
var _faction_upgrades: Dictionary = {}
# faction_id -> Array of BuildingUpgradeId that have been completed
var _faction_building_upgrades: Dictionary = {}
# faction_id -> current highest unlocked tier (starts at 1)
var _faction_tier: Dictionary = {}

func setup(num_factions: int) -> void:
	_faction_upgrades.clear()
	_faction_building_upgrades.clear()
	_faction_tier.clear()
	for i in range(num_factions):
		_faction_upgrades[i] = []
		_faction_building_upgrades[i] = []
		_faction_tier[i] = 1

# === QUERY METHODS ===

func has_upgrade(faction_id: int, upgrade_id: int) -> bool:
	return upgrade_id in _faction_upgrades.get(faction_id, [])

func has_building_upgrade(faction_id: int, upgrade_id: int) -> bool:
	return upgrade_id in _faction_building_upgrades.get(faction_id, [])

func get_faction_tier(faction_id: int) -> int:
	return _faction_tier.get(faction_id, 1)

func get_completed_count(faction_id: int) -> int:
	return _faction_upgrades.get(faction_id, []).size()

func can_research(faction_id: int, upgrade_id: int) -> bool:
	## Check if a unit upgrade can be researched by this faction.
	if has_upgrade(faction_id, upgrade_id):
		return false  # Already researched
	if upgrade_id not in UPGRADE_DATA:
		return false
	var data: Dictionary = UPGRADE_DATA[upgrade_id]
	var required_tier: int = data.get("tier", 1)
	if get_faction_tier(faction_id) < required_tier:
		return false  # Tier not unlocked
	return true

func can_research_building_upgrade(faction_id: int, upgrade_id: int) -> bool:
	## Check if a building upgrade can be researched.
	if has_building_upgrade(faction_id, upgrade_id):
		return false
	if upgrade_id not in BUILDING_UPGRADE_DATA:
		return false
	return true

func can_unlock_tier(faction_id: int, tier: int) -> bool:
	## Check if the faction can unlock a specific tier.
	if tier <= get_faction_tier(faction_id):
		return false  # Already unlocked
	if tier not in TIER_REQUIREMENTS:
		return false
	var req: Dictionary = TIER_REQUIREMENTS[tier]
	return get_completed_count(faction_id) >= req.get("upgrades_needed", 0)

func get_available_upgrades(faction_id: int) -> Array:
	## Returns array of UpgradeId values currently available for research.
	var available: Array = []
	var tier: int = get_faction_tier(faction_id)
	for uid in UPGRADE_DATA:
		if has_upgrade(faction_id, uid):
			continue
		var data: Dictionary = UPGRADE_DATA[uid]
		if data.get("tier", 1) <= tier:
			available.append(uid)
	return available

func get_available_building_upgrades(faction_id: int) -> Array:
	## Returns array of BuildingUpgradeId values currently available.
	var available: Array = []
	for uid in BUILDING_UPGRADE_DATA:
		if not has_building_upgrade(faction_id, uid):
			available.append(uid)
	return available

# === MUTATION METHODS ===

func complete_upgrade(faction_id: int, upgrade_id: int) -> void:
	## Register a completed unit upgrade for a faction.
	if faction_id not in _faction_upgrades:
		return
	if upgrade_id in _faction_upgrades[faction_id]:
		return
	_faction_upgrades[faction_id].append(upgrade_id)
	upgrade_completed.emit(faction_id, upgrade_id)

func complete_building_upgrade(faction_id: int, upgrade_id: int) -> void:
	## Register a completed building upgrade for a faction.
	if faction_id not in _faction_building_upgrades:
		return
	if upgrade_id in _faction_building_upgrades[faction_id]:
		return
	_faction_building_upgrades[faction_id].append(upgrade_id)
	building_upgrade_completed.emit(faction_id, upgrade_id)

func unlock_tier(faction_id: int, tier: int) -> bool:
	## Attempt to unlock a tier for a faction. Returns true if successful.
	if not can_unlock_tier(faction_id, tier):
		return false
	# Cost is handled by the caller (building/HUD should spend resources)
	_faction_tier[faction_id] = tier
	tier_unlocked.emit(faction_id, tier)
	return true

# === STAT MODIFIER METHODS ===
# Called by units to apply tech tree bonuses.

func get_armor_bonus(faction_id: int) -> float:
	## +2 armor from Hardened Membranes
	if has_upgrade(faction_id, UpgradeId.HARDENED_MEMBRANES):
		return 2.0
	return 0.0

func get_speed_mult(faction_id: int) -> float:
	## 1.15x speed from Metabolic Boost
	if has_upgrade(faction_id, UpgradeId.METABOLIC_BOOST):
		return 1.15
	return 1.0

func get_damage_bonus(faction_id: int) -> float:
	## +3 damage from Sharpened Cilia
	if has_upgrade(faction_id, UpgradeId.SHARPENED_CILIA):
		return 3.0
	return 0.0

func get_regen_rate(faction_id: int) -> float:
	## 1 HP/s from Regenerative Tissue (out of combat)
	if has_upgrade(faction_id, UpgradeId.REGENERATIVE_TISSUE):
		return 1.0
	return 0.0

func get_range_bonus(faction_id: int, is_ranged: bool) -> float:
	## Melee +20, Ranged +50 from Extended Pseudopods
	if has_upgrade(faction_id, UpgradeId.EXTENDED_PSEUDOPODS):
		return 50.0 if is_ranged else 20.0
	return 0.0

func get_production_mult(faction_id: int) -> float:
	## 0.75x production time from Rapid Mitosis (25% faster)
	if has_upgrade(faction_id, UpgradeId.RAPID_MITOSIS):
		return 0.75
	return 1.0

func get_berserker_mult(faction_id: int, hp_ratio: float) -> float:
	## 2x damage when below 30% HP from Berserker Enzymes
	if has_upgrade(faction_id, UpgradeId.BERSERKER_ENZYMES) and hp_ratio < 0.3:
		return 2.0
	return 1.0

func get_hive_armor(faction_id: int, nearby_count: int) -> float:
	## +2 armor per nearby ally (max +6) from Hive Mind
	if has_upgrade(faction_id, UpgradeId.HIVE_MIND):
		return minf(float(nearby_count) * 2.0, 6.0)
	return 0.0

func get_xp_mult(faction_id: int) -> float:
	## 2x veterancy XP from Apex Predator
	if has_upgrade(faction_id, UpgradeId.APEX_PREDATOR):
		return 2.0
	return 1.0

# === BUILDING UPGRADE STAT HELPERS ===

func get_tower_damage_mult(faction_id: int) -> float:
	## 1.5x tower damage from Spine Tower upgrade
	if has_building_upgrade(faction_id, BuildingUpgradeId.SPINE_TOWER):
		return 1.5
	return 1.0

func get_tower_range_bonus(faction_id: int) -> float:
	## +50 tower range from Spine Tower upgrade
	if has_building_upgrade(faction_id, BuildingUpgradeId.SPINE_TOWER):
		return 50.0
	return 0.0

func get_supply_bonus(faction_id: int) -> int:
	## +10 supply from Hatchery upgrade (per upgraded Spawning Pool)
	if has_building_upgrade(faction_id, BuildingUpgradeId.HATCHERY):
		return 10
	return 0

func get_gather_rate_mult(faction_id: int) -> float:
	## 1.5x gather rate from Refinery upgrade
	if has_building_upgrade(faction_id, BuildingUpgradeId.REFINERY):
		return 1.5
	return 1.0

func get_refinery_radius() -> float:
	## Radius within which the Refinery bonus applies
	return 200.0

# === UTILITY ===

static func get_upgrade_name(upgrade_id: int) -> String:
	if upgrade_id in UPGRADE_DATA:
		return UPGRADE_DATA[upgrade_id].get("name", "Unknown")
	return "Unknown"

static func get_building_upgrade_name(upgrade_id: int) -> String:
	if upgrade_id in BUILDING_UPGRADE_DATA:
		return BUILDING_UPGRADE_DATA[upgrade_id].get("name", "Unknown")
	return "Unknown"

static func get_tier_name(tier: int) -> String:
	match tier:
		1: return "Tier I"
		2: return "Tier II"
		3: return "Tier III"
	return "Unknown"

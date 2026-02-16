class_name UnitStats
## Static unit type definitions for the RTS stage.
## 5 unit types: WORKER, FIGHTER, DEFENDER, SCOUT, RANGED

enum UnitType { WORKER, FIGHTER, DEFENDER, SCOUT, RANGED }

const UNIT_DATA: Dictionary = {
	UnitType.WORKER: {
		"name": "Gatherer",
		"hp": 60,
		"armor": 0,
		"speed": 100.0,
		"damage": 5,
		"attack_range": 25.0,
		"attack_cooldown": 1.0,
		"cost_biomass": 50,
		"cost_genes": 0,
		"build_time": 4.0,
		"carry_capacity": 10,
		"build_speed": 1.0,
		"detection_range": 200.0,
		"supply_cost": 1,
		"can_build": true,
		"can_gather": true,
	},
	UnitType.FIGHTER: {
		"name": "Warrior",
		"hp": 120,
		"armor": 2,
		"speed": 110.0,
		"damage": 15,
		"attack_range": 30.0,
		"attack_cooldown": 0.8,
		"cost_biomass": 80,
		"cost_genes": 10,
		"build_time": 6.0,
		"carry_capacity": 0,
		"build_speed": 0.0,
		"detection_range": 200.0,
		"supply_cost": 2,
		"can_build": false,
		"can_gather": false,
		"charge_bonus": 1.5,  # +50% damage on first hit after moving
	},
	UnitType.DEFENDER: {
		"name": "Tank",
		"hp": 220,
		"armor": 5,
		"speed": 70.0,
		"damage": 8,
		"attack_range": 25.0,
		"attack_cooldown": 1.2,
		"cost_biomass": 120,
		"cost_genes": 20,
		"build_time": 10.0,
		"carry_capacity": 0,
		"build_speed": 0.0,
		"detection_range": 200.0,
		"supply_cost": 3,
		"can_build": false,
		"can_gather": false,
		"taunt_radius": 80.0,  # Enemies prefer attacking this unit
	},
	UnitType.SCOUT: {
		"name": "Scout",
		"hp": 50,
		"armor": 0,
		"speed": 180.0,
		"damage": 6,
		"attack_range": 25.0,
		"attack_cooldown": 0.6,
		"cost_biomass": 40,
		"cost_genes": 5,
		"build_time": 3.0,
		"carry_capacity": 0,
		"build_speed": 0.0,
		"detection_range": 400.0,  # Double detection range
		"supply_cost": 1,
		"can_build": false,
		"can_gather": false,
	},
	UnitType.RANGED: {
		"name": "Spitter",
		"hp": 70,
		"armor": 0,
		"speed": 90.0,
		"damage": 12,
		"attack_range": 200.0,
		"attack_cooldown": 1.5,
		"cost_biomass": 90,
		"cost_genes": 15,
		"build_time": 8.0,
		"carry_capacity": 0,
		"build_speed": 0.0,
		"detection_range": 250.0,
		"supply_cost": 2,
		"can_build": false,
		"can_gather": false,
		"min_range": 40.0,  # Can't fire at melee range
		"projectile_speed": 300.0,
	},
}

static func get_stats(unit_type: int) -> Dictionary:
	if unit_type in UNIT_DATA:
		return UNIT_DATA[unit_type]
	return UNIT_DATA[UnitType.WORKER]

static func get_name(unit_type: int) -> String:
	return get_stats(unit_type).get("name", "Unknown")

static func get_cost(unit_type: int) -> Dictionary:
	var stats: Dictionary = get_stats(unit_type)
	return {"biomass": stats.get("cost_biomass", 0), "genes": stats.get("cost_genes", 0)}

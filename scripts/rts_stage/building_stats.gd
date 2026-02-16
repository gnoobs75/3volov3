class_name BuildingStats
## Static building type definitions for the RTS stage.
## 5 building types with costs, stats, and functionality.

enum BuildingType { SPAWNING_POOL, EVOLUTION_CHAMBER, MEMBRANE_TOWER, BIO_WALL, NUTRIENT_PROCESSOR }

const BUILDING_DATA: Dictionary = {
	BuildingType.SPAWNING_POOL: {
		"name": "Spawning Pool",
		"hp": 500,
		"armor": 5,
		"cost_biomass": 300,
		"cost_genes": 0,
		"build_time": 15.0,
		"size_radius": 40.0,
		"is_depot": true,
		"is_production": true,
		"can_produce": [UnitStats.UnitType.WORKER],
		"supply_provided": 10,
		"is_main_base": true,
		"attack_range": 0.0,
		"attack_damage": 0,
	},
	BuildingType.EVOLUTION_CHAMBER: {
		"name": "Evolution Chamber",
		"hp": 350,
		"armor": 3,
		"cost_biomass": 200,
		"cost_genes": 50,
		"build_time": 12.0,
		"size_radius": 35.0,
		"is_depot": false,
		"is_production": true,
		"can_produce": [UnitStats.UnitType.FIGHTER, UnitStats.UnitType.DEFENDER, UnitStats.UnitType.SCOUT, UnitStats.UnitType.RANGED],
		"supply_provided": 5,
		"is_main_base": false,
		"attack_range": 0.0,
		"attack_damage": 0,
	},
	BuildingType.MEMBRANE_TOWER: {
		"name": "Membrane Tower",
		"hp": 250,
		"armor": 3,
		"cost_biomass": 100,
		"cost_genes": 15,
		"build_time": 8.0,
		"size_radius": 20.0,
		"is_depot": false,
		"is_production": false,
		"can_produce": [],
		"supply_provided": 0,
		"is_main_base": false,
		"attack_range": 200.0,
		"attack_damage": 10,
		"attack_cooldown": 1.5,
	},
	BuildingType.BIO_WALL: {
		"name": "Bio-Wall",
		"hp": 400,
		"armor": 8,
		"cost_biomass": 30,
		"cost_genes": 0,
		"build_time": 3.0,
		"size_radius": 15.0,
		"is_depot": false,
		"is_production": false,
		"can_produce": [],
		"supply_provided": 0,
		"is_main_base": false,
		"attack_range": 0.0,
		"attack_damage": 0,
	},
	BuildingType.NUTRIENT_PROCESSOR: {
		"name": "Nutrient Processor",
		"hp": 300,
		"armor": 2,
		"cost_biomass": 150,
		"cost_genes": 0,
		"build_time": 10.0,
		"size_radius": 30.0,
		"is_depot": true,
		"is_production": false,
		"can_produce": [],
		"supply_provided": 5,
		"is_main_base": false,
		"attack_range": 0.0,
		"attack_damage": 0,
	},
}

static func get_stats(building_type: int) -> Dictionary:
	if building_type in BUILDING_DATA:
		return BUILDING_DATA[building_type]
	return BUILDING_DATA[BuildingType.BIO_WALL]

static func get_name(building_type: int) -> String:
	return get_stats(building_type).get("name", "Unknown")

static func get_cost(building_type: int) -> Dictionary:
	var stats: Dictionary = get_stats(building_type)
	return {"biomass": stats.get("cost_biomass", 0), "genes": stats.get("cost_genes", 0)}

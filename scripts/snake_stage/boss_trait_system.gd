class_name BossTraitSystem
extends RefCounted
## Static utility: Boss trait definitions, energy costs, damage values per tier.
## Traits are looted from defeated biome bosses and activated via radial menu (Hold Q).

const TRAIT_DATA: Dictionary = {
	"pulse_wave": {
		"name": "Pulse Wave",
		"desc": "AoE knockback ring centered on the player",
		"boss": "Cardiac Colossus",
		"biome": "Heart Chamber",
		"icon_color": Color(0.9, 0.2, 0.3),
		"base_energy": 25.0,
		"base_damage": 15.0,
		"base_radius": 12.0,
		"base_knockback": 15.0,
		"cooldown": 6.0,
	},
	"acid_spit": {
		"name": "Acid Spit",
		"desc": "Ranged acid projectile. Sticks to enemies, deals DoT.",
		"boss": "Gut Warden",
		"biome": "Intestinal Tract",
		"icon_color": Color(0.4, 0.9, 0.1),
		"base_energy": 20.0,
		"base_damage": 8.0,
		"base_dot_dps": 5.0,
		"base_dot_duration": 4.0,
		"base_speed": 25.0,
		"cooldown": 4.0,
	},
	"wind_gust": {
		"name": "Wind Gust",
		"desc": "Directional cone push. Shoves enemies away.",
		"boss": "Alveolar Titan",
		"biome": "Lung Tissue",
		"icon_color": Color(0.5, 0.7, 0.9),
		"base_energy": 18.0,
		"base_damage": 8.0,
		"base_knockback": 20.0,
		"base_range": 15.0,
		"base_cone": 0.5,  # Dot product threshold
		"cooldown": 5.0,
	},
	"bone_shield": {
		"name": "Bone Shield",
		"desc": "Temporary invulnerability shield.",
		"boss": "Marrow Sentinel",
		"biome": "Bone Marrow",
		"icon_color": Color(0.9, 0.85, 0.6),
		"base_energy": 30.0,
		"base_duration": 3.0,
		"cooldown": 15.0,
	},
	"summon_minions": {
		"name": "Summon Minions",
		"desc": "Spawn allied creatures to fight for you.",
		"boss": "Macrophage Queen",
		"biome": "Brain",
		"icon_color": Color(0.7, 0.3, 0.9),
		"base_energy": 35.0,
		"base_count": 2,
		"base_minion_hp": 30.0,
		"base_minion_damage": 5.0,
		"cooldown": 20.0,
	},
}

static func get_trait(trait_id: String) -> Dictionary:
	return TRAIT_DATA.get(trait_id, {})

static func get_energy_cost(trait_id: String) -> float:
	var data: Dictionary = get_trait(trait_id)
	if data.is_empty():
		return 999.0
	var base: float = data.get("base_energy", 25.0)
	var mult: float = GameManager.get_trait_multiplier(trait_id)
	# Higher tier = cheaper (inverse scaling for energy)
	return base / (1.0 + (mult - 1.0) * 0.5)

static func get_damage(trait_id: String) -> float:
	var data: Dictionary = get_trait(trait_id)
	return data.get("base_damage", 10.0) * GameManager.get_trait_multiplier(trait_id)

static func get_radius(trait_id: String) -> float:
	var data: Dictionary = get_trait(trait_id)
	return data.get("base_radius", 10.0) * (1.0 + (GameManager.get_trait_multiplier(trait_id) - 1.0) * 0.3)

static func get_cooldown(trait_id: String) -> float:
	var data: Dictionary = get_trait(trait_id)
	return data.get("cooldown", 5.0)

static func get_all_trait_ids() -> Array:
	return TRAIT_DATA.keys()

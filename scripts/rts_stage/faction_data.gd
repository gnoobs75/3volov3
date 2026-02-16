class_name FactionData
## Static faction definitions for the RTS stage.
## 4 factions with unique traits, colors, and eye styles.

enum FactionID { PLAYER, SWARM, BULWARK, PREDATOR }

const FACTIONS: Array = [
	{
		"id": FactionID.PLAYER,
		"name": "Player Colony",
		"trait_name": "Adaptive",
		"description": "Uses evolved mutations from cell stage",
		"color": Color(0.3, 0.6, 1.0),
		"color_dark": Color(0.15, 0.3, 0.5),
		"color_glow": Color(0.4, 0.7, 1.0),
		"eye_style": "anime",
		"build_speed_mult": 1.0,
		"gather_mult": 1.0,
		"hp_mult": 1.0,
		"armor_mult": 1.0,
		"attack_mult": 1.0,
		"speed_mult": 1.0,
		"building_hp_mult": 1.0,
	},
	{
		"id": FactionID.SWARM,
		"name": "The Swarming Tide",
		"trait_name": "Prolific",
		"description": "+25% build speed, +15% gather, -10% HP",
		"color": Color(0.3, 0.9, 0.4),
		"color_dark": Color(0.15, 0.45, 0.2),
		"color_glow": Color(0.4, 1.0, 0.5),
		"eye_style": "compound",
		"build_speed_mult": 1.25,
		"gather_mult": 1.15,
		"hp_mult": 0.9,
		"armor_mult": 1.0,
		"attack_mult": 1.0,
		"speed_mult": 1.0,
		"building_hp_mult": 1.0,
	},
	{
		"id": FactionID.BULWARK,
		"name": "The Calcified Bulwark",
		"trait_name": "Fortified",
		"description": "+20% building HP, +15% armor, -15% speed",
		"color": Color(1.0, 0.85, 0.3),
		"color_dark": Color(0.5, 0.42, 0.15),
		"color_glow": Color(1.0, 0.9, 0.4),
		"eye_style": "slit",
		"build_speed_mult": 1.0,
		"gather_mult": 1.0,
		"hp_mult": 1.0,
		"armor_mult": 1.15,
		"attack_mult": 1.0,
		"speed_mult": 0.85,
		"building_hp_mult": 1.2,
	},
	{
		"id": FactionID.PREDATOR,
		"name": "The Crimson Maw",
		"trait_name": "Predatory",
		"description": "+20% attack, +10% speed, -20% building HP",
		"color": Color(0.9, 0.2, 0.2),
		"color_dark": Color(0.45, 0.1, 0.1),
		"color_glow": Color(1.0, 0.3, 0.3),
		"eye_style": "fierce",
		"build_speed_mult": 1.0,
		"gather_mult": 1.0,
		"hp_mult": 1.0,
		"armor_mult": 1.0,
		"attack_mult": 1.2,
		"speed_mult": 1.1,
		"building_hp_mult": 0.8,
	},
]

static func get_faction(id: int) -> Dictionary:
	if id >= 0 and id < FACTIONS.size():
		return FACTIONS[id]
	return FACTIONS[0]

static func get_faction_color(id: int) -> Color:
	if id < 0:
		return Color(0.7, 0.25, 0.15)  # Neutral hostile — orange-red
	return get_faction(id).get("color", Color.WHITE)

static func get_faction_name(id: int) -> String:
	return get_faction(id).get("name", "Unknown")

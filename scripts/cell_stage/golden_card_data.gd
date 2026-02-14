class_name GoldenCardData
## Static data class: golden AOE ability cards that appear every 3 evolution levels.

const GOLDEN_CARDS: Array = [
	{
		"id": "poison_cloud",
		"name": "Toxic Miasma",
		"desc": "Release a noxious cloud that terrifies all nearby enemies, causing them to flee in panic.",
		"gameplay_desc": "Press MMB to release a poison cloud. All enemies within range flee for 3.5 seconds. 15s cooldown.",
		"color": Color(0.2, 0.85, 0.3),
		"vfx_color": Color(0.3, 0.9, 0.2, 0.6),
		"aoe_radius": 150.0,
		"duration": 3.5,
		"cooldown": 15.0,
		"effect_type": "flee",
	},
	{
		"id": "electric_shock",
		"name": "Chain Lightning",
		"desc": "Unleash a burst of electricity that stuns all nearby enemies, disrupting their movement.",
		"gameplay_desc": "Press MMB to stun all nearby enemies for 2.5 seconds. Great for escaping swarms. 15s cooldown.",
		"color": Color(0.3, 0.5, 1.0),
		"vfx_color": Color(0.4, 0.7, 1.0, 0.8),
		"aoe_radius": 140.0,
		"duration": 2.5,
		"cooldown": 15.0,
		"effect_type": "stun",
	},
	{
		"id": "healing_aura",
		"name": "Regenerative Burst",
		"desc": "Channel vital energy to rapidly restore health and gain temporary invulnerability.",
		"gameplay_desc": "Press MMB to fully heal and become invulnerable for 2.5 seconds. Emergency lifesaver. 15s cooldown.",
		"color": Color(1.0, 0.85, 0.2),
		"vfx_color": Color(1.0, 0.9, 0.3, 0.8),
		"aoe_radius": 0.0,
		"duration": 2.5,
		"cooldown": 15.0,
		"effect_type": "heal",
	},
]

static func get_card_by_id(card_id: String) -> Dictionary:
	for card in GOLDEN_CARDS:
		if card["id"] == card_id:
			return card
	return {}

static func generate_golden_choice(exclude_id: String = "") -> Dictionary:
	## Pick a random golden card, excluding the currently equipped one.
	var pool: Array = []
	for card in GOLDEN_CARDS:
		if card["id"] != exclude_id:
			pool.append(card)
	if pool.is_empty():
		return GOLDEN_CARDS[randi() % GOLDEN_CARDS.size()]
	return pool[randi() % pool.size()]

class_name EvolutionData
## Static class: mutation pools, choice generation, category affinities.

# All possible mutations with visual + stat definitions
const MUTATIONS: Array = [
	{
		"id": "extra_cilia",
		"name": "Extra Cilia",
		"desc": "Grow additional cilia for faster movement",
		"visual": "extra_cilia",
		"stat": {"speed": 0.12},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["lipids", "amino_acids"],
	},
	{
		"id": "spikes",
		"name": "Defensive Spines",
		"desc": "Radiating spines that boost attack power",
		"visual": "spikes",
		"stat": {"attack": 0.2},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["amino_acids", "organic_acids"],
	},
	{
		"id": "armor_plates",
		"name": "Armor Plating",
		"desc": "Thick chitin plates protect against damage",
		"visual": "armor_plates",
		"stat": {"max_health": 0.15, "armor": 0.1},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["amino_acids", "lipids"],
	},
	{
		"id": "color_shift",
		"name": "Chromatophore Camouflage",
		"desc": "Shift colors to blend with surroundings",
		"visual": "color_shift",
		"stat": {"stealth": 0.2},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["coenzymes", "lipids"],
	},
	{
		"id": "bioluminescence",
		"name": "Bioluminescence",
		"desc": "Emit bright light to detect threats",
		"visual": "bioluminescence",
		"stat": {"detection": 0.15},
		"tier": 1,
		"sensory_upgrade": true,
		"affinities": ["coenzymes", "nucleotides"],
	},
	{
		"id": "flagellum",
		"name": "Flagellum Motor",
		"desc": "A powerful whip tail for rapid bursts",
		"visual": "flagellum",
		"stat": {"speed": 0.18},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["lipids", "nucleotides"],
	},
	{
		"id": "third_eye",
		"name": "Primitive Ocellus",
		"desc": "A light-sensing eye spot improves vision",
		"visual": "third_eye",
		"stat": {"beam_range": 0.1},
		"tier": 1,
		"sensory_upgrade": true,
		"affinities": ["nucleotides", "nucleotide_bases"],
	},
	{
		"id": "eye_stalks",
		"name": "Eye Stalks",
		"desc": "Eyes on stalks give wider field of view",
		"visual": "eye_stalks",
		"stat": {"beam_range": 0.15, "detection": 0.1},
		"tier": 2,
		"sensory_upgrade": true,
		"affinities": ["nucleotides", "amino_acids"],
	},
	{
		"id": "tentacles",
		"name": "Prehensile Tentacles",
		"desc": "Trailing tentacles extend your reach",
		"visual": "tentacles",
		"stat": {"beam_range": 0.2},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["amino_acids", "organic_acids"],
	},
	{
		"id": "larger_membrane",
		"name": "Expanded Membrane",
		"desc": "Larger cell body absorbs more damage",
		"visual": "larger_membrane",
		"stat": {"max_health": 0.2},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["lipids", "monosaccharides"],
	},
	{
		"id": "toxin_glands",
		"name": "Toxin Glands",
		"desc": "Produce potent toxins for defense",
		"visual": "toxin_glands",
		"stat": {"attack": 0.25},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["organic_acids", "coenzymes"],
	},
	{
		"id": "photoreceptor",
		"name": "Photoreceptor Array",
		"desc": "Advanced light-sensing cells sharpen sight",
		"visual": "photoreceptor",
		"stat": {"detection": 0.12},
		"tier": 1,
		"sensory_upgrade": true,
		"affinities": ["nucleotide_bases", "coenzymes"],
	},
	{
		"id": "thick_membrane",
		"name": "Reinforced Membrane",
		"desc": "Double-layered membrane resists damage",
		"visual": "thick_membrane",
		"stat": {"armor": 0.15},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["lipids", "amino_acids"],
	},
	{
		"id": "enzyme_boost",
		"name": "Enzyme Overdrive",
		"desc": "Hyperactive enzymes improve metabolism",
		"visual": "enzyme_boost",
		"stat": {"energy_efficiency": 0.15},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["coenzymes", "monosaccharides"],
	},
	{
		"id": "regeneration",
		"name": "Regenerative Matrix",
		"desc": "Rapid cell repair heals over time",
		"visual": "regeneration",
		"stat": {"health_regen": 0.12},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["nucleotides", "monosaccharides"],
	},
	{
		"id": "sprint_boost",
		"name": "Myosin Accelerator",
		"desc": "Contractile proteins boost sprint power",
		"visual": "sprint_boost",
		"stat": {"speed": 0.1, "energy_efficiency": 0.08},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["amino_acids", "nucleotides"],
	},
	{
		"id": "compound_eye",
		"name": "Compound Eye",
		"desc": "Multi-faceted vision sees everything",
		"visual": "compound_eye",
		"stat": {"detection": 0.2, "beam_range": 0.1},
		"tier": 3,
		"sensory_upgrade": true,
		"affinities": ["nucleotide_bases", "nucleotides"],
	},
	{
		"id": "absorption_villi",
		"name": "Absorption Villi",
		"desc": "Tiny projections absorb nutrients faster",
		"visual": "absorption_villi",
		"stat": {"energy_efficiency": 0.2},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["monosaccharides", "organic_acids"],
	},
	{
		"id": "dorsal_fin",
		"name": "Dorsal Fin",
		"desc": "A stabilizing fin improves turning speed",
		"visual": "dorsal_fin",
		"stat": {"speed": 0.08},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["lipids", "amino_acids"],
	},
	{
		"id": "ink_sac",
		"name": "Ink Sac",
		"desc": "Eject ink clouds to confuse predators",
		"visual": "ink_sac",
		"stat": {"stealth": 0.15, "speed": 0.05},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["organic_acids", "coenzymes"],
	},
	{
		"id": "electric_organ",
		"name": "Electric Organ",
		"desc": "Bioelectric discharge stuns nearby threats",
		"visual": "electric_organ",
		"stat": {"attack": 0.15, "detection": 0.1},
		"tier": 3,
		"sensory_upgrade": true,
		"affinities": ["nucleotides", "coenzymes"],
	},
	{
		"id": "symbiont_pouch",
		"name": "Symbiont Pouch",
		"desc": "Carry helpful bacteria that boost healing",
		"visual": "symbiont_pouch",
		"stat": {"health_regen": 0.08, "max_health": 0.1},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["monosaccharides", "nucleotides"],
	},
	{
		"id": "hardened_nucleus",
		"name": "Hardened Nucleus",
		"desc": "A fortified nucleus protects your DNA",
		"visual": "hardened_nucleus",
		"stat": {"armor": 0.12, "max_health": 0.08},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["nucleotide_bases", "amino_acids"],
	},
	{
		"id": "pili_network",
		"name": "Pili Network",
		"desc": "Hair-like pili extend your sensory reach",
		"visual": "pili_network",
		"stat": {"detection": 0.15, "beam_range": 0.08},
		"tier": 1,
		"sensory_upgrade": true,
		"affinities": ["amino_acids", "lipids"],
	},
	{
		"id": "chrono_enzyme",
		"name": "Chrono-Enzyme",
		"desc": "Hyperactive metabolism makes everything faster",
		"visual": "chrono_enzyme",
		"stat": {"speed": 0.12, "energy_efficiency": 0.1},
		"tier": 3,
		"sensory_upgrade": false,
		"affinities": ["coenzymes", "nucleotides"],
	},
	{
		"id": "thermal_vent_organ",
		"name": "Thermal Vent Organ",
		"desc": "Absorb heat energy from the environment",
		"visual": "thermal_vent_organ",
		"stat": {"energy_efficiency": 0.18, "armor": 0.05},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["organic_acids", "lipids"],
	},
	{
		"id": "lateral_line",
		"name": "Lateral Line",
		"desc": "Sense vibrations in the water around you",
		"visual": "lateral_line",
		"stat": {"detection": 0.18},
		"tier": 2,
		"sensory_upgrade": true,
		"affinities": ["nucleotide_bases", "amino_acids"],
	},
	{
		"id": "beak",
		"name": "Chitinous Beak",
		"desc": "A sharp beak for tearing prey apart",
		"visual": "beak",
		"stat": {"attack": 0.2, "beam_range": 0.05},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["amino_acids", "organic_acids"],
	},
	{
		"id": "gas_vacuole",
		"name": "Gas Vacuole",
		"desc": "Buoyancy control for effortless gliding",
		"visual": "gas_vacuole",
		"stat": {"speed": 0.1, "energy_efficiency": 0.12},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["lipids", "monosaccharides"],
	},
	# --- DIRECTIONAL OFFENSIVE MUTATIONS ---
	{
		"id": "front_spike",
		"name": "Frontal Horn",
		"desc": "A piercing spike — ram enemies head-on for massive damage",
		"visual": "front_spike",
		"stat": {"attack": 0.3},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["amino_acids", "organic_acids"],
		"directional": "front",
		"damage_arc": 0.5,  # ~60 degrees cone
	},
	{
		"id": "mandibles",
		"name": "Crushing Mandibles",
		"desc": "Powerful jaws that must face prey to devour them",
		"visual": "mandibles",
		"stat": {"attack": 0.25, "beam_range": 0.1},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["amino_acids", "nucleotide_bases"],
		"directional": "front",
		"damage_arc": 0.7,
	},
	{
		"id": "side_barbs",
		"name": "Lateral Barbs",
		"desc": "Sharp barbs on your flanks damage anything brushing past",
		"visual": "side_barbs",
		"stat": {"attack": 0.15, "armor": 0.08},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["amino_acids", "lipids"],
		"directional": "sides",
		"damage_arc": 0.4,
	},
	{
		"id": "rear_stinger",
		"name": "Caudal Stinger",
		"desc": "A venomous tail spike — sting pursuers behind you",
		"visual": "rear_stinger",
		"stat": {"attack": 0.35},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["organic_acids", "coenzymes"],
		"directional": "rear",
		"damage_arc": 0.5,
	},
	{
		"id": "ramming_crest",
		"name": "Battering Crest",
		"desc": "A reinforced head for charging attacks",
		"visual": "ramming_crest",
		"stat": {"attack": 0.2, "armor": 0.1, "speed": 0.05},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["amino_acids", "lipids"],
		"directional": "front",
		"damage_arc": 0.6,
	},
	{
		"id": "proboscis",
		"name": "Feeding Proboscis",
		"desc": "A needle-like tongue to drain nutrients from prey you face",
		"visual": "proboscis",
		"stat": {"beam_range": 0.2, "energy_efficiency": 0.1},
		"tier": 2,
		"sensory_upgrade": false,
		"affinities": ["lipids", "coenzymes"],
		"directional": "front",
		"damage_arc": 0.4,
	},
	{
		"id": "tail_club",
		"name": "Tail Club",
		"desc": "A heavy tail that stuns enemies behind you",
		"visual": "tail_club",
		"stat": {"attack": 0.2, "armor": 0.05},
		"tier": 1,
		"sensory_upgrade": false,
		"affinities": ["amino_acids", "monosaccharides"],
		"directional": "rear",
		"damage_arc": 0.6,
	},
	{
		"id": "electroreceptors",
		"name": "Electroreceptors",
		"desc": "Sense bioelectric fields — detect hidden prey",
		"visual": "electroreceptors",
		"stat": {"detection": 0.2, "beam_range": 0.1},
		"tier": 2,
		"sensory_upgrade": true,
		"affinities": ["nucleotides", "nucleotide_bases"],
	},
	{
		"id": "antenna",
		"name": "Sensory Antennae",
		"desc": "Long antennae detect movement in front",
		"visual": "antenna",
		"stat": {"detection": 0.15, "speed": 0.05},
		"tier": 1,
		"sensory_upgrade": true,
		"affinities": ["nucleotide_bases", "amino_acids"],
		"directional": "front",
	},
]

# Category color mapping for card borders
const CATEGORY_COLORS: Dictionary = {
	"nucleotides": Color(1.0, 0.9, 0.1),
	"monosaccharides": Color(0.9, 0.7, 0.2),
	"amino_acids": Color(0.6, 0.9, 0.4),
	"coenzymes": Color(0.4, 0.6, 1.0),
	"lipids": Color(0.3, 0.7, 0.9),
	"nucleotide_bases": Color(0.9, 0.3, 0.3),
	"organic_acids": Color(0.8, 0.5, 0.1),
	"organelles": Color(0.2, 0.9, 0.3),
}

static func generate_choices(category: String, evo_level: int) -> Array[Dictionary]:
	## Generate 3 unique mutation choices, weighted by category affinity
	var pool: Array[Dictionary] = []
	var already_have: Array[String] = []
	for m in GameManager.active_mutations:
		already_have.append(m.get("id", ""))

	# At sensory level 0 and first evolution, guarantee a sensory option
	var force_sensory: bool = GameManager.sensory_level == 0 and evo_level == 0

	for m in MUTATIONS:
		if m["id"] in already_have:
			continue
		# Tier filter: higher tier available at higher evolution levels
		if m.get("tier", 1) > evo_level + 1:
			continue
		pool.append(m)

	if pool.is_empty():
		# Fallback: allow repeats with boosted stats
		for m in MUTATIONS:
			pool.append(m)

	# Weight by affinity: mutations matching the consumed category get 3x weight
	var weighted: Array[Dictionary] = []
	for m in pool:
		var affinities: Array = m.get("affinities", [])
		var weight: int = 1
		if category in affinities:
			weight = 3
		for w in range(weight):
			weighted.append(m)

	# Pick 3 unique
	var choices: Array[Dictionary] = []
	var chosen_ids: Array[String] = []

	# Force sensory option first if needed
	if force_sensory:
		for m in pool:
			if m.get("sensory_upgrade", false) and m["id"] not in chosen_ids:
				choices.append(m)
				chosen_ids.append(m["id"])
				break

	var attempts: int = 0
	while choices.size() < 3 and attempts < 50:
		attempts += 1
		var pick: Dictionary = weighted[randi() % weighted.size()]
		if pick["id"] not in chosen_ids:
			choices.append(pick)
			chosen_ids.append(pick["id"])

	# Scale stats by evolution level (slight power increase)
	var scale: float = 1.0 + evo_level * 0.1
	for c in choices:
		var scaled: Dictionary = c.duplicate(true)
		var stat: Dictionary = scaled.get("stat", {})
		var new_stat: Dictionary = {}
		for key in stat:
			new_stat[key] = stat[key] * scale
		scaled["stat"] = new_stat
		choices[choices.find(c)] = scaled

	return choices

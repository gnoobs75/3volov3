class_name ForgeCalculator
## Static utility: mutation forging viability, stat combination, upgrade costs.
## Used by GameManager and the CRISPR Workshop UI.

# Upgrade costs: gene fragments needed per tier transition
const UPGRADE_COST_T1_TO_T2: int = 15
const UPGRADE_COST_T2_TO_T3: int = 30

# Tier stat multipliers
const TIER_MULTIPLIERS: Dictionary = {
	1: 1.0,
	2: 1.4,
	3: 1.9,
}

static func get_upgrade_cost(current_tier: int) -> int:
	match current_tier:
		1: return UPGRADE_COST_T1_TO_T2
		2: return UPGRADE_COST_T2_TO_T3
		_: return 999  # Cannot upgrade beyond tier 3

static func get_tier_multiplier(tier: int) -> float:
	return TIER_MULTIPLIERS.get(tier, 1.0)

static func calculate_viability(mut_a: Dictionary, mut_b: Dictionary) -> float:
	## Calculate forge viability based on shared affinities between two mutations.
	## 0 shared = 40%, 1 shared = 70%, 2 shared = 90%
	var aff_a: Array = mut_a.get("affinities", [])
	var aff_b: Array = mut_b.get("affinities", [])
	var shared: int = 0
	for a in aff_a:
		if a in aff_b:
			shared += 1
	match shared:
		0: return 0.40
		1: return 0.70
		_: return 0.90

static func combine_mutations(mut_a: Dictionary, mut_b: Dictionary, viability: float) -> Dictionary:
	## Create a hybrid mutation from two parents.
	## Stats are averaged then boosted by viability (up to +25% at 90% viability).
	var hybrid := {}
	hybrid["id"] = _generate_hybrid_id(mut_a.get("id", ""), mut_b.get("id", ""))
	hybrid["name"] = generate_hybrid_name(mut_a.get("name", ""), mut_b.get("name", ""))
	hybrid["desc"] = "Hybrid: %s + %s" % [mut_a.get("name", "?"), mut_b.get("name", "?")]
	hybrid["visual"] = mut_a.get("visual", "")  # Use first parent's visual
	hybrid["tier"] = maxi(mut_a.get("tier", 1), mut_b.get("tier", 1))
	hybrid["forged"] = true
	hybrid["parent_ids"] = [mut_a.get("id", ""), mut_b.get("id", "")]

	# Merge affinities (union, unique)
	var aff: Array = []
	for a in mut_a.get("affinities", []):
		if a not in aff:
			aff.append(a)
	for a in mut_b.get("affinities", []):
		if a not in aff:
			aff.append(a)
	hybrid["affinities"] = aff

	# Sensory upgrade: if either parent has it
	hybrid["sensory_upgrade"] = mut_a.get("sensory_upgrade", false) or mut_b.get("sensory_upgrade", false)

	# Combine stats: average + viability bonus (up to 25%)
	var stat_a: Dictionary = mut_a.get("stat", {})
	var stat_b: Dictionary = mut_b.get("stat", {})
	var all_keys: Array = []
	for k in stat_a:
		if k not in all_keys:
			all_keys.append(k)
	for k in stat_b:
		if k not in all_keys:
			all_keys.append(k)

	var bonus: float = 1.0 + viability * 0.25  # 1.0 to 1.225
	var merged_stat: Dictionary = {}
	for key in all_keys:
		var va: float = stat_a.get(key, 0.0)
		var vb: float = stat_b.get(key, 0.0)
		merged_stat[key] = ((va + vb) / 2.0) * bonus
	hybrid["stat"] = merged_stat

	# Directional: inherit from parent A if present, else B
	if mut_a.has("directional"):
		hybrid["directional"] = mut_a["directional"]
		hybrid["damage_arc"] = mut_a.get("damage_arc", 0.5)
	elif mut_b.has("directional"):
		hybrid["directional"] = mut_b["directional"]
		hybrid["damage_arc"] = mut_b.get("damage_arc", 0.5)

	return hybrid

static func generate_hybrid_name(name_a: String, name_b: String) -> String:
	## Create a hybrid name by combining halves of the parent names.
	## "Extra Cilia" + "Defensive Spines" → "Extra Spines"
	var words_a: PackedStringArray = name_a.split(" ", false)
	var words_b: PackedStringArray = name_b.split(" ", false)
	if words_a.size() == 0 or words_b.size() == 0:
		return name_a + "-" + name_b
	# Take first word of A, last word of B
	var first: String = words_a[0]
	var last: String = words_b[words_b.size() - 1]
	# Avoid duplicates like "Extra Extra"
	if first == last:
		if words_b.size() > 1:
			last = words_b[0]
		else:
			return first + " Hybrid"
	return first + " " + last

static func _generate_hybrid_id(id_a: String, id_b: String) -> String:
	## Deterministic hybrid ID from parent IDs (sorted for consistency).
	var parts: Array = [id_a, id_b]
	parts.sort()
	return "forge_%s_%s" % [parts[0], parts[1]]

static func find_base_mutation(mutation_id: String) -> Dictionary:
	## Look up the original mutation data from EvolutionData.
	for m in EvolutionData.MUTATIONS:
		if m.get("id", "") == mutation_id:
			return m
	# Check forged mutations in GameManager
	for m in GameManager.forged_mutations:
		if m.get("id", "") == mutation_id:
			return m
	return {}

static func get_forge_preview(mut_a: Dictionary, mut_b: Dictionary) -> Dictionary:
	## Preview what a forge would produce (without rolling viability).
	var viability: float = calculate_viability(mut_a, mut_b)
	var hybrid: Dictionary = combine_mutations(mut_a, mut_b, viability)
	return {"viability": viability, "hybrid": hybrid}

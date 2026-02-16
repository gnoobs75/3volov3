extends Node
## Autoload: Global game state, biomolecule inventory, and scene transitions.

signal stage_changed(new_stage: String)
signal inventory_changed()
signal biomolecule_collected(item: Dictionary)
signal evolution_triggered(category: String)
signal evolution_applied(mutation: Dictionary)
signal cell_stage_won
signal safe_zone_ended
signal gene_fragments_changed(new_total: int)
signal mutation_forged(hybrid: Dictionary)
signal mutation_upgraded(mutation_id: String, new_tier: int)
signal sensory_level_changed(new_level: int)
signal trait_unlocked(trait_id: String)
signal trait_upgraded(trait_id: String, new_tier: int)

enum Stage { MENU, INTRO, CELL, RTS, SNAKE, OCEAN_STUB }

var current_stage: Stage = Stage.MENU

var player_stats: Dictionary = {
	"organelles_collected": 0,
	"genes": ["Gene_1", "Gene_3"],
	"proteins": ["Protein_1"],
	"spliced_traits": {}
}

# Evolution system
var evolution_level: int = 0
var active_mutations: Array[Dictionary] = []
var sensory_level: int = 0
var tutorial_shown: bool = false
var initial_customization_done: bool = false

# Creature visual customization (persists across deaths)
var creature_customization: Dictionary = {
	"membrane_color": Color(0.3, 0.6, 1.0),
	"iris_color": Color(0.2, 0.5, 0.9),
	"glow_color": Color(0.3, 0.7, 1.0),
	"interior_color": Color(0.15, 0.25, 0.5),
	"cilia_color": Color(0.4, 0.7, 1.0),
	"organelle_tint": Color(0.3, 0.8, 0.5),
	"eye_style": "anime",   # round, anime, compound, googly, slit, lashed, fierce, dot, star
	"eye_left_x": -0.15,    # LEGACY — migrated to eyes[]
	"eye_left_y": -0.25,    # LEGACY
	"eye_right_x": -0.15,   # LEGACY
	"eye_right_y": 0.25,    # LEGACY
	"eye_size": 3.5,        # LEGACY — migrated to eyes[]
	"body_elongation_offset": 0.0,  # LEGACY — migrated to body_handles
	"body_bulge": 1.0,              # LEGACY — migrated to body_handles
	# New: 8 morph handles at 45-degree intervals (radius multipliers, 0.5-2.0, default 1.0)
	"body_handles": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	# New: multi-eye array (max 6 eyes)
	"eyes": [
		{"x": -0.15, "y": -0.25, "size": 3.5, "style": "anime"},
		{"x": -0.15, "y": 0.25, "size": 3.5, "style": "anime"},
	],
}

# Mutation placement map: mutation_id -> {angle: float, distance: float, mirrored: bool, scale: float, rotation_offset: float}
var mutation_placements: Dictionary = {}
var _placements_migrated: bool = false

# CRISPR Mutation Workshop — persistent across deaths
var gene_fragments: int = 0
var forged_mutations: Array[Dictionary] = []  # Hybrid mutations from the Forge
var mutation_upgrades: Dictionary = {}  # mutation_id -> {tier: int, multiplier: float}

# Golden Card AOE — persistent across deaths
var equipped_golden_card: String = ""  # ID of equipped golden ability (poison_cloud, electric_shock, healing_aura)

# Creature Codex — persistent across deaths
var discovered_creatures: Dictionary = {}  # creature_id -> bool

# Boss Traits — looted from defeated biome bosses
var unlocked_traits: Array[String] = []  # trait IDs: "pulse_wave", "acid_spit", "wind_gust", "bone_shield", "summon_minions"
var trait_tiers: Dictionary = {}  # trait_id -> int (1-3)
var equipped_trait: String = ""  # Currently selected trait for use

var safe_zone_active: bool = true  # No enemies until player collects a few items
const MAX_VIAL: int = 10
const SAFE_ZONE_THRESHOLD: int = 3  # Collections before enemies appear

const SENSORY_TIERS: Array = [
	{"visibility_range": 0.35, "color_perception": 0.0, "name": "Chemoreception"},
	{"visibility_range": 0.50, "color_perception": 0.15, "name": "Primitive Light Sensing"},
	{"visibility_range": 0.65, "color_perception": 0.4, "name": "Basic Photoreception"},
	{"visibility_range": 0.80, "color_perception": 0.7, "name": "Color Vision"},
	{"visibility_range": 0.90, "color_perception": 0.9, "name": "Advanced Vision"},
	{"visibility_range": 1.0, "color_perception": 1.0, "name": "Apex Predator Vision"},
]

## Biomolecule inventory: tracks collected "building blocks of life"
## Categories map to real biochemistry terminology
var inventory: Dictionary = {
	"nucleotides": [],       # ATP, ADP, GTP -- phosphorylated energy carriers
	"monosaccharides": [],   # Glucose, Ribose -- simple sugars for catabolism
	"amino_acids": [],       # Alanine, Glycine, Tryptophan -- polypeptide monomers
	"coenzymes": [],         # NADH, FADH2, CoA -- electron/acyl carriers
	"lipids": [],            # Phospholipids -- membrane bilayer components
	"nucleotide_bases": [],  # Adenine, Cytosine, Guanine -- genetic alphabet
	"organic_acids": [],     # Pyruvate -- metabolic intermediates
	"organelles": [],        # Mitochondria, Ribosomes, etc. -- subcellular machinery
}

## Category display names for HUD
const CATEGORY_LABELS: Dictionary = {
	"nucleotides": "Nucleotides",
	"monosaccharides": "Saccharides",
	"amino_acids": "Amino Acids",
	"coenzymes": "Coenzymes",
	"lipids": "Lipids",
	"nucleotide_bases": "Nucleobases",
	"organic_acids": "Organic Acids",
	"organelles": "Organelles",
}

func _ready() -> void:
	_migrate_placements_if_needed()
	_migrate_body_shape()
	_migrate_eyes()

func go_to_intro() -> void:
	current_stage = Stage.INTRO
	get_tree().change_scene_to_file("res://scenes/workstation.tscn")
	stage_changed.emit("intro")

func go_to_cell_stage() -> void:
	current_stage = Stage.CELL
	Engine.time_scale = 0.85  # 15% slower for accessibility
	get_tree().change_scene_to_file("res://scenes/cell_stage.tscn")
	stage_changed.emit("cell")

func go_to_rts_stage() -> void:
	current_stage = Stage.RTS
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/rts_stage.tscn")
	stage_changed.emit("rts")

func go_to_snake_stage() -> void:
	current_stage = Stage.SNAKE
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/snake_stage.tscn")
	stage_changed.emit("snake")

func go_to_ocean_stub() -> void:
	current_stage = Stage.OCEAN_STUB
	Engine.time_scale = 1.0
	print("GameManager: Ocean stage not yet implemented - you've completed the Cell Stage!")
	stage_changed.emit("ocean_stub")

func go_to_menu() -> void:
	current_stage = Stage.MENU
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	stage_changed.emit("menu")

## Win condition: evolution level 20
func check_cell_win() -> bool:
	return evolution_level >= 20

func add_organelle() -> void:
	player_stats.organelles_collected += 1

## Add a collected biomolecule or organelle to inventory
func collect_biomolecule(item: Dictionary) -> void:
	var cat: String = item.get("category", "")
	# Map category from JSON to inventory key
	var inv_key: String = ""
	match cat:
		"nucleotide": inv_key = "nucleotides"
		"monosaccharide": inv_key = "monosaccharides"
		"amino_acid": inv_key = "amino_acids"
		"coenzyme": inv_key = "coenzymes"
		"lipid": inv_key = "lipids"
		"nucleotide_base": inv_key = "nucleotide_bases"
		"organic_acid": inv_key = "organic_acids"
	if inv_key != "" and inv_key in inventory:
		inventory[inv_key].append(item.get("id", ""))
	biomolecule_collected.emit(item)
	inventory_changed.emit()
	# End safe zone after enough collections
	if safe_zone_active and get_total_collected() >= SAFE_ZONE_THRESHOLD:
		safe_zone_active = false
		safe_zone_ended.emit()
	# Check if any vial is full → trigger evolution
	if inv_key != "" and inventory[inv_key].size() >= MAX_VIAL:
		evolution_triggered.emit(inv_key)

func collect_organelle_item(item: Dictionary) -> void:
	inventory.organelles.append(item.get("id", ""))
	add_organelle()
	inventory_changed.emit()

func get_total_collected() -> int:
	var total: int = 0
	for key in inventory:
		total += inventory[key].size()
	return total

func get_unique_collected() -> int:
	var unique: Array = []
	for key in inventory:
		for item_id in inventory[key]:
			if item_id not in unique:
				unique.append(item_id)
	return unique.size()

## Consume nutrients for jet stream defense. Returns array of colors for VFX.
func consume_for_jet(count: int) -> Array:
	var consumable_keys: Array = ["nucleotides", "monosaccharides", "amino_acids", "coenzymes", "lipids", "nucleotide_bases", "organic_acids"]
	var colors: Array = []
	var consumed: int = 0
	for key in consumable_keys:
		while consumed < count and inventory[key].size() > 0:
			inventory[key].pop_back()
			# Map category to a color for the jet particles
			match key:
				"nucleotides": colors.append(Color(0.2, 0.6, 1.0))
				"monosaccharides": colors.append(Color(0.9, 0.7, 0.2))
				"amino_acids": colors.append(Color(0.3, 0.9, 0.4))
				"coenzymes": colors.append(Color(0.8, 0.4, 0.9))
				"lipids": colors.append(Color(1.0, 0.8, 0.3))
				"nucleotide_bases": colors.append(Color(0.4, 0.8, 0.8))
				"organic_acids": colors.append(Color(0.9, 0.5, 0.2))
			consumed += 1
		if consumed >= count:
			break
	if consumed > 0:
		inventory_changed.emit()
	return colors

func consume_vial_for_evolution(category_key: String) -> void:
	inventory[category_key].clear()
	evolution_level += 1
	inventory_changed.emit()
	# Bonus: award gene fragments for filling a vial
	add_gene_fragments(2)
	# Check win condition
	if check_cell_win():
		cell_stage_won.emit()

func apply_mutation(mutation: Dictionary) -> void:
	active_mutations.append(mutation)
	# Apply sensory upgrade if applicable
	if mutation.get("sensory_upgrade", false):
		sensory_level = mini(sensory_level + 1, SENSORY_TIERS.size() - 1)
	evolution_applied.emit(mutation)

func apply_mutation_with_placement(mutation: Dictionary, snap_slot: int, mirrored: bool) -> void:
	# New angular placement path
	var vis: String = mutation.get("visual", "")
	var angle: float = SnapPointSystem.get_default_angle_for_visual(vis)
	var distance: float = SnapPointSystem.get_default_distance_for_visual(vis)
	var auto_mirror: bool = not SnapPointSystem.is_center_angle(angle) and distance >= 0.5
	mutation_placements[mutation.get("id", "")] = {
		"angle": angle,
		"distance": distance,
		"mirrored": auto_mirror,
		"scale": 1.0,
		"rotation_offset": 0.0,
	}
	apply_mutation(mutation)

func apply_mutation_with_angle(mutation: Dictionary, angle: float, distance: float) -> void:
	var auto_mirror: bool = not SnapPointSystem.is_center_angle(angle) and distance >= 0.5
	mutation_placements[mutation.get("id", "")] = {
		"angle": angle,
		"distance": distance,
		"mirrored": auto_mirror,
		"scale": 1.0,
		"rotation_offset": 0.0,
	}
	apply_mutation(mutation)

func update_mutation_placement(mutation_id: String, snap_slot: int, mirrored: bool) -> void:
	# Legacy compat — convert snap_slot to angle
	var angle: float = SnapPointSystem.snap_slot_to_angle(snap_slot)
	var distance: float = SnapPointSystem.snap_slot_to_distance(snap_slot)
	var existing: Dictionary = mutation_placements.get(mutation_id, {})
	var scale_val: float = existing.get("scale", 1.0)
	var rot_off: float = existing.get("rotation_offset", 0.0)
	mutation_placements[mutation_id] = {
		"angle": angle,
		"distance": distance,
		"mirrored": mirrored,
		"scale": scale_val,
		"rotation_offset": rot_off,
	}

func update_mutation_angle(mutation_id: String, angle: float, distance: float, mirrored: bool) -> void:
	var existing: Dictionary = mutation_placements.get(mutation_id, {})
	var scale_val: float = existing.get("scale", 1.0)
	var rot_off: float = existing.get("rotation_offset", 0.0)
	mutation_placements[mutation_id] = {
		"angle": angle,
		"distance": distance,
		"mirrored": mirrored,
		"scale": scale_val,
		"rotation_offset": rot_off,
	}

func update_mutation_scale(mutation_id: String, scale: float) -> void:
	if mutation_id in mutation_placements:
		mutation_placements[mutation_id]["scale"] = clampf(scale, 0.4, 2.5)

func update_mutation_rotation(mutation_id: String, rotation_offset: float) -> void:
	if mutation_id in mutation_placements:
		mutation_placements[mutation_id]["rotation_offset"] = fmod(rotation_offset + TAU, TAU)

func remove_mutation_placement(mutation_id: String) -> void:
	mutation_placements.erase(mutation_id)

func _migrate_placements_if_needed() -> void:
	if _placements_migrated:
		return
	_placements_migrated = true
	var to_migrate: Array = []
	for mid in mutation_placements:
		var p: Dictionary = mutation_placements[mid]
		if p.has("snap_slot") and not p.has("angle"):
			to_migrate.append(mid)
	for mid in to_migrate:
		var p: Dictionary = mutation_placements[mid]
		var slot: int = p.get("snap_slot", 0)
		var mirrored: bool = p.get("mirrored", false)
		var scale_val: float = p.get("scale", 1.0)
		mutation_placements[mid] = {
			"angle": SnapPointSystem.snap_slot_to_angle(slot),
			"distance": SnapPointSystem.snap_slot_to_distance(slot),
			"mirrored": mirrored,
			"scale": scale_val,
			"rotation_offset": 0.0,
		}

func update_creature_customization(custom: Dictionary) -> void:
	for key in custom:
		creature_customization[key] = custom[key]

func update_body_elongation_offset(offset: float) -> void:
	creature_customization["body_elongation_offset"] = clampf(offset, -0.5, 0.5)

func update_body_bulge(bulge: float) -> void:
	creature_customization["body_bulge"] = clampf(bulge, 0.5, 2.0)

# --- Body Morph Handles ---

func get_body_handles() -> Array:
	return creature_customization.get("body_handles", [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])

func update_body_handle(index: int, value: float) -> void:
	var handles: Array = get_body_handles()
	if index >= 0 and index < handles.size():
		handles[index] = clampf(value, 0.5, 2.0)
		creature_customization["body_handles"] = handles

func _migrate_body_shape() -> void:
	## Convert old elongation_offset + bulge to 8 morph handles (if not already migrated)
	var handles: Array = creature_customization.get("body_handles", [])
	if handles.size() == 8:
		# Check if all defaults — if old values differ, reconvert
		var all_default: bool = true
		for h in handles:
			if absf(h - 1.0) > 0.01:
				all_default = false
				break
		if not all_default:
			return  # Already has custom handles
	var elong: float = creature_customization.get("body_elongation_offset", 0.0)
	var bulge: float = creature_customization.get("body_bulge", 1.0)
	if absf(elong) < 0.01 and absf(bulge - 1.0) < 0.01:
		return  # No old customization to migrate
	var base_elong: float = 1.0 + elong
	var new_handles: Array = []
	for i in range(8):
		var angle: float = TAU * i / 8.0
		var bulge_factor: float = 1.0 + (absf(sin(angle)) * (bulge - 1.0))
		var x_weight: float = absf(cos(angle))
		var y_weight: float = absf(sin(angle))
		new_handles.append(clampf(base_elong * x_weight + bulge_factor * y_weight, 0.5, 2.0))
	creature_customization["body_handles"] = new_handles

# --- Multi-Eye System ---

func get_eyes() -> Array:
	return creature_customization.get("eyes", [
		{"x": -0.15, "y": -0.25, "size": 3.5, "style": "anime"},
		{"x": -0.15, "y": 0.25, "size": 3.5, "style": "anime"},
	])

func add_eye(x: float, y: float) -> void:
	var eyes: Array = get_eyes()
	if eyes.size() >= 6:
		return
	var style: String = creature_customization.get("eye_style", "anime")
	eyes.append({"x": x, "y": y, "size": 3.5, "style": style})
	creature_customization["eyes"] = eyes

func remove_eye(index: int) -> void:
	var eyes: Array = get_eyes()
	if index >= 0 and index < eyes.size() and eyes.size() > 1:
		eyes.remove_at(index)
		creature_customization["eyes"] = eyes

func update_eye(index: int, data: Dictionary) -> void:
	var eyes: Array = get_eyes()
	if index >= 0 and index < eyes.size():
		eyes[index].merge(data, true)
		creature_customization["eyes"] = eyes

func _migrate_eyes() -> void:
	## Convert old eye_left_x/y + eye_right_x/y to eyes[] array
	var eyes: Array = creature_customization.get("eyes", [])
	if eyes.size() > 0:
		# Check if eyes have actual custom placement or are just defaults
		var first: Dictionary = eyes[0] if eyes.size() > 0 else {}
		if first.has("x") and first.has("y"):
			return  # Already migrated
	var style: String = creature_customization.get("eye_style", "anime")
	var sz: float = creature_customization.get("eye_size", 3.5)
	creature_customization["eyes"] = [
		{"x": creature_customization.get("eye_left_x", -0.15),
		 "y": creature_customization.get("eye_left_y", -0.25),
		 "size": sz, "style": style},
		{"x": creature_customization.get("eye_right_x", -0.15),
		 "y": creature_customization.get("eye_right_y", 0.25),
		 "size": sz, "style": style},
	]

func get_sensory_tier() -> Dictionary:
	return SENSORY_TIERS[sensory_level]

# --- CRISPR Mutation Workshop ---

func add_gene_fragments(amount: int) -> void:
	gene_fragments += amount
	gene_fragments_changed.emit(gene_fragments)

func spend_gene_fragments(amount: int) -> bool:
	if gene_fragments < amount:
		return false
	gene_fragments -= amount
	gene_fragments_changed.emit(gene_fragments)
	return true

func get_mutation_tier(mutation_id: String) -> int:
	if mutation_id in mutation_upgrades:
		return mutation_upgrades[mutation_id].get("tier", 1)
	return 1

func get_tier_multiplier(mutation_id: String) -> float:
	var tier: int = get_mutation_tier(mutation_id)
	match tier:
		2: return 1.4
		3: return 1.9
		_: return 1.0

func has_mutation(mutation_id: String) -> bool:
	for m in active_mutations:
		if m.get("id", "") == mutation_id:
			return true
	for m in forged_mutations:
		if m.get("id", "") == mutation_id:
			return true
	return false

func upgrade_mutation(mutation_id: String) -> bool:
	var current_tier: int = get_mutation_tier(mutation_id)
	if current_tier >= 3:
		return false
	var cost: int = ForgeCalculator.get_upgrade_cost(current_tier)
	if not spend_gene_fragments(cost):
		return false
	var new_tier: int = current_tier + 1
	mutation_upgrades[mutation_id] = {"tier": new_tier, "multiplier": ForgeCalculator.get_tier_multiplier(new_tier)}
	# Apply the stat boost to the active mutation
	_apply_tier_to_mutation(mutation_id, new_tier)
	mutation_upgraded.emit(mutation_id, new_tier)
	return true

func _apply_tier_to_mutation(mutation_id: String, tier: int) -> void:
	var mult: float = ForgeCalculator.get_tier_multiplier(tier)
	for m in active_mutations:
		if m.get("id", "") == mutation_id:
			# Recalculate stats from base using tier multiplier
			var base_mut: Dictionary = ForgeCalculator.find_base_mutation(mutation_id)
			if base_mut.is_empty():
				break
			var base_stat: Dictionary = base_mut.get("stat", {})
			var new_stat: Dictionary = {}
			for key in base_stat:
				new_stat[key] = base_stat[key] * mult
			m["stat"] = new_stat
			m["tier"] = tier
			evolution_applied.emit(m)
			break

func forge_mutations(mut_a: Dictionary, mut_b: Dictionary) -> Dictionary:
	## Combine two mutations into a hybrid. Returns empty dict on failure.
	var viability: float = ForgeCalculator.calculate_viability(mut_a, mut_b)
	# Roll for success
	if randf() > viability:
		return {}
	var hybrid: Dictionary = ForgeCalculator.combine_mutations(mut_a, mut_b, viability)
	# Remove the source mutations from active
	_remove_mutation(mut_a.get("id", ""))
	_remove_mutation(mut_b.get("id", ""))
	# Add hybrid
	forged_mutations.append(hybrid)
	active_mutations.append(hybrid)
	mutation_forged.emit(hybrid)
	evolution_applied.emit(hybrid)
	return hybrid

func _remove_mutation(mutation_id: String) -> void:
	for i in range(active_mutations.size() - 1, -1, -1):
		if active_mutations[i].get("id", "") == mutation_id:
			active_mutations.remove_at(i)
			break
	# Clean up placement
	mutation_placements.erase(mutation_id)
	mutation_upgrades.erase(mutation_id)

# --- Creature Codex ---

func discover_creature(creature_id: String) -> void:
	if creature_id in discovered_creatures:
		return
	discovered_creatures[creature_id] = true

func is_creature_discovered(creature_id: String) -> bool:
	return discovered_creatures.get(creature_id, false)

# --- Boss Traits ---

func unlock_trait(trait_id: String) -> void:
	if trait_id in unlocked_traits:
		return
	unlocked_traits.append(trait_id)
	trait_tiers[trait_id] = 1
	if equipped_trait == "":
		equipped_trait = trait_id
	trait_unlocked.emit(trait_id)

func grant_queen_visual_upgrade() -> void:
	## Grant unique psionic crown mutation from Macrophage Queen
	var queen_mut_id: String = "queen_psionic_crown"
	for m in active_mutations:
		if m.get("id", "") == queen_mut_id:
			return  # Already have it
	var mutation: Dictionary = {
		"id": queen_mut_id,
		"name": "Psionic Crown",
		"description": "Neural tendrils harvested from the Macrophage Queen. Grants a pulsing psionic crest.",
		"visual": "antenna",
		"tier": 3,
		"stat_bonuses": {"health": 15, "energy": 10},
		"affinities": ["neural", "predator"],
		"boss_reward": true,
	}
	active_mutations.append(mutation)
	mutation_placements[queen_mut_id] = {
		"angle": -PI * 0.5,  # Top of head
		"distance": 1.0,
		"mirrored": false,
		"scale": 1.3,
		"rotation_offset": 0.0,
	}
	evolution_applied.emit(mutation)

func has_trait(trait_id: String) -> bool:
	return trait_id in unlocked_traits

func get_trait_tier(trait_id: String) -> int:
	return trait_tiers.get(trait_id, 0)

func upgrade_trait(trait_id: String) -> bool:
	if not has_trait(trait_id):
		return false
	var current: int = get_trait_tier(trait_id)
	if current >= 3:
		return false
	var cost: int = 20 if current == 1 else 40  # T1→T2 = 20, T2→T3 = 40
	if not spend_gene_fragments(cost):
		return false
	trait_tiers[trait_id] = current + 1
	trait_upgraded.emit(trait_id, current + 1)
	return true

func get_trait_multiplier(trait_id: String) -> float:
	match get_trait_tier(trait_id):
		2: return 1.5
		3: return 2.2
		_: return 1.0

func equip_trait(trait_id: String) -> void:
	if has_trait(trait_id):
		equipped_trait = trait_id

func all_wing_bosses_defeated() -> bool:
	## Check if all 5 wing biome bosses (1-4 + 6) are killed
	for idx in [1, 2, 3, 4, 6]:
		if not get_meta("boss_%d_defeated" % idx, false):
			return false
	return true

func mark_boss_defeated(biome_idx: int) -> void:
	set_meta("boss_%d_defeated" % biome_idx, true)

# --- Sensory Upgrades (Snake Stage) ---

func upgrade_sensory_from_vial() -> void:
	## Small vision bump when filling a vial in snake stage
	sensory_level = mini(sensory_level + 1, SENSORY_TIERS.size() - 1)
	sensory_level_changed.emit(sensory_level)

func upgrade_sensory_from_boss() -> void:
	## Big vision jump when defeating a biome boss
	sensory_level = mini(sensory_level + 2, SENSORY_TIERS.size() - 1)
	sensory_level_changed.emit(sensory_level)

func reset_stats() -> void:
	## Soft reset: keep evolution progress, lose inventory.
	## Organelles partially preserved (50% rounded down).
	## CRISPR data, traits, codex persist permanently.
	var kept_organelles: int = player_stats.organelles_collected / 2
	player_stats.organelles_collected = kept_organelles
	player_stats.genes = ["Gene_1", "Gene_3"]
	player_stats.proteins = ["Protein_1"]
	player_stats.spliced_traits = {}
	for key in inventory:
		inventory[key] = []
	# Keep: evolution level, mutations, sensory upgrades, gene_fragments,
	# forged_mutations, mutation_upgrades, unlocked_traits, trait_tiers — all persist

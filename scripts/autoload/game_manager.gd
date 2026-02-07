extends Node
## Autoload: Global game state, biomolecule inventory, and scene transitions.

signal stage_changed(new_stage: String)
signal inventory_changed()
signal biomolecule_collected(item: Dictionary)
signal evolution_triggered(category: String)
signal evolution_applied(mutation: Dictionary)
signal cell_stage_won

enum Stage { MENU, INTRO, CELL, OCEAN_STUB }

var current_stage: Stage = Stage.MENU

var player_stats: Dictionary = {
	"reproductions": 0,
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
const MAX_VIAL: int = 10

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

func go_to_intro() -> void:
	current_stage = Stage.INTRO
	get_tree().change_scene_to_file("res://scenes/workstation.tscn")
	stage_changed.emit("intro")

func go_to_cell_stage() -> void:
	current_stage = Stage.CELL
	get_tree().change_scene_to_file("res://scenes/cell_stage.tscn")
	stage_changed.emit("cell")

func go_to_ocean_stub() -> void:
	current_stage = Stage.OCEAN_STUB
	print("GameManager: Ocean stage not yet implemented - you've completed the Cell Stage!")
	stage_changed.emit("ocean_stub")

func go_to_menu() -> void:
	current_stage = Stage.MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	stage_changed.emit("menu")

## Win condition: 10 repros + 5 organelles
func check_cell_win() -> bool:
	return player_stats.reproductions >= 10 and player_stats.organelles_collected >= 5

func add_reproduction() -> void:
	player_stats.reproductions += 1
	if check_cell_win():
		cell_stage_won.emit()

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

## Metabolize: consume collected nutrients to restore energy.
## Returns the number of items actually consumed.
func metabolize_nutrients(count: int) -> int:
	# Consume from non-organelle categories (don't burn organelles)
	var consumable_keys: Array = ["nucleotides", "monosaccharides", "amino_acids", "coenzymes", "lipids", "nucleotide_bases", "organic_acids"]
	var consumed: int = 0
	for key in consumable_keys:
		while consumed < count and inventory[key].size() > 0:
			inventory[key].pop_back()
			consumed += 1
		if consumed >= count:
			break
	if consumed > 0:
		inventory_changed.emit()
	return consumed

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

func apply_mutation(mutation: Dictionary) -> void:
	active_mutations.append(mutation)
	# Apply sensory upgrade if applicable
	if mutation.get("sensory_upgrade", false):
		sensory_level = mini(sensory_level + 1, SENSORY_TIERS.size() - 1)
	evolution_applied.emit(mutation)

func get_sensory_tier() -> Dictionary:
	return SENSORY_TIERS[sensory_level]

func reset_stats() -> void:
	## Soft reset: keep evolution progress, lose inventory and reproduction count.
	## Organelles partially preserved (50% rounded down).
	player_stats.reproductions = 0
	var kept_organelles: int = player_stats.organelles_collected / 2
	player_stats.organelles_collected = kept_organelles
	player_stats.genes = ["Gene_1", "Gene_3"]
	player_stats.proteins = ["Protein_1"]
	player_stats.spliced_traits = {}
	for key in inventory:
		inventory[key] = []
	# Keep evolution level, mutations, and sensory upgrades across deaths

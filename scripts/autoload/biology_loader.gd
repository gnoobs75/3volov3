extends Node
## Autoload: Loads and serves biology library data from JSON.
## Access anywhere via BiologyLoader.get_gene("Gene_1"), etc.

var _data: Dictionary = {}
var genes: Array = []
var proteins: Array = []
var helices: Array = []
var biomolecules: Array = []
var organelles: Array = []
var splice_rules: Array = []

func _ready() -> void:
	_load_library()

func _load_library() -> void:
	var file := FileAccess.open("res://data/biology_library.json", FileAccess.READ)
	if not file:
		push_error("BiologyLoader: Could not open biology_library.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("BiologyLoader: JSON parse error: " + json.get_error_message())
		return
	_data = json.data
	genes = _data.get("dna_genes", [])
	proteins = _data.get("proteins", [])
	helices = _data.get("helices", [])
	biomolecules = _data.get("biomolecules", [])
	organelles = _data.get("organelles", [])
	splice_rules = _data.get("splice_rules", [])
	print("BiologyLoader: Loaded %d genes, %d proteins, %d helices, %d biomolecules, %d organelles" % [
		genes.size(), proteins.size(), helices.size(), biomolecules.size(), organelles.size()
	])

func get_gene(gene_id: String) -> Dictionary:
	for g in genes:
		if g.get("id") == gene_id:
			return g
	return {}

func get_protein(protein_id: String) -> Dictionary:
	for p in proteins:
		if p.get("id") == protein_id:
			return p
	return {}

func get_helix(helix_id: String) -> Dictionary:
	for h in helices:
		if h.get("id") == helix_id:
			return h
	return {}

func get_organelle(organelle_id: String) -> Dictionary:
	for o in organelles:
		if o.get("id") == organelle_id:
			return o
	return {}

func get_random_biomolecule() -> Dictionary:
	if biomolecules.is_empty():
		return {}
	# Weighted by rarity: common=60%, uncommon=30%, rare=10%
	var weighted: Array = []
	for b in biomolecules:
		var count: int = 1
		match b.get("rarity", "common"):
			"common": count = 6
			"uncommon": count = 3
			"rare": count = 1
		for i in range(count):
			weighted.append(b)
	return weighted[randi() % weighted.size()]

func get_random_organelle() -> Dictionary:
	if organelles.is_empty():
		return {}
	var weighted: Array = []
	for o in organelles:
		var count: int = 1
		match o.get("rarity", "common"):
			"common": count = 5
			"uncommon": count = 3
			"rare": count = 1
			"legendary": count = 1
		for i in range(count):
			weighted.append(o)
	return weighted[randi() % weighted.size()]

func check_splice(gene_id_1: String, gene_id_2: String) -> Dictionary:
	for rule in splice_rules:
		var from: Array = rule.get("from", [])
		if (gene_id_1 in from and gene_id_2 in from):
			return rule
	return {"splice_id": "Wildcard", "from": [gene_id_1, gene_id_2], "viability": 0.3, "new_trait": {"random_boost": 0.05}}

func apply_trait_impact(stats: Dictionary, component: Dictionary) -> Dictionary:
	var impact: Dictionary = component.get("trait_impact", {})
	for key in impact:
		stats[key] = stats.get(key, 0.0) + impact[key]
	return stats

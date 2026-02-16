extends Node
## Tracks per-faction resources: biomass + gene fragments.

signal resources_changed(faction_id: int)

var _resources: Dictionary = {}  # faction_id -> {biomass: int, genes: int}

func setup(num_factions: int) -> void:
	_resources.clear()
	for i in range(num_factions):
		_resources[i] = {"biomass": 200, "genes": 50}

func get_biomass(faction_id: int) -> int:
	return _resources.get(faction_id, {}).get("biomass", 0)

func get_genes(faction_id: int) -> int:
	return _resources.get(faction_id, {}).get("genes", 0)

func add_biomass(faction_id: int, amount: int) -> void:
	if faction_id in _resources:
		_resources[faction_id]["biomass"] += amount
		resources_changed.emit(faction_id)

func add_genes(faction_id: int, amount: int) -> void:
	if faction_id in _resources:
		_resources[faction_id]["genes"] += amount
		resources_changed.emit(faction_id)

func can_afford(faction_id: int, biomass_cost: int, genes_cost: int) -> bool:
	return get_biomass(faction_id) >= biomass_cost and get_genes(faction_id) >= genes_cost

func spend(faction_id: int, biomass_cost: int, genes_cost: int) -> bool:
	if not can_afford(faction_id, biomass_cost, genes_cost):
		return false
	_resources[faction_id]["biomass"] -= biomass_cost
	_resources[faction_id]["genes"] -= genes_cost
	resources_changed.emit(faction_id)
	return true

extends Node
## Tracks per-faction resources: biomass + gene fragments.

signal resources_changed(faction_id: int)

var _resources: Dictionary = {}  # faction_id -> {biomass: int, genes: int}

func setup(num_factions: int) -> void:
	_resources.clear()
	for i in range(num_factions):
		_resources[i] = {"biomass": 400, "genes": 100}

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

func serialize() -> Dictionary:
	var data: Dictionary = {}
	for fid in _resources:
		data[str(fid)] = {
			"biomass": _resources[fid].get("biomass", 0),
			"genes": _resources[fid].get("genes", 0),
		}
	return data

func deserialize(data: Dictionary) -> void:
	for fid_str in data:
		var fid: int = int(fid_str)
		if fid not in _resources:
			_resources[fid] = {"biomass": 0, "genes": 0}
		_resources[fid]["biomass"] = int(data[fid_str].get("biomass", 0))
		_resources[fid]["genes"] = int(data[fid_str].get("genes", 0))
		resources_changed.emit(fid)

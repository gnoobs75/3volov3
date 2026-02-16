extends Node
## Runtime faction tracking: templates, elimination status, unit/building counts.

signal faction_eliminated(faction_id: int)

var templates: Dictionary = {}  # faction_id -> CreatureTemplate
var eliminated: Dictionary = {}  # faction_id -> bool
var _unit_counts: Dictionary = {}  # faction_id -> int
var _building_counts: Dictionary = {}  # faction_id -> int
var _supply_caps: Dictionary = {}  # faction_id -> int

func setup_factions() -> void:
	for i in range(4):
		var template := CreatureTemplate.new()
		if i == 0:
			template.setup_from_player()
		else:
			template.setup_from_faction(i)
		templates[i] = template
		eliminated[i] = false
		_unit_counts[i] = 0
		_building_counts[i] = 0
		_supply_caps[i] = 10  # Start with spawning pool supply

func get_template(faction_id: int) -> CreatureTemplate:
	return templates.get(faction_id, null)

func is_eliminated(faction_id: int) -> bool:
	return eliminated.get(faction_id, false)

func eliminate_faction(faction_id: int) -> void:
	eliminated[faction_id] = true
	faction_eliminated.emit(faction_id)

func get_alive_factions() -> Array:
	var alive: Array = []
	for fid in eliminated:
		if not eliminated[fid]:
			alive.append(fid)
	return alive

func get_alive_enemy_factions() -> Array:
	var alive: Array = []
	for fid in eliminated:
		if not eliminated[fid] and fid != 0:
			alive.append(fid)
	return alive

# === SUPPLY ===

func get_unit_count(faction_id: int) -> int:
	var count: int = 0
	for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if is_instance_valid(unit) and unit.is_in_group("rts_units"):
			count += 1
	return count

func get_supply_cap(faction_id: int) -> int:
	var cap: int = 0
	for building in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if is_instance_valid(building) and building.is_in_group("rts_buildings"):
			if "supply_provided" in building and building.is_complete():
				cap += building.supply_provided
	return cap

func get_supply_used(faction_id: int) -> int:
	var used: int = 0
	for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if is_instance_valid(unit) and unit.is_in_group("rts_units"):
			if "unit_type" in unit:
				var stats: Dictionary = UnitStats.get_stats(unit.unit_type)
				used += stats.get("supply_cost", 1)
	return used

func can_afford_supply(faction_id: int, unit_type: int) -> bool:
	var cost: int = UnitStats.get_stats(unit_type).get("supply_cost", 1)
	return get_supply_used(faction_id) + cost <= get_supply_cap(faction_id)

# === ELIMINATION CHECK ===

func check_elimination(faction_id: int) -> void:
	if eliminated.get(faction_id, false):
		return
	var has_base: bool = false
	var has_units: bool = false
	for node in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if not is_instance_valid(node):
			continue
		if node.is_in_group("rts_buildings") and "is_main_base" in node and node.is_main_base:
			has_base = true
		if node.is_in_group("rts_units"):
			has_units = true
	if not has_base and not has_units:
		eliminate_faction(faction_id)

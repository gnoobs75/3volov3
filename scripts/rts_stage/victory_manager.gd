extends Node
## Tracks faction eliminations and triggers win/loss conditions.

signal game_won()
signal game_lost()
signal faction_eliminated_announcement(faction_id: int, faction_name: String)

var _stage: Node = null
var _game_over: bool = false
var _game_time: float = 0.0
var _eliminations: Array = []

# Game stats tracking
var stats_units_produced: int = 0
var stats_units_lost: int = 0
var stats_enemies_killed: int = 0
var stats_buildings_built: int = 0
var stats_buildings_lost: int = 0
var stats_resources_gathered: int = 0
var stats_total_biomass: int = 0
var stats_total_genes: int = 0

# Army timeline: record player unit count every 30s
var _army_timeline: Array = []  # Array[int]
var _timeline_timer: float = 0.0
const TIMELINE_INTERVAL: float = 30.0

func setup(stage: Node) -> void:
	_stage = stage

func _process(delta: float) -> void:
	if _game_over:
		return
	_game_time += delta

	# Record army timeline
	_timeline_timer += delta
	if _timeline_timer >= TIMELINE_INTERVAL:
		_timeline_timer -= TIMELINE_INTERVAL
		var unit_count: int = 0
		for unit in get_tree().get_nodes_in_group("faction_0"):
			if unit.is_in_group("rts_units") and is_instance_valid(unit):
				unit_count += 1
		_army_timeline.append(unit_count)

	# Track cumulative resource income
	if _stage and _stage.has_method("get_resource_manager"):
		var rm: Node = _stage.get_resource_manager()
		var cur_bio: int = rm.get_biomass(0)
		var cur_gen: int = rm.get_genes(0)
		if cur_bio > stats_total_biomass:
			stats_total_biomass = cur_bio
		if cur_gen > stats_total_genes:
			stats_total_genes = cur_gen

func check_victory() -> void:
	if _game_over:
		return
	if not _stage or not _stage.has_method("get_faction_manager"):
		return
	var fm: Node = _stage.get_faction_manager()

	# Check all factions for elimination
	for fid in range(4):
		if not fm.is_eliminated(fid):
			fm.check_elimination(fid)
			if fm.is_eliminated(fid) and fid not in _eliminations:
				_eliminations.append(fid)
				var fname: String = FactionData.get_faction_name(fid)
				faction_eliminated_announcement.emit(fid, fname)

	# Player loses if eliminated
	if fm.is_eliminated(0):
		_game_over = true
		game_lost.emit()
		return

	# Player wins if all AI factions eliminated
	if fm.get_alive_enemy_factions().is_empty():
		_game_over = true
		game_won.emit()

func force_loss() -> void:
	## Surrender: force a loss regardless of game state.
	if _game_over:
		return
	_game_over = true
	game_lost.emit()

func is_game_over() -> bool:
	return _game_over

func get_game_time() -> float:
	return _game_time

func get_elimination_count() -> int:
	return _eliminations.size()

func get_stats_summary() -> Dictionary:
	## Returns all tracked stats for the end-game screen.
	# Count enemy factions eliminated (not counting player faction 0)
	var factions_eliminated: int = 0
	for fid in _eliminations:
		if fid != 0:
			factions_eliminated += 1
	return {
		"units_produced": stats_units_produced,
		"units_lost": stats_units_lost,
		"enemies_killed": stats_enemies_killed,
		"buildings_built": stats_buildings_built,
		"buildings_lost": stats_buildings_lost,
		"resources_gathered": stats_resources_gathered,
		"total_biomass": stats_total_biomass,
		"total_genes": stats_total_genes,
		"factions_eliminated": factions_eliminated,
		"army_timeline": _army_timeline.duplicate(),
	}

func serialize() -> Dictionary:
	return {
		"game_time": _game_time,
		"eliminations": _eliminations.duplicate(),
		"stats_units_produced": stats_units_produced,
		"stats_units_lost": stats_units_lost,
		"stats_enemies_killed": stats_enemies_killed,
		"stats_buildings_built": stats_buildings_built,
		"stats_buildings_lost": stats_buildings_lost,
		"stats_resources_gathered": stats_resources_gathered,
		"stats_total_biomass": stats_total_biomass,
		"stats_total_genes": stats_total_genes,
		"army_timeline": _army_timeline.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	_game_time = data.get("game_time", 0.0)
	_eliminations = []
	for e in data.get("eliminations", []):
		_eliminations.append(int(e))
	stats_units_produced = data.get("stats_units_produced", 0)
	stats_units_lost = data.get("stats_units_lost", 0)
	stats_enemies_killed = data.get("stats_enemies_killed", 0)
	stats_buildings_built = data.get("stats_buildings_built", 0)
	stats_buildings_lost = data.get("stats_buildings_lost", 0)
	stats_resources_gathered = data.get("stats_resources_gathered", 0)
	stats_total_biomass = data.get("stats_total_biomass", 0)
	stats_total_genes = data.get("stats_total_genes", 0)
	_army_timeline = []
	for v in data.get("army_timeline", []):
		_army_timeline.append(int(v))

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
var stats_resources_gathered: int = 0

func setup(stage: Node) -> void:
	_stage = stage

func _process(delta: float) -> void:
	if _game_over:
		return
	_game_time += delta

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

func is_game_over() -> bool:
	return _game_over

func get_game_time() -> float:
	return _game_time

func get_elimination_count() -> int:
	return _eliminations.size()

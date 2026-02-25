extends Node
## Records every command issued during an RTS match as a timestamped event stream.
## Events are recorded from the command_system signal and direct hooks.
## Auto-saves replay at end of match, keeps last 10 replays.

var _events: Array = []
var _recording: bool = true
var _game_time_ref: float = 0.0
var _initial_state: Dictionary = {}

const MAX_REPLAYS: int = 10
const REPLAY_DIR: String = "user://replays/"

func setup(stage: Node2D) -> void:
	_initial_state = {
		"map_id": stage._map_id if "_map_id" in stage else "petri_dish",
		"difficulty": stage.ai_difficulty if "ai_difficulty" in stage else 2,
		"ai_count": stage._ai_directors.size() if "_ai_directors" in stage else 3,
	}
	# Hook into command_system signal for player commands
	if stage._command_system:
		stage._command_system.command_issued.connect(_on_command_issued)
	# Ensure replay directory exists
	if not DirAccess.dir_exists_absolute(REPLAY_DIR):
		DirAccess.make_dir_recursive_absolute(REPLAY_DIR)

func record_event(event_type: String, data: Dictionary) -> void:
	if not _recording:
		return
	_events.append({
		"time": _game_time_ref,
		"type": event_type,
		"data": data,
	})

func update_time(game_time: float) -> void:
	_game_time_ref = game_time

func stop_recording() -> void:
	_recording = false

func get_event_count() -> int:
	return _events.size()

func get_total_time() -> float:
	if _events.is_empty():
		return 0.0
	return _events.back().time

# === COMMAND HOOKS ===

func record_move(units: Array, target_pos: Vector2) -> void:
	var ids: Array = _get_unit_ids(units)
	if ids.is_empty():
		return
	record_event("move", {"units": ids, "target_x": target_pos.x, "target_y": target_pos.y})

func record_attack(units: Array, target: Node2D) -> void:
	var ids: Array = _get_unit_ids(units)
	if ids.is_empty():
		return
	var target_id: String = target.name if is_instance_valid(target) else ""
	var target_pos: Vector2 = target.global_position if is_instance_valid(target) else Vector2.ZERO
	record_event("attack", {"units": ids, "target_id": target_id, "target_x": target_pos.x, "target_y": target_pos.y})

func record_attack_move(units: Array, target_pos: Vector2) -> void:
	var ids: Array = _get_unit_ids(units)
	if ids.is_empty():
		return
	record_event("attack_move", {"units": ids, "target_x": target_pos.x, "target_y": target_pos.y})

func record_build(worker: Node2D, building_type: int, pos: Vector2) -> void:
	var worker_id: String = worker.name if is_instance_valid(worker) else ""
	record_event("build", {"worker_id": worker_id, "building_type": building_type, "pos_x": pos.x, "pos_y": pos.y})

func record_produce(building: Node2D, unit_type: int) -> void:
	var building_id: String = building.name if is_instance_valid(building) else ""
	record_event("produce", {"building_id": building_id, "unit_type": unit_type})

func record_research(building: Node2D, upgrade_id: String) -> void:
	var building_id: String = building.name if is_instance_valid(building) else ""
	record_event("research", {"building_id": building_id, "upgrade_id": upgrade_id})

func record_ability(unit: Node2D, target_pos: Vector2) -> void:
	var unit_id: String = unit.name if is_instance_valid(unit) else ""
	record_event("ability", {"unit_id": unit_id, "target_x": target_pos.x, "target_y": target_pos.y})

func record_rally(building: Node2D, pos: Vector2) -> void:
	var building_id: String = building.name if is_instance_valid(building) else ""
	record_event("rally", {"building_id": building_id, "pos_x": pos.x, "pos_y": pos.y})

func record_patrol(units: Array, point_a: Vector2, point_b: Vector2) -> void:
	var ids: Array = _get_unit_ids(units)
	if ids.is_empty():
		return
	record_event("patrol", {"units": ids, "a_x": point_a.x, "a_y": point_a.y, "b_x": point_b.x, "b_y": point_b.y})

func record_gather(units: Array, target: Node2D) -> void:
	var ids: Array = _get_unit_ids(units)
	if ids.is_empty():
		return
	var target_id: String = target.name if is_instance_valid(target) else ""
	var target_pos: Vector2 = target.global_position if is_instance_valid(target) else Vector2.ZERO
	record_event("gather", {"units": ids, "target_id": target_id, "target_x": target_pos.x, "target_y": target_pos.y})

func record_repair(units: Array, building: Node2D) -> void:
	var ids: Array = _get_unit_ids(units)
	if ids.is_empty():
		return
	var building_id: String = building.name if is_instance_valid(building) else ""
	var building_pos: Vector2 = building.global_position if is_instance_valid(building) else Vector2.ZERO
	record_event("repair", {"units": ids, "building_id": building_id, "pos_x": building_pos.x, "pos_y": building_pos.y})

# === SAVE / LOAD ===

func save_replay(replay_name: String) -> String:
	## Saves replay to user://replays/<name>.json. Returns the full path.
	if not DirAccess.dir_exists_absolute(REPLAY_DIR):
		DirAccess.make_dir_recursive_absolute(REPLAY_DIR)
	var path: String = REPLAY_DIR + replay_name + ".json"
	var data: Dictionary = {
		"initial_state": _initial_state,
		"events": _events,
		"total_time": get_total_time(),
		"event_count": _events.size(),
		"timestamp": Time.get_datetime_string_from_system(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return ""
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	# Enforce max replay limit
	_cleanup_old_replays()
	return path

func auto_save_replay() -> String:
	## Auto-saves with a timestamped name. Returns the replay file path.
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var replay_name: String = "replay_%04d%02d%02d_%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	return save_replay(replay_name)

func _cleanup_old_replays() -> void:
	## Deletes oldest replays to stay under MAX_REPLAYS.
	var dir := DirAccess.open(REPLAY_DIR)
	if not dir:
		return
	var files: Array = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	# Sort alphabetically (timestamp-based names sort chronologically)
	files.sort()
	while files.size() > MAX_REPLAYS:
		var oldest: String = files.pop_front()
		DirAccess.remove_absolute(REPLAY_DIR + oldest)

# === STATIC HELPERS ===

static func list_replays() -> Array:
	## Returns array of dictionaries with replay info: {name, path, timestamp, total_time, event_count}
	var replay_dir: String = "user://replays/"
	if not DirAccess.dir_exists_absolute(replay_dir):
		return []
	var dir := DirAccess.open(replay_dir)
	if not dir:
		return []
	var replays: Array = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path: String = replay_dir + file_name
			var info: Dictionary = {"name": file_name.get_basename(), "path": path}
			# Try to read metadata without loading full events
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var parsed = JSON.parse_string(file.get_as_text())
				file.close()
				if parsed is Dictionary:
					info["timestamp"] = parsed.get("timestamp", "")
					info["total_time"] = parsed.get("total_time", 0.0)
					info["event_count"] = parsed.get("event_count", 0)
					var init: Dictionary = parsed.get("initial_state", {})
					info["map_id"] = init.get("map_id", "petri_dish")
					info["difficulty"] = init.get("difficulty", 2)
			replays.append(info)
		file_name = dir.get_next()
	dir.list_dir_end()
	# Sort newest first (reverse alphabetical since names are timestamp-based)
	replays.sort_custom(func(a, b): return a.name > b.name)
	return replays

# === INTERNAL ===

func _get_unit_ids(units: Array) -> Array:
	var ids: Array = []
	for unit in units:
		if is_instance_valid(unit):
			ids.append(unit.name)
	return ids

func _on_command_issued(_command: String, _target_pos: Vector2) -> void:
	# This is a fallback signal listener. Most events are recorded via direct
	# record_* calls from the stage manager hooks for richer data.
	pass

extends Node
## Manages save/load for the RTS stage. Saves to user://saves/ as JSON files.
## Supports manual saves, quicksave (F5/F9), and auto-save (every 300s, 3 rotating slots).

signal game_saved(slot_name: String)
signal game_loaded(slot_name: String)
signal save_failed(reason: String)

var _stage: Node2D = null

# Auto-save
var _auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 300.0  # 5 minutes
var _auto_save_slot: int = 0
const AUTO_SAVE_SLOTS: int = 3

# Toast notification
var _toast_text: String = ""
var _toast_timer: float = 0.0
const TOAST_DURATION: float = 2.0

func setup(stage: Node2D) -> void:
	_stage = stage

func _process(delta: float) -> void:
	# Auto-save tick
	if _stage and _stage._game_started and not _stage._game_over_shown:
		_auto_save_timer += delta
		if _auto_save_timer >= AUTO_SAVE_INTERVAL:
			_auto_save_timer = 0.0
			var slot: String = "auto_save_%d" % (_auto_save_slot + 1)
			_auto_save_slot = (_auto_save_slot + 1) % AUTO_SAVE_SLOTS
			if save_game(slot):
				_show_toast("Auto-saved")

	# Toast fade
	if _toast_timer > 0:
		_toast_timer -= delta

func save_game(slot_name: String) -> bool:
	if not _stage:
		save_failed.emit("No stage reference")
		return false

	var data: Dictionary = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"timestamp_str": Time.get_datetime_string_from_system(),
		"game_time": _stage._time,
		"ai_difficulty": _stage.ai_difficulty,
		"spectator_mode": _stage._spectator_mode,
		"units": [],
		"buildings": [],
		"resource_nodes": [],
		"tech_tree": {},
		"resources": {},
		"fog_of_war": {},
		"ai_directors": [],
		"map_events": {},
		"victory": {},
	}

	# Serialize units
	for unit in _stage.get_tree().get_nodes_in_group("rts_units"):
		if is_instance_valid(unit) and unit.has_method("serialize"):
			data["units"].append(unit.serialize())

	# Serialize buildings
	for building in _stage.get_tree().get_nodes_in_group("rts_buildings"):
		if is_instance_valid(building) and building.has_method("serialize"):
			data["buildings"].append(building.serialize())

	# Serialize resource nodes
	for res in _stage.get_tree().get_nodes_in_group("resource_nodes"):
		if is_instance_valid(res) and res.has_method("serialize"):
			var res_data: Dictionary = res.serialize()
			if res_data.get("biomass_remaining", 0) > 0:
				data["resource_nodes"].append(res_data)

	# Serialize tech tree
	if _stage._tech_tree and _stage._tech_tree.has_method("serialize"):
		data["tech_tree"] = _stage._tech_tree.serialize()

	# Serialize resources
	if _stage._resource_manager and _stage._resource_manager.has_method("serialize"):
		data["resources"] = _stage._resource_manager.serialize()

	# Serialize fog of war
	if _stage._fog_of_war and _stage._fog_of_war.has_method("serialize"):
		data["fog_of_war"] = _stage._fog_of_war.serialize()

	# Serialize AI directors
	for ai in _stage._ai_directors:
		if is_instance_valid(ai) and ai.has_method("serialize"):
			data["ai_directors"].append(ai.serialize())

	# Serialize map events
	if _stage._map_events and _stage._map_events.has_method("serialize"):
		data["map_events"] = _stage._map_events.serialize()

	# Serialize victory manager
	if _stage._victory_manager and _stage._victory_manager.has_method("serialize"):
		data["victory"] = _stage._victory_manager.serialize()

	# Write to file
	DirAccess.make_dir_recursive_absolute("user://saves")
	var path: String = "user://saves/%s.json" % slot_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		save_failed.emit("Cannot open file: %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	game_saved.emit(slot_name)
	return true

func load_game(slot_name: String) -> bool:
	var path: String = "user://saves/%s.json" % slot_name
	if not FileAccess.file_exists(path):
		save_failed.emit("Save file not found: %s" % slot_name)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		save_failed.emit("Cannot read file: %s" % slot_name)
		return false
	var text: String = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		save_failed.emit("Invalid save data in: %s" % slot_name)
		return false

	# Validate version
	var version: int = data.get("version", 0)
	if version < 1:
		save_failed.emit("Unsupported save version: %d" % version)
		return false

	# Clear current state
	_clear_all()

	# Restore from data
	_restore_from(data)

	game_loaded.emit(slot_name)
	return true

func _clear_all() -> void:
	if not _stage:
		return

	# Remove all units
	for unit in _stage.get_tree().get_nodes_in_group("rts_units"):
		if is_instance_valid(unit):
			unit.queue_free()

	# Remove all buildings
	for building in _stage.get_tree().get_nodes_in_group("rts_buildings"):
		if is_instance_valid(building):
			building.queue_free()

	# Remove all resource nodes
	for res in _stage.get_tree().get_nodes_in_group("resource_nodes"):
		if is_instance_valid(res):
			res.queue_free()

	# Also remove titan corpses (which are in rts_resources)
	for res in _stage.get_tree().get_nodes_in_group("titan_corpses"):
		if is_instance_valid(res):
			res.queue_free()

	# Clear selection
	if _stage._selection_manager:
		_stage._selection_manager.deselect_all()

	# Remove AI directors
	for ai in _stage._ai_directors:
		if is_instance_valid(ai):
			ai.queue_free()
	_stage._ai_directors.clear()

	# Wait one frame for queue_free to take effect
	# (In Godot, queue_free is deferred, but the new objects will be added after this)

func _restore_from(data: Dictionary) -> void:
	if not _stage:
		return

	# Restore game time and settings
	_stage._time = data.get("game_time", 0.0)
	_stage.ai_difficulty = data.get("ai_difficulty", 2)
	_stage._spectator_mode = data.get("spectator_mode", false)

	# Use call_deferred to ensure queue_free has processed
	call_deferred("_restore_deferred", data)

func _restore_deferred(data: Dictionary) -> void:
	# Restore resources first (needed before spawning anything)
	if _stage._resource_manager and _stage._resource_manager.has_method("deserialize"):
		_stage._resource_manager.deserialize(data.get("resources", {}))

	# Restore tech tree
	if _stage._tech_tree and _stage._tech_tree.has_method("deserialize"):
		_stage._tech_tree.deserialize(data.get("tech_tree", {}))

	# Get faction manager for templates
	var fm: Node = _stage._faction_manager

	# Restore resource nodes
	for res_data in data.get("resource_nodes", []):
		var rn: Node2D = preload("res://scripts/rts_stage/resource_node.gd").new()
		rn.name = "Resource_%d" % (randi() % 100000)
		rn.max_biomass = int(res_data.get("max_biomass", 200))
		rn.biomass_remaining = rn.max_biomass  # Set temporarily before position
		rn.add_to_group("rts_resources")
		rn.add_to_group("resource_nodes")
		_stage.add_child(rn)
		rn.global_position = Vector2(res_data.get("pos_x", 0.0), res_data.get("pos_y", 0.0))
		if rn.has_method("deserialize"):
			rn.deserialize(res_data)

	# Restore buildings
	for bld_data in data.get("buildings", []):
		var fid: int = int(bld_data.get("faction_id", 0))
		var btype: int = int(bld_data.get("building_type", 0))
		var pos: Vector2 = Vector2(bld_data.get("pos_x", 0.0), bld_data.get("pos_y", 0.0))
		var template: CreatureTemplate = fm.get_template(fid) if fm else null
		if not template:
			template = CreatureTemplate.new()
			template.setup_from_faction(fid)
		var is_constructed: bool = bld_data.get("is_constructed", false)
		var building: Node2D = _stage._create_building(fid, btype, pos, template, is_constructed)
		building.build_rotation = bld_data.get("build_rotation", 0.0)
		if building.has_method("deserialize"):
			building.deserialize(bld_data)

	# Restore units
	for unit_data in data.get("units", []):
		var fid: int = int(unit_data.get("faction_id", 0))
		var utype: int = int(unit_data.get("unit_type", 0))
		var pos: Vector2 = Vector2(unit_data.get("pos_x", 0.0), unit_data.get("pos_y", 0.0))
		var template: CreatureTemplate = fm.get_template(fid) if fm else null
		if not template:
			template = CreatureTemplate.new()
			template.setup_from_faction(fid)
		var unit: Node2D = _stage._spawn_unit(fid, utype, pos, template)
		if unit.has_method("deserialize"):
			unit.deserialize(unit_data)

	# Restore fog of war
	if _stage._fog_of_war and _stage._fog_of_war.has_method("deserialize"):
		_stage._fog_of_war.deserialize(data.get("fog_of_war", {}))

	# Restore AI directors
	var ai_data_list: Array = data.get("ai_directors", [])
	var ai_factions: Array = [1, 2, 3]
	if _stage._spectator_mode:
		ai_factions = [0, 1, 2, 3]
	for fid in ai_factions:
		var ai := preload("res://scripts/rts_stage/ai_director.gd").new()
		ai.name = "AIDirector_%d" % fid
		ai.setup(fid, _stage, _stage.ai_difficulty)
		_stage.add_child(ai)
		_stage._ai_directors.append(ai)
		# Restore AI state from saved data if available
		for ai_saved in ai_data_list:
			if int(ai_saved.get("faction_id", -1)) == fid:
				if ai.has_method("deserialize"):
					ai.deserialize(ai_saved)
				break
		# Re-wire tech tree and taunt signal
		if _stage._tech_tree:
			ai.set_tech_tree(_stage._tech_tree)
		ai.ai_taunt.connect(_stage._on_ai_taunt)

	# Restore map events
	if _stage._map_events and _stage._map_events.has_method("deserialize"):
		_stage._map_events.deserialize(data.get("map_events", {}))

	# Restore victory manager
	if _stage._victory_manager and _stage._victory_manager.has_method("deserialize"):
		_stage._victory_manager.deserialize(data.get("victory", {}))

	# Update faction eliminations from victory manager data
	var elim_data: Array = data.get("victory", {}).get("eliminations", [])
	for e in elim_data:
		var fid: int = int(e)
		if fm and not fm.is_eliminated(fid):
			fm.eliminated[fid] = true

func get_save_list() -> Array:
	## Returns an array of {name: String, timestamp: float, timestamp_str: String}
	## sorted by timestamp descending (most recent first).
	var saves: Array = []
	var dir := DirAccess.open("user://saves")
	if not dir:
		return saves
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var slot_name: String = fname.replace(".json", "")
			var path: String = "user://saves/%s" % fname
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var text: String = file.get_as_text()
				file.close()
				var parsed = JSON.parse_string(text)
				if parsed is Dictionary:
					saves.append({
						"name": slot_name,
						"timestamp": parsed.get("timestamp", 0.0),
						"timestamp_str": parsed.get("timestamp_str", "Unknown"),
						"game_time": parsed.get("game_time", 0.0),
						"ai_difficulty": parsed.get("ai_difficulty", 2),
					})
		fname = dir.get_next()
	dir.list_dir_end()
	# Sort by timestamp descending
	saves.sort_custom(func(a, b): return a.get("timestamp", 0) > b.get("timestamp", 0))
	return saves

func delete_save(slot_name: String) -> bool:
	var path: String = "user://saves/%s.json" % slot_name
	if not FileAccess.file_exists(path):
		return false
	DirAccess.remove_absolute(path)
	return true

func _show_toast(text: String) -> void:
	_toast_text = text
	_toast_timer = TOAST_DURATION

func get_toast_text() -> String:
	return _toast_text

func get_toast_alpha() -> float:
	if _toast_timer <= 0:
		return 0.0
	if _toast_timer < 0.5:
		return _toast_timer * 2.0  # Fade out
	return 1.0

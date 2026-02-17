extends Node
## Periodic map events that affect the entire RTS arena.
## Spawns timed events: nutrient blooms, toxic tides, evolutionary surges,
## petri quakes, and NPC migrations.

signal event_started(event_type: int, position: Vector2, name: String)
signal event_ended(event_type: int)
signal event_warning(event_type: int, position: Vector2, name: String)
signal event_started_minimap(pos: Vector2, event_type: int, duration: float)

enum EventType { NUTRIENT_BLOOM, TOXIC_TIDE, EVOLUTIONARY_SURGE, PETRI_QUAKE, MIGRATION }

const EVENT_INTERVAL_MIN: float = 90.0
const EVENT_INTERVAL_MAX: float = 180.0
const WARNING_TIME: float = 5.0

const EVENT_DATA: Dictionary = {
	EventType.NUTRIENT_BLOOM: {
		"name": "Nutrient Bloom",
		"duration": 30.0,
		"color": Color(0.2, 0.9, 0.4),
	},
	EventType.TOXIC_TIDE: {
		"name": "Toxic Tide",
		"duration": 20.0,
		"color": Color(0.7, 0.2, 0.8),
	},
	EventType.EVOLUTIONARY_SURGE: {
		"name": "Evolutionary Surge",
		"duration": 15.0,
		"color": Color(1.0, 0.85, 0.2),
	},
	EventType.PETRI_QUAKE: {
		"name": "Petri Quake",
		"duration": 3.0,
		"color": Color(0.9, 0.5, 0.1),
	},
	EventType.MIGRATION: {
		"name": "Migration",
		"duration": 25.0,
		"color": Color(0.9, 0.3, 0.2),
	},
}

# State
var _event_timer: float = 0.0
var _next_event_time: float = 0.0
var _active_event: int = -1  # -1 = no event
var _event_position: Vector2 = Vector2.ZERO
var _event_remaining: float = 0.0
var _warning_active: bool = false
var _warning_timer: float = 0.0
var _pending_event_type: int = -1
var _stage: Node = null

# Toxic tide state
var _toxic_radius: float = 0.0
var _toxic_tick_timer: float = 0.0

# Bloom resources
var _bloom_resources: Array[Node2D] = []

# Migration creatures
var _migration_creatures: Array = []  # [{node, start, end}]
var _migration_timer: float = 0.0

const MAP_RADIUS: float = 8000.0

func setup(stage: Node) -> void:
	_stage = stage
	_next_event_time = randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX)
	_event_timer = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(_stage):
		return

	if _active_event >= 0:
		# Active event ticking
		_event_remaining -= delta
		match _active_event:
			EventType.TOXIC_TIDE:
				_tick_toxic_tide(delta)
			EventType.MIGRATION:
				_tick_migration(delta)
		if _event_remaining <= 0:
			_end_event()
	elif _warning_active:
		# Warning countdown
		_warning_timer -= delta
		if _warning_timer <= 0:
			_start_event(_pending_event_type)
	else:
		# Waiting for next event
		_event_timer += delta
		if _event_timer >= _next_event_time:
			_trigger_warning()

func _trigger_warning() -> void:
	# Pick a random event type
	var types: Array = [
		EventType.NUTRIENT_BLOOM,
		EventType.TOXIC_TIDE,
		EventType.EVOLUTIONARY_SURGE,
		EventType.PETRI_QUAKE,
		EventType.MIGRATION,
	]
	_pending_event_type = types[randi() % types.size()]

	# Pick event position (random within map, biased toward mid-range)
	var angle: float = randf() * TAU
	var dist: float = randf_range(MAP_RADIUS * 0.15, MAP_RADIUS * 0.7)
	_event_position = Vector2(cos(angle) * dist, sin(angle) * dist)

	# For toxic tide, position is at map edge
	if _pending_event_type == EventType.TOXIC_TIDE:
		var edge_angle: float = randf() * TAU
		_event_position = Vector2(cos(edge_angle), sin(edge_angle)) * MAP_RADIUS * 0.85

	# For migration, position is at map edge (start point)
	if _pending_event_type == EventType.MIGRATION:
		var edge_angle: float = randf() * TAU
		_event_position = Vector2(cos(edge_angle), sin(edge_angle)) * MAP_RADIUS * 0.9

	_warning_active = true
	_warning_timer = WARNING_TIME
	var data: Dictionary = EVENT_DATA[_pending_event_type]
	event_warning.emit(_pending_event_type, _event_position, data["name"])

func _start_event(etype: int) -> void:
	_warning_active = false
	_active_event = etype
	var data: Dictionary = EVENT_DATA[etype]
	_event_remaining = data["duration"]

	match etype:
		EventType.NUTRIENT_BLOOM:
			_spawn_bloom_resources()
		EventType.TOXIC_TIDE:
			_toxic_radius = 0.0
			_toxic_tick_timer = 0.0
		EventType.EVOLUTIONARY_SURGE:
			_apply_surge()
		EventType.PETRI_QUAKE:
			_trigger_quake()
		EventType.MIGRATION:
			_spawn_migration()

	event_started.emit(etype, _event_position, data["name"])
	event_started_minimap.emit(_event_position, etype, data["duration"])

func _end_event() -> void:
	var ended_type: int = _active_event
	match ended_type:
		EventType.NUTRIENT_BLOOM:
			_cleanup_bloom()
		EventType.EVOLUTIONARY_SURGE:
			_remove_surge()
		EventType.MIGRATION:
			_cleanup_migration()
	_cleanup_event()
	event_ended.emit(ended_type)

func _cleanup_event() -> void:
	_active_event = -1
	_event_position = Vector2.ZERO
	_event_remaining = 0.0
	_event_timer = 0.0
	_next_event_time = randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX)

# === NUTRIENT BLOOM ===

func _spawn_bloom_resources() -> void:
	_bloom_resources.clear()
	for i in range(5):
		var offset_angle: float = TAU * float(i) / 5.0 + randf_range(-0.3, 0.3)
		var offset_dist: float = randf_range(40.0, 120.0)
		var pos: Vector2 = _event_position + Vector2(cos(offset_angle) * offset_dist, sin(offset_angle) * offset_dist)
		var rn: Node2D = preload("res://scripts/rts_stage/resource_node.gd").new()
		rn.name = "BloomResource_%d" % i
		rn.biomass_remaining = 300
		rn.max_biomass = 300
		rn.add_to_group("rts_resources")
		rn.add_to_group("resource_nodes")
		rn.global_position = pos
		_stage.add_child(rn)
		_bloom_resources.append(rn)

func _cleanup_bloom() -> void:
	for res in _bloom_resources:
		if is_instance_valid(res):
			res.queue_free()
	_bloom_resources.clear()

# === TOXIC TIDE ===

func _tick_toxic_tide(delta: float) -> void:
	var data: Dictionary = EVENT_DATA[EventType.TOXIC_TIDE]
	var duration: float = data["duration"]
	var progress: float = 1.0 - (_event_remaining / duration)
	_toxic_radius = progress * 2000.0

	_toxic_tick_timer += delta
	if _toxic_tick_timer >= 0.5:
		_toxic_tick_timer -= 0.5
		# Damage all units inside the expanding radius
		for unit in get_tree().get_nodes_in_group("rts_units"):
			if not is_instance_valid(unit):
				continue
			if "health" in unit and unit.health <= 0:
				continue
			var dist: float = unit.global_position.distance_to(_event_position)
			if dist <= _toxic_radius:
				if unit.has_method("take_damage"):
					unit.take_damage(5.0, null)

# === EVOLUTIONARY SURGE ===

func _apply_surge() -> void:
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if is_instance_valid(unit):
			unit.set_meta("attack_speed_bonus", 0.3)

func _remove_surge() -> void:
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if is_instance_valid(unit):
			if unit.has_meta("attack_speed_bonus"):
				unit.remove_meta("attack_speed_bonus")

# === PETRI QUAKE ===

func _trigger_quake() -> void:
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if "health" in building and building.health <= 0:
			continue
		if building.has_method("take_damage"):
			building.take_damage(50.0, null)

# === MIGRATION ===

func _spawn_migration() -> void:
	_migration_creatures.clear()
	_migration_timer = 0.0
	# Start at _event_position (edge), move to opposite edge
	var start_pos: Vector2 = _event_position
	var end_pos: Vector2 = -start_pos  # Opposite side of map

	var NpcCreature := preload("res://scripts/rts_stage/npc_creature.gd")
	for i in range(8):
		var creature: CharacterBody2D = NpcCreature.new()
		creature.name = "MigrationNPC_%d" % i
		# Spread them in a line perpendicular to travel direction
		var travel_dir: Vector2 = (end_pos - start_pos).normalized()
		var perp: Vector2 = travel_dir.rotated(PI * 0.5)
		var spread: float = (float(i) - 3.5) * 40.0
		var spawn_pos: Vector2 = start_pos + perp * spread
		creature.global_position = spawn_pos
		_stage.add_child(creature)
		creature.setup(NpcCreature.CreatureType.SWARMLING, spawn_pos)
		# Override leash so they don't return home
		creature._leash_range = 99999.0
		creature.detection_range = 60.0
		creature.died.connect(_on_migration_creature_died.bind(creature))
		_migration_creatures.append({
			"node": creature,
			"start": spawn_pos,
			"end": end_pos + perp * spread,
		})

func _tick_migration(delta: float) -> void:
	var data: Dictionary = EVENT_DATA[EventType.MIGRATION]
	var duration: float = data["duration"]
	_migration_timer += delta
	var progress: float = clampf(_migration_timer / duration, 0.0, 1.0)

	for mc in _migration_creatures:
		var node: Node2D = mc["node"]
		if not is_instance_valid(node):
			continue
		if "health" in node and node.health <= 0:
			continue
		# Move toward interpolated position unless chasing a target
		if node._ai_state == node.AIState.PATROL or node._ai_state == node.AIState.RETURN:
			var target_pos: Vector2 = (mc["start"] as Vector2).lerp(mc["end"], progress)
			node._home_pos = target_pos
			node._patrol_target = target_pos
			if node._nav_agent:
				node._nav_agent.target_position = target_pos
			# Direct movement fallback
			var dir: Vector2 = (target_pos - node.global_position).normalized()
			node.velocity = dir * node.speed
			node.move_and_slide()
		# Check for nearby enemies to attack
		var nearest: Node2D = _find_nearest_unit_to(node, 60.0)
		if nearest and node._ai_state == node.AIState.PATROL:
			node._attack_target = nearest
			node._ai_state = node.AIState.CHASE

func _find_nearest_unit_to(creature: Node2D, detection: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = detection
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if unit == creature or not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id < 0:
			continue  # Don't attack other neutrals
		if "health" in unit and unit.health <= 0:
			continue
		var dist: float = creature.global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit
	return nearest

func _on_migration_creature_died(creature: Node2D) -> void:
	for i in range(_migration_creatures.size() - 1, -1, -1):
		if _migration_creatures[i]["node"] == creature:
			_migration_creatures.remove_at(i)
			break

func _cleanup_migration() -> void:
	for mc in _migration_creatures:
		if is_instance_valid(mc["node"]):
			mc["node"].queue_free()
	_migration_creatures.clear()

# === GETTERS ===

func get_active_event() -> int:
	return _active_event

func get_event_position() -> Vector2:
	return _event_position

func get_event_remaining() -> float:
	return _event_remaining

func is_warning_active() -> bool:
	return _warning_active

func get_warning_event_name() -> String:
	if _pending_event_type >= 0 and EVENT_DATA.has(_pending_event_type):
		return EVENT_DATA[_pending_event_type]["name"]
	return ""

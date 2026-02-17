extends Node
## Scans for enemy units near player buildings and emits threat alerts.
## Connected to HUD for screen-edge warning indicators.

signal threat_detected(threat_pos: Vector2, threat_count: int)
signal threat_cleared(threat_id: int)

const SCAN_INTERVAL: float = 1.5
const THREAT_RADIUS: float = 500.0
const MAX_ALERTS: int = 3
const ALERT_LIFETIME: float = 10.0

var _stage: Node = null
var _scan_timer: float = 0.0
var _active_threats: Array = []  # [{id, pos, count, time, faction_id}]
var _next_threat_id: int = 0

func setup(stage: Node) -> void:
	_stage = stage

func _process(delta: float) -> void:
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_for_threats()
	# Age out old threats
	for i in range(_active_threats.size() - 1, -1, -1):
		_active_threats[i]["time"] += delta
		if _active_threats[i]["time"] >= ALERT_LIFETIME:
			threat_cleared.emit(_active_threats[i]["id"])
			_active_threats.remove_at(i)

func _scan_for_threats() -> void:
	var player_buildings: Array = []
	for b in get_tree().get_nodes_in_group("faction_0"):
		if b is StaticBody2D:
			player_buildings.append(b)
	if player_buildings.is_empty():
		return
	for fid in range(1, 4):
		for enemy in get_tree().get_nodes_in_group("faction_" + str(fid)):
			if not (enemy is CharacterBody2D) or not is_instance_valid(enemy):
				continue
			for building in player_buildings:
				if enemy.global_position.distance_to(building.global_position) < THREAT_RADIUS:
					_register_threat(enemy.global_position, fid)
					break

func _register_threat(pos: Vector2, faction_id: int) -> void:
	# Merge with existing nearby threat
	for threat in _active_threats:
		if threat["pos"].distance_to(pos) < 200.0:
			threat["time"] = 0.0
			threat["count"] += 1
			return
	if _active_threats.size() >= MAX_ALERTS:
		return
	var threat: Dictionary = {
		"id": _next_threat_id,
		"pos": pos,
		"count": 1,
		"time": 0.0,
		"faction_id": faction_id
	}
	_next_threat_id += 1
	_active_threats.append(threat)
	threat_detected.emit(pos, 1)

func get_active_threats() -> Array:
	return _active_threats

func clear_threat(threat_id: int) -> void:
	for i in range(_active_threats.size()):
		if _active_threats[i]["id"] == threat_id:
			_active_threats.remove_at(i)
			return

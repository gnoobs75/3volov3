extends Node
## Auto-camera controller for AI-vs-AI spectator mode.

var _camera: Camera2D = null
var _target_pos: Vector2 = Vector2.ZERO
var _switch_timer: float = 0.0
const SWITCH_INTERVAL: float = 6.0
var _active: bool = false

func setup(camera: Camera2D) -> void:
	_camera = camera
	_active = true

func _process(delta: float) -> void:
	if not _active or not _camera:
		return
	_switch_timer += delta
	if _switch_timer >= SWITCH_INTERVAL:
		_switch_timer = 0.0
		_target_pos = _find_action_center()
	# Smooth camera lerp
	_camera.global_position = _camera.global_position.lerp(_target_pos, delta * 2.0)

func _find_action_center() -> Vector2:
	## Find the position with most combat activity
	var best_pos: Vector2 = Vector2.ZERO
	var best_score: float = 0.0
	# Check clusters of units from different factions
	var units: Array = get_tree().get_nodes_in_group("rts_units")
	if units.is_empty():
		return Vector2.ZERO
	# Sample 10 random units and score by nearby enemy density
	for _i in range(mini(10, units.size())):
		var u: Node2D = units[randi() % units.size()]
		if not is_instance_valid(u):
			continue
		var score: float = 0.0
		var fid: int = u.faction_id if "faction_id" in u else 0
		for other in units:
			if not is_instance_valid(other):
				continue
			if "faction_id" in other and other.faction_id != fid:
				var dist: float = u.global_position.distance_to(other.global_position)
				if dist < 300:
					score += 1.0 / maxf(dist * 0.01, 0.1)
		if score > best_score:
			best_score = score
			best_pos = u.global_position
	return best_pos if best_score > 0.5 else units[randi() % units.size()].global_position

extends Node
## Routes player commands to selected units: move, attack, gather, build, patrol, hold, stop.

enum CommandMode { NORMAL, ATTACK_MOVE, PATROL, BUILD }

var current_mode: CommandMode = CommandMode.NORMAL
var _patrol_first_point: Vector2 = Vector2.ZERO
var _waiting_patrol_second: bool = false
var _build_type: int = -1

signal command_issued(command: String, target_pos: Vector2)
signal build_mode_entered(building_type: int)
signal build_mode_exited()

func issue_move(units: Array, target_pos: Vector2) -> void:
	for unit in units:
		if is_instance_valid(unit) and unit.has_method("command_move"):
			unit.command_move(target_pos)
	AudioManager.play_rts_command()
	command_issued.emit("move", target_pos)

func issue_attack(units: Array, target: Node2D) -> void:
	for unit in units:
		if is_instance_valid(unit) and unit.has_method("command_attack"):
			unit.command_attack(target)
	AudioManager.play_rts_command()

func issue_attack_move(units: Array, target_pos: Vector2) -> void:
	for unit in units:
		if is_instance_valid(unit) and unit.has_method("command_move"):
			unit.command_move(target_pos)
			# Units will auto-retaliate enemies on the way
	AudioManager.play_rts_command()
	command_issued.emit("attack_move", target_pos)

func issue_gather(units: Array, target: Node2D) -> void:
	for i in range(units.size()):
		var unit: Node2D = units[i]
		if is_instance_valid(unit) and unit.has_method("command_gather"):
			unit.command_gather(target)
	AudioManager.play_rts_gather()

func issue_build(worker: Node2D, build_ghost: Node2D) -> void:
	if is_instance_valid(worker) and worker.has_method("command_build"):
		worker.command_build(build_ghost)
	AudioManager.play_rts_build_place()

func issue_patrol(units: Array, point_a: Vector2, point_b: Vector2) -> void:
	for unit in units:
		if is_instance_valid(unit) and unit.has_method("command_patrol"):
			unit.command_patrol(point_a, point_b)
	AudioManager.play_rts_command()
	command_issued.emit("patrol", point_b)

func issue_hold(units: Array) -> void:
	for unit in units:
		if is_instance_valid(unit) and unit.has_method("command_hold"):
			unit.command_hold()

func issue_stop(units: Array) -> void:
	for unit in units:
		if is_instance_valid(unit) and unit.has_method("command_stop"):
			unit.command_stop()

func issue_set_rally_point(building: Node2D, pos: Vector2) -> void:
	if is_instance_valid(building) and building.has_method("set_rally_point"):
		building.set_rally_point(pos)
	AudioManager.play_rts_command()

# === COMMAND MODE MANAGEMENT ===

func enter_attack_move_mode() -> void:
	current_mode = CommandMode.ATTACK_MOVE

func enter_patrol_mode() -> void:
	current_mode = CommandMode.PATROL
	_waiting_patrol_second = false

func enter_build_mode(building_type: int) -> void:
	current_mode = CommandMode.BUILD
	_build_type = building_type
	build_mode_entered.emit(building_type)

func exit_special_mode() -> void:
	current_mode = CommandMode.NORMAL
	_waiting_patrol_second = false
	_build_type = -1
	build_mode_exited.emit()

func handle_patrol_click(pos: Vector2, units: Array) -> bool:
	## Returns true if patrol was completed (second click)
	if not _waiting_patrol_second:
		_patrol_first_point = pos
		_waiting_patrol_second = true
		return false
	else:
		issue_patrol(units, _patrol_first_point, pos)
		_waiting_patrol_second = false
		current_mode = CommandMode.NORMAL
		return true

func get_build_type() -> int:
	return _build_type

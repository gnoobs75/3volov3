extends CharacterBody2D
## Base RTS unit with FSM, procedural _draw(), pathfinding, combat, and gathering.

signal died(unit: Node2D)
signal reached_target(unit: Node2D)

enum State { IDLE, MOVE, ATTACK, GATHER, BUILD, PATROL, RETURN_RESOURCES, FLEE, HOLD, REPAIR, HEALING, DEPLOYED }
enum Stance { AGGRESSIVE, DEFENSIVE, PASSIVE }

var faction_id: int = 0
var unit_type: int = UnitStats.UnitType.WORKER
var creature_template: CreatureTemplate = null

# Stats (modified by faction bonuses)
var health: float = 100.0
var max_health: float = 100.0
var armor: float = 0.0
var speed: float = 100.0
var damage: float = 10.0
var attack_range: float = 30.0
var attack_cooldown: float = 1.0
var detection_range: float = 200.0

# Gathering
var carry_capacity: int = 0
var carried_biomass: int = 0
var carried_genes: int = 0
var build_speed: float = 0.0
var _last_resource_group: String = ""  # Track the group of the last gathered resource

# Stance
var stance: int = Stance.DEFENSIVE
var _last_attacker: Node2D = null
var _anchor_position: Vector2 = Vector2.ZERO

# State
var state: State = State.IDLE
var _target_position: Vector2 = Vector2.ZERO
var _attack_target: Node2D = null
var _gather_target: Node2D = null
var _build_target: Node2D = null
var _repair_target: Node2D = null
var _patrol_point_a: Vector2 = Vector2.ZERO
var _patrol_point_b: Vector2 = Vector2.ZERO
var _patrol_going_to_b: bool = true
var _attack_timer: float = 0.0
var _gather_timer: float = 0.0
var _flee_timer: float = 0.0
var _flee_recalc: float = 0.0

# Selection
var is_selected: bool = false
var control_group: int = -1

# Command Queue (shift-queue)
var _command_queue: Array = []
const MAX_QUEUE: int = 8

# Tech tree reference (set by stage manager)
var _tech_tree: Node = null

# Terrain zones reference (set by stage manager)
var _terrain_zones: Node = null

# Stutter-step kiting (ranged units)
var _kite_timer: float = 0.0

# Auto-cast abilities
var _auto_cast: bool = false

# Formation hold
var _formation_slot: Vector2 = Vector2.ZERO
var _has_formation_slot: bool = false

# Worker auto-return to gather after building
var _last_gather_target: Node2D = null

# Abilities
var _ability_cooldown_timer: float = 0.0
var _ability_cooldown_max: float = 0.0
var _ability_active: bool = false
var _ability_timer: float = 0.0
var _is_fortified: bool = false
var _is_burst_gathering: bool = false
var _is_stunned: bool = false
var _stun_timer: float = 0.0

# Medic healing
var _heal_target: Node2D = null

# Siege Worm deploy
var _is_deployed: bool = false
var _deploy_timer: float = 0.0
var _deploying: bool = false  # True while deploying/undeploying

# Psi-Caster field
var _psi_field_timer: float = 0.0
var _neural_target: Node2D = null  # Current neural disruption target

# Veterancy
var _xp: int = 0
var _vet_level: int = 0
const VET_THRESHOLDS: Array = [0, 3, 8, 15]
const VET_HP_BONUS: Array = [0.0, 0.1, 0.2, 0.3]
const VET_DMG_BONUS: Array = [0.0, 0.1, 0.2, 0.3]
const VET_SPD_BONUS: Array = [0.0, 0.0, 0.05, 0.1]
const VET_CD_BONUS: Array = [1.0, 1.0, 1.0, 0.75]
var _last_combat_time: float = 999.0
var _base_max_health: float = 100.0
var _base_damage: float = 10.0
var _base_speed: float = 100.0
var _base_attack_cooldown: float = 1.0

# Visual
var _time: float = 0.0
var _cell_radius: float = 12.0
var _membrane_points: PackedVector2Array
var _blink_timer: float = 0.0
var _hurt_flash: float = 0.0
var _charge_moved: bool = false  # For fighter charge bonus
var _trail_positions: Array = []  # Ghost trail for speed-upgraded units

# Navigation
var _nav_agent: NavigationAgent2D = null
var _using_nav: bool = false

func _ready() -> void:
	add_to_group("rts_units")
	# Collision
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _cell_radius
	shape.shape = circle
	add_child(shape)
	# Navigation agent
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 8.0
	_nav_agent.target_desired_distance = 8.0
	_nav_agent.avoidance_enabled = true
	_nav_agent.radius = _cell_radius
	_nav_agent.max_speed = speed
	add_child(_nav_agent)
	_nav_agent.velocity_computed.connect(_on_velocity_computed)
	# Generate membrane shape
	_init_membrane()

func setup(p_faction_id: int, p_unit_type: int, p_template: CreatureTemplate) -> void:
	faction_id = p_faction_id
	unit_type = p_unit_type
	creature_template = p_template
	# Apply base stats
	var stats: Dictionary = UnitStats.get_stats(unit_type)
	var fd: Dictionary = FactionData.get_faction(faction_id)
	max_health = stats.get("hp", 100) * fd.get("hp_mult", 1.0)
	health = max_health
	armor = stats.get("armor", 0) * fd.get("armor_mult", 1.0)
	speed = stats.get("speed", 100.0) * fd.get("speed_mult", 1.0)
	damage = stats.get("damage", 10) * fd.get("attack_mult", 1.0)
	attack_range = stats.get("attack_range", 30.0)
	attack_cooldown = stats.get("attack_cooldown", 1.0)
	detection_range = stats.get("detection_range", 200.0)
	carry_capacity = stats.get("carry_capacity", 0)
	build_speed = stats.get("build_speed", 0.0) * fd.get("build_speed_mult", 1.0)
	# Store base stats for veterancy recalculation
	_base_max_health = max_health
	_base_damage = damage
	_base_speed = speed
	_base_attack_cooldown = attack_cooldown
	# Initialize ability cooldown from stats
	_ability_cooldown_max = stats.get("ability_cooldown", 0.0)
	if _nav_agent:
		_nav_agent.max_speed = speed
	# Update groups
	add_to_group("faction_%d" % faction_id)
	# Set cell radius based on unit type
	match unit_type:
		UnitStats.UnitType.DEFENDER: _cell_radius = 16.0
		UnitStats.UnitType.SCOUT: _cell_radius = 9.0
		UnitStats.UnitType.RANGED: _cell_radius = 11.0
		UnitStats.UnitType.MEDIC: _cell_radius = 11.0
		UnitStats.UnitType.SIEGE_WORM: _cell_radius = 14.0
		UnitStats.UnitType.PSI_CASTER: _cell_radius = 10.0
		_: _cell_radius = 12.0
	_init_membrane()

func _init_membrane() -> void:
	_membrane_points = PackedVector2Array()
	var num_pts: int = 16
	var handles: Array = creature_template.body_handles if creature_template else [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	for i in range(num_pts):
		var angle: float = TAU * float(i) / float(num_pts)
		var handle_idx: int = int(angle / (TAU / 8.0)) % 8
		var r: float = _cell_radius * handles[handle_idx] + randf_range(-1.0, 1.0)
		_membrane_points.append(Vector2(cos(angle) * r, sin(angle) * r))

func _physics_process(delta: float) -> void:
	_time += delta
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_kite_timer = maxf(_kite_timer - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	_blink_timer -= delta
	if _blink_timer < 0:
		_blink_timer = randf_range(3.0, 6.0)

	# Ability cooldown tick
	_ability_cooldown_timer = maxf(_ability_cooldown_timer - delta, 0.0)

	# Ability active timer tick
	if _ability_active:
		_ability_timer -= delta
		if _ability_timer <= 0:
			_ability_active = false
			_is_fortified = false
			_is_burst_gathering = false
			if has_meta("spore_reveal"):
				remove_meta("spore_reveal")
				remove_meta("spore_reveal_radius")

	# Stun timer tick
	if _is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0:
			_is_stunned = false
		else:
			velocity = Vector2.ZERO
			queue_redraw()
			return  # Skip state processing while stunned

	# Combat timer for veterancy + out-of-combat regen
	_last_combat_time += delta
	if _last_combat_time > 5.0 and health < max_health:
		var regen: float = 0.0
		if _tech_tree and _tech_tree.has_method("get_regen_rate"):
			regen = _tech_tree.get_regen_rate(faction_id)
		if regen > 0:
			health = minf(health + regen * delta, max_health)

	# Neural disruption debuff tick (on any unit that has it)
	if has_meta("neural_disruption_remaining"):
		var nd_rem: float = get_meta("neural_disruption_remaining") - delta
		if nd_rem <= 0:
			remove_meta("neural_disruption_remaining")
			remove_meta("neural_slow")
			remove_meta("neural_damage_mult")
		else:
			set_meta("neural_disruption_remaining", nd_rem)

	# Regen aura tick (on any unit that has the aura buff)
	if has_meta("regen_aura_remaining"):
		var ra_rem: float = get_meta("regen_aura_remaining") - delta
		if ra_rem <= 0:
			remove_meta("regen_aura_remaining")
		else:
			set_meta("regen_aura_remaining", ra_rem)
			# Heal 2 HP/s from regen aura
			health = minf(health + 2.0 * delta, max_health)

	# Psi-Caster passive psi field (every 0.5s)
	if unit_type == UnitStats.UnitType.PSI_CASTER:
		_psi_field_timer += delta
		if _psi_field_timer >= 0.5:
			_psi_field_timer = 0.0
			_apply_psi_field()

	# Deploy timer tick (Siege Worm)
	if _deploying:
		_deploy_timer -= delta
		if _deploy_timer <= 0:
			_deploying = false
			_is_deployed = not _is_deployed
			if _is_deployed:
				velocity = Vector2.ZERO
				state = State.DEPLOYED

	match state:
		State.IDLE:
			_process_idle(delta)
		State.MOVE:
			_process_move(delta)
		State.ATTACK:
			_process_attack(delta)
		State.GATHER:
			_process_gather(delta)
		State.BUILD:
			_process_build(delta)
		State.PATROL:
			_process_patrol(delta)
		State.RETURN_RESOURCES:
			_process_return_resources(delta)
		State.FLEE:
			_process_flee(delta)
		State.HOLD:
			_process_hold(delta)
		State.REPAIR:
			_process_repair(delta)
		State.HEALING:
			_process_healing(delta)
		State.DEPLOYED:
			_process_deployed(delta)

	# Auto-cast abilities when enabled
	_check_auto_cast()

	# Update ghost trail positions for speed upgrade visual (only when moving)
	if state == State.MOVE or state == State.PATROL or state == State.FLEE:
		_trail_positions.append(global_position)
		if _trail_positions.size() > 3:
			_trail_positions = _trail_positions.slice(-3)
	elif not _trail_positions.is_empty():
		_trail_positions.clear()

	queue_redraw()

# === STATE PROCESSORS ===

func _process_idle(_delta: float) -> void:
	# Update anchor position when idle (for defensive stance leash)
	_anchor_position = global_position
	# Advance command queue if pending
	if not _command_queue.is_empty():
		_advance_queue()
		return
	# Auto-retaliate: find nearby enemies
	_check_auto_retaliate()

func _process_move(delta: float) -> void:
	if _nav_agent.is_navigation_finished():
		state = State.IDLE
		_anchor_position = global_position
		reached_target.emit(self)
		return
	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	_nav_agent.velocity = dir * speed
	_charge_moved = true

func _process_attack(delta: float) -> void:
	if not is_instance_valid(_attack_target):
		_attack_target = null
		# Formation hold: return to formation slot instead of going IDLE
		if _has_formation_slot:
			command_move(_formation_slot)
			_has_formation_slot = true  # Re-set since command_move clears it
		else:
			state = State.IDLE
		return
	var dist: float = global_position.distance_to(_attack_target.global_position)
	# Formation hold: don't chase target beyond 80u from formation slot
	if _has_formation_slot and dist > attack_range:
		var dist_from_slot: float = global_position.distance_to(_formation_slot)
		if dist_from_slot > 80.0:
			# Too far from formation slot, return to it
			_attack_target = null
			command_move(_formation_slot)
			_has_formation_slot = true  # Re-set since command_move clears it
			return
	# Defensive stance leash: don't chase beyond 80u from anchor position
	if stance == Stance.DEFENSIVE and dist > attack_range:
		var dist_from_anchor: float = global_position.distance_to(_anchor_position)
		if dist_from_anchor > 80.0:
			_attack_target = null
			command_move(_anchor_position)
			return
	if dist > attack_range:
		# Move toward target
		_nav_agent.target_position = _attack_target.global_position
		var next_pos: Vector2 = _nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		_nav_agent.velocity = dir * speed
		_charge_moved = true
	else:
		# Stutter-step kiting for ranged units
		if unit_type == UnitStats.UnitType.RANGED and _kite_timer > 0 and state != State.HOLD:
			if dist < attack_range * 0.7:
				# Target is getting close, kite away at 60% speed
				var away_dir: Vector2 = (global_position - _attack_target.global_position).normalized()
				var kite_pos: Vector2 = global_position + away_dir * 60.0
				_nav_agent.target_position = kite_pos
				var next_pos: Vector2 = _nav_agent.get_next_path_position()
				_nav_agent.velocity = (next_pos - global_position).normalized() * speed * 0.6
				return
		# In range — attack
		velocity = Vector2.ZERO
		if _attack_timer <= 0:
			_perform_attack()
			_attack_timer = attack_cooldown
			# Trigger stutter-step for ranged units after attacking
			if unit_type == UnitStats.UnitType.RANGED and state != State.HOLD:
				_kite_timer = 0.4

func _process_gather(delta: float) -> void:
	if not is_instance_valid(_gather_target) or _gather_target.is_depleted():
		# Remember the resource group before clearing
		if is_instance_valid(_gather_target):
			_last_resource_group = _get_resource_group(_gather_target)
		_gather_target = null
		if carried_biomass > 0 or carried_genes > 0:
			state = State.RETURN_RESOURCES
			_navigate_to_nearest_depot()
		else:
			# Try to find another resource of same type
			var new_res: Node2D = _find_nearest_resource()
			if new_res:
				command_gather(new_res)
			else:
				state = State.IDLE
		return
	var dist: float = global_position.distance_to(_gather_target.global_position)
	if dist > 30.0:
		_nav_agent.target_position = _gather_target.global_position
		var next_pos: Vector2 = _nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		_nav_agent.velocity = dir * speed
	else:
		velocity = Vector2.ZERO
		_gather_timer += delta
		if _gather_timer >= 1.0:
			_gather_timer = 0.0
			var gather_amount: int = 2
			if _is_burst_gathering:
				gather_amount *= 3
			var harvested: Dictionary = _gather_target.harvest(gather_amount)
			carried_biomass += harvested.get("biomass", 0)
			carried_genes += harvested.get("genes", 0)
			if carried_biomass + carried_genes >= carry_capacity:
				state = State.RETURN_RESOURCES
				_navigate_to_nearest_depot()

func _process_build(delta: float) -> void:
	if not is_instance_valid(_build_target):
		_build_target = null
		_try_auto_return_gather()
		return
	var dist: float = global_position.distance_to(_build_target.global_position)
	if dist > 40.0:
		_nav_agent.target_position = _build_target.global_position
		var next_pos: Vector2 = _nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		_nav_agent.velocity = dir * speed
	else:
		velocity = Vector2.ZERO
		if _build_target.has_method("add_construction"):
			_build_target.add_construction(build_speed * delta)
			if _build_target.has_method("is_complete") and _build_target.is_complete():
				_build_target = null
				_try_auto_return_gather()

func _process_patrol(_delta: float) -> void:
	var target: Vector2 = _patrol_point_b if _patrol_going_to_b else _patrol_point_a
	_nav_agent.target_position = target
	if _nav_agent.is_navigation_finished():
		_patrol_going_to_b = not _patrol_going_to_b
	else:
		var next_pos: Vector2 = _nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		_nav_agent.velocity = dir * speed
	# Check for enemies while patrolling
	_check_auto_retaliate()

func _process_return_resources(_delta: float) -> void:
	if _nav_agent.is_navigation_finished():
		# Deposit resources
		var stage: Node = get_tree().get_first_node_in_group("rts_stage")
		if stage and stage.has_method("get_resource_manager"):
			var rm: Node = stage.get_resource_manager()
			if rm:
				rm.add_biomass(faction_id, carried_biomass)
				rm.add_genes(faction_id, carried_genes)
				# Track resources gathered for stats (player faction only)
				if faction_id == 0 and stage.has_method("get_victory_manager"):
					var vm: Node = stage.get_victory_manager()
					if vm and "stats_resources_gathered" in vm:
						vm.stats_resources_gathered += carried_biomass + carried_genes
		carried_biomass = 0
		carried_genes = 0
		# Return to gather source
		if is_instance_valid(_gather_target) and not _gather_target.is_depleted():
			state = State.GATHER
		else:
			# Gather target depleted — auto-find nearest non-depleted resource of same group
			if is_instance_valid(_gather_target):
				_last_resource_group = _get_resource_group(_gather_target)
			_gather_target = null
			var new_res: Node2D = _find_nearest_resource()
			if new_res:
				command_gather(new_res)
			else:
				state = State.IDLE
		return
	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	_nav_agent.velocity = dir * speed

func _process_hold(_delta: float) -> void:
	# Hold position but still attack enemies in range
	_check_auto_retaliate()

func _process_flee(delta: float) -> void:
	_flee_timer += delta
	_flee_recalc += delta
	# After 3 seconds, stop fleeing
	if _flee_timer >= 3.0:
		state = State.IDLE
		_flee_timer = 0.0
		_flee_recalc = 0.0
		velocity = Vector2.ZERO
		return
	# Find nearest enemy and flee away from it (recalculate every 0.5s)
	if _flee_recalc >= 0.5 or _flee_recalc == delta:  # First frame or recalc interval
		_flee_recalc = 0.0
		var nearest_enemy: Node2D = null
		var nearest_dist: float = INF
		for unit in get_tree().get_nodes_in_group("rts_units"):
			if not is_instance_valid(unit) or unit == self:
				continue
			if "faction_id" in unit and unit.faction_id == faction_id:
				continue
			var dist: float = global_position.distance_to(unit.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = unit
		if nearest_enemy == null or nearest_dist > 200.0:
			# No enemies nearby, stop fleeing
			state = State.IDLE
			_flee_timer = 0.0
			_flee_recalc = 0.0
			velocity = Vector2.ZERO
			return
		# Flee away from nearest enemy at 130% speed
		var flee_dir: Vector2 = (global_position - nearest_enemy.global_position).normalized()
		var flee_pos: Vector2 = global_position + flee_dir * 150.0
		_nav_agent.target_position = flee_pos
	# Move along nav path at boosted speed
	if not _nav_agent.is_navigation_finished():
		var next_pos: Vector2 = _nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		_nav_agent.velocity = dir * speed * 1.3

func _process_repair(delta: float) -> void:
	if not is_instance_valid(_repair_target) or not _repair_target.is_in_group("rts_buildings"):
		_repair_target = null
		state = State.IDLE
		return
	# Check if target is fully healed
	if "health" in _repair_target and "max_health" in _repair_target:
		if _repair_target.health >= _repair_target.max_health:
			_repair_target = null
			state = State.IDLE
			return
	var dist: float = global_position.distance_to(_repair_target.global_position)
	if dist > 40.0:
		_nav_agent.target_position = _repair_target.global_position
		var next_pos: Vector2 = _nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		_nav_agent.velocity = dir * speed
	else:
		velocity = Vector2.ZERO
		if _repair_target.has_method("take_repair"):
			_repair_target.take_repair(15.0 * delta)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

# === RESOURCE HELPERS ===

func _get_resource_group(res: Node2D) -> String:
	## Returns a string identifying the resource type/group.
	if res.has_method("get_resource_type"):
		return str(res.get_resource_type())
	# Fallback: use the node's groups (look for rts_resource subtypes)
	for g in res.get_groups():
		if g != "rts_resources":
			return g
	return "rts_resources"

func _find_nearest_resource() -> Node2D:
	## Searches "rts_resources" group for nearest non-depleted resource.
	## Prefers resources of same group as _last_resource_group if set.
	var nearest: Node2D = null
	var nearest_dist: float = INF
	var nearest_same_type: Node2D = null
	var nearest_same_dist: float = INF
	for res in get_tree().get_nodes_in_group("rts_resources"):
		if not is_instance_valid(res):
			continue
		if res.has_method("is_depleted") and res.is_depleted():
			continue
		var dist: float = global_position.distance_to(res.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = res
		# Check if same type as last gathered
		if _last_resource_group != "" and _get_resource_group(res) == _last_resource_group:
			if dist < nearest_same_dist:
				nearest_same_dist = dist
				nearest_same_type = res
	# Prefer same type if found
	if nearest_same_type:
		return nearest_same_type
	return nearest

# === COMMANDS ===

func command_move(target_pos: Vector2) -> void:
	state = State.MOVE
	_target_position = target_pos
	_nav_agent.target_position = target_pos
	_charge_moved = false
	_has_formation_slot = false
	if faction_id == 0:
		AudioManager.play_rts_unit_voice(unit_type, "ack")

func command_attack(target: Node2D) -> void:
	state = State.ATTACK
	_attack_target = target
	_charge_moved = false
	if faction_id == 0:
		AudioManager.play_rts_unit_voice(unit_type, "attack")

func command_gather(target: Node2D) -> void:
	if carry_capacity <= 0:
		return
	state = State.GATHER
	_gather_target = target
	_last_gather_target = target
	_gather_timer = 0.0
	_last_resource_group = _get_resource_group(target)
	if target.has_method("add_worker"):
		target.add_worker()
	if faction_id == 0:
		AudioManager.play_rts_unit_voice(unit_type, "ack")

func command_build(target: Node2D) -> void:
	if build_speed <= 0:
		return
	state = State.BUILD
	_build_target = target

func command_repair(target: Node2D) -> void:
	if unit_type != UnitStats.UnitType.WORKER:
		return
	_repair_target = target
	state = State.REPAIR

func command_patrol(point_a: Vector2, point_b: Vector2) -> void:
	state = State.PATROL
	_patrol_point_a = point_a
	_patrol_point_b = point_b
	_patrol_going_to_b = true

func command_hold() -> void:
	state = State.HOLD
	velocity = Vector2.ZERO
	_anchor_position = global_position

func command_flee() -> void:
	state = State.FLEE
	_flee_timer = 0.0
	_flee_recalc = 0.0
	velocity = Vector2.ZERO
	_attack_target = null
	_gather_target = null
	_build_target = null
	_repair_target = null
	_has_formation_slot = false
	clear_command_queue()

func command_stop() -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	_attack_target = null
	_gather_target = null
	_build_target = null
	_repair_target = null
	_has_formation_slot = false
	_anchor_position = global_position
	clear_command_queue()

func cycle_stance() -> void:
	stance = ((stance + 1) % 3) as Stance
	_anchor_position = global_position

# === COMMAND QUEUE (shift-queue) ===

func queue_command(cmd: Dictionary) -> void:
	## Append a command to the queue. Dict: {"type": String, "target_pos": Vector2, "target_node": Node2D}
	if _command_queue.size() >= MAX_QUEUE:
		return
	_command_queue.append(cmd)

func get_command_queue() -> Array:
	return _command_queue

func clear_command_queue() -> void:
	_command_queue.clear()

func _advance_queue() -> void:
	## Pop front command and dispatch to appropriate command method.
	if _command_queue.is_empty():
		return
	var cmd: Dictionary = _command_queue.pop_front()
	var cmd_type: String = cmd.get("type", "")
	match cmd_type:
		"move":
			var pos: Vector2 = cmd.get("target_pos", global_position)
			command_move(pos)
		"attack_move":
			var pos: Vector2 = cmd.get("target_pos", global_position)
			command_move(pos)  # Units auto-retaliate enemies on the way
		"attack":
			var target: Node2D = cmd.get("target_node", null)
			if is_instance_valid(target):
				command_attack(target)
			else:
				_advance_queue()  # Skip invalid, try next
		"gather":
			var target: Node2D = cmd.get("target_node", null)
			if is_instance_valid(target) and not (target.has_method("is_depleted") and target.is_depleted()):
				command_gather(target)
			else:
				_advance_queue()
		"build":
			var target: Node2D = cmd.get("target_node", null)
			if is_instance_valid(target):
				command_build(target)
			else:
				_advance_queue()
		"patrol":
			var pa: Vector2 = cmd.get("patrol_a", global_position)
			var pb: Vector2 = cmd.get("target_pos", global_position)
			command_patrol(pa, pb)
		"repair":
			var target: Node2D = cmd.get("target_node", null)
			if is_instance_valid(target):
				command_repair(target)
			else:
				_advance_queue()
		"hold":
			command_hold()
		"stop":
			command_stop()
		_:
			pass  # Unknown command type, skip

# === COMBAT ===

func _perform_attack() -> void:
	if not is_instance_valid(_attack_target):
		return
	_last_combat_time = 0.0
	var actual_damage: float = damage
	# Tech tree damage bonus
	if _tech_tree and _tech_tree.has_method("get_damage_bonus"):
		actual_damage += _tech_tree.get_damage_bonus(faction_id)
	# Berserker enzymes: 2x damage below 30% HP
	if _tech_tree and _tech_tree.has_method("get_berserker_mult") and health < max_health * 0.3:
		actual_damage *= _tech_tree.get_berserker_mult(faction_id)
	# Terrain elevation bonus
	if _terrain_zones and is_instance_valid(_terrain_zones) and _terrain_zones.has_method("get_elevation_bonus"):
		actual_damage *= _terrain_zones.get_elevation_bonus(global_position, _attack_target.global_position)
	# Fighter charge bonus
	if unit_type == UnitStats.UnitType.FIGHTER and _charge_moved:
		actual_damage *= UnitStats.get_stats(unit_type).get("charge_bonus", 1.0)
		_charge_moved = false
	# Ranged: fire projectile
	if unit_type == UnitStats.UnitType.RANGED:
		# Spitter min_range: flee if enemy is too close
		var dist: float = global_position.distance_to(_attack_target.global_position)
		if dist < 40.0:
			# Kite away from target
			var flee_dir: Vector2 = (global_position - _attack_target.global_position).normalized()
			var flee_pos: Vector2 = global_position + flee_dir * 80.0
			_nav_agent.target_position = flee_pos
			var next_pos: Vector2 = _nav_agent.get_next_path_position()
			_nav_agent.velocity = (next_pos - global_position).normalized() * speed
			return
		_fire_projectile(_attack_target)
	else:
		# Melee: direct damage
		var stage: Node = get_tree().get_first_node_in_group("rts_stage")
		if stage and stage.has_method("get_combat_system"):
			var cs: Node = stage.get_combat_system()
			if _attack_target.is_in_group("rts_buildings"):
				cs.apply_building_damage(_attack_target, actual_damage, self)
			elif _attack_target.has_method("take_damage"):
				cs.apply_damage(_attack_target, actual_damage, self)
	AudioManager.play_rts_attack()

func _fire_projectile(target: Node2D) -> void:
	var proj := preload("res://scripts/rts_stage/rts_projectile.gd").new()
	proj.setup(global_position, target, damage, faction_id)
	get_parent().add_child(proj)

func take_damage(amount: float, _attacker: Node2D = null) -> void:
	# Tech tree armor + fortify bonus
	var effective_amount: float = amount
	var total_armor: float = armor
	if _tech_tree and _tech_tree.has_method("get_armor_bonus"):
		total_armor += _tech_tree.get_armor_bonus(faction_id)
	if _tech_tree and _tech_tree.has_method("get_hive_armor"):
		var nearby: int = _count_nearby_allies(80.0)
		total_armor += _tech_tree.get_hive_armor(faction_id, nearby)
	if _is_fortified:
		total_armor += UnitStats.get_stats(unit_type).get("ability_armor_bonus", 0.0)
	effective_amount = maxf(amount - total_armor, 1.0)
	health -= effective_amount
	_hurt_flash = 1.0
	_last_combat_time = 0.0
	# Track last attacker for defensive stance
	if is_instance_valid(_attacker):
		_last_attacker = _attacker
	if health <= 0:
		# Grant XP to attacker on kill
		if is_instance_valid(_attacker) and _attacker.has_method("grant_xp"):
			_attacker.grant_xp(1)
		_die()
	elif state == State.IDLE and is_instance_valid(_attacker) and stance != Stance.PASSIVE:
		# Auto-retaliate (not in passive stance)
		command_attack(_attacker)

func _count_nearby_allies(radius: float) -> int:
	var count: int = 0
	for u in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if u != self and is_instance_valid(u) and u is CharacterBody2D:
			if u.global_position.distance_squared_to(global_position) < radius * radius:
				count += 1
	return count

func _die() -> void:
	if is_instance_valid(_gather_target) and _gather_target.has_method("remove_worker"):
		_gather_target.remove_worker()
	died.emit(self)
	queue_free()

func _find_best_target(enemies: Array) -> Node2D:
	## Score enemies by priority: attacking me > lowest HP > nearest.
	## Stance modifies target selection:
	##   PASSIVE: never auto-acquire targets
	##   DEFENSIVE: only auto-target _last_attacker if alive and in range
	##   AGGRESSIVE: full detection range scan (default)
	if stance == Stance.PASSIVE:
		return null
	if stance == Stance.DEFENSIVE:
		# Only auto-target the last unit that attacked us
		if is_instance_valid(_last_attacker) and "faction_id" in _last_attacker and _last_attacker.faction_id != faction_id:
			var dist: float = global_position.distance_to(_last_attacker.global_position)
			if dist <= detection_range:
				return _last_attacker
		return null
	# Aggressive: score all enemies normally
	var best: Node2D = null
	var best_score: float = -1.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var score: float = 0.0
		# Priority: enemy is attacking me
		if enemy.has_meta("attack_target") and enemy.get_meta("attack_target") == self:
			score += 1000.0
		elif "_attack_target" in enemy and is_instance_valid(enemy._attack_target) and enemy._attack_target == self:
			score += 1000.0
		# Priority: low HP ratio
		if "health" in enemy and "max_health" in enemy and enemy.max_health > 0:
			score += (1.0 - enemy.health / enemy.max_health) * 100.0
		# Priority: proximity (closer = higher score)
		var dist: float = global_position.distance_to(enemy.global_position)
		if detection_range > 0:
			score += (1.0 - dist / detection_range) * 50.0
		if score > best_score:
			best_score = score
			best = enemy
	return best

func _check_auto_retaliate() -> void:
	# Passive stance: never auto-attack or auto-retaliate
	if stance == Stance.PASSIVE:
		return
	if state == State.ATTACK and is_instance_valid(_attack_target):
		return
	# Defensive stance: only engage _last_attacker if alive and in range
	if stance == Stance.DEFENSIVE:
		if is_instance_valid(_last_attacker) and "faction_id" in _last_attacker and _last_attacker.faction_id != faction_id:
			var dist: float = global_position.distance_to(_last_attacker.global_position)
			if dist <= detection_range:
				command_attack(_last_attacker)
		return
	# Aggressive stance: scan for all enemies in detection range
	var enemies_in_range: Array = []
	# Check for defender taunt -- prefer attacking defenders within 80 units
	var taunting_defender: Node2D = null
	var taunt_dist: float = 80.0
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if unit == self or not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id == faction_id:
			continue
		var dist: float = global_position.distance_to(unit.global_position)
		# Defender taunt: prioritize defenders within taunt range
		if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.DEFENDER and dist < taunt_dist:
			taunt_dist = dist
			taunting_defender = unit
		if dist < detection_range:
			enemies_in_range.append(unit)
	if taunting_defender:
		command_attack(taunting_defender)
	elif not enemies_in_range.is_empty():
		var best: Node2D = _find_best_target(enemies_in_range)
		if best:
			command_attack(best)

func _navigate_to_nearest_depot() -> void:
	var nearest_depot: Node2D = null
	var nearest_dist: float = INF
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		if "faction_id" in building and building.faction_id == faction_id:
			if "is_depot" in building and building.is_depot:
				var dist: float = global_position.distance_to(building.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_depot = building
	if nearest_depot:
		_nav_agent.target_position = nearest_depot.global_position

# === DRAWING ===

func _is_on_screen() -> bool:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return true
	var cam_pos: Vector2 = camera.global_position
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: float = camera.zoom.x if camera.zoom.x > 0 else 1.0
	var margin: float = 50.0  # Extra margin to avoid pop-in
	var half_view: Vector2 = vp_size / (2.0 * zoom) + Vector2(margin, margin)
	var diff: Vector2 = (global_position - cam_pos).abs()
	return diff.x < half_view.x and diff.y < half_view.y

func _draw() -> void:
	if not creature_template:
		# Fallback simple draw
		draw_circle(Vector2.ZERO, _cell_radius, FactionData.get_faction_color(faction_id))
		return

	# Skip detailed drawing if off-screen
	if not _is_on_screen():
		return

	var mc: Color = creature_template.membrane_color
	var ic: Color = creature_template.interior_color
	var gc: Color = creature_template.glow_color

	# 1. Selection ring (animated dashed arc)
	if is_selected:
		var sel_r: float = _cell_radius + 4.0
		var sel_color: Color = Color(0.2, 1.0, 0.3, 0.8)
		# Rotating dashed selection ring
		var dash_count: int = 8
		var dash_arc: float = TAU / float(dash_count) * 0.6
		var gap_arc: float = TAU / float(dash_count) * 0.4
		var ring_offset: float = _time * 1.5
		for di in range(dash_count):
			var start_a: float = ring_offset + float(di) * (dash_arc + gap_arc)
			draw_arc(Vector2.ZERO, sel_r, start_a, start_a + dash_arc, 6, sel_color, 1.5)
		# Inner glow ring
		draw_arc(Vector2.ZERO, sel_r - 1.0, 0, TAU, 16, Color(0.2, 1.0, 0.3, 0.15), 3.0)
		# Attack range indicator (subtle)
		if unit_type != UnitStats.UnitType.WORKER:
			draw_arc(Vector2.ZERO, attack_range, 0, TAU, 32, Color(1.0, 0.4, 0.3, 0.08), 1.0)
		# Control group number
		if control_group >= 0:
			var cg_text: String = str(control_group)
			var cg_font: Font = UIConstants.get_mono_font()
			draw_string(cg_font, Vector2(-3, -_cell_radius - 8), cg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.2, 1.0, 0.3, 0.9))

	# 2. Glow
	draw_circle(Vector2.ZERO, _cell_radius * 2.0, Color(gc.r, gc.g, gc.b, 0.06))

	# 3. Hurt flash
	if _hurt_flash > 0:
		draw_circle(Vector2.ZERO, _cell_radius * 1.5, Color(1.0, 0.2, 0.2, _hurt_flash * 0.3))

	# 4. Interior
	draw_circle(Vector2.ZERO, _cell_radius * 0.75, ic)

	# 5. Membrane body
	if _membrane_points.size() >= 3:
		var animated_pts := PackedVector2Array()
		for i in range(_membrane_points.size()):
			var p: Vector2 = _membrane_points[i]
			var wobble: float = sin(_time * 2.0 + float(i) * 0.5) * 0.8
			animated_pts.append(p + p.normalized() * wobble)
		draw_colored_polygon(animated_pts, mc)

	# 6. Unit-type decorations
	_draw_unit_decorations()

	# 7. Face (eyes)
	_draw_face()

	# 8. Health bar
	_draw_health_bar()

	# 9. Carry indicator (worker)
	if carried_biomass > 0 or carried_genes > 0:
		_draw_carry_indicator()

	# 10. Veterancy stars
	if _vet_level > 0:
		_draw_veterancy_stars()

	# 11. Ability cooldown indicator
	if _ability_cooldown_timer > 0 and _ability_cooldown_max > 0:
		_draw_ability_cooldown()

	# 12. Fortify ring
	if _is_fortified:
		_draw_fortify_ring()

	# 13. Stun indicator
	if _is_stunned:
		_draw_stun_indicator()

	# 14. Burst gather glow
	if _is_burst_gathering:
		draw_circle(Vector2.ZERO, _cell_radius * 1.3, Color(0.3, 0.9, 0.4, 0.12 + 0.06 * sin(_time * 5.0)))

	# 15. Command queue waypoints (shift-queue visualization)
	if is_selected and not _command_queue.is_empty():
		_draw_command_queue()

	# 16. Tech tree upgrade visuals
	_draw_upgrade_indicators()

	# 17. Patrol route visualization (selected patrolling units)
	if state == State.PATROL and is_selected:
		_draw_patrol_route()

	# 18. Stance indicator (only when selected)
	if is_selected:
		_draw_stance_indicator()

func _draw_command_queue() -> void:
	## Draw faint lines from current position through queued waypoints, with numbered dots.
	var queue_color: Color = Color(0.5, 0.9, 1.0, 0.35)
	var dot_color: Color = Color(0.5, 0.9, 1.0, 0.6)
	var prev_pos: Vector2 = Vector2.ZERO  # Local coords (unit is at origin)
	for i in range(_command_queue.size()):
		var cmd: Dictionary = _command_queue[i]
		var wp: Vector2 = Vector2.ZERO
		var has_pos: bool = false
		if cmd.has("target_pos"):
			wp = cmd["target_pos"] - global_position  # Convert to local
			has_pos = true
		elif cmd.has("target_node") and is_instance_valid(cmd["target_node"]):
			wp = cmd["target_node"].global_position - global_position
			has_pos = true
		if not has_pos:
			continue
		# Draw line from previous waypoint (or unit) to this one
		draw_line(prev_pos, wp, queue_color, 1.0)
		# Draw numbered dot
		draw_circle(wp, 3.5, dot_color)
		draw_circle(wp, 2.0, Color(0.1, 0.15, 0.2, 0.8))
		# Number label
		var num_font: Font = ThemeDB.fallback_font
		if num_font:
			draw_string(num_font, wp + Vector2(-2.5, 3.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.95, 1.0, 0.9))
		prev_pos = wp

func _draw_unit_decorations() -> void:
	match unit_type:
		UnitStats.UnitType.FIGHTER:
			# Spikes
			for i in range(4):
				var angle: float = TAU * float(i) / 4.0 + _time * 0.2
				var start: Vector2 = Vector2(cos(angle), sin(angle)) * _cell_radius
				var end: Vector2 = Vector2(cos(angle), sin(angle)) * (_cell_radius + 6.0)
				var mc: Color = creature_template.membrane_color if creature_template else Color.WHITE
				draw_line(start, end, Color(mc.r * 1.3, mc.g * 0.8, mc.b * 0.8, 0.9), 2.0)
		UnitStats.UnitType.DEFENDER:
			# Armor ring
			draw_arc(Vector2.ZERO, _cell_radius + 2.0, 0, TAU, 20, Color(0.7, 0.65, 0.5, 0.5), 3.0)
		UnitStats.UnitType.SCOUT:
			# Trailing cilia
			for i in range(3):
				var angle: float = PI + float(i - 1) * 0.4  # Behind
				var start: Vector2 = Vector2(cos(angle), sin(angle)) * _cell_radius
				var end: Vector2 = start + Vector2(cos(angle), sin(angle)) * (8.0 + sin(_time * 4.0 + float(i)) * 3.0)
				var cc: Color = creature_template.glow_color if creature_template else Color.CYAN
				draw_line(start, end, Color(cc.r, cc.g, cc.b, 0.6), 1.5)
		UnitStats.UnitType.RANGED:
			# Glowing antenna
			var tip: Vector2 = Vector2(-_cell_radius - 5.0, 0)
			var base: Vector2 = Vector2(-_cell_radius * 0.5, 0)
			var gc: Color = creature_template.glow_color if creature_template else Color.GREEN
			draw_line(base, tip, Color(gc.r, gc.g, gc.b, 0.8), 1.5)
			draw_circle(tip, 2.5, Color(gc.r, gc.g, gc.b, 0.5 + 0.3 * sin(_time * 3.0)))
		UnitStats.UnitType.WORKER:
			# Carry sac (visible when carrying)
			if carried_biomass > 0 or carried_genes > 0:
				var sac_pos: Vector2 = Vector2(_cell_radius * 0.3, 0)
				var fill: float = float(carried_biomass + carried_genes) / float(maxi(carry_capacity, 1))
				draw_circle(sac_pos, 4.0 * fill + 2.0, Color(0.3, 0.8, 0.4, 0.5))

func _draw_face() -> void:
	if not creature_template:
		return
	var eyes: Array = creature_template.eye_data
	if eyes.is_empty():
		eyes = [{"x": -0.15, "y": -0.2, "size": 2.5, "style": "anime"},
				{"x": -0.15, "y": 0.2, "size": 2.5, "style": "anime"}]
	var is_blinking: bool = _blink_timer > 0 and _blink_timer < 0.15
	for eye in eyes:
		var ex: float = eye.get("x", -0.15) * _cell_radius
		var ey: float = eye.get("y", -0.2) * _cell_radius
		var es: float = eye.get("size", 2.5) * (_cell_radius / 12.0)
		var style: String = eye.get("style", "anime")
		var pos: Vector2 = Vector2(ex, ey)
		if is_blinking:
			# Closed eye - horizontal line
			draw_line(pos - Vector2(es * 0.4, 0), pos + Vector2(es * 0.4, 0), Color.BLACK, 1.0)
			continue
		match style:
			"anime":
				draw_circle(pos, es, Color.WHITE)
				draw_circle(pos + Vector2(0.2, 0.2) * es, es * 0.5, creature_template.membrane_color.lightened(0.3))
				draw_circle(pos + Vector2(0.3, 0.3) * es, es * 0.25, Color.BLACK)
				draw_circle(pos + Vector2(0.5, 0.1) * es, es * 0.12, Color.WHITE)
			"compound":
				for j in range(5):
					var ca: float = TAU * float(j) / 5.0
					var cp: Vector2 = pos + Vector2(cos(ca), sin(ca)) * es * 0.3
					draw_circle(cp, es * 0.25, Color.BLACK)
					draw_circle(cp, es * 0.15, Color(0.3, 0.6, 0.3, 0.8))
			"slit":
				draw_circle(pos, es, Color(0.9, 0.8, 0.2))
				draw_line(pos - Vector2(0, es * 0.6), pos + Vector2(0, es * 0.6), Color.BLACK, es * 0.2)
			"fierce":
				draw_circle(pos, es, Color(0.9, 0.1, 0.1))
				draw_circle(pos, es * 0.4, Color.BLACK)
				# Angry brow
				draw_line(pos + Vector2(-es, -es * 0.8), pos + Vector2(0, -es * 0.4), Color.BLACK, 1.5)
			_:
				draw_circle(pos, es, Color.WHITE)
				draw_circle(pos, es * 0.4, Color.BLACK)

func _draw_health_bar() -> void:
	if health >= max_health:
		return
	var bar_w: float = _cell_radius * 2.0
	var bar_h: float = 2.5
	var bar_y: float = -_cell_radius - 6.0
	var fill: float = clampf(health / max_health, 0.0, 1.0)
	# Background
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.7))
	# Fill
	var bar_color: Color = Color(0.2, 0.9, 0.3) if fill > 0.5 else Color(0.9, 0.9, 0.2) if fill > 0.25 else Color(0.9, 0.2, 0.2)
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * fill, bar_h), bar_color)

func _draw_carry_indicator() -> void:
	var total: int = carried_biomass + carried_genes
	var cap: int = maxi(carry_capacity, 1)
	var fill: float = float(total) / float(cap)
	var indicator_y: float = _cell_radius + 4.0
	draw_rect(Rect2(-5.0, indicator_y, 10.0 * fill, 2.0), Color(0.3, 0.9, 0.5, 0.6))

func _draw_veterancy_stars() -> void:
	## Draw gold 5-pointed stars above health bar based on vet level (1-3).
	var star_y: float = -_cell_radius - 12.0
	var star_color: Color = Color(1.0, 0.85, 0.2, 0.9)
	var star_size: float = 2.5
	var spacing: float = 7.0
	var total_w: float = float(_vet_level - 1) * spacing
	var start_x: float = -total_w * 0.5
	for i in range(_vet_level):
		var cx: float = start_x + float(i) * spacing
		var center: Vector2 = Vector2(cx, star_y)
		_draw_star(center, star_size, 5, star_color)

func _draw_star(center: Vector2, radius: float, points: int, color: Color) -> void:
	## Draw a filled 5-pointed star.
	var pts: PackedVector2Array = PackedVector2Array()
	var inner_r: float = radius * 0.4
	for i in range(points * 2):
		var angle: float = float(i) * PI / float(points) - PI * 0.5
		var r: float = radius if i % 2 == 0 else inner_r
		pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(pts, color)

func _draw_ability_cooldown() -> void:
	## Draw a small radial sweep near the unit showing ability cooldown progress.
	var cd_center: Vector2 = Vector2(_cell_radius + 6.0, -_cell_radius + 2.0)
	var cd_radius: float = 4.0
	var cd_progress: float = 1.0 - (_ability_cooldown_timer / _ability_cooldown_max)
	# Background circle
	draw_circle(cd_center, cd_radius, Color(0.15, 0.15, 0.15, 0.6))
	# Progress arc (clockwise from top)
	if cd_progress > 0.01:
		var start_angle: float = -PI * 0.5
		var sweep: float = cd_progress * TAU
		draw_arc(cd_center, cd_radius - 1.0, start_angle, start_angle + sweep, 12, Color(0.3, 0.8, 1.0, 0.8), 2.0)
	# Ready flash
	if _ability_cooldown_timer <= 0:
		var pulse: float = 0.3 + 0.2 * sin(_time * 4.0)
		draw_circle(cd_center, cd_radius + 1.0, Color(0.3, 0.8, 1.0, pulse))

func _draw_fortify_ring() -> void:
	## Draw extra armor ring when fortified.
	var fortify_alpha: float = 0.5 + 0.2 * sin(_time * 3.0)
	draw_arc(Vector2.ZERO, _cell_radius + 4.0, 0, TAU, 24, Color(0.9, 0.75, 0.3, fortify_alpha), 3.0)
	draw_arc(Vector2.ZERO, _cell_radius + 6.0, 0, TAU, 24, Color(0.9, 0.75, 0.3, fortify_alpha * 0.4), 1.5)

func _draw_stun_indicator() -> void:
	## Draw spinning stars above the unit's head when stunned.
	var stun_y: float = -_cell_radius - 10.0
	var spin_speed: float = _time * 5.0
	for i in range(3):
		var angle: float = spin_speed + float(i) * TAU / 3.0
		var orbit_r: float = 6.0
		var pos: Vector2 = Vector2(cos(angle) * orbit_r, stun_y + sin(angle) * orbit_r * 0.4)
		_draw_star(pos, 2.0, 4, Color(1.0, 1.0, 0.3, 0.8))

func _draw_upgrade_indicators() -> void:
	## Draw subtle visual indicators for tech tree upgrades on this unit.
	if not _tech_tree:
		return
	var fc: Color = FactionData.get_faction_color(faction_id)
	# Armor upgrade: thin hexagonal outline
	if _tech_tree.has_method("get_armor_bonus") and _tech_tree.get_armor_bonus(faction_id) > 0:
		var hex_r: float = _cell_radius + 4.0
		var hex_color: Color = Color(fc.r, fc.g, fc.b, 0.3)
		for i in range(6):
			var a1: float = TAU * float(i) / 6.0 - PI * 0.5
			var a2: float = TAU * float(i + 1) / 6.0 - PI * 0.5
			var p1: Vector2 = Vector2(cos(a1) * hex_r, sin(a1) * hex_r)
			var p2: Vector2 = Vector2(cos(a2) * hex_r, sin(a2) * hex_r)
			draw_line(p1, p2, hex_color, 1.0)
	# Damage upgrade: small upward chevron above unit
	if _tech_tree.has_method("get_damage_bonus") and _tech_tree.get_damage_bonus(faction_id) > 0:
		var chev_y: float = -_cell_radius - 14.0
		var chev_color: Color = Color(1.0, 0.3, 0.2, 0.4)
		var chev_size: float = 3.0
		draw_line(Vector2(-chev_size, chev_y + chev_size), Vector2(0, chev_y), chev_color, 1.5)
		draw_line(Vector2(chev_size, chev_y + chev_size), Vector2(0, chev_y), chev_color, 1.5)
	# Speed upgrade: ghost trail circles when moving
	if _tech_tree.has_method("get_speed_mult") and _tech_tree.get_speed_mult(faction_id) > 1.0:
		if state == State.MOVE or state == State.PATROL or state == State.ATTACK:
			var alphas: Array = [0.15, 0.10, 0.05]
			var trail_color: Color = Color(fc.r, fc.g, fc.b)
			for i in range(_trail_positions.size()):
				var trail_pos: Vector2 = _trail_positions[i] - global_position
				if trail_pos.length() < 1.0:
					continue
				var alpha: float = alphas[i] if i < alphas.size() else 0.05
				draw_circle(trail_pos, _cell_radius * 0.6, Color(trail_color.r, trail_color.g, trail_color.b, alpha))

func _draw_patrol_route() -> void:
	## Draw dashed line between patrol points with diamond markers and direction arrow.
	var local_a: Vector2 = _patrol_point_a - global_position
	var local_b: Vector2 = _patrol_point_b - global_position
	var patrol_color: Color = Color(0.5, 0.8, 1.0, 0.3)
	_draw_dashed_line(local_a, local_b, patrol_color, 6.0, 4.0)
	var diamond_size: float = 4.0
	_draw_diamond(local_a, diamond_size, patrol_color)
	_draw_diamond(local_b, diamond_size, patrol_color)
	var mid: Vector2 = (local_a + local_b) * 0.5
	var dir: Vector2 = (local_b - local_a).normalized()
	var perp: Vector2 = dir.rotated(PI * 0.5)
	var arrow_size: float = 5.0
	var arrow_tip: Vector2 = mid + dir * arrow_size
	var arrow_l: Vector2 = mid - dir * arrow_size * 0.5 + perp * arrow_size * 0.4
	var arrow_r: Vector2 = mid - dir * arrow_size * 0.5 - perp * arrow_size * 0.4
	draw_colored_polygon(PackedVector2Array([arrow_tip, arrow_l, arrow_r]), Color(0.5, 0.8, 1.0, 0.25))

func _draw_dashed_line(from_pos: Vector2, to_pos: Vector2, color: Color, dash_len: float, gap_len: float) -> void:
	## Draw a dashed line between two local-space positions.
	var total_dir: Vector2 = to_pos - from_pos
	var total_len: float = total_dir.length()
	if total_len < 1.0:
		return
	var dir: Vector2 = total_dir / total_len
	var segment_len: float = dash_len + gap_len
	var dist: float = 0.0
	while dist < total_len:
		var seg_start: Vector2 = from_pos + dir * dist
		var seg_end_dist: float = minf(dist + dash_len, total_len)
		var seg_end: Vector2 = from_pos + dir * seg_end_dist
		draw_line(seg_start, seg_end, color, 1.5)
		dist += segment_len

func _draw_diamond(center: Vector2, size: float, color: Color) -> void:
	## Draw a small diamond shape at the given position.
	var pts := PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size, 0),
		center + Vector2(0, size),
		center + Vector2(-size, 0),
	])
	draw_colored_polygon(pts, color)

func _draw_stance_indicator() -> void:
	## Draw a small stance letter in the bottom-right: A (red), D (yellow), P (grey).
	var label: String = ""
	var label_color: Color = Color.WHITE
	match stance:
		Stance.AGGRESSIVE:
			label = "A"
			label_color = Color(1.0, 0.3, 0.3, 0.9)
		Stance.DEFENSIVE:
			label = "D"
			label_color = Color(1.0, 0.9, 0.2, 0.9)
		Stance.PASSIVE:
			label = "P"
			label_color = Color(0.6, 0.6, 0.6, 0.9)
	var stance_pos: Vector2 = Vector2(_cell_radius + 2.0, _cell_radius + 2.0)
	var stance_font: Font = ThemeDB.fallback_font
	if stance_font:
		draw_string(stance_font, stance_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, label_color)

# === ABILITIES ===

func can_use_ability() -> bool:
	## Returns true if cooldown is ready and unit is not stunned.
	return _ability_cooldown_timer <= 0 and not _is_stunned and _ability_cooldown_max > 0

func use_ability(target_pos: Vector2) -> void:
	## Dispatch to type-specific ability execution.
	if not can_use_ability():
		return
	match unit_type:
		UnitStats.UnitType.FIGHTER:
			_execute_charge(target_pos)
		UnitStats.UnitType.DEFENDER:
			_execute_fortify()
		UnitStats.UnitType.SCOUT:
			_execute_spores()
		UnitStats.UnitType.RANGED:
			_execute_acid_volley(target_pos)
		UnitStats.UnitType.WORKER:
			_execute_burst_gather()
	# Apply veterancy cooldown reduction
	var cd_mult: float = VET_CD_BONUS[_vet_level] if _vet_level < VET_CD_BONUS.size() else 1.0
	_ability_cooldown_timer = _ability_cooldown_max * cd_mult
	AudioManager.play_rts_attack()

func _execute_charge(target_pos: Vector2) -> void:
	## Dash 150 units toward target, deal 2.5x damage to first enemy within 40u, stun 0.5s.
	var stats: Dictionary = UnitStats.get_stats(unit_type)
	var charge_range: float = stats.get("ability_range", 150.0)
	var dir: Vector2 = (target_pos - global_position).normalized()
	var charge_dest: Vector2 = global_position + dir * charge_range
	# Teleport/dash to destination
	global_position = charge_dest
	# Find and hit nearest enemy within 40 units of destination
	var hit_radius: float = 40.0
	var dmg_mult: float = stats.get("ability_damage_mult", 2.5)
	var stun_dur: float = stats.get("ability_stun", 0.5)
	var best_enemy: Node2D = null
	var best_dist: float = hit_radius
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit) or unit == self:
			continue
		if "faction_id" in unit and unit.faction_id == faction_id:
			continue
		var dist: float = global_position.distance_to(unit.global_position)
		if dist < best_dist:
			best_dist = dist
			best_enemy = unit
	if is_instance_valid(best_enemy):
		var charge_damage: float = damage * dmg_mult
		var stage: Node = get_tree().get_first_node_in_group("rts_stage")
		if stage and stage.has_method("get_combat_system"):
			stage.get_combat_system().apply_damage(best_enemy, charge_damage, self)
		elif best_enemy.has_method("take_damage"):
			best_enemy.take_damage(charge_damage, self)
		if best_enemy.has_method("apply_stun"):
			best_enemy.apply_stun(stun_dur)
	_last_combat_time = 0.0

func _execute_fortify() -> void:
	## Set fortified for ability_duration seconds. Armor bonus applied in take_damage.
	var stats: Dictionary = UnitStats.get_stats(unit_type)
	_is_fortified = true
	_ability_active = true
	_ability_timer = stats.get("ability_duration", 5.0)
	velocity = Vector2.ZERO  # Can't move while fortified

func _execute_spores() -> void:
	## Set spore_reveal metadata for fog-of-war integration.
	var stats: Dictionary = UnitStats.get_stats(unit_type)
	set_meta("spore_reveal", true)
	set_meta("spore_reveal_radius", stats.get("ability_reveal_radius", 400.0))
	_ability_active = true
	_ability_timer = stats.get("ability_reveal_duration", 8.0)

func _execute_acid_volley(target_pos: Vector2) -> void:
	## Fire 3 projectiles in a spread pattern.
	var stats: Dictionary = UnitStats.get_stats(unit_type)
	var count: int = stats.get("ability_projectile_count", 3)
	var dmg_mult: float = stats.get("ability_damage_mult", 0.75)
	var spread: float = stats.get("ability_spread", 0.3)
	var base_dir: Vector2 = (target_pos - global_position).normalized()
	var base_angle: float = base_dir.angle()
	for i in range(count):
		# Spread projectiles evenly across the spread arc
		var offset: float = (float(i) - float(count - 1) * 0.5) * spread
		var proj_angle: float = base_angle + offset
		var proj_dir: Vector2 = Vector2(cos(proj_angle), sin(proj_angle))
		var proj_target_pos: Vector2 = global_position + proj_dir * attack_range
		# Find nearest enemy near that trajectory for targeting
		var best_target: Node2D = _find_enemy_near_line(global_position, proj_target_pos, 50.0)
		if is_instance_valid(best_target):
			var proj := preload("res://scripts/rts_stage/rts_projectile.gd").new()
			proj.setup(global_position, best_target, damage * dmg_mult, faction_id)
			get_parent().add_child(proj)
		else:
			# Fire projectile at the spread position (create a dummy target position)
			_fire_spread_projectile(proj_target_pos, damage * dmg_mult)
	_last_combat_time = 0.0

func _fire_spread_projectile(target_pos: Vector2, dmg: float) -> void:
	## Fire a projectile toward a position (no tracking target).
	var proj := preload("res://scripts/rts_stage/rts_projectile.gd").new()
	# Create a temporary marker at target position for the projectile
	var marker := Node2D.new()
	marker.global_position = target_pos
	get_parent().add_child(marker)
	proj.setup(global_position, marker, dmg, faction_id)
	get_parent().add_child(proj)
	# Clean up marker after a delay
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(marker):
			marker.queue_free()
	)

func _find_enemy_near_line(from: Vector2, to: Vector2, max_dist: float) -> Node2D:
	## Find the nearest enemy unit close to a line segment.
	var best: Node2D = null
	var best_d: float = max_dist
	var line_dir: Vector2 = (to - from).normalized()
	var line_len: float = from.distance_to(to)
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit) or unit == self:
			continue
		if "faction_id" in unit and unit.faction_id == faction_id:
			continue
		# Project unit position onto line
		var to_unit: Vector2 = unit.global_position - from
		var proj: float = to_unit.dot(line_dir)
		if proj < 0 or proj > line_len:
			continue
		var closest_on_line: Vector2 = from + line_dir * proj
		var dist: float = unit.global_position.distance_to(closest_on_line)
		if dist < best_d:
			best_d = dist
			best = unit
	return best

func _execute_burst_gather() -> void:
	## Set burst gathering for ability_duration seconds, multiplying gather amount.
	var stats: Dictionary = UnitStats.get_stats(unit_type)
	_is_burst_gathering = true
	_ability_active = true
	_ability_timer = stats.get("ability_duration", 5.0)

func apply_stun(duration: float) -> void:
	## Apply stun state for the given duration.
	_is_stunned = true
	_stun_timer = maxf(_stun_timer, duration)  # Don't shorten existing stun
	velocity = Vector2.ZERO

func toggle_auto_cast() -> void:
	## Toggle automatic ability usage on/off.
	_auto_cast = not _auto_cast

func _check_auto_cast() -> void:
	## Auto-use abilities when conditions are met.
	if not _auto_cast or _ability_cooldown_timer > 0 or _is_stunned or _ability_cooldown_max <= 0:
		return
	if state != State.ATTACK and state != State.IDLE and state != State.GATHER:
		return
	# Gather nearby enemies for condition checks
	var nearby_enemies: Array = []
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit) or unit == self:
			continue
		if "faction_id" in unit and unit.faction_id == faction_id:
			continue
		nearby_enemies.append(unit)
	match unit_type:
		UnitStats.UnitType.FIGHTER:
			# Use charge if nearest enemy > 150u away
			var nearest_enemy: Node2D = null
			var nearest_dist: float = INF
			for enemy in nearby_enemies:
				var dist: float = global_position.distance_to(enemy.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_enemy = enemy
			if is_instance_valid(nearest_enemy) and nearest_dist > 150.0 and nearest_dist < detection_range:
				use_ability(nearest_enemy.global_position)
		UnitStats.UnitType.DEFENDER:
			# Use fortify if 3+ enemies within 100u
			var count: int = 0
			for enemy in nearby_enemies:
				if global_position.distance_to(enemy.global_position) < 100.0:
					count += 1
			if count >= 3:
				use_ability(global_position)
		UnitStats.UnitType.SCOUT:
			# Use spores if 2+ enemies within 80u
			var count: int = 0
			for enemy in nearby_enemies:
				if global_position.distance_to(enemy.global_position) < 80.0:
					count += 1
			if count >= 2:
				use_ability(global_position)
		UnitStats.UnitType.RANGED:
			# Use acid volley if 3+ enemies clustered within 60u of each other
			for enemy in nearby_enemies:
				if global_position.distance_to(enemy.global_position) > attack_range * 1.5:
					continue
				# Count enemies within 60u of this enemy
				var cluster_count: int = 1
				for other in nearby_enemies:
					if other == enemy:
						continue
					if enemy.global_position.distance_to(other.global_position) < 60.0:
						cluster_count += 1
				if cluster_count >= 3:
					use_ability(enemy.global_position)
					return
		UnitStats.UnitType.WORKER:
			# Use burst gather if currently gathering
			if state == State.GATHER and is_instance_valid(_gather_target):
				use_ability(global_position)

func _try_auto_return_gather() -> void:
	## After building completes, auto-return to last gather target if valid.
	if is_instance_valid(_last_gather_target) and _last_gather_target.has_method("is_depleted") and not _last_gather_target.is_depleted():
		command_gather(_last_gather_target)
	else:
		state = State.IDLE

# === SERIALIZATION ===

func serialize() -> Dictionary:
	return {
		"unit_type": unit_type,
		"faction_id": faction_id,
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"health": health,
		"max_health": max_health,
		"state": state,
		"stance": stance,
		"xp": _xp,
		"vet_level": _vet_level,
		"carried_biomass": carried_biomass,
		"carried_genes": carried_genes,
		"ability_cooldown": _ability_cooldown_timer,
		"ability_cooldown_max": _ability_cooldown_max,
		"is_fortified": _is_fortified,
		"is_burst_gathering": _is_burst_gathering,
		"auto_cast": _auto_cast,
		"control_group": control_group,
		"base_max_health": _base_max_health,
		"base_damage": _base_damage,
		"base_speed": _base_speed,
		"base_attack_cooldown": _base_attack_cooldown,
		"anchor_x": _anchor_position.x,
		"anchor_y": _anchor_position.y,
		"patrol_a_x": _patrol_point_a.x,
		"patrol_a_y": _patrol_point_a.y,
		"patrol_b_x": _patrol_point_b.x,
		"patrol_b_y": _patrol_point_b.y,
		"patrol_going_to_b": _patrol_going_to_b,
	}

func deserialize(data: Dictionary) -> void:
	health = data.get("health", max_health)
	max_health = data.get("max_health", max_health)
	state = data.get("state", State.IDLE) as State
	stance = data.get("stance", Stance.DEFENSIVE) as Stance
	_xp = data.get("xp", 0)
	_vet_level = data.get("vet_level", 0)
	carried_biomass = data.get("carried_biomass", 0)
	carried_genes = data.get("carried_genes", 0)
	_ability_cooldown_timer = data.get("ability_cooldown", 0.0)
	_ability_cooldown_max = data.get("ability_cooldown_max", _ability_cooldown_max)
	_is_fortified = data.get("is_fortified", false)
	_is_burst_gathering = data.get("is_burst_gathering", false)
	_auto_cast = data.get("auto_cast", false)
	control_group = data.get("control_group", -1)
	_base_max_health = data.get("base_max_health", _base_max_health)
	_base_damage = data.get("base_damage", _base_damage)
	_base_speed = data.get("base_speed", _base_speed)
	_base_attack_cooldown = data.get("base_attack_cooldown", _base_attack_cooldown)
	_anchor_position = Vector2(data.get("anchor_x", global_position.x), data.get("anchor_y", global_position.y))
	_patrol_point_a = Vector2(data.get("patrol_a_x", 0.0), data.get("patrol_a_y", 0.0))
	_patrol_point_b = Vector2(data.get("patrol_b_x", 0.0), data.get("patrol_b_y", 0.0))
	_patrol_going_to_b = data.get("patrol_going_to_b", true)
	# If state references targets that no longer exist, fall back to idle
	if state == State.ATTACK or state == State.GATHER or state == State.BUILD or state == State.REPAIR:
		state = State.IDLE

# === VETERANCY ===

func grant_xp(amount: int) -> void:
	## Add XP and check for level-up.
	_xp += amount
	# Check all thresholds
	var new_level: int = 0
	for i in range(VET_THRESHOLDS.size()):
		if _xp >= VET_THRESHOLDS[i]:
			new_level = i
	if new_level > _vet_level:
		_vet_level = new_level
		_apply_veterancy()

func _apply_veterancy() -> void:
	## Recalculate stats based on vet level.
	if _vet_level <= 0 or _vet_level >= VET_HP_BONUS.size():
		return
	var hp_bonus: float = VET_HP_BONUS[_vet_level]
	var dmg_bonus: float = VET_DMG_BONUS[_vet_level]
	var spd_bonus: float = VET_SPD_BONUS[_vet_level]
	var old_max: float = max_health
	max_health = _base_max_health * (1.0 + hp_bonus)
	# Heal the difference so units don't lose HP% on level-up
	health += max_health - old_max
	health = minf(health, max_health)
	damage = _base_damage * (1.0 + dmg_bonus)
	speed = _base_speed * (1.0 + spd_bonus)
	# Tech tree speed multiplier
	if _tech_tree and _tech_tree.has_method("get_speed_mult"):
		speed *= _tech_tree.get_speed_mult(faction_id)
	attack_cooldown = _base_attack_cooldown  # CD bonus applied at ability use, not base attacks
	if _nav_agent:
		_nav_agent.max_speed = speed

extends CharacterBody2D
## Base RTS unit with FSM, procedural _draw(), pathfinding, combat, and gathering.

signal died(unit: Node2D)
signal reached_target(unit: Node2D)

enum State { IDLE, MOVE, ATTACK, GATHER, BUILD, PATROL, RETURN_RESOURCES, FLEE, HOLD }

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

# State
var state: State = State.IDLE
var _target_position: Vector2 = Vector2.ZERO
var _attack_target: Node2D = null
var _gather_target: Node2D = null
var _build_target: Node2D = null
var _patrol_point_a: Vector2 = Vector2.ZERO
var _patrol_point_b: Vector2 = Vector2.ZERO
var _patrol_going_to_b: bool = true
var _attack_timer: float = 0.0
var _gather_timer: float = 0.0

# Selection
var is_selected: bool = false
var control_group: int = -1

# Visual
var _time: float = 0.0
var _cell_radius: float = 12.0
var _membrane_points: PackedVector2Array
var _blink_timer: float = 0.0
var _hurt_flash: float = 0.0
var _charge_moved: bool = false  # For fighter charge bonus

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
	if _nav_agent:
		_nav_agent.max_speed = speed
	# Update groups
	add_to_group("faction_%d" % faction_id)
	# Set cell radius based on unit type
	match unit_type:
		UnitStats.UnitType.DEFENDER: _cell_radius = 16.0
		UnitStats.UnitType.SCOUT: _cell_radius = 9.0
		UnitStats.UnitType.RANGED: _cell_radius = 11.0
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
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	_blink_timer -= delta
	if _blink_timer < 0:
		_blink_timer = randf_range(3.0, 6.0)

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
		State.HOLD:
			_process_hold(delta)

	queue_redraw()

# === STATE PROCESSORS ===

func _process_idle(_delta: float) -> void:
	# Auto-retaliate: find nearby enemies
	_check_auto_retaliate()

func _process_move(delta: float) -> void:
	if _nav_agent.is_navigation_finished():
		state = State.IDLE
		reached_target.emit(self)
		return
	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	_nav_agent.velocity = dir * speed
	_charge_moved = true

func _process_attack(delta: float) -> void:
	if not is_instance_valid(_attack_target):
		_attack_target = null
		state = State.IDLE
		return
	var dist: float = global_position.distance_to(_attack_target.global_position)
	if dist > attack_range:
		# Move toward target
		_nav_agent.target_position = _attack_target.global_position
		var next_pos: Vector2 = _nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		_nav_agent.velocity = dir * speed
		_charge_moved = true
	else:
		# In range — attack
		velocity = Vector2.ZERO
		if _attack_timer <= 0:
			_perform_attack()
			_attack_timer = attack_cooldown

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
			var harvested: Dictionary = _gather_target.harvest(2)
			carried_biomass += harvested.get("biomass", 0)
			carried_genes += harvested.get("genes", 0)
			if carried_biomass + carried_genes >= carry_capacity:
				state = State.RETURN_RESOURCES
				_navigate_to_nearest_depot()

func _process_build(delta: float) -> void:
	if not is_instance_valid(_build_target):
		_build_target = null
		state = State.IDLE
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
				state = State.IDLE

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

func command_attack(target: Node2D) -> void:
	state = State.ATTACK
	_attack_target = target
	_charge_moved = false

func command_gather(target: Node2D) -> void:
	if carry_capacity <= 0:
		return
	state = State.GATHER
	_gather_target = target
	_gather_timer = 0.0
	_last_resource_group = _get_resource_group(target)
	if target.has_method("add_worker"):
		target.add_worker()

func command_build(target: Node2D) -> void:
	if build_speed <= 0:
		return
	state = State.BUILD
	_build_target = target

func command_patrol(point_a: Vector2, point_b: Vector2) -> void:
	state = State.PATROL
	_patrol_point_a = point_a
	_patrol_point_b = point_b
	_patrol_going_to_b = true

func command_hold() -> void:
	state = State.HOLD
	velocity = Vector2.ZERO

func command_stop() -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	_attack_target = null
	_gather_target = null
	_build_target = null

# === COMBAT ===

func _perform_attack() -> void:
	if not is_instance_valid(_attack_target):
		return
	var actual_damage: float = damage
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
	health -= amount
	_hurt_flash = 1.0
	if health <= 0:
		_die()
	elif state == State.IDLE and is_instance_valid(_attacker):
		# Auto-retaliate
		command_attack(_attacker)

func _die() -> void:
	if is_instance_valid(_gather_target) and _gather_target.has_method("remove_worker"):
		_gather_target.remove_worker()
	died.emit(self)
	queue_free()

func _check_auto_retaliate() -> void:
	if state == State.ATTACK and is_instance_valid(_attack_target):
		return
	var nearest: Node2D = null
	var nearest_dist: float = detection_range
	# Check for defender taunt — prefer attacking defenders within 80 units
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
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit
	if taunting_defender:
		command_attack(taunting_defender)
	elif nearest:
		command_attack(nearest)

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

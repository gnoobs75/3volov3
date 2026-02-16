extends CharacterBody2D
## Neutral hostile creature — patrols a small area and attacks any faction that comes near.
## Drops biomass on death. Used for NPC danger pockets across the map.

signal died(unit: Node2D)

enum CreatureType { SWARMLING, BRUTE, SPITTER }

var faction_id: int = -1  # Hostile to all factions
var creature_type: int = CreatureType.SWARMLING

# Stats
var health: float = 80.0
var max_health: float = 80.0
var armor: float = 0.0
var speed: float = 60.0
var damage: float = 8.0
var attack_range: float = 30.0
var attack_cooldown: float = 1.0
var detection_range: float = 150.0

# Drop on death
var drop_biomass: int = 15
var drop_genes: int = 3

# AI state
enum AIState { PATROL, CHASE, ATTACK, RETURN }
var _ai_state: AIState = AIState.PATROL
var _home_pos: Vector2 = Vector2.ZERO
var _patrol_radius: float = 120.0
var _patrol_target: Vector2 = Vector2.ZERO
var _attack_target: Node2D = null
var _attack_timer: float = 0.0
var _leash_range: float = 400.0  # Max distance from home before returning

# Visual
var _time: float = 0.0
var _cell_radius: float = 10.0
var _hurt_flash: float = 0.0
var _body_color: Color = Color(0.7, 0.2, 0.15)
var _glow_color: Color = Color(0.9, 0.3, 0.1)

# Navigation
var _nav_agent: NavigationAgent2D = null

func _ready() -> void:
	add_to_group("rts_units")
	add_to_group("npc_creatures")
	# Collision
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _cell_radius
	shape.shape = circle
	add_child(shape)
	# Navigation
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 8.0
	_nav_agent.target_desired_distance = 8.0
	_nav_agent.avoidance_enabled = true
	_nav_agent.radius = _cell_radius
	_nav_agent.max_speed = speed
	add_child(_nav_agent)
	_nav_agent.velocity_computed.connect(_on_velocity_computed)

func setup(p_type: int, p_home: Vector2) -> void:
	creature_type = p_type
	_home_pos = p_home
	_patrol_target = _home_pos + Vector2(randf_range(-_patrol_radius, _patrol_radius), randf_range(-_patrol_radius, _patrol_radius))
	match creature_type:
		CreatureType.SWARMLING:
			health = 60.0; max_health = 60.0; speed = 80.0; damage = 6.0
			attack_range = 25.0; detection_range = 120.0; _cell_radius = 8.0
			_body_color = Color(0.6, 0.15, 0.1); _glow_color = Color(0.8, 0.25, 0.05)
			drop_biomass = 10; drop_genes = 1
		CreatureType.BRUTE:
			health = 200.0; max_health = 200.0; armor = 3.0; speed = 45.0; damage = 18.0
			attack_range = 35.0; detection_range = 130.0; _cell_radius = 18.0
			_body_color = Color(0.5, 0.1, 0.08); _glow_color = Color(0.7, 0.2, 0.05)
			drop_biomass = 40; drop_genes = 8
			_leash_range = 300.0
		CreatureType.SPITTER:
			health = 70.0; max_health = 70.0; speed = 50.0; damage = 12.0
			attack_range = 180.0; attack_cooldown = 1.8; detection_range = 200.0; _cell_radius = 10.0
			_body_color = Color(0.5, 0.3, 0.1); _glow_color = Color(0.7, 0.5, 0.1)
			drop_biomass = 15; drop_genes = 4
	if _nav_agent:
		_nav_agent.max_speed = speed

func _physics_process(delta: float) -> void:
	_time += delta
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	match _ai_state:
		AIState.PATROL:
			_process_patrol(delta)
		AIState.CHASE:
			_process_chase(delta)
		AIState.ATTACK:
			_process_attack(delta)
		AIState.RETURN:
			_process_return(delta)
	queue_redraw()

func _process_patrol(_delta: float) -> void:
	# Move toward patrol target
	if _nav_agent.is_navigation_finished() or global_position.distance_to(_patrol_target) < 15.0:
		_patrol_target = _home_pos + Vector2(randf_range(-_patrol_radius, _patrol_radius), randf_range(-_patrol_radius, _patrol_radius))
		_nav_agent.target_position = _patrol_target
	else:
		var next_pos: Vector2 = _nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		_nav_agent.velocity = dir * speed * 0.5  # Patrol at half speed
	# Check for enemies
	var nearest: Node2D = _find_nearest_enemy()
	if nearest:
		_attack_target = nearest
		_ai_state = AIState.CHASE

func _process_chase(_delta: float) -> void:
	if not is_instance_valid(_attack_target) or _attack_target_is_dead():
		_attack_target = null
		_ai_state = AIState.RETURN
		return
	# Leash check
	if global_position.distance_to(_home_pos) > _leash_range:
		_attack_target = null
		_ai_state = AIState.RETURN
		return
	var dist: float = global_position.distance_to(_attack_target.global_position)
	if dist <= attack_range:
		_ai_state = AIState.ATTACK
	else:
		_nav_agent.target_position = _attack_target.global_position
		var next_pos: Vector2 = _nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		_nav_agent.velocity = dir * speed

func _process_attack(_delta: float) -> void:
	if not is_instance_valid(_attack_target) or _attack_target_is_dead():
		_attack_target = null
		_ai_state = AIState.RETURN
		return
	# Leash check
	if global_position.distance_to(_home_pos) > _leash_range:
		_attack_target = null
		_ai_state = AIState.RETURN
		return
	var dist: float = global_position.distance_to(_attack_target.global_position)
	if dist > attack_range * 1.2:
		_ai_state = AIState.CHASE
		return
	velocity = Vector2.ZERO
	if _attack_timer <= 0:
		_perform_attack()
		_attack_timer = attack_cooldown

func _process_return(_delta: float) -> void:
	if global_position.distance_to(_home_pos) < 30.0:
		_ai_state = AIState.PATROL
		return
	_nav_agent.target_position = _home_pos
	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	_nav_agent.velocity = dir * speed
	# Heal while returning
	health = minf(health + 5.0 * get_physics_process_delta_time(), max_health)

func _attack_target_is_dead() -> bool:
	if not is_instance_valid(_attack_target):
		return true
	return "health" in _attack_target and _attack_target.health <= 0

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = detection_range
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if unit == self or not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id == faction_id:
			continue  # Don't attack other neutrals
		if "health" in unit and unit.health <= 0:
			continue
		var dist: float = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit
	return nearest

func _perform_attack() -> void:
	if not is_instance_valid(_attack_target):
		return
	if creature_type == CreatureType.SPITTER:
		# Spitter min_range: don't shoot if too close, chase instead
		var dist: float = global_position.distance_to(_attack_target.global_position)
		if dist < 50.0:
			_ai_state = AIState.CHASE
			return
		_fire_projectile(_attack_target)
	else:
		var stage: Node = get_tree().get_first_node_in_group("rts_stage")
		if stage and stage.has_method("get_combat_system"):
			var cs: Node = stage.get_combat_system()
			if _attack_target.has_method("take_damage"):
				cs.apply_damage(_attack_target, damage, self)

func _fire_projectile(target: Node2D) -> void:
	var proj := preload("res://scripts/rts_stage/rts_projectile.gd").new()
	proj.setup(global_position, target, damage, faction_id)
	get_parent().add_child(proj)

func take_damage(amount: float, _attacker: Node2D = null) -> void:
	health -= amount
	_hurt_flash = 1.0
	if health <= 0:
		_die()
	elif _ai_state == AIState.PATROL and is_instance_valid(_attacker):
		_attack_target = _attacker
		_ai_state = AIState.CHASE

func _die() -> void:
	# Drop resources for the killer's faction
	var stage: Node = get_tree().get_first_node_in_group("rts_stage")
	if stage and stage.has_method("get_resource_manager"):
		var rm: Node = stage.get_resource_manager()
		# Give resources to whichever faction kills it — approximated by nearest faction unit
		var nearest_faction: int = 0
		var nearest_dist: float = INF
		for unit in get_tree().get_nodes_in_group("rts_units"):
			if unit == self or not is_instance_valid(unit):
				continue
			if "faction_id" in unit and unit.faction_id >= 0:
				var dist: float = global_position.distance_to(unit.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_faction = unit.faction_id
		rm.add_biomass(nearest_faction, drop_biomass)
		rm.add_genes(nearest_faction, drop_genes)
	died.emit(self)
	queue_free()

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

# === DRAWING ===

func _is_on_screen() -> bool:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return true
	var cam_pos: Vector2 = camera.global_position
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: float = camera.zoom.x if camera.zoom.x > 0 else 1.0
	var half_view: Vector2 = vp_size / (2.0 * zoom) + Vector2(50, 50)
	var diff: Vector2 = (global_position - cam_pos).abs()
	return diff.x < half_view.x and diff.y < half_view.y

func _draw() -> void:
	if not _is_on_screen():
		return

	# Hurt flash
	if _hurt_flash > 0:
		draw_circle(Vector2.ZERO, _cell_radius * 1.5, Color(1.0, 0.2, 0.2, _hurt_flash * 0.3))

	# Aggro glow when chasing/attacking
	if _ai_state == AIState.CHASE or _ai_state == AIState.ATTACK:
		var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
		draw_circle(Vector2.ZERO, _cell_radius * 2.0, Color(_glow_color.r, _glow_color.g, _glow_color.b, 0.08 + 0.06 * pulse))

	# Body
	match creature_type:
		CreatureType.SWARMLING:
			_draw_swarmling()
		CreatureType.BRUTE:
			_draw_brute()
		CreatureType.SPITTER:
			_draw_spitter()

	# Health bar
	if health < max_health:
		var bar_w: float = _cell_radius * 2.0
		var bar_h: float = 2.0
		var bar_y: float = -_cell_radius - 5.0
		var fill: float = clampf(health / max_health, 0.0, 1.0)
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.7))
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * fill, bar_h), Color(0.9, 0.2, 0.2))

func _draw_swarmling() -> void:
	# Small aggressive cell with spikes
	var pts := PackedVector2Array()
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		var r: float = _cell_radius + sin(_time * 3.0 + angle * 2.0) * 1.5
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(pts, _body_color)
	# Spines
	for i in range(4):
		var angle: float = TAU * float(i) / 4.0 + _time * 0.5
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * _cell_radius
		var end: Vector2 = Vector2(cos(angle), sin(angle)) * (_cell_radius + 5.0)
		draw_line(start, end, Color(_glow_color.r, _glow_color.g, _glow_color.b, 0.8), 1.5)
	# Eye
	draw_circle(Vector2(-2, 0), 2.5, Color(0.9, 0.8, 0.2))
	draw_circle(Vector2(-2, 0), 1.2, Color.BLACK)

func _draw_brute() -> void:
	# Large armored cell
	var pts := PackedVector2Array()
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0
		var r: float = _cell_radius + sin(angle * 3.0) * 3.0 + sin(_time * 1.0 + angle) * 1.0
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(pts, _body_color)
	# Armor plates
	draw_arc(Vector2.ZERO, _cell_radius * 0.8, 0, TAU, 16, Color(0.35, 0.15, 0.1, 0.6), 3.0)
	draw_arc(Vector2.ZERO, _cell_radius + 2.0, 0, TAU, 20, Color(0.4, 0.15, 0.08, 0.4), 2.0)
	# Mean eyes
	for ey in [-4.0, 4.0]:
		draw_circle(Vector2(-5, ey), 3.0, Color(0.9, 0.2, 0.1))
		draw_circle(Vector2(-5, ey), 1.5, Color.BLACK)

func _draw_spitter() -> void:
	# Ranged creature with antenna
	var pts := PackedVector2Array()
	for i in range(10):
		var angle: float = TAU * float(i) / 10.0
		var r: float = _cell_radius + sin(_time * 2.0 + angle * 3.0) * 1.0
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(pts, _body_color)
	# Acid sac
	draw_circle(Vector2(3, 0), 4.0, Color(0.5, 0.6, 0.1, 0.5))
	# Spitter tube
	var tip: Vector2 = Vector2(-_cell_radius - 6.0, 0)
	var base: Vector2 = Vector2(-_cell_radius * 0.5, 0)
	draw_line(base, tip, Color(_glow_color.r, _glow_color.g, _glow_color.b, 0.7), 2.0)
	var pulse: float = 0.4 + 0.3 * sin(_time * 3.0)
	draw_circle(tip, 2.0, Color(_glow_color.r, _glow_color.g, _glow_color.b, pulse))
	# Eye
	draw_circle(Vector2(-2, -2), 2.0, Color(0.8, 0.7, 0.2))
	draw_circle(Vector2(-2, -2), 1.0, Color.BLACK)

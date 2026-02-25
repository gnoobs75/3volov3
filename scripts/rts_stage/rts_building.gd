extends StaticBody2D
## Base RTS building with construction, production, and procedural _draw().

signal construction_complete(building: Node2D)
signal destroyed(building: Node2D)
signal unit_produced(building: Node2D, unit_type: int)
signal research_complete(building: Node2D, upgrade_id: int, is_building_upgrade: bool)

var faction_id: int = 0
var building_type: int = BuildingStats.BuildingType.BIO_WALL
var creature_template: CreatureTemplate = null
var is_selected: bool = false

# Stats
var health: float = 400.0
var max_health: float = 400.0
var armor: float = 5.0
var size_radius: float = 30.0
var is_depot: bool = false
var is_production: bool = false
var is_main_base: bool = false
var can_produce: Array = []
var supply_provided: int = 0

# Construction
var construction_progress: float = 0.0
var build_time: float = 10.0
var _is_constructed: bool = false
var _active_builders: int = 0

# Production queue
var _production_queue: Array = []  # Array of unit_type ints
var _production_timer: float = 0.0
var _current_production_time: float = 0.0

# Tower attack
var attack_range: float = 0.0
var attack_damage: float = 0.0
var attack_cooldown: float = 1.5
var _tower_attack_timer: float = 0.0
var _tower_target: Node2D = null

# Rotation (cosmetic only)
var build_rotation: float = 0.0

# Rally point
var rally_point: Vector2 = Vector2.ZERO
var has_rally_point: bool = false

# Research
var _research_queue: Array = []  # Array of {id: int, is_building: bool}
var _research_timer: float = 0.0
var _current_research_time: float = 0.0
var _is_researching: bool = false
var _current_research_type: String = ""  # "unit" or "building"
var _building_upgrade_id: int = -1  # BuildingUpgradeId applied to this building, -1 = none
var _tech_tree: Node = null

# Repair
var _being_repaired: bool = false
var _repair_fade: float = 0.0
var _last_damage_time: float = 999.0

# Singularity Core
var _singularity_charge: float = 0.0  # 0 to 60
var _singularity_cooldown: float = 0.0  # 180s after firing
var _singularity_charging: bool = false

# Visual
var _time: float = 0.0
var _collision_shape: CollisionShape2D = null
var _tower_eye_dir: Vector2 = Vector2.ZERO  # Smoothed tower eye direction
var _hurt_flash: float = 0.0

func _ready() -> void:
	add_to_group("rts_buildings")
	# Collision shape
	_collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = size_radius
	_collision_shape.shape = circle
	add_child(_collision_shape)

func setup(p_faction_id: int, p_building_type: int, p_template: CreatureTemplate, pre_built: bool = false) -> void:
	faction_id = p_faction_id
	building_type = p_building_type
	creature_template = p_template
	# Apply base stats
	var stats: Dictionary = BuildingStats.get_stats(building_type)
	var fd: Dictionary = FactionData.get_faction(faction_id)
	max_health = stats.get("hp", 400) * fd.get("building_hp_mult", 1.0)
	health = max_health if pre_built else max_health * 0.1
	armor = stats.get("armor", 0)
	size_radius = stats.get("size_radius", 30.0)
	build_time = stats.get("build_time", 10.0) / fd.get("build_speed_mult", 1.0)
	is_depot = stats.get("is_depot", false)
	is_production = stats.get("is_production", false)
	is_main_base = stats.get("is_main_base", false)
	can_produce = stats.get("can_produce", [])
	supply_provided = stats.get("supply_provided", 0)
	attack_range = stats.get("attack_range", 0.0)
	attack_damage = stats.get("attack_damage", 0.0)
	attack_cooldown = stats.get("attack_cooldown", 1.5)
	# Update collision (shape may not exist yet if _ready() hasn't fired)
	if _collision_shape and _collision_shape.shape is CircleShape2D:
		(_collision_shape.shape as CircleShape2D).radius = size_radius
	if pre_built:
		construction_progress = build_time
		_is_constructed = true
	add_to_group("faction_%d" % faction_id)

func is_complete() -> bool:
	return _is_constructed

func get_build_speed_multiplier() -> float:
	## Multiple workers speed up construction: each extra worker adds 50% speed.
	if _active_builders <= 1:
		return 1.0
	return 1.0 + (_active_builders - 1) * 0.5

func add_construction(amount: float) -> void:
	if _is_constructed:
		return
	construction_progress += amount * get_build_speed_multiplier()
	# Scale health with construction progress
	var progress_pct: float = clampf(construction_progress / build_time, 0.0, 1.0)
	health = max_health * (0.1 + 0.9 * progress_pct)
	if construction_progress >= build_time:
		_is_constructed = true
		health = max_health
		construction_complete.emit(self)
		AudioManager.play_rts_build_complete()

func take_damage(amount: float, _attacker: Node2D = null) -> void:
	health -= amount
	_hurt_flash = 1.0
	_last_damage_time = 0.0
	if health <= 0:
		_die()

func take_repair(amount: float) -> void:
	if health >= max_health:
		return
	health = minf(health + amount, max_health)
	_being_repaired = true
	_repair_fade = 0.5

# Salvage visual
var _salvage_flash: float = 0.0
var _salvage_pending: bool = false

func salvage() -> void:
	## Salvage a fully constructed building, returning 50% of original cost.
	if not _is_constructed:
		return
	var stats: Dictionary = BuildingStats.get_stats(building_type)
	var biomass_refund: int = int(stats.get("cost_biomass", 0) * 0.5)
	var genes_refund: int = int(stats.get("cost_genes", 0) * 0.5)
	var stage: Node = get_tree().get_first_node_in_group("rts_stage")
	if stage and stage.has_method("get_resource_manager"):
		var rm: Node = stage.get_resource_manager()
		if rm:
			rm.add_biomass(faction_id, biomass_refund)
			rm.add_genes(faction_id, genes_refund)
	# Flash white for 0.3s before removal
	_salvage_flash = 0.3
	_salvage_pending = true

func cancel_construction() -> void:
	## Cancel a building under construction with partial refund.
	## Early cancel ~ 75% back, late cancel ~ 0% back.
	if _is_constructed:
		return
	var progress_pct: float = clampf(construction_progress / build_time, 0.0, 1.0)
	var refund_pct: float = 0.75 * (1.0 - progress_pct)
	var stats: Dictionary = BuildingStats.get_stats(building_type)
	var biomass_refund: int = int(stats.get("cost_biomass", 0) * refund_pct)
	var genes_refund: int = int(stats.get("cost_genes", 0) * refund_pct)
	var stage: Node = get_tree().get_first_node_in_group("rts_stage")
	if stage and stage.has_method("get_resource_manager"):
		var rm: Node = stage.get_resource_manager()
		if rm:
			rm.add_biomass(faction_id, biomass_refund)
			rm.add_genes(faction_id, genes_refund)
	_die()

func _die() -> void:
	destroyed.emit(self)
	queue_free()

# === RALLY POINT ===

func set_rally_point(pos: Vector2) -> void:
	rally_point = pos
	has_rally_point = true
	queue_redraw()

# === SINGULARITY CORE ===

func start_singularity_charge() -> void:
	if building_type != BuildingStats.BuildingType.SINGULARITY_CORE:
		return
	if not _is_constructed or _singularity_cooldown > 0.0 or _singularity_charging:
		return
	_singularity_charging = true
	_singularity_charge = 0.0

func fire_singularity_pulse() -> void:
	if building_type != BuildingStats.BuildingType.SINGULARITY_CORE:
		return
	if _singularity_charge < 60.0 or _singularity_cooldown > 0.0:
		return
	# Deal 80 damage to ALL enemy units on the map
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id == faction_id:
			continue
		if unit.has_method("take_damage"):
			unit.take_damage(80.0, self)
		# Apply 40% slow for 8s
		unit.set_meta("singularity_slow", 0.4)
		unit.set_meta("singularity_slow_remaining", 8.0)
	# Reset state
	_singularity_cooldown = 180.0
	_singularity_charge = 0.0
	_singularity_charging = false
	if faction_id == 0:
		AudioManager.play_rts_attack()

func get_singularity_charge() -> float:
	return _singularity_charge

func get_singularity_cooldown() -> float:
	return _singularity_cooldown

func is_singularity_charging() -> bool:
	return _singularity_charging

func is_singularity_ready() -> bool:
	return _singularity_charge >= 60.0 and _singularity_cooldown <= 0.0

# === PRODUCTION ===

func queue_unit(unit_type: int) -> bool:
	if not _is_constructed or not is_production:
		return false
	if unit_type not in can_produce:
		return false
	var cost: Dictionary = UnitStats.get_cost(unit_type)
	var stage: Node = get_tree().get_first_node_in_group("rts_stage")
	if not stage or not stage.has_method("get_resource_manager"):
		return false
	var rm: Node = stage.get_resource_manager()
	if not rm.spend(faction_id, cost.get("biomass", 0), cost.get("genes", 0)):
		return false
	_production_queue.append(unit_type)
	if _production_queue.size() == 1:
		_start_production()
	return true

func _start_production() -> void:
	if _production_queue.is_empty():
		return
	var unit_type: int = _production_queue[0]
	var stats: Dictionary = UnitStats.get_stats(unit_type)
	var fd: Dictionary = FactionData.get_faction(faction_id)
	_current_production_time = stats.get("build_time", 5.0) / fd.get("build_speed_mult", 1.0)
	_production_timer = 0.0

func get_production_progress() -> float:
	if _production_queue.is_empty() or _current_production_time <= 0:
		return 0.0
	return clampf(_production_timer / _current_production_time, 0.0, 1.0)

func get_queue_size() -> int:
	return _production_queue.size()

func cancel_queue_item(index: int) -> void:
	## Cancel a production queue item at index, refunding 75% of cost.
	if index < 0 or index >= _production_queue.size():
		return
	var utype: int = _production_queue[index]
	_production_queue.remove_at(index)
	# Refund 75% of cost
	var cost: Dictionary = UnitStats.get_cost(utype)
	var biomass_refund: int = int(cost.get("biomass", 0) * 0.75)
	var genes_refund: int = int(cost.get("genes", 0) * 0.75)
	var stage: Node = get_tree().get_first_node_in_group("rts_stage")
	if stage and stage.has_method("get_resource_manager"):
		var rm: Node = stage.get_resource_manager()
		if rm:
			rm.add_biomass(faction_id, biomass_refund)
			rm.add_genes(faction_id, genes_refund)
	# If we canceled the currently-producing item, reset progress and start next
	if index == 0:
		_production_timer = 0.0
		_start_production()

func cancel_last_queue_item() -> void:
	## Convenience: cancel the last item in the production queue.
	if not _production_queue.is_empty():
		cancel_queue_item(_production_queue.size() - 1)

func reorder_queue(from_idx: int, to_idx: int) -> void:
	## Move a queued item from from_idx to to_idx. Cannot move index 0 (currently producing).
	if from_idx <= 0 or to_idx <= 0:
		return
	if from_idx >= _production_queue.size() or to_idx >= _production_queue.size():
		return
	if from_idx == to_idx:
		return
	var item: int = _production_queue[from_idx]
	_production_queue.remove_at(from_idx)
	_production_queue.insert(to_idx, item)

func _process(delta: float) -> void:
	_time += delta
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	# Salvage flash countdown
	if _salvage_pending:
		_salvage_flash -= delta
		if _salvage_flash <= 0.0:
			_salvage_pending = false
			_die()
			return
	# Repair fade timer
	if _repair_fade > 0:
		_repair_fade -= delta
		if _repair_fade <= 0:
			_being_repaired = false
	# Auto-repair: passive 2 HP/sec after 10s without damage
	_last_damage_time += delta
	if _is_constructed and _last_damage_time > 10.0 and health < max_health:
		health = minf(health + 2.0 * delta, max_health)
	# Research
	if _is_constructed:
		_process_research(delta)
	# Production
	if _is_constructed and not _production_queue.is_empty():
		_production_timer += delta
		if _production_timer >= _current_production_time:
			var unit_type: int = _production_queue.pop_front()
			unit_produced.emit(self, unit_type)
			_start_production()  # Start next in queue
	# Singularity Core charge/cooldown
	if _is_constructed and building_type == BuildingStats.BuildingType.SINGULARITY_CORE:
		if _singularity_cooldown > 0.0:
			_singularity_cooldown = maxf(_singularity_cooldown - delta, 0.0)
		elif _singularity_charging and _singularity_charge < 60.0:
			_singularity_charge = minf(_singularity_charge + delta, 60.0)
		# Minimap pulse while charging
		set_meta("minimap_pulse", _singularity_charging and _singularity_charge < 60.0)
	# Tower auto-attack + smooth eye
	if _is_constructed and attack_range > 0:
		_tower_attack_timer = maxf(_tower_attack_timer - delta, 0.0)
		_update_tower_attack()
		# Smooth eye tracking
		if is_instance_valid(_tower_target):
			var target_dir: Vector2 = (_tower_target.global_position - global_position).normalized() * 2.5
			_tower_eye_dir = _tower_eye_dir.lerp(target_dir, delta * 6.0)
		else:
			_tower_eye_dir = _tower_eye_dir.lerp(Vector2.ZERO, delta * 3.0)
	queue_redraw()

func _update_tower_attack() -> void:
	if _tower_attack_timer > 0:
		return
	# Find nearest enemy
	var nearest: Node2D = null
	var nearest_dist: float = attack_range
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if "faction_id" in unit and unit.faction_id == faction_id:
			continue
		var dist: float = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit
	if nearest:
		_tower_target = nearest
		_tower_attack_timer = attack_cooldown
		# Fire projectile
		var proj := preload("res://scripts/rts_stage/rts_projectile.gd").new()
		proj.setup(global_position, nearest, attack_damage, faction_id)
		get_parent().add_child(proj)
		if faction_id == 0:
			AudioManager.play_rts_attack()

func _is_on_screen() -> bool:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return true
	var cam_pos: Vector2 = camera.global_position
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: float = camera.zoom.x if camera.zoom.x > 0 else 1.0
	var margin: float = size_radius + 20.0
	var half_view: Vector2 = vp_size / (2.0 * zoom) + Vector2(margin, margin)
	var diff: Vector2 = (global_position - cam_pos).abs()
	return diff.x < half_view.x and diff.y < half_view.y

func _draw() -> void:
	# Skip if off-screen (except rally points which extend far)
	if not _is_on_screen() and not has_rally_point:
		return

	var mc: Color = creature_template.membrane_color if creature_template else FactionData.get_faction_color(faction_id)
	var gc: Color = creature_template.glow_color if creature_template else mc.lightened(0.3)

	if not _is_constructed:
		# Under construction — translucent with progress indicator
		var pct: float = clampf(construction_progress / build_time, 0.0, 1.0)
		draw_circle(Vector2.ZERO, size_radius, Color(mc.r, mc.g, mc.b, 0.2 + pct * 0.5))
		draw_arc(Vector2.ZERO, size_radius + 3.0, -PI * 0.5, -PI * 0.5 + TAU * pct, 32, Color(gc.r, gc.g, gc.b, 0.8), 2.5)
		# Construction scaffolding
		for i in range(4):
			var angle: float = TAU * float(i) / 4.0 + build_rotation
			draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle)) * size_radius * 0.8, Color(0.5, 0.5, 0.4, 0.3 * pct), 1.0)
		# Selection ring — show even during construction so user sees feedback
		if is_selected and faction_id == 0:
			var sel_r: float = size_radius + 4.0
			var sel_color: Color = Color(0.2, 1.0, 0.3, 0.6)
			var dash_count: int = 8
			var dash_arc: float = TAU / float(dash_count) * 0.6
			var gap_arc: float = TAU / float(dash_count) * 0.4
			var ring_offset: float = _time * 1.5
			for di in range(dash_count):
				var start_a: float = ring_offset + float(di) * (dash_arc + gap_arc)
				draw_arc(Vector2.ZERO, sel_r, start_a, start_a + dash_arc, 6, sel_color, 1.5)
			# Construction percentage text
			var font: Font = ThemeDB.fallback_font
			var pct_text: String = "Building... %d%%" % int(pct * 100)
			if font:
				draw_string(font, Vector2(-35, size_radius + 18), pct_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 9, Color(0.8, 0.9, 0.5, 0.8))
		# Health bar during construction
		_draw_health_bar()
		return

	# Salvage flash (white overlay)
	if _salvage_pending:
		var flash_alpha: float = clampf(_salvage_flash / 0.3, 0.0, 1.0) * 0.6
		draw_circle(Vector2.ZERO, size_radius * 1.3, Color(1.0, 1.0, 1.0, flash_alpha))

	# Hurt flash
	if _hurt_flash > 0:
		draw_circle(Vector2.ZERO, size_radius * 1.2, Color(1.0, 0.2, 0.2, _hurt_flash * 0.25))

	# Glow
	draw_circle(Vector2.ZERO, size_radius * 1.5, Color(gc.r, gc.g, gc.b, 0.04))

	# Selection ring (animated dashed arc)
	if is_selected and faction_id == 0:
		var sel_r: float = size_radius + 4.0
		var sel_color: Color = Color(0.2, 1.0, 0.3, 0.8)
		var dash_count: int = 8
		var dash_arc: float = TAU / float(dash_count) * 0.6
		var gap_arc: float = TAU / float(dash_count) * 0.4
		var ring_offset: float = _time * 1.5
		for di in range(dash_count):
			var start_a: float = ring_offset + float(di) * (dash_arc + gap_arc)
			draw_arc(Vector2.ZERO, sel_r, start_a, start_a + dash_arc, 6, sel_color, 1.5)
		draw_arc(Vector2.ZERO, sel_r - 1.0, 0, TAU, 16, Color(0.2, 1.0, 0.3, 0.15), 3.0)

	match building_type:
		BuildingStats.BuildingType.SPAWNING_POOL:
			_draw_spawning_pool(mc, gc)
		BuildingStats.BuildingType.EVOLUTION_CHAMBER:
			_draw_evolution_chamber(mc, gc)
		BuildingStats.BuildingType.MEMBRANE_TOWER:
			_draw_membrane_tower(mc, gc)
		BuildingStats.BuildingType.BIO_WALL:
			_draw_bio_wall(mc, gc)
		BuildingStats.BuildingType.NUTRIENT_PROCESSOR:
			_draw_nutrient_processor(mc, gc)
		BuildingStats.BuildingType.SUPPLY_DEPOT:
			_draw_supply_depot(mc, gc)
		BuildingStats.BuildingType.SINGULARITY_CORE:
			_draw_singularity_core(mc, gc)

	# Health bar
	_draw_health_bar()

	# Production progress
	if not _production_queue.is_empty():
		_draw_production_bar()

	# Research progress
	if _is_researching:
		_draw_research_bar()

	# Upgraded indicator
	if _building_upgrade_id >= 0:
		_draw_upgrade_indicator(gc)

	# Rally point (only when selected)
	if has_rally_point and faction_id == 0 and is_selected:
		_draw_rally_point()

	# Repair sparkle effect
	if _being_repaired or _repair_fade > 0:
		_draw_repair_sparkles()

func _draw_spawning_pool(mc: Color, gc: Color) -> void:
	# Large pulsing pool
	var pulse: float = 1.0 + 0.05 * sin(_time * 1.5)
	# Hatchery upgrade: extra outer glow ring
	if _building_upgrade_id == 0:  # HATCHERY
		var glow_pulse: float = 0.08 + 0.04 * sin(_time * 2.5)
		draw_circle(Vector2.ZERO, size_radius * 1.8, Color(gc.r, gc.g, gc.b, glow_pulse))
		draw_arc(Vector2.ZERO, size_radius * 1.4, 0, TAU, 24, Color(gc.r, gc.g, gc.b, 0.15 + 0.05 * sin(_time * 3.0)), 2.0)
	# Outer membrane
	var pts := PackedVector2Array()
	for i in range(20):
		var angle: float = TAU * float(i) / 20.0 + build_rotation
		var r: float = size_radius * pulse + sin(angle * 3.0 + _time) * 3.0
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(pts, Color(mc.r * 0.6, mc.g * 0.6, mc.b * 0.6, 0.8))
	# Inner pool
	draw_circle(Vector2.ZERO, size_radius * 0.6, Color(mc.r * 0.3, mc.g * 0.3, mc.b * 0.3, 0.9))
	# Bubbles (more bubbles when upgraded)
	var bubble_count: int = 5 if _building_upgrade_id == 0 else 3
	for i in range(bubble_count):
		var ba: float = _time * 0.5 + TAU * float(i) / float(bubble_count) + build_rotation
		var bp: Vector2 = Vector2(cos(ba) * 12.0, sin(ba) * 12.0)
		draw_circle(bp, 3.0, Color(gc.r, gc.g, gc.b, 0.3))

func _draw_evolution_chamber(mc: Color, gc: Color) -> void:
	# Hexagonal-ish structure
	var pts := PackedVector2Array()
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0 + PI / 6.0 + build_rotation
		pts.append(Vector2(cos(angle), sin(angle)) * size_radius)
	draw_colored_polygon(pts, Color(mc.r * 0.5, mc.g * 0.5, mc.b * 0.7, 0.8))
	# DNA helix center
	for i in range(8):
		var t: float = float(i) / 8.0
		var y: float = (t - 0.5) * size_radius * 1.2
		var x1: float = sin(_time * 2.0 + t * 6.0) * 6.0
		var x2: float = sin(_time * 2.0 + t * 6.0 + PI) * 6.0
		draw_circle(Vector2(x1, y), 2.0, Color(gc.r, gc.g, gc.b, 0.6))
		draw_circle(Vector2(x2, y), 2.0, Color(gc.r, gc.g, gc.b, 0.4))

func _draw_membrane_tower(mc: Color, gc: Color) -> void:
	# Spine Tower upgrade: spike decorations around circle
	if _building_upgrade_id == 1:  # SPINE_TOWER
		var spike_count: int = 8
		for si in range(spike_count):
			var sa: float = TAU * float(si) / float(spike_count) + _time * 0.3 + build_rotation
			var base_l: Vector2 = Vector2(cos(sa - 0.15), sin(sa - 0.15)) * size_radius
			var base_r: Vector2 = Vector2(cos(sa + 0.15), sin(sa + 0.15)) * size_radius
			var tip: Vector2 = Vector2(cos(sa), sin(sa)) * (size_radius + 10.0 + 2.0 * sin(_time * 4.0 + float(si)))
			var spike_pts := PackedVector2Array()
			spike_pts.append(base_l)
			spike_pts.append(tip)
			spike_pts.append(base_r)
			draw_colored_polygon(spike_pts, Color(mc.r * 0.9, mc.g * 0.4, mc.b * 0.4, 0.7))
	# Tall tower shape with concentric rings
	draw_circle(Vector2.ZERO, size_radius, Color(mc.r * 0.7, mc.g * 0.5, mc.b * 0.5, 0.8))
	draw_arc(Vector2.ZERO, size_radius * 0.7, 0, TAU, 16, Color(mc.r * 0.5, mc.g * 0.3, mc.b * 0.3, 0.4), 1.5)
	# Eye on top (uses smoothed direction)
	var eye_size: float = 7.5 if _building_upgrade_id == 1 else 6.0
	draw_circle(Vector2.ZERO, eye_size, Color.WHITE)
	draw_circle(Vector2.ZERO, eye_size + 0.5, Color(gc.r, gc.g, gc.b, 0.3 + 0.1 * sin(_time * 2.0)))
	draw_circle(_tower_eye_dir, eye_size * 0.5, Color(0.9, 0.2, 0.2))
	# Pupil highlight
	draw_circle(_tower_eye_dir + Vector2(-0.5, -0.5), 1.0, Color(1.0, 0.5, 0.5, 0.6))
	# Range indicator (dashed) — wider when upgraded
	if attack_range > 0:
		var dash_count: int = 20 if _building_upgrade_id == 1 else 16
		var dash_arc: float = TAU / float(dash_count) * 0.5
		var range_alpha: float = 0.09 if _building_upgrade_id == 1 else 0.06
		for di in range(dash_count):
			var a_start: float = float(di) * TAU / float(dash_count) + _time * 0.2
			draw_arc(Vector2.ZERO, attack_range, a_start, a_start + dash_arc, 4, Color(mc.r, mc.g, mc.b, range_alpha), 1.0)

func _draw_bio_wall(mc: Color, _gc: Color) -> void:
	# Thick wall segment (rotated by build_rotation)
	var pts := PackedVector2Array()
	var corners: Array = [
		Vector2(-size_radius, -size_radius * 0.6),
		Vector2(size_radius, -size_radius * 0.6),
		Vector2(size_radius, size_radius * 0.6),
		Vector2(-size_radius, size_radius * 0.6),
	]
	for c in corners:
		pts.append(c.rotated(build_rotation))
	draw_colored_polygon(pts, Color(mc.r * 0.4, mc.g * 0.4, mc.b * 0.3, 0.9))
	# Texture lines
	for i in range(3):
		var x: float = -size_radius + size_radius * 2.0 * float(i + 1) / 4.0
		var line_start: Vector2 = Vector2(x, -size_radius * 0.5).rotated(build_rotation)
		var line_end: Vector2 = Vector2(x, size_radius * 0.5).rotated(build_rotation)
		draw_line(line_start, line_end, Color(mc.r * 0.3, mc.g * 0.3, mc.b * 0.2, 0.4), 1.5)

func _draw_nutrient_processor(mc: Color, gc: Color) -> void:
	# Refinery upgrade: processing glow circle
	if _building_upgrade_id == 2:  # REFINERY
		var glow_pulse: float = 0.08 + 0.05 * sin(_time * 4.0)
		draw_circle(Vector2.ZERO, size_radius * 1.6, Color(gc.r, gc.g, gc.b, glow_pulse))
	# Circular processor with vanes
	draw_circle(Vector2.ZERO, size_radius, Color(mc.r * 0.5, mc.g * 0.6, mc.b * 0.4, 0.8))
	# Rotating vanes (faster when upgraded)
	var vane_speed: float = 1.5 if _building_upgrade_id == 2 else 0.5
	var vane_count: int = 6 if _building_upgrade_id == 2 else 4
	for i in range(vane_count):
		var angle: float = _time * vane_speed + TAU * float(i) / float(vane_count) + build_rotation
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * 5.0
		var end: Vector2 = Vector2(cos(angle), sin(angle)) * (size_radius * 0.8)
		draw_line(start, end, Color(gc.r, gc.g, gc.b, 0.5), 2.0)
	# Center hub (larger when upgraded)
	var hub_r: float = 7.0 if _building_upgrade_id == 2 else 5.0
	draw_circle(Vector2.ZERO, hub_r, Color(gc.r, gc.g, gc.b, 0.6))
	# Refinery: inner processing ring
	if _building_upgrade_id == 2:
		draw_arc(Vector2.ZERO, size_radius * 0.5, _time * 3.0, _time * 3.0 + PI * 1.2, 12, Color(gc.r, gc.g, gc.b, 0.25), 1.5)

func _draw_singularity_core(mc: Color, gc: Color) -> void:
	var is_cooling: bool = _singularity_cooldown > 0.0
	var charge_pct: float = clampf(_singularity_charge / 60.0, 0.0, 1.0)
	# Dim when cooling down
	var dim: float = 0.3 if is_cooling else 1.0

	# Outer energy field (concentric pulsing circles)
	var pulse: float = sin(_time * 2.0) * 4.0
	var pulse2: float = sin(_time * 3.0 + 1.5) * 3.0
	draw_circle(Vector2.ZERO, size_radius * 1.4 + pulse, Color(gc.r * 0.3, gc.g * 0.2, gc.b * 0.6, 0.06 * dim))
	draw_circle(Vector2.ZERO, size_radius * 1.1 + pulse2, Color(gc.r * 0.4, gc.g * 0.2, gc.b * 0.8, 0.08 * dim))

	# Core orb — large pulsing center
	var core_pulse: float = 1.0 + 0.08 * sin(_time * 2.5)
	var core_r: float = size_radius * 0.7 * core_pulse
	var core_intensity: float = 0.4 + charge_pct * 0.5
	var core_color: Color = Color(0.5 * dim, 0.2 * dim, 0.9 * dim, core_intensity * dim)
	draw_circle(Vector2.ZERO, core_r, core_color)
	# Inner bright core
	draw_circle(Vector2.ZERO, core_r * 0.4, Color(0.7 * dim, 0.4 * dim, 1.0 * dim, (0.5 + charge_pct * 0.4) * dim))
	# White hot center when fully charged
	if charge_pct >= 1.0 and not is_cooling:
		var hot_pulse: float = 0.6 + 0.4 * sin(_time * 6.0)
		draw_circle(Vector2.ZERO, core_r * 0.2, Color(1.0, 1.0, 1.0, hot_pulse))

	# Energy tendrils radiating outward (6 wavy lines)
	var tendril_count: int = 6
	for i in range(tendril_count):
		var base_angle: float = TAU * float(i) / float(tendril_count) + _time * 0.3
		var tendril_alpha: float = (0.2 + charge_pct * 0.4) * dim
		var tendril_color: Color = Color(0.6, 0.3, 1.0, tendril_alpha)
		var prev_pt: Vector2 = Vector2(cos(base_angle), sin(base_angle)) * core_r * 0.5
		var segments: int = 8
		for j in range(1, segments + 1):
			var t: float = float(j) / float(segments)
			var r: float = core_r * 0.5 + t * (size_radius * 0.9)
			var wave: float = sin(_time * 4.0 + float(i) * 1.5 + t * 6.0) * 6.0 * t
			var angle: float = base_angle + wave * 0.02
			var pt: Vector2 = Vector2(cos(angle), sin(angle)) * r + Vector2(0, wave * 0.3)
			draw_line(prev_pt, pt, Color(tendril_color.r, tendril_color.g, tendril_color.b, tendril_alpha * (1.0 - t * 0.5)), 1.5 - t * 0.8)
			prev_pt = pt

	# Charge progress arc (filling ring around building)
	if _singularity_charging and charge_pct > 0.0 and charge_pct < 1.0:
		var arc_r: float = size_radius + 6.0
		var arc_end: float = -PI * 0.5 + TAU * charge_pct
		draw_arc(Vector2.ZERO, arc_r, -PI * 0.5, arc_end, 32, Color(0.7, 0.3, 1.0, 0.8), 3.0)
		# Glow at arc tip
		var tip_angle: float = arc_end
		var tip_pos: Vector2 = Vector2(cos(tip_angle), sin(tip_angle)) * arc_r
		draw_circle(tip_pos, 3.0, Color(0.8, 0.5, 1.0, 0.6))
	elif charge_pct >= 1.0 and not is_cooling:
		# Fully charged — complete pulsing ring
		var ring_alpha: float = 0.5 + 0.3 * sin(_time * 5.0)
		draw_arc(Vector2.ZERO, size_radius + 6.0, 0, TAU, 32, Color(1.0, 0.8, 0.3, ring_alpha), 3.0)

	# Cooldown indicator (grey arc showing remaining cooldown)
	if is_cooling:
		var cd_pct: float = clampf(_singularity_cooldown / 180.0, 0.0, 1.0)
		draw_arc(Vector2.ZERO, size_radius + 6.0, -PI * 0.5, -PI * 0.5 + TAU * cd_pct, 32, Color(0.4, 0.4, 0.4, 0.4), 2.0)
		# Cooldown text
		var font: Font = ThemeDB.fallback_font
		if font and is_selected and faction_id == 0:
			var cd_text: String = "CD: %ds" % int(_singularity_cooldown)
			draw_string(font, Vector2(-20, size_radius + 20), cd_text, HORIZONTAL_ALIGNMENT_CENTER, 50, 9, Color(0.6, 0.6, 0.6, 0.8))

	# Outer membrane ring
	var membrane_pts := PackedVector2Array()
	for i in range(24):
		var angle: float = TAU * float(i) / 24.0
		var r: float = size_radius + sin(angle * 5.0 + _time * 1.5) * 2.5
		membrane_pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	for i in range(membrane_pts.size()):
		var next_i: int = (i + 1) % membrane_pts.size()
		draw_line(membrane_pts[i], membrane_pts[next_i], Color(mc.r * 0.5, mc.g * 0.3, mc.b * 0.7, 0.5 * dim), 1.5)

func _draw_health_bar() -> void:
	if health >= max_health:
		return
	var bar_w: float = size_radius * 2.0
	var bar_h: float = 3.0
	var bar_y: float = -size_radius - 8.0
	var fill: float = clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.7))
	var bar_color: Color = Color(0.2, 0.9, 0.3) if fill > 0.5 else Color(0.9, 0.9, 0.2) if fill > 0.25 else Color(0.9, 0.2, 0.2)
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * fill, bar_h), bar_color)

func _draw_production_bar() -> void:
	var bar_w: float = size_radius * 1.5
	var bar_h: float = 2.5
	var bar_y: float = size_radius + 5.0
	var pct: float = get_production_progress()
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.5))
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * pct, bar_h), Color(0.3, 0.6, 1.0, 0.7))

func _draw_rally_point() -> void:
	## Draws a rally point flag with dashed line from building (faction color)
	var rp_local: Vector2 = rally_point - global_position
	var fc: Color = FactionData.get_faction_color(faction_id)
	var flag_color: Color = Color(fc.r, fc.g, fc.b, 0.7)

	# Dashed line from building center to rally point (8px dash, 4px gap)
	var line_len: float = rp_local.length()
	var dir: Vector2 = rp_local.normalized() if line_len > 0 else Vector2.RIGHT
	var dash_len: float = 8.0
	var gap_len: float = 4.0
	var d: float = 0.0
	while d < line_len:
		var seg_start: Vector2 = dir * d
		var seg_end: Vector2 = dir * minf(d + dash_len, line_len)
		draw_line(seg_start, seg_end, Color(fc.r, fc.g, fc.b, 0.4), 1.0)
		d += dash_len + gap_len

	# Flag pole (vertical line)
	var pole_base: Vector2 = rp_local
	var pole_top: Vector2 = rp_local + Vector2(0, -14.0)
	draw_line(pole_base, pole_top, flag_color, 1.5)

	# Animated flag triangle (wave effect)
	var wave: float = sin(_time * 3.0) * 2.0
	var flag_pts := PackedVector2Array()
	flag_pts.append(pole_top)
	flag_pts.append(pole_top + Vector2(8.0 + wave, 3.0))
	flag_pts.append(pole_top + Vector2(0, 6.0))
	draw_colored_polygon(flag_pts, flag_color)

	# Small base circle
	draw_circle(pole_base, 2.0, flag_color)

func _draw_repair_sparkles() -> void:
	## Draw green sparkle particles around building when being repaired
	var sparkle_alpha: float = 1.0 if _being_repaired else maxf(_repair_fade * 2.0, 0.0)
	var sparkle_color: Color = Color(0.3, 1.0, 0.4, 0.6 * sparkle_alpha)
	for i in range(6):
		var angle: float = _time * 2.5 + TAU * float(i) / 6.0
		var radius: float = size_radius * (0.6 + 0.3 * sin(_time * 4.0 + float(i) * 1.3))
		var pos: Vector2 = Vector2(cos(angle) * radius, sin(angle) * radius)
		# Sparkle: small cross
		var spark_size: float = 2.0 + sin(_time * 6.0 + float(i)) * 1.0
		draw_line(pos - Vector2(spark_size, 0), pos + Vector2(spark_size, 0), sparkle_color, 1.0)
		draw_line(pos - Vector2(0, spark_size), pos + Vector2(0, spark_size), sparkle_color, 1.0)
		# Small glow dot
		draw_circle(pos, 1.5, Color(0.3, 1.0, 0.4, 0.3 * sparkle_alpha))

# === SERIALIZATION ===

func serialize() -> Dictionary:
	var prod_queue_copy: Array = []
	for ut in _production_queue:
		prod_queue_copy.append(ut)
	var res_queue_copy: Array = []
	for entry in _research_queue:
		res_queue_copy.append({"id": entry.get("id", 0), "is_building": entry.get("is_building", false)})
	return {
		"building_type": building_type,
		"faction_id": faction_id,
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"health": health,
		"max_health": max_health,
		"construction_progress": construction_progress,
		"is_constructed": _is_constructed,
		"build_time": build_time,
		"build_rotation": build_rotation,
		"production_queue": prod_queue_copy,
		"production_timer": _production_timer,
		"current_production_time": _current_production_time,
		"research_queue": res_queue_copy,
		"research_timer": _research_timer,
		"current_research_time": _current_research_time,
		"is_researching": _is_researching,
		"building_upgrade_id": _building_upgrade_id,
		"rally_x": rally_point.x,
		"rally_y": rally_point.y,
		"has_rally_point": has_rally_point,
		"supply_provided": supply_provided,
		"attack_range": attack_range,
		"attack_damage": attack_damage,
		"singularity_charge": _singularity_charge,
		"singularity_cooldown": _singularity_cooldown,
		"singularity_charging": _singularity_charging,
	}

func deserialize(data: Dictionary) -> void:
	health = data.get("health", max_health)
	max_health = data.get("max_health", max_health)
	construction_progress = data.get("construction_progress", 0.0)
	_is_constructed = data.get("is_constructed", false)
	build_time = data.get("build_time", build_time)
	build_rotation = data.get("build_rotation", 0.0)
	_production_timer = data.get("production_timer", 0.0)
	_current_production_time = data.get("current_production_time", 0.0)
	_research_timer = data.get("research_timer", 0.0)
	_current_research_time = data.get("current_research_time", 0.0)
	_is_researching = data.get("is_researching", false)
	_building_upgrade_id = data.get("building_upgrade_id", -1)
	supply_provided = data.get("supply_provided", supply_provided)
	attack_range = data.get("attack_range", attack_range)
	attack_damage = data.get("attack_damage", attack_damage)
	# Restore production queue
	var prod_q: Array = data.get("production_queue", [])
	_production_queue.clear()
	for ut in prod_q:
		_production_queue.append(int(ut))
	# Restore research queue
	var res_q: Array = data.get("research_queue", [])
	_research_queue.clear()
	for entry in res_q:
		_research_queue.append({"id": int(entry.get("id", 0)), "is_building": entry.get("is_building", false)})
	# Singularity Core state
	_singularity_charge = data.get("singularity_charge", 0.0)
	_singularity_cooldown = data.get("singularity_cooldown", 0.0)
	_singularity_charging = data.get("singularity_charging", false)
	# Rally point
	if data.get("has_rally_point", false):
		rally_point = Vector2(data.get("rally_x", 0.0), data.get("rally_y", 0.0))
		has_rally_point = true

# === RESEARCH ===

func set_tech_tree(tree: Node) -> void:
	_tech_tree = tree

func queue_research(upgrade_id: int, is_building_upgrade: bool = false) -> bool:
	## Queue a research item. Returns true if successfully queued. Max 3 in queue.
	if not _is_constructed:
		return false
	if not _tech_tree:
		return false
	if _research_queue.size() >= 3:
		return false

	var data: Dictionary = {}
	if is_building_upgrade:
		if upgrade_id not in _tech_tree.BUILDING_UPGRADE_DATA:
			return false
		if _tech_tree.has_building_upgrade(faction_id, upgrade_id):
			return false
		data = _tech_tree.BUILDING_UPGRADE_DATA[upgrade_id]
		# Building upgrades can only be researched at the correct building type
		var target_building: int = data.get("target_building", -1)
		if target_building != building_type:
			return false
	else:
		if upgrade_id not in _tech_tree.UPGRADE_DATA:
			return false
		if not _tech_tree.can_research(faction_id, upgrade_id):
			return false
		# Unit upgrades are researched at Evolution Chamber
		if building_type != BuildingStats.BuildingType.EVOLUTION_CHAMBER:
			return false
		data = _tech_tree.UPGRADE_DATA[upgrade_id]

	# Spend resources
	var stage: Node = get_tree().get_first_node_in_group("rts_stage")
	if not stage or not stage.has_method("get_resource_manager"):
		return false
	var rm: Node = stage.get_resource_manager()
	if not rm.spend(faction_id, data.get("cost_biomass", 0), data.get("cost_genes", 0)):
		return false

	_research_queue.append({"id": upgrade_id, "is_building": is_building_upgrade})
	if not _is_researching:
		_start_research()
	return true

func _start_research() -> void:
	if _research_queue.is_empty():
		_is_researching = false
		_current_research_type = ""
		return
	var entry: Dictionary = _research_queue[0]
	var upgrade_id: int = entry.get("id", 0)
	var is_building: bool = entry.get("is_building", false)
	var data: Dictionary = {}
	if is_building:
		data = _tech_tree.BUILDING_UPGRADE_DATA.get(upgrade_id, {})
		_current_research_type = "building"
	else:
		data = _tech_tree.UPGRADE_DATA.get(upgrade_id, {})
		_current_research_type = "unit"
	_current_research_time = data.get("research_time", 20.0)
	# Apply production multiplier from faction data
	var fd: Dictionary = FactionData.get_faction(faction_id)
	_current_research_time /= fd.get("build_speed_mult", 1.0)
	_research_timer = 0.0
	_is_researching = true

func _process_research(delta: float) -> void:
	if not _is_researching or _research_queue.is_empty():
		return
	_research_timer += delta
	if _research_timer >= _current_research_time:
		_complete_current_research()

func _complete_current_research() -> void:
	if _research_queue.is_empty():
		_is_researching = false
		return
	var entry: Dictionary = _research_queue.pop_front()
	var upgrade_id: int = entry.get("id", 0)
	var is_building: bool = entry.get("is_building", false)
	if _tech_tree:
		if is_building:
			_tech_tree.complete_building_upgrade(faction_id, upgrade_id)
			_apply_building_upgrade(upgrade_id)
		else:
			_tech_tree.complete_upgrade(faction_id, upgrade_id)
	research_complete.emit(self, upgrade_id, is_building)
	if faction_id == 0:
		AudioManager.play_rts_build_complete()
	# Start next in queue
	_start_research()

func _apply_building_upgrade(uid: int) -> void:
	## Apply a building-specific upgrade to this building.
	_building_upgrade_id = uid
	match uid:
		0:  # HATCHERY — applied to Spawning Pool
			supply_provided += 10
		1:  # SPINE_TOWER — applied to Membrane Tower
			attack_damage *= 1.5
			attack_range += 50.0
		2:  # REFINERY — applied to Nutrient Processor
			pass  # Gather rate bonus is checked via tech_tree by units

func get_research_progress() -> float:
	if not _is_researching or _current_research_time <= 0:
		return 0.0
	return clampf(_research_timer / _current_research_time, 0.0, 1.0)

func is_researching() -> bool:
	return _is_researching

func is_upgraded() -> bool:
	return _building_upgrade_id >= 0

func get_upgrade_name() -> String:
	if _building_upgrade_id < 0:
		return ""
	if not _tech_tree:
		return "Upgraded"
	return _tech_tree.get_building_upgrade_name(_building_upgrade_id)

func get_current_research_name() -> String:
	if _research_queue.is_empty():
		return ""
	var entry: Dictionary = _research_queue[0]
	var upgrade_id: int = entry.get("id", 0)
	var is_building: bool = entry.get("is_building", false)
	if is_building:
		return _tech_tree.get_building_upgrade_name(upgrade_id) if _tech_tree else "Research"
	else:
		return _tech_tree.get_upgrade_name(upgrade_id) if _tech_tree else "Research"

func get_research_queue_size() -> int:
	return _research_queue.size()

func _draw_research_bar() -> void:
	## Purple/cyan research progress bar below production bar
	var bar_w: float = size_radius * 1.5
	var bar_h: float = 2.5
	# Place below production bar if it exists, otherwise below building
	var bar_y: float = size_radius + 5.0
	if not _production_queue.is_empty():
		bar_y += 5.0  # Offset below production bar
	var pct: float = get_research_progress()
	# Background
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.1, 0.05, 0.15, 0.5))
	# Fill — animated purple-cyan gradient
	var fill_color: Color = Color(0.55 + 0.15 * sin(_time * 2.0), 0.2, 0.85 + 0.1 * sin(_time * 3.0), 0.8)
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * pct, bar_h), fill_color)
	# Small glow at fill edge
	if pct > 0.02 and pct < 0.99:
		var edge_x: float = -bar_w * 0.5 + bar_w * pct
		draw_circle(Vector2(edge_x, bar_y + bar_h * 0.5), 2.5, Color(0.6, 0.3, 1.0, 0.3))

func _draw_supply_depot(mc: Color, gc: Color) -> void:
	# Rounded organic sac shape — wider than tall (ellipse)
	var pulse: float = 1.0 + 0.03 * sin(_time * 1.2)
	var rx: float = size_radius * 1.2 * pulse
	var ry: float = size_radius * 0.8 * pulse
	var sac_pts := PackedVector2Array()
	for i in range(24):
		var angle: float = TAU * float(i) / 24.0
		sac_pts.append(Vector2(cos(angle) * rx, sin(angle) * ry).rotated(build_rotation))
	var sac_color: Color = Color(0.4, 0.2, 0.6, 0.8)
	draw_colored_polygon(sac_pts, Color(sac_color.r * mc.r * 2.0, sac_color.g * mc.g * 2.0, sac_color.b * mc.b * 2.0, 0.75))
	# Inner cavity (darker)
	draw_circle(Vector2.ZERO, size_radius * 0.5, Color(sac_color.r * 0.4, sac_color.g * 0.3, sac_color.b * 0.5, 0.6))
	# Pulsing veins across surface (3 sine-based line paths)
	var vein_color: Color = Color(gc.r * 0.6, gc.g * 0.3, gc.b * 0.8, 0.4 + 0.15 * sin(_time * 2.5))
	for vi in range(3):
		var vein_pts := PackedVector2Array()
		var base_y: float = -ry * 0.5 + ry * float(vi) / 2.0
		for j in range(10):
			var t: float = float(j) / 9.0
			var vx: float = (t - 0.5) * rx * 1.8
			var vy: float = base_y + sin(t * PI * 2.0 + _time * 1.5 + float(vi) * 1.2) * 5.0
			vein_pts.append(Vector2(vx, vy).rotated(build_rotation))
		for j in range(vein_pts.size() - 1):
			draw_line(vein_pts[j], vein_pts[j + 1], vein_color, 1.5)
	# Supply count label when selected
	if is_selected and faction_id == 0:
		var font: Font = ThemeDB.fallback_font
		var stage: Node = get_tree().get_first_node_in_group("rts_stage")
		if stage and stage.has_method("get_faction_manager"):
			var fm: Node = stage.get_faction_manager()
			var used: int = fm.get_supply_used(faction_id)
			var cap: int = fm.get_supply_cap(faction_id)
			var supply_text: String = "Supply: %d/%d" % [used, cap]
			draw_string(font, Vector2(-30, -size_radius - 16), supply_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 9, Color(0.7, 0.5, 1.0, 0.9))

func _draw_upgrade_indicator(gc: Color) -> void:
	## Small chevron/star indicator showing this building is upgraded
	var indicator_y: float = -size_radius - 14.0
	# Small diamond
	var pts := PackedVector2Array()
	pts.append(Vector2(0, indicator_y - 4.0))
	pts.append(Vector2(3.0, indicator_y))
	pts.append(Vector2(0, indicator_y + 4.0))
	pts.append(Vector2(-3.0, indicator_y))
	draw_colored_polygon(pts, Color(gc.r, gc.g, gc.b, 0.7))
	# Tiny glow
	draw_circle(Vector2(0, indicator_y), 5.0, Color(gc.r, gc.g, gc.b, 0.1))

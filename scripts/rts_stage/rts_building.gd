extends StaticBody2D
## Base RTS building with construction, production, and procedural _draw().

signal construction_complete(building: Node2D)
signal destroyed(building: Node2D)
signal unit_produced(building: Node2D, unit_type: int)

var faction_id: int = 0
var building_type: int = BuildingStats.BuildingType.BIO_WALL
var creature_template: CreatureTemplate = null

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

# Rally point
var rally_point: Vector2 = Vector2.ZERO
var has_rally_point: bool = false

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

func add_construction(amount: float) -> void:
	if _is_constructed:
		return
	construction_progress += amount
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
	if health <= 0:
		_die()

func _die() -> void:
	destroyed.emit(self)
	queue_free()

# === RALLY POINT ===

func set_rally_point(pos: Vector2) -> void:
	rally_point = pos
	has_rally_point = true
	queue_redraw()

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

func _process(delta: float) -> void:
	_time += delta
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	# Production
	if _is_constructed and not _production_queue.is_empty():
		_production_timer += delta
		if _production_timer >= _current_production_time:
			var unit_type: int = _production_queue.pop_front()
			unit_produced.emit(self, unit_type)
			_start_production()  # Start next in queue
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
			var angle: float = TAU * float(i) / 4.0
			draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle)) * size_radius * 0.8, Color(0.5, 0.5, 0.4, 0.3 * pct), 1.0)
		return

	# Hurt flash
	if _hurt_flash > 0:
		draw_circle(Vector2.ZERO, size_radius * 1.2, Color(1.0, 0.2, 0.2, _hurt_flash * 0.25))

	# Glow
	draw_circle(Vector2.ZERO, size_radius * 1.5, Color(gc.r, gc.g, gc.b, 0.04))

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

	# Health bar
	_draw_health_bar()

	# Production progress
	if not _production_queue.is_empty():
		_draw_production_bar()

	# Rally point
	if has_rally_point and faction_id == 0:
		_draw_rally_point()

func _draw_spawning_pool(mc: Color, gc: Color) -> void:
	# Large pulsing pool
	var pulse: float = 1.0 + 0.05 * sin(_time * 1.5)
	# Outer membrane
	var pts := PackedVector2Array()
	for i in range(20):
		var angle: float = TAU * float(i) / 20.0
		var r: float = size_radius * pulse + sin(angle * 3.0 + _time) * 3.0
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(pts, Color(mc.r * 0.6, mc.g * 0.6, mc.b * 0.6, 0.8))
	# Inner pool
	draw_circle(Vector2.ZERO, size_radius * 0.6, Color(mc.r * 0.3, mc.g * 0.3, mc.b * 0.3, 0.9))
	# Bubbles
	for i in range(3):
		var ba: float = _time * 0.5 + TAU * float(i) / 3.0
		var bp: Vector2 = Vector2(cos(ba) * 12.0, sin(ba) * 12.0)
		draw_circle(bp, 3.0, Color(gc.r, gc.g, gc.b, 0.3))

func _draw_evolution_chamber(mc: Color, gc: Color) -> void:
	# Hexagonal-ish structure
	var pts := PackedVector2Array()
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0 + PI / 6.0
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
	# Tall tower shape with concentric rings
	draw_circle(Vector2.ZERO, size_radius, Color(mc.r * 0.7, mc.g * 0.5, mc.b * 0.5, 0.8))
	draw_arc(Vector2.ZERO, size_radius * 0.7, 0, TAU, 16, Color(mc.r * 0.5, mc.g * 0.3, mc.b * 0.3, 0.4), 1.5)
	# Eye on top (uses smoothed direction)
	draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
	draw_circle(Vector2.ZERO, 6.5, Color(gc.r, gc.g, gc.b, 0.3 + 0.1 * sin(_time * 2.0)))
	draw_circle(_tower_eye_dir, 3.0, Color(0.9, 0.2, 0.2))
	# Pupil highlight
	draw_circle(_tower_eye_dir + Vector2(-0.5, -0.5), 1.0, Color(1.0, 0.5, 0.5, 0.6))
	# Range indicator (dashed)
	if attack_range > 0:
		var dash_count: int = 16
		var dash_arc: float = TAU / float(dash_count) * 0.5
		for di in range(dash_count):
			var a_start: float = float(di) * TAU / float(dash_count) + _time * 0.2
			draw_arc(Vector2.ZERO, attack_range, a_start, a_start + dash_arc, 4, Color(mc.r, mc.g, mc.b, 0.06), 1.0)

func _draw_bio_wall(mc: Color, _gc: Color) -> void:
	# Thick wall segment
	var pts := PackedVector2Array()
	pts.append(Vector2(-size_radius, -size_radius * 0.6))
	pts.append(Vector2(size_radius, -size_radius * 0.6))
	pts.append(Vector2(size_radius, size_radius * 0.6))
	pts.append(Vector2(-size_radius, size_radius * 0.6))
	draw_colored_polygon(pts, Color(mc.r * 0.4, mc.g * 0.4, mc.b * 0.3, 0.9))
	# Texture lines
	for i in range(3):
		var x: float = -size_radius + size_radius * 2.0 * float(i + 1) / 4.0
		draw_line(Vector2(x, -size_radius * 0.5), Vector2(x, size_radius * 0.5), Color(mc.r * 0.3, mc.g * 0.3, mc.b * 0.2, 0.4), 1.5)

func _draw_nutrient_processor(mc: Color, gc: Color) -> void:
	# Circular processor with vanes
	draw_circle(Vector2.ZERO, size_radius, Color(mc.r * 0.5, mc.g * 0.6, mc.b * 0.4, 0.8))
	# Rotating vanes
	for i in range(4):
		var angle: float = _time * 0.5 + TAU * float(i) / 4.0
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * 5.0
		var end: Vector2 = Vector2(cos(angle), sin(angle)) * (size_radius * 0.8)
		draw_line(start, end, Color(gc.r, gc.g, gc.b, 0.5), 2.0)
	draw_circle(Vector2.ZERO, 5.0, Color(gc.r, gc.g, gc.b, 0.6))

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
	## Draws a rally point flag with dotted line from building
	var rp_local: Vector2 = rally_point - global_position
	var flag_color: Color = Color(0.2, 1.0, 0.4, 0.7)

	# Dotted line from building center to rally point
	var line_len: float = rp_local.length()
	var dir: Vector2 = rp_local.normalized() if line_len > 0 else Vector2.RIGHT
	var dash_len: float = 6.0
	var gap_len: float = 4.0
	var d: float = 0.0
	while d < line_len:
		var seg_start: Vector2 = dir * d
		var seg_end: Vector2 = dir * minf(d + dash_len, line_len)
		draw_line(seg_start, seg_end, Color(flag_color.r, flag_color.g, flag_color.b, 0.4), 1.0)
		d += dash_len + gap_len

	# Flag pole (vertical line)
	var pole_base: Vector2 = rp_local
	var pole_top: Vector2 = rp_local + Vector2(0, -14.0)
	draw_line(pole_base, pole_top, flag_color, 1.5)

	# Flag triangle
	var flag_pts := PackedVector2Array()
	flag_pts.append(pole_top)
	flag_pts.append(pole_top + Vector2(8.0, 3.0))
	flag_pts.append(pole_top + Vector2(0, 6.0))
	draw_colored_polygon(flag_pts, flag_color)

	# Small base circle
	draw_circle(pole_base, 2.0, flag_color)

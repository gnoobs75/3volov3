extends Node2D
## Ambient micro-life: tiny non-interactable creatures that make the petri dish
## feel alive and horrifying. OPTIMIZED for performance.

const NUM_CREATURES: int = 35  # Further reduced for performance
const SPAWN_RANGE: float = 400.0  # Smaller range for denser feel
const PLAYER_DETECT_RANGE: float = 180.0
const VIEWPORT_MARGIN: float = 100.0  # Pixels beyond viewport to still draw

enum CreatureType { BACTERIA, PARAMECIUM, SPIROCHETE, ROTIFER, FLAGELLATE, PHAGE, DIATOM, TARDIGRADE }
enum Behavior { WANDER, CURIOUS, NIPPER, CIRCLER, FLEER, DRIFTER }

var _creatures: Array[Dictionary] = []
var _time: float = 0.0
var _player: Node2D = null
var _update_index: int = 0  # For staggered updates
var _viewport_size: Vector2 = Vector2(1920, 1080)
var _camera_pos: Vector2 = Vector2.ZERO
var _camera_zoom: float = 1.0

func _ready() -> void:
	for i in range(NUM_CREATURES):
		_creatures.append(_spawn_creature())
	call_deferred("_find_player")

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _spawn_creature() -> Dictionary:
	var type: CreatureType = randi() % CreatureType.size() as CreatureType
	var behavior: Behavior = _random_behavior_for_type(type)
	var base_speed: float = _speed_for_type(type)

	return {
		"pos": _random_spawn_pos(),
		"vel": Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * base_speed,
		"type": type,
		"behavior": behavior,
		"size": randf_range(2.0, 5.0) * _size_mult_for_type(type),
		"phase": randf() * TAU,
		"rotation": randf() * TAU,
		"color": _color_for_type(type),
		"alpha": randf_range(0.2, 0.5),
		"state": 0,  # 0=idle, 1=approaching, 2=nipping, 3=fleeing
		"state_timer": randf_range(0.0, 3.0),
		"target_dir": Vector2.RIGHT.rotated(randf() * TAU),
		"nip_cooldown": 0.0,
		"speed": base_speed,
		"visible": true,
	}

func _random_spawn_pos() -> Vector2:
	if _player:
		return _player.global_position + Vector2(randf_range(-SPAWN_RANGE, SPAWN_RANGE), randf_range(-SPAWN_RANGE, SPAWN_RANGE))
	return Vector2(randf_range(-SPAWN_RANGE, SPAWN_RANGE), randf_range(-SPAWN_RANGE, SPAWN_RANGE))

func _speed_for_type(type: CreatureType) -> float:
	match type:
		CreatureType.BACTERIA: return randf_range(50.0, 90.0)
		CreatureType.SPIROCHETE: return randf_range(60.0, 100.0)
		CreatureType.PARAMECIUM: return randf_range(25.0, 45.0)
		CreatureType.ROTIFER: return randf_range(10.0, 25.0)
		CreatureType.PHAGE: return randf_range(70.0, 110.0)
		CreatureType.DIATOM: return randf_range(5.0, 12.0)
		CreatureType.TARDIGRADE: return randf_range(15.0, 25.0)
		_: return randf_range(20.0, 50.0)

func _random_behavior_for_type(type: CreatureType) -> Behavior:
	var roll: int = randi() % 4
	match type:
		CreatureType.BACTERIA: return [Behavior.WANDER, Behavior.WANDER, Behavior.NIPPER, Behavior.FLEER][roll]
		CreatureType.PARAMECIUM: return [Behavior.WANDER, Behavior.CURIOUS, Behavior.CIRCLER, Behavior.WANDER][roll]
		CreatureType.SPIROCHETE: return [Behavior.WANDER, Behavior.NIPPER, Behavior.NIPPER, Behavior.WANDER][roll]
		CreatureType.PHAGE: return [Behavior.NIPPER, Behavior.NIPPER, Behavior.WANDER, Behavior.FLEER][roll]
		_: return [Behavior.DRIFTER, Behavior.WANDER, Behavior.CURIOUS, Behavior.DRIFTER][roll]

func _size_mult_for_type(type: CreatureType) -> float:
	match type:
		CreatureType.BACTERIA: return 0.4
		CreatureType.PHAGE: return 0.35
		CreatureType.SPIROCHETE: return 0.5
		CreatureType.DIATOM: return 0.7
		CreatureType.PARAMECIUM: return 1.1
		CreatureType.TARDIGRADE: return 1.5
		_: return 1.0

func _color_for_type(type: CreatureType) -> Color:
	match type:
		CreatureType.BACTERIA: return Color(0.7, 0.85, 0.6)
		CreatureType.PARAMECIUM: return Color(0.6, 0.75, 0.9)
		CreatureType.SPIROCHETE: return Color(0.9, 0.7, 0.8)
		CreatureType.ROTIFER: return Color(0.8, 0.8, 0.5)
		CreatureType.FLAGELLATE: return Color(0.5, 0.9, 0.7)
		CreatureType.PHAGE: return Color(0.9, 0.5, 0.4)
		CreatureType.DIATOM: return Color(0.6, 0.8, 0.7)
		CreatureType.TARDIGRADE: return Color(0.8, 0.7, 0.6)
	return Color(0.7, 0.7, 0.7)

func _process(delta: float) -> void:
	_time += delta

	if not _player:
		_find_player()
		return

	# Cache camera info for culling
	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam:
		_camera_pos = _player.global_position
		_camera_zoom = cam.zoom.x

	# Staggered updates: only update 10 creatures per frame
	var updates_per_frame: int = 10
	for i in range(updates_per_frame):
		var idx: int = (_update_index + i) % _creatures.size()
		_update_creature(_creatures[idx], delta * (_creatures.size() / float(updates_per_frame)))
	_update_index = (_update_index + updates_per_frame) % _creatures.size()

	# Only redraw when player is within visual range
	if _player and global_position.distance_squared_to(_player.global_position) < 1440000.0:
		queue_redraw()

func _update_creature(c: Dictionary, delta: float) -> void:
	c.state_timer -= delta
	c.nip_cooldown -= delta
	c.phase += delta * 6.0  # Slower wiggle update
	c.rotation += delta  # Simplified rotation

	# Check visibility for culling
	c.visible = _is_in_viewport(c.pos)

	var player_pos: Vector2 = _player.global_position
	var to_player: Vector2 = player_pos - c.pos
	var dist_to_player: float = to_player.length()

	# Simplified behavior state machine
	match c.behavior:
		Behavior.WANDER:
			if c.state_timer <= 0:
				c.target_dir = Vector2.RIGHT.rotated(randf() * TAU)
				c.state_timer = randf_range(1.5, 4.0)
			c.vel = c.vel.lerp(c.target_dir * c.speed, delta * 2.0)

		Behavior.CURIOUS:
			if c.state == 0:  # idle
				if dist_to_player < PLAYER_DETECT_RANGE and randf() < 0.008:
					c.state = 1
					c.state_timer = randf_range(1.5, 2.5)
				elif c.state_timer <= 0:
					c.target_dir = Vector2.RIGHT.rotated(randf() * TAU)
					c.state_timer = randf_range(2.0, 4.0)
				c.vel = c.vel.lerp(c.target_dir * c.speed, delta * 2.0)
			elif c.state == 1:  # approaching
				if c.state_timer <= 0 or dist_to_player < 35.0:
					c.state = 3
					c.state_timer = randf_range(1.0, 2.0)
				else:
					c.vel = c.vel.lerp(to_player.normalized() * c.speed * 0.8, delta * 3.0)
			else:  # fleeing
				if c.state_timer <= 0:
					c.state = 0
					c.state_timer = randf_range(2.0, 4.0)
				else:
					c.vel = c.vel.lerp(-to_player.normalized() * c.speed * 1.5, delta * 4.0)

		Behavior.NIPPER:
			if c.state == 0:  # idle
				if dist_to_player < PLAYER_DETECT_RANGE and c.nip_cooldown <= 0 and randf() < 0.015:
					c.state = 1
					c.state_timer = randf_range(0.6, 1.2)
				elif c.state_timer <= 0:
					c.target_dir = Vector2.RIGHT.rotated(randf() * TAU)
					c.state_timer = randf_range(1.5, 3.0)
				c.vel = c.vel.lerp(c.target_dir * c.speed, delta * 2.0)
			elif c.state == 1:  # approaching
				if dist_to_player < 20.0:
					c.state = 2
					c.state_timer = 0.12
				elif c.state_timer <= 0:
					c.state = 3
					c.state_timer = randf_range(0.5, 1.0)
				else:
					c.vel = c.vel.lerp(to_player.normalized() * c.speed * 2.5, delta * 6.0)
			elif c.state == 2:  # nipping
				if c.state_timer <= 0:
					c.state = 3
					c.state_timer = randf_range(1.0, 1.5)
					c.nip_cooldown = randf_range(4.0, 8.0)
				c.vel = Vector2(randf_range(-40, 40), randf_range(-40, 40))
			else:  # fleeing
				if c.state_timer <= 0:
					c.state = 0
					c.state_timer = randf_range(2.0, 5.0)
				else:
					c.vel = c.vel.lerp(-to_player.normalized() * c.speed * 3.0, delta * 8.0)

		Behavior.CIRCLER:
			if dist_to_player < PLAYER_DETECT_RANGE * 1.5:
				var tangent: Vector2 = to_player.normalized().rotated(PI * 0.5)
				var orbit_dist: float = 70.0 + sin(_time * 0.5 + c.phase) * 25.0
				var to_orbit: Vector2 = (player_pos + to_player.normalized() * orbit_dist - c.pos).normalized()
				c.vel = c.vel.lerp((tangent + to_orbit * 0.3).normalized() * c.speed, delta * 2.0)
			else:
				if c.state_timer <= 0:
					c.target_dir = Vector2.RIGHT.rotated(randf() * TAU)
					c.state_timer = randf_range(2.0, 4.0)
				c.vel = c.vel.lerp(c.target_dir * c.speed, delta * 2.0)

		Behavior.FLEER:
			if dist_to_player < PLAYER_DETECT_RANGE:
				c.vel = c.vel.lerp(-to_player.normalized() * c.speed * 1.5, delta * 5.0)
			else:
				if c.state_timer <= 0:
					c.target_dir = Vector2.RIGHT.rotated(randf() * TAU)
					c.state_timer = randf_range(2.0, 4.0)
				c.vel = c.vel.lerp(c.target_dir * c.speed, delta * 2.0)

		Behavior.DRIFTER:
			if c.state_timer <= 0:
				c.target_dir = Vector2.RIGHT.rotated(randf() * TAU)
				c.state_timer = randf_range(4.0, 8.0)
			c.vel = c.vel.lerp(c.target_dir * c.speed * 0.3, delta * 0.5)

	# Apply movement
	c.pos += c.vel * delta

	# Keep near player
	if c.pos.distance_to(_player.global_position) > SPAWN_RANGE:
		c.pos = _player.global_position + Vector2(randf_range(-SPAWN_RANGE * 0.4, SPAWN_RANGE * 0.4), randf_range(-SPAWN_RANGE * 0.4, SPAWN_RANGE * 0.4))
		c.state = 0
		c.state_timer = randf_range(1.0, 3.0)

func _is_in_viewport(pos: Vector2) -> bool:
	var half_view: Vector2 = (_viewport_size / _camera_zoom) * 0.5 + Vector2(VIEWPORT_MARGIN, VIEWPORT_MARGIN)
	var rel: Vector2 = pos - _camera_pos
	return abs(rel.x) < half_view.x and abs(rel.y) < half_view.y

func _draw() -> void:
	if not _player:
		return

	for c in _creatures:
		if not c.visible:
			continue
		_draw_creature(c)

func _draw_creature(c: Dictionary) -> void:
	var pos: Vector2 = c.pos
	var col: Color = c.color
	col.a = c.alpha
	var size: float = c.size

	# Brighten when nipping
	if c.state == 2:
		col = col.lightened(0.4)
		size *= 1.2

	# Simplified drawing based on type
	match c.type:
		CreatureType.BACTERIA:
			_draw_bacteria_simple(pos, size, col, c)
		CreatureType.PARAMECIUM:
			_draw_paramecium_simple(pos, size, col, c)
		CreatureType.SPIROCHETE:
			_draw_spirochete_simple(pos, size, col, c)
		CreatureType.ROTIFER:
			_draw_rotifer_simple(pos, size, col, c)
		CreatureType.FLAGELLATE:
			_draw_flagellate_simple(pos, size, col, c)
		CreatureType.PHAGE:
			_draw_phage_simple(pos, size, col, c)
		CreatureType.DIATOM:
			_draw_diatom_simple(pos, size, col, c)
		CreatureType.TARDIGRADE:
			_draw_tardigrade_simple(pos, size, col, c)

func _draw_bacteria_simple(pos: Vector2, size: float, col: Color, c: Dictionary) -> void:
	var facing: float = c.vel.angle() if c.vel.length() > 1.0 else c.rotation
	# Simple rod or dot
	var p1: Vector2 = pos + Vector2(cos(facing), sin(facing)) * size
	var p2: Vector2 = pos - Vector2(cos(facing), sin(facing)) * size
	draw_line(p1, p2, col, size * 0.7, true)

func _draw_paramecium_simple(pos: Vector2, size: float, col: Color, c: Dictionary) -> void:
	# Simplified to just oval shape, no cilia
	var facing: float = c.vel.angle() if c.vel.length() > 1.0 else c.rotation
	draw_circle(pos, size, Color(col.r, col.g, col.b, col.a * 0.5))
	draw_circle(pos + Vector2(cos(facing), sin(facing)) * size * 0.4, size * 0.5, Color(col.r, col.g, col.b, col.a * 0.4))

func _draw_spirochete_simple(pos: Vector2, size: float, col: Color, c: Dictionary) -> void:
	var facing: float = c.vel.angle() if c.vel.length() > 1.0 else c.rotation
	# Simple wavy line
	var prev: Vector2 = pos - Vector2(cos(facing), sin(facing)) * size * 2.0
	for i in range(5):
		var t: float = float(i) / 4.0
		var wave: float = sin(c.phase + t * 6.0) * size * 0.5
		var along: Vector2 = Vector2(cos(facing), sin(facing)) * (t - 0.5) * size * 4.0
		var perp: Vector2 = Vector2(-sin(facing), cos(facing)) * wave
		var p: Vector2 = pos + along + perp
		draw_line(prev, p, col, size * 0.3, true)
		prev = p

func _draw_rotifer_simple(pos: Vector2, size: float, col: Color, c: Dictionary) -> void:
	# Simplified - body with small head
	draw_circle(pos, size, Color(col.r, col.g, col.b, col.a * 0.5))
	var head_pos: Vector2 = pos + Vector2(0, -size * 0.8).rotated(c.rotation)
	draw_circle(head_pos, size * 0.4, Color(col.r, col.g, col.b, col.a * 0.6))

func _draw_flagellate_simple(pos: Vector2, size: float, col: Color, c: Dictionary) -> void:
	var facing: float = c.vel.angle() if c.vel.length() > 1.0 else c.rotation
	draw_circle(pos, size, Color(col.r, col.g, col.b, col.a * 0.6))
	# Simple flagellum
	var base: Vector2 = pos + Vector2(cos(facing), sin(facing)) * size
	var tip: Vector2 = base + Vector2(cos(facing), sin(facing)) * size * 3.0 + Vector2(sin(c.phase) * 3.0, cos(c.phase) * 2.0)
	draw_line(base, tip, Color(col.r, col.g, col.b, col.a * 0.5), 0.5, true)

func _draw_phage_simple(pos: Vector2, size: float, col: Color, c: Dictionary) -> void:
	# Hexagonal head
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var a: float = TAU * i / 6.0 + c.rotation
		pts.append(pos + Vector2(cos(a), sin(a)) * size)
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, col.a * 0.6))
	# Tail
	var tail_dir: Vector2 = c.vel.normalized() if c.vel.length() > 1.0 else Vector2.DOWN
	var tail_end: Vector2 = pos + tail_dir * size * 2.5
	draw_line(pos + tail_dir * size, tail_end, col, size * 0.25, true)

func _draw_diatom_simple(pos: Vector2, size: float, col: Color, c: Dictionary) -> void:
	# Simplified to just a circle with center dot
	draw_circle(pos, size, Color(col.r, col.g, col.b, col.a * 0.4))
	draw_circle(pos, size * 0.3, Color(col.r, col.g, col.b, col.a * 0.6))

func _draw_tardigrade_simple(pos: Vector2, size: float, col: Color, c: Dictionary) -> void:
	# Simplified to 2 circles for body + head
	var facing: float = c.vel.angle() if c.vel.length() > 1.0 else c.rotation
	draw_circle(pos, size, Color(col.r, col.g, col.b, col.a * 0.5))
	var head_pos: Vector2 = pos + Vector2(cos(facing), sin(facing)) * size * 1.2
	draw_circle(head_pos, size * 0.6, col)

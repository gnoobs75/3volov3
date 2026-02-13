extends CharacterBody2D
## Electric Eel: elongated predator that charges up and releases chain-lightning.
## The discharge stuns nearby creatures and arcs between them.
## Glows brighter as it charges. Patrols in sinusoidal patterns.

enum State { PATROL, CHARGE, DISCHARGE, RECOVER, FLEE }

var state: State = State.PATROL
var health: float = 45.0
var max_health: float = 45.0
var speed: float = 110.0
var damage: float = 12.0
var stun_damage: float = 5.0
var detection_range: float = 200.0
var discharge_range: float = 120.0

var _time: float = 0.0
var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_timer: float = 0.0
var _charge_timer: float = 0.0
var _discharge_timer: float = 0.0
var _recover_timer: float = 0.0
var _charge_amount: float = 0.0  # 0-1, visual charge buildup
var _current_target: Node2D = null

const CHARGE_DURATION: float = 2.0
const DISCHARGE_DURATION: float = 0.3
const RECOVER_DURATION: float = 1.5
const MAX_CHAIN: int = 3  # Max creatures hit by chain

# Procedural graphics
var _body_length: float = 30.0
var _body_width: float = 7.0
var _base_color: Color
var _spark_color: Color
var _damage_flash: float = 0.0

# Lightning bolt visuals
var _lightning_arcs: Array = []  # [{from, to, life}]

# Face
var _eye_size: float = 2.5
var _blink_timer: float = 0.0
var _is_blinking: bool = false

func _ready() -> void:
	_init_shape()
	_pick_patrol_target()
	add_to_group("enemies")
	_blink_timer = randf_range(2.0, 4.0)

func _init_shape() -> void:
	_body_length = randf_range(28.0, 35.0)
	_body_width = randf_range(6.0, 9.0)
	_eye_size = _body_width * 0.3
	_base_color = Color(
		randf_range(0.1, 0.2),
		randf_range(0.2, 0.35),
		randf_range(0.5, 0.7),
		0.95
	)
	_spark_color = Color(
		randf_range(0.6, 0.8),
		randf_range(0.8, 1.0),
		randf_range(0.9, 1.0),
		1.0
	)

func _physics_process(delta: float) -> void:
	_time += delta
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)

	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(1.0, 3.0)
		else:
			_is_blinking = true
			_blink_timer = 0.08

	var player := _find_player()
	_current_target = player

	match state:
		State.PATROL:
			_do_patrol(delta)
			if player and global_position.distance_to(player.global_position) < detection_range:
				state = State.CHARGE
				_charge_timer = CHARGE_DURATION
		State.CHARGE:
			_do_charge(delta)
		State.DISCHARGE:
			_do_discharge(delta)
		State.RECOVER:
			_do_recover(delta)
		State.FLEE:
			_do_flee(delta)

	# Update lightning visuals
	var alive_arcs: Array = []
	for arc in _lightning_arcs:
		arc.life -= delta * 3.0
		if arc.life > 0:
			alive_arcs.append(arc)
	_lightning_arcs = alive_arcs

	move_and_slide()
	if _current_target and is_instance_valid(_current_target):
		var target_angle: float = (global_position.direction_to(_current_target.global_position)).angle()
		rotation = lerp_angle(rotation, target_angle, delta * 2.0)
	elif velocity.length() > 10:
		rotation = lerp_angle(rotation, velocity.angle(), delta * 1.5)

	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _do_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0 or global_position.distance_to(_patrol_target) < 30:
		_pick_patrol_target()
	# Sinusoidal movement
	var base_dir: Vector2 = global_position.direction_to(_patrol_target)
	var wave: float = sin(_time * 3.0) * 0.4
	velocity = velocity.lerp(base_dir.rotated(wave) * speed * 0.5, delta * 2.0)
	_charge_amount = maxf(_charge_amount - delta * 0.5, 0.0)

func _do_charge(delta: float) -> void:
	_charge_timer -= delta
	_charge_amount = minf(_charge_amount + delta / CHARGE_DURATION, 1.0)

	# Slow approach while charging
	if _current_target and is_instance_valid(_current_target):
		var dir: Vector2 = global_position.direction_to(_current_target.global_position)
		velocity = velocity.lerp(dir * speed * 0.3, delta * 2.0)
	else:
		velocity = velocity * 0.9

	if _charge_timer <= 0:
		_fire_discharge()
		state = State.DISCHARGE
		_discharge_timer = DISCHARGE_DURATION

func _do_discharge(delta: float) -> void:
	_discharge_timer -= delta
	velocity = velocity * 0.8  # Recoil
	_charge_amount = maxf(_charge_amount - delta * 4.0, 0.0)
	if _discharge_timer <= 0:
		state = State.RECOVER
		_recover_timer = RECOVER_DURATION

func _do_recover(delta: float) -> void:
	_recover_timer -= delta
	velocity = velocity * 0.95
	if _recover_timer <= 0:
		if health < max_health * 0.3:
			state = State.FLEE
		else:
			state = State.PATROL
			_pick_patrol_target()

func _do_flee(delta: float) -> void:
	if _current_target and is_instance_valid(_current_target):
		var flee_dir: Vector2 = (_current_target.global_position.direction_to(global_position))
		velocity = velocity.lerp(flee_dir * speed * 1.2, delta * 2.0)
		if global_position.distance_to(_current_target.global_position) > detection_range * 1.5:
			state = State.PATROL
	else:
		state = State.PATROL

func _fire_discharge() -> void:
	AudioManager.play_toxin()
	# Find all targets in discharge range, chain between them
	var hit_targets: Array = []
	var all_targets: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and global_position.distance_to(p.global_position) < discharge_range:
			all_targets.append(p)
	for c in get_tree().get_nodes_in_group("competitors"):
		if is_instance_valid(c) and global_position.distance_to(c.global_position) < discharge_range:
			all_targets.append(c)
	for pr in get_tree().get_nodes_in_group("prey"):
		if is_instance_valid(pr) and global_position.distance_to(pr.global_position) < discharge_range:
			all_targets.append(pr)

	# Primary target
	if _current_target and is_instance_valid(_current_target) and global_position.distance_to(_current_target.global_position) < discharge_range:
		_hit_target(_current_target, stun_damage)
		hit_targets.append(_current_target)
		_lightning_arcs.append({"from": Vector2.ZERO, "to": _current_target.global_position - global_position, "life": 1.0})

		# Chain to nearby targets
		var last_pos: Vector2 = _current_target.global_position
		for _chain in range(MAX_CHAIN):
			var best: Node2D = null
			var best_dist: float = discharge_range * 0.6
			for t in all_targets:
				if t in hit_targets or not is_instance_valid(t):
					continue
				var d: float = last_pos.distance_to(t.global_position)
				if d < best_dist:
					best_dist = d
					best = t
			if best:
				_hit_target(best, stun_damage * 0.7)
				hit_targets.append(best)
				_lightning_arcs.append({"from": last_pos - global_position, "to": best.global_position - global_position, "life": 1.0})
				last_pos = best.global_position
			else:
				break

func _hit_target(target: Node2D, dmg: float) -> void:
	if target.has_method("take_damage"):
		target.take_damage(dmg)
	if target.has_method("confuse"):
		target.confuse(0.8)

func _pick_patrol_target() -> void:
	_patrol_target = global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	_patrol_timer = randf_range(3.0, 5.0)

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	var nearest: Node2D = null
	var best_dist: float = INF
	for p in players:
		var d: float = global_position.distance_squared_to(p.global_position)
		if d < best_dist:
			best_dist = d
			nearest = p
	return nearest

func _draw() -> void:
	var health_ratio: float = health / max_health
	var draw_color: Color = _base_color
	# Glow brighter when charging
	var charge_glow: float = _charge_amount

	match state:
		State.CHARGE:
			draw_color = _base_color.lerp(_spark_color, charge_glow * 0.5)
		State.DISCHARGE:
			draw_color = _spark_color
		State.FLEE:
			draw_color = _base_color.lerp(Color(0.5, 0.5, 0.3), 0.4)

	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)

	# Charge aura
	if charge_glow > 0.1:
		var aura_a: float = charge_glow * 0.15
		draw_circle(Vector2.ZERO, _body_length * 0.8, Color(_spark_color.r, _spark_color.g, _spark_color.b, aura_a))
		# Sparks orbiting
		for i in range(4):
			var sa: float = _time * 8.0 + TAU * i / 4.0
			var sr: float = _body_length * 0.5 * charge_glow
			var sp := Vector2(cos(sa) * sr, sin(sa) * sr * 0.5)
			draw_circle(sp, 1.5, Color(_spark_color, charge_glow * 0.8))

	# Body glow
	draw_circle(Vector2.ZERO, _body_length * 0.6, Color(draw_color.r, draw_color.g, draw_color.b, 0.06 + charge_glow * 0.08))

	# Eel body - long sinusoidal shape
	var body_pts: PackedVector2Array = PackedVector2Array()
	var segments: int = 16
	# Top edge
	for i in range(segments):
		var t: float = float(i) / float(segments - 1)
		var x: float = lerpf(_body_length * 0.5, -_body_length * 0.5, t)
		var wave: float = sin(_time * 4.0 + t * PI * 2.0) * 2.0 * t
		var w: float = _body_width * sin(t * PI) * 0.9
		if t < 0.15:
			w *= t / 0.15  # Taper nose
		if t > 0.85:
			w *= (1.0 - t) / 0.15  # Taper tail
		body_pts.append(Vector2(x, -w + wave))
	# Bottom edge (reverse)
	for i in range(segments - 1, -1, -1):
		var t: float = float(i) / float(segments - 1)
		var x: float = lerpf(_body_length * 0.5, -_body_length * 0.5, t)
		var wave: float = sin(_time * 4.0 + t * PI * 2.0) * 2.0 * t
		var w: float = _body_width * sin(t * PI) * 0.9
		if t < 0.15:
			w *= t / 0.15
		if t > 0.85:
			w *= (1.0 - t) / 0.15
		body_pts.append(Vector2(x, w + wave))

	var fill_color := Color(draw_color.r * 0.4, draw_color.g * 0.4, draw_color.b * 0.5, 0.85)
	draw_colored_polygon(body_pts, fill_color)
	for i in range(body_pts.size()):
		draw_line(body_pts[i], body_pts[(i + 1) % body_pts.size()], draw_color, 1.5, true)

	# Electric stripe along spine
	var stripe_alpha: float = 0.4 + charge_glow * 0.5
	for i in range(segments - 1):
		var t: float = float(i) / float(segments - 1)
		var x1: float = lerpf(_body_length * 0.4, -_body_length * 0.4, t)
		var x2: float = lerpf(_body_length * 0.4, -_body_length * 0.4, t + 1.0 / (segments - 1))
		var wave1: float = sin(_time * 4.0 + t * PI * 2.0) * 2.0 * t
		var wave2: float = sin(_time * 4.0 + (t + 1.0 / (segments - 1)) * PI * 2.0) * 2.0 * (t + 1.0 / (segments - 1))
		draw_line(Vector2(x1, wave1), Vector2(x2, wave2), Color(_spark_color, stripe_alpha), 1.5, true)

	# Eyes
	_draw_eyes(draw_color)

	# Lightning arc visuals
	for arc in _lightning_arcs:
		_draw_lightning(arc.from, arc.to, arc.life)

	# Health ring
	if health_ratio < 1.0:
		draw_arc(Vector2.ZERO, _body_length * 0.5, 0, TAU * health_ratio, 24, Color(1.0, 0.3, 0.1, 0.5), 1.5, true)

	# Discharge warning ring
	if state == State.CHARGE:
		var warn_a: float = _charge_amount * 0.2 + 0.1 * sin(_time * 10.0)
		draw_arc(Vector2.ZERO, discharge_range * 0.3, 0, TAU, 24, Color(_spark_color, warn_a), 1.0, true)

func _draw_eyes(body_color: Color) -> void:
	var eye_x: float = _body_length * 0.3
	var eye_y: float = _body_width * 0.35
	var le := Vector2(eye_x, -eye_y)
	var re := Vector2(eye_x, eye_y)
	var eye_squash: float = 0.7 if not _is_blinking else 0.1

	for ep in [le, re]:
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			eye_pts.append(ep + Vector2(cos(a) * _eye_size, sin(a) * _eye_size * eye_squash))
		draw_colored_polygon(eye_pts, Color(0.85, 0.9, 0.95, 0.95))
		if not _is_blinking:
			# Electric blue iris
			draw_circle(ep, _eye_size * 0.5, Color(0.3, 0.5, 0.9, 1.0))
			draw_circle(ep, _eye_size * 0.2, Color(0.05, 0.05, 0.1, 1.0))
			# Spark highlight
			if _charge_amount > 0.5:
				draw_circle(ep + Vector2(-0.3, -0.3), _eye_size * 0.15, Color(_spark_color, _charge_amount))
			else:
				draw_circle(ep + Vector2(-0.3, -0.3), _eye_size * 0.12, Color(1, 1, 1, 0.6))

func _draw_lightning(from: Vector2, to: Vector2, life: float) -> void:
	# Jagged lightning bolt between two points
	var bolt_color := Color(_spark_color.r, _spark_color.g, _spark_color.b, life * 0.9)
	var points: int = 6
	var prev: Vector2 = from
	for i in range(1, points + 1):
		var t: float = float(i) / float(points)
		var pos: Vector2 = from.lerp(to, t)
		if i < points:
			var perp: Vector2 = (to - from).normalized().rotated(PI * 0.5)
			pos += perp * randf_range(-15.0, 15.0) * life
		draw_line(prev, pos, bolt_color, 2.0 * life, true)
		prev = pos
	# Glow at endpoints
	draw_circle(from, 3.0 * life, Color(_spark_color, life * 0.3))
	draw_circle(to, 3.0 * life, Color(_spark_color, life * 0.3))

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	AudioManager.play_hurt()
	if health <= 0:
		_die()

func _die() -> void:
	# Death discharge: small AoE zap
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and global_position.distance_to(p.global_position) < 60:
			if p.has_method("take_damage"):
				p.take_damage(stun_damage * 0.5)
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(4, 7), _spark_color)
	AudioManager.play_death()
	queue_free()

func confuse(duration: float) -> void:
	# Discharge immediately when confused (panic zap)
	if _charge_amount > 0.3:
		_fire_discharge()
	state = State.RECOVER
	_recover_timer = duration

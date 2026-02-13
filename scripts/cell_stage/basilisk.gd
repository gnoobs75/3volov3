extends CharacterBody2D
## Basilisk: Boss 3 (spawns after 9th evolution).
## Slow, armored front. Fires ranged projectiles (toxic spines).
## Vulnerable ONLY from behind — player must use jet spray, rear spikes,
## or mouth mutations to attack its exposed back.
## Front attacks are deflected. Turns slowly to face the player.

enum State { IDLE, PATROL, AIM, FIRE, TURN, WEAKENED, DYING }

var state: State = State.IDLE
var health: float = 150.0
var max_health: float = 150.0
var speed: float = 30.0  # Very slow
var damage: float = 15.0
var detection_range: float = 350.0
var fire_range: float = 250.0

var _time: float = 0.0
var _state_timer: float = 0.0
var _current_target: Node2D = null
var _damage_flash: float = 0.0
var _patrol_target: Vector2 = Vector2.ZERO
var _aim_timer: float = 0.0
var _fire_cooldown: float = 0.0
var _turn_speed: float = 1.2  # Radians per second — slow turner
var _voice_cooldown: float = 0.0

const FIRE_BURST_COUNT: int = 3
const FIRE_INTERVAL: float = 0.3
var _burst_remaining: int = 0
var _burst_timer: float = 0.0

# Rear vulnerability
const REAR_ARC: float = 1.2  # ~70 degrees from directly behind
var _rear_hit_flash: float = 0.0

# Body
var _body_radius: float = 35.0
var _base_color: Color
var _shield_color: Color
var _spine_color: Color

# Face
var _eye_size: float = 6.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false

# Shield visual
var _shield_integrity: float = 1.0  # Visual only, shows damage taken
var _active_spines: Array = []  # Managed projectiles

func _ready() -> void:
	_init_shape()
	_pick_patrol_target()
	add_to_group("enemies")
	add_to_group("bosses")
	_blink_timer = randf_range(3.0, 6.0)

func _init_shape() -> void:
	_body_radius = randf_range(32.0, 38.0)
	_eye_size = _body_radius * 0.16
	_base_color = Color(
		randf_range(0.3, 0.45),
		randf_range(0.15, 0.25),
		randf_range(0.4, 0.55),
		0.95
	)
	_shield_color = Color(
		randf_range(0.5, 0.65),
		randf_range(0.55, 0.7),
		randf_range(0.6, 0.75),
		0.9
	)
	_spine_color = Color(
		randf_range(0.7, 0.85),
		randf_range(0.3, 0.45),
		randf_range(0.5, 0.65),
		1.0
	)

func _physics_process(delta: float) -> void:
	_time += delta
	_damage_flash = maxf(_damage_flash - delta * 3.0, 0.0)
	_rear_hit_flash = maxf(_rear_hit_flash - delta * 4.0, 0.0)
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_voice_cooldown = maxf(_voice_cooldown - delta, 0.0)
	# Move active spine projectiles
	for i in range(_active_spines.size() - 1, -1, -1):
		var proj: Node2D = _active_spines[i]
		if not is_instance_valid(proj):
			_active_spines.remove_at(i)
			continue
		var v: Vector2 = proj.get_meta("velocity", Vector2.ZERO)
		proj.global_position += v * delta

	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(2.0, 5.0)
		else:
			_is_blinking = true
			_blink_timer = 0.12

	var player := _find_player()
	_current_target = player

	match state:
		State.IDLE:
			_do_idle(delta, player)
		State.PATROL:
			_do_patrol(delta)
		State.AIM:
			_do_aim(delta)
		State.FIRE:
			_do_fire(delta)
		State.TURN:
			_do_turn(delta)
		State.WEAKENED:
			_do_weakened(delta)
		State.DYING:
			_do_dying(delta)

	# Slow turn toward player
	if _current_target and is_instance_valid(_current_target) and state in [State.AIM, State.FIRE, State.TURN]:
		var to_player: Vector2 = (_current_target.global_position - global_position)
		var target_angle: float = to_player.angle()
		rotation = _rotate_toward(rotation, target_angle, _turn_speed * delta)

	# Shield integrity visual
	_shield_integrity = clampf(health / max_health, 0.0, 1.0)

	move_and_slide()
	queue_redraw()

func _rotate_toward(current: float, target: float, max_delta: float) -> float:
	var diff: float = wrapf(target - current, -PI, PI)
	if absf(diff) <= max_delta:
		return target
	return current + signf(diff) * max_delta

func _do_idle(delta: float, player: Node2D) -> void:
	velocity = velocity.lerp(Vector2.ZERO, delta * 2.0)
	if player and global_position.distance_to(player.global_position) < detection_range:
		state = State.AIM
		_aim_timer = 1.5
		if _voice_cooldown <= 0.0:
			AudioManager.play_creature_voice("basilisk", "alert", 1.3, 0.7, 1.0)
			_voice_cooldown = 3.0

func _do_patrol(delta: float) -> void:
	if global_position.distance_to(_patrol_target) < 40:
		_pick_patrol_target()
	velocity = velocity.lerp(global_position.direction_to(_patrol_target) * speed * 0.4, delta * 1.0)
	if velocity.length() > 5:
		rotation = lerp_angle(rotation, velocity.angle(), delta * 0.5)
	if _current_target and is_instance_valid(_current_target):
		if global_position.distance_to(_current_target.global_position) < detection_range:
			state = State.AIM
			_aim_timer = 1.5
			if _voice_cooldown <= 0.0:
				AudioManager.play_creature_voice("basilisk", "alert", 1.3, 0.7, 1.0)
				_voice_cooldown = 3.0

func _do_aim(delta: float) -> void:
	_aim_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)

	if not _current_target or not is_instance_valid(_current_target):
		state = State.PATROL
		return

	var dist: float = global_position.distance_to(_current_target.global_position)

	# Check if player is behind us — turn to face
	if _is_player_behind():
		state = State.TURN
		_state_timer = 2.0
		return

	if _aim_timer <= 0 and _fire_cooldown <= 0 and dist < fire_range:
		state = State.FIRE
		_burst_remaining = FIRE_BURST_COUNT
		_burst_timer = 0.0
	elif dist > detection_range * 1.3:
		state = State.PATROL

func _do_fire(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, delta * 4.0)
	_burst_timer -= delta
	if _burst_timer <= 0 and _burst_remaining > 0:
		_fire_spine()
		_burst_remaining -= 1
		_burst_timer = FIRE_INTERVAL
	if _burst_remaining <= 0 and _burst_timer <= 0:
		_fire_cooldown = 3.0
		state = State.AIM
		_aim_timer = 2.0

func _do_turn(delta: float) -> void:
	_state_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
	# After turning, go back to aiming
	if _state_timer <= 0 or not _is_player_behind():
		state = State.AIM
		_aim_timer = 1.0

func _do_weakened(delta: float) -> void:
	_state_timer -= delta
	velocity = velocity * 0.95
	if _state_timer <= 0:
		state = State.AIM
		_aim_timer = 1.0

func _do_dying(delta: float) -> void:
	_state_timer -= delta
	velocity = velocity * 0.9
	if _state_timer <= 0:
		_die()

func _is_player_behind() -> bool:
	if not _current_target or not is_instance_valid(_current_target):
		return false
	var to_player: Vector2 = (_current_target.global_position - global_position).normalized()
	var facing: Vector2 = Vector2.RIGHT.rotated(rotation)
	return to_player.dot(facing) < -cos(REAR_ARC)

func _fire_spine() -> void:
	if not _current_target or not is_instance_valid(_current_target):
		return
	AudioManager.play_toxin()
	var dir: Vector2 = (global_position.direction_to(_current_target.global_position))
	var spread: float = randf_range(-0.15, 0.15)
	dir = dir.rotated(spread)

	var proj := Area2D.new()
	proj.global_position = global_position + dir * (_body_radius + 5.0)
	proj.collision_layer = 0
	proj.collision_mask = 1
	proj.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	proj.add_child(shape)
	proj.set_meta("velocity", dir * 250.0)
	proj.set_meta("damage", damage)
	proj.set_meta("life", 3.0)
	proj.set_meta("time", 0.0)
	proj.set_meta("color", _spine_color)
	proj.add_to_group("basilisk_spines")
	proj.body_entered.connect(_on_spine_hit.bind(proj))
	# Auto-destroy
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(proj.queue_free)
	proj.add_child(timer)
	get_parent().add_child(proj)
	_active_spines.append(proj)

func _on_spine_hit(body: Node2D, proj: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(proj.get_meta("damage", 10.0))
	if is_instance_valid(proj):
		proj.queue_free()

func _pick_patrol_target() -> void:
	_patrol_target = global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))

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

	match state:
		State.AIM:
			draw_color = _base_color.lerp(Color(0.5, 0.2, 0.4), 0.2)
		State.FIRE:
			draw_color = _base_color.lerp(Color(0.7, 0.3, 0.4), 0.4)
		State.TURN:
			draw_color = _base_color.lerp(Color(0.5, 0.4, 0.3), 0.3)
		State.WEAKENED:
			draw_color = _base_color.lerp(Color(0.6, 0.5, 0.3), 0.4)

	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)

	# Glow
	draw_circle(Vector2.ZERO, _body_radius * 1.8, Color(draw_color.r, draw_color.g, draw_color.b, 0.06))

	# Rear vulnerability indicator (glowing weak spot)
	var rear_pos := Vector2(-_body_radius * 0.7, 0)
	var rear_glow_a: float = 0.15 + 0.1 * sin(_time * 4.0)
	if _rear_hit_flash > 0:
		rear_glow_a += _rear_hit_flash * 0.5
	draw_circle(rear_pos, _body_radius * 0.4, Color(1.0, 0.3, 0.2, rear_glow_a))

	# Main body
	var pts: PackedVector2Array = PackedVector2Array()
	var num_pts: int = 28
	for i in range(num_pts):
		var angle: float = TAU * i / num_pts
		var r: float = _body_radius
		# Bulkier front, narrower rear
		if cos(angle) > 0:
			r *= 1.1
		else:
			r *= 0.85
		r += sin(angle * 3.0 + _time * 1.0) * 2.0
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))

	draw_colored_polygon(pts, Color(draw_color.r * 0.3, draw_color.g * 0.25, draw_color.b * 0.35, 0.85))
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(draw_color, 0.8), 2.0, true)

	# Front shield (armored plates)
	_draw_shield(draw_color)

	# Rear weak spot (exposed, pulsing)
	var weak_pts: PackedVector2Array = PackedVector2Array()
	for i in range(8):
		var a: float = TAU * i / 8.0
		weak_pts.append(rear_pos + Vector2(cos(a) * _body_radius * 0.25, sin(a) * _body_radius * 0.25))
	draw_colored_polygon(weak_pts, Color(0.7, 0.2, 0.2, 0.5 + 0.2 * sin(_time * 5.0)))
	# Pulsing veins on weak spot
	for v in range(4):
		var va: float = TAU * v / 4.0 + _time * 0.5
		var vstart := rear_pos
		var vend := rear_pos + Vector2(cos(va) * _body_radius * 0.3, sin(va) * _body_radius * 0.3)
		draw_line(vstart, vend, Color(0.8, 0.2, 0.15, 0.4), 1.5, true)

	# Spine launchers on sides
	for side in [-1, 1]:
		var launcher_pos := Vector2(_body_radius * 0.3, side * _body_radius * 0.7)
		for s in range(3):
			var spine_a: float = atan2(side, 1.0) + (s - 1) * 0.3
			var spine_base := launcher_pos
			var spine_tip := spine_base + Vector2(cos(spine_a) * 12.0, sin(spine_a) * 12.0)
			draw_line(spine_base, spine_tip, Color(_spine_color, 0.8), 2.0, true)
			draw_circle(spine_tip, 1.5, Color(_spine_color, 0.6))

	# Face
	_draw_face()

	# Health bar
	if health_ratio < 1.0:
		var bar_w: float = _body_radius * 1.5
		var bar_y: float = -_body_radius - 12.0
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, 5), Color(0.2, 0.15, 0.2, 0.5))
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * health_ratio, 5), Color(0.6, 0.2, 0.4, 0.8))

	# Aim laser when aiming
	if state == State.AIM and _current_target and is_instance_valid(_current_target):
		var to_target: Vector2 = (_current_target.global_position - global_position)
		var aim_len: float = minf(to_target.length(), fire_range) * 0.5
		var aim_dir: Vector2 = to_target.normalized()
		# Convert to local space
		var local_dir: Vector2 = aim_dir.rotated(-rotation)
		var aim_alpha: float = 0.1 + 0.1 * sin(_time * 8.0)
		draw_line(Vector2(_body_radius, 0), Vector2(_body_radius, 0) + local_dir * aim_len, Color(_spine_color.r, _spine_color.g, _spine_color.b, aim_alpha), 1.5, true)

	# Dying flash
	if state == State.DYING:
		var die_t: float = 1.0 - _state_timer / 2.0
		draw_circle(Vector2.ZERO, _body_radius * (1.0 + die_t * 0.2), Color(0.7, 0.2, 0.4, die_t * 0.4))

func _draw_shield(color: Color) -> void:
	# Front armor arc
	var shield_r: float = _body_radius * 1.05
	var shield_arc: float = PI * 0.7  # Front 126 degrees
	var shield_pts: PackedVector2Array = PackedVector2Array()
	var num_shield: int = 12
	for i in range(num_shield):
		var t: float = float(i) / float(num_shield - 1)
		var a: float = -shield_arc * 0.5 + shield_arc * t
		shield_pts.append(Vector2(cos(a) * shield_r, sin(a) * shield_r))
	# Inner arc (reverse)
	for i in range(num_shield - 1, -1, -1):
		var t: float = float(i) / float(num_shield - 1)
		var a: float = -shield_arc * 0.5 + shield_arc * t
		shield_pts.append(Vector2(cos(a) * (shield_r - 6.0), sin(a) * (shield_r - 6.0)))

	var shield_alpha: float = _shield_integrity * 0.7
	draw_colored_polygon(shield_pts, Color(_shield_color.r * 0.5, _shield_color.g * 0.5, _shield_color.b * 0.6, shield_alpha))
	# Shield outline
	for i in range(num_shield - 1):
		var t: float = float(i) / float(num_shield - 1)
		var a: float = -shield_arc * 0.5 + shield_arc * t
		var t2: float = float(i + 1) / float(num_shield - 1)
		var a2: float = -shield_arc * 0.5 + shield_arc * t2
		draw_line(
			Vector2(cos(a) * shield_r, sin(a) * shield_r),
			Vector2(cos(a2) * shield_r, sin(a2) * shield_r),
			Color(_shield_color, 0.8), 2.0, true
		)

func _draw_face() -> void:
	# Single large eye (cyclops-like)
	var ep := Vector2(_body_radius * 0.35, 0)
	var eye_squash: float = 0.7 if not _is_blinking else 0.08

	# Eye socket
	draw_circle(ep + Vector2(1.5, 1.5), _eye_size * 1.2, Color(0.1, 0.08, 0.15, 0.4))

	var eye_pts: PackedVector2Array = PackedVector2Array()
	for i in range(14):
		var a: float = TAU * i / 14.0
		eye_pts.append(ep + Vector2(cos(a) * _eye_size, sin(a) * _eye_size * eye_squash))
	draw_colored_polygon(eye_pts, Color(0.9, 0.85, 0.8, 0.95))

	if eye_squash > 0.2:
		# Purple iris
		var iris_r: float = _eye_size * 0.6
		draw_circle(ep, iris_r, Color(0.4, 0.15, 0.5, 1.0))
		# Vertical slit pupil
		var pupil_w: float = _eye_size * 0.15
		var pupil_h: float = _eye_size * 0.45 * eye_squash
		var pupil_pts: PackedVector2Array = PackedVector2Array([
			ep + Vector2(-pupil_w, 0),
			ep + Vector2(0, -pupil_h),
			ep + Vector2(pupil_w, 0),
			ep + Vector2(0, pupil_h),
		])
		draw_colored_polygon(pupil_pts, Color(0.02, 0.02, 0.02, 1.0))
		# Highlight
		draw_circle(ep + Vector2(-_eye_size * 0.2, -_eye_size * 0.2), _eye_size * 0.12, Color(1, 1, 1, 0.7))

	# Eye outline
	for i in range(eye_pts.size()):
		draw_line(eye_pts[i], eye_pts[(i + 1) % eye_pts.size()], Color(0.2, 0.1, 0.2, 0.7), 1.5, true)

func take_damage(amount: float, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	# Check if damage is from behind
	var from_behind: bool = false
	if attacker_pos != Vector2.ZERO:
		var to_attacker: Vector2 = (attacker_pos - global_position).normalized()
		var facing: Vector2 = Vector2.RIGHT.rotated(rotation)
		from_behind = to_attacker.dot(facing) < -cos(REAR_ARC)

	if from_behind:
		# Vulnerable! Take full damage
		health -= amount
		_damage_flash = 1.0
		_rear_hit_flash = 1.0
		AudioManager.play_hurt()
		if _voice_cooldown <= 0.0:
			AudioManager.play_creature_voice("basilisk", "hurt", 1.3, 0.7, 1.0)
			_voice_cooldown = 2.5
		state = State.WEAKENED
		_state_timer = 1.5
	else:
		# Front/side: deflect
		_damage_flash = 0.3
		# Deflection spark visual handled by draw

	if health <= 0:
		state = State.DYING
		_state_timer = 2.0

func take_damage_from_behind(amount: float) -> void:
	## Convenience for jet/rear attacks that know they're from behind
	health -= amount
	_damage_flash = 1.0
	_rear_hit_flash = 1.0
	AudioManager.play_hurt()
	if _voice_cooldown <= 0.0:
		AudioManager.play_creature_voice("basilisk", "hurt", 1.3, 0.7, 1.0)
		_voice_cooldown = 2.5
	state = State.WEAKENED
	_state_timer = 1.5
	if health <= 0:
		state = State.DYING
		_state_timer = 2.0

func _die() -> void:
	AudioManager.play_creature_voice("basilisk", "death", 1.3, 0.7, 1.0)
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(15, 22), _spine_color)
	if manager and manager.has_method("_on_boss_defeated"):
		manager._on_boss_defeated("basilisk")
	AudioManager.play_death()
	queue_free()

func confuse(_duration: float) -> void:
	# Boss resists confusion — turns slightly slower for a moment
	_turn_speed = 0.6
	# Reset after a bit
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(func(): _turn_speed = 1.2)
	add_child(timer)

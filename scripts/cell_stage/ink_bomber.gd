extends CharacterBody2D
## Ink Bomber: rotund defensive creature that deploys ink clouds when threatened.
## Ink clouds obscure vision (darken screen edges) and slow creatures inside them.
## Flees after deploying ink. Comical panicked expression.

enum State { DRIFT, ALARMED, INK, FLEE, CONFUSED }

var state: State = State.DRIFT
var health: float = 30.0
var max_health: float = 30.0
var speed: float = 60.0
var damage: float = 3.0  # Minimal contact damage
var detection_range: float = 150.0
var ink_range: float = 80.0  # Radius of ink cloud
var ink_slow: float = 0.5  # Speed multiplier inside ink

var _time: float = 0.0
var _drift_target: Vector2 = Vector2.ZERO
var _drift_timer: float = 0.0
var _alarmed_timer: float = 0.0
var _ink_timer: float = 0.0
var _ink_cooldown: float = 0.0
var _confused_timer: float = 0.0
var _current_target: Node2D = null
var _voice_cooldown: float = 0.0

const INK_CLOUD_DURATION: float = 6.0

# Procedural graphics
var _body_radius: float = 14.0
var _base_color: Color
var _damage_flash: float = 0.0
var _inflate: float = 0.0  # Puffs up when alarmed

# Face
var _eye_size: float = 4.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _panic_level: float = 0.0

# Ink clouds spawned (visual references for drawing)
var _ink_clouds: Array = []  # [{pos, life, radius}]

func _ready() -> void:
	_init_shape()
	_pick_drift_target()
	add_to_group("enemies")
	_blink_timer = randf_range(2.0, 5.0)

func _init_shape() -> void:
	_body_radius = randf_range(12.0, 16.0)
	_eye_size = _body_radius * 0.28
	_base_color = Color(
		randf_range(0.2, 0.35),
		randf_range(0.15, 0.25),
		randf_range(0.3, 0.45),
		0.95
	)

func _physics_process(delta: float) -> void:
	_time += delta
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
	_ink_cooldown = maxf(_ink_cooldown - delta, 0.0)
	_voice_cooldown = maxf(_voice_cooldown - delta, 0.0)

	if _confused_timer > 0:
		_confused_timer -= delta
		if _confused_timer <= 0:
			state = State.DRIFT

	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(1.5, 3.0)
		else:
			_is_blinking = true
			_blink_timer = 0.1

	var player := _find_player()
	_current_target = player

	if state != State.CONFUSED:
		match state:
			State.DRIFT:
				_do_drift(delta)
				if player and global_position.distance_to(player.global_position) < detection_range:
					state = State.ALARMED
					_alarmed_timer = 0.6
					if _voice_cooldown <= 0.0:
						AudioManager.play_creature_voice("ink_bomber", "alert", 1.0, 0.4, 0.8)
						_voice_cooldown = 3.0
			State.ALARMED:
				_do_alarmed(delta)
			State.INK:
				_do_ink(delta)
			State.FLEE:
				_do_flee(delta)
	else:
		_do_confused(delta)

	# Inflate animation
	if state == State.ALARMED:
		_inflate = minf(_inflate + delta * 3.0, 1.0)
		_panic_level = minf(_panic_level + delta * 3.0, 1.0)
	elif state == State.INK:
		_inflate = maxf(_inflate - delta * 5.0, 0.0)
	else:
		_inflate = maxf(_inflate - delta * 2.0, 0.0)
		_panic_level = maxf(_panic_level - delta * 1.0, 0.0)

	# Update ink clouds
	_update_ink_clouds(delta)

	move_and_slide()
	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _do_drift(delta: float) -> void:
	_drift_timer -= delta
	if _drift_timer <= 0 or global_position.distance_to(_drift_target) < 30:
		_pick_drift_target()
	velocity = velocity.lerp(global_position.direction_to(_drift_target) * speed * 0.3, delta * 2.0)

func _do_alarmed(delta: float) -> void:
	_alarmed_timer -= delta
	# Freeze in place, puffing up
	velocity = velocity * 0.9

	if _alarmed_timer <= 0 and _ink_cooldown <= 0:
		state = State.INK
		_ink_timer = 0.3
		_deploy_ink()

func _do_ink(delta: float) -> void:
	_ink_timer -= delta
	velocity = velocity * 0.8
	if _ink_timer <= 0:
		state = State.FLEE
		_ink_cooldown = 8.0

func _do_flee(delta: float) -> void:
	if _current_target and is_instance_valid(_current_target):
		var flee_dir: Vector2 = (_current_target.global_position.direction_to(global_position))
		velocity = velocity.lerp(flee_dir * speed * 1.5, delta * 3.0)
		if global_position.distance_to(_current_target.global_position) > detection_range * 1.5:
			state = State.DRIFT
			_pick_drift_target()
	else:
		state = State.DRIFT

func _do_confused(delta: float) -> void:
	_drift_timer -= delta
	if _drift_timer <= 0:
		_drift_target = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		_drift_timer = randf_range(0.3, 0.6)
	velocity = velocity.lerp(global_position.direction_to(_drift_target) * speed * 0.2, delta * 3.0)

func _deploy_ink() -> void:
	AudioManager.play_jet()
	# Spawn ink cloud at current position
	_ink_clouds.append({
		"pos": global_position,
		"life": INK_CLOUD_DURATION,
		"radius": ink_range,
	})
	# Also spawn an Area2D to slow things
	var ink_area := Area2D.new()
	ink_area.global_position = global_position
	ink_area.collision_layer = 0
	ink_area.collision_mask = 1 | 2  # Player and enemies
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ink_range
	shape.shape = circle
	ink_area.add_child(shape)
	ink_area.set_meta("ink_slow", ink_slow)
	ink_area.set_meta("ink_life", INK_CLOUD_DURATION)
	ink_area.add_to_group("ink_clouds")
	get_parent().add_child(ink_area)
	# Auto-destroy
	var timer := Timer.new()
	timer.wait_time = INK_CLOUD_DURATION
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(ink_area.queue_free)
	ink_area.add_child(timer)

func _update_ink_clouds(delta: float) -> void:
	var alive: Array = []
	for cloud in _ink_clouds:
		cloud.life -= delta
		if cloud.life > 0:
			alive.append(cloud)
			# Slow creatures inside cloud
			_apply_ink_slow(cloud, delta)
	_ink_clouds = alive

func _apply_ink_slow(cloud: Dictionary, delta: float) -> void:
	var pos: Vector2 = cloud.pos
	var r: float = cloud.radius
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and pos.distance_to(p.global_position) < r:
			if p is CharacterBody2D:
				p.velocity *= (1.0 - (1.0 - ink_slow) * delta * 2.0)

func _pick_drift_target() -> void:
	_drift_target = global_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
	_drift_timer = randf_range(3.0, 6.0)

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
		State.ALARMED:
			draw_color = _base_color.lerp(Color(0.7, 0.3, 0.4), _panic_level * 0.4)
		State.INK:
			draw_color = _base_color.lerp(Color(0.1, 0.1, 0.15), 0.5)
		State.FLEE:
			draw_color = _base_color.lerp(Color(0.6, 0.5, 0.3), 0.3)

	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)

	# Draw ink clouds (in world space relative to us)
	for cloud in _ink_clouds:
		var local_pos: Vector2 = cloud.pos - global_position
		var alpha: float = clampf(cloud.life / INK_CLOUD_DURATION, 0.0, 1.0) * 0.4
		# Multiple overlapping circles for cloudy look
		for c in range(5):
			var offset := Vector2(
				sin(_time * 0.5 + c * 1.3) * cloud.radius * 0.3,
				cos(_time * 0.4 + c * 0.9) * cloud.radius * 0.3
			)
			var cr: float = cloud.radius * (0.5 + c * 0.12)
			draw_circle(local_pos + offset, cr, Color(0.05, 0.03, 0.08, alpha * (1.0 - c * 0.15)))

	# Body glow
	var effective_radius: float = _body_radius * (1.0 + _inflate * 0.4)
	draw_circle(Vector2.ZERO, effective_radius * 1.5, Color(draw_color.r, draw_color.g, draw_color.b, 0.06))

	# Body - round, pufferfish-like
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(20):
		var angle: float = TAU * i / 20.0
		var r: float = effective_radius
		r += sin(angle * 4.0 + _time * 2.0) * 1.5
		# Bumpy when inflated
		if _inflate > 0.3:
			r += sin(angle * 8.0) * _inflate * 2.0
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))

	draw_colored_polygon(pts, Color(draw_color.r * 0.3, draw_color.g * 0.25, draw_color.b * 0.35, 0.8))
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(draw_color, 0.85), 1.3, true)

	# Ink sac (dark spot on belly)
	var sac_r: float = effective_radius * 0.3
	var sac_alpha: float = 0.6 if _ink_cooldown <= 0 else 0.2
	draw_circle(Vector2(-effective_radius * 0.2, 0), sac_r, Color(0.08, 0.05, 0.12, sac_alpha))

	# Face - panicked expression
	_draw_face(effective_radius, draw_color)

	# Health ring
	if health_ratio < 1.0:
		draw_arc(Vector2.ZERO, effective_radius + 2.0, 0, TAU * health_ratio, 24, Color(0.4, 0.3, 0.6, 0.5), 1.5, true)

	# Alarmed exclamation
	if state == State.ALARMED:
		var warn_y: float = -effective_radius - 8.0
		var warn_alpha: float = 0.5 + 0.4 * sin(_time * 12.0)
		draw_line(Vector2(0, warn_y), Vector2(0, warn_y + 5), Color(1.0, 0.5, 0.2, warn_alpha), 2.5, true)
		draw_circle(Vector2(0, warn_y + 7), 1.0, Color(1.0, 0.5, 0.2, warn_alpha))

	# Confused stars
	if state == State.CONFUSED:
		for s in range(3):
			var sa: float = _time * 4.0 + TAU * s / 3.0
			var star_pos := Vector2(-effective_radius - 3.0, 0) + Vector2(cos(sa) * 5.0, sin(sa) * 5.0)
			draw_circle(star_pos, 1.5, Color(1.0, 1.0, 0.3, 0.5))

func _draw_face(r: float, color: Color) -> void:
	var eye_x: float = r * 0.15
	var eye_y: float = r * 0.25
	var le := Vector2(eye_x, -eye_y)
	var re := Vector2(eye_x, eye_y)
	var eye_squash: float = 0.85 if not _is_blinking else 0.08
	var er: float = _eye_size * (1.0 + _panic_level * 0.4)  # Bigger eyes when panicked

	for idx in range(2):
		var ep: Vector2 = le if idx == 0 else re
		# Panic: jittering eyes
		if _panic_level > 0.3:
			ep += Vector2(sin(_time * 20.0 + idx) * _panic_level, cos(_time * 18.0 + idx) * _panic_level) * 0.5
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			eye_pts.append(ep + Vector2(cos(a) * er, sin(a) * er * eye_squash))
		draw_colored_polygon(eye_pts, Color(0.95, 0.95, 0.95, 0.95))
		if not _is_blinking:
			# Tiny panicked pupils
			var pupil_r: float = er * (0.4 - _panic_level * 0.15)
			draw_circle(ep, pupil_r, Color(0.1, 0.08, 0.15, 1.0))
			draw_circle(ep + Vector2(-0.3, -0.3), pupil_r * 0.3, Color(1, 1, 1, 0.6))

	# Eyebrows - worried/panicked arch
	var brow_panic: float = _panic_level * 0.6
	draw_line(le + Vector2(-er, -er * (0.4 + brow_panic)), le + Vector2(er, -er * 0.7), Color(0.2, 0.15, 0.25, 0.8), 1.5, true)
	draw_line(re + Vector2(-er, -er * 0.7), re + Vector2(er, -er * (0.4 + brow_panic)), Color(0.2, 0.15, 0.25, 0.8), 1.5, true)

	# Mouth - O-shaped panic mouth
	var mp := Vector2(r * 0.35, 0)
	if _panic_level > 0.3:
		var mo_size: float = 2.0 + _panic_level * 2.0
		var mo_pts: PackedVector2Array = PackedVector2Array()
		for i in range(8):
			var a: float = TAU * i / 8.0
			mo_pts.append(mp + Vector2(cos(a) * mo_size * 0.5, sin(a) * mo_size))
		draw_colored_polygon(mo_pts, Color(0.1, 0.06, 0.12, 0.9))
	else:
		# Neutral worried line
		draw_line(mp + Vector2(0, -2), mp + Vector2(1, 0), Color(0.15, 0.1, 0.2, 0.8), 1.5, true)
		draw_line(mp + Vector2(1, 0), mp + Vector2(0, 2), Color(0.15, 0.1, 0.2, 0.8), 1.5, true)

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	_panic_level = 1.0
	AudioManager.play_hurt()
	if _voice_cooldown <= 0.0:
		AudioManager.play_creature_voice("ink_bomber", "hurt", 1.0, 0.4, 0.8)
		_voice_cooldown = 2.5
	# Panic-ink when hit (if available)
	if _ink_cooldown <= 0 and state != State.INK:
		state = State.ALARMED
		_alarmed_timer = 0.2  # Quick reaction
	if health <= 0:
		_die()

func _die() -> void:
	AudioManager.play_creature_voice("ink_bomber", "death", 1.0, 0.4, 0.8)
	# Death ink burst
	if _ink_cooldown <= 0:
		_deploy_ink()
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(2, 4), _base_color)
	AudioManager.play_death()
	queue_free()

func confuse(duration: float) -> void:
	state = State.CONFUSED
	_confused_timer = duration

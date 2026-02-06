extends CharacterBody2D
## Leviathan - Massive, slow-moving apex predator.
## Very high health, devastating damage, but slow and telegraphed attacks.
## Creates shockwaves and has a vacuum inhale attack.

enum State { DRIFT, APPROACH, INHALE, CHOMP, STUN, RETREAT }

var state: State = State.DRIFT
var health: float = 200.0
var max_health: float = 200.0
var speed: float = 35.0  # Very slow
var chomp_damage: float = 40.0
var vacuum_strength: float = 150.0
var detection_range: float = 400.0
var attack_range: float = 120.0
var chomp_range: float = 50.0

# Timers
var _time: float = 0.0
var _drift_timer: float = 0.0
var _approach_timer: float = 0.0
var _inhale_timer: float = 0.0
var _chomp_timer: float = 0.0
var _stun_timer: float = 0.0
var _attack_cooldown: float = 0.0

# Movement
var _drift_target: Vector2 = Vector2.ZERO
var _current_target: Node2D = null

# Procedural graphics
var _body_radius: float = 45.0
var _base_color: Color
var _belly_color: Color
var _damage_flash: float = 0.0
var _jaw_open: float = 0.0  # 0-1 jaw animation

# Tentacles/appendages
var _tentacle_phases: Array[float] = []
const NUM_TENTACLES: int = 6

# Eye
var _eye_size: float = 12.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _pupil_dilation: float = 1.0

# Inhale vacuum effect
var _vacuum_particles: Array = []

func _ready() -> void:
	_init_shape()
	_pick_drift_target()
	add_to_group("enemies")
	add_to_group("leviathans")
	_blink_timer = randf_range(3.0, 6.0)

	# Initialize tentacle phases
	for i in range(NUM_TENTACLES):
		_tentacle_phases.append(randf() * TAU)

func _init_shape() -> void:
	_body_radius = randf_range(40.0, 50.0)
	_eye_size = _body_radius * randf_range(0.22, 0.28)

	# Deep sea monster colors
	_base_color = Color(
		randf_range(0.1, 0.2),
		randf_range(0.15, 0.25),
		randf_range(0.25, 0.4),
		0.95
	)
	_belly_color = Color(
		_base_color.r * 1.5,
		_base_color.g * 1.3,
		_base_color.b * 0.9,
		0.8
	)

func _physics_process(delta: float) -> void:
	_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_damage_flash = maxf(_damage_flash - delta * 3.0, 0.0)

	# Blink timer
	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(4.0, 8.0)
		else:
			_is_blinking = true
			_blink_timer = 0.15

	# Find targets
	var player := _find_player()
	var best_target: Node2D = null
	var best_dist: float = detection_range

	if player:
		var d: float = global_position.distance_to(player.global_position)
		if d < best_dist:
			best_dist = d
			best_target = player

	# Also hunt other creatures
	for prey in get_tree().get_nodes_in_group("prey"):
		var d: float = global_position.distance_to(prey.global_position)
		if d < best_dist * 0.7:  # Prefers closer prey
			best_dist = d
			best_target = prey

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self:
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < best_dist * 0.5:  # Really close enemies become prey
			best_dist = d
			best_target = enemy

	_current_target = best_target

	# State machine
	match state:
		State.DRIFT:
			_do_drift(delta)
			if _current_target and best_dist < detection_range:
				state = State.APPROACH
				_approach_timer = 0.0
		State.APPROACH:
			_do_approach(delta)
		State.INHALE:
			_do_inhale(delta)
		State.CHOMP:
			_do_chomp(delta)
		State.STUN:
			_do_stun(delta)
		State.RETREAT:
			_do_retreat(delta)

	# Jaw animation
	if state == State.CHOMP:
		_jaw_open = minf(_jaw_open + delta * 8.0, 1.0)
	elif state == State.INHALE:
		_jaw_open = lerpf(_jaw_open, 0.6, delta * 4.0)
	else:
		_jaw_open = maxf(_jaw_open - delta * 3.0, 0.0)

	# Pupil dilation
	match state:
		State.APPROACH, State.INHALE:
			_pupil_dilation = lerpf(_pupil_dilation, 0.6, delta * 3.0)
		State.CHOMP:
			_pupil_dilation = lerpf(_pupil_dilation, 0.3, delta * 5.0)
		_:
			_pupil_dilation = lerpf(_pupil_dilation, 1.0, delta * 2.0)

	# Update vacuum particles
	_update_vacuum_particles(delta)

	move_and_slide()
	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _do_drift(delta: float) -> void:
	_drift_timer -= delta
	if _drift_timer <= 0 or global_position.distance_to(_drift_target) < 50:
		_pick_drift_target()

	# Very slow, majestic movement
	var dir: Vector2 = global_position.direction_to(_drift_target)
	velocity = velocity.lerp(dir * speed * 0.3, delta * 0.5)

	# Gentle rotation toward movement
	if velocity.length() > 5:
		var target_angle: float = velocity.angle()
		rotation = lerp_angle(rotation, target_angle, delta * 0.3)

func _do_approach(delta: float) -> void:
	if not _current_target or not is_instance_valid(_current_target):
		state = State.DRIFT
		return

	_approach_timer += delta

	var to_target: Vector2 = _current_target.global_position - global_position
	var dist: float = to_target.length()

	# Slow, deliberate approach
	velocity = velocity.lerp(to_target.normalized() * speed, delta * 0.8)

	# Face target
	var target_angle: float = to_target.angle()
	rotation = lerp_angle(rotation, target_angle, delta * 1.0)

	# Start inhale attack when in range
	if dist < attack_range and _attack_cooldown <= 0:
		state = State.INHALE
		_inhale_timer = 1.5  # Wind-up time
		AudioManager.play_inhale() if AudioManager.has_method("play_inhale") else null

	# Give up if target too far
	if dist > detection_range * 1.3:
		state = State.DRIFT

func _do_inhale(delta: float) -> void:
	_inhale_timer -= delta

	# Slow down during inhale
	velocity = velocity * 0.9

	# Create vacuum effect pulling things toward mouth
	if _current_target and is_instance_valid(_current_target):
		var to_target: Vector2 = _current_target.global_position - global_position
		var dist: float = to_target.length()

		# Pull target toward us
		if dist < attack_range * 1.5:
			var pull_strength: float = vacuum_strength * (1.0 - dist / (attack_range * 1.5))
			var pull_dir: Vector2 = -to_target.normalized()

			# Apply force to target
			if _current_target is CharacterBody2D:
				_current_target.velocity += pull_dir * pull_strength * delta * 60.0

			# Spawn vacuum particles
			_spawn_vacuum_particles()

	# Chomp when ready
	if _inhale_timer <= 0:
		state = State.CHOMP
		_chomp_timer = 0.3
		AudioManager.play_toxin()

func _do_chomp(delta: float) -> void:
	_chomp_timer -= delta

	# Lunge forward slightly
	velocity = Vector2.RIGHT.rotated(rotation) * speed * 3.0

	# Check for hit
	if _current_target and is_instance_valid(_current_target):
		var dist: float = global_position.distance_to(_current_target.global_position)
		if dist < chomp_range:
			if _current_target.has_method("take_damage"):
				_current_target.take_damage(chomp_damage)
			_attack_cooldown = 4.0  # Long cooldown
			state = State.RETREAT
			return

	if _chomp_timer <= 0:
		_attack_cooldown = 3.0
		state = State.RETREAT

func _do_stun(delta: float) -> void:
	_stun_timer -= delta
	velocity = velocity * 0.95

	if _stun_timer <= 0:
		state = State.RETREAT

func _do_retreat(delta: float) -> void:
	# Back away slowly
	if _current_target and is_instance_valid(_current_target):
		var away: Vector2 = (global_position - _current_target.global_position).normalized()
		velocity = velocity.lerp(away * speed * 0.5, delta * 0.5)
	else:
		velocity = velocity * 0.95

	# Return to drift after moving away
	if velocity.length() < 10 or \
	   (_current_target and global_position.distance_to(_current_target.global_position) > attack_range * 2):
		state = State.DRIFT
		_pick_drift_target()

func _spawn_vacuum_particles() -> void:
	# Spawn particles being sucked toward mouth
	if randf() > 0.7:
		return

	var mouth_pos: Vector2 = global_position + Vector2(_body_radius * 0.8, 0).rotated(rotation)
	var spawn_angle: float = rotation + randf_range(-0.8, 0.8)
	var spawn_dist: float = randf_range(attack_range * 0.5, attack_range * 1.2)
	var spawn_pos: Vector2 = mouth_pos + Vector2(spawn_dist, 0).rotated(spawn_angle)

	_vacuum_particles.append({
		"pos": spawn_pos,
		"target": mouth_pos,
		"life": 1.0,
		"size": randf_range(2.0, 4.0),
		"color": Color(0.4, 0.6, 0.8, 0.6),
	})

func _update_vacuum_particles(delta: float) -> void:
	var alive: Array = []
	var mouth_pos: Vector2 = global_position + Vector2(_body_radius * 0.8, 0).rotated(rotation)

	for p in _vacuum_particles:
		p.life -= delta * 1.5
		# Accelerate toward mouth
		var to_mouth: Vector2 = (mouth_pos - p.pos).normalized()
		p.pos += to_mouth * (2.0 - p.life) * 200.0 * delta

		if p.life > 0 and p.pos.distance_to(mouth_pos) > 5:
			alive.append(p)

	_vacuum_particles = alive

func _pick_drift_target() -> void:
	_drift_target = global_position + Vector2(randf_range(-300, 300), randf_range(-300, 300))
	_drift_timer = randf_range(5.0, 10.0)

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]

func _draw() -> void:
	var health_ratio: float = health / max_health

	# State-based color
	var draw_color: Color = _base_color
	match state:
		State.APPROACH:
			draw_color = _base_color.lerp(Color(0.4, 0.2, 0.3), 0.3)
		State.INHALE:
			var pulse: float = 0.5 + 0.5 * sin(_time * 10.0)
			draw_color = _base_color.lerp(Color(0.5, 0.3, 0.5), pulse * 0.4)
		State.CHOMP:
			draw_color = _base_color.lerp(Color(0.6, 0.2, 0.2), 0.5)
		State.STUN:
			draw_color = _base_color.lerp(Color(0.5, 0.5, 0.3), 0.4)

	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)

	# Outer glow - ominous
	var glow_alpha: float = 0.05 + 0.03 * sin(_time * 2.0)
	draw_circle(Vector2.ZERO, _body_radius * 2.0, Color(draw_color.r, draw_color.g, draw_color.b, glow_alpha))
	draw_circle(Vector2.ZERO, _body_radius * 1.5, Color(draw_color.r, draw_color.g, draw_color.b, glow_alpha * 2))

	# Tentacles (drawn behind body)
	_draw_tentacles(draw_color)

	# Main body - massive blob with texture
	var body_pts: PackedVector2Array = PackedVector2Array()
	var num_pts: int = 32
	for i in range(num_pts):
		var angle: float = TAU * float(i) / float(num_pts)
		var r: float = _body_radius
		# Organic bumpy shape
		r += sin(angle * 5.0 + _time * 0.5) * 3.0
		r += cos(angle * 3.0 - _time * 0.3) * 4.0
		# Jaw opens at front
		if angle > -0.5 and angle < 0.5:
			r -= _jaw_open * 8.0
		body_pts.append(Vector2(cos(angle) * r, sin(angle) * r))

	# Body fill with gradient effect
	var fill_color := Color(draw_color.r * 0.35, draw_color.g * 0.3, draw_color.b * 0.4, 0.9)
	draw_colored_polygon(body_pts, fill_color)

	# Body outline - thick
	for i in range(body_pts.size()):
		draw_line(body_pts[i], body_pts[(i + 1) % body_pts.size()], draw_color, 3.0, true)

	# Inner texture/organelles
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0 + _time * 0.1
		var dist: float = _body_radius * 0.5 + sin(_time + i) * 5.0
		var pos := Vector2(cos(angle) * dist, sin(angle) * dist)
		var org_size: float = 4.0 + sin(_time * 1.5 + i) * 1.5
		draw_circle(pos, org_size, Color(0.2, 0.3, 0.4, 0.3))

	# Belly highlight
	var belly_pos := Vector2(-_body_radius * 0.2, 0)
	draw_circle(belly_pos, _body_radius * 0.4, _belly_color)

	# Jaw / mouth
	_draw_mouth(draw_color)

	# Main eye
	_draw_eye(draw_color)

	# Vacuum particles
	for p in _vacuum_particles:
		var p_local: Vector2 = p.pos - global_position
		p_local = p_local.rotated(-rotation)
		var alpha: float = p.life * 0.7
		draw_circle(p_local, p.size, Color(p.color.r, p.color.g, p.color.b, alpha))

	# Health bar (large creature, show it)
	if health_ratio < 1.0:
		var bar_width: float = _body_radius * 1.5
		var bar_y: float = -_body_radius - 15.0
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 5), Color(0.2, 0.2, 0.2, 0.5))
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * health_ratio, 5), Color(0.8, 0.2, 0.2, 0.8))

	# Inhale indicator
	if state == State.INHALE:
		var warn_alpha: float = 0.3 + 0.3 * sin(_time * 12.0)
		draw_arc(Vector2.ZERO, _body_radius + 10, -0.3, 0.3, 8, Color(0.8, 0.4, 0.5, warn_alpha), 3.0, true)

func _draw_tentacles(body_color: Color) -> void:
	for i in range(NUM_TENTACLES):
		var base_angle: float = PI + (float(i) / NUM_TENTACLES - 0.5) * PI * 0.8
		var base := Vector2(cos(base_angle), sin(base_angle)) * _body_radius * 0.9

		var segments: int = 10
		var prev: Vector2 = base
		for s in range(segments):
			var t: float = float(s + 1) / float(segments)
			var wave: float = sin(_time * 2.0 + _tentacle_phases[i] + t * 3.0) * 12.0 * t
			var length: float = 35.0 + sin(_tentacle_phases[i]) * 10.0
			var seg_angle: float = base_angle + wave * 0.02
			var next: Vector2 = base + Vector2(cos(seg_angle), sin(seg_angle)) * t * length
			next += Vector2(-sin(seg_angle), cos(seg_angle)) * wave

			var width: float = 4.0 * (1.0 - t * 0.7)
			var alpha: float = 0.7 - t * 0.3
			draw_line(prev, next, Color(body_color.r, body_color.g, body_color.b, alpha), width, true)
			prev = next

		# Tentacle tip
		draw_circle(prev, 2.0, Color(body_color.r * 1.3, body_color.g, body_color.b * 0.8, 0.6))

func _draw_mouth(body_color: Color) -> void:
	var mouth_x: float = _body_radius * 0.7
	var mouth_width: float = _body_radius * 0.4
	var mouth_open: float = _jaw_open * mouth_width * 0.8

	# Upper jaw
	var upper_pts: PackedVector2Array = PackedVector2Array([
		Vector2(mouth_x - 5, -mouth_width * 0.3),
		Vector2(mouth_x + 10 + mouth_open * 0.5, -mouth_open * 0.5),
		Vector2(mouth_x + 10 + mouth_open * 0.5, 0),
		Vector2(mouth_x - 5, 0),
	])
	draw_colored_polygon(upper_pts, Color(body_color.r * 0.6, body_color.g * 0.5, body_color.b * 0.5, 0.9))

	# Lower jaw
	var lower_pts: PackedVector2Array = PackedVector2Array([
		Vector2(mouth_x - 5, 0),
		Vector2(mouth_x + 10 + mouth_open * 0.5, 0),
		Vector2(mouth_x + 10 + mouth_open * 0.5, mouth_open * 0.5),
		Vector2(mouth_x - 5, mouth_width * 0.3),
	])
	draw_colored_polygon(lower_pts, Color(body_color.r * 0.5, body_color.g * 0.4, body_color.b * 0.5, 0.9))

	# Mouth interior
	if _jaw_open > 0.2:
		var interior_pts: PackedVector2Array = PackedVector2Array([
			Vector2(mouth_x, -mouth_open * 0.4),
			Vector2(mouth_x + 5, 0),
			Vector2(mouth_x, mouth_open * 0.4),
			Vector2(mouth_x - 3, 0),
		])
		draw_colored_polygon(interior_pts, Color(0.15, 0.05, 0.1, 0.95))

		# Teeth
		if _jaw_open > 0.4:
			for t in range(3):
				var ty: float = (t - 1) * mouth_open * 0.25
				var tooth_pts: PackedVector2Array = PackedVector2Array([
					Vector2(mouth_x + 2, ty - 2),
					Vector2(mouth_x + 6, ty),
					Vector2(mouth_x + 2, ty + 2),
				])
				draw_colored_polygon(tooth_pts, Color(0.9, 0.85, 0.8, 0.9))

func _draw_eye(body_color: Color) -> void:
	var eye_pos := Vector2(_body_radius * 0.15, -_body_radius * 0.2)

	var eye_squash: float = 0.85
	if _is_blinking:
		eye_squash = 0.08

	# Eye socket shadow
	draw_circle(eye_pos + Vector2(2, 2), _eye_size * 1.2, Color(0.1, 0.1, 0.15, 0.4))

	# Eye white
	var eye_pts: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var a: float = TAU * i / 16.0
		eye_pts.append(eye_pos + Vector2(cos(a) * _eye_size, sin(a) * _eye_size * eye_squash))
	draw_colored_polygon(eye_pts, Color(0.85, 0.8, 0.75, 0.95))

	if eye_squash > 0.2:
		# Iris - large, dark
		var iris_size: float = _eye_size * 0.7
		var iris_pts: PackedVector2Array = PackedVector2Array()
		for i in range(14):
			var a: float = TAU * i / 14.0
			iris_pts.append(eye_pos + Vector2(cos(a) * iris_size, sin(a) * iris_size * eye_squash))
		draw_colored_polygon(iris_pts, Color(0.2, 0.15, 0.1, 1.0))

		# Pupil - vertical slit
		var pupil_w: float = _eye_size * 0.2 * _pupil_dilation
		var pupil_h: float = _eye_size * 0.5 * eye_squash
		var pupil_pts: PackedVector2Array = PackedVector2Array([
			eye_pos + Vector2(-pupil_w, 0),
			eye_pos + Vector2(0, -pupil_h),
			eye_pos + Vector2(pupil_w, 0),
			eye_pos + Vector2(0, pupil_h),
		])
		draw_colored_polygon(pupil_pts, Color(0.02, 0.02, 0.02, 1.0))

		# Eye shine
		draw_circle(eye_pos + Vector2(-_eye_size * 0.3, -_eye_size * 0.2), _eye_size * 0.15, Color(1, 1, 1, 0.7))

	# Eye outline
	for i in range(eye_pts.size()):
		draw_line(eye_pts[i], eye_pts[(i + 1) % eye_pts.size()], Color(0.15, 0.1, 0.1, 0.8), 1.5, true)

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	AudioManager.play_hurt()

	# Leviathans get stunned when hit hard
	if amount > 15 and state in [State.INHALE, State.CHOMP]:
		state = State.STUN
		_stun_timer = 0.8

	if health <= 0:
		_die()

func _die() -> void:
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		# Lots of loot from a leviathan
		manager.spawn_death_nutrients(global_position, randi_range(10, 15), _base_color)
	AudioManager.play_death()
	queue_free()

func confuse(duration: float) -> void:
	# Leviathans resist confusion - just retreat
	state = State.RETREAT

extends CharacterBody2D
## AI enemy cell with comical expressive face. Color/shape changes based on FSM state.

enum State { WANDER, PURSUE, FLEE, CONFUSED }

var state: State = State.WANDER
var health: float = 50.0
var max_health: float = 50.0
var speed: float = 100.0
var damage: float = 8.0
var detection_range: float = 300.0
var attack_range: float = 45.0
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var _confused_timer: float = 0.0
var _target_velocity: Vector2 = Vector2.ZERO  # For smooth interpolated movement

# Procedural graphics
var _time: float = 0.0
var _cell_radius: float = 14.0
var _membrane_points: Array[Vector2] = []
var _spike_count: int = 0
var _base_color: Color
var _damage_flash: float = 0.0
const NUM_MEMBRANE_PTS: int = 24

# Face system
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _eye_spacing: float = 0.0
var _eye_size: float = 0.0
var _pupil_size: float = 0.0
var _mouth_open: float = 0.0
var _face_style: int = 0  # 0=round eyes, 1=angry slits, 2=derpy uneven

# Comical animation extras
var _eye_bounce: Vector2 = Vector2.ZERO  # Googly eye offset
var _eye_bounce_vel: Vector2 = Vector2.ZERO  # For physics-based googly eyes
var _tongue_out: float = 0.0  # 0-1 tongue extension
var _eye_pop: float = 0.0  # Eye bulge multiplier
var _double_blink: bool = false  # For double-take blinks
var _eyebrow_bounce: float = 0.0  # Animated eyebrow raise

func _ready() -> void:
	_pick_wander_target()
	_init_shape()
	_randomize_face()

func _randomize_face() -> void:
	_eye_spacing = randf_range(3.5, 6.0)
	_eye_size = randf_range(2.5, 4.0)
	_pupil_size = randf_range(1.0, 2.0)
	_face_style = randi_range(0, 2)
	_blink_timer = randf_range(1.0, 4.0)

func _init_shape() -> void:
	_spike_count = randi_range(4, 8)
	_membrane_points.clear()
	for i in range(NUM_MEMBRANE_PTS):
		var angle: float = TAU * i / NUM_MEMBRANE_PTS
		var r: float = _cell_radius
		var spike_freq: float = float(NUM_MEMBRANE_PTS) / _spike_count
		var spike_phase: float = fmod(float(i), spike_freq) / spike_freq
		if spike_phase < 0.15 or spike_phase > 0.85:
			r += randf_range(3.0, 6.0)
		else:
			r += randf_range(-2.0, 1.0)
		_membrane_points.append(Vector2(cos(angle) * r, sin(angle) * r))
	_base_color = Color(
		randf_range(0.7, 1.0),
		randf_range(0.15, 0.35),
		randf_range(0.1, 0.3)
	)

var _attack_target: Node2D = null  # Non-player target (competitor/prey)
var _attack_cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	# Confused timer countdown
	if _confused_timer > 0:
		_confused_timer -= delta
		if _confused_timer <= 0:
			state = State.WANDER

	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)

	var player := _find_player()
	if state != State.CONFUSED:
		if player:
			var dist := global_position.distance_to(player.global_position)
			if health < 15.0:
				state = State.FLEE
			elif dist < detection_range:
				_attack_target = null
				state = State.PURSUE
			else:
				# No player nearby — hunt competitors or prey
				_scan_for_other_targets()
				if _attack_target and is_instance_valid(_attack_target):
					state = State.PURSUE
				else:
					state = State.WANDER
		else:
			_scan_for_other_targets()
			if _attack_target and is_instance_valid(_attack_target):
				state = State.PURSUE
			else:
				state = State.WANDER
	match state:
		State.WANDER: _do_wander(delta)
		State.PURSUE:
			if _attack_target and is_instance_valid(_attack_target):
				_do_pursue_target(delta, _attack_target)
			else:
				_do_pursue(delta, player)
		State.FLEE: _do_flee(delta, player)
		State.CONFUSED: _do_confused(delta)

	# Smooth velocity interpolation (like player) for fluid movement
	velocity = velocity.move_toward(_target_velocity, speed * 4.0 * delta)
	move_and_slide()
	_time += delta
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
	_mouth_open = maxf(_mouth_open - delta * 3.0, 0.0)

	# Googly eye physics - eyes lag behind movement
	var eye_target := -velocity * 0.015  # Eyes drift opposite to movement
	var spring_k: float = 15.0
	var damping: float = 5.0
	_eye_bounce_vel += (eye_target - _eye_bounce) * spring_k * delta
	_eye_bounce_vel *= exp(-damping * delta)
	_eye_bounce += _eye_bounce_vel * delta
	_eye_bounce = _eye_bounce.limit_length(3.0)  # Max offset

	# Eye pop decay
	_eye_pop = maxf(_eye_pop - delta * 3.0, 0.0)

	# Tongue decay (stick out when pursuing)
	if state == State.PURSUE:
		_tongue_out = minf(_tongue_out + delta * 2.0, 0.7)
	else:
		_tongue_out = maxf(_tongue_out - delta * 3.0, 0.0)

	# Eyebrow bounce decay
	_eyebrow_bounce = maxf(_eyebrow_bounce - delta * 4.0, 0.0)

	# Blink - with occasional double-take
	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			if _double_blink:
				_blink_timer = 0.15  # Quick second blink
				_double_blink = false
			else:
				_blink_timer = randf_range(1.5, 4.0)
				_double_blink = randf() < 0.2  # 20% chance of double blink
		else:
			_is_blinking = true
			_blink_timer = 0.1
	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _draw() -> void:
	var health_ratio: float = health / max_health

	# State-dependent color
	var draw_color: Color = _base_color
	match state:
		State.PURSUE:
			draw_color = _base_color.lerp(Color(1.0, 0.1, 0.0), 0.3 + 0.15 * sin(_time * 6.0))
		State.FLEE:
			draw_color = _base_color.lerp(Color(0.9, 0.8, 0.2), 0.4)
		State.CONFUSED:
			draw_color = _base_color.lerp(Color(0.6, 0.8, 0.3), 0.3 + 0.15 * sin(_time * 4.0))

	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)

	# Glow
	var glow_a: float = 0.06 + 0.04 * sin(_time * 3.0)
	draw_circle(Vector2.ZERO, _cell_radius * 1.8, Color(draw_color.r, draw_color.g, draw_color.b, glow_a))

	# Membrane polygon
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(NUM_MEMBRANE_PTS):
		var wobble: float = sin(_time * 4.0 + i * 0.9) * 1.2
		var pt: Vector2 = _membrane_points[i] + _membrane_points[i].normalized() * wobble
		pts.append(pt)

	var fill := Color(draw_color.r * 0.4, draw_color.g * 0.3, draw_color.b * 0.3, 0.75)
	draw_colored_polygon(pts, fill)
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(draw_color, 0.9), 1.3, true)

	# Nucleus
	var nr: float = _cell_radius * 0.3
	draw_circle(Vector2(sin(_time) * 1.0, cos(_time * 0.8) * 1.0), nr, Color(0.3, 0.08, 0.08, 0.85))

	# --- COMICAL FACE ---
	_draw_face()

	# Health ring
	if health_ratio < 1.0:
		draw_arc(Vector2.ZERO, _cell_radius + 2.0, 0, TAU * health_ratio, 32, Color(1.0, 0.3, 0.1, 0.5), 1.5, true)

	# Pursue pulsing aura
	if state == State.PURSUE:
		var pulse: float = 0.1 + 0.08 * sin(_time * 8.0)
		draw_arc(Vector2.ZERO, _cell_radius + 4.0, 0, TAU, 32, Color(1.0, 0.2, 0.0, pulse), 1.0, true)

func _draw_face() -> void:
	var eye_y_offset: float = -0.5
	# Apply googly eye bounce offset
	var left_eye := Vector2(_eye_spacing * 0.5, -_eye_spacing * 0.5 + eye_y_offset) + _eye_bounce
	var right_eye := Vector2(_eye_spacing * 0.5, _eye_spacing * 0.5 + eye_y_offset) + _eye_bounce * 0.8  # Slight delay
	var mouth_pos := Vector2(_cell_radius * 0.4, 0)

	var eye_white_color := Color(0.95, 0.9, 0.85, 0.95)
	var pupil_color := Color(0.15, 0.02, 0.0, 1.0)
	var eye_r: float = _eye_size
	var pupil_r: float = _pupil_size
	var eye_squash_y: float = 1.0
	var pupil_offset := Vector2.ZERO
	var brow_angle_l: float = 0.0
	var brow_angle_r: float = 0.0
	var mouth_curve: float = 0.0
	var mouth_width: float = 4.5
	var mouth_open_amt: float = _mouth_open

	# State-based expressions
	match state:
		State.WANDER:
			# Dopey / bored
			if _face_style == 2:
				# Derpy: one eye bigger
				eye_r *= 0.9
			eye_squash_y = 0.75
			brow_angle_l = 0.1
			brow_angle_r = -0.05
			mouth_curve = -0.5
			mouth_width = 3.0
		State.PURSUE:
			# Angry / aggressive
			eye_squash_y = 0.6
			brow_angle_l = -0.5
			brow_angle_r = 0.5
			pupil_r *= 0.85
			mouth_curve = -3.5
			mouth_width = 6.0
			mouth_open_amt = maxf(mouth_open_amt, 0.3 + 0.2 * sin(_time * 5.0))
			pupil_offset = Vector2(1.5, 0)  # Staring forward
		State.FLEE:
			# Terrified
			eye_r *= 1.5
			pupil_r *= 0.5  # Tiny pinpricks
			eye_squash_y = 1.2
			brow_angle_l = 0.5
			brow_angle_r = 0.5
			mouth_curve = -1.5
			mouth_open_amt = maxf(mouth_open_amt, 0.9)
			mouth_width = 3.5
			# Trembling offset
			pupil_offset = Vector2(sin(_time * 12.0) * 0.5, cos(_time * 10.0) * 0.5)
		State.CONFUSED:
			# Dazed spiral eyes, dopey grin
			eye_squash_y = 1.0
			eye_r *= 1.2
			pupil_r *= 0.7
			# Spiral pupils - offset rotates
			pupil_offset = Vector2(cos(_time * 8.0) * eye_r * 0.3, sin(_time * 8.0) * eye_r * 0.3)
			brow_angle_l = sin(_time * 3.0) * 0.3
			brow_angle_r = cos(_time * 3.0) * 0.3
			mouth_curve = 2.0 + sin(_time * 4.0)
			mouth_width = 5.0

	if _is_blinking:
		eye_squash_y = 0.07

	# Apply eye pop effect (bulging eyes)
	eye_r *= (1.0 + _eye_pop * 0.5)

	# Draw eyes
	for idx in range(2):
		var eye_pos: Vector2 = left_eye if idx == 0 else right_eye
		var er: float = eye_r
		# Derpy style: right eye is bigger
		if _face_style == 2 and idx == 1:
			er *= 1.3
		var eh: float = er * eye_squash_y
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(12):
			var a: float = TAU * i / 12.0
			eye_pts.append(eye_pos + Vector2(cos(a) * er, sin(a) * eh))
		draw_colored_polygon(eye_pts, eye_white_color)
		# Pupil
		var p_pos: Vector2 = eye_pos + pupil_offset
		# Angry slit style
		if _face_style == 1 and state == State.PURSUE:
			# Vertical slit pupils
			var slit_pts: PackedVector2Array = PackedVector2Array()
			for i in range(8):
				var a: float = TAU * i / 8.0
				slit_pts.append(p_pos + Vector2(cos(a) * pupil_r * 0.4, sin(a) * pupil_r * 1.3))
			draw_colored_polygon(slit_pts, pupil_color)
		else:
			draw_circle(p_pos, pupil_r, pupil_color)
		# Highlight
		draw_circle(p_pos + Vector2(-0.4, -0.4), pupil_r * 0.3, Color(1, 0.9, 0.8, 0.6))

	# Eyebrows (always drawn for enemies - they're expressive)
	var brow_len: float = eye_r * 1.5
	var brow_y: float = eye_y_offset - eye_r - 1.5
	var brow_color := Color(0.3, 0.08, 0.05, 0.9)
	# Left brow
	var lb_start := Vector2(left_eye.x - brow_len * 0.5, left_eye.y + brow_y)
	var lb_end := lb_start + Vector2(brow_len, 0).rotated(brow_angle_l)
	draw_line(lb_start, lb_end, brow_color, 2.0, true)
	# Right brow
	var rb_start := Vector2(right_eye.x - brow_len * 0.5, right_eye.y + brow_y)
	var rb_end := rb_start + Vector2(brow_len, 0).rotated(brow_angle_r)
	draw_line(rb_start, rb_end, brow_color, 2.0, true)

	# Mouth
	if mouth_open_amt > 0.1:
		var mo_w: float = mouth_width * (0.4 + mouth_open_amt * 0.6)
		var mo_h: float = 1.5 + mouth_open_amt * 3.0
		var mo_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			mo_pts.append(mouth_pos + Vector2(cos(a) * mo_w * 0.4, sin(a) * mo_h))
		draw_colored_polygon(mo_pts, Color(0.2, 0.02, 0.05, 0.9))
		# Teeth when pursuing (jagged top edge)
		if state == State.PURSUE:
			for t in range(3):
				var tx: float = mouth_pos.x - mo_w * 0.2 + mo_w * 0.2 * t
				var ty: float = mouth_pos.y - mo_h * 0.6
				var tooth_pts: PackedVector2Array = PackedVector2Array([
					Vector2(tx - 0.8, ty),
					Vector2(tx, ty + 1.5),
					Vector2(tx + 0.8, ty),
				])
				draw_colored_polygon(tooth_pts, Color(0.95, 0.9, 0.8, 0.9))
	else:
		# Closed mouth
		var m_left := mouth_pos + Vector2(0, -mouth_width * 0.5)
		var m_right := mouth_pos + Vector2(0, mouth_width * 0.5)
		var m_mid := mouth_pos + Vector2(mouth_curve, 0)
		draw_line(m_left, m_mid, Color(0.2, 0.05, 0.05, 0.85), 1.8, true)
		draw_line(m_mid, m_right, Color(0.2, 0.05, 0.05, 0.85), 1.8, true)

	# Tongue sticking out when pursuing (drooling for prey)
	if _tongue_out > 0.1:
		var tongue_base := mouth_pos + Vector2(2.0, 0)
		var tongue_len: float = 4.0 + _tongue_out * 5.0
		var tongue_wave: float = sin(_time * 8.0) * 1.5 * _tongue_out
		var tongue_tip := tongue_base + Vector2(tongue_len, tongue_wave)
		var tongue_mid := tongue_base + Vector2(tongue_len * 0.5, tongue_wave * 0.3)
		# Tongue shape
		var tongue_pts: PackedVector2Array = PackedVector2Array([
			tongue_base + Vector2(0, -1.2),
			tongue_mid + Vector2(0, -1.0 - _tongue_out * 0.5),
			tongue_tip + Vector2(0, -0.8),
			tongue_tip + Vector2(1.0, 0),  # Rounded tip
			tongue_tip + Vector2(0, 0.8),
			tongue_mid + Vector2(0, 1.0 + _tongue_out * 0.5),
			tongue_base + Vector2(0, 1.2),
		])
		draw_colored_polygon(tongue_pts, Color(0.9, 0.3, 0.35, 0.9))
		# Tongue highlight
		draw_line(tongue_base + Vector2(1, -0.3), tongue_mid + Vector2(0, -0.3), Color(1.0, 0.5, 0.5, 0.5), 0.8, true)

	# Confused: orbiting stars/spirals above head
	if state == State.CONFUSED:
		for s in range(3):
			var sa: float = _time * 4.0 + TAU * s / 3.0
			var star_pos := Vector2(-_cell_radius - 3.0, 0) + Vector2(cos(sa) * 6.0, sin(sa) * 6.0)
			var star_a: float = 0.5 + 0.3 * sin(_time * 6.0 + s)
			draw_circle(star_pos, 1.5, Color(1.0, 1.0, 0.3, star_a))

func _do_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0 or global_position.distance_to(wander_target) < 20:
		_pick_wander_target()
	_target_velocity = global_position.direction_to(wander_target) * speed * 0.5

func _do_pursue(delta: float, player: Node2D) -> void:
	if not player:
		state = State.WANDER
		return
	_target_velocity = global_position.direction_to(player.global_position) * speed
	if global_position.distance_to(player.global_position) < attack_range:
		_mouth_open = 0.8
		if player.has_method("take_damage"):
			player.take_damage(damage * delta)

func _do_pursue_target(delta: float, target: Node2D) -> void:
	if not is_instance_valid(target):
		_attack_target = null
		state = State.WANDER
		return
	_target_velocity = global_position.direction_to(target.global_position) * speed
	if global_position.distance_to(target.global_position) < attack_range:
		_mouth_open = 0.8
		if _attack_cooldown <= 0 and target.has_method("take_damage"):
			target.take_damage(damage * 0.5)
			_attack_cooldown = 0.3

func _scan_for_other_targets() -> void:
	_attack_target = null
	var best_dist: float = detection_range
	# Hunt competitors
	for c in get_tree().get_nodes_in_group("competitors"):
		var d: float = global_position.distance_to(c.global_position)
		if d < best_dist:
			best_dist = d
			_attack_target = c
	# Hunt prey (prefer closer)
	for p in get_tree().get_nodes_in_group("prey"):
		var d: float = global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			_attack_target = p

func _do_flee(delta: float, player: Node2D) -> void:
	if not player:
		state = State.WANDER
		return
	_target_velocity = player.global_position.direction_to(global_position) * speed * 1.2

func _do_confused(delta: float) -> void:
	# Spiral around randomly, dazed
	wander_timer -= delta
	if wander_timer <= 0:
		wander_target = global_position + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		wander_timer = randf_range(0.3, 0.8)
	var confused_vel := global_position.direction_to(wander_target) * speed * 0.3
	# Add spin wobble
	_target_velocity = confused_vel.rotated(sin(_time * 6.0) * 0.5)

func confuse(duration: float) -> void:
	## Called by player jet stream to daze this enemy
	state = State.CONFUSED
	_confused_timer = duration
	_mouth_open = 0.6
	if AudioManager:
		AudioManager.play_confused()

func _pick_wander_target() -> void:
	wander_target = global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	wander_timer = randf_range(2.0, 5.0)

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

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	_mouth_open = 0.7
	_eye_pop = 1.0  # Eyes bulge when hit
	_eyebrow_bounce = 1.0  # Eyebrows jump up
	if health <= 0:
		_die()

func _die() -> void:
	# Spawn nutrients at death location
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if not manager:
		# Fallback: find by class
		manager = get_parent()
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(3, 6), _base_color)
	if AudioManager:
		AudioManager.play_death()
	queue_free()

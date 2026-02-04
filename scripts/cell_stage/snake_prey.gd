extends CharacterBody2D
## Snake-like prey organism: small, eatable, panicky. Restores health when consumed.
## Multi-segment body that slithers. Gets sad/terrified when player is near.
## When beamed, stretches like a noodle being slurped toward the player.

enum State { IDLE, PANIC, FLEEING }

var state: State = State.IDLE
var health: float = 15.0
var speed: float = 60.0
var panic_speed: float = 180.0
var detection_range: float = 120.0
var health_restore: float = 15.0
var energy_restore: float = 10.0

var _time: float = 0.0
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0

# Body segments
var _num_segments: int = 0
var _segment_positions: Array[Vector2] = []
var _segment_radius: float = 3.5
var _head_radius: float = 5.0
var _base_color: Color
var _belly_color: Color
var _segment_spacing: float = 5.0

# Face
var _eye_size: float = 2.2
var _pupil_size: float = 1.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _panic_level: float = 0.0

# Beam / noodle-slurp interaction
var is_being_beamed: bool = false
var _beam_pull_speed: float = 0.0
var _beam_stretch: float = 0.0        # 0-1, how stretched toward player
var _segment_compression: float = 1.0  # 1→0.25, segments bunch up at head
var _beam_source: Vector2 = Vector2.ZERO
var _slurp_vibrate: float = 0.0       # Vibration intensity while being slurped

func _ready() -> void:
	_num_segments = randi_range(4, 7)
	_head_radius = randf_range(4.0, 5.5)
	_segment_radius = _head_radius * randf_range(0.6, 0.8)
	_eye_size = _head_radius * randf_range(0.35, 0.5)
	_pupil_size = _eye_size * randf_range(0.4, 0.55)
	_segment_spacing = _head_radius * 1.1
	_base_color = Color(
		randf_range(0.7, 1.0),
		randf_range(0.5, 0.8),
		randf_range(0.2, 0.5),
		0.9
	)
	_belly_color = Color(_base_color.r * 1.1, _base_color.g * 1.1, _base_color.b * 0.8, 0.7)
	_segment_positions.clear()
	for i in range(_num_segments):
		_segment_positions.append(global_position + Vector2(-_segment_spacing * (i + 1), 0))
	add_to_group("prey")
	_pick_wander_target()
	_blink_timer = randf_range(1.0, 3.0)

func _physics_process(delta: float) -> void:
	var player := _find_player()
	var player_dist: float = INF
	if player:
		player_dist = global_position.distance_to(player.global_position)

	# Check for nearby enemies/competitors as threats too
	var nearest_threat: Node2D = player if player_dist < detection_range else null
	var threat_dist: float = player_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position)
		if d < detection_range and d < threat_dist:
			threat_dist = d
			nearest_threat = e
	for c in get_tree().get_nodes_in_group("competitors"):
		var d: float = global_position.distance_to(c.global_position)
		if d < detection_range and d < threat_dist:
			threat_dist = d
			nearest_threat = c

	# State transitions
	match state:
		State.IDLE:
			if nearest_threat:
				state = State.PANIC
			else:
				_do_idle(delta)
		State.PANIC:
			if not nearest_threat or threat_dist > detection_range * 1.8:
				state = State.IDLE
				_panic_level = maxf(_panic_level - delta * 2.0, 0.0)
			else:
				_do_panic(delta, nearest_threat)
		State.FLEEING:
			_do_panic(delta, nearest_threat)
			if not nearest_threat or threat_dist > detection_range * 2.0:
				state = State.IDLE

	# Beam noodle-slurp override
	if is_being_beamed:
		_beam_pull_speed = minf(_beam_pull_speed + 600.0 * delta, 800.0)
		_panic_level = 1.0
		_beam_stretch = minf(_beam_stretch + 2.5 * delta, 1.0)
		_segment_compression = maxf(_segment_compression - 2.0 * delta, 0.2)
		_slurp_vibrate = minf(_slurp_vibrate + 3.0 * delta, 1.0)
		# Override velocity entirely — sucked toward beam source
		var dir := (_beam_source - global_position).normalized()
		velocity = dir * _beam_pull_speed
	else:
		_beam_pull_speed = maxf(_beam_pull_speed - 400.0 * delta, 0.0)
		_beam_stretch = maxf(_beam_stretch - 4.0 * delta, 0.0)
		_segment_compression = minf(_segment_compression + 3.0 * delta, 1.0)
		_slurp_vibrate = maxf(_slurp_vibrate - 5.0 * delta, 0.0)

	move_and_slide()

	# Update segment positions (follow-the-leader with compression)
	var leader: Vector2 = global_position
	for i in range(_segment_positions.size()):
		var seg: Vector2 = _segment_positions[i]
		var dir: Vector2 = (leader - seg)
		# When being slurped, front segments compress, tail stretches
		var effective_spacing: float = _segment_spacing * _segment_compression
		if is_being_beamed:
			# Front segments bunch tighter, tail segments stretch out
			var t: float = float(i) / _segment_positions.size()
			var compress_factor: float = lerpf(0.3, 1.8, t * _beam_stretch)
			effective_spacing *= compress_factor
		if dir.length() > effective_spacing:
			_segment_positions[i] = leader - dir.normalized() * effective_spacing
		leader = _segment_positions[i]

	# Blink
	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(0.8, 2.5) if state == State.IDLE else randf_range(0.3, 0.8)
		else:
			_is_blinking = true
			_blink_timer = 0.1

	_time += delta
	_panic_level = clampf(_panic_level, 0.0, 1.0)
	queue_redraw()

func _do_idle(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0 or global_position.distance_to(wander_target) < 15:
		_pick_wander_target()
	velocity = global_position.direction_to(wander_target) * speed * 0.4
	_panic_level = maxf(_panic_level - delta * 1.5, 0.0)

func _do_panic(delta: float, player: Node2D) -> void:
	_panic_level = minf(_panic_level + delta * 3.0, 1.0)
	if not player:
		state = State.IDLE
		return
	var flee_dir: Vector2 = (global_position - player.global_position).normalized()
	var zigzag: float = sin(_time * 8.0) * 0.4
	flee_dir = flee_dir.rotated(zigzag)
	velocity = flee_dir * lerpf(speed, panic_speed, _panic_level)
	state = State.FLEEING

func _pick_wander_target() -> void:
	wander_target = global_position + Vector2(randf_range(-120, 120), randf_range(-120, 120))
	wander_timer = randf_range(2.0, 4.0)

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]

func _draw() -> void:
	var local_segments: Array[Vector2] = []
	for seg_global in _segment_positions:
		local_segments.append(seg_global - global_position)

	# Tail segments (back to front)
	for i in range(local_segments.size() - 1, -1, -1):
		var t: float = float(i) / local_segments.size()
		var seg_r: float = _segment_radius * (1.0 - t * 0.35)
		var seg_pos: Vector2 = local_segments[i]

		# Slurp vibration
		if _slurp_vibrate > 0:
			var vib: float = _slurp_vibrate * sin(_time * 30.0 + i * 2.0) * 2.0
			seg_pos += Vector2(0, vib)

		var seg_col := Color(
			_base_color.r * (1.0 - t * 0.15),
			_base_color.g * (1.0 - t * 0.1),
			_base_color.b,
			_base_color.a * (1.0 - t * 0.2)
		)
		if _panic_level > 0:
			seg_col = seg_col.lerp(Color(1.0, 0.5, 0.4), _panic_level * 0.3)

		# When being slurped, tail segments get elongated/stretched look
		if is_being_beamed and t > 0.5:
			var stretch_alpha: float = _beam_stretch * (t - 0.5) * 2.0
			seg_r *= lerpf(1.0, 0.6, stretch_alpha)  # Thinner when stretched

		draw_circle(seg_pos, seg_r + 0.5, Color(seg_col.r * 0.5, seg_col.g * 0.4, seg_col.b * 0.3, 0.4))
		draw_circle(seg_pos, seg_r, seg_col)
		draw_circle(seg_pos + Vector2(0, seg_r * 0.2), seg_r * 0.5, _belly_color)

		# Connecting line to previous
		var prev_pos: Vector2
		if i == 0:
			prev_pos = Vector2.ZERO
		else:
			prev_pos = local_segments[i - 1]
			if _slurp_vibrate > 0:
				prev_pos += Vector2(0, _slurp_vibrate * sin(_time * 30.0 + (i - 1) * 2.0) * 2.0)
		var line_width: float = seg_r * 0.8
		# Stretch lines thinner when being slurped
		if is_being_beamed and t > 0.3:
			line_width *= lerpf(1.0, 0.4, _beam_stretch * t)
		draw_line(prev_pos, seg_pos, Color(seg_col, 0.5), line_width, true)

		# Stretch strain lines when being slurped hard
		if is_being_beamed and _beam_stretch > 0.4 and t > 0.4:
			var mid := (prev_pos + seg_pos) * 0.5
			var perp := (seg_pos - prev_pos).normalized().rotated(PI * 0.5)
			var strain_a: float = (_beam_stretch - 0.4) * 1.5 * (0.3 + 0.2 * sin(_time * 20.0 + i))
			draw_line(mid - perp * 3.0, mid + perp * 3.0, Color(1.0, 0.8, 0.6, strain_a), 0.5, true)

	# Head
	var head_col := _base_color
	if _panic_level > 0:
		head_col = head_col.lerp(Color(1.0, 0.5, 0.4), _panic_level * 0.3)
	# Head vibrates when slurped
	var head_offset := Vector2.ZERO
	if _slurp_vibrate > 0:
		head_offset = Vector2(sin(_time * 35.0) * _slurp_vibrate * 1.5, cos(_time * 28.0) * _slurp_vibrate * 1.0)
	draw_circle(head_offset, _head_radius * 1.5, Color(head_col.r, head_col.g, head_col.b, 0.05))
	draw_circle(head_offset, _head_radius, head_col)
	draw_circle(head_offset + Vector2(_head_radius * 0.15, 0), _head_radius * 0.5, _belly_color)

	# Face
	_draw_face(head_col, head_offset)

	# Tail tip
	if local_segments.size() > 0:
		var tail_pos: Vector2 = local_segments[local_segments.size() - 1]
		if _slurp_vibrate > 0:
			tail_pos += Vector2(0, _slurp_vibrate * sin(_time * 30.0 + _num_segments * 2.0) * 2.0)
		draw_circle(tail_pos, _segment_radius * 0.25, Color(head_col, 0.6))

	# Beam suction effect on head when being slurped
	if is_being_beamed:
		var ring_alpha: float = 0.3 + 0.2 * sin(_time * 12.0)
		var ring_r: float = _head_radius * 2.5 - fmod(_time * 50.0, _head_radius * 2.0)
		draw_arc(head_offset, maxf(ring_r, 2.0), 0, TAU, 16, Color(0.5, 0.8, 1.0, ring_alpha * _beam_stretch), 1.5, true)

func _draw_face(head_col: Color, offset: Vector2) -> void:
	var le := offset + Vector2(_head_radius * 0.35, -_head_radius * 0.4)
	var re := offset + Vector2(_head_radius * 0.35, _head_radius * 0.4)

	var eye_r: float = _eye_size
	var pupil_r: float = _pupil_size
	var eye_squash: float = 1.0
	var pupil_offset := Vector2.ZERO
	var brow_angle_l: float = 0.0
	var brow_angle_r: float = 0.0

	if _panic_level < 0.1:
		eye_squash = 0.85
		brow_angle_l = 0.1
		brow_angle_r = 0.1
	elif _panic_level < 0.5:
		eye_r *= 1.1
		eye_squash = 0.9
		brow_angle_l = -0.2
		brow_angle_r = -0.2
		pupil_r *= 0.85
	else:
		eye_r *= 1.4 + sin(_time * 10.0) * 0.1
		pupil_r *= 0.4
		eye_squash = 1.1
		brow_angle_l = 0.5
		brow_angle_r = 0.5
		pupil_offset = Vector2(sin(_time * 15.0) * 0.5, cos(_time * 12.0) * 0.5)

	# Extra terror when being slurped — eyes bulge out
	if is_being_beamed and _beam_stretch > 0.3:
		eye_r *= lerpf(1.0, 1.6, _beam_stretch)
		pupil_r *= lerpf(1.0, 0.3, _beam_stretch)  # Pinprick pupils
		eye_squash = lerpf(eye_squash, 1.3, _beam_stretch)
		brow_angle_l = lerpf(brow_angle_l, 0.7, _beam_stretch)
		brow_angle_r = lerpf(brow_angle_r, 0.7, _beam_stretch)

	if _is_blinking:
		eye_squash = 0.08

	for eye_pos in [le, re]:
		var eh: float = eye_r * eye_squash
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(12):
			var a: float = TAU * i / 12.0
			eye_pts.append(eye_pos + Vector2(cos(a) * eye_r, sin(a) * eh))
		draw_colored_polygon(eye_pts, Color(0.97, 0.97, 1.0, 0.95))
		var p_off := pupil_offset
		if _panic_level > 0.3:
			var player := _find_player()
			if player:
				var threat_dir := (player.global_position - global_position).normalized()
				var local_threat := threat_dir.rotated(-rotation)
				p_off += local_threat * eye_r * 0.25
		draw_circle(eye_pos + p_off, pupil_r, Color(0.08, 0.05, 0.02, 1.0))
		draw_circle(eye_pos + p_off + Vector2(-0.3, -0.3), pupil_r * 0.35, Color(1, 1, 1, 0.7))

	# Eyebrows
	var brow_len: float = eye_r * 1.2
	var brow_y: float = -eye_r - 1.0
	var brow_col := Color(head_col.r * 0.5, head_col.g * 0.4, head_col.b * 0.3, 0.8)
	var lb_s := Vector2(le.x - brow_len * 0.5, le.y + brow_y)
	draw_line(lb_s, lb_s + Vector2(brow_len, 0).rotated(brow_angle_l), brow_col, 1.5, true)
	var rb_s := Vector2(re.x - brow_len * 0.5, re.y + brow_y)
	draw_line(rb_s, rb_s + Vector2(brow_len, 0).rotated(brow_angle_r), brow_col, 1.5, true)

	# Mouth — wide open scream when being slurped
	var mouth_pos := offset + Vector2(_head_radius * 0.55, 0)
	if is_being_beamed and _beam_stretch > 0.2:
		# HUGE screaming mouth
		var mo_size: float = 2.5 + _beam_stretch * 2.5
		var mo_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			mo_pts.append(mouth_pos + Vector2(cos(a) * mo_size * 0.6, sin(a) * mo_size))
		draw_colored_polygon(mo_pts, Color(0.15, 0.02, 0.02, 0.95))
		# Uvula
		var uvula_y: float = sin(_time * 8.0) * mo_size * 0.3
		draw_circle(mouth_pos + Vector2(-mo_size * 0.2, uvula_y), 0.8, Color(0.8, 0.3, 0.3, 0.7))
	elif _panic_level > 0.5:
		var mo_size: float = 1.5 + _panic_level * 1.5
		var mo_pts: PackedVector2Array = PackedVector2Array()
		for i in range(8):
			var a: float = TAU * i / 8.0
			mo_pts.append(mouth_pos + Vector2(cos(a) * mo_size * 0.5, sin(a) * mo_size))
		draw_colored_polygon(mo_pts, Color(0.15, 0.05, 0.05, 0.9))
	elif _panic_level > 0.1:
		var m_left := mouth_pos + Vector2(0, -2.0)
		var m_right := mouth_pos + Vector2(0, 2.0)
		var m_mid := mouth_pos + Vector2(-1.5 + sin(_time * 4.0) * 0.5, 0)
		draw_line(m_left, m_mid, Color(0.2, 0.1, 0.05, 0.8), 1.2, true)
		draw_line(m_mid, m_right, Color(0.2, 0.1, 0.05, 0.8), 1.2, true)
	else:
		var m_left := mouth_pos + Vector2(0, -1.5)
		var m_right := mouth_pos + Vector2(0, 1.5)
		var m_mid := mouth_pos + Vector2(0.8, 0)
		draw_line(m_left, m_mid, Color(0.2, 0.1, 0.05, 0.7), 1.0, true)
		draw_line(m_mid, m_right, Color(0.2, 0.1, 0.05, 0.7), 1.0, true)

	# Tears — stream heavily when being slurped
	if _panic_level > 0.6 or is_being_beamed:
		var tear_count: int = 2 if not is_being_beamed else 4
		for eye_pos in [le, re]:
			for tc in range(tear_count):
				var tear_phase: float = fmod(_time * (2.0 + tc * 0.5) + tc * 0.3, 1.0)
				var tear_drop: float = tear_phase * 8.0
				var tear_alpha: float = (1.0 - tear_phase) * (0.6 if not is_being_beamed else 0.9)
				var tear_x: float = eye_pos.x + eye_r + 1.0 + tear_drop * 0.3
				var tear_y: float = eye_pos.y + (tc - tear_count * 0.5) * 1.5
				draw_circle(Vector2(tear_x, tear_y), 0.8, Color(0.5, 0.7, 1.0, tear_alpha))

func take_damage(amount: float) -> void:
	health -= amount
	_panic_level = 1.0
	state = State.FLEEING
	if health <= 0:
		_die()

func _die() -> void:
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(2, 4), _base_color)
	if AudioManager:
		AudioManager.play_death()
	queue_free()

func beam_pull_toward(target_pos: Vector2, delta: float) -> void:
	is_being_beamed = true
	_beam_source = target_pos

func beam_release() -> void:
	is_being_beamed = false
	_beam_stretch = 0.0
	_segment_compression = 1.0
	_slurp_vibrate = 0.0
	_beam_pull_speed = 0.0

func get_beam_color() -> Color:
	return _base_color

func get_eaten() -> Dictionary:
	return {
		"health_restore": health_restore,
		"energy_restore": energy_restore,
		"id": "SnakePrey",
		"short_name": "Nematode",
		"display_name": "Micro-nematode",
		"color": [_base_color.r, _base_color.g, _base_color.b],
		"rarity": "uncommon",
	}

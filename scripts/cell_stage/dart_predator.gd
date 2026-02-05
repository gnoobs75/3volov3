extends CharacterBody2D
## Fast, darting predator that lunges at prey. Quick attacks, then retreats.
## More dangerous than regular enemies but lower health. Hit-and-run tactics.

enum State { PATROL, STALK, LUNGE, RECOVER, FLEE }

var state: State = State.PATROL
var health: float = 30.0
var max_health: float = 30.0
var speed: float = 80.0
var lunge_speed: float = 500.0
var damage: float = 15.0
var detection_range: float = 250.0
var attack_range: float = 180.0
var lunge_range: float = 30.0  # Must be this close to hit

# Timers
var _time: float = 0.0
var _patrol_timer: float = 0.0
var _stalk_timer: float = 0.0
var _lunge_timer: float = 0.0
var _recover_timer: float = 0.0
var _attack_cooldown: float = 0.0

# Movement
var _patrol_target: Vector2 = Vector2.ZERO
var _lunge_direction: Vector2 = Vector2.ZERO
var _current_target: Node2D = null

# Procedural graphics
var _body_length: float = 0.0
var _body_width: float = 0.0
var _base_color: Color
var _accent_color: Color
var _damage_flash: float = 0.0
var _lunge_stretch: float = 0.0  # Body elongates during lunge

# Face
var _eye_size: float = 3.0
var _is_blinking: bool = false
var _blink_timer: float = 0.0

func _ready() -> void:
	_init_shape()
	_pick_patrol_target()
	add_to_group("enemies")
	_blink_timer = randf_range(1.5, 4.0)

func _init_shape() -> void:
	_body_length = randf_range(22.0, 28.0)
	_body_width = randf_range(8.0, 11.0)
	_eye_size = _body_width * randf_range(0.25, 0.35)
	# Aggressive colors - dark with bright accents
	_base_color = Color(
		randf_range(0.15, 0.3),
		randf_range(0.1, 0.2),
		randf_range(0.2, 0.35),
		0.95
	)
	_accent_color = Color(
		randf_range(0.7, 1.0),
		randf_range(0.2, 0.5),
		randf_range(0.1, 0.3),
		1.0
	)

func _physics_process(delta: float) -> void:
	_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)

	# Blink timer
	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(1.0, 3.0)
		else:
			_is_blinking = true
			_blink_timer = 0.08

	# Find targets
	var player := _find_player()
	var best_target: Node2D = null
	var best_dist: float = detection_range

	if player:
		var d: float = global_position.distance_to(player.global_position)
		if d < best_dist:
			best_dist = d
			best_target = player

	# Also hunt prey and competitors
	for prey in get_tree().get_nodes_in_group("prey"):
		var d: float = global_position.distance_to(prey.global_position)
		if d < best_dist:
			best_dist = d
			best_target = prey

	for comp in get_tree().get_nodes_in_group("competitors"):
		var d: float = global_position.distance_to(comp.global_position)
		if d < best_dist:
			best_dist = d
			best_target = comp

	_current_target = best_target

	# State machine
	match state:
		State.PATROL:
			_do_patrol(delta)
			if _current_target and best_dist < detection_range:
				state = State.STALK
				_stalk_timer = randf_range(0.8, 1.5)
		State.STALK:
			_do_stalk(delta)
		State.LUNGE:
			_do_lunge(delta)
		State.RECOVER:
			_do_recover(delta)
		State.FLEE:
			_do_flee(delta)

	# Lunge stretch animation
	if state == State.LUNGE:
		_lunge_stretch = minf(_lunge_stretch + delta * 8.0, 1.0)
	else:
		_lunge_stretch = maxf(_lunge_stretch - delta * 4.0, 0.0)

	move_and_slide()
	queue_redraw()

func _do_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0 or global_position.distance_to(_patrol_target) < 20:
		_pick_patrol_target()

	velocity = global_position.direction_to(_patrol_target) * speed * 0.4
	look_at(global_position + velocity)

func _do_stalk(delta: float) -> void:
	if not _current_target or not is_instance_valid(_current_target):
		state = State.PATROL
		return

	_stalk_timer -= delta

	# Circle around target, getting closer
	var to_target: Vector2 = _current_target.global_position - global_position
	var dist: float = to_target.length()

	# Orbit slightly while approaching
	var orbit_angle: float = sin(_time * 3.0) * 0.3
	var move_dir: Vector2 = to_target.normalized().rotated(orbit_angle)
	velocity = move_dir * speed * 0.7

	look_at(_current_target.global_position)

	# Ready to lunge?
	if _stalk_timer <= 0 and dist < attack_range and _attack_cooldown <= 0:
		state = State.LUNGE
		_lunge_direction = to_target.normalized()
		_lunge_timer = 0.3  # Lunge duration
		AudioManager.play_jet()

func _do_lunge(delta: float) -> void:
	_lunge_timer -= delta

	velocity = _lunge_direction * lunge_speed

	# Check for hit during lunge
	if _current_target and is_instance_valid(_current_target):
		var dist: float = global_position.distance_to(_current_target.global_position)
		if dist < lunge_range:
			if _current_target.has_method("take_damage"):
				_current_target.take_damage(damage)
				_attack_cooldown = 2.0
				AudioManager.play_toxin()
			state = State.RECOVER
			_recover_timer = 0.8
			return

	if _lunge_timer <= 0:
		state = State.RECOVER
		_recover_timer = 0.6
		_attack_cooldown = 1.5

func _do_recover(delta: float) -> void:
	_recover_timer -= delta

	# Slow down and back away slightly
	velocity = velocity * 0.9
	if velocity.length() > 10:
		velocity = -velocity.normalized() * speed * 0.3

	if _recover_timer <= 0:
		if health < max_health * 0.3:
			state = State.FLEE
		else:
			state = State.PATROL
			_pick_patrol_target()

func _do_flee(delta: float) -> void:
	if not _current_target or not is_instance_valid(_current_target):
		state = State.PATROL
		return

	var flee_dir: Vector2 = (global_position - _current_target.global_position).normalized()
	velocity = flee_dir * speed * 1.3

	# Stop fleeing if far enough away
	var dist: float = global_position.distance_to(_current_target.global_position)
	if dist > detection_range * 1.5:
		state = State.PATROL
		_pick_patrol_target()

func _pick_patrol_target() -> void:
	_patrol_target = global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	_patrol_timer = randf_range(2.0, 4.0)

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]

func _draw() -> void:
	var health_ratio: float = health / max_health

	# Calculate body stretch for lunge
	var stretch: float = 1.0 + _lunge_stretch * 0.5
	var compress: float = 1.0 - _lunge_stretch * 0.3

	var length: float = _body_length * stretch
	var width: float = _body_width * compress

	# State-based color
	var draw_color: Color = _base_color
	match state:
		State.STALK:
			draw_color = _base_color.lerp(_accent_color, 0.3 + 0.2 * sin(_time * 8.0))
		State.LUNGE:
			draw_color = _accent_color
		State.RECOVER:
			draw_color = _base_color.lerp(Color(0.5, 0.5, 0.6), 0.3)
		State.FLEE:
			draw_color = _base_color.lerp(Color(0.7, 0.7, 0.3), 0.4)

	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)

	# Body glow
	var glow_alpha: float = 0.08 + 0.05 * sin(_time * 4.0)
	if state == State.LUNGE:
		glow_alpha = 0.2
	draw_circle(Vector2.ZERO, length * 0.8, Color(draw_color.r, draw_color.g, draw_color.b, glow_alpha))

	# Main body - sleek torpedo shape
	var body_pts: PackedVector2Array = PackedVector2Array()
	# Pointed nose
	body_pts.append(Vector2(length * 0.6, 0))
	# Top curve
	for i in range(8):
		var t: float = float(i) / 7.0
		var x: float = lerpf(length * 0.4, -length * 0.5, t)
		var w: float = width * sin(t * PI) * 0.9
		body_pts.append(Vector2(x, -w))
	# Tail point
	body_pts.append(Vector2(-length * 0.6, 0))
	# Bottom curve (reverse)
	for i in range(7, -1, -1):
		var t: float = float(i) / 7.0
		var x: float = lerpf(length * 0.4, -length * 0.5, t)
		var w: float = width * sin(t * PI) * 0.9
		body_pts.append(Vector2(x, w))

	# Fill body
	var fill_color := Color(draw_color.r * 0.5, draw_color.g * 0.4, draw_color.b * 0.6, 0.85)
	draw_colored_polygon(body_pts, fill_color)

	# Body outline
	for i in range(body_pts.size()):
		draw_line(body_pts[i], body_pts[(i + 1) % body_pts.size()], draw_color, 1.5, true)

	# Racing stripes (accent color)
	var stripe_y: float = width * 0.4
	draw_line(Vector2(length * 0.3, -stripe_y), Vector2(-length * 0.4, -stripe_y), Color(_accent_color, 0.6), 1.5, true)
	draw_line(Vector2(length * 0.3, stripe_y), Vector2(-length * 0.4, stripe_y), Color(_accent_color, 0.6), 1.5, true)

	# Dorsal fin
	var fin_wave: float = sin(_time * 6.0) * 2.0 if state != State.LUNGE else 0.0
	var fin_pts: PackedVector2Array = PackedVector2Array([
		Vector2(length * 0.1, -width * 0.8),
		Vector2(-length * 0.1, -width - 6.0 + fin_wave),
		Vector2(-length * 0.3, -width * 0.7),
	])
	draw_colored_polygon(fin_pts, Color(draw_color.r * 0.8, draw_color.g * 0.8, draw_color.b, 0.7))

	# Tail fin - V-shaped
	var tail_angle: float = sin(_time * 8.0) * 0.2 if state != State.LUNGE else 0.0
	draw_line(Vector2(-length * 0.5, 0), Vector2(-length * 0.7, -width * 0.6).rotated(tail_angle), _accent_color, 2.0, true)
	draw_line(Vector2(-length * 0.5, 0), Vector2(-length * 0.7, width * 0.6).rotated(-tail_angle), _accent_color, 2.0, true)

	# Speed lines when lunging
	if state == State.LUNGE:
		for i in range(4):
			var line_y: float = (i - 1.5) * width * 0.4
			var line_x: float = -length * 0.4 - i * 5.0
			var line_alpha: float = 0.4 + 0.2 * sin(_time * 15.0 + i)
			draw_line(Vector2(line_x, line_y), Vector2(line_x - 15.0, line_y), Color(0.5, 0.8, 1.0, line_alpha), 1.5, true)

	# Eyes - predator forward-facing
	_draw_face(length, width, draw_color)

	# Health ring
	if health_ratio < 1.0:
		draw_arc(Vector2.ZERO, length * 0.6, 0, TAU * health_ratio, 24, Color(1.0, 0.3, 0.1, 0.5), 1.5, true)

	# Stalk indicator - pulsing aura
	if state == State.STALK:
		var pulse: float = 0.1 + 0.1 * sin(_time * 6.0)
		draw_arc(Vector2.ZERO, length * 0.7, 0, TAU, 24, Color(_accent_color.r, _accent_color.g, _accent_color.b, pulse), 1.5, true)

func _draw_face(length: float, width: float, body_color: Color) -> void:
	# Eyes positioned on sides of head for predator look
	var eye_x: float = length * 0.25
	var eye_y_offset: float = width * 0.35
	var left_eye := Vector2(eye_x, -eye_y_offset)
	var right_eye := Vector2(eye_x, eye_y_offset)

	var eye_squash: float = 0.7  # Narrow predator eyes
	if _is_blinking:
		eye_squash = 0.1

	# Intense eye expression based on state
	var pupil_size: float = _eye_size * 0.5
	var iris_color := Color(0.9, 0.3, 0.1, 1.0)  # Predator red-orange

	match state:
		State.STALK:
			pupil_size *= 0.6  # Focused
			iris_color = iris_color.lerp(Color(1.0, 0.5, 0.1), 0.5)
		State.LUNGE:
			pupil_size *= 0.4  # Pinpoint focus
			eye_squash = 0.5  # Narrowed
		State.RECOVER:
			pupil_size *= 0.8
			eye_squash = 0.9
		State.FLEE:
			pupil_size *= 1.2  # Dilated
			eye_squash = 1.1

	for eye_pos in [left_eye, right_eye]:
		var ew: float = _eye_size
		var eh: float = _eye_size * eye_squash

		# Eye white
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			eye_pts.append(eye_pos + Vector2(cos(a) * ew, sin(a) * eh))
		draw_colored_polygon(eye_pts, Color(0.9, 0.85, 0.8, 0.95))

		# Iris/pupil
		var look_offset := Vector2(ew * 0.2, 0)  # Always looking forward
		if _current_target and is_instance_valid(_current_target):
			var to_target := (_current_target.global_position - global_position).normalized()
			look_offset = to_target.rotated(-rotation) * ew * 0.25
		draw_circle(eye_pos + look_offset, pupil_size, iris_color)
		draw_circle(eye_pos + look_offset, pupil_size * 0.5, Color(0.02, 0.02, 0.02, 1.0))

		# Highlight
		draw_circle(eye_pos + look_offset + Vector2(-pupil_size * 0.3, -pupil_size * 0.3), pupil_size * 0.25, Color(1, 1, 1, 0.8))

		# Eye outline
		for i in range(eye_pts.size()):
			draw_line(eye_pts[i], eye_pts[(i + 1) % eye_pts.size()], Color(0.2, 0.1, 0.1, 0.7), 0.8, true)

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	AudioManager.play_hurt()

	# Interrupt lunge on hit
	if state == State.LUNGE:
		state = State.RECOVER
		_recover_timer = 0.5

	if health <= 0:
		_die()

func _die() -> void:
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(4, 7), _accent_color)
	AudioManager.play_death()
	queue_free()

func confuse(duration: float) -> void:
	# Predators are harder to confuse - reduced duration
	state = State.RECOVER
	_recover_timer = duration * 0.5

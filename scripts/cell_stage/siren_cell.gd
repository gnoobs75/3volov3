extends CharacterBody2D
## Siren Cell: disguises itself as a food particle to lure prey.
## Looks like a shimmering golden biomolecule until something gets close, then
## it reveals its true form and lunges. Deceptive ambush predator.

enum State { DISGUISE, REVEAL, LUNGE, FEED, WANDER, FLEE }

var state: State = State.DISGUISE
var health: float = 35.0
var max_health: float = 35.0
var speed: float = 70.0
var lunge_speed: float = 350.0
var damage: float = 18.0
var detection_range: float = 100.0  # Short — ambush range
var lure_range: float = 250.0  # Draws prey from afar

var _time: float = 0.0
var _reveal_timer: float = 0.0
var _lunge_timer: float = 0.0
var _feed_timer: float = 0.0
var _wander_timer: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _lunge_dir: Vector2 = Vector2.ZERO
var _current_target: Node2D = null
var _attack_cooldown: float = 0.0
var _disguise_phase: float = 0.0  # 0=fully disguised, 1=fully revealed

# Procedural graphics
var _cell_radius: float = 10.0
var _true_radius: float = 16.0
var _base_color: Color
var _lure_color: Color  # Gold shimmer when disguised
var _damage_flash: float = 0.0
var _membrane_points: Array[Vector2] = []
const NUM_MEMBRANE_PTS: int = 20

# Face (hidden when disguised)
var _eye_size: float = 3.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _mouth_open: float = 0.0

func _ready() -> void:
	_init_shape()
	_pick_wander_target()
	add_to_group("enemies")
	_blink_timer = randf_range(2.0, 4.0)

func _init_shape() -> void:
	_cell_radius = randf_range(8.0, 12.0)
	_true_radius = _cell_radius * 1.5
	_eye_size = _true_radius * 0.2
	_lure_color = Color(
		randf_range(0.9, 1.0),
		randf_range(0.7, 0.9),
		randf_range(0.2, 0.4),
		0.9
	)
	_base_color = Color(
		randf_range(0.6, 0.8),
		randf_range(0.1, 0.25),
		randf_range(0.3, 0.5),
		0.95
	)
	_membrane_points.clear()
	for i in range(NUM_MEMBRANE_PTS):
		var angle: float = TAU * i / NUM_MEMBRANE_PTS
		var r: float = _true_radius + randf_range(-2.0, 2.0)
		_membrane_points.append(Vector2(cos(angle) * r, sin(angle) * r))

func _physics_process(delta: float) -> void:
	_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)

	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(1.5, 3.5)
		else:
			_is_blinking = true
			_blink_timer = 0.1

	var player := _find_player()
	var best_target: Node2D = null
	var best_dist: float = lure_range

	if player:
		var d: float = global_position.distance_to(player.global_position)
		if d < best_dist:
			best_dist = d
			best_target = player

	for prey in get_tree().get_nodes_in_group("prey"):
		var d: float = global_position.distance_to(prey.global_position)
		if d < best_dist:
			best_dist = d
			best_target = prey

	_current_target = best_target

	match state:
		State.DISGUISE:
			_do_disguise(delta, best_dist)
		State.REVEAL:
			_do_reveal(delta)
		State.LUNGE:
			_do_lunge(delta)
		State.FEED:
			_do_feed(delta)
		State.WANDER:
			_do_wander(delta)
		State.FLEE:
			_do_flee(delta)

	# Disguise phase interpolation
	if state == State.DISGUISE:
		_disguise_phase = maxf(_disguise_phase - delta * 2.0, 0.0)
	elif state != State.WANDER:
		_disguise_phase = minf(_disguise_phase + delta * 4.0, 1.0)

	_mouth_open = maxf(_mouth_open - delta * 3.0, 0.0)
	move_and_slide()

	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _do_disguise(delta: float, target_dist: float) -> void:
	# Sit still, shimmer like food. Gently bob.
	velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
	if _current_target and target_dist < detection_range:
		state = State.REVEAL
		_reveal_timer = 0.4

func _do_reveal(delta: float) -> void:
	_reveal_timer -= delta
	velocity = velocity.lerp(Vector2.ZERO, delta * 5.0)
	if _reveal_timer <= 0:
		if _current_target and is_instance_valid(_current_target):
			_lunge_dir = (global_position.direction_to(_current_target.global_position))
			state = State.LUNGE
			_lunge_timer = 0.25
			AudioManager.play_jet()
		else:
			state = State.WANDER

func _do_lunge(delta: float) -> void:
	_lunge_timer -= delta
	velocity = _lunge_dir * lunge_speed
	if _current_target and is_instance_valid(_current_target):
		var dist: float = global_position.distance_to(_current_target.global_position)
		if dist < _true_radius + 15.0:
			if _current_target.has_method("take_damage"):
				_current_target.take_damage(damage)
				_mouth_open = 1.0
				AudioManager.play_toxin()
			state = State.FEED
			_feed_timer = 1.0
			_attack_cooldown = 3.0
			return
	if _lunge_timer <= 0:
		state = State.WANDER
		_attack_cooldown = 2.0

func _do_feed(delta: float) -> void:
	_feed_timer -= delta
	velocity = velocity * 0.9
	if _feed_timer <= 0:
		if health < max_health * 0.3:
			state = State.FLEE
		else:
			state = State.WANDER
			_pick_wander_target()

func _do_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0 or global_position.distance_to(_wander_target) < 20:
		_pick_wander_target()
	velocity = global_position.direction_to(_wander_target) * speed * 0.3
	# Re-disguise after wandering a bit
	if _disguise_phase < 0.1 and _attack_cooldown <= 0:
		state = State.DISGUISE

func _do_flee(delta: float) -> void:
	if _current_target and is_instance_valid(_current_target):
		velocity = (_current_target.global_position.direction_to(global_position)) * speed * 1.3
		if global_position.distance_to(_current_target.global_position) > lure_range:
			state = State.WANDER
	else:
		state = State.WANDER

func _pick_wander_target() -> void:
	_wander_target = global_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
	_wander_timer = randf_range(3.0, 6.0)

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
	var r: float = lerpf(_cell_radius, _true_radius, _disguise_phase)
	var draw_color: Color = _lure_color.lerp(_base_color, _disguise_phase)

	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)

	if _disguise_phase < 0.5:
		# Disguised: draw as food particle (golden shimmer)
		_draw_disguised(r, draw_color)
	else:
		# Revealed: draw as predator
		_draw_revealed(r, draw_color)

	# Health ring
	var health_ratio: float = health / max_health
	if health_ratio < 1.0:
		draw_arc(Vector2.ZERO, r + 2.0, 0, TAU * health_ratio, 24, Color(1.0, 0.3, 0.1, 0.5), 1.5, true)

func _draw_disguised(r: float, color: Color) -> void:
	# Shimmering food-like particle
	var shimmer: float = 0.3 + 0.2 * sin(_time * 5.0)
	draw_circle(Vector2.ZERO, r * 1.4, Color(color.r, color.g, color.b, 0.08 + shimmer * 0.05))

	# Sparkle ring
	for i in range(6):
		var a: float = TAU * i / 6.0 + _time * 1.5
		var sp := Vector2(cos(a) * r * 1.2, sin(a) * r * 1.2)
		var sa: float = 0.3 + 0.3 * sin(_time * 8.0 + i)
		draw_circle(sp, 1.5, Color(1.0, 0.95, 0.6, sa))

	# Body - round, golden
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(12):
		var a: float = TAU * i / 12.0
		var wobble: float = sin(_time * 3.0 + i * 1.2) * 1.0
		pts.append(Vector2(cos(a) * (r + wobble), sin(a) * (r + wobble)))
	draw_colored_polygon(pts, Color(color.r * 0.5, color.g * 0.45, color.b * 0.3, 0.8))
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(color, 0.7), 1.0, true)

	# Faint eye hint (barely visible)
	var eye_hint_a: float = _disguise_phase * 0.3
	if eye_hint_a > 0.05:
		draw_circle(Vector2(r * 0.2, -r * 0.15), 1.5, Color(0.9, 0.1, 0.1, eye_hint_a))
		draw_circle(Vector2(r * 0.2, r * 0.15), 1.5, Color(0.9, 0.1, 0.1, eye_hint_a))

func _draw_revealed(r: float, color: Color) -> void:
	# Predator form with jagged membrane
	draw_circle(Vector2.ZERO, r * 1.6, Color(color.r, color.g, color.b, 0.06))

	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(NUM_MEMBRANE_PTS):
		var scale_f: float = r / _true_radius
		var wobble: float = sin(_time * 5.0 + i * 0.8) * 1.5
		pts.append(_membrane_points[i] * scale_f + _membrane_points[i].normalized() * wobble)
	draw_colored_polygon(pts, Color(color.r * 0.35, color.g * 0.25, color.b * 0.35, 0.8))
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(color, 0.85), 1.3, true)

	# Nucleus
	draw_circle(Vector2(sin(_time) * 1.5, cos(_time * 0.7) * 1.5), r * 0.25, Color(0.3, 0.08, 0.15, 0.8))

	# Face
	var eye_y: float = r * 0.2
	var eye_x: float = r * 0.15
	var eye_squash: float = 0.7 if not _is_blinking else 0.08
	for idx in range(2):
		var ep := Vector2(eye_x, -eye_y if idx == 0 else eye_y)
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			eye_pts.append(ep + Vector2(cos(a) * _eye_size, sin(a) * _eye_size * eye_squash))
		draw_colored_polygon(eye_pts, Color(0.95, 0.9, 0.85, 0.95))
		if not _is_blinking:
			draw_circle(ep, _eye_size * 0.45, Color(0.8, 0.15, 0.1, 1.0))
			draw_circle(ep, _eye_size * 0.2, Color(0.05, 0.02, 0.02, 1.0))
			draw_circle(ep + Vector2(-0.3, -0.3), _eye_size * 0.12, Color(1, 1, 1, 0.7))

	# Angry brows
	draw_line(Vector2(eye_x - _eye_size, -eye_y - _eye_size * 1.2), Vector2(eye_x + _eye_size, -eye_y - _eye_size * 0.4), Color(0.3, 0.08, 0.1, 0.9), 1.8, true)
	draw_line(Vector2(eye_x - _eye_size, eye_y - _eye_size * 0.4), Vector2(eye_x + _eye_size, eye_y - _eye_size * 1.2), Color(0.3, 0.08, 0.1, 0.9), 1.8, true)

	# Mouth
	if _mouth_open > 0.1:
		var mp := Vector2(r * 0.4, 0)
		var mo_h: float = 2.0 + _mouth_open * 4.0
		var mo_w: float = 2.0 + _mouth_open * 3.0
		var mo_pts: PackedVector2Array = PackedVector2Array()
		for i in range(8):
			var a: float = TAU * i / 8.0
			mo_pts.append(mp + Vector2(cos(a) * mo_w * 0.5, sin(a) * mo_h))
		draw_colored_polygon(mo_pts, Color(0.15, 0.02, 0.08, 0.95))
	else:
		var mp := Vector2(r * 0.35, 0)
		draw_line(mp + Vector2(0, -3), mp + Vector2(2, 0), Color(0.2, 0.05, 0.1, 0.8), 1.5, true)
		draw_line(mp + Vector2(2, 0), mp + Vector2(0, 3), Color(0.2, 0.05, 0.1, 0.8), 1.5, true)

	# Lunge speed lines
	if state == State.LUNGE:
		for i in range(3):
			var ly: float = (i - 1) * r * 0.5
			var lx: float = -r * 0.5 - i * 4.0
			draw_line(Vector2(lx, ly), Vector2(lx - 12.0, ly), Color(0.5, 0.8, 1.0, 0.4), 1.5, true)

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	_mouth_open = 0.5
	# Taking damage breaks disguise
	if state == State.DISGUISE:
		_disguise_phase = 0.8
		state = State.WANDER
	if health <= 0:
		_die()

func _die() -> void:
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(3, 6), _base_color)
	AudioManager.play_death()
	queue_free()

func confuse(duration: float) -> void:
	_disguise_phase = 1.0
	state = State.WANDER
	_wander_timer = duration

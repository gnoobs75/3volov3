extends CharacterBody2D
## Splitter Cell: divides into 2 smaller copies when killed.
## Each generation is smaller and weaker. Max 2 splits (3 generations).
## Comical mitosis animation on death.

enum State { WANDER, PURSUE, FLEE, CONFUSED }

var state: State = State.WANDER
var health: float = 40.0
var max_health: float = 40.0
var speed: float = 90.0
var damage: float = 6.0
var detection_range: float = 200.0
var attack_range: float = 35.0

var generation: int = 0  # 0=full, 1=half, 2=quarter (no more splits)
const MAX_GENERATION: int = 2

var _time: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _confused_timer: float = 0.0
var _attack_cooldown: float = 0.0

# Procedural graphics
var _cell_radius: float = 16.0
var _base_color: Color
var _damage_flash: float = 0.0
var _split_flash: float = 0.0  # Visual wobble before splitting

# Face
var _eye_size: float = 3.5
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _worry_amount: float = 0.0  # Gets worried when low health (knows it's about to split)

# Mitosis visual
var _pinch_amount: float = 0.0  # 0-1, how much the cell is pinching in the middle

func _ready() -> void:
	_init_shape()
	_pick_wander_target()
	add_to_group("enemies")
	_blink_timer = randf_range(1.5, 4.0)

func _init_shape() -> void:
	var gen_scale: float = 1.0 - generation * 0.3  # Each gen is 30% smaller
	_cell_radius = randf_range(14.0, 18.0) * gen_scale
	_eye_size = _cell_radius * 0.22
	health = max_health * gen_scale
	max_health = health
	damage *= gen_scale
	speed += generation * 20.0  # Smaller = faster

	# Green/teal colors (cell division theme)
	_base_color = Color(
		randf_range(0.15, 0.35),
		randf_range(0.6, 0.85),
		randf_range(0.3, 0.5),
		0.95
	)

func setup_generation(gen: int, color: Color) -> void:
	generation = gen
	_base_color = color.lerp(Color(0.8, 0.9, 0.3), gen * 0.15)
	_init_shape()

func _physics_process(delta: float) -> void:
	_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
	_split_flash = maxf(_split_flash - delta * 2.0, 0.0)

	if _confused_timer > 0:
		_confused_timer -= delta
		if _confused_timer <= 0:
			state = State.WANDER

	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(1.0, 3.0)
		else:
			_is_blinking = true
			_blink_timer = 0.1

	# Worry when low health
	var health_ratio: float = health / max_health
	_worry_amount = clampf((1.0 - health_ratio) * 2.0, 0.0, 1.0)
	# Pinch when very low health (visual foreshadowing)
	_pinch_amount = clampf((1.0 - health_ratio - 0.5) * 2.0, 0.0, 0.3)

	var player := _find_player()
	if state != State.CONFUSED:
		if player:
			var dist: float = global_position.distance_to(player.global_position)
			if health_ratio < 0.3:
				state = State.FLEE
			elif dist < detection_range:
				state = State.PURSUE
			else:
				state = State.WANDER
		else:
			state = State.WANDER

	match state:
		State.WANDER: _do_wander(delta)
		State.PURSUE: _do_pursue(delta, player)
		State.FLEE: _do_flee(delta, player)
		State.CONFUSED: _do_confused(delta)

	move_and_slide()
	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _do_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0 or global_position.distance_to(_wander_target) < 20:
		_pick_wander_target()
	velocity = velocity.lerp(global_position.direction_to(_wander_target) * speed * 0.4, delta * 3.0)

func _do_pursue(delta: float, player: Node2D) -> void:
	if not player:
		state = State.WANDER
		return
	velocity = velocity.lerp(global_position.direction_to(player.global_position) * speed, delta * 3.0)
	if global_position.distance_to(player.global_position) < attack_range and _attack_cooldown <= 0:
		if player.has_method("take_damage"):
			player.take_damage(damage)
			_attack_cooldown = 0.5

func _do_flee(delta: float, player: Node2D) -> void:
	if not player:
		state = State.WANDER
		return
	velocity = velocity.lerp(player.global_position.direction_to(global_position) * speed * 1.2, delta * 3.0)

func _do_confused(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0:
		_wander_target = global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		_wander_timer = randf_range(0.3, 0.6)
	velocity = velocity.lerp(global_position.direction_to(_wander_target) * speed * 0.3, delta * 3.0)

func _pick_wander_target() -> void:
	_wander_target = global_position + Vector2(randf_range(-180, 180), randf_range(-180, 180))
	_wander_timer = randf_range(2.0, 4.0)

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
		State.PURSUE:
			draw_color = _base_color.lerp(Color(0.8, 0.4, 0.2), 0.3)
		State.FLEE:
			draw_color = _base_color.lerp(Color(0.9, 0.9, 0.3), 0.4)
		State.CONFUSED:
			draw_color = _base_color.lerp(Color(0.5, 0.7, 0.3), 0.3)

	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)

	# Glow
	draw_circle(Vector2.ZERO, _cell_radius * 1.6, Color(draw_color.r, draw_color.g, draw_color.b, 0.06))

	# Body - with pinch deformation when low health
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(20):
		var angle: float = TAU * i / 20.0
		var r: float = _cell_radius
		r += sin(angle * 3.0 + _time * 2.0) * 1.5
		# Pinch at the equator (vertical axis) to show mitosis starting
		var pinch: float = _pinch_amount * (1.0 - abs(cos(angle))) * _cell_radius * 0.4
		r -= pinch
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))

	draw_colored_polygon(pts, Color(draw_color.r * 0.35, draw_color.g * 0.35, draw_color.b * 0.3, 0.8))
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(draw_color, 0.85), 1.3, true)

	# Two nuclei (visible hint that this cell splits)
	var nuc_sep: float = _cell_radius * 0.2 + _pinch_amount * _cell_radius * 0.3
	var nuc_r: float = _cell_radius * 0.2
	draw_circle(Vector2(0, -nuc_sep), nuc_r, Color(0.1, 0.3, 0.15, 0.8))
	draw_circle(Vector2(0, nuc_sep), nuc_r, Color(0.1, 0.3, 0.15, 0.8))

	# DNA strands connecting nuclei
	for s in range(3):
		var sx: float = sin(_time * 3.0 + s * 2.0) * 2.0
		var sy: float = lerpf(-nuc_sep, nuc_sep, (s + 1.0) / 4.0)
		draw_circle(Vector2(sx, sy), 0.8, Color(0.3, 0.7, 0.4, 0.5))

	# Face - worried expression when about to split
	_draw_face(draw_color)

	# Health ring
	if health_ratio < 1.0:
		draw_arc(Vector2.ZERO, _cell_radius + 2.0, 0, TAU * health_ratio, 24, Color(draw_color.r, draw_color.g * 0.8, 0.2, 0.5), 1.5, true)

	# Generation indicator dots
	for g in range(generation + 1):
		var gx: float = -_cell_radius - 4.0 - g * 3.0
		draw_circle(Vector2(gx, 0), 1.5, Color(0.5, 0.9, 0.4, 0.6))

	# Confused stars
	if state == State.CONFUSED:
		for s in range(3):
			var sa: float = _time * 4.0 + TAU * s / 3.0
			var star_pos := Vector2(-_cell_radius - 3.0, 0) + Vector2(cos(sa) * 5.0, sin(sa) * 5.0)
			draw_circle(star_pos, 1.5, Color(1.0, 1.0, 0.3, 0.5 + 0.3 * sin(_time * 6.0 + s)))

func _draw_face(color: Color) -> void:
	var eye_x: float = _cell_radius * 0.15
	var eye_y: float = _cell_radius * 0.2
	var le := Vector2(eye_x, -eye_y)
	var re := Vector2(eye_x, eye_y)
	var eye_squash: float = 0.8 if not _is_blinking else 0.08

	# Worried eyes get rounder
	if _worry_amount > 0.3:
		eye_squash = lerpf(eye_squash, 1.3, _worry_amount) if not _is_blinking else 0.08

	for idx in range(2):
		var ep: Vector2 = le if idx == 0 else re
		var er: float = _eye_size * (1.0 + _worry_amount * 0.3)
		var eh: float = er * eye_squash
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			eye_pts.append(ep + Vector2(cos(a) * er, sin(a) * eh))
		draw_colored_polygon(eye_pts, Color(0.95, 0.95, 0.9, 0.95))
		if not _is_blinking:
			var pupil_r: float = _eye_size * 0.4
			# Tiny worried pupils when low health
			if _worry_amount > 0.5:
				pupil_r *= 0.5
			draw_circle(ep, pupil_r, Color(0.1, 0.2, 0.08, 1.0))
			draw_circle(ep + Vector2(-0.3, -0.3), pupil_r * 0.3, Color(1, 1, 1, 0.6))

	# Eyebrows - worried arch
	var brow_worry: float = _worry_amount * 0.5
	draw_line(le + Vector2(-_eye_size, -_eye_size * (0.5 + brow_worry)), le + Vector2(_eye_size, -_eye_size * 0.8), Color(0.15, 0.3, 0.15, 0.8), 1.5, true)
	draw_line(re + Vector2(-_eye_size, -_eye_size * 0.8), re + Vector2(_eye_size, -_eye_size * (0.5 + brow_worry)), Color(0.15, 0.3, 0.15, 0.8), 1.5, true)

	# Mouth - wavy worry line
	var mp := Vector2(_cell_radius * 0.35, 0)
	var worry_wave: float = sin(_time * 6.0) * _worry_amount * 1.5
	draw_line(mp + Vector2(0, -2.5), mp + Vector2(1.0, worry_wave), Color(0.15, 0.25, 0.12, 0.8), 1.5, true)
	draw_line(mp + Vector2(1.0, worry_wave), mp + Vector2(0, 2.5), Color(0.15, 0.25, 0.12, 0.8), 1.5, true)

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if health <= 0:
		_die()

func _die() -> void:
	if generation < MAX_GENERATION:
		# SPLIT: spawn 2 smaller copies
		_spawn_children()
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		var drops: int = randi_range(1, 3) if generation > 0 else randi_range(2, 4)
		manager.spawn_death_nutrients(global_position, drops, _base_color)
	AudioManager.play_death()
	queue_free()

func _spawn_children() -> void:
	var SplitterScene := preload("res://scenes/splitter_cell.tscn")
	for i in range(2):
		var child := SplitterScene.instantiate()
		var offset: Vector2 = Vector2(0, 15.0 if i == 0 else -15.0).rotated(randf() * TAU)
		child.global_position = global_position + offset
		child.setup_generation(generation + 1, _base_color)
		child.velocity = offset.normalized() * 100.0  # Fling apart
		get_parent().add_child(child)

func confuse(duration: float) -> void:
	state = State.CONFUSED
	_confused_timer = duration

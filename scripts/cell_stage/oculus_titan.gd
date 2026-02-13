extends CharacterBody2D
## Oculus Titan: Boss 1 (spawns after 3rd evolution).
## Massive creature covered in eyes. Cannot be killed by normal damage.
## Player must use tractor beam (LMB) to suck each eye off one by one.
## Each eye removed weakens it. Remove all eyes to kill it.
## Eyes are beamable targets in "food" group temporarily when exposed.

enum State { IDLE, APPROACH, STARE, THRASH, WEAKENED, DYING }

var state: State = State.IDLE
var speed: float = 40.0
var damage: float = 12.0
var detection_range: float = 350.0
var attack_range: float = 60.0

var _time: float = 0.0
var _state_timer: float = 0.0
var _current_target: Node2D = null
var _damage_flash: float = 0.0
var _voice_cooldown: float = 0.0

# Eye system
var _eyes: Array = []  # [{angle, dist, size, alive, wobble_phase, blink_timer, is_blinking, detach_progress}]
var _total_eyes: int = 12
var _eyes_remaining: int = 12
var _eye_nodes: Array = []  # Area2D nodes for beam targeting
const EYE_DETACH_THRESHOLD: float = 1.0  # Beam time to detach

# Body
var _body_radius: float = 40.0
var _base_color: Color
var _membrane_points: Array[Vector2] = []
const NUM_MEMBRANE_PTS: int = 32

# Thrash attack
var _thrash_dir: Vector2 = Vector2.ZERO
var _thrash_speed: float = 200.0

func _ready() -> void:
	_init_shape()
	_spawn_eyes()
	add_to_group("enemies")
	add_to_group("bosses")

func _init_shape() -> void:
	_body_radius = randf_range(38.0, 45.0)
	_base_color = Color(
		randf_range(0.5, 0.7),
		randf_range(0.2, 0.35),
		randf_range(0.3, 0.5),
		0.95
	)
	_membrane_points.clear()
	for i in range(NUM_MEMBRANE_PTS):
		var angle: float = TAU * i / NUM_MEMBRANE_PTS
		var r: float = _body_radius + randf_range(-3.0, 5.0)
		_membrane_points.append(Vector2(cos(angle) * r, sin(angle) * r))

func _spawn_eyes() -> void:
	_eyes.clear()
	for _node in _eye_nodes:
		if is_instance_valid(_node):
			_node.queue_free()
	_eye_nodes.clear()

	_total_eyes = randi_range(10, 14)
	_eyes_remaining = _total_eyes
	for i in range(_total_eyes):
		var angle: float = TAU * i / _total_eyes + randf_range(-0.15, 0.15)
		var dist: float = _body_radius * randf_range(0.3, 0.7)
		var size: float = randf_range(4.0, 7.0)
		_eyes.append({
			"angle": angle,
			"dist": dist,
			"size": size,
			"alive": true,
			"wobble_phase": randf() * TAU,
			"blink_timer": randf_range(2.0, 5.0),
			"is_blinking": false,
			"detach_progress": 0.0,
		})
		# Create beamable Area2D for this eye
		var eye_area := Area2D.new()
		eye_area.add_to_group("boss_eyes")
		eye_area.set_meta("eye_index", i)
		eye_area.set_meta("boss", self)
		# Make it beamable like food
		eye_area.add_to_group("food")
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = size + 3.0
		shape.shape = circle
		eye_area.add_child(shape)
		# Add beam interaction script
		var EyeScript := preload("res://scripts/cell_stage/boss_eye_node.gd")
		eye_area.set_script(EyeScript)
		add_child(eye_area)
		_eye_nodes.append(eye_area)
		_update_eye_position(i)

func _update_eye_position(idx: int) -> void:
	if idx >= _eyes.size() or idx >= _eye_nodes.size():
		return
	var eye: Dictionary = _eyes[idx]
	if not eye.alive:
		return
	var pos := Vector2(cos(eye.angle) * eye.dist, sin(eye.angle) * eye.dist)
	if is_instance_valid(_eye_nodes[idx]):
		_eye_nodes[idx].position = pos

func _on_eye_being_pulled(idx: int, progress: float) -> void:
	if idx >= _eyes.size() or not _eyes[idx].alive:
		return
	_eyes[idx].detach_progress = progress
	if progress >= EYE_DETACH_THRESHOLD:
		_remove_eye(idx)

func _on_eye_release(idx: int) -> void:
	if idx >= _eyes.size():
		return
	_eyes[idx].detach_progress = 0.0

func _remove_eye(idx: int) -> void:
	_eyes[idx].alive = false
	_eyes[idx].detach_progress = 0.0
	_eyes_remaining -= 1
	# Remove the Area2D
	if idx < _eye_nodes.size() and is_instance_valid(_eye_nodes[idx]):
		_eye_nodes[idx].remove_from_group("food")
		_eye_nodes[idx].queue_free()
	AudioManager.play_hurt()
	# React to eye loss
	if _eyes_remaining <= 0:
		state = State.DYING
		_state_timer = 2.0
	elif _eyes_remaining <= _total_eyes * 0.5:
		state = State.THRASH
		_state_timer = 2.0
		_thrash_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	# Spawn a nutrient from the eye
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		var eye_pos: Vector2 = global_position + Vector2(cos(_eyes[idx].angle) * _eyes[idx].dist, sin(_eyes[idx].angle) * _eyes[idx].dist)
		manager.spawn_death_nutrients(eye_pos, 1, Color(0.9, 0.3, 0.3))

func _physics_process(delta: float) -> void:
	_time += delta
	_damage_flash = maxf(_damage_flash - delta * 3.0, 0.0)
	_voice_cooldown = maxf(_voice_cooldown - delta, 0.0)

	var player := _find_player()
	_current_target = player

	# Eye blink timers
	for eye in _eyes:
		if not eye.alive:
			continue
		eye.blink_timer -= delta
		if eye.blink_timer <= 0:
			if eye.is_blinking:
				eye.is_blinking = false
				eye.blink_timer = randf_range(1.5, 4.0)
			else:
				eye.is_blinking = true
				eye.blink_timer = 0.12

	# Update eye Area2D positions
	for i in range(_eyes.size()):
		_update_eye_position(i)

	match state:
		State.IDLE:
			velocity = velocity.lerp(Vector2.ZERO, delta * 2.0)
			if player and global_position.distance_to(player.global_position) < detection_range:
				state = State.APPROACH
				if _voice_cooldown <= 0.0:
					AudioManager.play_creature_voice("oculus_titan", "alert", 2.0, 0.85, 0.6)
					_voice_cooldown = 3.0
		State.APPROACH:
			_do_approach(delta, player)
		State.STARE:
			_do_stare(delta)
		State.THRASH:
			_do_thrash(delta)
		State.WEAKENED:
			velocity = velocity * 0.95
			_state_timer -= delta
			if _state_timer <= 0:
				state = State.APPROACH
		State.DYING:
			_do_dying(delta)

	move_and_slide()
	queue_redraw()

func _do_approach(delta: float, player: Node2D) -> void:
	if not player:
		state = State.IDLE
		return
	var dist: float = global_position.distance_to(player.global_position)
	velocity = velocity.lerp(global_position.direction_to(player.global_position) * speed, delta * 1.0)
	if dist < attack_range:
		state = State.STARE
		_state_timer = 3.0
	if dist > detection_range * 1.3:
		state = State.IDLE

func _do_stare(delta: float) -> void:
	_state_timer -= delta
	velocity = velocity * 0.95
	# Damage player if touching
	if _current_target and is_instance_valid(_current_target):
		if global_position.distance_to(_current_target.global_position) < _body_radius + 20:
			if _current_target.has_method("take_damage"):
				_current_target.take_damage(damage * delta)
	if _state_timer <= 0:
		state = State.APPROACH

func _do_thrash(delta: float) -> void:
	_state_timer -= delta
	velocity = _thrash_dir * _thrash_speed
	# Random direction changes
	if randf() < delta * 3.0:
		_thrash_dir = _thrash_dir.rotated(randf_range(-1.0, 1.0))
	# Damage anything nearby during thrash
	if _current_target and is_instance_valid(_current_target):
		if global_position.distance_to(_current_target.global_position) < _body_radius + 30:
			if _current_target.has_method("take_damage"):
				_current_target.take_damage(damage * 1.5 * delta)
	if _state_timer <= 0:
		state = State.WEAKENED
		_state_timer = 2.0

func _do_dying(delta: float) -> void:
	_state_timer -= delta
	velocity = velocity * 0.9
	if _state_timer <= 0:
		_die()

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
	var draw_color: Color = _base_color
	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)

	# Ominous outer glow
	var glow_a: float = 0.08 + 0.04 * sin(_time * 2.0)
	draw_circle(Vector2.ZERO, _body_radius * 2.0, Color(draw_color.r, draw_color.g, draw_color.b, glow_a))
	draw_circle(Vector2.ZERO, _body_radius * 1.5, Color(draw_color.r, draw_color.g, draw_color.b, glow_a * 2.0))

	# Tentacles radiating
	for i in range(8):
		var base_a: float = TAU * i / 8.0 + _time * 0.1
		var base_pt := Vector2(cos(base_a), sin(base_a)) * _body_radius * 0.9
		var prev: Vector2 = base_pt
		for s in range(6):
			var t: float = float(s + 1) / 6.0
			var wave: float = sin(_time * 2.5 + i * 0.7 + t * 3.0) * 10.0 * t
			var seg_angle: float = base_a + wave * 0.02
			var next: Vector2 = base_pt + Vector2(cos(seg_angle), sin(seg_angle)) * t * 30.0
			next += Vector2(-sin(seg_angle), cos(seg_angle)) * wave
			var w: float = 3.0 * (1.0 - t * 0.6)
			draw_line(prev, next, Color(draw_color, 0.6 - t * 0.3), w, true)
			prev = next

	# Main body
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(NUM_MEMBRANE_PTS):
		var wobble: float = sin(_time * 3.0 + i * 0.7) * 2.0
		var thrash_wobble: float = 0.0
		if state == State.THRASH:
			thrash_wobble = sin(_time * 15.0 + i * 1.5) * 4.0
		pts.append(_membrane_points[i] + _membrane_points[i].normalized() * (wobble + thrash_wobble))
	draw_colored_polygon(pts, Color(draw_color.r * 0.3, draw_color.g * 0.25, draw_color.b * 0.35, 0.85))
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(draw_color, 0.8), 2.5, true)

	# Inner organelle texture
	for i in range(6):
		var a: float = TAU * i / 6.0 + _time * 0.08
		var d: float = _body_radius * 0.4 + sin(_time + i) * 5.0
		draw_circle(Vector2(cos(a) * d, sin(a) * d), 5.0, Color(0.25, 0.15, 0.3, 0.3))

	# Eyes
	for eye in _eyes:
		if not eye.alive:
			continue
		var ep := Vector2(cos(eye.angle) * eye.dist, sin(eye.angle) * eye.dist)
		# Wobble
		ep += Vector2(sin(_time * 2.0 + eye.wobble_phase) * 1.5, cos(_time * 1.8 + eye.wobble_phase) * 1.5)

		var eye_r: float = eye.size
		var eye_squash: float = 0.8 if not eye.is_blinking else 0.08

		# Detach visual: eye stretches outward when being pulled
		if eye.detach_progress > 0:
			var stretch: float = eye.detach_progress / EYE_DETACH_THRESHOLD
			ep += ep.normalized() * stretch * 8.0
			eye_r *= (1.0 + stretch * 0.3)
			# Red warning glow
			draw_circle(ep, eye_r * 1.5, Color(1.0, 0.2, 0.1, stretch * 0.3))

		# Eye socket shadow
		draw_circle(ep + Vector2(1, 1), eye_r * 1.1, Color(0.1, 0.05, 0.15, 0.4))

		# Eye white
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for j in range(12):
			var a: float = TAU * j / 12.0
			eye_pts.append(ep + Vector2(cos(a) * eye_r, sin(a) * eye_r * eye_squash))
		draw_colored_polygon(eye_pts, Color(0.92, 0.88, 0.82, 0.95))

		if eye_squash > 0.2:
			# Iris
			var iris_r: float = eye_r * 0.65
			draw_circle(ep, iris_r, Color(0.6, 0.2, 0.3, 1.0))
			# Pupil - looks at player
			var pupil_offset := Vector2.ZERO
			if _current_target and is_instance_valid(_current_target):
				var to_player: Vector2 = (_current_target.global_position - global_position).normalized()
				pupil_offset = to_player * eye_r * 0.15
			draw_circle(ep + pupil_offset, iris_r * 0.4, Color(0.02, 0.02, 0.02, 1.0))
			# Highlight
			draw_circle(ep + pupil_offset + Vector2(-eye_r * 0.15, -eye_r * 0.15), eye_r * 0.12, Color(1, 1, 1, 0.7))

		# Eye outline
		for j in range(eye_pts.size()):
			draw_line(eye_pts[j], eye_pts[(j + 1) % eye_pts.size()], Color(0.3, 0.15, 0.2, 0.7), 1.0, true)

	# Eye count indicator
	var count_y: float = -_body_radius - 15.0
	var count_text: String = str(_eyes_remaining) + "/" + str(_total_eyes)
	draw_string(ThemeDB.fallback_font, Vector2(-12, count_y), count_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.9, 0.3, 0.3, 0.8))

	# Dying: red flash and shrink
	if state == State.DYING:
		var die_t: float = 1.0 - _state_timer / 2.0
		draw_circle(Vector2.ZERO, _body_radius * (1.0 + die_t * 0.3), Color(1.0, 0.2, 0.1, die_t * 0.4))

	# Boss health indicator (eyes remaining as bar)
	var eye_ratio: float = float(_eyes_remaining) / float(_total_eyes)
	var bar_w: float = _body_radius * 1.5
	var bar_y: float = _body_radius + 8.0
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, 4), Color(0.2, 0.1, 0.15, 0.5))
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * eye_ratio, 4), Color(0.9, 0.3, 0.4, 0.8))

func take_damage(amount: float) -> void:
	# Normal damage barely affects the Oculus Titan
	_damage_flash = 0.5
	if _voice_cooldown <= 0.0:
		AudioManager.play_creature_voice("oculus_titan", "hurt", 2.0, 0.85, 0.6)
		_voice_cooldown = 2.5
	# Only thrash reaction, no health loss (must remove eyes)
	if state == State.APPROACH or state == State.STARE:
		state = State.THRASH
		_state_timer = 1.0
		_thrash_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _die() -> void:
	AudioManager.play_creature_voice("oculus_titan", "death", 2.0, 0.85, 0.6)
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(12, 18), _base_color)
	if manager and manager.has_method("_on_boss_defeated"):
		manager._on_boss_defeated("oculus_titan")
	AudioManager.play_death()
	# Clean up eye nodes
	for node in _eye_nodes:
		if is_instance_valid(node):
			node.queue_free()
	queue_free()

func confuse(_duration: float) -> void:
	# Boss resists confusion
	pass

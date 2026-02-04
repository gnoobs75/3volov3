extends CharacterBody2D
## Competitor cell: neutral AI that hunts biomolecules, creating food rivalry.
## Has its own comical face that reacts to finding/losing food.

enum State { HUNT, EATING, WANDER, STARTLED }

var state: State = State.WANDER
var health: float = 40.0
var max_health: float = 40.0
var speed: float = 90.0
var detection_range: float = 180.0
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var food_target: Node2D = null
var eat_timer: float = 0.0
var startled_timer: float = 0.0
var collected_count: int = 0

# Procedural
var _time: float = 0.0
var _cell_radius: float = 12.0
var _base_color: Color
var _membrane_points: Array[Vector2] = []
var _damage_flash: float = 0.0
const NUM_MEMBRANE_PTS: int = 20

# Face
var _eye_spacing: float = 0.0
var _eye_size: float = 0.0
var _pupil_size: float = 0.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _mouth_open: float = 0.0
var _smugness: float = 0.0  # Increases when it steals food near player

func _ready() -> void:
	_init_shape()
	_randomize_face()
	add_to_group("competitors")
	_pick_wander_target()

func _randomize_face() -> void:
	_eye_spacing = randf_range(3.5, 5.5)
	_eye_size = randf_range(2.5, 3.8)
	_pupil_size = randf_range(1.0, 1.8)
	_blink_timer = randf_range(1.0, 3.0)

func _init_shape() -> void:
	_membrane_points.clear()
	for i in range(NUM_MEMBRANE_PTS):
		var angle: float = TAU * i / NUM_MEMBRANE_PTS
		var r: float = _cell_radius + randf_range(-1.5, 1.5)
		_membrane_points.append(Vector2(cos(angle) * r, sin(angle) * r))
	# Greenish-yellow tones (neutral, not hostile)
	_base_color = Color(
		randf_range(0.6, 0.85),
		randf_range(0.7, 0.95),
		randf_range(0.15, 0.4)
	)

var _prey_target: Node2D = null
var _prey_attack_cooldown: float = 0.0
var _parasite_target: Node2D = null
var _cleaning_player: bool = false

func _physics_process(delta: float) -> void:
	_prey_attack_cooldown = maxf(_prey_attack_cooldown - delta, 0.0)
	match state:
		State.WANDER:
			_do_wander(delta)
			_scan_for_parasites()
			if state == State.WANDER:
				_scan_for_food()
			if state == State.WANDER:
				_scan_for_prey()
		State.HUNT:
			_do_hunt(delta)
		State.EATING:
			eat_timer -= delta
			velocity = Vector2.ZERO
			if eat_timer <= 0:
				state = State.WANDER
		State.STARTLED:
			startled_timer -= delta
			# Flee from player briefly
			var player := _find_player()
			if player:
				velocity = player.global_position.direction_to(global_position) * speed * 1.3
			if startled_timer <= 0:
				state = State.WANDER

	move_and_slide()
	_time += delta
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
	_mouth_open = maxf(_mouth_open - delta * 2.5, 0.0)
	_smugness = maxf(_smugness - delta * 0.5, 0.0)

	# Blink
	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(1.5, 3.5)
		else:
			_is_blinking = true
			_blink_timer = 0.12
	queue_redraw()

func _do_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0 or global_position.distance_to(wander_target) < 20:
		_pick_wander_target()
	velocity = global_position.direction_to(wander_target) * speed * 0.4

func _scan_for_food() -> void:
	var foods := get_tree().get_nodes_in_group("food")
	var best_dist: float = detection_range
	food_target = null
	for f in foods:
		var d: float = global_position.distance_to(f.global_position)
		if d < best_dist:
			best_dist = d
			food_target = f
	if food_target:
		state = State.HUNT

func _scan_for_prey() -> void:
	_prey_target = null
	var close_range: float = detection_range * 0.9  # Chase prey when fairly close
	var best_dist: float = close_range
	for p in get_tree().get_nodes_in_group("prey"):
		var d: float = global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			_prey_target = p
	if _prey_target:
		state = State.HUNT

func _scan_for_parasites() -> void:
	_parasite_target = null
	_cleaning_player = false
	var player := _find_player()
	if not player or not "attached_parasites" in player:
		return
	if player.attached_parasites.size() == 0:
		return
	# Only if we're somewhat near the player
	if global_position.distance_to(player.global_position) > detection_range * 1.2:
		return
	# Target a random attached parasite
	for p in player.attached_parasites:
		if is_instance_valid(p):
			_parasite_target = p
			_cleaning_player = true
			state = State.HUNT
			break

func _do_hunt(delta: float) -> void:
	# Hunting attached parasites (cleaner behavior)
	if _cleaning_player and _parasite_target:
		if not is_instance_valid(_parasite_target):
			_parasite_target = null
			_cleaning_player = false
			state = State.WANDER
			return
		var dist := global_position.distance_to(_parasite_target.global_position)
		velocity = global_position.direction_to(_parasite_target.global_position) * speed * 0.9
		if dist < 15.0:
			# Eat the parasite off the player
			_mouth_open = 1.0
			_smugness = 0.8
			if _parasite_target.has_method("force_detach"):
				_parasite_target.force_detach()
				_parasite_target.queue_free()
			_parasite_target = null
			_cleaning_player = false
			state = State.EATING
			eat_timer = 0.6
		return

	# Hunting prey target
	if _prey_target and is_instance_valid(_prey_target):
		var dist := global_position.distance_to(_prey_target.global_position)
		velocity = global_position.direction_to(_prey_target.global_position) * speed * 1.1
		if dist < 18.0 and _prey_attack_cooldown <= 0:
			_mouth_open = 1.0
			if _prey_target.has_method("take_damage"):
				_prey_target.take_damage(15.0)
				_prey_attack_cooldown = 0.5
			_prey_target = null
			state = State.EATING
			eat_timer = 0.6
			return
		return
	_prey_target = null
	# Hunting food
	if not is_instance_valid(food_target):
		food_target = null
		state = State.WANDER
		return
	var dist := global_position.distance_to(food_target.global_position)
	velocity = global_position.direction_to(food_target.global_position) * speed
	if dist < 15.0:
		_eat_food()

func _eat_food() -> void:
	if not is_instance_valid(food_target):
		state = State.WANDER
		return
	collected_count += 1
	_mouth_open = 1.0
	# Check if player is nearby - be smug about it
	var player := _find_player()
	if player and global_position.distance_to(player.global_position) < 150.0:
		_smugness = 1.0
	food_target.queue_free()
	food_target = null
	state = State.EATING
	eat_timer = 0.4

func _pick_wander_target() -> void:
	wander_target = global_position + Vector2(randf_range(-180, 180), randf_range(-180, 180))
	wander_timer = randf_range(2.0, 4.0)

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]

func _draw() -> void:
	var draw_color: Color = _base_color
	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)
	if _smugness > 0:
		draw_color = draw_color.lerp(Color(1.0, 0.9, 0.2), _smugness * 0.3)

	# Glow
	draw_circle(Vector2.ZERO, _cell_radius * 1.6, Color(draw_color.r, draw_color.g, draw_color.b, 0.05))

	# Membrane
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(NUM_MEMBRANE_PTS):
		var wobble: float = sin(_time * 3.5 + i * 0.8) * 1.0
		pts.append(_membrane_points[i] + _membrane_points[i].normalized() * wobble)
	draw_colored_polygon(pts, Color(draw_color.r * 0.35, draw_color.g * 0.4, draw_color.b * 0.25, 0.7))
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(draw_color, 0.85), 1.2, true)

	# Small flagella (2 trailing)
	for f in range(2):
		var base_a: float = PI + (f - 0.5) * 0.6
		var base_pt := Vector2(cos(base_a) * _cell_radius, sin(base_a) * _cell_radius)
		var segments: int = 4
		var prev: Vector2 = base_pt
		for s in range(segments):
			var wave: float = sin(_time * 6.0 + s * 1.5 + f) * 3.0
			var next: Vector2 = prev + Vector2(-4.0, wave)
			draw_line(prev, next, Color(draw_color.r, draw_color.g, draw_color.b, 0.5), 1.0, true)
			prev = next

	# Face
	_draw_face()

func _draw_face() -> void:
	var left_eye := Vector2(_eye_spacing * 0.4, -_eye_spacing * 0.45)
	var right_eye := Vector2(_eye_spacing * 0.4, _eye_spacing * 0.45)
	var mouth_pos := Vector2(_cell_radius * 0.35, 0)

	var eye_r: float = _eye_size
	var pupil_r: float = _pupil_size
	var eye_squash_y: float = 1.0
	var pupil_offset := Vector2.ZERO
	var brow_angle_l: float = 0.0
	var brow_angle_r: float = 0.0
	var mouth_curve: float = 1.0  # Default slight smile
	var mouth_width: float = 3.5
	var mouth_open_amt: float = _mouth_open

	match state:
		State.HUNT:
			# Focused / determined
			eye_squash_y = 0.8
			pupil_offset = Vector2(1.0, 0)
			brow_angle_l = -0.2
			brow_angle_r = 0.2
			mouth_curve = 0.0
		State.EATING:
			eye_squash_y = 0.4  # Satisfied squint
			mouth_curve = 3.0
			mouth_open_amt = maxf(mouth_open_amt, 0.7)
			brow_angle_l = 0.2
			brow_angle_r = 0.2
		State.STARTLED:
			eye_r *= 1.4
			pupil_r *= 0.5
			mouth_open_amt = maxf(mouth_open_amt, 0.8)
			mouth_curve = -1.0
			brow_angle_l = 0.4
			brow_angle_r = 0.4

	# Smug override: half-lidded + smirk
	if _smugness > 0.3:
		eye_squash_y = lerpf(eye_squash_y, 0.5, _smugness)
		mouth_curve = lerpf(mouth_curve, 4.0, _smugness)
		brow_angle_l = lerpf(brow_angle_l, 0.3, _smugness)
		brow_angle_r = lerpf(brow_angle_r, -0.1, _smugness)

	if _is_blinking:
		eye_squash_y = 0.07

	# Eyes
	for eye_pos in [left_eye, right_eye]:
		var eh: float = eye_r * eye_squash_y
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(12):
			var a: float = TAU * i / 12.0
			eye_pts.append(eye_pos + Vector2(cos(a) * eye_r, sin(a) * eh))
		draw_colored_polygon(eye_pts, Color(0.95, 0.95, 0.9, 0.95))
		draw_circle(eye_pos + pupil_offset, pupil_r, Color(0.1, 0.15, 0.0, 1.0))
		draw_circle(eye_pos + pupil_offset + Vector2(-0.3, -0.3), pupil_r * 0.3, Color(1, 1, 0.9, 0.6))

	# Brows
	var brow_len: float = eye_r * 1.3
	var brow_y: float = -eye_r - 1.2
	var brow_col := Color(0.2, 0.25, 0.05, 0.85)
	var lb_s := Vector2(left_eye.x - brow_len * 0.5, left_eye.y + brow_y)
	draw_line(lb_s, lb_s + Vector2(brow_len, 0).rotated(brow_angle_l), brow_col, 1.6, true)
	var rb_s := Vector2(right_eye.x - brow_len * 0.5, right_eye.y + brow_y)
	draw_line(rb_s, rb_s + Vector2(brow_len, 0).rotated(brow_angle_r), brow_col, 1.6, true)

	# Mouth
	if mouth_open_amt > 0.1:
		var mo_w: float = mouth_width * (0.4 + mouth_open_amt * 0.5)
		var mo_h: float = 1.5 + mouth_open_amt * 2.5
		var mo_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			mo_pts.append(mouth_pos + Vector2(cos(a) * mo_w * 0.4, sin(a) * mo_h))
		draw_colored_polygon(mo_pts, Color(0.1, 0.15, 0.02, 0.9))
	else:
		var m_left := mouth_pos + Vector2(0, -mouth_width * 0.5)
		var m_right := mouth_pos + Vector2(0, mouth_width * 0.5)
		var m_mid := mouth_pos + Vector2(mouth_curve, 0)
		draw_line(m_left, m_mid, Color(0.15, 0.2, 0.05, 0.85), 1.5, true)
		draw_line(m_mid, m_right, Color(0.15, 0.2, 0.05, 0.85), 1.5, true)

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	_mouth_open = 0.6
	state = State.STARTLED
	startled_timer = 1.5
	if health <= 0:
		_die()

func _die() -> void:
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(2, 5), _base_color)
	if AudioManager:
		AudioManager.play_death()
	queue_free()

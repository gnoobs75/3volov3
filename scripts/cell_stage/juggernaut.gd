extends CharacterBody2D
## Juggernaut: Boss 2 (spawns after 6th evolution).
## Massive, heavily armored charger. Cannot be damaged by player directly.
## Must be kited through Anemones (repellers) which strip its armor.
## Once armor is fully stripped, it dies. Chase feel: relentless pursuit.
## Kin organisms will attack it when the player passes nearby during the chase.

enum State { IDLE, CHARGE, STUN, RECOVER, DYING }

var state: State = State.IDLE
var speed: float = 50.0
var charge_speed: float = 180.0
var damage: float = 20.0
var detection_range: float = 400.0

var _time: float = 0.0
var _state_timer: float = 0.0
var _current_target: Node2D = null
var _charge_dir: Vector2 = Vector2.ZERO
var _damage_flash: float = 0.0

# Armor system
var armor_plates: int = 8  # Total plates
var _max_armor: int = 8
var _armor_flash: float = 0.0
const REPELLER_STRIP_RANGE: float = 70.0  # How close to anemone to lose a plate

# Chase mechanics
var _charge_accel: float = 0.0  # Builds up during charge for increasing speed
var _wall_stun_timer: float = 0.0
var _voice_cooldown: float = 0.0

# Kin assistance
var _kin_attack_cooldown: float = 0.0
const KIN_ATTACK_RANGE: float = 100.0
const KIN_DAMAGE_PER_HIT: float = 0.0  # Kin don't damage, they slow it

# Body
var _body_radius: float = 35.0
var _base_color: Color
var _armor_color: Color

# Face (angry bull-like)
var _eye_size: float = 5.0
var _nostril_flare: float = 0.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false

func _ready() -> void:
	_init_shape()
	add_to_group("enemies")
	add_to_group("bosses")
	_blink_timer = randf_range(3.0, 6.0)

func _init_shape() -> void:
	_body_radius = randf_range(33.0, 38.0)
	_eye_size = _body_radius * 0.14
	_base_color = Color(
		randf_range(0.4, 0.55),
		randf_range(0.25, 0.35),
		randf_range(0.2, 0.3),
		0.95
	)
	_armor_color = Color(
		randf_range(0.55, 0.7),
		randf_range(0.5, 0.6),
		randf_range(0.45, 0.55),
		1.0
	)

func _physics_process(delta: float) -> void:
	_time += delta
	_damage_flash = maxf(_damage_flash - delta * 3.0, 0.0)
	_armor_flash = maxf(_armor_flash - delta * 3.0, 0.0)
	_kin_attack_cooldown = maxf(_kin_attack_cooldown - delta, 0.0)
	_voice_cooldown = maxf(_voice_cooldown - delta, 0.0)

	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(2.0, 4.0)
		else:
			_is_blinking = true
			_blink_timer = 0.1

	var player := _find_player()
	_current_target = player

	match state:
		State.IDLE:
			_do_idle(delta, player)
		State.CHARGE:
			_do_charge(delta)
		State.STUN:
			_do_stun(delta)
		State.RECOVER:
			_do_recover(delta)
		State.DYING:
			_do_dying(delta)

	# Check repeller proximity (armor stripping)
	_check_repellers()

	# Check kin proximity (kin help)
	if state == State.CHARGE:
		_check_kin_help(delta)

	# Nostril flare animation
	if state == State.CHARGE:
		_nostril_flare = minf(_nostril_flare + delta * 3.0, 1.0)
	else:
		_nostril_flare = maxf(_nostril_flare - delta * 2.0, 0.0)

	move_and_slide()
	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _do_idle(delta: float, player: Node2D) -> void:
	velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
	if player and global_position.distance_to(player.global_position) < detection_range:
		state = State.CHARGE
		_charge_accel = 0.0
		if _voice_cooldown <= 0.0:
			AudioManager.play_creature_voice("juggernaut", "alert", 1.8, 0.8, 0.7)
			_voice_cooldown = 3.0

func _do_charge(delta: float) -> void:
	if not _current_target or not is_instance_valid(_current_target):
		state = State.IDLE
		return

	# Relentless pursuit - gradually accelerate
	_charge_accel = minf(_charge_accel + delta * 0.5, 1.0)
	var current_speed: float = lerpf(speed, charge_speed, _charge_accel)

	var to_player: Vector2 = (_current_target.global_position - global_position).normalized()
	velocity = velocity.lerp(to_player * current_speed, delta * 2.5)

	# Contact damage
	if global_position.distance_to(_current_target.global_position) < _body_radius + 15:
		if _current_target.has_method("take_damage"):
			_current_target.take_damage(damage * delta)

	# Face player
	if velocity.length() > 10:
		rotation = lerp_angle(rotation, velocity.angle(), delta * 3.0)

	# Give up if very far
	if global_position.distance_to(_current_target.global_position) > detection_range * 2.0:
		state = State.IDLE

func _do_stun(delta: float) -> void:
	_state_timer -= delta
	velocity = velocity * 0.92
	if _state_timer <= 0:
		state = State.RECOVER
		_state_timer = 1.0

func _do_recover(delta: float) -> void:
	_state_timer -= delta
	velocity = velocity * 0.95
	if _state_timer <= 0:
		if armor_plates <= 0:
			state = State.DYING
			_state_timer = 2.0
		else:
			state = State.CHARGE
			_charge_accel = 0.0
			if _voice_cooldown <= 0.0:
				AudioManager.play_creature_voice("juggernaut", "alert", 1.8, 0.8, 0.7)
				_voice_cooldown = 3.0

func _do_dying(delta: float) -> void:
	_state_timer -= delta
	velocity = velocity * 0.9
	if _state_timer <= 0:
		_die()

func _check_repellers() -> void:
	for rep in get_tree().get_nodes_in_group("repellers"):
		if not is_instance_valid(rep):
			continue
		var dist: float = global_position.distance_to(rep.global_position)
		if dist < REPELLER_STRIP_RANGE and armor_plates > 0:
			_strip_armor_plate()
			# Stun on armor loss
			state = State.STUN
			_state_timer = 1.5
			# Bounce away from repeller
			var bounce_dir: Vector2 = (global_position - rep.global_position).normalized()
			velocity = bounce_dir * 150.0
			break

func _check_kin_help(delta: float) -> void:
	if _kin_attack_cooldown > 0:
		return
	for kin in get_tree().get_nodes_in_group("kin"):
		if not is_instance_valid(kin):
			continue
		var dist: float = global_position.distance_to(kin.global_position)
		if dist < KIN_ATTACK_RANGE:
			# Kin slows the juggernaut
			_charge_accel = maxf(_charge_accel - 0.3, 0.0)
			_kin_attack_cooldown = 2.0
			# Visual feedback on the kin (make them flash)
			if kin.has_method("_set_mood"):
				kin._set_mood(2, 1.0)  # EXCITED mood
			# Briefly stagger
			velocity *= 0.7
			_armor_flash = 0.5
			break

func _strip_armor_plate() -> void:
	armor_plates -= 1
	_armor_flash = 1.0
	_damage_flash = 0.8
	AudioManager.play_hurt()
	# Spawn armor debris
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, 2, _armor_color)

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
	var armor_ratio: float = float(armor_plates) / float(_max_armor)

	match state:
		State.CHARGE:
			draw_color = _base_color.lerp(Color(0.8, 0.3, 0.2), 0.3 + _charge_accel * 0.2)
		State.STUN:
			draw_color = _base_color.lerp(Color(0.6, 0.6, 0.3), 0.4)
		State.DYING:
			draw_color = _base_color.lerp(Color(0.4, 0.3, 0.3), 0.5)

	if _damage_flash > 0:
		draw_color = draw_color.lerp(Color.WHITE, _damage_flash)

	# Charge glow
	if state == State.CHARGE:
		var charge_glow: float = 0.08 + _charge_accel * 0.12
		draw_circle(Vector2.ZERO, _body_radius * 2.0, Color(0.8, 0.3, 0.1, charge_glow))

	# Ground shake lines when charging fast
	if state == State.CHARGE and _charge_accel > 0.5:
		for i in range(4):
			var shake_x: float = -_body_radius - 5.0 - i * 8.0
			var shake_y: float = sin(_time * 20.0 + i * 1.5) * (_body_radius * 0.3)
			draw_line(Vector2(shake_x, shake_y - 3), Vector2(shake_x, shake_y + 3), Color(0.6, 0.4, 0.2, 0.3), 2.0, true)

	# Body - bulky, angular shape
	var pts: PackedVector2Array = PackedVector2Array()
	var num_pts: int = 24
	for i in range(num_pts):
		var angle: float = TAU * i / num_pts
		var r: float = _body_radius
		# Bulkier at front (charging head)
		if cos(angle) > 0.3:
			r *= 1.15
		# Bumpy organic texture
		r += sin(angle * 4.0 + _time * 1.5) * 2.0
		if state == State.CHARGE:
			r += sin(_time * 12.0 + angle * 6.0) * 1.5  # Vibration
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))

	draw_colored_polygon(pts, Color(draw_color.r * 0.3, draw_color.g * 0.25, draw_color.b * 0.25, 0.85))
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(draw_color, 0.85), 2.0, true)

	# Armor plates (drawn as overlapping scales)
	for p in range(_max_armor):
		var plate_angle: float = TAU * p / _max_armor
		var plate_r: float = _body_radius * 0.85
		var plate_pos := Vector2(cos(plate_angle) * plate_r, sin(plate_angle) * plate_r)

		if p < armor_plates:
			# Intact plate
			var plate_color := _armor_color
			if _armor_flash > 0 and p == armor_plates - 1:
				plate_color = plate_color.lerp(Color.WHITE, _armor_flash)
			var plate_size: float = _body_radius * 0.25
			var p_pts: PackedVector2Array = PackedVector2Array()
			for j in range(6):
				var a: float = TAU * j / 6.0
				p_pts.append(plate_pos + Vector2(cos(a + plate_angle) * plate_size, sin(a + plate_angle) * plate_size * 0.7))
			draw_colored_polygon(p_pts, Color(plate_color, 0.8))
			draw_line(p_pts[0], p_pts[3], Color(plate_color.darkened(0.3), 0.6), 1.0, true)
		else:
			# Missing plate: scar mark
			draw_circle(plate_pos, 3.0, Color(0.6, 0.2, 0.2, 0.3))

	# Horns (front)
	var horn_len: float = _body_radius * 0.5
	for side in [-1, 1]:
		var horn_base := Vector2(_body_radius * 0.9, side * _body_radius * 0.3)
		var horn_tip := horn_base + Vector2(horn_len, side * horn_len * 0.4)
		draw_line(horn_base, horn_tip, Color(0.7, 0.65, 0.5, 0.9), 3.0, true)
		draw_circle(horn_tip, 2.0, Color(0.8, 0.75, 0.6, 0.8))

	# Face
	_draw_face()

	# Armor count
	var bar_w: float = _body_radius * 1.5
	var bar_y: float = _body_radius + 10.0
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, 5), Color(0.2, 0.2, 0.2, 0.5))
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * armor_ratio, 5), Color(_armor_color, 0.8))

	# Stun stars
	if state == State.STUN:
		for s in range(4):
			var sa: float = _time * 5.0 + TAU * s / 4.0
			var star_pos := Vector2(cos(sa) * (_body_radius + 8), sin(sa) * (_body_radius + 8))
			draw_circle(star_pos, 2.0, Color(1.0, 1.0, 0.3, 0.6))

func _draw_face() -> void:
	var eye_x: float = _body_radius * 0.5
	var eye_y: float = _body_radius * 0.25
	var le := Vector2(eye_x, -eye_y)
	var re := Vector2(eye_x, eye_y)
	var eye_squash: float = 0.5 if not _is_blinking else 0.08  # Narrow angry eyes

	if state == State.STUN:
		eye_squash = 1.0  # Dazed wide eyes

	for idx in range(2):
		var ep: Vector2 = le if idx == 0 else re
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			eye_pts.append(ep + Vector2(cos(a) * _eye_size, sin(a) * _eye_size * eye_squash))
		draw_colored_polygon(eye_pts, Color(0.95, 0.85, 0.8, 0.95))
		if not _is_blinking:
			# Red angry pupil
			var pupil_r: float = _eye_size * 0.4
			if state == State.CHARGE:
				pupil_r *= 0.6  # Focused
			draw_circle(ep, pupil_r, Color(0.7, 0.15, 0.1, 1.0))
			draw_circle(ep, pupil_r * 0.4, Color(0.05, 0.02, 0.02, 1.0))

	# Angry brows (deep V shape)
	draw_line(le + Vector2(-_eye_size * 1.2, -_eye_size * 0.2), le + Vector2(_eye_size, -_eye_size * 1.0), Color(0.3, 0.15, 0.1, 0.9), 2.5, true)
	draw_line(re + Vector2(-_eye_size, -_eye_size * 1.0), re + Vector2(_eye_size * 1.2, -_eye_size * 0.2), Color(0.3, 0.15, 0.1, 0.9), 2.5, true)

	# Nostrils (flare when charging)
	var nose_x: float = _body_radius * 0.7
	var flare: float = 1.0 + _nostril_flare * 0.5
	draw_circle(Vector2(nose_x, -3 * flare), 2.0 * flare, Color(0.2, 0.1, 0.1, 0.7))
	draw_circle(Vector2(nose_x, 3 * flare), 2.0 * flare, Color(0.2, 0.1, 0.1, 0.7))
	# Steam puffs from nostrils when charging
	if _nostril_flare > 0.5:
		for n in range(2):
			var ny: float = -3.0 if n == 0 else 3.0
			var puff_x: float = nose_x + 4.0 + sin(_time * 10.0 + n) * 2.0
			draw_circle(Vector2(puff_x, ny * flare), 1.5, Color(0.8, 0.8, 0.9, (_nostril_flare - 0.5) * 0.5))

func take_damage(_amount: float) -> void:
	# Juggernaut is immune to direct damage
	_damage_flash = 0.3
	if _voice_cooldown <= 0.0:
		AudioManager.play_creature_voice("juggernaut", "hurt", 1.8, 0.8, 0.7)
		_voice_cooldown = 2.5
	# But it gets angrier (speeds up slightly)
	_charge_accel = minf(_charge_accel + 0.1, 1.0)

func _die() -> void:
	AudioManager.play_creature_voice("juggernaut", "death", 1.8, 0.8, 0.7)
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(15, 20), _armor_color)
	if manager and manager.has_method("_on_boss_defeated"):
		manager._on_boss_defeated("juggernaut")
	AudioManager.play_death()
	queue_free()

func confuse(_duration: float) -> void:
	# Boss resists confusion but staggers briefly
	if state == State.CHARGE:
		_charge_accel = maxf(_charge_accel - 0.2, 0.0)
		velocity *= 0.8

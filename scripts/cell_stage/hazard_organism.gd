extends Area2D
## Passive hazard organism: drifts through the environment dealing contact damage.
## Types: jellyfish (trailing tentacles), spike ball (radiating spines), toxic blob (pulsing aura).

enum HazardType { JELLYFISH, SPIKE_BALL, TOXIC_BLOB, POISON_CLOUD }

var hazard_type: HazardType = HazardType.JELLYFISH
var drift_velocity: Vector2 = Vector2.ZERO
var damage_per_second: float = 15.0
var _time: float = 0.0
var _radius: float = 10.0
var _base_color: Color = Color(0.8, 0.2, 0.9, 0.8)
var _tentacle_count: int = 0
var _spike_angles: Array[float] = []
var _pulse_phase: float = 0.0

# Tiny derpy face (even hazards get one)
var _eye_size: float = 1.8
var _has_face: bool = true
var health: float = 60.0
var _damage_flash: float = 0.0
var _voice_cooldown: float = 0.0

# Googly eye animation
var _eye_bounce_l: Vector2 = Vector2.ZERO
var _eye_bounce_r: Vector2 = Vector2.ZERO
var _eye_vel_l: Vector2 = Vector2.ZERO
var _eye_vel_r: Vector2 = Vector2.ZERO
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _tongue_wiggle: float = 0.0

func _ready() -> void:
	_init_hazard()
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func setup(type: HazardType) -> void:
	hazard_type = type

func _init_hazard() -> void:
	_pulse_phase = randf() * TAU
	_has_face = randf() > 0.2
	_blink_timer = randf_range(2.0, 5.0)
	match hazard_type:
		HazardType.JELLYFISH:
			_radius = randf_range(8.0, 12.0)
			_base_color = Color(randf_range(0.6, 0.9), 0.15, randf_range(0.7, 1.0), 0.7)
			_tentacle_count = randi_range(4, 7)
			damage_per_second = 12.0
			drift_velocity = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		HazardType.SPIKE_BALL:
			_radius = randf_range(6.0, 9.0)
			_base_color = Color(0.9, randf_range(0.3, 0.5), 0.1, 0.85)
			var num_spikes: int = randi_range(6, 12)
			_spike_angles.clear()
			for i in range(num_spikes):
				_spike_angles.append(TAU * i / num_spikes + randf_range(-0.1, 0.1))
			damage_per_second = 20.0
			drift_velocity = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		HazardType.TOXIC_BLOB:
			_radius = randf_range(10.0, 15.0)
			_base_color = Color(0.3, randf_range(0.8, 1.0), 0.1, 0.6)
			damage_per_second = 10.0
			drift_velocity = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		HazardType.POISON_CLOUD:
			_radius = randf_range(25.0, 40.0)
			_base_color = Color(0.5, randf_range(0.15, 0.3), 0.6, 0.35)
			damage_per_second = 8.0
			drift_velocity = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			health = 200.0  # Very tanky — meant to be avoided, not killed
			_has_face = false
			# Enlarge collision to match visual size
			var col := get_node_or_null("CollisionShape2D")
			if col and col.shape is CircleShape2D:
				var big_shape := CircleShape2D.new()
				big_shape.radius = _radius * 0.8
				col.shape = big_shape

var _touching_bodies: Array[Node2D] = []

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("competitors") or body.is_in_group("enemies") or body.is_in_group("prey"):
		_touching_bodies.append(body)
		if body.is_in_group("player") and _voice_cooldown <= 0.0:
			AudioManager.play_creature_voice("hazard_organism", "alert", 1.2, 0.3, 0.5)
			_voice_cooldown = 3.0

func _on_body_exited(body: Node2D) -> void:
	_touching_bodies.erase(body)

func _process(delta: float) -> void:
	_time += delta
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
	_voice_cooldown = maxf(_voice_cooldown - delta, 0.0)
	global_position += drift_velocity * delta

	# Googly eye physics - eyes react to drift
	var spring_k: float = 20.0
	var damping: float = 6.0
	var eye_target := -drift_velocity * 0.01
	# Left eye
	_eye_vel_l += (eye_target - _eye_bounce_l) * spring_k * delta
	_eye_vel_l *= exp(-damping * delta)
	_eye_bounce_l += _eye_vel_l * delta
	_eye_bounce_l = _eye_bounce_l.limit_length(2.0)
	# Right eye (slightly different timing for derpy effect)
	_eye_vel_r += (eye_target * 0.8 - _eye_bounce_r) * spring_k * delta
	_eye_vel_r *= exp(-damping * delta * 0.9)
	_eye_bounce_r += _eye_vel_r * delta
	_eye_bounce_r = _eye_bounce_r.limit_length(2.0)

	# Blink timer
	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(2.0, 5.0)
		else:
			_is_blinking = true
			_blink_timer = 0.15

	# Tongue wiggle animation
	_tongue_wiggle = sin(_time * 4.0) * 0.3

	# Apply continuous damage to touching bodies
	for body in _touching_bodies:
		if is_instance_valid(body) and body.has_method("take_damage"):
			body.take_damage(damage_per_second * delta)
	# Remove invalid refs
	_touching_bodies = _touching_bodies.filter(func(b): return is_instance_valid(b))
	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _draw() -> void:
	match hazard_type:
		HazardType.JELLYFISH: _draw_jellyfish()
		HazardType.SPIKE_BALL: _draw_spike_ball()
		HazardType.TOXIC_BLOB: _draw_toxic_blob()
		HazardType.POISON_CLOUD: _draw_poison_cloud()
	if _has_face and hazard_type != HazardType.POISON_CLOUD:
		_draw_tiny_face()

func _draw_jellyfish() -> void:
	var pulse: float = 0.9 + 0.15 * sin(_time * 2.5 + _pulse_phase)
	var r: float = _radius * pulse

	# Warning glow
	draw_circle(Vector2.ZERO, r * 2.0, Color(_base_color.r, _base_color.g, _base_color.b, 0.04))

	# Bell (dome shape - top half of oval)
	var bell_pts: PackedVector2Array = PackedVector2Array()
	for i in range(13):
		var a: float = PI + PI * i / 12.0
		bell_pts.append(Vector2(cos(a) * r, sin(a) * r * 0.7))
	draw_colored_polygon(bell_pts, Color(_base_color.r * 0.4, _base_color.g * 0.2, _base_color.b * 0.5, 0.6))
	for i in range(bell_pts.size() - 1):
		draw_line(bell_pts[i], bell_pts[i + 1], _base_color, 1.2, true)

	# Tentacles
	for t in range(_tentacle_count):
		var tx: float = -r * 0.8 + r * 1.6 * t / (_tentacle_count - 1) if _tentacle_count > 1 else 0.0
		var base_pt := Vector2(tx, r * 0.1)
		var prev: Vector2 = base_pt
		for s in range(5):
			var wave: float = sin(_time * 3.0 + t * 1.2 + s * 0.8) * 3.0
			var next: Vector2 = prev + Vector2(wave, 5.0)
			var alpha: float = 0.6 - s * 0.1
			draw_line(prev, next, Color(_base_color.r, _base_color.g, _base_color.b, alpha), 1.0, true)
			prev = next

func _draw_spike_ball() -> void:
	var r: float = _radius
	# Danger glow
	var glow_pulse: float = 0.06 + 0.04 * sin(_time * 4.0)
	draw_circle(Vector2.ZERO, r * 2.0, Color(1.0, 0.3, 0.0, glow_pulse))

	# Core
	draw_circle(Vector2.ZERO, r, Color(_base_color.r * 0.4, _base_color.g * 0.3, _base_color.b * 0.2, 0.8))
	draw_arc(Vector2.ZERO, r, 0, TAU, 16, _base_color, 1.2, true)

	# Spikes
	for a in _spike_angles:
		var rotate_a: float = a + sin(_time * 2.0 + a) * 0.1
		var base_pt := Vector2(cos(rotate_a) * r, sin(rotate_a) * r)
		var tip_pt := Vector2(cos(rotate_a) * (r + 6.0), sin(rotate_a) * (r + 6.0))
		draw_line(base_pt, tip_pt, Color(1.0, 0.4, 0.1, 0.9), 1.5, true)

func _draw_toxic_blob() -> void:
	var r: float = _radius + sin(_time * 2.0 + _pulse_phase) * 2.0

	# Toxic aura rings
	for ring in range(3):
		var ring_r: float = r + 4.0 * ring + sin(_time * 3.0 + ring) * 2.0
		var alpha: float = 0.08 - ring * 0.02
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 20, Color(_base_color.r, _base_color.g, _base_color.b, alpha), 1.5, true)

	# Amorphous body
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 14
	for i in range(n):
		var a: float = TAU * i / n
		var wobble: float = sin(_time * 2.0 + i * 1.1 + _pulse_phase) * 2.5
		pts.append(Vector2(cos(a) * (r + wobble), sin(a) * (r + wobble)))
	draw_colored_polygon(pts, Color(_base_color.r * 0.3, _base_color.g * 0.5, _base_color.b * 0.15, 0.55))
	for i in range(n):
		draw_line(pts[i], pts[(i + 1) % n], _base_color, 1.0, true)

	# Bubbling particles inside
	for b in range(4):
		var ba: float = _time * 1.5 + b * 1.7
		var bd: float = r * 0.5 * (0.5 + 0.5 * sin(ba * 0.7))
		var bp := Vector2(cos(ba) * bd, sin(ba * 0.8) * bd)
		draw_circle(bp, 1.5, Color(_base_color.r, _base_color.g, _base_color.b, 0.4))

func _draw_poison_cloud() -> void:
	var r: float = _radius + sin(_time * 1.2 + _pulse_phase) * 3.0

	# Multiple overlapping translucent blobs for cloud effect
	for layer in range(5):
		var lr: float = r * (0.6 + layer * 0.15)
		var offset := Vector2(
			sin(_time * 0.8 + layer * 1.3) * r * 0.15,
			cos(_time * 0.6 + layer * 1.7) * r * 0.12
		)
		var pts: PackedVector2Array = PackedVector2Array()
		var n: int = 16
		for i in range(n):
			var a: float = TAU * i / n
			var wobble: float = sin(_time * 1.5 + i * 0.9 + layer * 2.0) * r * 0.12
			pts.append(offset + Vector2(cos(a) * (lr + wobble), sin(a) * (lr + wobble)))
		var cloud_alpha: float = 0.12 - layer * 0.015
		draw_colored_polygon(pts, Color(_base_color.r, _base_color.g, _base_color.b, cloud_alpha))

	# Inner toxic swirl particles
	for p in range(8):
		var pa: float = _time * 0.7 + p * 0.8
		var pd: float = r * 0.5 * (0.3 + 0.4 * sin(pa * 0.5 + p))
		var pp := Vector2(cos(pa) * pd, sin(pa * 0.7) * pd)
		var particle_alpha: float = 0.15 + 0.1 * sin(_time * 2.0 + p * 1.2)
		draw_circle(pp, randf_range(2.0, 4.0), Color(_base_color.r * 1.3, _base_color.g, _base_color.b * 1.2, particle_alpha))

	# Warning skull-like pattern in center (two dark dots + line)
	var skull_alpha: float = 0.12 + 0.06 * sin(_time * 2.0)
	draw_circle(Vector2(-4, -2), 2.5, Color(0.1, 0.0, 0.1, skull_alpha))
	draw_circle(Vector2(4, -2), 2.5, Color(0.1, 0.0, 0.1, skull_alpha))
	draw_line(Vector2(-3, 4), Vector2(3, 4), Color(0.1, 0.0, 0.1, skull_alpha * 0.7), 1.5)

func _draw_tiny_face() -> void:
	# Minimalist derpy face on hazards with googly eyes
	var le := Vector2(0, -_eye_size * 0.8)
	var re := Vector2(0, _eye_size * 0.8)
	var er: float = _eye_size

	var eye_squash: float = 1.0 if not _is_blinking else 0.15

	# Vacant stare with googly bounce
	var face_col := Color(0.95, 0.95, 0.9, 0.9)
	if _damage_flash > 0:
		face_col = face_col.lerp(Color.WHITE, _damage_flash)

	# Draw eye whites (slightly different sizes for derpy look)
	var le_pts: PackedVector2Array = PackedVector2Array()
	var re_pts: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var a: float = TAU * i / 10.0
		le_pts.append(le + Vector2(cos(a) * er, sin(a) * er * eye_squash))
		re_pts.append(re + Vector2(cos(a) * er * 1.15, sin(a) * er * 1.15 * eye_squash))  # Derpy: one eye bigger
	draw_colored_polygon(le_pts, face_col)
	draw_colored_polygon(re_pts, face_col)

	# Googly pupils that bounce around
	if not _is_blinking:
		var pupil_col := Color(0.1, 0.0, 0.1, 0.95)
		draw_circle(le + _eye_bounce_l, er * 0.5, pupil_col)
		draw_circle(re + _eye_bounce_r, er * 0.55, pupil_col)  # Slightly bigger for derpy eye
		# Tiny highlight
		draw_circle(le + _eye_bounce_l + Vector2(-0.3, -0.3), er * 0.15, Color(1, 1, 1, 0.7))
		draw_circle(re + _eye_bounce_r + Vector2(-0.3, -0.3), er * 0.15, Color(1, 1, 1, 0.7))

	# Tongue sticking out slightly (hazards are derpy)
	var mp := Vector2(_radius * 0.3, 0)
	var tongue_y: float = _tongue_wiggle
	# Small tongue blob
	draw_circle(mp + Vector2(1.5, tongue_y), 1.2, Color(0.9, 0.35, 0.4, 0.85))
	# O-shaped mouth behind tongue
	draw_arc(mp, 1.5, 0, TAU, 8, Color(0.2, 0.05, 0.1, 0.7), 1.2, true)

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if _voice_cooldown <= 0.0:
		AudioManager.play_creature_voice("hazard_organism", "hurt", 1.2, 0.3, 0.5)
		_voice_cooldown = 2.5
	if health <= 0:
		_die()

func _die() -> void:
	AudioManager.play_creature_voice("hazard_organism", "death", 1.2, 0.3, 0.5)
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(4, 7), _base_color)
	if AudioManager:
		AudioManager.play_death()
	queue_free()

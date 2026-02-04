extends Area2D
## Passive hazard organism: drifts through the environment dealing contact damage.
## Types: jellyfish (trailing tentacles), spike ball (radiating spines), toxic blob (pulsing aura).

enum HazardType { JELLYFISH, SPIKE_BALL, TOXIC_BLOB }

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

var _touching_bodies: Array[Node2D] = []

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("competitors") or body.is_in_group("enemies") or body.is_in_group("prey"):
		_touching_bodies.append(body)

func _on_body_exited(body: Node2D) -> void:
	_touching_bodies.erase(body)

func _process(delta: float) -> void:
	_time += delta
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
	global_position += drift_velocity * delta
	# Apply continuous damage to touching bodies
	for body in _touching_bodies:
		if is_instance_valid(body) and body.has_method("take_damage"):
			body.take_damage(damage_per_second * delta)
	# Remove invalid refs
	_touching_bodies = _touching_bodies.filter(func(b): return is_instance_valid(b))
	queue_redraw()

func _draw() -> void:
	match hazard_type:
		HazardType.JELLYFISH: _draw_jellyfish()
		HazardType.SPIKE_BALL: _draw_spike_ball()
		HazardType.TOXIC_BLOB: _draw_toxic_blob()
	if _has_face:
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

func _draw_tiny_face() -> void:
	# Minimalist derpy face on hazards
	var le := Vector2(0, -_eye_size * 0.8)
	var re := Vector2(0, _eye_size * 0.8)
	var er: float = _eye_size
	# Vacant stare
	var face_col := Color(0.95, 0.95, 0.9, 0.8)
	if _damage_flash > 0:
		face_col = face_col.lerp(Color.WHITE, _damage_flash)
	draw_circle(le, er, face_col)
	draw_circle(re, er, face_col)
	# Tiny pupils looking in random slow directions
	var look_a: float = sin(_time * 0.5) * 0.5
	var look_v := Vector2(cos(look_a), sin(look_a)) * er * 0.3
	draw_circle(le + look_v, er * 0.45, Color(0.1, 0.0, 0.1, 0.9))
	draw_circle(re + look_v, er * 0.45, Color(0.1, 0.0, 0.1, 0.9))
	# Tiny o-shaped mouth
	var mp := Vector2(_radius * 0.3, 0)
	draw_arc(mp, 1.5, 0, TAU, 8, Color(0.2, 0.05, 0.1, 0.7), 1.0, true)

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if health <= 0:
		_die()

func _die() -> void:
	var manager := get_tree().get_first_node_in_group("cell_stage_manager")
	if manager and manager.has_method("spawn_death_nutrients"):
		manager.spawn_death_nutrients(global_position, randi_range(4, 7), _base_color)
	if AudioManager:
		AudioManager.play_death()
	queue_free()

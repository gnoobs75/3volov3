extends Area2D
## Virus organism: spiky icosahedral pathogen that attaches and drains health.
## Looks like a classic virus with geometric core and protein spikes.
## Creepy grin gets wider as it drains more health.

enum State { DRIFT, SEEK, ATTACHED, FLEE }

var state: State = State.DRIFT
var _time: float = 0.0
var speed: float = 55.0
var detection_range: float = 180.0
var _flee_timer: float = 0.0
var _flee_dir: Vector2 = Vector2.ZERO

# Virus appearance
var _radius: float = 7.0
var _base_color: Color
var _spike_count: int = 0
var _spike_angles: Array[float] = []
var _spike_lengths: Array[float] = []
var _core_rotation: float = 0.0  # Slowly rotating core

# Attachment
var drift_target: Vector2 = Vector2.ZERO
var drift_timer: float = 0.0
var attach_offset: Vector2 = Vector2.ZERO
var _attached_to: Node2D = null

# Health drain
const DRAIN_RATE: float = 4.0  # Health per second drained from host
var _total_drained: float = 0.0  # Tracks how much health stolen (affects grin)

# Face animation
var _eye_size: float = 1.5
var _grin_width: float = 0.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _pupil_target: Vector2 = Vector2.ZERO  # Pupils track player
var _creepy_pulse: float = 0.0  # Pulsing when attached

func _ready() -> void:
	_radius = randf_range(6.0, 9.0)
	_spike_count = randi_range(12, 18)
	_base_color = Color(
		randf_range(0.3, 0.5),
		randf_range(0.6, 0.9),
		randf_range(0.2, 0.4),
		0.9
	)
	# Initialize spikes at various angles
	for i in range(_spike_count):
		var angle: float = TAU * i / _spike_count + randf_range(-0.15, 0.15)
		_spike_angles.append(angle)
		_spike_lengths.append(randf_range(3.0, 6.0))
	_blink_timer = randf_range(1.0, 3.0)
	add_to_group("viruses")
	add_to_group("parasites")  # Also in parasites group for general parasite handling
	body_entered.connect(_on_body_entered)
	_pick_drift_target()

func _pick_drift_target() -> void:
	drift_target = global_position + Vector2(randf_range(-120, 120), randf_range(-120, 120))
	drift_timer = randf_range(2.0, 5.0)

func _physics_process(delta: float) -> void:
	_time += delta
	_core_rotation += delta * 0.5  # Slow rotation

	# Blink timer
	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(1.5, 4.0)
		else:
			_is_blinking = true
			_blink_timer = 0.1

	# Creepy pulse when attached
	if state == State.ATTACHED:
		_creepy_pulse = 0.5 + 0.5 * sin(_time * 4.0)
	else:
		_creepy_pulse = maxf(_creepy_pulse - delta * 3.0, 0.0)

	match state:
		State.DRIFT:
			drift_timer -= delta
			if drift_timer <= 0 or global_position.distance_to(drift_target) < 15:
				_pick_drift_target()
			var dir: Vector2 = global_position.direction_to(drift_target)
			global_position += dir * speed * 0.25 * delta
			# Check for player
			var player := _find_player()
			if player:
				var dist: float = global_position.distance_to(player.global_position)
				if dist < detection_range:
					state = State.SEEK
					_pupil_target = player.global_position

		State.SEEK:
			var player := _find_player()
			if not player:
				state = State.DRIFT
				return
			var dist: float = global_position.distance_to(player.global_position)
			if dist > detection_range * 1.6:
				state = State.DRIFT
				return
			# Chase with increasing urgency
			var urgency: float = 1.0 + (1.0 - dist / detection_range) * 0.6
			var dir: Vector2 = global_position.direction_to(player.global_position)
			global_position += dir * speed * urgency * delta
			_pupil_target = player.global_position

		State.ATTACHED:
			if not is_instance_valid(_attached_to):
				_detach()
				return
			global_position = _attached_to.global_position + attach_offset.rotated(_attached_to.rotation)
			# DRAIN HEALTH from host
			if _attached_to.has_method("take_damage"):
				var drain_amount: float = DRAIN_RATE * delta
				_attached_to.take_damage(drain_amount)
				_total_drained += drain_amount
				# Grin gets wider the more we drain
				_grin_width = minf(_total_drained * 0.1, 1.0)

		State.FLEE:
			_flee_timer -= delta
			if _flee_timer <= 0:
				state = State.DRIFT
				_pick_drift_target()
			else:
				global_position += _flee_dir * speed * 2.5 * delta

	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if state == State.ATTACHED:
		return
	if body.is_in_group("player") and body.has_method("attach_parasite"):
		_attach_to(body)

func _attach_to(target: Node2D) -> void:
	state = State.ATTACHED
	_attached_to = target
	_total_drained = 0.0  # Reset drain counter
	# Random position around the cell edge
	var angle: float = randf() * TAU
	attach_offset = Vector2(cos(angle) * 22.0, sin(angle) * 22.0)
	if target.has_method("attach_parasite"):
		target.attach_parasite(self)
	if AudioManager:
		AudioManager.play_hurt()  # Use hurt sound for attachment

func _detach() -> void:
	state = State.DRIFT
	_attached_to = null
	_grin_width = 0.0
	_total_drained = 0.0
	_pick_drift_target()

func force_detach() -> void:
	var flee_from: Vector2 = global_position
	if is_instance_valid(_attached_to):
		flee_from = _attached_to.global_position
	_detach()
	_flee_dir = (global_position - flee_from).normalized()
	if _flee_dir.length() < 0.5:
		_flee_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	_flee_timer = 2.5
	state = State.FLEE

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]

func _draw() -> void:
	# Glow aura (sickly green)
	var glow_a: float = 0.06 + _creepy_pulse * 0.08
	draw_circle(Vector2.ZERO, _radius * 2.5, Color(_base_color.r, _base_color.g, _base_color.b, glow_a))

	# Core body - icosahedral/hexagonal shape
	var core_pts: PackedVector2Array = PackedVector2Array()
	var num_sides: int = 6
	for i in range(num_sides):
		var angle: float = TAU * i / num_sides + _core_rotation
		var wobble: float = sin(_time * 3.0 + i * 1.2) * 0.5
		core_pts.append(Vector2(cos(angle) * (_radius + wobble), sin(angle) * (_radius + wobble)))

	# Core fill
	var fill_color := Color(_base_color.r * 0.3, _base_color.g * 0.4, _base_color.b * 0.25, 0.8)
	if state == State.ATTACHED:
		fill_color = fill_color.lerp(Color(0.5, 0.8, 0.3), _creepy_pulse * 0.3)
	draw_colored_polygon(core_pts, fill_color)

	# Core outline
	for i in range(core_pts.size()):
		draw_line(core_pts[i], core_pts[(i + 1) % core_pts.size()], Color(_base_color, 0.9), 1.2, true)

	# Inner structure (capsid pattern)
	for i in range(3):
		var inner_angle: float = TAU * i / 3.0 + _core_rotation * 1.5
		var p1 := Vector2(cos(inner_angle) * _radius * 0.5, sin(inner_angle) * _radius * 0.5)
		var p2 := Vector2(cos(inner_angle + TAU / 3) * _radius * 0.5, sin(inner_angle + TAU / 3) * _radius * 0.5)
		draw_line(p1, p2, Color(_base_color.r, _base_color.g, _base_color.b, 0.4), 0.8, true)

	# Protein spikes (the classic virus look)
	for i in range(_spike_count):
		var angle: float = _spike_angles[i] + _core_rotation * 0.3
		var spike_len: float = _spike_lengths[i]
		# Spike wobble when seeking
		if state == State.SEEK:
			spike_len += sin(_time * 8.0 + i) * 1.0
		var base_pt := Vector2(cos(angle) * _radius, sin(angle) * _radius)
		var tip_pt := Vector2(cos(angle) * (_radius + spike_len), sin(angle) * (_radius + spike_len))
		# Spike line
		draw_line(base_pt, tip_pt, Color(_base_color.r * 1.2, _base_color.g, _base_color.b * 0.8, 0.8), 1.0, true)
		# Spike tip ball
		draw_circle(tip_pt, 1.2, Color(_base_color.r * 1.3, _base_color.g * 1.1, _base_color.b, 0.9))

	# --- CREEPY FACE ---
	_draw_face()

	# Attached indicator: pulsing sickly aura
	if state == State.ATTACHED:
		var pulse_a: float = 0.15 + 0.15 * sin(_time * 6.0)
		draw_circle(Vector2.ZERO, _radius * 2.2, Color(0.4, 0.9, 0.2, pulse_a))
		# Health drain particles flowing into virus
		for p in range(3):
			var p_angle: float = _time * 3.0 + TAU * p / 3.0
			var p_dist: float = _radius * 1.5 + fmod(_time * 20.0 + p * 10.0, _radius * 1.0)
			var p_pos := Vector2(cos(p_angle) * p_dist, sin(p_angle) * p_dist)
			var p_alpha: float = 1.0 - (p_dist - _radius * 1.5) / (_radius * 1.0)
			draw_circle(p_pos, 1.0, Color(1.0, 0.3, 0.3, p_alpha * 0.6))

func _draw_face() -> void:
	var eye_squash: float = 1.0 if not _is_blinking else 0.15

	# Eye positions
	var le := Vector2(0, -_eye_size * 1.2)
	var re := Vector2(0, _eye_size * 1.2)

	# Track player with pupils
	var look_dir := Vector2.ZERO
	if _pupil_target != Vector2.ZERO:
		var to_target := (_pupil_target - global_position).normalized()
		look_dir = to_target.rotated(-rotation) * _eye_size * 0.3

	# State-based expressions
	var er: float = _eye_size
	match state:
		State.DRIFT:
			er *= 0.9
		State.SEEK:
			er *= 1.1 + 0.1 * sin(_time * 6.0)  # Excited pulsing
		State.ATTACHED:
			er *= 0.7  # Satisfied squint

	# Draw eyes
	for eye_pos in [le, re]:
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			eye_pts.append(eye_pos + Vector2(cos(a) * er, sin(a) * er * eye_squash))
		# Sickly yellowish eye whites
		draw_colored_polygon(eye_pts, Color(0.95, 0.95, 0.7, 0.95))

		if not _is_blinking:
			# Creepy red pupils
			var pupil_pos: Vector2 = eye_pos + look_dir
			draw_circle(pupil_pos, er * 0.5, Color(0.7, 0.15, 0.1, 1.0))
			draw_circle(pupil_pos, er * 0.25, Color(0.2, 0.0, 0.0, 1.0))
			# Glint
			draw_circle(pupil_pos + Vector2(-er * 0.2, -er * 0.2), er * 0.15, Color(1, 1, 0.8, 0.7))

	# Creepy grin - gets wider when attached and draining
	var mouth_x: float = _radius * 0.5
	var base_grin_width: float = 2.0
	var grin_w: float = base_grin_width + _grin_width * 4.0  # Gets much wider
	var grin_curve: float = 2.0 + _grin_width * 3.0  # Gets more curved

	if state == State.ATTACHED and _grin_width > 0.3:
		# Wide creepy open grin showing teeth
		var grin_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var t: float = float(i) / 9.0
			var gx: float = mouth_x + sin(t * PI) * grin_curve
			var gy: float = -grin_w + t * grin_w * 2.0
			grin_pts.append(Vector2(gx, gy))
		# Close the mouth shape
		for i in range(9, -1, -1):
			var t: float = float(i) / 9.0
			var gx: float = mouth_x + sin(t * PI) * grin_curve * 0.5  # Inner curve
			var gy: float = -grin_w + t * grin_w * 2.0
			grin_pts.append(Vector2(gx, gy))
		draw_colored_polygon(grin_pts, Color(0.15, 0.05, 0.05, 0.95))

		# Tiny sharp teeth
		var num_teeth: int = int(3 + _grin_width * 4)
		for t in range(num_teeth):
			var ty: float = -grin_w * 0.8 + (grin_w * 1.6) * t / (num_teeth - 1)
			var tx: float = mouth_x + sin((float(t) / (num_teeth - 1)) * PI) * grin_curve * 0.7
			var tooth_pts: PackedVector2Array = PackedVector2Array([
				Vector2(tx, ty - 0.8),
				Vector2(tx + 1.2, ty),
				Vector2(tx, ty + 0.8),
			])
			draw_colored_polygon(tooth_pts, Color(0.95, 0.9, 0.8, 0.9))
	else:
		# Simple curved smile
		var smile_pts: Array[Vector2] = []
		for i in range(8):
			var t: float = float(i) / 7.0
			var gx: float = mouth_x + sin(t * PI) * (1.0 + _grin_width * 2.0)
			var gy: float = -grin_w * 0.5 + t * grin_w
			smile_pts.append(Vector2(gx, gy))
		for i in range(len(smile_pts) - 1):
			draw_line(smile_pts[i], smile_pts[i + 1], Color(0.2, 0.1, 0.1, 0.9), 1.2, true)

	# Drool when really feeding
	if _grin_width > 0.6:
		var drool_y: float = fmod(_time * 2.0, 1.0) * 5.0
		var drool_alpha: float = 1.0 - drool_y / 5.0
		draw_circle(Vector2(mouth_x + grin_curve * 0.3, grin_w * 0.3 + drool_y), 0.8, Color(0.6, 0.8, 0.5, drool_alpha * 0.6))

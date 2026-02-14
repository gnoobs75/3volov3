extends Area2D
## Parasite organism: chases player and latches on. If 5 attach, they take over the cell.
## Visually: small wormy organism with creepy grin that gets more frantic near player.

enum State { SEEK, ATTACHED, DRIFT, FLEE }

var state: State = State.DRIFT
var _time: float = 0.0
var speed: float = 70.0
var detection_range: float = 150.0
var _flee_timer: float = 0.0
var _flee_dir: Vector2 = Vector2.ZERO
var _radius: float = 5.0
var _base_color: Color
var drift_target: Vector2 = Vector2.ZERO
var drift_timer: float = 0.0
var attach_offset: Vector2 = Vector2.ZERO  # Offset from player when attached
var _attached_to: Node2D = null
var _wiggle_phase: float = 0.0
var _body_segments: int = 0
var _attach_duration: float = 0.0  # Time attached
var _energy_drain_rate: float = 1.5  # Energy per second while attached
var _reproduce_threshold: float = 25.0  # Seconds before reproducing
var _has_reproduced: bool = false

func _ready() -> void:
	_radius = randf_range(4.0, 6.0)
	_base_color = Color(
		randf_range(0.4, 0.6),
		randf_range(0.1, 0.25),
		randf_range(0.3, 0.5),
		0.9
	)
	_body_segments = randi_range(3, 5)
	_wiggle_phase = randf() * TAU
	add_to_group("parasites")
	body_entered.connect(_on_body_entered)
	_pick_drift_target()

func _pick_drift_target() -> void:
	drift_target = global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	drift_timer = randf_range(2.0, 4.0)

func _physics_process(delta: float) -> void:
	_time += delta

	match state:
		State.DRIFT:
			drift_timer -= delta
			if drift_timer <= 0 or global_position.distance_to(drift_target) < 15:
				_pick_drift_target()
			var dir: Vector2 = global_position.direction_to(drift_target)
			global_position += dir * speed * 0.3 * delta
			# Check for player
			var player := _find_player()
			if player:
				var dist: float = global_position.distance_to(player.global_position)
				if dist < detection_range:
					state = State.SEEK

		State.SEEK:
			var player := _find_player()
			if not player:
				state = State.DRIFT
				return
			var dist: float = global_position.distance_to(player.global_position)
			if dist > detection_range * 1.5:
				state = State.DRIFT
				return
			# Chase with increasing urgency
			var urgency: float = 1.0 + (1.0 - dist / detection_range) * 0.8
			var dir: Vector2 = global_position.direction_to(player.global_position)
			global_position += dir * speed * urgency * delta

		State.ATTACHED:
			if not is_instance_valid(_attached_to):
				_detach()
				return
			global_position = _attached_to.global_position + attach_offset.rotated(_attached_to.rotation)
			_attach_duration += delta
			# Drain host energy
			if _attached_to.has_method("get") and _attached_to.get("energy") != null:
				_attached_to.energy = maxf(_attached_to.energy - _energy_drain_rate * delta, 0.0)
			# Reproduce after threshold
			if _attach_duration >= _reproduce_threshold and not _has_reproduced:
				_has_reproduced = true
				_try_reproduce()

		State.FLEE:
			_flee_timer -= delta
			if _flee_timer <= 0:
				state = State.DRIFT
				_pick_drift_target()
			else:
				global_position += _flee_dir * speed * 3.0 * delta

	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if state == State.ATTACHED:
		return
	if body.is_in_group("player") and body.has_method("attach_parasite"):
		_attach_to(body)

func _attach_to(target: Node2D) -> void:
	state = State.ATTACHED
	_attached_to = target
	# Random position around the cell edge
	var angle: float = randf() * TAU
	attach_offset = Vector2(cos(angle) * 20.0, sin(angle) * 20.0)
	if target.has_method("attach_parasite"):
		target.attach_parasite(self)

func _detach() -> void:
	state = State.DRIFT
	_attached_to = null
	_pick_drift_target()

func force_detach() -> void:
	var flee_from: Vector2 = global_position
	if is_instance_valid(_attached_to):
		flee_from = _attached_to.global_position
	_detach()
	_flee_dir = (global_position - flee_from).normalized()
	if _flee_dir.length() < 0.5:
		_flee_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	_flee_timer = 2.0
	state = State.FLEE

func _try_reproduce() -> void:
	## Spawn a new parasite nearby the attached host
	if not is_instance_valid(_attached_to):
		return
	# Global cap: prevent exponential parasite growth
	if get_tree().get_nodes_in_group("parasites").size() >= 8:
		return
	var ParasiteScene := preload("res://scenes/parasite_organism.tscn")
	var offspring := ParasiteScene.instantiate()
	var spawn_offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
	offspring.global_position = global_position + spawn_offset
	get_parent().add_child(offspring)

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
	# Wormy segmented body — turns redder while attached
	var seg_size: float = _radius
	var prev_pos := Vector2.ZERO
	var color_shift: float = clampf(_attach_duration / _reproduce_threshold, 0.0, 1.0) if state == State.ATTACHED else 0.0
	var active_color := _base_color.lerp(Color(0.85, 0.15, 0.1), color_shift * 0.6)

	for s in range(_body_segments):
		var t: float = float(s) / _body_segments
		var wiggle: float = sin(_time * 6.0 + _wiggle_phase + s * 1.2) * 3.0
		var sx: float = -s * seg_size * 0.8
		var sy: float = wiggle
		var seg_pos := Vector2(sx, sy)
		var seg_r: float = seg_size * (1.0 - t * 0.3)
		var seg_color := Color(active_color.r * (1.0 - t * 0.2), active_color.g, active_color.b * (1.0 - t * 0.15), 0.8)
		draw_circle(seg_pos, seg_r, seg_color)
		if s > 0:
			draw_line(prev_pos, seg_pos, Color(_base_color, 0.5), seg_r * 0.8, true)
		prev_pos = seg_pos

	# Head (first segment gets the face)
	var head_pos := Vector2.ZERO

	# State-dependent face
	match state:
		State.DRIFT:
			# Neutral beady eyes
			draw_circle(head_pos + Vector2(2, -2), 1.5, Color(0.95, 0.9, 0.85, 0.9))
			draw_circle(head_pos + Vector2(2, 2), 1.5, Color(0.95, 0.9, 0.85, 0.9))
			draw_circle(head_pos + Vector2(2.3, -2), 0.7, Color(0.1, 0.0, 0.1, 0.9))
			draw_circle(head_pos + Vector2(2.3, 2), 0.7, Color(0.1, 0.0, 0.1, 0.9))
		State.SEEK:
			# Wide excited eyes, creepy grin
			var pulse: float = 1.0 + 0.2 * sin(_time * 8.0)
			draw_circle(head_pos + Vector2(2, -2.5), 2.0 * pulse, Color(0.95, 0.85, 0.85, 0.95))
			draw_circle(head_pos + Vector2(2, 2.5), 2.0 * pulse, Color(0.95, 0.85, 0.85, 0.95))
			# Tiny pinprick pupils
			draw_circle(head_pos + Vector2(2.5, -2.5), 0.5, Color(0.2, 0.0, 0.0, 1.0))
			draw_circle(head_pos + Vector2(2.5, 2.5), 0.5, Color(0.2, 0.0, 0.0, 1.0))
			# Creepy wide grin
			draw_arc(head_pos + Vector2(3, 0), 2.5, -0.8, 0.8, 8, Color(0.2, 0.0, 0.1, 0.9), 1.0, true)
		State.ATTACHED:
			# Satisfied squint, latched
			var squint: float = 0.4
			for ep in [Vector2(1.5, -2), Vector2(1.5, 2)]:
				var eye_pts: PackedVector2Array = PackedVector2Array()
				for i in range(8):
					var a: float = TAU * i / 8.0
					eye_pts.append(head_pos + ep + Vector2(cos(a) * 1.5, sin(a) * 1.5 * squint))
				draw_colored_polygon(eye_pts, Color(0.95, 0.9, 0.85, 0.9))
				draw_circle(head_pos + ep, 0.6, Color(0.1, 0.0, 0.1, 0.9))
			# Happy creepy smile
			draw_arc(head_pos + Vector2(2.5, 0), 2.0, -0.6, 0.6, 8, Color(0.2, 0.0, 0.1, 0.8), 1.2, true)

	# Flee face: terrified
	if state == State.FLEE:
		for ep in [Vector2(2, -2.5), Vector2(2, 2.5)]:
			draw_circle(head_pos + ep, 2.2, Color(0.95, 0.9, 0.85, 0.95))
			draw_circle(head_pos + ep + Vector2(0.5, 0), 0.5, Color(0.1, 0.0, 0.1, 0.9))
		# Screaming O mouth
		draw_circle(head_pos + Vector2(3.5, 0), 1.8, Color(0.15, 0.0, 0.1, 0.9))

	# Attached indicator: pulsing red aura
	if state == State.ATTACHED:
		var pulse_a: float = 0.15 + 0.1 * sin(_time * 4.0)
		draw_circle(Vector2.ZERO, _radius * 2.0, Color(0.8, 0.1, 0.2, pulse_a))

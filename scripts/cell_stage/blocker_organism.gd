extends StaticBody2D
## Blocker organism: immovable colonial structure that blocks passage.
## Visually: dense coral-like or biofilm mass with a stubborn face.

var _time: float = 0.0
var _radius: float = 20.0
var _base_color: Color
var _branch_count: int = 0
var _branch_angles: Array[float] = []
var _branch_lengths: Array[float] = []
var _shape_points: Array[Vector2] = []

# Face animation
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _yawn_timer: float = 0.0
var _is_yawning: bool = false
var _eye_roll_angle: float = 0.0
var _annoyance: float = 0.0  # Increases when player is nearby
var _player: Node2D = null

func _ready() -> void:
	_radius = randf_range(16.0, 26.0)
	_base_color = Color(
		randf_range(0.4, 0.6),
		randf_range(0.35, 0.5),
		randf_range(0.25, 0.4),
		0.9
	)
	_branch_count = randi_range(5, 9)
	for i in range(_branch_count):
		_branch_angles.append(TAU * i / _branch_count + randf_range(-0.3, 0.3))
		_branch_lengths.append(randf_range(6.0, 14.0))
	# Irregular rock/coral shape
	for i in range(20):
		var a: float = TAU * i / 20.0
		var r: float = _radius + randf_range(-3.0, 4.0)
		_shape_points.append(Vector2(cos(a) * r, sin(a) * r))
	add_to_group("blockers")
	_blink_timer = randf_range(3.0, 8.0)
	_yawn_timer = randf_range(8.0, 20.0)
	call_deferred("_cache_player")

func _cache_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]

func _process(delta: float) -> void:
	_time += delta

	# Check if player is nearby for annoyance (cached ref)
	if not is_instance_valid(_player):
		_player = null
	if _player:
		var player_dist: float = global_position.distance_to(_player.global_position)
		if player_dist < 150.0:
			_annoyance = minf(_annoyance + delta * 0.5, 1.0)
		else:
			_annoyance = maxf(_annoyance - delta * 0.3, 0.0)

	# Blink timer
	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(3.0, 8.0)
		else:
			_is_blinking = true
			_blink_timer = 0.2  # Slow, heavy blink

	# Yawn timer
	_yawn_timer -= delta
	if _yawn_timer <= 0:
		if _is_yawning:
			_is_yawning = false
			_yawn_timer = randf_range(10.0, 25.0)
		else:
			_is_yawning = true
			_yawn_timer = 1.5  # Yawn duration

	# Eye roll when annoyed
	if _annoyance > 0.5:
		_eye_roll_angle = sin(_time * 2.0) * 0.3
	else:
		_eye_roll_angle = lerpf(_eye_roll_angle, 0.0, delta * 3.0)

	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _draw() -> void:
	# Shadow
	draw_circle(Vector2(2, 2), _radius, Color(0.0, 0.0, 0.0, 0.15))

	# Main body
	var pts: PackedVector2Array = PackedVector2Array()
	for p in _shape_points:
		pts.append(p)
	draw_colored_polygon(pts, Color(_base_color.r * 0.4, _base_color.g * 0.35, _base_color.b * 0.3, 0.85))

	# Texture: rocky bumps
	for b in range(6):
		var ba: float = TAU * b / 6.0 + 0.3
		var bd: float = _radius * randf_range(0.2, 0.6)
		var bp := Vector2(cos(ba) * bd, sin(ba) * bd)
		draw_circle(bp, randf_range(2.0, 4.0), Color(_base_color.r * 0.5, _base_color.g * 0.45, _base_color.b * 0.35, 0.4))

	# Coral branches
	for i in range(_branch_count):
		var ba: float = _branch_angles[i]
		var bl: float = _branch_lengths[i]
		var base_pt := Vector2(cos(ba) * _radius * 0.8, sin(ba) * _radius * 0.8)
		var tip_pt := base_pt + Vector2(cos(ba) * bl, sin(ba) * bl)
		# Slight sway
		tip_pt += Vector2(sin(_time * 1.5 + i) * 1.5, cos(_time * 1.2 + i * 0.7) * 1.5)
		draw_line(base_pt, tip_pt, Color(_base_color.r * 0.7, _base_color.g * 0.6, _base_color.b * 0.5, 0.7), 2.5, true)
		# Branch tip dot
		draw_circle(tip_pt, 2.0, Color(_base_color, 0.6))

	# Outline
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(_base_color, 0.7), 1.5, true)

	# Stubborn face (barely visible, like it's embedded in rock)
	var face_a: float = 0.6 + 0.1 * sin(_time * 0.5)
	# Tiny unamused eyes
	var le := Vector2(-2.5, 0)
	var re := Vector2(2.5, 0)

	# Eye roll offset when annoyed
	var roll_offset := Vector2(sin(_eye_roll_angle) * 1.0, cos(_eye_roll_angle) * 0.5 - 0.5)

	var eye_squash: float = 1.0
	if _is_blinking:
		eye_squash = 0.15

	# Eyes - slightly squashed when bored/blinking
	var eye_h: float = 2.5 * eye_squash
	for eye_pos in [le, re]:
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			eye_pts.append(eye_pos + Vector2(cos(a) * 2.5, sin(a) * eye_h))
		draw_colored_polygon(eye_pts, Color(0.9, 0.85, 0.8, face_a))

	# Pupils with eye roll
	if not _is_blinking:
		draw_circle(le + roll_offset, 1.0, Color(0.1, 0.08, 0.05, face_a))
		draw_circle(re + roll_offset, 1.0, Color(0.1, 0.08, 0.05, face_a))

	# Heavy droopy eyelids
	var lid_droop: float = 1.5 if _annoyance > 0.3 else 1.0
	draw_line(le + Vector2(-3.0, -0.5), le + Vector2(3.0, -0.5 + lid_droop), Color(_base_color.r * 0.3, _base_color.g * 0.3, _base_color.b * 0.25, face_a), 2.5, true)
	draw_line(re + Vector2(-3.0, -0.5 + lid_droop), re + Vector2(3.0, -0.5), Color(_base_color.r * 0.3, _base_color.g * 0.3, _base_color.b * 0.25, face_a), 2.5, true)

	# Mouth - yawns occasionally
	if _is_yawning:
		# Big open yawn mouth
		var yawn_progress: float = sin((_yawn_timer / 1.5) * PI)  # Peaks in middle
		var yawn_size: float = 2.0 + yawn_progress * 4.0
		var yawn_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			yawn_pts.append(Vector2(4, 0) + Vector2(cos(a) * yawn_size * 0.8, sin(a) * yawn_size))
		draw_colored_polygon(yawn_pts, Color(0.1, 0.05, 0.05, face_a))
		# Tiny uvula wiggle
		if yawn_progress > 0.3:
			var uvula_y: float = sin(_time * 6.0) * 0.5
			draw_circle(Vector2(4 - yawn_size * 0.3, uvula_y), 0.6, Color(0.8, 0.4, 0.4, face_a * 0.7))
	else:
		# Flat annoyed line mouth - slight frown when annoyed
		var frown: float = _annoyance * 1.5
		draw_line(Vector2(-3, 4), Vector2(0, 4 + frown), Color(0.15, 0.1, 0.08, face_a), 1.5, true)
		draw_line(Vector2(0, 4 + frown), Vector2(3, 4), Color(0.15, 0.1, 0.08, face_a), 1.5, true)

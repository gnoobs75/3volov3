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

func _process(delta: float) -> void:
	_time += delta
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
	var face_a: float = 0.5 + 0.1 * sin(_time * 0.5)
	# Tiny unamused eyes
	var le := Vector2(-2.5, 0)
	var re := Vector2(2.5, 0)
	draw_circle(le, 2.5, Color(0.9, 0.85, 0.8, face_a))
	draw_circle(re, 2.5, Color(0.9, 0.85, 0.8, face_a))
	# Half-lidded pupils (bored)
	draw_circle(le, 1.0, Color(0.1, 0.08, 0.05, face_a))
	draw_circle(re, 1.0, Color(0.1, 0.08, 0.05, face_a))
	# Heavy eyelids (top half darkened)
	draw_line(le + Vector2(-2.5, -0.5), le + Vector2(2.5, -0.5), Color(_base_color.r * 0.3, _base_color.g * 0.3, _base_color.b * 0.25, face_a), 2.0, true)
	draw_line(re + Vector2(-2.5, -0.5), re + Vector2(2.5, -0.5), Color(_base_color.r * 0.3, _base_color.g * 0.3, _base_color.b * 0.25, face_a), 2.0, true)
	# Flat line mouth
	draw_line(Vector2(-3, 4), Vector2(3, 4), Color(0.15, 0.1, 0.08, face_a), 1.5, true)

extends Node2D
## Visual rendering for terrain obstacle rocks/barriers.

var _time: float = 0.0
var _radius: float = 40.0
var _pts: PackedVector2Array

func _ready() -> void:
	_radius = get_meta("radius", 40.0)
	# Generate rocky polygon
	_pts = PackedVector2Array()
	var num_pts: int = randi_range(6, 10)
	for i in range(num_pts):
		var angle: float = TAU * float(i) / float(num_pts)
		var r: float = _radius * randf_range(0.7, 1.0)
		_pts.append(Vector2(cos(angle) * r, sin(angle) * r))

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if _pts.size() < 3:
		return
	# Rock body
	draw_colored_polygon(_pts, Color(0.12, 0.1, 0.08, 0.85))
	# Edge highlight
	for i in range(_pts.size()):
		var next: int = (i + 1) % _pts.size()
		draw_line(_pts[i], _pts[next], Color(0.2, 0.18, 0.14, 0.4), 1.5)
	# Subtle moss/growth
	var moss_pos: Vector2 = Vector2(cos(_time * 0.1) * 5.0, sin(_time * 0.1) * 5.0)
	draw_circle(moss_pos, _radius * 0.3, Color(0.1, 0.25, 0.1, 0.15))

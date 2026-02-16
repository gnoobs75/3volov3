extends Node2D
## Brief expanding ring + particles on projectile impact.

var _time: float = 0.0
var _color: Color = Color.WHITE
const LIFETIME: float = 0.4

func setup(color: Color) -> void:
	_color = color

func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = _time / LIFETIME
	var alpha: float = 1.0 - t
	var radius: float = 4.0 + t * 18.0
	# Expanding ring
	draw_arc(Vector2.ZERO, radius, 0, TAU, 12, Color(_color.r, _color.g, _color.b, alpha * 0.6), 1.5)
	# Inner flash
	if t < 0.15:
		draw_circle(Vector2.ZERO, 5.0 * (1.0 - t / 0.15), Color(1.0, 1.0, 1.0, 0.7 * alpha))
	# Splash particles
	for i in range(4):
		var angle: float = TAU * float(i) / 4.0 + 0.7
		var dist: float = t * 20.0
		var pt: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
		var pt_size: float = 2.0 * (1.0 - t)
		draw_circle(pt, pt_size, Color(_color.r, _color.g, _color.b, alpha * 0.5))

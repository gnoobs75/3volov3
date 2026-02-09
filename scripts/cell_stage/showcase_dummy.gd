extends CharacterBody2D
## Dummy cell used during creature showcase cinematic.
## Looks like a simple cell, is in "player" group so hostile creatures target it.
## Has minimal health so creatures can demonstrate their attacks.

var _time: float = 0.0
var _radius: float = 14.0
var _base_color: Color = Color(0.3, 0.7, 0.5, 0.8)
var _membrane_points: Array[Vector2] = []
var _damage_flash: float = 0.0
var health: float = 500.0  # Very high health so it survives the full showcase phase
var attached_parasites: Array = []

func _ready() -> void:
	add_to_group("player")
	_init_shape()

func _init_shape() -> void:
	_membrane_points.clear()
	for i in range(20):
		var angle: float = TAU * i / 20.0
		var r: float = _radius + randf_range(-1.5, 1.5)
		_membrane_points.append(Vector2(cos(angle) * r, sin(angle) * r))

func _physics_process(delta: float) -> void:
	_time += delta
	_damage_flash = maxf(_damage_flash - delta * 3.0, 0.0)
	queue_redraw()

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0

func attach_parasite(parasite: Node2D) -> void:
	attached_parasites.append(parasite)

func _draw() -> void:
	# Glow
	var glow_a: float = 0.06 + 0.03 * sin(_time * 2.0)
	draw_circle(Vector2.ZERO, _radius * 2.0, Color(_base_color.r, _base_color.g, _base_color.b, glow_a))

	# Membrane
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(_membrane_points.size()):
		var wobble := sin(_time * 3.0 + i * 0.7) * 1.0
		pts.append(_membrane_points[i] + _membrane_points[i].normalized() * wobble)

	var fill := Color(0.1, 0.2, 0.35, 0.6)
	if _damage_flash > 0:
		fill = fill.lerp(Color(1.0, 0.2, 0.2), _damage_flash)
	draw_colored_polygon(pts, fill)

	var outline_col := _base_color
	if _damage_flash > 0:
		outline_col = outline_col.lerp(Color(1.0, 0.3, 0.3), _damage_flash)
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], outline_col, 1.2, true)

	# Simple eyes
	var le := Vector2(4, -3)
	var re := Vector2(4, 3)
	for eye_pos in [le, re]:
		draw_circle(eye_pos, 2.5, Color(0.9, 0.9, 0.95, 0.9))
		draw_circle(eye_pos + Vector2(0.5, 0), 1.0, Color(0.1, 0.15, 0.2, 0.9))

	# Small smile
	draw_arc(Vector2(6, 0), 2.0, -0.5, 0.5, 6, Color(0.15, 0.2, 0.3, 0.8), 1.0, true)

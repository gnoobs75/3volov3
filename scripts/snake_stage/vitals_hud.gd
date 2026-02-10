extends Control
## Organic membrane-style arc bars for health (left) and energy (right).
## Drawn via _draw(), centered on screen where the character roughly is.
## Features layered glow, wavy edges, flowing cell dots, and soft tips.

var health_ratio: float = 1.0
var energy_ratio: float = 1.0
var _time: float = 0.0

# Arc parameters
const ARC_RADIUS: float = 140.0
const ARC_BG_ALPHA: float = 0.12
const ARC_FILL_ALPHA: float = 0.45

# Health arc: left side, centered on 180° (120° to 240°)
const HEALTH_START_ANGLE: float = 120.0
const HEALTH_END_ANGLE: float = 240.0

# Energy arc: right side, centered on 0° (-60° to 60°)
const ENERGY_START_ANGLE: float = -60.0
const ENERGY_END_ANGLE: float = 60.0

# Organic visual parameters
const WAVE_AMPLITUDE: float = 1.5
const WAVE_FREQUENCY: float = 12.0
const NUM_FLOW_DOTS: int = 5
const DOT_RADIUS: float = 2.5
const DOT_SPEED: float = 0.15
const HUE_SHIFT_AMOUNT: float = 0.04

# Reusable draw buffers (avoid per-frame allocations)
var _buf_points: PackedVector2Array = PackedVector2Array()
var _buf_outer: PackedVector2Array = PackedVector2Array()
var _buf_inner: PackedVector2Array = PackedVector2Array()
var _buf_colors: PackedColorArray = PackedColorArray()
var _buf_polygon: PackedVector2Array = PackedVector2Array()
var _buf_poly_colors: PackedColorArray = PackedColorArray()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = get_viewport_rect().size * 0.5

	# Health arc (left side, red)
	_draw_organic_arc(
		center, ARC_RADIUS,
		deg_to_rad(HEALTH_START_ANGLE), deg_to_rad(HEALTH_END_ANGLE),
		health_ratio,
		Color(0.8, 0.1, 0.05), Color(0.4, 0.05, 0.02),
		health_ratio < 0.25
	)

	# Energy arc (right side, green)
	_draw_organic_arc(
		center, ARC_RADIUS,
		deg_to_rad(ENERGY_START_ANGLE), deg_to_rad(ENERGY_END_ANGLE),
		energy_ratio,
		Color(0.1, 0.7, 0.4), Color(0.05, 0.35, 0.15),
		energy_ratio < 0.25
	)

func _draw_organic_arc(
	center: Vector2, radius: float,
	start_angle: float, end_angle: float,
	fill_ratio: float,
	color_bright: Color, color_dark: Color,
	pulsing: bool
) -> void:
	var segments: int = 48

	# --- Background arc (full span, dark translucent) ---
	var bg_color: Color = color_dark
	bg_color.a = ARC_BG_ALPHA
	# Outer glow layer (wide, very faint)
	_draw_wavy_arc(center, radius, start_angle, end_angle, segments,
		_with_alpha(bg_color, 0.08), 20.0, 0.0)
	# Mid membrane layer
	_draw_wavy_arc(center, radius, start_angle, end_angle, segments,
		_with_alpha(bg_color, 0.15), 14.0, 0.0)
	# Background core
	_draw_wavy_arc(center, radius, start_angle, end_angle, segments,
		bg_color, 6.0, 0.0)

	# --- Foreground arc (filled portion) ---
	if fill_ratio > 0.01:
		var fill_end: float = lerpf(start_angle, end_angle, fill_ratio)
		var fg_color: Color = color_bright
		fg_color.a = ARC_FILL_ALPHA

		# Low pulse effect (slower breathing)
		if pulsing:
			var pulse: float = sin(_time * 4.0) * 0.3 + 0.7
			fg_color.a *= pulse
			fg_color = fg_color.lightened(0.1 * (1.0 - pulse))

		# Outer glow layer
		_draw_wavy_arc(center, radius, start_angle, fill_end, segments,
			_with_alpha(fg_color, fg_color.a * 0.18), 20.0, 0.0)
		# Mid membrane layer
		_draw_wavy_arc(center, radius, start_angle, fill_end, segments,
			_with_alpha(fg_color, fg_color.a * 0.35), 14.0, 0.0)
		# Main fill arc (polygon with variable width for vein-like taper)
		_draw_vein_arc(center, radius, start_angle, fill_end, segments, fg_color)
		# Inner highlight (thin bright core)
		var highlight: Color = color_bright.lightened(0.3)
		highlight.a = 0.3
		if pulsing:
			highlight.a *= sin(_time * 4.0) * 0.3 + 0.7
		_draw_wavy_arc(center, radius, start_angle, fill_end, segments,
			highlight, 2.0, WAVE_AMPLITUDE * 0.5)

		# Flowing "cell" dots
		_draw_flow_dots(center, radius, start_angle, fill_end, fg_color, color_bright)

		# Soft tip (fading glow instead of hard circle)
		_draw_soft_tip(center, radius, fill_end, color_bright, pulsing)

func _draw_wavy_arc(
	center: Vector2, radius: float,
	start_angle: float, end_angle: float,
	segments: int, color: Color, width: float,
	wave_amp: float
) -> void:
	_buf_points.clear()
	for i in range(segments + 1):
		var t: float = float(i) / segments
		var angle: float = lerpf(start_angle, end_angle, t)
		var r: float = radius
		if wave_amp > 0.0:
			r += sin(angle * WAVE_FREQUENCY + _time * 2.0) * wave_amp
		_buf_points.append(center + Vector2(cos(angle), sin(angle)) * r)

	if _buf_points.size() >= 2:
		draw_polyline(_buf_points, color, width, true)

func _draw_vein_arc(
	center: Vector2, radius: float,
	start_angle: float, end_angle: float,
	segments: int, color: Color
) -> void:
	# Build a polygon that's thicker in the center, tapering at the ends
	# with wavy edge perturbation for organic feel
	_buf_outer.clear()
	_buf_inner.clear()
	_buf_colors.clear()

	for i in range(segments + 1):
		var t: float = float(i) / segments
		var angle: float = lerpf(start_angle, end_angle, t)

		var taper: float = 4.0 * t * (1.0 - t)
		var half_w: float = lerpf(1.0, 6.0, taper)

		var wave_outer: float = sin(angle * WAVE_FREQUENCY + _time * 2.0) * WAVE_AMPLITUDE
		var wave_inner: float = sin(angle * WAVE_FREQUENCY + _time * 2.0 + 1.5) * WAVE_AMPLITUDE

		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		_buf_outer.append(center + dir * (radius + half_w + wave_outer))
		_buf_inner.append(center + dir * (radius - half_w + wave_inner))

		var shifted_color: Color = _hue_shift(color, (t - 0.5) * HUE_SHIFT_AMOUNT)
		_buf_colors.append(shifted_color)

	# Combine into a closed polygon (outer forward, inner reversed)
	_buf_polygon.clear()
	_buf_poly_colors.clear()
	for i in range(_buf_outer.size()):
		_buf_polygon.append(_buf_outer[i])
		_buf_poly_colors.append(_buf_colors[i])
	for i in range(_buf_inner.size() - 1, -1, -1):
		_buf_polygon.append(_buf_inner[i])
		_buf_poly_colors.append(_buf_colors[i])

	if _buf_polygon.size() >= 3:
		draw_polygon(_buf_polygon, _buf_poly_colors)

func _draw_flow_dots(
	center: Vector2, radius: float,
	start_angle: float, end_angle: float,
	fill_color: Color, bright_color: Color
) -> void:
	var arc_span: float = end_angle - start_angle
	if absf(arc_span) < 0.01:
		return

	for i in range(NUM_FLOW_DOTS):
		# Each dot drifts at its own phase offset
		var phase: float = float(i) / NUM_FLOW_DOTS
		var drift: float = fmod(_time * DOT_SPEED + phase, 1.0)
		var t: float = drift
		var angle: float = lerpf(start_angle, end_angle, t)

		# Wavy radius to match the arc
		var r: float = radius + sin(angle * WAVE_FREQUENCY + _time * 2.0) * WAVE_AMPLITUDE * 0.5

		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * r

		# Dot color: brighter than fill, semi-transparent
		var dot_color: Color = bright_color.lightened(0.2)
		# Fade dots near the ends for smooth appearance
		var edge_fade: float = smoothstep(0.0, 0.1, t) * smoothstep(1.0, 0.9, t)
		dot_color.a = 0.35 * edge_fade

		# Slight size variation with time
		var dot_r: float = DOT_RADIUS * (0.7 + 0.3 * sin(_time * 3.0 + float(i) * 1.7))

		# Draw dot with soft edge (two layers)
		draw_circle(pos, dot_r * 1.8, _with_alpha(dot_color, dot_color.a * 0.3))
		draw_circle(pos, dot_r, dot_color)

func _draw_soft_tip(
	center: Vector2, radius: float,
	tip_angle: float, bright_color: Color, pulsing: bool
) -> void:
	var tip_pos: Vector2 = center + Vector2(cos(tip_angle), sin(tip_angle)) * radius
	var base_alpha: float = 0.5
	if pulsing:
		base_alpha *= sin(_time * 4.0) * 0.3 + 0.7

	var tip_color: Color = bright_color.lightened(0.3)
	# 3 concentric circles with decreasing alpha for soft glow
	draw_circle(tip_pos, 6.0, _with_alpha(tip_color, base_alpha * 0.12))
	draw_circle(tip_pos, 4.0, _with_alpha(tip_color, base_alpha * 0.25))
	draw_circle(tip_pos, 2.0, _with_alpha(tip_color, base_alpha * 0.5))

# --- Utility functions ---

func _with_alpha(color: Color, alpha: float) -> Color:
	var c: Color = color
	c.a = alpha
	return c

func _hue_shift(color: Color, amount: float) -> Color:
	var h: float = color.h + amount
	var s: float = color.s
	var v: float = color.v
	var a: float = color.a
	return Color.from_hsv(fmod(h + 1.0, 1.0), s, v, a)

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

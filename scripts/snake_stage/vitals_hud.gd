extends Control
## Curved parentheses-style arc bars for health (left, red) and energy (right, green).
## Drawn via _draw(), centered on screen where the character roughly is.

var health_ratio: float = 1.0
var energy_ratio: float = 1.0
var _time: float = 0.0

# Arc parameters
const ARC_RADIUS: float = 120.0
const ARC_WIDTH: float = 8.0
const ARC_BG_ALPHA: float = 0.25

# Health arc: 7 o'clock to 11 o'clock (210° to 330°)
const HEALTH_START_ANGLE: float = 210.0
const HEALTH_END_ANGLE: float = 330.0

# Energy arc: 1 o'clock to 5 o'clock (30° to 150°)
const ENERGY_START_ANGLE: float = 30.0
const ENERGY_END_ANGLE: float = 150.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = get_viewport_rect().size * 0.5

	# Health arc (left side, red)
	_draw_arc_bar(
		center, ARC_RADIUS,
		deg_to_rad(HEALTH_START_ANGLE), deg_to_rad(HEALTH_END_ANGLE),
		health_ratio,
		Color(0.8, 0.1, 0.05), Color(0.4, 0.05, 0.02),
		health_ratio < 0.25
	)

	# Energy arc (right side, green)
	_draw_arc_bar(
		center, ARC_RADIUS,
		deg_to_rad(ENERGY_START_ANGLE), deg_to_rad(ENERGY_END_ANGLE),
		energy_ratio,
		Color(0.1, 0.7, 0.4), Color(0.05, 0.35, 0.15),
		energy_ratio < 0.25
	)

func _draw_arc_bar(
	center: Vector2, radius: float,
	start_angle: float, end_angle: float,
	fill_ratio: float,
	color_bright: Color, color_dark: Color,
	pulsing: bool
) -> void:
	var segments: int = 32

	# Background arc (dark, translucent)
	var bg_color: Color = color_dark
	bg_color.a = ARC_BG_ALPHA
	_draw_thick_arc(center, radius, start_angle, end_angle, segments, bg_color, ARC_WIDTH)

	# Foreground arc (filled portion)
	if fill_ratio > 0.01:
		var fill_end: float = lerpf(start_angle, end_angle, fill_ratio)
		var fg_color: Color = color_bright
		fg_color.a = 0.8

		# Low pulse effect
		if pulsing:
			var pulse: float = sin(_time * 6.0) * 0.3 + 0.7
			fg_color.a *= pulse
			fg_color = fg_color.lightened(0.1 * (1.0 - pulse))

		_draw_thick_arc(center, radius, start_angle, fill_end, segments, fg_color, ARC_WIDTH)

		# Bright tip at the fill end
		var tip_angle: float = fill_end
		var tip_pos: Vector2 = center + Vector2(cos(tip_angle), sin(tip_angle)) * radius
		var tip_color: Color = color_bright.lightened(0.4)
		tip_color.a = 0.9
		draw_circle(tip_pos, ARC_WIDTH * 0.6, tip_color)

func _draw_thick_arc(
	center: Vector2, radius: float,
	start_angle: float, end_angle: float,
	segments: int, color: Color, width: float
) -> void:
	# Draw as a series of connected line segments forming a thick arc
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for i in range(segments + 1):
		var t: float = float(i) / segments
		var angle: float = lerpf(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		colors.append(color)

	if points.size() >= 2:
		draw_polyline_colors(points, colors, width, true)

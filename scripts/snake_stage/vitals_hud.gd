extends Control
## Organic membrane-style arc bars for health (left) and energy (right).
## Drawn via _draw(), centered on screen where the character roughly is.
## Features layered glow, wavy edges, flowing cell dots, soft tips,
## and a delta-flash effect showing recent gains/losses.
## Both bars drain from the top (end of arc disappears first).

var health_ratio: float = 1.0
var energy_ratio: float = 1.0
var _time: float = 0.0

# Boss health bar state (set via metadata by snake_stage_manager)
var _boss_bar_alpha: float = 0.0  # Fade in/out
var _boss_bar_shake: float = 0.0  # Screen shake on damage

# Boss intro title card state (set via metadata)
var _intro_alpha: float = 0.0

# Arc parameters — pushed far from center, tall and narrow
const ARC_RADIUS: float = 210.0
const ARC_BG_ALPHA: float = 0.05
const ARC_FILL_ALPHA: float = 0.20

# Health arc: left side, centered on 180° — tall narrow arc
const HEALTH_START_ANGLE: float = 145.0
const HEALTH_END_ANGLE: float = 215.0

# Energy arc: right side — REVERSED so it drains from top like health
# Goes from 35° (lower-right) up to -35° (upper-right)
const ENERGY_START_ANGLE: float = 35.0
const ENERGY_END_ANGLE: float = -35.0

# Organic visual parameters
const WAVE_AMPLITUDE: float = 1.5
const WAVE_FREQUENCY: float = 12.0
const NUM_FLOW_DOTS: int = 5
const DOT_RADIUS: float = 2.5
const DOT_SPEED: float = 0.15
const HUE_SHIFT_AMOUNT: float = 0.04

# Delta flash system — shows recent change as a fading ghost arc
var _prev_health: float = 1.0
var _prev_energy: float = 1.0
var _health_flash_ratio: float = 0.0
var _energy_flash_ratio: float = 0.0
var _health_flash_alpha: float = 0.0
var _energy_flash_alpha: float = 0.0
const FLASH_FADE_SPEED: float = 2.0

# Reusable draw buffers (avoid per-frame allocations)
var _buf_points: PackedVector2Array = PackedVector2Array()
var _buf_outer: PackedVector2Array = PackedVector2Array()
var _buf_inner: PackedVector2Array = PackedVector2Array()
var _buf_colors: PackedColorArray = PackedColorArray()
var _buf_polygon: PackedVector2Array = PackedVector2Array()
var _buf_poly_colors: PackedColorArray = PackedColorArray()

func _process(delta: float) -> void:
	_time += delta

	# Detect health changes for flash effect
	if absf(health_ratio - _prev_health) > 0.01:
		_health_flash_ratio = _prev_health
		_health_flash_alpha = 0.6
		_prev_health = health_ratio

	if absf(energy_ratio - _prev_energy) > 0.01:
		_energy_flash_ratio = _prev_energy
		_energy_flash_alpha = 0.6
		_prev_energy = energy_ratio

	# Boss bar fade
	var boss_active: bool = get_meta("boss_health", -1.0) >= 0.0
	if boss_active:
		_boss_bar_alpha = minf(_boss_bar_alpha + delta * 3.0, 1.0)
	else:
		_boss_bar_alpha = maxf(_boss_bar_alpha - delta * 2.0, 0.0)
	_boss_bar_shake = maxf(_boss_bar_shake - delta * 4.0, 0.0)

	# Boss intro fade
	var intro_t: float = get_meta("boss_intro_t", 0.0)
	if intro_t > 0.0:
		# Fade in fast, hold, fade out at end
		if intro_t < 0.3:
			_intro_alpha = intro_t / 0.3
		elif intro_t > 0.7:
			_intro_alpha = (1.0 - intro_t) / 0.3
		else:
			_intro_alpha = 1.0
	else:
		_intro_alpha = maxf(_intro_alpha - delta * 3.0, 0.0)

	# Fade flash toward current value
	if _health_flash_alpha > 0:
		_health_flash_alpha = maxf(_health_flash_alpha - FLASH_FADE_SPEED * delta, 0.0)
		_health_flash_ratio = lerpf(_health_flash_ratio, health_ratio, delta * 4.0)
	if _energy_flash_alpha > 0:
		_energy_flash_alpha = maxf(_energy_flash_alpha - FLASH_FADE_SPEED * delta, 0.0)
		_energy_flash_ratio = lerpf(_energy_flash_ratio, energy_ratio, delta * 4.0)

	queue_redraw()

func _draw() -> void:
	var center: Vector2 = get_viewport_rect().size * 0.5

	# Health arc (left side, red)
	_draw_organic_arc(
		center, ARC_RADIUS,
		deg_to_rad(HEALTH_START_ANGLE), deg_to_rad(HEALTH_END_ANGLE),
		health_ratio,
		Color(0.8, 0.1, 0.05), Color(0.4, 0.05, 0.02),
		health_ratio < 0.25,
		_health_flash_ratio, _health_flash_alpha
	)

	# Energy arc (right side, green) — reversed angles so it drains from top
	_draw_organic_arc(
		center, ARC_RADIUS,
		deg_to_rad(ENERGY_START_ANGLE), deg_to_rad(ENERGY_END_ANGLE),
		energy_ratio,
		Color(0.1, 0.7, 0.4), Color(0.05, 0.35, 0.15),
		energy_ratio < 0.25,
		_energy_flash_ratio, _energy_flash_alpha
	)

	# Boss intro title card
	_draw_boss_intro(center)

	# Boss health bar (top center)
	_draw_boss_health_bar(center)

	# Danger proximity indicator (red arrow at screen edge toward nearest threat)
	_draw_danger_indicator(center)

func _draw_organic_arc(
	center: Vector2, radius: float,
	start_angle: float, end_angle: float,
	fill_ratio: float,
	color_bright: Color, color_dark: Color,
	pulsing: bool,
	flash_ratio: float, flash_alpha: float
) -> void:
	var segments: int = 48

	# --- Background arc (full span, dark translucent) ---
	var bg_color: Color = color_dark
	bg_color.a = ARC_BG_ALPHA
	# Outer glow layer (wide, very faint)
	_draw_wavy_arc(center, radius, start_angle, end_angle, segments,
		_with_alpha(bg_color, 0.03), 20.0, 0.0)
	# Mid membrane layer
	_draw_wavy_arc(center, radius, start_angle, end_angle, segments,
		_with_alpha(bg_color, 0.06), 14.0, 0.0)
	# Background core
	_draw_wavy_arc(center, radius, start_angle, end_angle, segments,
		bg_color, 6.0, 0.0)

	# --- Delta flash arc (ghost of previous value fading toward current) ---
	if flash_alpha > 0.02 and absf(flash_ratio - fill_ratio) > 0.005:
		var flash_min: float = minf(fill_ratio, flash_ratio)
		var flash_max: float = maxf(fill_ratio, flash_ratio)
		var flash_start: float = lerpf(start_angle, end_angle, flash_min)
		var flash_end: float = lerpf(start_angle, end_angle, flash_max)
		var is_gain: bool = fill_ratio > flash_ratio
		var flash_col: Color
		if is_gain:
			flash_col = color_bright.lightened(0.3)
		else:
			flash_col = color_bright.darkened(0.2)
		flash_col.a = flash_alpha * 0.4
		_draw_wavy_arc(center, radius, flash_start, flash_end, segments,
			flash_col, 10.0, 0.0)

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
			_with_alpha(fg_color, fg_color.a * 0.12), 20.0, 0.0)
		# Mid membrane layer
		_draw_wavy_arc(center, radius, start_angle, fill_end, segments,
			_with_alpha(fg_color, fg_color.a * 0.25), 14.0, 0.0)
		# Main fill arc (polygon with variable width for vein-like taper)
		_draw_vein_arc(center, radius, start_angle, fill_end, segments, fg_color)
		# Inner highlight (thin bright core)
		var highlight: Color = color_bright.lightened(0.3)
		highlight.a = 0.15
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
		var phase: float = float(i) / NUM_FLOW_DOTS
		var drift: float = fmod(_time * DOT_SPEED + phase, 1.0)
		var t: float = drift
		var angle: float = lerpf(start_angle, end_angle, t)

		var r: float = radius + sin(angle * WAVE_FREQUENCY + _time * 2.0) * WAVE_AMPLITUDE * 0.5
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * r

		var dot_color: Color = bright_color.lightened(0.2)
		var edge_fade: float = smoothstep(0.0, 0.1, t) * smoothstep(1.0, 0.9, t)
		dot_color.a = 0.18 * edge_fade

		var dot_r: float = DOT_RADIUS * (0.7 + 0.3 * sin(_time * 3.0 + float(i) * 1.7))

		draw_circle(pos, dot_r * 1.8, _with_alpha(dot_color, dot_color.a * 0.3))
		draw_circle(pos, dot_r, dot_color)

func _draw_soft_tip(
	center: Vector2, radius: float,
	tip_angle: float, bright_color: Color, pulsing: bool
) -> void:
	var tip_pos: Vector2 = center + Vector2(cos(tip_angle), sin(tip_angle)) * radius
	var base_alpha: float = 0.25
	if pulsing:
		base_alpha *= sin(_time * 4.0) * 0.3 + 0.7

	var tip_color: Color = bright_color.lightened(0.3)
	draw_circle(tip_pos, 6.0, _with_alpha(tip_color, base_alpha * 0.08))
	draw_circle(tip_pos, 4.0, _with_alpha(tip_color, base_alpha * 0.15))
	draw_circle(tip_pos, 2.0, _with_alpha(tip_color, base_alpha * 0.3))

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

func _draw_danger_indicator(center: Vector2) -> void:
	var threat_dist: float = get_meta("threat_dist", INF)
	var threat_range: float = get_meta("threat_range", 100.0)
	if threat_dist >= threat_range:
		return

	var threat_dir: Vector3 = get_meta("threat_dir", Vector3.ZERO)
	if threat_dir.length_squared() < 0.01:
		return

	# Convert 3D direction to 2D screen angle (XZ plane -> screen)
	var screen_angle: float = atan2(threat_dir.x, threat_dir.z)
	# Factor in camera rotation
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		screen_angle -= cam.global_rotation.y

	# Proximity intensity (closer = brighter, larger)
	var proximity: float = 1.0 - clampf(threat_dist / threat_range, 0.0, 1.0)
	var pulse: float = sin(_time * 6.0) * 0.2 + 0.8
	var alpha: float = proximity * 0.7 * pulse

	# Arrow position: at screen edge in the direction of the threat
	var viewport_size: Vector2 = get_viewport_rect().size
	var edge_dist: float = minf(viewport_size.x, viewport_size.y) * 0.42
	var arrow_pos: Vector2 = center + Vector2(sin(screen_angle), -cos(screen_angle)) * edge_dist

	# Draw pulsing red arrow
	var arrow_size: float = 12.0 + proximity * 10.0
	var arrow_color: Color = Color(1.0, 0.15, 0.05, alpha)

	# Arrow triangle pointing toward threat
	var dir_2d: Vector2 = Vector2(sin(screen_angle), -cos(screen_angle))
	var perp_2d: Vector2 = Vector2(dir_2d.y, -dir_2d.x)

	var tip: Vector2 = arrow_pos + dir_2d * arrow_size
	var left: Vector2 = arrow_pos - dir_2d * arrow_size * 0.5 + perp_2d * arrow_size * 0.6
	var right: Vector2 = arrow_pos - dir_2d * arrow_size * 0.5 - perp_2d * arrow_size * 0.6

	# Glow layer (larger, dimmer)
	var glow_color: Color = Color(1.0, 0.1, 0.0, alpha * 0.2)
	var glow_scale: float = 1.8
	var glow_tip: Vector2 = arrow_pos + dir_2d * arrow_size * glow_scale
	var glow_left: Vector2 = arrow_pos - dir_2d * arrow_size * 0.5 * glow_scale + perp_2d * arrow_size * 0.6 * glow_scale
	var glow_right: Vector2 = arrow_pos - dir_2d * arrow_size * 0.5 * glow_scale - perp_2d * arrow_size * 0.6 * glow_scale
	draw_polygon(PackedVector2Array([glow_tip, glow_left, glow_right]),
		PackedColorArray([glow_color, glow_color, glow_color]))

	# Main arrow
	draw_polygon(PackedVector2Array([tip, left, right]),
		PackedColorArray([arrow_color, arrow_color, arrow_color]))

	# Bright center highlight
	var highlight_color: Color = Color(1.0, 0.4, 0.2, alpha * 0.5)
	draw_circle(arrow_pos, 3.0 + proximity * 3.0, highlight_color)

func _draw_boss_intro(center: Vector2) -> void:
	if _intro_alpha < 0.01:
		return
	var intro_name: String = get_meta("boss_intro_name", "")
	var intro_subtitle: String = get_meta("boss_intro_subtitle", "")
	var intro_color: Color = get_meta("boss_intro_color", Color.RED)
	var intro_t: float = get_meta("boss_intro_t", 0.0)
	if intro_name.is_empty():
		return
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var a: float = _intro_alpha
	var viewport_size: Vector2 = get_viewport_rect().size

	# Cinematic letterbox bars (slide in from edges)
	var bar_ease: float = minf(intro_t / 0.15, 1.0)
	var bar_h: float = 65.0 * bar_ease
	draw_rect(Rect2(0, 0, viewport_size.x, bar_h), Color(0, 0, 0, a * 0.85))
	draw_rect(Rect2(0, viewport_size.y - bar_h, viewport_size.x, bar_h), Color(0, 0, 0, a * 0.85))
	# Accent line on inner edge of bars
	var bar_line_col: Color = intro_color
	bar_line_col.a = a * 0.4
	draw_line(Vector2(0, bar_h), Vector2(viewport_size.x, bar_h), bar_line_col, 1.0)
	draw_line(Vector2(0, viewport_size.y - bar_h), Vector2(viewport_size.x, viewport_size.y - bar_h), bar_line_col, 1.0)

	# Expanding energy ring (bursts outward at start, fades)
	if intro_t < 0.5:
		var ring_t: float = intro_t / 0.5
		var ring_ease: float = 1.0 - (1.0 - ring_t) * (1.0 - ring_t)  # ease-out quad
		var ring_radius: float = 20.0 + ring_ease * 280.0
		var ring_alpha: float = (1.0 - ring_t) * a * 0.6
		var ring_col: Color = intro_color
		ring_col.a = ring_alpha
		_draw_ring(center + Vector2(0, 5), ring_radius, ring_col, 2.5)
		# Second ring, slightly delayed
		if intro_t > 0.08:
			var ring_t2: float = (intro_t - 0.08) / 0.5
			ring_t2 = clampf(ring_t2, 0.0, 1.0)
			var ring_ease2: float = 1.0 - (1.0 - ring_t2) * (1.0 - ring_t2)
			var r2: float = 15.0 + ring_ease2 * 220.0
			ring_col.a = (1.0 - ring_t2) * a * 0.3
			_draw_ring(center + Vector2(0, 5), r2, ring_col, 1.5)

	# Ominous glow behind name (pulses gently)
	var glow_pulse: float = 1.0 + sin(_time * 3.0) * 0.15
	var glow_col: Color = intro_color
	glow_col.a = a * 0.1 * glow_pulse
	draw_circle(center + Vector2(0, 5), 140.0 * glow_pulse, glow_col)
	glow_col.a = a * 0.04
	draw_circle(center + Vector2(0, 5), 200.0, glow_col)

	# Horizontal accent lines flanking the name (slide in)
	var line_slide: float = clampf((intro_t - 0.1) / 0.2, 0.0, 1.0)
	line_slide = line_slide * line_slide * (3.0 - 2.0 * line_slide)  # smoothstep
	var line_y: float = center.y - 10
	var line_w: float = 160.0 * line_slide
	var line_col: Color = intro_color
	line_col.a = a * 0.6
	draw_line(Vector2(center.x - 200 - line_w, line_y), Vector2(center.x - 200, line_y), line_col, 2.0)
	draw_line(Vector2(center.x + 200, line_y), Vector2(center.x + 200 + line_w, line_y), line_col, 2.0)
	# Diamond endpoints
	var diamond_a: float = a * 0.7 * line_slide
	var diamond_col: Color = intro_color
	diamond_col.a = diamond_a
	draw_circle(Vector2(center.x - 200 - line_w, line_y), 3.0, diamond_col)
	draw_circle(Vector2(center.x + 200 + line_w, line_y), 3.0, diamond_col)

	# Glitch text reveal — characters appear progressively with chromatic aberration
	var name_size: int = 36
	var reveal_progress: float = clampf((intro_t - 0.12) / 0.25, 0.0, 1.0)
	var chars_to_show: int = int(reveal_progress * intro_name.length())
	var revealed: String = intro_name.substr(0, chars_to_show)

	if revealed.length() > 0:
		var name_w: float = font.get_string_size(revealed, HORIZONTAL_ALIGNMENT_CENTER, -1, name_size).x
		var name_x: float = center.x - name_w * 0.5
		var name_y: float = center.y + 4

		# Chromatic aberration offset (strongest during reveal, fades after)
		var glitch_intensity: float = 0.0
		if intro_t < 0.4:
			glitch_intensity = (1.0 - reveal_progress) * 4.0
		elif fmod(_time * 7.0, 3.0) < 0.15:  # occasional micro-glitch
			glitch_intensity = 1.5

		if glitch_intensity > 0.3:
			# Red channel offset
			var r_col: Color = Color(1.0, 0.2, 0.1, a * 0.4)
			draw_string(font, Vector2(name_x - glitch_intensity, name_y - glitch_intensity * 0.5), revealed,
				HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, r_col)
			# Blue channel offset
			var b_col: Color = Color(0.1, 0.3, 1.0, a * 0.4)
			draw_string(font, Vector2(name_x + glitch_intensity, name_y + glitch_intensity * 0.5), revealed,
				HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, b_col)

		# Main name text
		var name_col: Color = Color(1.0, 0.97, 0.92, a)
		draw_string(font, Vector2(name_x, name_y), revealed,
			HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, name_col)

		# Cursor/scanline at reveal edge
		if chars_to_show < intro_name.length() and reveal_progress > 0.0:
			var cursor_x: float = name_x + name_w + 2
			var cursor_flash: float = fmod(_time * 12.0, 1.0)
			if cursor_flash < 0.6:
				draw_rect(Rect2(cursor_x, name_y - name_size * 0.7, 2, name_size * 0.8), Color(intro_color.r, intro_color.g, intro_color.b, a * 0.8))

	# Subtitle (fades in after name is revealed)
	var sub_fade: float = clampf((intro_t - 0.4) / 0.15, 0.0, 1.0)
	if sub_fade > 0.0 and not intro_subtitle.is_empty():
		var sub_col: Color = intro_color.lightened(0.3)
		sub_col.a = a * 0.7 * sub_fade
		var sub_w: float = font.get_string_size(intro_subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
		draw_string(font, Vector2(center.x - sub_w * 0.5, center.y + 32), intro_subtitle,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, sub_col)

	# Corner warning glyphs (alien text in letterbox corners)
	var glyph_a: float = a * 0.25
	var glyph_text: String = UIConstants.random_glyphs(6, _time * 0.5)
	draw_string(mono, Vector2(16, bar_h - 8), glyph_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(intro_color.r, intro_color.g, intro_color.b, glyph_a))
	var glyph_text2: String = UIConstants.random_glyphs(6, _time * 0.5 + 100)
	var g2w: float = mono.get_string_size(glyph_text2, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY).x
	draw_string(mono, Vector2(viewport_size.x - g2w - 16, bar_h - 8), glyph_text2, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(intro_color.r, intro_color.g, intro_color.b, glyph_a))

func _draw_ring(center: Vector2, radius: float, col: Color, width: float) -> void:
	var segments: int = 48
	for i in range(segments):
		var a0: float = TAU * i / segments
		var a1: float = TAU * (i + 1) / segments
		draw_line(
			center + Vector2(cos(a0), sin(a0)) * radius,
			center + Vector2(cos(a1), sin(a1)) * radius,
			col, width
		)

func _draw_boss_health_bar(center: Vector2) -> void:
	if _boss_bar_alpha < 0.01:
		return
	var boss_hp: float = get_meta("boss_health", -1.0)
	var boss_max_hp: float = get_meta("boss_max_health", 1.0)
	var boss_name: String = get_meta("boss_name", "BOSS")
	var boss_color: Color = get_meta("boss_color", Color(0.9, 0.15, 0.1))

	var ratio: float = clampf(boss_hp / maxf(boss_max_hp, 1.0), 0.0, 1.0)
	var a: float = _boss_bar_alpha

	# Bar dimensions (top center of screen)
	var bar_w: float = 400.0
	var bar_h: float = 14.0
	var bar_x: float = center.x - bar_w * 0.5
	var bar_y: float = 90.0 + sin(_boss_bar_shake * 12.0) * _boss_bar_shake * 4.0

	# Boss name label
	var font: Font = UIConstants.get_display_font()
	var name_col: Color = Color(1.0, 0.95, 0.85, a * 0.9)
	draw_string(font, Vector2(center.x - 80, bar_y - 8), boss_name,
		HORIZONTAL_ALIGNMENT_CENTER, 160, 16, name_col)

	# Background (dark)
	var bg: Color = Color(0.1, 0.05, 0.05, a * 0.6)
	draw_rect(Rect2(bar_x - 2, bar_y, bar_w + 4, bar_h + 4), bg)

	# Border
	var border_col: Color = boss_color
	border_col.a = a * 0.4
	draw_rect(Rect2(bar_x - 2, bar_y, bar_w + 4, bar_h + 4), border_col, false, 1.5)

	# Fill (gradient from dark to bright at ratio edge)
	if ratio > 0.005:
		var fill_w: float = bar_w * ratio
		var fill_col: Color = boss_color
		fill_col.a = a * 0.8
		draw_rect(Rect2(bar_x, bar_y + 2, fill_w, bar_h), fill_col)

		# Bright edge highlight
		var edge_col: Color = boss_color.lightened(0.4)
		edge_col.a = a * 0.6
		draw_rect(Rect2(bar_x + fill_w - 3.0, bar_y + 2, 3.0, bar_h), edge_col)

		# Inner glow line
		var glow_col: Color = boss_color.lightened(0.2)
		glow_col.a = a * 0.3
		draw_rect(Rect2(bar_x, bar_y + 2, fill_w, 3.0), glow_col)

	# Low HP pulse
	if ratio < 0.25 and ratio > 0.0:
		var pulse: float = sin(_time * 6.0) * 0.3 + 0.7
		var warn_col: Color = Color(1.0, 0.2, 0.05, a * 0.15 * pulse)
		draw_rect(Rect2(bar_x - 4, bar_y - 2, bar_w + 8, bar_h + 8), warn_col)

	# HP text (right side)
	var hp_text: String = "%d / %d" % [int(boss_hp), int(boss_max_hp)]
	var hp_col: Color = Color(0.9, 0.85, 0.75, a * 0.7)
	draw_string(font, Vector2(bar_x + bar_w + 10, bar_y + bar_h), hp_text,
		HORIZONTAL_ALIGNMENT_LEFT, 120, 12, hp_col)

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

extends Control
## Renders a scaled creature preview for the editor.
## Shows body, face (eyes only, no mouth), mutations at snap positions with customization applied.
## Supports new color targets, eye placement, mutation scaling, and direction indicator.

var _time: float = 0.0
var _cell_radius: float = 18.0
var _handles: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var _evo_scale: float = 1.0
var _membrane_points: Array[Vector2] = []
var _organelle_positions: Array[Vector2] = []
var _cilia_angles: Array[float] = []
var preview_center: Vector2 = Vector2.ZERO
var preview_scale: float = 3.5
var preview_rotation: float = 0.0
var show_morph_handles: bool = false
var dragging_morph_handle: int = -1  # -1 = not dragging

const NUM_MEMBRANE_PTS: int = 32
const NUM_CILIA: int = 12
const NUM_ORGANELLES: int = 5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_handles = GameManager.get_body_handles()
	_evo_scale = 1.0 + GameManager.evolution_level * 0.08
	_cell_radius = 18.0
	for m in GameManager.active_mutations:
		if m.get("id", "") == "larger_membrane":
			_cell_radius += 3.0
	_init_shape()

func set_body_shape(_elongation_offset: float, _bulge: float) -> void:
	# Legacy compat — ignored, handles are now used directly
	_handles = GameManager.get_body_handles()
	_init_shape()

func refresh_handles() -> void:
	_handles = GameManager.get_body_handles()
	_init_shape()

func _get_handle_radius_at_angle(angle: float) -> float:
	return SnapPointSystem.get_radius_at_angle(angle, _cell_radius, _get_effective_handles())

func _get_effective_handles() -> Array:
	var eff: Array = []
	for h in _handles:
		eff.append(h * _evo_scale)
	return eff

func _init_shape() -> void:
	_membrane_points.clear()
	var eff_handles: Array = _get_effective_handles()
	for i in range(NUM_MEMBRANE_PTS):
		var angle: float = TAU * i / NUM_MEMBRANE_PTS
		var r: float = SnapPointSystem.get_radius_at_angle(angle, _cell_radius, eff_handles) + randf_range(-1.5, 1.5)
		_membrane_points.append(Vector2(cos(angle) * r, sin(angle) * r))

	# Tightened organelles — stay in center 40% to avoid eye area
	_organelle_positions.clear()
	for i in range(NUM_ORGANELLES):
		var a: float = randf() * TAU
		var max_r: float = _cell_radius * 0.35
		var dx: float = randf_range(2.0, max_r)
		var dy: float = randf_range(2.0, max_r)
		_organelle_positions.append(Vector2(cos(a) * dx, sin(a) * dy))

	_cilia_angles.clear()
	for i in range(NUM_CILIA):
		_cilia_angles.append(TAU * i / NUM_CILIA + randf_range(-0.08, 0.08))

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if preview_center == Vector2.ZERO:
		return
	var s: float = preview_scale
	var custom: Dictionary = GameManager.creature_customization

	# Apply rotation around preview center
	var rotated: bool = absf(preview_rotation) > 0.001
	var dc: Vector2 = preview_center  # draw center
	if rotated:
		draw_set_transform(preview_center, preview_rotation, Vector2.ONE)
		dc = Vector2.ZERO  # When transform is set, origin is at preview_center

	var membrane_col: Color = custom.get("membrane_color", Color(0.3, 0.6, 1.0))
	var glow_col: Color = custom.get("glow_color", Color(0.3, 0.7, 1.0))
	var interior_col: Color = custom.get("interior_color", Color(0.15, 0.25, 0.5))
	var cilia_col: Color = custom.get("cilia_color", Color(0.4, 0.7, 1.0))
	var org_tint: Color = custom.get("organelle_tint", Color(0.3, 0.8, 0.5))

	# Direction indicator (FRONT arrow)
	_draw_direction_indicator(s, dc)

	# Outer glow
	var glow_a: float = 0.06 + 0.04 * sin(_time * 2.0)
	var avg_r: float = _cell_radius * _evo_scale * 2.2
	_draw_ellipse_at(dc, avg_r * s, avg_r * s, Color(glow_col.r, glow_col.g, glow_col.b, glow_a))

	# Cilia — use cilia_color
	var eff_handles: Array = _get_effective_handles()
	for i in range(NUM_CILIA):
		var base_angle: float = _cilia_angles[i]
		var wave: float = sin(_time * 6.0 + i * 1.3) * 0.15
		var angle: float = base_angle + wave
		var cilia_r: float = SnapPointSystem.get_radius_at_angle(base_angle, _cell_radius, eff_handles)
		var base_pt: Vector2 = dc + Vector2(cos(base_angle) * cilia_r, sin(base_angle) * cilia_r) * s
		var tip_len: float = (8.0 + 3.0 * sin(_time * 5.0 + i)) * s
		var tip_pt: Vector2 = base_pt + Vector2(cos(angle) * tip_len, sin(angle) * tip_len)
		draw_line(base_pt, tip_pt, Color(cilia_col.r * 1.1, cilia_col.g * 1.1, cilia_col.b * 1.1, 0.5), 1.2 * s * 0.4, true)

	# Membrane body — use interior_color for fill
	var fill_col := Color(interior_col.r, interior_col.g, interior_col.b, 0.7)
	var pts := PackedVector2Array()
	for i in range(NUM_MEMBRANE_PTS):
		var wobble: float = sin(_time * 2.5 + i * 0.7) * 1.2 * s
		var base: Vector2 = _membrane_points[i] * s
		pts.append(dc + base + base.normalized() * wobble)
	draw_colored_polygon(pts, fill_col)
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(membrane_col.r, membrane_col.g, membrane_col.b, 0.85), 1.5, true)

	# Internal organelles — tinted by organelle_tint
	var base_org_colors: Array[Color] = [
		Color(0.2, 0.9, 0.3, 0.6), Color(0.9, 0.6, 0.1, 0.6),
		Color(0.7, 0.2, 0.8, 0.5), Color(0.1, 0.8, 0.8, 0.5), Color(0.9, 0.9, 0.2, 0.4),
	]
	for i in range(_organelle_positions.size()):
		var wobble_v: Vector2 = Vector2(sin(_time * 2.0 + i), cos(_time * 1.8 + i * 0.7)) * 1.2 * s
		var base_c: Color = base_org_colors[i % base_org_colors.size()]
		var tinted: Color = base_c.lerp(org_tint, 0.4)
		tinted.a = base_c.a
		draw_circle(dc + _organelle_positions[i] * s + wobble_v, 2.5 * s, tinted)

	# Mutations at angular positions
	_draw_mutations_at_angles(dc)

	# Symmetry line
	_draw_symmetry_line(dc, s)

	# Face (eyes only — no mouth)
	_draw_face(dc)

	# Morph handles (in editor CUSTOMIZE mode)
	draw_morph_handles_overlay(dc)

	# Blueprint annotations (drawn on top of creature)
	_draw_annotations(dc, s)

	# Reset transform
	if rotated:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_direction_indicator(s: float, dc: Vector2) -> void:
	# Arrow pointing in the forward (+X) direction
	var front_r: float = _get_handle_radius_at_angle(0.0)
	var back_r: float = _get_handle_radius_at_angle(PI)
	var arrow_start: Vector2 = dc + Vector2(front_r * 1.4 * s, 0)
	var arrow_end: Vector2 = dc + Vector2(front_r * 1.8 * s, 0)
	var arrow_col: Color = Color(0.4, 0.8, 1.0, 0.4 + 0.15 * sin(_time * 2.0))

	# Arrow shaft
	draw_line(arrow_start, arrow_end, arrow_col, 2.0, true)
	# Arrow head
	var head_size: float = 5.0 * s * 0.3
	var tip: Vector2 = arrow_end
	draw_line(tip, tip + Vector2(-head_size, -head_size * 0.6), arrow_col, 2.0, true)
	draw_line(tip, tip + Vector2(-head_size, head_size * 0.6), arrow_col, 2.0, true)

	# FRONT label
	var font := UIConstants.get_display_font()
	var label_pos: Vector2 = arrow_end + Vector2(4, 4)
	draw_string(font, label_pos, "FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.8, 1.0, 0.5))

	# BACK label on opposite side
	var back_pos: Vector2 = dc + Vector2(-back_r * 1.6 * s, 4)
	draw_string(font, back_pos, "BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.4, 0.6, 0.7, 0.3))

func _draw_mutations_at_angles(dc: Vector2) -> void:
	var s: float = preview_scale
	var eff_handles: Array = _get_effective_handles()
	for m in GameManager.active_mutations:
		var mid: String = m.get("id", "")
		var vis: String = m.get("visual", "")
		if vis == "" or vis == "larger_membrane":
			continue
		var placement: Dictionary = GameManager.mutation_placements.get(mid, {})
		var angle: float = placement.get("angle", SnapPointSystem.get_default_angle_for_visual(vis))
		var distance: float = placement.get("distance", SnapPointSystem.get_default_distance_for_visual(vis))
		var mirrored: bool = placement.get("mirrored", false)
		var mut_scale: float = placement.get("scale", 1.0)
		var rot_offset: float = placement.get("rotation_offset", 0.0)
		var pos: Vector2 = SnapPointSystem.angle_to_perimeter_position_morphed(angle, _cell_radius, eff_handles, distance) * s
		var outward_rot: float = SnapPointSystem.get_outward_rotation(angle) + rot_offset
		# Draw with oriented transform
		draw_set_transform(dc + pos, outward_rot, Vector2(s * 0.8 * mut_scale, s * 0.8 * mut_scale))
		_draw_mutation_icon(vis, Vector2.ZERO, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Draw mirrored copy
		if mirrored:
			var mirror_angle: float = SnapPointSystem.get_mirror_angle(angle)
			var mpos: Vector2 = SnapPointSystem.angle_to_perimeter_position_morphed(mirror_angle, _cell_radius, eff_handles, distance) * s
			var mirror_rot: float = SnapPointSystem.get_outward_rotation(mirror_angle) - rot_offset
			draw_set_transform(dc + mpos, mirror_rot, Vector2(s * 0.8 * mut_scale, s * 0.8 * mut_scale))
			_draw_mutation_icon(vis, Vector2.ZERO, 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_symmetry_line(dc: Vector2, s: float) -> void:
	# Pulsing dashed horizontal line through center (front-to-back axis)
	var front_r: float = _get_handle_radius_at_angle(0.0)
	var back_r: float = _get_handle_radius_at_angle(PI)
	var line_len: float = (front_r + back_r) * s
	var dash_len: float = 8.0
	var gap_len: float = 6.0
	var alpha: float = 0.2 + 0.1 * sin(_time * 2.5)
	var col: Color = Color(1.0, 0.85, 0.3, alpha)
	var x_start: float = dc.x - line_len * 0.8
	var x_end: float = dc.x + line_len * 0.8
	var x: float = x_start
	while x < x_end:
		var seg_end: float = minf(x + dash_len, x_end)
		draw_line(Vector2(x, dc.y), Vector2(seg_end, dc.y), col, 1.0, true)
		x = seg_end + gap_len

func _draw_mutation_icon(visual: String, center: Vector2, icon_scale: float) -> void:
	var r: float = 8.0 * icon_scale
	var c := Color(0.5, 0.85, 1.0, 0.8)
	match visual:
		"extra_cilia":
			for i in range(6):
				var a: float = TAU * i / 6.0 + sin(_time * 3.0) * 0.15
				var p1: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.5
				var p2: Vector2 = center + Vector2(cos(a), sin(a)) * r * 1.2
				draw_line(p1, p2, c, 1.2, true)
		"spikes":
			for i in range(6):
				var a: float = TAU * i / 6.0
				draw_line(center + Vector2(cos(a), sin(a)) * r * 0.5, center + Vector2(cos(a), sin(a)) * r * 1.2, Color(0.9, 0.3, 0.2, 0.8), 1.5, true)
		"armor_plates":
			for i in range(4):
				var a: float = TAU * i / 4.0 + 0.3
				var p: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.6
				draw_rect(Rect2(p.x - 3 * icon_scale, p.y - 2 * icon_scale, 6 * icon_scale, 4 * icon_scale), Color(0.4, 0.5, 0.6, 0.6))
		"flagellum":
			var prev: Vector2 = center
			for i in range(8):
				var t: float = float(i + 1) / 8.0
				var next: Vector2 = center + Vector2(-t * r * 2.0, sin(_time * 6.0 + t * 4.0) * r * 0.5 * t)
				draw_line(prev, next, Color(0.5, 0.8, 0.4, 0.7), maxf(1.5 - t, 0.5), true)
				prev = next
		"third_eye", "photoreceptor":
			draw_circle(center, r * 0.5, Color(1, 1, 1, 0.85))
			draw_circle(center, r * 0.25, Color(0.6, 0.1, 0.8, 0.9))
		"eye_stalks":
			for side: float in [-1.0, 1.0]:
				var tip: Vector2 = center + Vector2(side * r * 0.8, -r * 0.6 + sin(_time * 2.0 + side) * 2.0)
				draw_line(center, tip, c, 1.5, true)
				draw_circle(tip, r * 0.3, Color(1, 1, 1, 0.85))
				draw_circle(tip, r * 0.15, Color(0.1, 0.1, 0.3, 0.9))
		"compound_eye":
			for row in range(2):
				for col in range(2):
					var ep: Vector2 = center + Vector2((col - 0.5) * r * 0.5, (row - 0.5) * r * 0.5)
					draw_circle(ep, r * 0.25, Color(0.9, 0.9, 1.0, 0.7))
					draw_circle(ep, r * 0.12, Color(0.1, 0.1, 0.3, 0.8))
		"tentacles":
			for i in range(3):
				var prev2: Vector2 = center
				for seg in range(6):
					var t: float = float(seg + 1) / 6.0
					var next2: Vector2 = center + Vector2((i - 1) * r * 0.3 + sin(_time * 3.0 + i + t * 2.0) * r * 0.3, t * r * 1.5)
					draw_line(prev2, next2, c, maxf(1.5 - t * 0.8, 0.5), true)
					prev2 = next2
		"toxin_glands":
			for i in range(3):
				var a: float = TAU * i / 3.0 + _time * 0.5
				var gp: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.5
				draw_circle(gp, r * 0.25 * (0.7 + 0.3 * sin(_time * 4.0 + i)), Color(0.6, 0.9, 0.1, 0.6))
		"bioluminescence":
			var pulse: float = 0.3 + 0.2 * sin(_time * 3.0)
			draw_circle(center, r * 1.2, Color(0.2, 0.8, 1.0, pulse * 0.15))
			draw_circle(center, r * 0.4, Color(1, 1, 0.8, pulse * 0.4))
		"color_shift":
			var hue: float = fmod(_time * 0.3, 1.0)
			draw_circle(center, r * 0.7, Color.from_hsv(hue, 0.6, 0.9, 0.3))
		"regeneration":
			draw_line(center + Vector2(-r * 0.3, 0), center + Vector2(r * 0.3, 0), Color(0.3, 1.0, 0.4, 0.7), 2.0)
			draw_line(center + Vector2(0, -r * 0.3), center + Vector2(0, r * 0.3), Color(0.3, 1.0, 0.4, 0.7), 2.0)
		"electric_organ":
			for i in range(3):
				var a: float = TAU * i / 3.0 + _time * 3.0
				var p1: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.4
				var jit: Vector2 = Vector2(sin(_time * 15.0 + i * 5) * 3, cos(_time * 12.0 + i * 3) * 3)
				draw_line(p1, p1 + Vector2(cos(a), sin(a)) * r * 0.5 + jit, Color(0.5, 0.8, 1.0, 0.6), 1.2, true)
		"front_spike":
			var spike_pts := PackedVector2Array([center + Vector2(-r * 0.2, -r * 0.3), center + Vector2(r, 0), center + Vector2(-r * 0.2, r * 0.3)])
			draw_colored_polygon(spike_pts, Color(0.85, 0.7, 0.4, 0.8))
		"mandibles":
			for side: float in [-1.0, 1.0]:
				var open: float = 0.2 + sin(_time * 3.0) * 0.15
				draw_line(center + Vector2(r * 0.2, side * r * 0.15), center + Vector2(r * 0.7, side * (r * 0.3 + open * r * 0.3)), c, 1.5, true)
		"rear_stinger":
			var prev3: Vector2 = center
			for i in range(4):
				var t: float = float(i + 1) / 4.0
				var cur: Vector2 = center + Vector2(-t * r, sin(_time * 3.0 + t * 2) * r * 0.3 * t)
				draw_line(prev3, cur, Color(0.3, 0.8, 0.2, 0.8), 2.0 - t * 0.5, true)
				prev3 = cur
			draw_circle(prev3, r * 0.15, Color(0.2, 0.9, 0.3, 0.7))
		"tail_club":
			draw_line(center, center + Vector2(-r * 0.6, sin(_time * 2) * r * 0.15), c, 2.0, true)
			draw_circle(center + Vector2(-r * 0.8, sin(_time * 2) * r * 0.15), r * 0.3, Color(0.55, 0.45, 0.35, 0.8))
		"side_barbs":
			for side_val: float in [-1.0, 1.0]:
				for i in range(2):
					var x: float = -r * 0.3 + i * r * 0.3
					draw_line(center + Vector2(x, side_val * r * 0.4), center + Vector2(x, side_val * r * 0.8), Color(0.9, 0.4, 0.3, 0.7), 1.2, true)
		"dorsal_fin":
			var fin: PackedVector2Array = PackedVector2Array([center + Vector2(r * 0.2, -r * 0.3), center + Vector2(-r * 0.1, -r * 0.9), center + Vector2(-r * 0.4, -r * 0.3)])
			draw_colored_polygon(fin, Color(c.r, c.g, c.b, 0.5))
		"ramming_crest":
			var crest: PackedVector2Array = PackedVector2Array([center + Vector2(r * 0.2, -r * 0.3), center + Vector2(r * 0.6, -r * 0.15), center + Vector2(r * 0.7, 0), center + Vector2(r * 0.6, r * 0.15), center + Vector2(r * 0.2, r * 0.3)])
			draw_polyline(crest, Color(0.5, 0.55, 0.6, 0.8), 2.5, true)
		"proboscis":
			var pv: Vector2 = center
			for i in range(4):
				var t: float = float(i + 1) / 4.0
				var nc: Vector2 = center + Vector2(t * r, sin(_time * 4 + t * 2) * r * 0.1)
				draw_line(pv, nc, Color(0.8, 0.5, 0.6, 0.7), 1.5 - t * 0.3, true)
				pv = nc
		"beak":
			var bk: PackedVector2Array = PackedVector2Array([center + Vector2(r * 0.2, -r * 0.2), center + Vector2(r * 0.8, 0), center + Vector2(r * 0.2, r * 0.2)])
			draw_colored_polygon(bk, Color(0.7, 0.5, 0.2, 0.75))
		"antenna":
			for side: float in [-1.0, 1.0]:
				var tip: Vector2 = center + Vector2(r * 0.8, side * r * 0.1 + sin(_time * 4 + side) * r * 0.15)
				draw_line(center, tip, Color(0.6, 0.7, 0.5, 0.6), 1.0, true)
				draw_circle(tip, r * 0.1, Color(0.5, 0.9, 0.6, 0.5))
		_:
			draw_circle(center, r * 0.5, Color(c.r, c.g, c.b, 0.4))
			draw_arc(center, r * 0.5, 0, TAU, 12, c, 1.0, true)

func _draw_face(dc: Vector2) -> void:
	var s: float = preview_scale
	var custom: Dictionary = GameManager.creature_customization
	var iris_color: Color = custom.get("iris_color", Color(0.2, 0.5, 0.9))
	var eyes: Array = GameManager.get_eyes()

	for eye_data in eyes:
		var ex: float = eye_data.get("x", 0.0)
		var ey: float = eye_data.get("y", 0.0)
		var eye_size_val: float = eye_data.get("size", 3.5)
		var eye_style: String = eye_data.get("style", "anime")
		var ep: Vector2 = dc + Vector2(ex, ey) * _cell_radius * s
		var eye_r: float = eye_size_val * s * 0.3
		var iris_r: float = eye_r * 0.65
		var pupil_r: float = eye_r * 0.32
		_draw_single_eye(eye_style, ep, eye_r, iris_r, pupil_r, iris_color)

func _draw_single_eye(eye_style: String, ep: Vector2, eye_r: float, iris_r: float, pupil_r: float, iris_color: Color) -> void:
	var s: float = preview_scale
	match eye_style:
		"anime":
			draw_circle(ep, eye_r, Color(1, 1, 1, 0.95))
			draw_circle(ep, iris_r, iris_color)
			draw_circle(ep, pupil_r, Color(0.02, 0.02, 0.08, 1.0))
			draw_circle(ep + Vector2(-1, -1) * s * 0.3, 1.0 * s * 0.3, Color(1, 1, 1, 0.7))
			draw_circle(ep + Vector2(0.8, 0.5) * s * 0.3, 0.5 * s * 0.3, Color(1, 1, 1, 0.4))
		"round":
			draw_circle(ep, eye_r * 0.8, Color(1, 1, 1, 0.95))
			draw_circle(ep, pupil_r * 1.2, Color(0.02, 0.02, 0.08, 1.0))
		"compound":
			for row in range(2):
				for col in range(2):
					var sub: Vector2 = ep + Vector2((col - 0.5) * eye_r * 0.5, (row - 0.5) * eye_r * 0.5)
					draw_circle(sub, eye_r * 0.3, Color(iris_color.r, iris_color.g, iris_color.b, 0.7))
					draw_circle(sub, pupil_r * 0.5, Color(0.02, 0.02, 0.08, 0.9))
		"googly":
			draw_circle(ep, eye_r * 1.1, Color(1, 1, 1, 0.95))
			var wobble: Vector2 = Vector2(sin(_time * 5.0 + ep.y), cos(_time * 4.0 + ep.x)) * eye_r * 0.3
			draw_circle(ep + wobble, pupil_r * 1.5, Color(0.02, 0.02, 0.08, 1.0))
		"slit":
			draw_circle(ep, eye_r * 0.9, Color(iris_color.r, iris_color.g, iris_color.b, 0.8))
			draw_line(ep + Vector2(0, -pupil_r * 1.5), ep + Vector2(0, pupil_r * 1.5), Color(0.02, 0.02, 0.08, 1.0), pupil_r * 0.6, true)
		"lashed":
			draw_circle(ep, eye_r, Color(1, 1, 1, 0.95))
			draw_circle(ep, iris_r, Color(iris_color.r * 0.9, iris_color.g * 0.7, iris_color.b, 0.95))
			draw_circle(ep, pupil_r, Color(0.02, 0.02, 0.08, 1.0))
			draw_circle(ep + Vector2(-1, -1) * s * 0.3, 1.0 * s * 0.3, Color(1, 1, 1, 0.7))
			for i in range(3):
				var la: float = -PI * 0.6 + i * PI * 0.3
				var lash_base: Vector2 = ep + Vector2(cos(la), sin(la)) * eye_r
				var lash_tip: Vector2 = ep + Vector2(cos(la), sin(la)) * (eye_r + 3.0 * s * 0.3)
				draw_line(lash_base, lash_tip, Color(0.1, 0.1, 0.15, 0.9), 1.2, true)
			draw_arc(ep, eye_r, PI * 0.15, PI * 0.85, 6, Color(0.1, 0.1, 0.15, 0.5), 0.8, true)
		"fierce":
			var hw: float = eye_r * 1.1
			var hh: float = eye_r * 0.6
			var eye_pts: PackedVector2Array = PackedVector2Array([
				ep + Vector2(-hw, 0),
				ep + Vector2(-hw * 0.5, -hh),
				ep + Vector2(hw * 0.7, -hh * 0.6),
				ep + Vector2(hw, 0),
				ep + Vector2(hw * 0.5, hh * 0.7),
				ep + Vector2(-hw * 0.4, hh * 0.5),
			])
			draw_colored_polygon(eye_pts, Color(1, 1, 1, 0.9))
			draw_circle(ep + Vector2(hw * 0.1, 0), iris_r * 0.8, Color(iris_color.r, iris_color.g * 0.7, iris_color.b * 0.5, 0.95))
			draw_circle(ep + Vector2(hw * 0.1, 0), pupil_r, Color(0.02, 0.02, 0.08, 1.0))
			draw_line(ep + Vector2(-hw, -hh * 0.9), ep + Vector2(hw * 0.8, -hh * 1.1), Color(0.12, 0.12, 0.18, 0.85), 2.0, true)
		"dot":
			draw_circle(ep, eye_r * 0.5, Color(0.02, 0.02, 0.1, 0.95))
			draw_circle(ep + Vector2(-0.5, -0.5) * s * 0.2, 0.8 * s * 0.3, Color(1, 1, 1, 0.4))
		"star":
			draw_circle(ep, eye_r, Color(1, 1, 1, 0.9))
			var star_pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var a: float = -PI * 0.5 + TAU * i / 10.0
				var r_v: float = iris_r if i % 2 == 0 else iris_r * 0.4
				star_pts.append(ep + Vector2(cos(a) * r_v, sin(a) * r_v))
			draw_colored_polygon(star_pts, Color(iris_color.r, iris_color.g * 0.8, iris_color.b * 0.3, 0.9))
			draw_circle(ep, pupil_r * 0.8, Color(0.02, 0.02, 0.08, 0.95))
			draw_circle(ep + Vector2(-1, -1) * s * 0.2, 0.7 * s * 0.2, Color(1, 1, 1, 0.6))
		"hypnotize":
			draw_circle(ep, eye_r, Color(1, 1, 1, 0.9))
			var num_rings: int = 5
			for ring_i in range(num_rings, 0, -1):
				var ring_t: float = float(ring_i) / float(num_rings)
				var ring_r: float = iris_r * ring_t
				var phase: float = _time * 2.0 + ring_i * 0.5
				var pulse: float = 0.8 + 0.2 * sin(phase)
				var ring_col: Color
				if ring_i % 2 == 0:
					ring_col = Color(iris_color.r * pulse, iris_color.g * pulse, iris_color.b * pulse, 0.9)
				else:
					ring_col = Color(0.05, 0.02, 0.1, 0.85)
				draw_circle(ep, ring_r, ring_col)
			draw_circle(ep, pupil_r * 0.3, Color(1, 1, 1, 0.8))
		"x_eyes":
			draw_circle(ep, eye_r, Color(1, 1, 1, 0.85))
			var line_len: float = eye_r * 0.65
			draw_line(ep + Vector2(-line_len, -line_len), ep + Vector2(line_len, line_len), Color(0.1, 0.1, 0.15, 0.95), eye_r * 0.2, true)
			draw_line(ep + Vector2(line_len, -line_len), ep + Vector2(-line_len, line_len), Color(0.1, 0.1, 0.15, 0.95), eye_r * 0.2, true)
		"heart":
			draw_circle(ep, eye_r, Color(1, 1, 1, 0.9))
			var heart_pts: PackedVector2Array = PackedVector2Array()
			var heart_scale: float = iris_r * 0.18
			for i in range(24):
				var t: float = float(i) / 24.0 * TAU
				var hx: float = heart_scale * (sin(t) * sin(t) * sin(t)) * 16.0
				var hy: float = -heart_scale * (13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				heart_pts.append(ep + Vector2(hx, hy * 0.5 - iris_r * 0.1))
			var heart_col: Color = Color(minf(iris_color.r + 0.3, 1.0), iris_color.g * 0.4, minf(iris_color.b * 0.5 + 0.2, 1.0), 0.9)
			draw_colored_polygon(heart_pts, heart_col)
			draw_circle(ep + Vector2(-1.5, -1.5) * s * 0.25, 1.0 * s * 0.25, Color(1, 1, 1, 0.65))
		"spiral":
			draw_circle(ep, eye_r, Color(iris_color.r * 0.3, iris_color.g * 0.3, iris_color.b * 0.5, 0.8))
			var prev_sp: Vector2 = ep
			var spiral_segs: int = 28
			for i in range(spiral_segs):
				var t: float = float(i + 1) / float(spiral_segs)
				var spiral_a: float = t * TAU * 2.5 + _time * 3.0
				var spiral_r: float = t * iris_r * 0.85
				var sp: Vector2 = ep + Vector2(cos(spiral_a) * spiral_r, sin(spiral_a) * spiral_r)
				draw_line(prev_sp, sp, Color(iris_color.r, iris_color.g, iris_color.b, 0.9), maxf(2.0 * s * 0.15 * (1.0 - t * 0.5), 0.8), true)
				prev_sp = sp
			draw_circle(ep, pupil_r * 0.25, Color(1, 1, 1, 0.7))
		"alien":
			var alien_pts: PackedVector2Array = PackedVector2Array()
			for i in range(20):
				var t: float = float(i) / 20.0 * TAU
				var ax: float = cos(t) * eye_r * 0.55
				var ay: float = sin(t) * eye_r * 1.2
				alien_pts.append(ep + Vector2(ax, ay))
			draw_colored_polygon(alien_pts, Color(0.03, 0.08, 0.06, 0.95))
			var sheen_a: float = 0.15 + 0.1 * sin(_time * 1.5 + ep.x * 0.1)
			draw_arc(ep, eye_r * 0.7, -PI * 0.3, PI * 0.3, 8, Color(0.1, 0.8, 0.6, sheen_a), eye_r * 0.15, true)
			draw_circle(ep + Vector2(0, -eye_r * 0.15), pupil_r * 0.3, Color(0.2, 0.9, 0.7, 0.4))

func _draw_annotations(dc: Vector2, s: float) -> void:
	var font := UIConstants.get_display_font()
	var ann_col: Color = Color(0.3, 0.6, 0.8, 0.35 + 0.1 * sin(_time * 1.5))
	var label_col: Color = Color(0.4, 0.7, 0.9, 0.5)

	# MEMBRANE callout — from top of cell outward
	var top_r: float = _get_handle_radius_at_angle(-PI * 0.5)
	var membrane_pt: Vector2 = dc + Vector2(0, -top_r * s * 1.1)
	var membrane_end: Vector2 = dc + Vector2(-_cell_radius * s * 0.8, -top_r * s * 1.8)
	draw_line(membrane_pt, membrane_end, ann_col, 1.0, true)
	draw_circle(membrane_pt, 2.0, ann_col)
	draw_string(font, membrane_end + Vector2(-30, -4), "MEMBRANE", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, label_col)

	# CORE callout — from center
	var front_r: float = _get_handle_radius_at_angle(0.0)
	var core_end: Vector2 = dc + Vector2(front_r * s * 0.7, _cell_radius * s * 1.5)
	draw_line(dc, core_end, ann_col, 1.0, true)
	draw_circle(dc, 2.0, ann_col)
	draw_string(font, core_end + Vector2(4, -2), "CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, label_col)

	# Mutation callouts — one per active mutation
	var mut_idx: int = 0
	for m in GameManager.active_mutations:
		var mid: String = m.get("id", "")
		var vis: String = m.get("visual", "")
		var mname: String = m.get("name", mid)
		if vis == "" or vis == "larger_membrane":
			continue
		var placement: Dictionary = GameManager.mutation_placements.get(mid, {})
		var angle: float = placement.get("angle", SnapPointSystem.get_default_angle_for_visual(vis))
		var distance: float = placement.get("distance", SnapPointSystem.get_default_distance_for_visual(vis))
		var eff_h: Array = _get_effective_handles()
		var pos: Vector2 = SnapPointSystem.angle_to_perimeter_position_morphed(angle, _cell_radius, eff_h, distance) * s
		# Stagger annotation endpoints
		var offset_angle: float = PI * 0.3 + mut_idx * PI * 0.4
		var end_pt: Vector2 = dc + pos + Vector2(cos(offset_angle), sin(offset_angle)) * 45.0
		draw_line(dc + pos, end_pt, ann_col, 0.8, true)
		draw_circle(dc + pos, 1.5, ann_col)
		draw_string(font, end_pt + Vector2(3, 3), mname, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, label_col)
		mut_idx += 1
		if mut_idx >= 3:
			break  # Max 3 mutation annotations to avoid clutter

func draw_morph_handles_overlay(dc: Vector2) -> void:
	## Draw 8 diamond-shaped morph handles on the membrane (called by evolution_ui in CUSTOMIZE mode)
	if not show_morph_handles:
		return
	var s: float = preview_scale
	var eff_handles: Array = _get_effective_handles()
	for i in range(8):
		var angle: float = TAU * i / 8.0
		var r: float = SnapPointSystem.get_radius_at_angle(angle, _cell_radius, eff_handles)
		var pos: Vector2 = dc + Vector2(cos(angle), sin(angle)) * r * s
		var handle_size: float = 5.0
		var col: Color = Color(0.3, 0.9, 1.0, 0.6)
		if dragging_morph_handle == i:
			col = Color(0.5, 1.0, 1.0, 0.9)
			handle_size = 7.0
		var pts: PackedVector2Array = PackedVector2Array([
			pos + Vector2(0, -handle_size),
			pos + Vector2(handle_size, 0),
			pos + Vector2(0, handle_size),
			pos + Vector2(-handle_size, 0),
		])
		draw_polygon(pts, [col])
		draw_polyline(pts, Color(col.r, col.g, col.b, col.a * 0.6), 1.0, true)

func _draw_ellipse_at(center: Vector2, rx: float, ry: float, color: Color, segments: int = 24) -> void:
	if absf(rx - ry) < 0.5:
		draw_circle(center, rx, color)
		return
	var pts := PackedVector2Array()
	for i in range(segments):
		var a: float = TAU * i / segments
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)

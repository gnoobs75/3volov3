extends Control
## Organism Hologram Viewer — Rotating 3D-style creature display with scans.
## Shows building block progress and blueprint overlay on evolution.

const CARD_WIDTH: float = 280.0
const VIEWER_HEIGHT: float = 320.0  # Top hologram area
const PROGRESS_HEIGHT: float = 200.0  # Building block progress

# Alien glyphs for labels
const ALIEN_GLYPHS: Array = [
	"◊", "∆", "Ω", "Σ", "Φ", "Ψ", "λ", "π", "θ", "ξ",
	"╬", "╫", "╪", "┼", "╋", "╂", "╁", "╀", "┿", "┾",
	"⊕", "⊗", "⊙", "⊚", "⊛", "⊜", "⊝", "⊞", "⊟", "⊠",
]

var _time: float = 0.0
var _rotation_angle: float = 0.0
var _scan_y: float = 0.0
var _glitch_timer: float = 0.0

# Blueprint overlay state
var _blueprint_active: bool = false
var _blueprint_timer: float = 0.0
var _blueprint_mutation: Dictionary = {}
var _blueprint_callouts: Array = []  # [{pos, label, alpha, revealed}]

# Live scanning state - features reveal as scan line passes
var _scan_revealed_features: Array = []  # Feature IDs that have been revealed
var _live_scan_mode: bool = true  # Scan reveals features as it passes

# Creature shape data (regenerated on mutation)
var _creature_points: Array = []  # Base membrane points
var _creature_features: Array = []  # {type, pos, size, label, id, scan_y}
var _creature_radius: float = 60.0

func _ready() -> void:
	GameManager.evolution_applied.connect(_on_evolution_applied)
	GameManager.inventory_changed.connect(_on_inventory_changed)
	_regenerate_creature_shape()

func _on_evolution_applied(mutation: Dictionary) -> void:
	_blueprint_active = true
	_blueprint_timer = 0.0
	_blueprint_mutation = mutation
	_glitch_timer = 0.3
	_regenerate_creature_shape()
	_generate_blueprint_callouts()
	# Reset scan reveal for new mutation
	_scan_revealed_features.clear()
	_scan_y = 0.0

func _on_inventory_changed() -> void:
	# When inventory changes, trigger a quick glitch effect
	_glitch_timer = 0.1

func _regenerate_creature_shape() -> void:
	# Generate membrane points
	_creature_points.clear()
	var num_points: int = 24
	for i in range(num_points):
		var angle: float = TAU * float(i) / float(num_points)
		var r: float = _creature_radius + randf_range(-8, 8)
		# Add bumps for mutations
		for m in GameManager.active_mutations:
			if m.get("visual", "") in ["spikes", "armor_plates", "larger_membrane"]:
				r += randf_range(0, 12)
		_creature_points.append(Vector2(cos(angle) * r, sin(angle) * r))

	# Generate features based on mutations
	_creature_features.clear()
	_scan_revealed_features.clear()  # Reset revealed features
	var feature_id: int = 0

	# Always have nucleus - center
	var nucleus_pos := Vector2(0, 0)
	_creature_features.append({
		"type": "nucleus",
		"pos": nucleus_pos,
		"size": 18.0,
		"label": _make_alien_label(),
		"id": feature_id,
		"scan_y": VIEWER_HEIGHT * 0.5 + nucleus_pos.y,  # Y position for scan reveal
	})
	feature_id += 1

	# Add organelles
	for i in range(3):
		var angle: float = TAU * float(i) / 3.0 + 0.5
		var dist: float = _creature_radius * 0.5
		var org_pos := Vector2(cos(angle) * dist, sin(angle) * dist)
		_creature_features.append({
			"type": "organelle",
			"pos": org_pos,
			"size": 8.0 + randf() * 4,
			"label": _make_alien_label(),
			"id": feature_id,
			"scan_y": VIEWER_HEIGHT * 0.5 + org_pos.y + 20,  # Offset to viewer center
		})
		feature_id += 1

	# Add mutation-based features
	for m in GameManager.active_mutations:
		var visual: String = m.get("visual", "")
		match visual:
			"extra_cilia":
				for i in range(6):
					var angle: float = TAU * float(i) / 6.0
					var cilia_pos := Vector2(cos(angle), sin(angle)) * _creature_radius
					_creature_features.append({
						"type": "cilia",
						"pos": cilia_pos,
						"size": 15.0,
						"angle": angle,
						"label": _make_alien_label(),
						"id": feature_id,
						"scan_y": VIEWER_HEIGHT * 0.5 + cilia_pos.y + 20,
					})
					feature_id += 1
			"third_eye", "eye_stalks", "photoreceptor":
				var eye_pos := Vector2(0, -_creature_radius * 0.3)
				_creature_features.append({
					"type": "eye",
					"pos": eye_pos,
					"size": 12.0,
					"label": _make_alien_label(),
					"id": feature_id,
					"scan_y": VIEWER_HEIGHT * 0.5 + eye_pos.y + 20,
				})
				feature_id += 1
			"spikes":
				for i in range(8):
					var angle: float = TAU * float(i) / 8.0
					var spike_pos := Vector2(cos(angle), sin(angle)) * _creature_radius
					_creature_features.append({
						"type": "spike",
						"pos": spike_pos,
						"size": 20.0,
						"angle": angle,
						"label": _make_alien_label(),
						"id": feature_id,
						"scan_y": VIEWER_HEIGHT * 0.5 + spike_pos.y + 20,
					})
					feature_id += 1
			"flagellum":
				var flag_pos := Vector2(0, _creature_radius)
				_creature_features.append({
					"type": "flagellum",
					"pos": flag_pos,
					"size": 40.0,
					"label": _make_alien_label(),
					"id": feature_id,
					"scan_y": VIEWER_HEIGHT * 0.5 + flag_pos.y + 20,
				})
				feature_id += 1
			"tentacles":
				for i in range(3):
					var angle: float = PI + (float(i) - 1) * 0.4
					var tent_pos := Vector2(cos(angle), sin(angle)) * _creature_radius * 0.8
					_creature_features.append({
						"type": "tentacle",
						"pos": tent_pos,
						"size": 30.0,
						"angle": angle,
						"label": _make_alien_label(),
						"id": feature_id,
						"scan_y": VIEWER_HEIGHT * 0.5 + tent_pos.y + 20,
					})
					feature_id += 1
			"toxin_glands":
				for i in range(2):
					var angle: float = PI * 0.5 + float(i) * PI
					var gland_pos := Vector2(cos(angle), sin(angle)) * _creature_radius * 0.6
					_creature_features.append({
						"type": "gland",
						"pos": gland_pos,
						"size": 10.0,
						"label": _make_alien_label(),
						"id": feature_id,
						"scan_y": VIEWER_HEIGHT * 0.5 + gland_pos.y + 20,
					})
					feature_id += 1

func _generate_blueprint_callouts() -> void:
	_blueprint_callouts.clear()
	# Generate callout lines for each feature
	for f in _creature_features:
		var callout_dir: Vector2 = f.pos.normalized()
		if callout_dir.length() < 0.1:
			callout_dir = Vector2(1, -1).normalized()
		var callout_end: Vector2 = f.pos + callout_dir * 60.0
		_blueprint_callouts.append({
			"start": f.pos,
			"end": callout_end,
			"label": f.label,
			"alpha": 0.0,
			"delay": randf() * 1.5,
		})

func _make_alien_label() -> String:
	var label: String = ""
	for i in range(randi_range(4, 8)):
		label += ALIEN_GLYPHS[randi() % ALIEN_GLYPHS.size()]
	return label

func _process(delta: float) -> void:
	_time += delta
	_rotation_angle += delta * 0.3  # Slow rotation
	var old_scan_y: float = _scan_y
	_scan_y = fmod(_scan_y + delta * 80.0, VIEWER_HEIGHT)

	# Live feature reveal - when scan line passes a feature, reveal it
	if _live_scan_mode:
		for f in _creature_features:
			var fid: int = f.get("id", -1)
			var f_scan_y: float = f.get("scan_y", 0.0)
			# Check if scan line just passed this feature (with some tolerance)
			if fid not in _scan_revealed_features:
				if (_scan_y > f_scan_y and old_scan_y <= f_scan_y) or \
				   (_scan_y < old_scan_y and (f_scan_y > old_scan_y or f_scan_y < _scan_y)):
					_scan_revealed_features.append(fid)
					_glitch_timer = 0.08  # Small glitch when feature detected

	if _glitch_timer > 0:
		_glitch_timer -= delta

	# Blueprint animation
	if _blueprint_active:
		_blueprint_timer += delta
		# Update callout alphas
		for c in _blueprint_callouts:
			if _blueprint_timer > c.delay:
				c.alpha = minf(c.alpha + delta * 2.0, 1.0)
		# End blueprint after 5 seconds
		if _blueprint_timer > 5.0:
			_blueprint_active = false

	queue_redraw()

func _draw() -> void:
	var font := UIConstants.get_display_font()

	# === TOP: Hologram Viewer ===
	_draw_hologram_viewer(font)

	# === BOTTOM: Building Block Progress ===
	_draw_progress_section(font)

	# === BLUEPRINT OVERLAY ===
	if _blueprint_active:
		_draw_blueprint_overlay(font)

func _draw_hologram_viewer(font: Font) -> void:
	var cx: float = CARD_WIDTH * 0.5
	var cy: float = VIEWER_HEIGHT * 0.5

	# Hologram container frame
	var frame_color := Color(0.2, 0.5, 0.7, 0.5)
	_draw_tech_frame(Rect2(10, 10, CARD_WIDTH - 20, VIEWER_HEIGHT - 20), frame_color)

	# Header
	draw_string(font, Vector2(15, 28), _make_alien_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 0.5, 0.6, 0.5))
	draw_string(font, Vector2(15, 42), "SPECIMEN SCAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.7, 0.9, 0.8))

	# Hologram glow base
	draw_circle(Vector2(cx, cy + 20), 90.0, Color(0.1, 0.3, 0.5, 0.1))
	draw_circle(Vector2(cx, cy + 20), 70.0, Color(0.15, 0.4, 0.6, 0.15))

	# Draw rotating creature
	_draw_creature_hologram(cx, cy + 20, font)

	# Scan line
	var scan_alpha: float = 0.3 + 0.2 * sin(_time * 3.0)
	draw_line(Vector2(20, 50 + _scan_y), Vector2(CARD_WIDTH - 20, 50 + _scan_y), Color(0.3, 0.8, 1.0, scan_alpha), 1.5)

	# Grid overlay
	for i in range(6):
		var gy: float = 60 + i * 40
		draw_line(Vector2(20, gy), Vector2(CARD_WIDTH - 20, gy), Color(0.2, 0.4, 0.5, 0.1), 0.5)
	for i in range(5):
		var gx: float = 30 + i * 55
		draw_line(Vector2(gx, 50), Vector2(gx, VIEWER_HEIGHT - 20), Color(0.2, 0.4, 0.5, 0.1), 0.5)

	# Glitch effect
	if _glitch_timer > 0:
		for i in range(5):
			var gy: float = randf() * VIEWER_HEIGHT
			draw_rect(Rect2(10, gy, CARD_WIDTH - 20, 3), Color(0.4, 0.9, 1.0, _glitch_timer))

	# Tech readouts (meaningless but cool)
	_draw_tech_readouts(font)

func _draw_creature_hologram(cx: float, cy: float, font: Font) -> void:
	# Apply rotation transform for 3D-ish effect
	var rot: float = _rotation_angle
	var scale_x: float = 0.7 + 0.3 * cos(rot)  # Compress on rotation
	var tilt: float = sin(rot) * 0.15  # Slight vertical tilt

	# Hologram color
	var holo_color := Color(0.3, 0.8, 1.0, 0.7)
	var holo_glow := Color(0.4, 0.9, 1.0, 0.3)

	# Draw membrane
	var transformed_points: Array = []
	for p in _creature_points:
		var tp := Vector2(p.x * scale_x, p.y + p.x * tilt)
		transformed_points.append(Vector2(cx + tp.x, cy + tp.y))

	# Membrane outline
	for i in range(transformed_points.size()):
		var p1: Vector2 = transformed_points[i]
		var p2: Vector2 = transformed_points[(i + 1) % transformed_points.size()]
		draw_line(p1, p2, holo_color, 1.5, true)
		# Glow
		draw_line(p1, p2, holo_glow, 4.0, true)

	# Draw features - only show revealed features with fade-in effect
	for f in _creature_features:
		var fid: int = f.get("id", -1)
		var is_revealed: bool = fid in _scan_revealed_features or not _live_scan_mode

		# Calculate fade-in alpha (features fade in when revealed)
		var feature_alpha: float = 1.0 if is_revealed else 0.1

		var fp := Vector2(f.pos.x * scale_x, f.pos.y + f.pos.x * tilt)
		var fpos := Vector2(cx + fp.x, cy + fp.y)

		match f.type:
			"nucleus":
				# Nucleus is always visible but gets brighter when scanned
				draw_circle(fpos, f.size, Color(0.2, 0.5, 0.8, 0.4 * feature_alpha))
				draw_arc(fpos, f.size, 0, TAU, 16, Color(holo_color.r, holo_color.g, holo_color.b, feature_alpha), 1.5)
				# Inner structure
				draw_circle(fpos, f.size * 0.5, Color(0.3, 0.7, 1.0, 0.3 * feature_alpha))
				# Newly revealed flash
				if is_revealed and _glitch_timer > 0.02:
					draw_circle(fpos, f.size + 5, Color(0.5, 0.9, 1.0, _glitch_timer * 3))

			"organelle":
				if is_revealed:
					draw_circle(fpos, f.size, Color(0.3, 0.7, 0.5, 0.4 * feature_alpha))
					draw_arc(fpos, f.size, 0, TAU, 12, Color(0.4, 0.9, 0.6, 0.6 * feature_alpha), 1.0)
					# Reveal flash
					if _glitch_timer > 0.02:
						draw_arc(fpos, f.size + 3, 0, TAU, 12, Color(0.6, 1.0, 0.7, _glitch_timer * 5), 2.0)
				else:
					# Ghost outline before reveal
					draw_arc(fpos, f.size, 0, TAU, 12, Color(0.3, 0.5, 0.4, 0.15), 0.5)

			"eye":
				if is_revealed:
					draw_circle(fpos, f.size, Color(0.9, 0.9, 0.3, 0.5 * feature_alpha))
					draw_circle(fpos, f.size * 0.4, Color(0.1, 0.1, 0.1, 0.8 * feature_alpha))
					draw_arc(fpos, f.size, 0, TAU, 12, Color(holo_color.r, holo_color.g, holo_color.b, feature_alpha), 1.0)
					if _glitch_timer > 0.02:
						draw_circle(fpos, f.size + 4, Color(1.0, 1.0, 0.5, _glitch_timer * 4))
				else:
					draw_arc(fpos, f.size, 0, TAU, 8, Color(0.5, 0.5, 0.2, 0.1), 0.5)

			"cilia":
				if is_revealed:
					var angle: float = f.get("angle", 0)
					var end_pos: Vector2 = fpos + Vector2(cos(angle), sin(angle)) * f.size
					var wave: float = sin(_time * 5.0 + angle * 2.0) * 3.0
					end_pos += Vector2(-sin(angle), cos(angle)) * wave
					draw_line(fpos, end_pos, Color(0.5, 0.8, 1.0, 0.6 * feature_alpha), 1.5, true)

			"spike":
				if is_revealed:
					var angle: float = f.get("angle", 0)
					var tip: Vector2 = fpos + Vector2(cos(angle), sin(angle)) * f.size
					draw_line(fpos, tip, Color(0.9, 0.4, 0.3, 0.7 * feature_alpha), 2.0, true)
					if _glitch_timer > 0.02:
						draw_circle(tip, 4, Color(1.0, 0.5, 0.3, _glitch_timer * 4))
				else:
					var angle: float = f.get("angle", 0)
					var tip: Vector2 = fpos + Vector2(cos(angle), sin(angle)) * f.size * 0.5
					draw_line(fpos, tip, Color(0.5, 0.3, 0.2, 0.1), 0.5, true)

			"flagellum":
				if is_revealed:
					var base: Vector2 = fpos
					for i in range(8):
						var wave: float = sin(_time * 4.0 + i * 0.5) * 8.0
						var next: Vector2 = base + Vector2(wave, 5.0)
						draw_line(base, next, Color(0.4, 0.8, 0.6, (0.6 - i * 0.05) * feature_alpha), 2.0 - i * 0.15, true)
						base = next

			"tentacle":
				if is_revealed:
					var angle: float = f.get("angle", PI)
					var base: Vector2 = fpos
					for i in range(6):
						var wave: float = sin(_time * 3.0 + i * 0.7 + angle) * 5.0
						var dir := Vector2(cos(angle + wave * 0.05), sin(angle + wave * 0.05))
						var next: Vector2 = base + dir * 5.0
						draw_line(base, next, Color(0.6, 0.4, 0.8, (0.6 - i * 0.08) * feature_alpha), 2.5 - i * 0.3, true)
						base = next

			"gland":
				if is_revealed:
					var pulse: float = 0.8 + 0.2 * sin(_time * 2.0)
					draw_circle(fpos, f.size * pulse, Color(0.8, 0.3, 0.5, 0.5 * feature_alpha))
					draw_arc(fpos, f.size, 0, TAU, 10, Color(0.9, 0.4, 0.6, 0.7 * feature_alpha), 1.0)
					if _glitch_timer > 0.02:
						draw_circle(fpos, f.size + 3, Color(1.0, 0.5, 0.6, _glitch_timer * 4))

func _draw_tech_readouts(font: Font) -> void:
	# Fake scientific readouts
	var readout_y: float = VIEWER_HEIGHT - 50

	# Oscillating values
	var val1: float = 50 + sin(_time * 1.3) * 30 + randf() * 5
	var val2: float = 75 + cos(_time * 0.9) * 20 + randf() * 3
	var val3: float = 30 + sin(_time * 2.1) * 25 + randf() * 8

	draw_string(font, Vector2(15, readout_y), "BIO.SIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.6, 0.7, 0.6))
	draw_string(font, Vector2(60, readout_y), "%.1f" % val1, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 0.9, 0.5, 0.8))

	draw_string(font, Vector2(100, readout_y), "MTB.RT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.6, 0.7, 0.6))
	draw_string(font, Vector2(145, readout_y), "%.1f" % val2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 0.9, 0.5, 0.8))

	readout_y += 14
	draw_string(font, Vector2(15, readout_y), "STAB.IX", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.6, 0.7, 0.6))
	draw_string(font, Vector2(65, readout_y), "%.1f%%" % val3, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 0.9, 0.5, 0.8))

	# Alien timestamp
	draw_string(font, Vector2(140, readout_y), _make_alien_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.3, 0.5, 0.6, 0.4))

func _draw_progress_section(font: Font) -> void:
	var start_y: float = VIEWER_HEIGHT + 10

	# Section header
	draw_line(Vector2(10, start_y), Vector2(CARD_WIDTH - 10, start_y), Color(0.2, 0.5, 0.7, 0.4), 1.0)
	start_y += 15
	draw_string(font, Vector2(15, start_y), _make_alien_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.3, 0.5, 0.6, 0.4))
	start_y += 12
	draw_string(font, Vector2(15, start_y), "EVOLUTION PROGRESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.7, 0.9, 0.8))
	start_y += 20

	# Building block categories
	var categories: Array = [
		{"key": "nucleotides", "label": "NUCLEOTIDES", "color": Color(0.3, 0.7, 1.0)},
		{"key": "amino_acids", "label": "AMINO ACIDS", "color": Color(0.2, 1.0, 0.5)},
		{"key": "lipids", "label": "LIPIDS", "color": Color(1.0, 0.9, 0.3)},
		{"key": "coenzymes", "label": "COENZYMES", "color": Color(1.0, 0.5, 0.7)},
		{"key": "organelles", "label": "ORGANELLES", "color": Color(0.8, 0.4, 1.0)},
	]

	var evolve_threshold: int = 10  # Items needed to trigger evolution

	for cat in categories:
		var count: int = GameManager.inventory.get(cat.key, []).size()
		var progress: float = clampf(float(count) / float(evolve_threshold), 0.0, 1.0)
		var is_ready: bool = count >= evolve_threshold

		# Label
		draw_string(font, Vector2(15, start_y), cat.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.6, 0.7, 0.7))

		# Count
		var count_text: String = "%d/%d" % [count, evolve_threshold]
		var count_color: Color = cat.color if not is_ready else Color(1.0, 1.0, 0.5, 1.0)
		draw_string(font, Vector2(CARD_WIDTH - 50, start_y), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, count_color)

		start_y += 12

		# Progress bar background
		var bar_rect := Rect2(15, start_y, CARD_WIDTH - 30, 8)
		draw_rect(bar_rect, Color(0.1, 0.15, 0.2, 0.5))

		# Progress bar fill
		var fill_rect := Rect2(15, start_y, (CARD_WIDTH - 30) * progress, 8)
		var fill_color := Color(cat.color.r, cat.color.g, cat.color.b, 0.7)
		draw_rect(fill_rect, fill_color)

		# Glow if ready
		if is_ready:
			var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
			draw_rect(bar_rect, Color(1.0, 1.0, 0.5, pulse * 0.3), false, 2.0)

		# Segment markers
		for i in range(1, evolve_threshold):
			var mx: float = 15 + (CARD_WIDTH - 30) * (float(i) / evolve_threshold)
			draw_line(Vector2(mx, start_y), Vector2(mx, start_y + 8), Color(0.0, 0.0, 0.0, 0.3), 1.0)

		start_y += 18

	# Evolution level display
	start_y += 5
	draw_line(Vector2(10, start_y), Vector2(CARD_WIDTH - 10, start_y), Color(0.2, 0.5, 0.7, 0.3), 1.0)
	start_y += 15

	var evo_level: int = GameManager.evolution_level
	draw_string(font, Vector2(15, start_y), "EVO LEVEL:", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.7, 0.8, 0.7))
	draw_string(font, Vector2(90, start_y), str(evo_level), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 1.0, 0.5, 0.95))

	# Evolution pips
	for i in range(mini(evo_level, 10)):
		var px: float = 120 + i * 14
		var pip_color := Color(0.3, 0.9, 0.5, 0.7)
		if i >= 5:
			pip_color = Color(0.9, 0.7, 0.2, 0.8)
		draw_rect(Rect2(px, start_y - 10, 10, 12), pip_color)

func _draw_blueprint_overlay(font: Font) -> void:
	# Darken background
	draw_rect(Rect2(0, 0, CARD_WIDTH, VIEWER_HEIGHT), Color(0.0, 0.02, 0.05, 0.7))

	# Blueprint grid
	var grid_color := Color(0.2, 0.4, 0.6, 0.2)
	for i in range(20):
		var gy: float = i * 16
		draw_line(Vector2(0, gy), Vector2(CARD_WIDTH, gy), grid_color, 0.5)
	for i in range(18):
		var gx: float = i * 16
		draw_line(Vector2(gx, 0), Vector2(gx, VIEWER_HEIGHT), grid_color, 0.5)

	var cx: float = CARD_WIDTH * 0.5
	var cy: float = VIEWER_HEIGHT * 0.5

	# Blueprint header
	var header_flash: float = 0.7 + 0.3 * sin(_time * 5.0)
	draw_string(font, Vector2(15, 25), "MUTATION ANALYSIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.8, 1.0, header_flash))

	# Mutation name
	var mut_name: String = _blueprint_mutation.get("name", "UNKNOWN")
	draw_string(font, Vector2(15, 42), mut_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.7, 0.3, 0.9))

	# Draw creature outline (blueprint style)
	var blueprint_color := Color(0.3, 0.6, 0.9, 0.8)
	var blueprint_glow := Color(0.2, 0.5, 0.8, 0.2)

	# Membrane outline
	for i in range(_creature_points.size()):
		var p1: Vector2 = _creature_points[i] + Vector2(cx, cy)
		var p2: Vector2 = _creature_points[(i + 1) % _creature_points.size()] + Vector2(cx, cy)
		draw_line(p1, p2, blueprint_color, 1.0, true)

	# Draw callout lines
	for c in _blueprint_callouts:
		if c.alpha > 0:
			var start: Vector2 = c.start + Vector2(cx, cy)
			var end: Vector2 = c.end + Vector2(cx, cy)
			var line_color := Color(0.4, 0.7, 0.9, c.alpha * 0.8)

			# Callout line
			draw_line(start, end, line_color, 1.0, true)

			# Endpoint dot
			draw_circle(end, 3.0, line_color)

			# Label
			var label_offset := Vector2(5, 4) if end.x > cx else Vector2(-80, 4)
			draw_string(font, end + label_offset, c.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.5, 0.7, 0.9, c.alpha * 0.7))

	# Highlight new mutation area
	if _blueprint_timer < 4.0:
		var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
		var highlight_color := Color(0.9, 0.6, 0.2, pulse * 0.4)

		# Draw highlight around relevant features
		var visual: String = _blueprint_mutation.get("visual", "")
		for f in _creature_features:
			if _feature_matches_mutation(f.type, visual):
				var fpos: Vector2 = f.pos + Vector2(cx, cy)
				draw_circle(fpos, f.size + 10, highlight_color)
				draw_arc(fpos, f.size + 15, 0, TAU, 16, Color(0.9, 0.5, 0.2, pulse * 0.6), 2.0)

func _feature_matches_mutation(feature_type: String, visual: String) -> bool:
	match visual:
		"extra_cilia": return feature_type == "cilia"
		"third_eye", "eye_stalks", "photoreceptor": return feature_type == "eye"
		"spikes": return feature_type == "spike"
		"flagellum": return feature_type == "flagellum"
		"tentacles": return feature_type == "tentacle"
		"toxin_glands": return feature_type == "gland"
	return false

func _draw_tech_frame(rect: Rect2, color: Color) -> void:
	var corner_len: float = 15.0
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y

	# Corner brackets
	draw_line(Vector2(x, y), Vector2(x + corner_len, y), color, 1.5)
	draw_line(Vector2(x, y), Vector2(x, y + corner_len), color, 1.5)
	draw_line(Vector2(x + w, y), Vector2(x + w - corner_len, y), color, 1.5)
	draw_line(Vector2(x + w, y), Vector2(x + w, y + corner_len), color, 1.5)
	draw_line(Vector2(x, y + h), Vector2(x + corner_len, y + h), color, 1.5)
	draw_line(Vector2(x, y + h), Vector2(x, y + h - corner_len), color, 1.5)
	draw_line(Vector2(x + w, y + h), Vector2(x + w - corner_len, y + h), color, 1.5)
	draw_line(Vector2(x + w, y + h), Vector2(x + w, y + h - corner_len), color, 1.5)

extends Control
## DNA helix HUD — compact helix for left pane bottom section.
## Redraws only on inventory change or periodic rotation tick.

# Compact sizing for bottom of left pane
var _cx: float = 140.0  # Center X
var _top_y: float = 30.0  # Start after header
var _height: float = 350.0  # Compact height
var _radius: float = 50.0  # Moderate radius
const MAX_FILL: int = 10

var _angle: float = 0.0
var _redraw_timer: float = 0.0
var _flash_active: bool = false

const DEFS: Array = [
	{"key": "nucleotides", "label": "NTP", "color": [1.0, 0.9, 0.1]},
	{"key": "monosaccharides", "label": "CHO", "color": [0.9, 0.7, 0.2]},
	{"key": "amino_acids", "label": "AA", "color": [0.6, 0.9, 0.4]},
	{"key": "coenzymes", "label": "CoE", "color": [0.4, 0.6, 1.0]},
	{"key": "lipids", "label": "LPD", "color": [0.3, 0.7, 0.9]},
	{"key": "nucleotide_bases", "label": "Base", "color": [0.9, 0.3, 0.3]},
	{"key": "organic_acids", "label": "OA", "color": [0.8, 0.5, 0.1]},
	{"key": "organelles", "label": "ORG", "color": [0.2, 0.9, 0.3]},
]

var _flash: Dictionary = {}
var _last_counts: Dictionary = {}

func _ready() -> void:
	GameManager.inventory_changed.connect(_on_inv_changed)
	for d in DEFS:
		_flash[d.key] = 0.0
		_last_counts[d.key] = 0
	# Calculate sizes based on available space
	call_deferred("_calculate_sizes")
	# Recalculate when resized
	resized.connect(_calculate_sizes)

func _calculate_sizes() -> void:
	# Use own size property for reliable sizing (fixes cutoff issue)
	_cx = size.x * 0.5
	_top_y = 30.0  # Start after header
	_height = size.y - 80.0  # Leave margins for header and footer
	# Scale radius to fit available space - ensures helix is fully visible
	_radius = minf(size.x * 0.32, minf(size.y * 0.08, 50.0))

func _on_inv_changed() -> void:
	for d in DEFS:
		var c: int = GameManager.inventory[d.key].size()
		if c > _last_counts[d.key]:
			_flash[d.key] = 1.0
			_flash_active = true
		_last_counts[d.key] = c
	queue_redraw()

func _process(delta: float) -> void:
	_angle += delta * 1.0
	if _flash_active:
		var any: bool = false
		for key in _flash:
			_flash[key] = maxf(_flash[key] - delta * 2.0, 0.0)
			if _flash[key] > 0:
				any = true
		_flash_active = any

	# Only redraw every ~100ms for rotation, or immediately on flash
	_redraw_timer -= delta
	if _redraw_timer <= 0 or _flash_active:
		_redraw_timer = 0.1
		queue_redraw()

func _draw() -> void:
	var n: int = DEFS.size()
	var spacing: float = _height / float(n)
	var font := UIConstants.get_display_font()

	# Draw helix title
	draw_string(font, Vector2(10, 20), "GENOME", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.7, 0.9, 0.8))
	draw_line(Vector2(10, 28), Vector2(size.x - 10, 28), Color(0.2, 0.5, 0.7, 0.3), 1.0)

	# Backbone thickness scales with size
	var backbone_width: float = maxf(2.0, _radius * 0.04)
	var rung_width: float = maxf(3.0, _radius * 0.06)
	var glow_width: float = maxf(5.0, _radius * 0.1)

	for i in range(n):
		var d: Dictionary = DEFS[i]
		var y: float = _top_y + (i + 0.5) * spacing
		var a: float = _angle + TAU * float(i) / float(n)
		var sx: float = sin(a)
		var depth: float = cos(a) * 0.5 + 0.5
		var lx: float = _cx + sx * _radius
		var rx: float = _cx - sx * _radius
		var light: float = 0.4 + 0.6 * depth
		var al: float = 0.35 + 0.5 * depth

		# Backbone to next (double helix strands)
		if i < n - 1:
			var ny: float = _top_y + (i + 1.5) * spacing
			var na: float = _angle + TAU * float(i + 1) / float(n)
			# Left strand
			draw_line(Vector2(lx, y), Vector2(_cx + sin(na) * _radius, ny), Color(0.3, 0.5, 0.8, al * 0.5), backbone_width, true)
			# Right strand
			draw_line(Vector2(rx, y), Vector2(_cx - sin(na) * _radius, ny), Color(0.3, 0.5, 0.8, al * 0.5), backbone_width, true)

		# Rung (base pair)
		var col := Color(d.color[0], d.color[1], d.color[2])
		var count: int = GameManager.inventory[d.key].size()
		var fill: float = clampf(float(count) / MAX_FILL, 0.0, 1.0)
		var from := Vector2(lx, y)
		var to := Vector2(rx, y)

		# Empty rung (dark)
		draw_line(from, to, Color(0.15, 0.2, 0.3, al * 0.4), rung_width * 0.6, true)

		if fill > 0:
			var mid := (from + to) * 0.5
			var fl := mid.lerp(from, fill)
			var fr := mid.lerp(to, fill)
			# Filled portion glows
			draw_line(fl, fr, Color(col.r * light, col.g * light, col.b * light, al), rung_width, true)

			# Flash effect when collecting
			var f: float = _flash[d.key]
			if f > 0:
				draw_line(fl, fr, Color(1.0, 1.0, 0.9, f * 0.5 * light), glow_width, true)

		# Node circles at connection points
		var node_size: float = maxf(3.0, _radius * 0.05)
		draw_circle(from, node_size, Color(0.4, 0.6, 0.9, al * 0.6))
		draw_circle(to, node_size, Color(0.4, 0.6, 0.9, al * 0.6))

		# Labels on visible side
		if depth > 0.25:
			var label_alpha: float = (depth - 0.25) * 1.2
			var lbl_x: float = maxf(lx, rx) + 12.0
			var lbl_text: String = "%s %d/%d" % [d.label, count, MAX_FILL]
			draw_string(font, Vector2(lbl_x, y + 4), lbl_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col.r, col.g, col.b, label_alpha * 0.9))

	# Bottom summary
	var total: int = GameManager.get_total_collected()
	var summary_y: float = _top_y + _height + 30
	draw_string(font, Vector2(10, summary_y), "TOTAL: %d" % total, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.8, 0.9, 0.7))

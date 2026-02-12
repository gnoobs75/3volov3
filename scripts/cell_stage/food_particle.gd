extends Area2D
## Procedurally drawn food particle with alien symbol labels.
## Biomolecules use color from JSON data; organelles get complex multi-ring shapes.

# Alien glyphs for category-based symbols
const CATEGORY_SYMBOLS: Dictionary = {
	"nucleotide": "⊛",
	"amino_acid": "∆",
	"coenzyme": "Ω",
	"lipid": "◊",
	"nucleotide_base": "Φ",
	"monosaccharide": "⊕",
	"organic_acid": "Ψ",
	"organelle": "⊞",
	"default": "⊗",
}

# Additional decorative glyphs
const DECO_GLYPHS: Array = ["╬", "╫", "╪", "┼", "╋", "╂", "╁", "╀"]

var component_data: Dictionary = {}
var is_organelle: bool = false
var _time: float = 0.0
var _base_radius: float = 6.0
var _shape_seed: float = 0.0
var _color: Color = Color(0.95, 0.85, 0.2, 0.8)
var _symbol: String = "⊗"  # Alien symbol for this particle
var _deco_glyph: String = ""  # Optional decorative glyph

# Beam interaction
var is_being_beamed: bool = false
var _beam_pull_speed: float = 0.0  # Accelerates while beamed

func _ready() -> void:
	_shape_seed = randf() * 100.0
	if is_organelle:
		_base_radius = 9.0
	# Parse color from data if available
	var c: Array = component_data.get("color", [])
	if c.size() >= 3:
		_color = Color(c[0], c[1], c[2], 0.85)
	# Assign alien symbol based on category
	var category: String = component_data.get("category", "default")
	_symbol = CATEGORY_SYMBOLS.get(category, CATEGORY_SYMBOLS["default"])
	# Random decorative glyph for rare items
	var rarity: String = component_data.get("rarity", "common")
	if rarity in ["uncommon", "rare", "legendary"]:
		_deco_glyph = DECO_GLYPHS[randi() % DECO_GLYPHS.size()]
	body_entered.connect(_on_body_entered)

func setup(data: Dictionary, organelle: bool = false) -> void:
	component_data = data
	is_organelle = organelle

func _process(delta: float) -> void:
	_time += delta
	if is_being_beamed:
		_beam_pull_speed = minf(_beam_pull_speed + 500.0 * delta, 600.0)
		queue_redraw()  # Only redraw when being beamed (visual feedback needed)
	elif _beam_pull_speed > 0.0:
		_beam_pull_speed = maxf(_beam_pull_speed - 400.0 * delta, 0.0)
		queue_redraw()  # Redraw while decelerating from beam
	# Skip redraw when idle - pulse animation is subtle and not worth the cost

func beam_pull_toward(target_pos: Vector2, delta: float) -> void:
	## Called by player each frame while beaming this particle
	is_being_beamed = true
	var dir := (target_pos - global_position).normalized()
	global_position += dir * _beam_pull_speed * delta

func beam_release() -> void:
	is_being_beamed = false

func get_beam_color() -> Color:
	return _color

func _draw() -> void:
	var pulse: float = 0.9 + 0.15 * sin(_time * 3.0 + _shape_seed)
	var r: float = _base_radius * pulse

	if is_organelle:
		_draw_organelle(r)
	else:
		_draw_biomolecule(r)

	# Beam suction rings when being pulled
	if is_being_beamed:
		var ring_alpha: float = 0.3 + 0.2 * sin(_time * 10.0)
		var ring_r: float = r * 2.5 - fmod(_time * 40.0, r * 2.0)
		draw_arc(Vector2.ZERO, maxf(ring_r, 2.0), 0, TAU, 16, Color(_color.r, _color.g, _color.b, ring_alpha), 1.5, true)
		var ring_r2: float = r * 2.5 - fmod(_time * 40.0 + r, r * 2.0)
		draw_arc(Vector2.ZERO, maxf(ring_r2, 2.0), 0, TAU, 16, Color(_color.r, _color.g, _color.b, ring_alpha * 0.5), 1.0, true)

	# Floating label with short scientific name
	_draw_label()

func _draw_biomolecule(r: float) -> void:
	var color := _color
	var rarity: String = component_data.get("rarity", "common")

	# Outer glow (brighter, more vibrant)
	var glow_mult: float = 1.5
	match rarity:
		"uncommon": glow_mult = 2.5
		"rare": glow_mult = 4.0

	draw_circle(Vector2.ZERO, r * 2.8, Color(color.r, color.g, color.b, 0.06 * glow_mult))
	draw_circle(Vector2.ZERO, r * 2.0, Color(color.r, color.g, color.b, 0.1 * glow_mult))
	draw_circle(Vector2.ZERO, r * 1.3, Color(color.r, color.g, color.b, 0.15 * glow_mult))

	# Rare items get sparkle ring
	if rarity == "rare":
		var sparkle_a: float = 0.15 + 0.1 * sin(_time * 5.0)
		draw_arc(Vector2.ZERO, r * 1.6, _time * 2.0, _time * 2.0 + PI, 12, Color(1.0, 1.0, 0.8, sparkle_a), 1.0, true)

	# Shape varies by category
	var category: String = component_data.get("category", "")
	match category:
		"nucleotide":
			_draw_hexagon(r, color)
		"amino_acid":
			_draw_diamond(r, color)
		"coenzyme":
			_draw_ring(r, color)
		"lipid":
			_draw_pill(r, color)
		"nucleotide_base":
			_draw_pentagon(r, color)
		_:
			_draw_hexagon(r, color)

func _draw_hexagon(r: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var a: float = TAU * i / 6.0 - PI / 6.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	draw_colored_polygon(pts, Color(color.r * 0.6, color.g * 0.6, color.b * 0.4, 0.65))
	for i in range(6):
		draw_line(pts[i], pts[(i + 1) % 6], color, 1.0, true)
	draw_circle(Vector2.ZERO, r * 0.25, color)

func _draw_diamond(r: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, r), Vector2(-r * 0.7, 0)
	])
	draw_colored_polygon(pts, Color(color.r * 0.5, color.g * 0.5, color.b * 0.4, 0.65))
	for i in range(4):
		draw_line(pts[i], pts[(i + 1) % 4], color, 1.0, true)

func _draw_ring(r: float, color: Color) -> void:
	draw_arc(Vector2.ZERO, r, 0, TAU, 16, color, 2.0, true)
	draw_arc(Vector2.ZERO, r * 0.5, 0, TAU, 12, Color(color, 0.5), 1.2, true)
	draw_circle(Vector2.ZERO, r * 0.2, color)

func _draw_pill(r: float, color: Color) -> void:
	# Elongated capsule shape
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(8):
		var a: float = PI + PI * i / 7.0
		pts.append(Vector2(cos(a) * r * 0.5 - r * 0.4, sin(a) * r))
	for i in range(8):
		var a: float = PI * i / 7.0
		pts.append(Vector2(cos(a) * r * 0.5 + r * 0.4, sin(a) * r))
	draw_colored_polygon(pts, Color(color.r * 0.5, color.g * 0.5, color.b * 0.4, 0.6))
	# Outline
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], color, 1.0, true)

func _draw_pentagon(r: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(5):
		var a: float = TAU * i / 5.0 - PI / 2.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	draw_colored_polygon(pts, Color(color.r * 0.5, color.g * 0.5, color.b * 0.4, 0.65))
	for i in range(5):
		draw_line(pts[i], pts[(i + 1) % 5], color, 1.0, true)

func _draw_organelle(r: float) -> void:
	var color := _color

	# Glow (vibrant bioluminescent)
	draw_circle(Vector2.ZERO, r * 3.5, Color(color.r, color.g, color.b, 0.06))
	draw_circle(Vector2.ZERO, r * 2.5, Color(color.r, color.g, color.b, 0.12))
	draw_circle(Vector2.ZERO, r * 1.8, Color(color.r, color.g, color.b, 0.18))

	# Outer membrane (wobbly circle)
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 16
	for i in range(n):
		var angle: float = TAU * i / n
		var wobble: float = sin(_time * 2.5 + _shape_seed + i * 0.8) * 1.5
		pts.append(Vector2(cos(angle) * (r + wobble), sin(angle) * (r + wobble)))
	draw_colored_polygon(pts, Color(color.r * 0.35, color.g * 0.35, color.b * 0.25, 0.6))
	for i in range(n):
		draw_line(pts[i], pts[(i + 1) % n], color, 1.2, true)

	# Inner structure
	var inner_r: float = r * 0.5
	draw_arc(Vector2.ZERO, inner_r, 0, TAU, 16, Color(color, 0.5), 1.0, true)
	for i in range(3):
		var a: float = TAU * i / 3.0 + _time * 0.5
		var d: float = inner_r * 0.5
		draw_circle(Vector2(cos(a) * d, sin(a) * d), 1.5, Color(color, 0.7))

	# Rare organelles get a star burst
	var rarity: String = component_data.get("rarity", "common")
	if rarity == "rare" or rarity == "legendary":
		for s in range(4):
			var sa: float = _time * 1.5 + TAU * s / 4.0
			var sp := Vector2(cos(sa) * r * 1.3, sin(sa) * r * 1.3)
			draw_circle(sp, 1.0, Color(1.0, 1.0, 0.8, 0.3 + 0.2 * sin(_time * 4.0 + s)))

func _draw_label() -> void:
	# Simple floating alien symbol - minimal and clean
	var font := UIConstants.get_display_font()
	var font_size: int = 10
	var label_y: float = -_base_radius - 6.0 + sin(_time * 2.0) * 1.0
	var rarity: String = component_data.get("rarity", "common")

	# Just the symbol, color-matched to the particle
	var symbol_color := Color(
		minf(_color.r * 1.2, 1.0),
		minf(_color.g * 1.2, 1.0),
		minf(_color.b * 1.1, 1.0),
		0.85
	)

	# Rarity affects brightness
	if rarity == "uncommon":
		symbol_color = symbol_color.lightened(0.15)
	elif rarity == "rare":
		symbol_color = Color(1.0, 0.95, 0.6, 0.95)
	elif rarity == "legendary":
		var hue: float = fmod(_time * 0.3, 1.0)
		symbol_color = Color.from_hsv(hue, 0.5, 1.0, 0.95)

	# Tiny shadow for readability
	var text_width: float = font.get_string_size(_symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	draw_string(font, Vector2(-text_width * 0.5 + 0.5, label_y + 0.5), _symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.4))
	draw_string(font, Vector2(-text_width * 0.5, label_y), _symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, symbol_color)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("feed"):
		body.feed(component_data)
		# 15% chance to drop a gene fragment from rare food
		if randf() < 0.15:
			GameManager.add_gene_fragments(1)
		queue_free()

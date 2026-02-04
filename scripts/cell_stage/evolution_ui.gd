extends CanvasLayer
## Evolution choice UI: shows 3 procedurally drawn mutation cards when a vial fills.
## Pauses game, player picks one, mutation applied, game resumes.

const CARD_WIDTH: float = 200.0
const CARD_HEIGHT: float = 300.0
const CARD_SPACING: float = 30.0
const CARD_Y: float = 150.0

var _active: bool = false
var _choices: Array[Dictionary] = []
var _category: String = ""
var _hover_index: int = -1
var _time: float = 0.0
var _appear_t: float = 0.0  # 0→1 animation
var _card_draw: Control = null
var _bg_particles: Array = []  # [{pos, vel, life, color, size}]
var _selected_index: int = -1
var _select_anim: float = 0.0  # 0→1 selection flash

func _ready() -> void:
	visible = false
	layer = 10
	GameManager.evolution_triggered.connect(_on_evolution_triggered)
	# Create a Control child for drawing cards
	_card_draw = Control.new()
	_card_draw.name = "CardDraw"
	_card_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_draw.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_draw.draw.connect(_draw_cards)
	_card_draw.gui_input.connect(_on_gui_input)
	add_child(_card_draw)

func _on_evolution_triggered(category_key: String) -> void:
	if _active:
		return
	_category = category_key
	_choices = EvolutionData.generate_choices(category_key, GameManager.evolution_level)
	if _choices.is_empty():
		return
	_active = true
	_appear_t = 0.0
	_hover_index = -1
	visible = true
	get_tree().paused = true

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_appear_t = minf(_appear_t + delta * 3.0, 1.0)

	# Selection animation
	if _selected_index >= 0:
		_select_anim += delta * 4.0
		if _select_anim >= 1.0:
			_finalize_selection()
			return

	# Background particles
	if _appear_t > 0.3 and randf() < 0.3:
		var vp := get_viewport().get_visible_rect().size
		_bg_particles.append({
			"pos": Vector2(randf() * vp.x, vp.y + 10),
			"vel": Vector2(randf_range(-20, 20), randf_range(-60, -30)),
			"life": 1.0,
			"color": Color(randf_range(0.2, 0.5), randf_range(0.5, 0.9), randf_range(0.7, 1.0), 0.3),
			"size": randf_range(1.0, 3.0),
		})
	var alive: Array = []
	for p in _bg_particles:
		p.life -= delta * 0.4
		p.pos += p.vel * delta
		if p.life > 0:
			alive.append(p)
	_bg_particles = alive

	_card_draw.queue_redraw()

func _get_card_rect(index: int) -> Rect2:
	var total_w: float = _choices.size() * CARD_WIDTH + (_choices.size() - 1) * CARD_SPACING
	var vp_size := get_viewport().get_visible_rect().size
	var start_x: float = (vp_size.x - total_w) * 0.5
	var x: float = start_x + index * (CARD_WIDTH + CARD_SPACING)
	var y: float = CARD_Y + (1.0 - _appear_t) * 80.0
	return Rect2(x, y, CARD_WIDTH, CARD_HEIGHT)

func _on_gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion:
		_hover_index = -1
		for i in range(_choices.size()):
			if _get_card_rect(i).has_point(event.position):
				_hover_index = i
				break
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover_index >= 0 and _hover_index < _choices.size():
			_select_choice(_hover_index)

func _select_choice(index: int) -> void:
	if _selected_index >= 0:
		return  # Already selecting
	_selected_index = index
	_select_anim = 0.0

func _finalize_selection() -> void:
	var mutation: Dictionary = _choices[_selected_index]
	GameManager.consume_vial_for_evolution(_category)
	GameManager.apply_mutation(mutation)
	_active = false
	_selected_index = -1
	_select_anim = 0.0
	_bg_particles.clear()
	visible = false
	get_tree().paused = false

func _draw_cards() -> void:
	if not _active:
		return
	var vp_size := get_viewport().get_visible_rect().size

	# Dim background
	_card_draw.draw_rect(Rect2(0, 0, vp_size.x, vp_size.y), Color(0.0, 0.02, 0.05, 0.75 * _appear_t))

	# Background floating particles
	for p in _bg_particles:
		_card_draw.draw_circle(p.pos, p.size, Color(p.color.r, p.color.g, p.color.b, p.life * p.color.a))

	# Title
	var font := ThemeDB.fallback_font
	var title := "EVOLUTION — Choose a Mutation"
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
	var title_x: float = (vp_size.x - title_size.x) * 0.5
	var title_a: float = _appear_t
	_card_draw.draw_string(font, Vector2(title_x, 100 + (1.0 - _appear_t) * 30.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 0.9, 1.0, title_a))

	# Category subtitle
	var cat_label: String = GameManager.CATEGORY_LABELS.get(_category, _category)
	var sub := "Vial filled: " + cat_label
	var sub_size := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	_card_draw.draw_string(font, Vector2((vp_size.x - sub_size.x) * 0.5, 125 + (1.0 - _appear_t) * 20.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.8, 0.9, title_a * 0.7))

	# Draw each card
	for i in range(_choices.size()):
		_draw_single_card(i)

func _draw_single_card(index: int) -> void:
	var m: Dictionary = _choices[index]
	var rect := _get_card_rect(index)
	var hovered: bool = index == _hover_index
	var font := ThemeDB.fallback_font

	# Card animation offset per card
	var card_a: float = clampf(_appear_t * 3.0 - index * 0.5, 0.0, 1.0)

	# Border color from category affinity
	var affinities: Array = m.get("affinities", [])
	var border_color := Color(0.3, 0.7, 0.9)
	if affinities.size() > 0:
		border_color = EvolutionData.CATEGORY_COLORS.get(affinities[0], border_color)

	# Tier glow
	var tier: int = m.get("tier", 1)
	var tier_glow: float = 0.3 + tier * 0.15

	# Selection state
	var is_selected: bool = index == _selected_index
	var is_rejected: bool = _selected_index >= 0 and not is_selected

	# Card background
	var bg_color := Color(0.03, 0.06, 0.12, 0.92 * card_a)
	if hovered and _selected_index < 0:
		bg_color = Color(0.06, 0.1, 0.18, 0.95 * card_a)
	if is_selected:
		bg_color = bg_color.lerp(Color(border_color.r * 0.2, border_color.g * 0.2, border_color.b * 0.2, 0.95), _select_anim)
	if is_rejected:
		card_a *= (1.0 - _select_anim)
	_card_draw.draw_rect(rect, bg_color)

	# Selection glow
	if is_selected:
		var glow_r: float = 20.0 + _select_anim * 40.0
		_card_draw.draw_rect(Rect2(rect.position.x - glow_r * 0.5, rect.position.y - glow_r * 0.5, rect.size.x + glow_r, rect.size.y + glow_r), Color(border_color.r, border_color.g, border_color.b, (1.0 - _select_anim) * 0.15))

	# Border
	var bw: float = 2.0 if not hovered else 3.0
	var bc := Color(border_color.r, border_color.g, border_color.b, (tier_glow + 0.2 * sin(_time * 2.0 + index)) * card_a)
	# Top
	_card_draw.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), bc, bw)
	# Bottom
	_card_draw.draw_line(rect.position + Vector2(0, rect.size.y), rect.end, bc, bw)
	# Left
	_card_draw.draw_line(rect.position, rect.position + Vector2(0, rect.size.y), bc, bw)
	# Right
	_card_draw.draw_line(rect.position + Vector2(rect.size.x, 0), rect.end, bc, bw)

	# Hover glow
	if hovered:
		_card_draw.draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, 0.08))

	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y

	# Tier stars
	var star_y: float = cy + 18.0
	for s in range(tier):
		var sx: float = cx - (tier - 1) * 8.0 + s * 16.0
		_draw_star(Vector2(sx, star_y), 5.0, Color(1.0, 0.9, 0.3, card_a))

	# Mutation visual preview (centered icon area)
	var preview_center := Vector2(cx, cy + 80.0)
	_draw_mutation_preview(m.get("visual", ""), preview_center, card_a, border_color)

	# Name
	var name_str: String = m.get("name", "Unknown")
	var name_size := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	_card_draw.draw_string(font, Vector2(cx - name_size.x * 0.5, cy + 145.0), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.95, 1.0, card_a))

	# Description
	var desc: String = m.get("desc", "")
	var desc_size := font.get_string_size(desc, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	# Word wrap manually if too wide
	if desc_size.x > CARD_WIDTH - 20:
		var words: PackedStringArray = desc.split(" ")
		var lines: Array[String] = [""]
		for word in words:
			var test: String = lines[-1] + (" " if lines[-1] != "" else "") + word
			if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > CARD_WIDTH - 20:
				lines.append(word)
			else:
				lines[-1] = test
		for li in range(lines.size()):
			var ls := font.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			_card_draw.draw_string(font, Vector2(cx - ls.x * 0.5, cy + 165.0 + li * 14.0), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.75, 0.85, card_a * 0.8))
	else:
		_card_draw.draw_string(font, Vector2(cx - desc_size.x * 0.5, cy + 165.0), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.75, 0.85, card_a * 0.8))

	# Stat bonuses
	var stat: Dictionary = m.get("stat", {})
	var stat_y: float = cy + 210.0
	for key in stat:
		var val: float = stat[key]
		var sign: String = "+" if val > 0 else ""
		var stat_str: String = "%s%s: %s%.0f%%" % [_stat_icon(key), _stat_label(key), sign, val * 100.0]
		var ss := font.get_string_size(stat_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
		_card_draw.draw_string(font, Vector2(cx - ss.x * 0.5, stat_y), stat_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 1.0, 0.6, card_a))
		stat_y += 16.0

	# Sensory upgrade badge
	if m.get("sensory_upgrade", false):
		var badge := "👁 SENSORY UPGRADE"
		var bs := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var badge_y: float = cy + CARD_HEIGHT - 25.0
		_card_draw.draw_rect(Rect2(cx - bs.x * 0.5 - 6, badge_y - 12, bs.x + 12, 16), Color(0.2, 0.1, 0.4, 0.6 * card_a))
		_card_draw.draw_string(font, Vector2(cx - bs.x * 0.5, badge_y), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.5, 1.0, card_a))

func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var angle: float = -PI / 2.0 + TAU * i / 10.0
		var r: float = radius if i % 2 == 0 else radius * 0.4
		pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	_card_draw.draw_colored_polygon(pts, color)

func _draw_mutation_preview(visual: String, center: Vector2, alpha: float, accent: Color) -> void:
	## Draw a small iconic preview of the mutation
	var c := Color(accent.r, accent.g, accent.b, alpha)
	var dim := Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, alpha * 0.5)

	match visual:
		"extra_cilia":
			for i in range(8):
				var a: float = TAU * i / 8.0 + sin(_time * 3.0) * 0.2
				var p1 := center + Vector2(cos(a), sin(a)) * 12.0
				var p2 := center + Vector2(cos(a), sin(a)) * 30.0 + Vector2(sin(_time * 4.0 + i) * 3.0, 0)
				_card_draw.draw_line(p1, p2, c, 1.5, true)
			_card_draw.draw_circle(center, 12.0, dim)
		"spikes":
			_card_draw.draw_circle(center, 14.0, dim)
			for i in range(10):
				var a: float = TAU * i / 10.0
				var base := center + Vector2(cos(a), sin(a)) * 14.0
				var tip := center + Vector2(cos(a), sin(a)) * 30.0
				_card_draw.draw_line(base, tip, c, 2.0, true)
		"armor_plates":
			_card_draw.draw_circle(center, 18.0, dim)
			for i in range(6):
				var a: float = TAU * i / 6.0 + 0.3
				var p := center + Vector2(cos(a), sin(a)) * 16.0
				_card_draw.draw_rect(Rect2(p.x - 5, p.y - 3, 10, 6), c)
		"color_shift":
			for i in range(3):
				var hue: float = fmod(_time * 0.3 + i * 0.33, 1.0)
				var col := Color.from_hsv(hue, 0.7, 0.9, alpha * 0.6)
				_card_draw.draw_circle(center + Vector2(cos(_time + i) * 6, sin(_time + i) * 6), 16.0 - i * 3, col)
		"bioluminescence":
			var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
			_card_draw.draw_circle(center, 22.0 * pulse, Color(c.r, c.g, c.b, alpha * 0.2))
			_card_draw.draw_circle(center, 14.0 * pulse, Color(c.r, c.g, c.b, alpha * 0.4))
			_card_draw.draw_circle(center, 6.0, Color(1.0, 1.0, 0.8, alpha))
		"flagellum":
			_card_draw.draw_circle(center + Vector2(0, -10), 10.0, dim)
			for i in range(12):
				var t: float = float(i) / 11.0
				var px: float = center.x + sin(_time * 5.0 + t * 4.0) * 8.0 * t
				var py: float = center.y + t * 35.0
				if i > 0:
					var prev_t: float = float(i - 1) / 11.0
					var ppx: float = center.x + sin(_time * 5.0 + prev_t * 4.0) * 8.0 * prev_t
					var ppy: float = center.y + prev_t * 35.0
					_card_draw.draw_line(Vector2(ppx, ppy), Vector2(px, py), c, 2.0 - t, true)
		"third_eye":
			_card_draw.draw_circle(center, 14.0, dim)
			_card_draw.draw_circle(center, 8.0, Color(1.0, 1.0, 1.0, alpha * 0.9))
			_card_draw.draw_circle(center, 4.0, Color(0.1, 0.1, 0.3, alpha))
			_card_draw.draw_circle(center + Vector2(1.5, -1), 1.5, Color(1, 1, 1, alpha))
		"eye_stalks":
			_card_draw.draw_circle(center, 10.0, dim)
			for side in [-1.0, 1.0]:
				var stalk_end := center + Vector2(side * 22.0, -18.0 + sin(_time * 2.0 + side) * 3.0)
				_card_draw.draw_line(center + Vector2(side * 6, -5), stalk_end, c, 2.0, true)
				_card_draw.draw_circle(stalk_end, 5.0, Color(1, 1, 1, alpha * 0.9))
				_card_draw.draw_circle(stalk_end, 2.5, Color(0.1, 0.1, 0.3, alpha))
		"tentacles":
			_card_draw.draw_circle(center + Vector2(0, -8), 10.0, dim)
			for i in range(4):
				var base_x: float = center.x + (i - 1.5) * 8.0
				for s in range(8):
					var t: float = float(s) / 7.0
					var px: float = base_x + sin(_time * 3.0 + i + t * 3.0) * 6.0 * t
					var py: float = center.y + 2.0 + t * 30.0
					if s > 0:
						var pt: float = float(s - 1) / 7.0
						var ppx: float = base_x + sin(_time * 3.0 + i + pt * 3.0) * 6.0 * pt
						var ppy: float = center.y + 2.0 + pt * 30.0
						_card_draw.draw_line(Vector2(ppx, ppy), Vector2(px, py), c, 2.0 - t * 1.2, true)
		"larger_membrane":
			_card_draw.draw_circle(center, 24.0, Color(c.r, c.g, c.b, alpha * 0.15))
			_card_draw.draw_arc(center, 24.0, 0, TAU, 24, c, 1.5, true)
			_card_draw.draw_circle(center, 14.0, dim)
		"toxin_glands":
			_card_draw.draw_circle(center, 12.0, dim)
			for i in range(4):
				var a: float = TAU * i / 4.0 + _time * 0.5
				var gp := center + Vector2(cos(a), sin(a)) * 18.0
				var pulse: float = 0.7 + 0.3 * sin(_time * 4.0 + i * 1.5)
				_card_draw.draw_circle(gp, 5.0 * pulse, Color(0.6, 0.9, 0.1, alpha * 0.7))
		"photoreceptor":
			_card_draw.draw_circle(center, 14.0, dim)
			for i in range(3):
				var a: float = -PI * 0.4 + PI * 0.4 * i
				var ep := center + Vector2(cos(a), sin(a)) * 10.0
				_card_draw.draw_circle(ep, 4.0, Color(0.8, 0.9, 1.0, alpha * (0.5 + 0.3 * sin(_time * 3.0 + i))))
				_card_draw.draw_circle(ep, 2.0, Color(0.1, 0.2, 0.4, alpha))
		"thick_membrane":
			_card_draw.draw_arc(center, 20.0, 0, TAU, 24, Color(c.r, c.g, c.b, alpha * 0.5), 4.0, true)
			_card_draw.draw_arc(center, 16.0, 0, TAU, 24, c, 2.0, true)
			_card_draw.draw_circle(center, 12.0, dim)
		"enzyme_boost":
			_card_draw.draw_circle(center, 14.0, dim)
			for i in range(5):
				var a: float = TAU * i / 5.0 + _time * 2.0
				var r: float = 6.0 + 3.0 * sin(_time * 5.0 + i)
				var ep := center + Vector2(cos(a), sin(a)) * r
				_card_draw.draw_circle(ep, 2.5, Color(1.0, 0.8, 0.2, alpha * 0.8))
		"regeneration":
			_card_draw.draw_circle(center, 14.0, dim)
			var pulse: float = 0.3 + 0.3 * sin(_time * 2.5)
			_card_draw.draw_circle(center, 20.0, Color(0.2, 0.9, 0.3, alpha * pulse))
			# Plus sign
			_card_draw.draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), Color(0.3, 1.0, 0.4, alpha), 2.5)
			_card_draw.draw_line(center + Vector2(0, -6), center + Vector2(0, 6), Color(0.3, 1.0, 0.4, alpha), 2.5)
		"sprint_boost":
			_card_draw.draw_circle(center, 10.0, dim)
			for i in range(3):
				var off: float = float(i) * 10.0
				_card_draw.draw_line(center + Vector2(-20 - off, -3 + i * 3), center + Vector2(-8 - off, -3 + i * 3), Color(c.r, c.g, c.b, alpha * (0.8 - i * 0.2)), 1.5, true)
		"compound_eye":
			for row in range(3):
				for col in range(3):
					var ep := center + Vector2((col - 1) * 10.0, (row - 1) * 10.0)
					_card_draw.draw_circle(ep, 5.0, Color(0.9, 0.9, 1.0, alpha * 0.7))
					_card_draw.draw_circle(ep, 2.5, Color(0.1, 0.1, 0.3, alpha))
		"absorption_villi":
			_card_draw.draw_circle(center, 14.0, dim)
			for i in range(12):
				var a: float = TAU * i / 12.0
				var base := center + Vector2(cos(a), sin(a)) * 14.0
				var tip := center + Vector2(cos(a), sin(a)) * (22.0 + sin(_time * 3.0 + i) * 3.0)
				_card_draw.draw_line(base, tip, c, 1.2, true)
				_card_draw.draw_circle(tip, 1.5, c)
		"dorsal_fin":
			_card_draw.draw_circle(center, 12.0, dim)
			var fin_pts: PackedVector2Array = PackedVector2Array([center + Vector2(6, -10), center + Vector2(-4, -24), center + Vector2(-10, -10)])
			_card_draw.draw_colored_polygon(fin_pts, Color(c.r, c.g, c.b, alpha * 0.6))
		"ink_sac":
			_card_draw.draw_circle(center, 14.0, dim)
			_card_draw.draw_circle(center, 8.0, Color(0.1, 0.05, 0.2, alpha * 0.7))
			_card_draw.draw_circle(center + Vector2(3, 2), 4.0, Color(0.15, 0.1, 0.25, alpha * 0.5))
		"electric_organ":
			_card_draw.draw_circle(center, 14.0, dim)
			for i in range(4):
				var ea: float = TAU * i / 4.0 + _time * 3.0
				var p1 := center + Vector2(cos(ea), sin(ea)) * 14.0
				var jit := Vector2(sin(_time * 15.0 + i * 5) * 5, cos(_time * 12.0 + i * 3) * 5)
				_card_draw.draw_line(p1, p1 + Vector2(cos(ea), sin(ea)) * 10.0 + jit, Color(0.5, 0.8, 1.0, alpha * 0.7), 1.5, true)
		"symbiont_pouch":
			_card_draw.draw_circle(center, 14.0, dim)
			for i in range(5):
				var ea: float = _time * 1.5 + TAU * i / 5.0
				var p := center + Vector2(cos(ea), sin(ea)) * 9.0
				_card_draw.draw_circle(p, 2.5, Color(0.3, 0.9, 0.5, alpha * 0.6))
		"hardened_nucleus":
			_card_draw.draw_circle(center, 14.0, dim)
			_card_draw.draw_circle(center, 7.0, Color(0.5, 0.4, 0.7, alpha * 0.5))
			for i in range(6):
				var a1: float = TAU * i / 6.0
				var a2: float = TAU * (i + 1) / 6.0
				_card_draw.draw_line(center + Vector2(cos(a1), sin(a1)) * 7.0, center + Vector2(cos(a2), sin(a2)) * 7.0, c, 1.5, true)
		"pili_network":
			_card_draw.draw_circle(center, 12.0, dim)
			for i in range(16):
				var ea: float = TAU * i / 16.0
				var b := center + Vector2(cos(ea), sin(ea)) * 12.0
				var t := b + Vector2(cos(ea), sin(ea)) * 8.0
				_card_draw.draw_line(b, t, Color(c.r, c.g, c.b, alpha * 0.4), 0.8, true)
		"chrono_enzyme":
			_card_draw.draw_circle(center, 14.0, dim)
			for i in range(6):
				var ea: float = _time * 4.0 + TAU * i / 6.0
				var r: float = 8.0 + sin(_time * 6.0 + i) * 2.0
				_card_draw.draw_circle(center + Vector2(cos(ea), sin(ea)) * r, 2.0, Color(1.0, 0.6, 0.2, alpha * 0.6))
		"thermal_vent_organ":
			_card_draw.draw_circle(center, 14.0, dim)
			for i in range(3):
				var ea: float = TAU * i / 3.0 + 0.5
				var p := center + Vector2(cos(ea), sin(ea)) * 9.0
				_card_draw.draw_circle(p, 4.0, Color(0.9, 0.4, 0.1, alpha * 0.4))
		"lateral_line":
			_card_draw.draw_circle(center, 14.0, dim)
			for i in range(7):
				var px: float = center.x - 12.0 + i * 4.0
				_card_draw.draw_circle(Vector2(px, center.y), 1.5, Color(0.5, 0.7, 1.0, alpha * 0.6))
		"beak":
			_card_draw.draw_circle(center + Vector2(-4, 0), 12.0, dim)
			var bk: PackedVector2Array = PackedVector2Array([center + Vector2(8, -4), center + Vector2(20, 0), center + Vector2(8, 4)])
			_card_draw.draw_colored_polygon(bk, Color(0.7, 0.5, 0.2, alpha * 0.8))
		"gas_vacuole":
			_card_draw.draw_circle(center, 14.0, dim)
			_card_draw.draw_circle(center, 8.0, Color(0.7, 0.85, 1.0, alpha * 0.15))
			_card_draw.draw_arc(center, 8.0, 0, TAU, 12, Color(0.7, 0.9, 1.0, alpha * 0.3), 1.0, true)
		# Directional mutations
		"front_spike":
			_card_draw.draw_circle(center + Vector2(-6, 0), 12.0, dim)
			var spike_pts: PackedVector2Array = PackedVector2Array([center + Vector2(6, -5), center + Vector2(25, 0), center + Vector2(6, 5)])
			_card_draw.draw_colored_polygon(spike_pts, Color(0.85, 0.7, 0.4, alpha * 0.9))
			_card_draw.draw_line(spike_pts[0], spike_pts[1], c, 1.5, true)
			_card_draw.draw_line(spike_pts[2], spike_pts[1], c, 1.5, true)
		"mandibles":
			_card_draw.draw_circle(center, 10.0, dim)
			for side in [-1.0, 1.0]:
				var open: float = 0.3 + sin(_time * 3.0) * 0.2
				_card_draw.draw_line(center + Vector2(8, side * 4), center + Vector2(18, side * (6 + open * 8)), c, 2.0, true)
				_card_draw.draw_line(center + Vector2(18, side * (6 + open * 8)), center + Vector2(22, side * (3 + open * 4)), c, 1.5, true)
		"side_barbs":
			_card_draw.draw_circle(center, 12.0, dim)
			for side in [-1.0, 1.0]:
				for i in range(3):
					var x: float = -8.0 + i * 8.0
					_card_draw.draw_line(center + Vector2(x, side * 12), center + Vector2(x, side * 20), Color(0.9, 0.4, 0.3, alpha * 0.8), 1.5, true)
		"rear_stinger":
			_card_draw.draw_circle(center + Vector2(6, 0), 10.0, dim)
			var prev := center + Vector2(-4, 0)
			for i in range(4):
				var t: float = float(i + 1) / 4.0
				var cur := center + Vector2(-4 - t * 18, sin(_time * 3.0 + t * 2) * 5 * t)
				_card_draw.draw_line(prev, cur, Color(0.3, 0.8, 0.2, alpha * 0.9), 2.5 - t, true)
				prev = cur
			_card_draw.draw_circle(prev, 2.5, Color(0.2, 0.9, 0.3, alpha * 0.7))
		"ramming_crest":
			_card_draw.draw_circle(center + Vector2(-4, 0), 10.0, dim)
			var crest_pts: PackedVector2Array = PackedVector2Array([center + Vector2(6, -8), center + Vector2(16, -4), center + Vector2(18, 0), center + Vector2(16, 4), center + Vector2(6, 8)])
			_card_draw.draw_polyline(crest_pts, Color(0.5, 0.55, 0.6, alpha * 0.8), 3.0, true)
		"proboscis":
			_card_draw.draw_circle(center + Vector2(-6, 0), 10.0, dim)
			var pv := center + Vector2(4, 0)
			for i in range(5):
				var t: float = float(i + 1) / 5.0
				var nc := center + Vector2(4 + t * 22, sin(_time * 4 + t * 3) * 2 * t)
				_card_draw.draw_line(pv, nc, Color(0.8, 0.5, 0.6, alpha * 0.8), 2.0 - t, true)
				pv = nc
		"tail_club":
			_card_draw.draw_circle(center + Vector2(6, 0), 10.0, dim)
			_card_draw.draw_line(center + Vector2(-4, 0), center + Vector2(-14, sin(_time * 2) * 3), c, 2.5, true)
			_card_draw.draw_circle(center + Vector2(-17, sin(_time * 2) * 3), 6.0, Color(0.55, 0.45, 0.35, alpha * 0.85))
		"electroreceptors":
			_card_draw.draw_circle(center, 12.0, dim)
			for i in range(5):
				var ea: float = TAU * i / 5.0 + _time * 0.3
				var ep := center + Vector2(cos(ea) * 10, sin(ea) * 10)
				var pulse: float = 0.4 + 0.3 * sin(_time * 5 + i)
				_card_draw.draw_circle(ep, 2.5, Color(0.4, 0.7, 1.0, alpha * pulse))
		"antenna":
			_card_draw.draw_circle(center + Vector2(-4, 0), 10.0, dim)
			for side in [-1.0, 1.0]:
				var ap := center + Vector2(6, side * 3)
				for i in range(4):
					var t: float = float(i + 1) / 4.0
					var np := center + Vector2(6 + t * 20, side * 3 + sin(_time * 5 + t * 3) * 4 * t)
					_card_draw.draw_line(ap, np, Color(0.6, 0.7, 0.5, alpha * 0.7), 1.5 - t * 0.8, true)
					ap = np
				_card_draw.draw_circle(ap, 1.5, Color(0.5, 0.9, 0.6, alpha * 0.6))
		_:
			_card_draw.draw_circle(center, 16.0, c)

func _stat_icon(key: String) -> String:
	match key:
		"speed": return "⚡"
		"attack": return "⚔"
		"max_health": return "❤"
		"armor": return "🛡"
		"stealth": return "👻"
		"detection": return "🔍"
		"beam_range": return "🎯"
		"energy_efficiency": return "⚗"
		"health_regen": return "💚"
	return ""

func _stat_label(key: String) -> String:
	match key:
		"speed": return "Speed"
		"attack": return "Attack"
		"max_health": return "Health"
		"armor": return "Armor"
		"stealth": return "Stealth"
		"detection": return "Detection"
		"beam_range": return "Beam Range"
		"energy_efficiency": return "Efficiency"
		"health_regen": return "Regen"
	return key.capitalize()

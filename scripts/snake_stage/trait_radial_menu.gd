extends Control
## Radial menu for selecting boss traits. Hold Q to open, release to select.
## Draws a circular menu with trait icons, highlights on hover.

var _active: bool = false
var _appear_t: float = 0.0
var _selected_index: int = -1
var _time: float = 0.0

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false

func _process(delta: float) -> void:
	_time += delta
	if Input.is_key_pressed(KEY_Q) and not get_tree().paused:
		if not _active and GameManager.unlocked_traits.size() > 0:
			_open()
	elif _active:
		_close_and_select()

	if _active:
		_appear_t = minf(_appear_t + delta * 6.0, 1.0)
		_update_selection()
		queue_redraw()

func _open() -> void:
	_active = true
	_appear_t = 0.0
	_selected_index = -1
	visible = true
	mouse_filter = MOUSE_FILTER_STOP
	# Slow down time while selecting
	Engine.time_scale = 0.2

func _close_and_select() -> void:
	_active = false
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	Engine.time_scale = 1.0
	# Equip selected trait
	if _selected_index >= 0 and _selected_index < GameManager.unlocked_traits.size():
		GameManager.equip_trait(GameManager.unlocked_traits[_selected_index])
		if AudioManager.has_method("play_ui_confirm"):
			AudioManager.play_ui_confirm()

func _update_selection() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var center: Vector2 = vp * 0.5
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var offset: Vector2 = mouse - center
	if offset.length() < 30.0:
		_selected_index = -1
		return
	var angle: float = atan2(offset.y, offset.x)
	if angle < 0:
		angle += TAU
	var count: int = GameManager.unlocked_traits.size()
	if count == 0:
		return
	var segment: float = TAU / count
	_selected_index = int(angle / segment) % count

func _draw() -> void:
	if not _active:
		return
	var vp: Vector2 = get_viewport_rect().size
	var center: Vector2 = vp * 0.5
	var traits: Array = GameManager.unlocked_traits
	var count: int = traits.size()
	if count == 0:
		return

	var ease_t: float = _appear_t * _appear_t * (3.0 - 2.0 * _appear_t)
	var ring_radius: float = 100.0 * ease_t
	var segment_angle: float = TAU / count

	# Dim background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.4 * ease_t))

	# Draw each trait sector
	for i in range(count):
		var angle: float = segment_angle * i - PI * 0.5
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * ring_radius
		var trait_id: String = traits[i]
		var data: Dictionary = BossTraitSystem.get_trait(trait_id)
		var col: Color = data.get("icon_color", Color.WHITE)
		var is_selected: bool = i == _selected_index
		var is_equipped: bool = trait_id == GameManager.equipped_trait

		# Background circle
		var bg_alpha: float = 0.7 if is_selected else 0.3
		var bg_radius: float = 38.0 if is_selected else 30.0
		draw_circle(pos, bg_radius, Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, bg_alpha * ease_t))
		# Border
		var border_col: Color = col if is_selected else col * 0.5
		border_col.a = ease_t
		_draw_circle_outline(pos, bg_radius, border_col, 2.0 if is_selected else 1.0)

		# Trait icon (simple shape)
		var icon_col: Color = col
		icon_col.a = ease_t
		_draw_trait_icon(pos, trait_id, icon_col, bg_radius * 0.5)

		# Trait name label
		var name_str: String = data.get("name", trait_id)
		var label_pos: Vector2 = pos + Vector2(-30, bg_radius + 8)
		var font: Font = UIConstants.get_display_font()
		var font_size: int = 11 if is_selected else 9
		var text_col: Color = Color.WHITE if is_selected else Color(0.7, 0.7, 0.7)
		text_col.a = ease_t
		draw_string(font, label_pos, name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

		# Equipped indicator
		if is_equipped:
			draw_circle(pos + Vector2(bg_radius - 5, -bg_radius + 5), 4.0, Color(1, 1, 1, ease_t))

		# Tier pips
		var tier: int = GameManager.get_trait_tier(trait_id)
		for t in range(tier):
			var pip_pos: Vector2 = pos + Vector2(-8 + t * 8, bg_radius + 22)
			draw_circle(pip_pos, 3.0, Color(col.r, col.g, col.b, ease_t * 0.8))

	# Center text
	var font: Font = UIConstants.get_display_font()
	var center_text: String = "TRAITS" if _selected_index < 0 else ""
	draw_string(font, center - Vector2(20, -4), center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.8, 0.7, ease_t * 0.6))

func _draw_circle_outline(center: Vector2, radius: float, col: Color, width: float = 1.0) -> void:
	var segments: int = 32
	for i in range(segments):
		var a0: float = TAU * i / segments
		var a1: float = TAU * (i + 1) / segments
		draw_line(
			center + Vector2(cos(a0), sin(a0)) * radius,
			center + Vector2(cos(a1), sin(a1)) * radius,
			col, width
		)

func _draw_trait_icon(center: Vector2, trait_id: String, col: Color, size: float) -> void:
	match trait_id:
		"pulse_wave":
			# Concentric rings
			for r in range(3):
				_draw_circle_outline(center, size * (0.3 + r * 0.25), col, 1.5)
		"acid_spit":
			# Droplet shape
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(12):
				var a: float = TAU * i / 12.0
				var r: float = size * (0.6 + sin(a * 2) * 0.2)
				pts.append(center + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, col)
		"wind_gust":
			# Three curved lines
			for i in range(3):
				var y_off: float = (i - 1) * size * 0.35
				draw_line(center + Vector2(-size * 0.5, y_off), center + Vector2(size * 0.5, y_off - size * 0.1), col, 2.0)
		"bone_shield":
			# Hexagonal shield
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var a: float = TAU * i / 6.0 - PI * 0.5
				pts.append(center + Vector2(cos(a), sin(a)) * size * 0.7)
			draw_colored_polygon(pts, col)
		"summon_minions":
			# Three small circles
			for i in range(3):
				var a: float = TAU * i / 3.0 - PI * 0.5
				draw_circle(center + Vector2(cos(a), sin(a)) * size * 0.4, size * 0.2, col)

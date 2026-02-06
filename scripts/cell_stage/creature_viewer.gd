extends Control
## Creature Viewer — Blueprint-style display of recently encountered creatures.
## Shows procedural breakdown with alien annotations when player interacts with organisms.

const VIEWER_WIDTH: float = 320.0
const VIEWER_HEIGHT: float = 400.0
const DISPLAY_DURATION: float = 8.0
const FADE_DURATION: float = 2.0

# Alien glyphs for labels
const ALIEN_GLYPHS: Array = [
	"◊", "∆", "Ω", "Σ", "Φ", "Ψ", "λ", "π", "θ", "ξ",
	"╬", "╫", "╪", "┼", "╋", "╂", "╁", "╀", "┿", "┾",
	"⊕", "⊗", "⊙", "⊚", "⊛", "⊜", "⊝", "⊞", "⊟", "⊠",
]

# Creature type display names
const CREATURE_NAMES: Dictionary = {
	"enemy": "HOSTILE CELL",
	"competitor": "RIVAL ORGANISM",
	"prey": "PREY SPECIMEN",
	"parasite": "PARASITIC WORM",
	"virus": "VIRAL AGENT",
	"hazard_jellyfish": "CNIDARIAN HAZARD",
	"hazard_spike": "SPINE CLUSTER",
	"hazard_toxic": "TOXIC MASS",
	"dart_predator": "APEX HUNTER",
	"leviathan": "LEVIATHAN",
	"food": "BIOMOLECULE",
}

# Current specimen being displayed
var _current_specimen: Dictionary = {}
var _display_timer: float = 0.0
var _is_displaying: bool = false
var _scan_y: float = 0.0
var _time: float = 0.0
var _glitch_timer: float = 0.0

# Blueprint callout lines
var _callouts: Array = []

# Trigger cooldown to avoid spam
var _trigger_cooldown: float = 0.0
const TRIGGER_COOLDOWN: float = 3.0

func _ready() -> void:
	# Wait a frame for scene to be fully ready before connecting signals
	await get_tree().process_frame
	_connect_signals()

func _connect_signals() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node = players[0]
		if player.has_signal("damaged"):
			player.damaged.connect(_on_player_damaged)
		if player.has_signal("prey_killed"):
			player.prey_killed.connect(_on_prey_killed)
		if player.has_signal("parasites_changed"):
			player.parasites_changed.connect(_on_parasites_changed)
		if player.has_signal("died"):
			player.died.connect(_on_player_died)
		if player.has_signal("food_consumed"):
			player.food_consumed.connect(_on_food_consumed)

	# Connect to evolution events
	if GameManager.has_signal("evolution_applied"):
		GameManager.evolution_applied.connect(_on_evolution_applied)

func _on_player_damaged(amount: float) -> void:
	if amount < 5.0:
		return

	# Observer gasps when player takes significant damage
	if amount > 15.0 and randf() < 0.4:  # 40% chance for big hits
		AudioManager.play_observer_gasp()

	# Try to find what damaged us - check nearby enemies/hazards
	var player := _get_player()
	if not player:
		return

	# Check for nearby threats
	for group in ["enemies", "hazards", "viruses"]:
		var nodes := get_tree().get_nodes_in_group(group)
		for node in nodes:
			if node.global_position.distance_to(player.global_position) < 100.0:
				_capture_specimen(node, group)
				return

func _on_prey_killed() -> void:
	# Observer sometimes laughs when player kills prey (finding it amusing)
	if randf() < 0.25:  # 25% chance
		AudioManager.play_observer_laugh()

	# Find recently killed prey (might be gone, so check nearby)
	var player := _get_player()
	if not player:
		return

	# Capture generic prey data since the actual prey might be freed
	_capture_generic_specimen("prey")

func _on_parasites_changed(count: int) -> void:
	if count > 0:
		# A parasite just attached
		var player := _get_player()
		if not player or not "attached_parasites" in player:
			return
		if player.attached_parasites.size() > 0:
			var parasite = player.attached_parasites[0]
			if is_instance_valid(parasite):
				_capture_specimen(parasite, "parasites")

func _on_player_died() -> void:
	# Observer is distressed when specimen dies
	if randf() < 0.8:  # 80% chance
		AudioManager.play_observer_distressed()

func _on_food_consumed() -> void:
	# Occasionally react to feeding
	if randf() < 0.1:  # 10% chance
		AudioManager.play_observer_hmm()

func _on_evolution_applied(_mutation: Dictionary) -> void:
	# Observer is impressed by evolution
	if randf() < 0.6:  # 60% chance
		AudioManager.play_observer_impressed()

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _capture_specimen(node: Node2D, group: String) -> void:
	if _trigger_cooldown > 0:
		return
	_trigger_cooldown = TRIGGER_COOLDOWN

	var specimen: Dictionary = {
		"type": _get_creature_type(node, group),
		"color": _extract_color(node),
		"size": _extract_size(node),
		"features": _extract_features(node, group),
		"threat_level": _get_threat_level(group),
	}

	_show_specimen(specimen)

func _capture_generic_specimen(type: String) -> void:
	if _trigger_cooldown > 0:
		return
	_trigger_cooldown = TRIGGER_COOLDOWN

	var specimen: Dictionary = {
		"type": type,
		"color": _get_default_color(type),
		"size": 1.0,
		"features": _get_default_features(type),
		"threat_level": _get_threat_level(type),
	}

	_show_specimen(specimen)

func _get_creature_type(node: Node2D, group: String) -> String:
	# Try to get specific type
	if "hazard_type" in node:
		match node.hazard_type:
			0: return "hazard_jellyfish"
			1: return "hazard_spike"
			2: return "hazard_toxic"
	if node.is_in_group("viruses"):
		return "virus"
	if node.is_in_group("parasites"):
		return "parasite"
	if node.is_in_group("enemies"):
		if "dart_predator" in node.name.to_lower():
			return "dart_predator"
		if "leviathan" in node.name.to_lower():
			return "leviathan"
		return "enemy"
	if node.is_in_group("competitors"):
		return "competitor"
	if node.is_in_group("prey"):
		return "prey"
	return group.trim_suffix("s")  # Remove trailing 's' from group name

func _extract_color(node: Node2D) -> Color:
	if "_base_color" in node:
		return node._base_color
	if "_color" in node:
		return node._color
	return Color(0.5, 0.7, 0.9)

func _extract_size(node: Node2D) -> float:
	if "_cell_radius" in node:
		return node._cell_radius / 15.0  # Normalize
	return 1.0

func _extract_features(node: Node2D, group: String) -> Array:
	var features: Array = []

	# Core body
	features.append({"type": "membrane", "pos": Vector2.ZERO, "size": 50.0})

	# Add type-specific features
	match group:
		"enemies":
			features.append({"type": "nucleus", "pos": Vector2(0, 0), "size": 15.0})
			features.append({"type": "eye", "pos": Vector2(15, -10), "size": 8.0})
			features.append({"type": "eye", "pos": Vector2(15, 10), "size": 8.0})
			features.append({"type": "flagellum", "pos": Vector2(-40, 0), "size": 30.0})
		"hazards":
			features.append({"type": "core", "pos": Vector2(0, 0), "size": 20.0})
			if "hazard_type" in node and node.hazard_type == 0:
				for i in range(4):
					var a: float = PI * 0.5 + i * 0.3
					features.append({"type": "tentacle", "pos": Vector2(cos(a) * 30, sin(a) * 30), "size": 25.0, "angle": a})
			elif "hazard_type" in node and node.hazard_type == 1:
				for i in range(8):
					var a: float = TAU * i / 8.0
					features.append({"type": "spike", "pos": Vector2(cos(a) * 35, sin(a) * 35), "size": 20.0, "angle": a})
		"viruses":
			features.append({"type": "capsid", "pos": Vector2(0, 0), "size": 25.0})
			for i in range(12):
				var a: float = TAU * i / 12.0
				features.append({"type": "spike", "pos": Vector2(cos(a) * 25, sin(a) * 25), "size": 10.0, "angle": a})
		"parasites":
			features.append({"type": "head", "pos": Vector2(20, 0), "size": 12.0})
			for i in range(5):
				features.append({"type": "segment", "pos": Vector2(-i * 10, sin(i * 0.5) * 5), "size": 10.0 - i})
		"prey":
			features.append({"type": "head", "pos": Vector2(30, 0), "size": 10.0})
			for i in range(6):
				features.append({"type": "segment", "pos": Vector2(20 - i * 12, 0), "size": 8.0})
		"competitors":
			features.append({"type": "nucleus", "pos": Vector2(0, 0), "size": 12.0})
			features.append({"type": "eye", "pos": Vector2(10, -8), "size": 6.0})
			features.append({"type": "eye", "pos": Vector2(10, 8), "size": 6.0})

	# Add alien labels to features
	for f in features:
		f["label"] = _make_alien_label()

	return features

func _get_default_features(type: String) -> Array:
	var features: Array = []
	features.append({"type": "membrane", "pos": Vector2.ZERO, "size": 50.0, "label": _make_alien_label()})

	match type:
		"prey":
			features.append({"type": "head", "pos": Vector2(30, 0), "size": 10.0, "label": _make_alien_label()})
			for i in range(5):
				features.append({"type": "segment", "pos": Vector2(20 - i * 12, 0), "size": 8.0, "label": _make_alien_label()})
		_:
			features.append({"type": "nucleus", "pos": Vector2(0, 0), "size": 15.0, "label": _make_alien_label()})

	return features

func _get_default_color(type: String) -> Color:
	match type:
		"prey": return Color(0.4, 0.9, 0.5)
		"enemy": return Color(0.9, 0.3, 0.3)
		"competitor": return Color(0.7, 0.8, 0.3)
		"virus": return Color(0.8, 0.2, 0.4)
		"parasite": return Color(0.6, 0.4, 0.5)
		_: return Color(0.5, 0.7, 0.9)

func _get_threat_level(group: String) -> int:
	match group:
		"enemies": return 3
		"hazards": return 2
		"viruses": return 4
		"parasites": return 3
		"prey": return 0
		"competitors": return 1
		_: return 1

func _show_specimen(specimen: Dictionary) -> void:
	_current_specimen = specimen
	_display_timer = 0.0
	_is_displaying = true
	_scan_y = 0.0
	_glitch_timer = 0.3
	_generate_callouts()

	# Trigger observer audio reaction
	if AudioManager.has_method("play_observer_hmm"):
		AudioManager.play_observer_hmm()

	# Notify observer notes to add a contextual note
	_notify_observer_notes()

func _generate_callouts() -> void:
	_callouts.clear()
	var features: Array = _current_specimen.get("features", [])

	for i in range(mini(features.size(), 6)):  # Limit callouts
		var f: Dictionary = features[i]
		var callout_dir: Vector2 = f.pos.normalized()
		if callout_dir.length() < 0.1:
			callout_dir = Vector2(1, -0.5).normalized()

		# Alternate sides for readability
		if i % 2 == 1:
			callout_dir.x = -absf(callout_dir.x)

		var callout_end: Vector2 = f.pos + callout_dir * 70.0
		_callouts.append({
			"start": f.pos,
			"end": callout_end,
			"label": f.get("label", _make_alien_label()),
			"alpha": 0.0,
			"delay": i * 0.3,
		})

func _notify_observer_notes() -> void:
	# Find observer notes and trigger a contextual note
	var notes_nodes := get_tree().get_nodes_in_group("observer_notes")
	if notes_nodes.size() > 0 and notes_nodes[0].has_method("_queue_note"):
		notes_nodes[0]._queue_note()

func _make_alien_label() -> String:
	var label: String = ""
	for i in range(randi_range(3, 6)):
		label += ALIEN_GLYPHS[randi() % ALIEN_GLYPHS.size()]
	return label

func _process(delta: float) -> void:
	_time += delta
	_trigger_cooldown = maxf(_trigger_cooldown - delta, 0.0)

	if _glitch_timer > 0:
		_glitch_timer -= delta

	if _is_displaying:
		_display_timer += delta
		_scan_y = fmod(_scan_y + delta * 60.0, VIEWER_HEIGHT * 0.6)

		# Update callout alphas
		for c in _callouts:
			if _display_timer > c.delay:
				c.alpha = minf(c.alpha + delta * 2.0, 1.0)

		# Start fading after display duration
		if _display_timer > DISPLAY_DURATION + FADE_DURATION:
			_is_displaying = false
			_current_specimen = {}

		queue_redraw()

func _draw() -> void:
	if not _is_displaying:
		_draw_idle_state()
		return

	var fade_alpha: float = 1.0
	if _display_timer > DISPLAY_DURATION:
		fade_alpha = 1.0 - ((_display_timer - DISPLAY_DURATION) / FADE_DURATION)

	_draw_specimen(fade_alpha)

func _draw_idle_state() -> void:
	var font := ThemeDB.fallback_font

	# Subtle waiting indicator
	var pulse: float = 0.3 + 0.2 * sin(_time * 2.0)
	draw_string(font, Vector2(15, 30), _make_alien_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 0.4, 0.5, pulse))
	draw_string(font, Vector2(15, 48), "SPECIMEN ANALYSIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.5, 0.6, 0.4))
	draw_string(font, Vector2(15, 65), "AWAITING DATA...", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.5, 0.6, pulse))

	# Scan line (slower when idle)
	var idle_scan: float = fmod(_time * 20.0, VIEWER_HEIGHT * 0.5)
	draw_line(Vector2(20, 80 + idle_scan), Vector2(VIEWER_WIDTH - 20, 80 + idle_scan), Color(0.2, 0.4, 0.5, 0.15), 1.0)

func _draw_specimen(fade_alpha: float) -> void:
	var font := ThemeDB.fallback_font
	var cx: float = VIEWER_WIDTH * 0.5
	var cy: float = VIEWER_HEIGHT * 0.45

	# Header
	var type_name: String = CREATURE_NAMES.get(_current_specimen.get("type", ""), "UNKNOWN ORGANISM")
	var header_flash: float = 0.8 + 0.2 * sin(_time * 4.0)

	draw_string(font, Vector2(15, 25), _make_alien_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.3, 0.5, 0.6, 0.5 * fade_alpha))
	draw_string(font, Vector2(15, 42), "SPECIMEN ANALYSIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.7, 0.9, 0.8 * fade_alpha))
	draw_string(font, Vector2(15, 60), type_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.7, 0.3, header_flash * fade_alpha))

	# Threat level indicator
	var threat: int = _current_specimen.get("threat_level", 1)
	var threat_color: Color
	match threat:
		0: threat_color = Color(0.3, 0.8, 0.4)
		1: threat_color = Color(0.7, 0.7, 0.3)
		2: threat_color = Color(0.9, 0.6, 0.2)
		3: threat_color = Color(0.9, 0.3, 0.2)
		_: threat_color = Color(1.0, 0.2, 0.3)

	draw_string(font, Vector2(VIEWER_WIDTH - 80, 60), "THREAT:", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.5, fade_alpha))
	for i in range(5):
		var pip_alpha: float = 1.0 if i < threat else 0.2
		draw_rect(Rect2(VIEWER_WIDTH - 80 + i * 12, 65, 8, 8), Color(threat_color.r, threat_color.g, threat_color.b, pip_alpha * fade_alpha))

	# Blueprint grid
	var grid_color := Color(0.15, 0.3, 0.4, 0.15 * fade_alpha)
	for i in range(int(VIEWER_HEIGHT / 20)):
		var gy: float = 80 + i * 20
		draw_line(Vector2(10, gy), Vector2(VIEWER_WIDTH - 10, gy), grid_color, 0.5)
	for i in range(int(VIEWER_WIDTH / 20)):
		var gx: float = 10 + i * 20
		draw_line(Vector2(gx, 80), Vector2(gx, VIEWER_HEIGHT - 40), grid_color, 0.5)

	# Tech frame
	_draw_tech_frame(Rect2(15, 75, VIEWER_WIDTH - 30, VIEWER_HEIGHT - 120), Color(0.2, 0.5, 0.7, 0.4 * fade_alpha))

	# Creature display
	var base_color: Color = _current_specimen.get("color", Color(0.5, 0.7, 0.9))
	var holo_color := Color(base_color.r * 0.7 + 0.3, base_color.g * 0.7 + 0.3, base_color.b * 0.7 + 0.3, 0.8 * fade_alpha)
	var glow_color := Color(holo_color.r, holo_color.g, holo_color.b, 0.2 * fade_alpha)

	# Draw features
	var features: Array = _current_specimen.get("features", [])
	for f in features:
		var fpos: Vector2 = Vector2(cx, cy) + f.pos
		var fsize: float = f.size

		match f.type:
			"membrane":
				# Outer membrane circle
				draw_arc(fpos, fsize, 0, TAU, 32, holo_color, 1.5)
				draw_arc(fpos, fsize, 0, TAU, 32, glow_color, 4.0)
			"nucleus", "core", "capsid":
				draw_circle(fpos, fsize, Color(holo_color.r, holo_color.g, holo_color.b, 0.3 * fade_alpha))
				draw_arc(fpos, fsize, 0, TAU, 16, holo_color, 1.2)
			"eye":
				draw_circle(fpos, fsize, Color(0.9, 0.9, 0.8, 0.6 * fade_alpha))
				draw_circle(fpos, fsize * 0.4, Color(0.1, 0.1, 0.1, 0.8 * fade_alpha))
			"spike":
				var angle: float = f.get("angle", 0)
				var tip: Vector2 = fpos + Vector2(cos(angle), sin(angle)) * fsize
				draw_line(fpos, tip, Color(0.9, 0.4, 0.3, 0.7 * fade_alpha), 2.0, true)
			"tentacle":
				var angle: float = f.get("angle", PI * 0.5)
				var base: Vector2 = fpos
				for i in range(5):
					var wave: float = sin(_time * 3.0 + i * 0.7) * 5.0
					var dir := Vector2(cos(angle), sin(angle))
					var next: Vector2 = base + dir * 8.0 + Vector2(-sin(angle), cos(angle)) * wave
					draw_line(base, next, Color(holo_color.r, holo_color.g, holo_color.b, (0.6 - i * 0.1) * fade_alpha), 2.0 - i * 0.3, true)
					base = next
			"flagellum":
				var base: Vector2 = fpos
				for i in range(6):
					var wave: float = sin(_time * 4.0 + i * 0.5) * 6.0
					var next: Vector2 = base + Vector2(-6.0, wave)
					draw_line(base, next, Color(holo_color.r, holo_color.g, holo_color.b, (0.5 - i * 0.07) * fade_alpha), 1.5, true)
					base = next
			"head":
				draw_circle(fpos, fsize, Color(holo_color.r, holo_color.g, holo_color.b, 0.5 * fade_alpha))
				draw_arc(fpos, fsize, 0, TAU, 12, holo_color, 1.0)
			"segment":
				draw_circle(fpos, fsize, Color(holo_color.r, holo_color.g, holo_color.b, 0.3 * fade_alpha))
				draw_arc(fpos, fsize, 0, TAU, 10, Color(holo_color.r, holo_color.g, holo_color.b, 0.5 * fade_alpha), 0.8)

	# Scan line
	var scan_alpha: float = 0.4 + 0.2 * sin(_time * 3.0)
	draw_line(Vector2(20, 85 + _scan_y), Vector2(VIEWER_WIDTH - 20, 85 + _scan_y), Color(0.3, 0.8, 1.0, scan_alpha * fade_alpha), 1.5)

	# Callout lines
	for c in _callouts:
		if c.alpha > 0:
			var start: Vector2 = c.start + Vector2(cx, cy)
			var end: Vector2 = c.end + Vector2(cx, cy)
			var line_color := Color(0.4, 0.7, 0.9, c.alpha * 0.7 * fade_alpha)

			draw_line(start, end, line_color, 1.0, true)
			draw_circle(end, 2.5, line_color)

			var label_offset := Vector2(8, 4) if end.x > cx else Vector2(-70, 4)
			draw_string(font, end + label_offset, c.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.5, 0.7, 0.9, c.alpha * 0.6 * fade_alpha))

	# Glitch effect
	if _glitch_timer > 0:
		for i in range(4):
			var gy: float = randf() * VIEWER_HEIGHT
			draw_rect(Rect2(10, gy, VIEWER_WIDTH - 20, 2), Color(0.4, 0.9, 1.0, _glitch_timer * fade_alpha))

	# Bottom status
	var status_y: float = VIEWER_HEIGHT - 25
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	draw_circle(Vector2(20, status_y), 4.0, Color(0.3, 0.8, 0.4, pulse * fade_alpha))
	draw_string(font, Vector2(30, status_y + 4), "ANALYZING...", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.6, 0.5, 0.7 * fade_alpha))

func _draw_tech_frame(rect: Rect2, color: Color) -> void:
	var corner_len: float = 12.0
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

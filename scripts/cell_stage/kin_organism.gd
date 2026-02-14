extends CharacterBody2D
## Same-species NPC organism. Copies player appearance (colors, mutations, shape)
## but with randomized eyes. Friendly social behavior: wanders, follows player,
## makes funny faces and shows alien speech bubbles when near others.

enum State { WANDER, FOLLOW, SOCIALIZE }

var state: State = State.WANDER
var speed: float = 80.0
var wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0

# Appearance (copied from player on spawn)
var _colors: Dictionary = {}  # membrane_color, iris_color, glow_color, interior_color, cilia_color, organelle_tint
var _mutations: Array = []  # Copy of GameManager.active_mutations
var _placements: Dictionary = {}  # Copy of GameManager.mutation_placements
var _elongation: float = 1.0
var _cell_radius: float = 18.0

# Randomized eyes (unique per NPC)
var _eye_style: String = "anime"
var _eye_angle: float = 0.0
var _eye_spacing: float = 5.5
var _eye_size: float = 3.5
var _iris_color: Color = Color(0.2, 0.5, 0.9)

# Procedural drawing state
var _time: float = 0.0
var _membrane_points: Array[Vector2] = []
var _organelle_positions: Array[Vector2] = []
var _cilia_angles: Array[float] = []
const NUM_MEMBRANE_PTS: int = 24
const NUM_CILIA: int = 10
const NUM_ORGANELLES: int = 4

# Face / mood system
enum Mood { IDLE, HAPPY, WAVE, SHY, SILLY, SURPRISED }
var _mood: Mood = Mood.IDLE
var _mood_timer: float = 0.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _eye_sparkle_timer: float = 0.0

# Social system
var _social_target: Node2D = null  # Who we're facing/interacting with
var _social_cooldown: float = 0.0
const SOCIAL_RANGE: float = 120.0  # Range to notice others
const FOLLOW_RANGE: float = 200.0  # Range to follow player
const FOLLOW_STOP: float = 80.0  # Stop following when this close

# Speech bubble
var _bubble_active: bool = false
var _bubble_timer: float = 0.0
var _bubble_text: String = ""
var _bubble_duration: float = 2.5
const BUBBLE_COOLDOWN: float = 4.0
var _bubble_cooldown_timer: float = 0.0

# Emoji/glyph sets for speech bubbles
const EMOJI_SYMBOLS: Array = ["♥", "!", "?", "♪", "★", "~", "♦", "☆", "◇", "○"]
var ALIEN_GLYPHS: Array = UIConstants.ALIEN_GLYPHS

const EYE_STYLES: Array = ["round", "anime", "compound", "googly", "slit", "lashed", "fierce", "dot", "star"]

func _ready() -> void:
	add_to_group("kin")
	_copy_player_appearance()
	_randomize_eyes()
	_init_procedural_shape()
	_wander_timer = randf_range(1.0, 3.0)
	wander_target = global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	_time = randf_range(0.0, 10.0)  # Desync animations

func _copy_player_appearance() -> void:
	var cc: Dictionary = GameManager.creature_customization
	_colors = {
		"membrane_color": cc.get("membrane_color", Color(0.3, 0.6, 1.0)),
		"glow_color": cc.get("glow_color", Color(0.3, 0.7, 1.0)),
		"interior_color": cc.get("interior_color", Color(0.15, 0.25, 0.5)),
		"cilia_color": cc.get("cilia_color", Color(0.4, 0.7, 1.0)),
		"organelle_tint": cc.get("organelle_tint", Color(0.3, 0.8, 0.5)),
	}
	_mutations = GameManager.active_mutations.duplicate(true)
	_placements = GameManager.mutation_placements.duplicate(true)
	_elongation = 1.0 + GameManager.evolution_level * 0.15
	# Check for larger_membrane mutation
	for m in _mutations:
		if m.get("visual", "") == "larger_membrane":
			_cell_radius = 24.0

func _randomize_eyes() -> void:
	# Pick a random style different from player if possible
	var player_style: String = GameManager.creature_customization.get("eye_style", "anime")
	var available: Array = EYE_STYLES.duplicate()
	available.erase(player_style)
	if available.size() > 0:
		_eye_style = available[randi() % available.size()]
	else:
		_eye_style = EYE_STYLES[randi() % EYE_STYLES.size()]
	_eye_angle = randf_range(-0.4, 0.4)  # Roughly horizontal eyes
	_eye_spacing = randf_range(3.5, 8.0)
	_eye_size = randf_range(2.5, 5.5)
	_iris_color = Color.from_hsv(randf(), randf_range(0.4, 0.9), randf_range(0.5, 1.0))

func _init_procedural_shape() -> void:
	_membrane_points.clear()
	for i in range(NUM_MEMBRANE_PTS):
		var a: float = TAU * i / NUM_MEMBRANE_PTS
		var r: float = _cell_radius + randf_range(-1.0, 1.0)
		_membrane_points.append(Vector2(cos(a) * r * _elongation, sin(a) * r))
	_organelle_positions.clear()
	for i in range(NUM_ORGANELLES):
		var a: float = TAU * i / NUM_ORGANELLES + randf_range(-0.3, 0.3)
		var r: float = randf_range(3.0, _cell_radius * 0.6)
		_organelle_positions.append(Vector2(cos(a) * r * _elongation, sin(a) * r))
	_cilia_angles.clear()
	for i in range(NUM_CILIA):
		_cilia_angles.append(TAU * i / NUM_CILIA + randf_range(-0.15, 0.15))

func _physics_process(delta: float) -> void:
	_time += delta
	_mood_timer -= delta
	_social_cooldown -= delta
	_bubble_cooldown_timer -= delta

	# Blink
	_blink_timer -= delta
	if _blink_timer <= 0:
		_is_blinking = not _is_blinking
		_blink_timer = 0.08 if _is_blinking else randf_range(2.0, 5.0)
	_eye_sparkle_timer += delta

	# Mood timeout
	if _mood_timer <= 0:
		_mood = Mood.IDLE
		_social_target = null

	# Speech bubble timer
	if _bubble_active:
		_bubble_timer -= delta
		if _bubble_timer <= 0:
			_bubble_active = false

	# State machine
	match state:
		State.WANDER:
			_do_wander(delta)
		State.FOLLOW:
			_do_follow(delta)
		State.SOCIALIZE:
			_do_socialize(delta)

	# Check for social opportunities
	if _social_cooldown <= 0 and state != State.SOCIALIZE:
		_scan_for_social()

	move_and_slide()
	# Face toward movement direction
	if velocity.length() > 5.0:
		rotation = lerp_angle(rotation, velocity.angle(), delta * 3.0)
	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _do_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0:
		_wander_timer = randf_range(2.0, 5.0)
		wander_target = global_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
	var dir: Vector2 = (wander_target - global_position)
	if dir.length() > 10.0:
		velocity = velocity.lerp(dir.normalized() * speed * 0.5, delta * 2.0)
	else:
		velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
	# Check if player is nearby to follow
	var player := _get_player()
	if player and global_position.distance_to(player.global_position) < FOLLOW_RANGE:
		if randf() < delta * 0.3:  # ~30% chance per second to start following
			state = State.FOLLOW

func _do_follow(delta: float) -> void:
	var player := _get_player()
	if not player:
		state = State.WANDER
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist > FOLLOW_RANGE * 1.5:
		state = State.WANDER
		return
	if dist > FOLLOW_STOP:
		var dir: Vector2 = (player.global_position - global_position).normalized()
		velocity = velocity.lerp(dir * speed * 0.7, delta * 2.5)
	else:
		velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
		# Occasionally break off
		if randf() < delta * 0.1:
			state = State.WANDER
			_wander_timer = randf_range(3.0, 6.0)

func _do_socialize(_delta: float) -> void:
	if not is_instance_valid(_social_target):
		state = State.WANDER
		return
	# Face toward social target
	var dir: Vector2 = (_social_target.global_position - global_position)
	if dir.length() > 5.0:
		rotation = lerp_angle(rotation, dir.angle(), _delta * 4.0)
	velocity = velocity.lerp(Vector2.ZERO, _delta * 5.0)

func _scan_for_social() -> void:
	# Check player first
	var player := _get_player()
	if player:
		var dist: float = global_position.distance_to(player.global_position)
		if dist < SOCIAL_RANGE:
			_start_social(player)
			return
	# Check other kin
	for kin in get_tree().get_nodes_in_group("kin"):
		if kin == self:
			continue
		if global_position.distance_to(kin.global_position) < SOCIAL_RANGE:
			_start_social(kin)
			return

func _start_social(target: Node2D) -> void:
	state = State.SOCIALIZE
	_social_target = target
	_social_cooldown = randf_range(5.0, 10.0)
	# Pick a random mood
	var moods: Array = [Mood.HAPPY, Mood.WAVE, Mood.SHY, Mood.SILLY, Mood.SURPRISED]
	_mood = moods[randi() % moods.size()]
	_mood_timer = randf_range(2.0, 4.0)
	# Show speech bubble
	if _bubble_cooldown_timer <= 0:
		_show_speech_bubble()

func _show_speech_bubble() -> void:
	_bubble_active = true
	_bubble_timer = _bubble_duration
	_bubble_cooldown_timer = BUBBLE_COOLDOWN
	# Generate mixed alien glyph + emoji text
	var parts: Array = []
	var word_count: int = randi_range(1, 3)
	for _w in range(word_count):
		if randf() < 0.35:
			# Emoji symbol
			parts.append(EMOJI_SYMBOLS[randi() % EMOJI_SYMBOLS.size()])
		else:
			# Alien word (2-4 glyphs)
			var word: String = ""
			for _g in range(randi_range(2, 4)):
				word += ALIEN_GLYPHS[randi() % ALIEN_GLYPHS.size()]
			parts.append(word)
	_bubble_text = " ".join(parts)

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

# ======================== DRAWING ========================

func _draw() -> void:
	# Outer glow
	var glow_col: Color = _colors.get("glow_color", Color(0.3, 0.7, 1.0))
	var glow_alpha: float = 0.06 + 0.04 * sin(_time * 2.0)
	_draw_ellipse(Vector2.ZERO, _cell_radius * _elongation * 2.0, _cell_radius * 2.0, Color(glow_col.r, glow_col.g, glow_col.b, glow_alpha))

	# Cilia
	var cilia_col: Color = _colors.get("cilia_color", Color(0.4, 0.7, 1.0))
	for i in range(NUM_CILIA):
		var base_angle: float = _cilia_angles[i]
		var wave: float = sin(_time * 6.0 + i * 1.3) * 0.2
		var angle: float = base_angle + wave
		var base_pt := Vector2(cos(base_angle) * _cell_radius * _elongation, sin(base_angle) * _cell_radius)
		var tip_len: float = 7.0 + 2.0 * sin(_time * 4.0 + i)
		var tip_pt := base_pt + Vector2(cos(angle) * tip_len, sin(angle) * tip_len)
		draw_line(base_pt, tip_pt, Color(cilia_col.r * 1.1, cilia_col.g, cilia_col.b, 0.6), 1.0, true)

	# Membrane body
	var membrane_col: Color = _colors.get("membrane_color", Color(0.3, 0.6, 1.0))
	var interior_col: Color = _colors.get("interior_color", Color(0.15, 0.25, 0.5))
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(NUM_MEMBRANE_PTS):
		var wobble := sin(_time * 2.5 + i * 0.8) * 1.2
		pts.append(_membrane_points[i] + _membrane_points[i].normalized() * wobble)
	draw_colored_polygon(pts, Color(interior_col.r, interior_col.g, interior_col.b, 0.65))
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(membrane_col.r, membrane_col.g, membrane_col.b, 0.8), 1.3, true)

	# Organelles
	var org_tint: Color = _colors.get("organelle_tint", Color(0.3, 0.8, 0.5))
	var base_org_colors: Array = [
		Color(0.2, 0.9, 0.3, 0.6), Color(0.9, 0.6, 0.1, 0.6),
		Color(0.7, 0.2, 0.8, 0.5), Color(0.1, 0.8, 0.8, 0.5),
	]
	for i in range(_organelle_positions.size()):
		var wobble_v := Vector2(sin(_time * 1.8 + i), cos(_time * 1.5 + i * 0.7)) * 1.2
		var oc: Color = base_org_colors[i % base_org_colors.size()]
		var tinted: Color = oc.lerp(org_tint, 0.4)
		tinted.a = oc.a
		draw_circle(_organelle_positions[i] + wobble_v, 2.2, tinted)

	# Mutations
	_draw_mutations()

	# Face
	_draw_face()

	# Speech bubble
	if _bubble_active:
		_draw_speech_bubble()

# ======================== MUTATIONS ========================

const GLOBAL_MUTATIONS: Array = [
	"extra_cilia", "spikes", "armor_plates", "color_shift",
	"bioluminescence", "thick_membrane", "regeneration",
	"pili_network", "absorption_villi", "electroreceptors",
	"electric_organ", "side_barbs", "lateral_line", "larger_membrane"
]

func _draw_mutations() -> void:
	for m in _mutations:
		var vis: String = m.get("visual", "")
		var mid: String = m.get("id", "")
		if vis in GLOBAL_MUTATIONS:
			_draw_mutation_visual(vis)
			continue
		var placement: Dictionary = _placements.get(mid, {})
		if placement.is_empty():
			_draw_mutation_visual(vis)
			continue
		if placement.has("angle"):
			var angle: float = placement.get("angle", 0.0)
			var distance: float = placement.get("distance", 1.0)
			var mirrored: bool = placement.get("mirrored", false)
			var mut_scale: float = placement.get("scale", 1.0)
			var rot_offset: float = placement.get("rotation_offset", 0.0)
			var pos: Vector2 = SnapPointSystem.angle_to_perimeter_position(angle, _cell_radius, _elongation, distance)
			var outward_rot: float = SnapPointSystem.get_outward_rotation(angle) + rot_offset
			draw_set_transform(pos, outward_rot, Vector2(mut_scale, mut_scale))
			_draw_mutation_visual(vis)
			if mirrored:
				var mirror_angle: float = SnapPointSystem.get_mirror_angle(angle)
				var mirror_pos: Vector2 = SnapPointSystem.angle_to_perimeter_position(mirror_angle, _cell_radius, _elongation, distance)
				var mirror_rot: float = SnapPointSystem.get_outward_rotation(mirror_angle) - rot_offset
				draw_set_transform(mirror_pos, mirror_rot, Vector2(mut_scale, mut_scale))
				_draw_mutation_visual(vis)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_mutation_visual(vis: String) -> void:
	match vis:
		"extra_cilia": _draw_mut_extra_cilia()
		"spikes": _draw_mut_spikes()
		"armor_plates": _draw_mut_armor_plates()
		"bioluminescence": _draw_mut_bioluminescence()
		"flagellum": _draw_mut_flagellum()
		"tentacles": _draw_mut_tentacles()
		"thick_membrane": _draw_mut_thick_membrane()
		"regeneration": _draw_mut_regeneration()
		"dorsal_fin": _draw_mut_dorsal_fin()
		"toxin_glands": _draw_mut_toxin_glands()
		"pili_network": _draw_mut_pili_network()
		"electric_organ": _draw_mut_electric_organ()
		"absorption_villi": _draw_mut_absorption_villi()
		"front_spike": _draw_mut_front_spike()
		"mandibles": _draw_mut_mandibles()
		"rear_stinger": _draw_mut_rear_stinger()
		"side_barbs": _draw_mut_side_barbs()
		"tail_club": _draw_mut_tail_club()
		"antenna": _draw_mut_antenna()
		_: _draw_mut_generic(vis)

# --- Mutation visuals (simplified versions of player_cell's) ---

func _draw_mut_extra_cilia() -> void:
	for i in range(6):
		var a: float = TAU * i / 6.0 + 0.3
		var wave: float = sin(_time * 8.0 + i * 1.5) * 0.3
		var base := Vector2(cos(a) * _cell_radius, sin(a) * _cell_radius)
		var tip := base + Vector2(cos(a + wave) * 12.0, sin(a + wave) * 12.0)
		draw_line(base, tip, Color(0.4, 0.9, 1.0, 0.5), 1.0, true)

func _draw_mut_spikes() -> void:
	for i in range(6):
		var a: float = TAU * i / 6.0
		var base := Vector2(cos(a) * _cell_radius, sin(a) * _cell_radius)
		var tip := base + Vector2(cos(a), sin(a)) * (8.0 + sin(_time * 2.0 + i) * 1.5)
		draw_line(base, tip, Color(0.9, 0.3, 0.2, 0.7), 1.8, true)

func _draw_mut_armor_plates() -> void:
	for i in range(4):
		var a: float = TAU * i / 4.0 + PI * 0.3
		var p := Vector2(cos(a), sin(a)) * (_cell_radius - 2.0)
		var perp := Vector2(-sin(a), cos(a))
		var plate_pts: PackedVector2Array = PackedVector2Array([
			p + perp * 4.0, p - perp * 4.0,
			p - perp * 3.0 + Vector2(cos(a), sin(a)) * 3.0,
			p + perp * 3.0 + Vector2(cos(a), sin(a)) * 3.0,
		])
		draw_colored_polygon(plate_pts, Color(0.4, 0.5, 0.6, 0.4))

func _draw_mut_bioluminescence() -> void:
	var pulse: float = 0.3 + 0.15 * sin(_time * 2.5)
	draw_circle(Vector2.ZERO, _cell_radius * 1.6, Color(0.2, 0.8, 1.0, pulse * 0.08))

func _draw_mut_flagellum() -> void:
	var base := Vector2(-_cell_radius * _elongation - 2.0, 0)
	for i in range(12):
		var t: float = float(i) / 11.0
		var px: float = base.x - t * 24.0
		var py: float = sin(_time * 7.0 + t * 5.0) * 7.0 * t
		if i > 0:
			var pt: float = float(i - 1) / 11.0
			var ppx: float = base.x - pt * 24.0
			var ppy: float = sin(_time * 7.0 + pt * 5.0) * 7.0 * pt
			draw_line(Vector2(ppx, ppy), Vector2(px, py), Color(0.5, 0.8, 0.4, 0.6), 1.8 - t * 1.0, true)

func _draw_mut_tentacles() -> void:
	for i in range(3):
		var base_a: float = PI + (i - 1) * 0.4
		var base := Vector2(cos(base_a), sin(base_a)) * _cell_radius
		for s in range(8):
			var t: float = float(s) / 7.0
			var px: float = base.x + cos(base_a) * t * 20.0 + sin(_time * 2.5 + i + t * 3.0) * 4.0 * t
			var py: float = base.y + sin(base_a) * t * 20.0 + cos(_time * 2.0 + i * 2.0 + t * 2.0) * 3.0 * t
			if s > 0:
				var pt: float = float(s - 1) / 7.0
				var ppx: float = base.x + cos(base_a) * pt * 20.0 + sin(_time * 2.5 + i + pt * 3.0) * 4.0 * pt
				var ppy: float = base.y + sin(base_a) * pt * 20.0 + cos(_time * 2.0 + i * 2.0 + pt * 2.0) * 3.0 * pt
				draw_line(Vector2(ppx, ppy), Vector2(px, py), Color(0.6, 0.4, 0.8, 0.5 - t * 0.3), 1.8 - t * 1.2, true)

func _draw_mut_thick_membrane() -> void:
	for i in range(NUM_MEMBRANE_PTS):
		var wobble := sin(_time * 2.5 + i * 0.8) * 0.8
		var p := _membrane_points[i].normalized() * (_cell_radius + 2.5 + wobble)
		var p2 := _membrane_points[(i + 1) % NUM_MEMBRANE_PTS].normalized() * (_cell_radius + 2.5 + sin(_time * 2.5 + (i + 1) * 0.8) * 0.8)
		draw_line(p, p2, Color(0.4, 0.6, 0.9, 0.3), 2.0, true)

func _draw_mut_regeneration() -> void:
	var pulse: float = 0.12 + 0.08 * sin(_time * 1.8)
	draw_circle(Vector2.ZERO, _cell_radius * 1.2, Color(0.2, 0.9, 0.3, pulse))

func _draw_mut_dorsal_fin() -> void:
	var wave: float = sin(_time * 2.5) * 1.5
	var fin_pts: PackedVector2Array = PackedVector2Array([
		Vector2(3.0, -_cell_radius),
		Vector2(-5.0, -_cell_radius - 8.0 + wave),
		Vector2(-7.0, -_cell_radius),
	])
	draw_colored_polygon(fin_pts, Color(0.3, 0.6, 0.9, 0.45))

func _draw_mut_toxin_glands() -> void:
	for i in range(3):
		var a: float = TAU * i / 3.0 + PI * 0.5
		var p := Vector2(cos(a), sin(a)) * (_cell_radius * 0.7)
		var pulse: float = 0.5 + 0.2 * sin(_time * 3.0 + i * 2.0)
		draw_circle(p, 2.5 * pulse, Color(0.5, 0.9, 0.1, 0.4))

func _draw_mut_pili_network() -> void:
	for i in range(12):
		var a: float = TAU * i / 12.0
		var base := Vector2(cos(a), sin(a)) * _cell_radius
		var tip := base + Vector2(cos(a), sin(a)) * (3.0 + sin(_time * 1.5 + i) * 1.0)
		draw_line(base, tip, Color(0.6, 0.7, 0.5, 0.25), 0.5, true)

func _draw_mut_electric_organ() -> void:
	for i in range(2):
		var a: float = TAU * i / 2.0 + _time * 4.0
		var p1 := Vector2(cos(a), sin(a)) * _cell_radius
		var jitter := Vector2(sin(_time * 15.0 + i * 7.0) * 3.0, cos(_time * 13.0 + i * 5.0) * 3.0)
		var p2 := p1 + Vector2(cos(a), sin(a)) * 6.0 + jitter
		draw_line(p1, p2, Color(0.5, 0.8, 1.0, 0.5), 0.8, true)

func _draw_mut_absorption_villi() -> void:
	for i in range(8):
		var a: float = TAU * i / 8.0 + 0.15
		var base := Vector2(cos(a), sin(a)) * _cell_radius
		var tip := base + Vector2(cos(a), sin(a)) * (5.0 + sin(_time * 2.5 + i) * 1.5)
		draw_line(base, tip, Color(0.8, 0.6, 0.3, 0.4), 0.8, true)
		draw_circle(tip, 1.0, Color(0.9, 0.7, 0.4, 0.5))

func _draw_mut_front_spike() -> void:
	var base := Vector2(_cell_radius * _elongation, 0)
	var tip := base + Vector2(10.0 + sin(_time * 3.0) * 1.5, 0)
	draw_line(base, tip, Color(0.9, 0.2, 0.1, 0.7), 2.0, true)

func _draw_mut_mandibles() -> void:
	for side in [-1.0, 1.0]:
		var base := Vector2(_cell_radius * _elongation * 0.8, side * 4.0)
		var open: float = 0.3 + sin(_time * 2.0) * 0.15
		var tip := base + Vector2(8.0, side * 6.0 * open)
		draw_line(base, tip, Color(0.7, 0.5, 0.3, 0.7), 1.5, true)

func _draw_mut_rear_stinger() -> void:
	var base := Vector2(-_cell_radius * _elongation, 0)
	var tip := base + Vector2(-10.0, sin(_time * 4.0) * 2.0)
	draw_line(base, tip, Color(0.8, 0.2, 0.5, 0.7), 2.0, true)
	draw_circle(tip, 2.0, Color(0.9, 0.3, 0.6, 0.5))

func _draw_mut_side_barbs() -> void:
	for i in range(4):
		var a: float = PI * 0.5 + (i - 1.5) * 0.5
		var base := Vector2(cos(a), sin(a)) * _cell_radius
		var tip := base + Vector2(cos(a), sin(a)) * 6.0
		draw_line(base, tip, Color(0.8, 0.4, 0.2, 0.6), 1.2, true)

func _draw_mut_tail_club() -> void:
	var base := Vector2(-_cell_radius * _elongation - 4.0, 0)
	var swing: float = sin(_time * 3.0) * 3.0
	draw_circle(base + Vector2(-6.0, swing), 4.0, Color(0.5, 0.4, 0.3, 0.5))

func _draw_mut_antenna() -> void:
	for side in [-1.0, 1.0]:
		var base := Vector2(_cell_radius * _elongation * 0.7, side * 3.0)
		var tip := base + Vector2(12.0 + sin(_time * 2.0) * 1.0, side * 8.0 + sin(_time * 1.5 + side) * 2.0)
		draw_line(base, tip, Color(0.5, 0.7, 0.4, 0.6), 1.0, true)
		draw_circle(tip, 1.5, Color(0.6, 0.8, 0.5, 0.7))

func _draw_mut_generic(_vis: String) -> void:
	# Generic colored dot for unrecognized mutations
	draw_circle(Vector2.ZERO, 2.5, Color(0.6, 0.6, 0.8, 0.4))

# ======================== FACE ========================

func _draw_face() -> void:
	var base_spacing: float = _eye_spacing * 1.1
	var face_fwd: float = _cell_radius * (_elongation - 1.0) * 0.3
	var face_center := Vector2(_cell_radius * 0.2 + face_fwd, 0)
	var perp := Vector2(-sin(_eye_angle), cos(_eye_angle))
	var left_eye := face_center + perp * (-base_spacing * 0.4)
	var right_eye := face_center + perp * (base_spacing * 0.4)

	var eye_r: float = _eye_size * 1.3
	var pupil_r: float = eye_r * 0.35
	var iris_r: float = eye_r * 0.65
	var eye_squash_y: float = 1.0
	var show_sparkles: bool = false
	var pupil_offset := Vector2.ZERO

	# Mood modifiers
	match _mood:
		Mood.IDLE:
			eye_squash_y = 0.9
			show_sparkles = true
		Mood.HAPPY:
			eye_squash_y = 0.4
			show_sparkles = true
		Mood.WAVE:
			eye_r *= 1.15
			pupil_offset = Vector2(0.5, 0)
		Mood.SHY:
			eye_squash_y = 0.6
			pupil_offset = Vector2(-0.3, 0.4)
		Mood.SILLY:
			eye_r *= 1.2
			pupil_r *= 1.4
			# Cross-eyed
			pupil_offset = Vector2(0, 0)  # Handled per-eye below
		Mood.SURPRISED:
			eye_r *= 1.4
			pupil_r *= 0.5

	# Eye style modifications
	match _eye_style:
		"round": iris_r = eye_r * 0.55; pupil_r *= 1.2
		"compound": eye_r *= 0.7
		"googly": eye_r *= 1.3; pupil_r *= 0.8; iris_r = eye_r * 0.5
		"slit": eye_squash_y *= 0.6; pupil_r *= 0.6
		"lashed": eye_r *= 1.05; iris_r = eye_r * 0.6
		"fierce": eye_squash_y *= 0.65; eye_r *= 1.1; iris_r = eye_r * 0.55
		"dot": eye_r *= 0.5; pupil_r *= 1.8; iris_r = eye_r * 0.3
		"star": iris_r = eye_r * 0.7

	if _is_blinking:
		eye_squash_y = 0.05

	# Look toward social target or wander direction
	var look_dir := Vector2.ZERO
	if is_instance_valid(_social_target):
		look_dir = (_social_target.global_position - global_position).rotated(-rotation).normalized() * eye_r * 0.2
	elif velocity.length() > 5.0:
		look_dir = velocity.rotated(-rotation).normalized() * eye_r * 0.15

	# Draw each eye
	for idx in range(2):
		var eye_pos: Vector2 = left_eye if idx == 0 else right_eye
		var ew: float = eye_r
		var eh: float = eye_r * eye_squash_y

		# Silly cross-eyed offset
		var local_pupil_offset := pupil_offset
		if _mood == Mood.SILLY:
			local_pupil_offset = Vector2(0, (1.0 if idx == 0 else -1.0) * eye_r * 0.3)

		if _eye_style == "compound" and not _is_blinking:
			# Compound: cluster of facets
			var facet_r: float = eye_r * 0.35
			for row in range(3):
				for col in range(3):
					if (row == 0 or row == 2) and (col == 0 or col == 2):
						continue
					var c_offset := Vector2((col - 1) * facet_r * 1.8, (row - 1) * facet_r * 1.6)
					var fp := eye_pos + c_offset
					draw_circle(fp, facet_r, Color(_iris_color.r * 0.8, _iris_color.g * 0.8, _iris_color.b, 0.7))
					draw_circle(fp, facet_r * 0.5, Color(0.05, 0.05, 0.1, 0.9))
		elif _eye_style == "dot" and not _is_blinking:
			draw_circle(eye_pos, eye_r, Color(0.02, 0.02, 0.08))
			draw_circle(eye_pos + Vector2(-eye_r * 0.2, -eye_r * 0.25), eye_r * 0.3, Color(1, 1, 1, 0.35))
		else:
			# Standard eye
			var eye_pts: PackedVector2Array = PackedVector2Array()
			for i in range(16):
				var a: float = TAU * i / 16.0
				eye_pts.append(eye_pos + Vector2(cos(a) * ew, sin(a) * eh))
			draw_colored_polygon(eye_pts, Color(1.0, 1.0, 1.0, 1.0))
			if eye_squash_y > 0.15:
				var p_pos := eye_pos + look_dir + local_pupil_offset
				# Iris
				var iris_pts: PackedVector2Array = PackedVector2Array()
				for i in range(16):
					var a: float = TAU * i / 16.0
					iris_pts.append(p_pos + Vector2(cos(a) * iris_r, sin(a) * iris_r * eye_squash_y))
				draw_colored_polygon(iris_pts, _iris_color)
				# Slit pupil variant
				if _eye_style == "slit":
					var slit_h: float = pupil_r * eye_squash_y * 1.8
					var slit_w: float = pupil_r * 0.35
					draw_colored_polygon(PackedVector2Array([
						p_pos + Vector2(-slit_w, 0), p_pos + Vector2(0, -slit_h),
						p_pos + Vector2(slit_w, 0), p_pos + Vector2(0, slit_h),
					]), Color(0.02, 0.02, 0.08))
				else:
					draw_circle(p_pos, pupil_r, Color(0.02, 0.02, 0.08))
				# Sparkle highlights
				if show_sparkles or _mood == Mood.IDLE:
					var sp := p_pos + Vector2(-iris_r * 0.3, -iris_r * 0.3)
					var pulse: float = 0.7 + 0.3 * sin(_eye_sparkle_timer * 3.0 + idx)
					draw_circle(sp, pupil_r * 0.5 * pulse, Color(1, 1, 1, 0.9))
				else:
					draw_circle(p_pos + Vector2(-pupil_r * 0.4, -pupil_r * 0.4), pupil_r * 0.3, Color(1, 1, 1, 0.7))
			# Eye outline
			for i in range(eye_pts.size()):
				draw_line(eye_pts[i], eye_pts[(i + 1) % eye_pts.size()], Color(0.1, 0.15, 0.25, 0.5), 0.7, true)
			# Lashes
			if _eye_style == "lashed" and not _is_blinking:
				for li in range(3):
					var la: float = -PI * 0.6 + li * PI * 0.3
					var lash_base := eye_pos + Vector2(cos(la) * ew, sin(la) * eh)
					var lash_tip := eye_pos + Vector2(cos(la) * (ew + 2.0), sin(la) * (eh + 2.0))
					draw_line(lash_base, lash_tip, Color(0.08, 0.08, 0.12, 0.8), 1.2, true)

	# Mouth expression (small, near bottom of face)
	var mouth_pos := face_center + Vector2(1.0, 4.0)
	match _mood:
		Mood.HAPPY:
			# Big smile arc
			draw_arc(mouth_pos, 3.0, 0.2, PI - 0.2, 8, Color(0.2, 0.15, 0.1, 0.7), 1.2, true)
		Mood.WAVE:
			# Open happy mouth
			draw_circle(mouth_pos, 2.0, Color(0.2, 0.1, 0.1, 0.6))
		Mood.SHY:
			# Small squiggle
			draw_line(mouth_pos + Vector2(-2, 0), mouth_pos + Vector2(0, 1), Color(0.3, 0.2, 0.2, 0.5), 0.8, true)
			draw_line(mouth_pos + Vector2(0, 1), mouth_pos + Vector2(2, 0), Color(0.3, 0.2, 0.2, 0.5), 0.8, true)
		Mood.SILLY:
			# Tongue out
			draw_arc(mouth_pos, 2.5, 0.2, PI - 0.2, 8, Color(0.2, 0.15, 0.1, 0.7), 1.0, true)
			draw_circle(mouth_pos + Vector2(0, 3.5), 2.0, Color(0.9, 0.4, 0.5, 0.6))
		Mood.SURPRISED:
			# O mouth
			draw_circle(mouth_pos, 2.5, Color(0.15, 0.1, 0.1, 0.7))
			draw_circle(mouth_pos, 1.5, Color(0.3, 0.15, 0.15, 0.5))

# ======================== SPEECH BUBBLE ========================

func _draw_speech_bubble() -> void:
	if _bubble_text.is_empty():
		return
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var bubble_alpha: float = 1.0
	# Fade in and out
	var elapsed: float = _bubble_duration - _bubble_timer
	if elapsed < 0.3:
		bubble_alpha = elapsed / 0.3
	elif _bubble_timer < 0.5:
		bubble_alpha = _bubble_timer / 0.5

	# Bubble position (above the organism, in local space)
	var bubble_pos := Vector2(0, -_cell_radius - 18.0).rotated(-rotation)  # Cancel parent rotation
	var text_size := mono.get_string_size(_bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
	var bubble_w: float = text_size.x + 14.0
	var bubble_h: float = 18.0

	# Wobble
	var wobble := Vector2(sin(_time * 3.0) * 1.5, cos(_time * 2.5) * 1.0)
	bubble_pos += wobble

	# Draw at screen-aligned rotation (cancel entity rotation)
	draw_set_transform(bubble_pos, -rotation, Vector2.ONE)

	# Bubble background (rounded rectangle via polygon)
	var bx: float = -bubble_w * 0.5
	var by: float = -bubble_h
	var bg_col := Color(1.0, 1.0, 1.0, 0.85 * bubble_alpha)
	var border_col := Color(0.3, 0.5, 0.7, 0.6 * bubble_alpha)
	draw_rect(Rect2(bx, by, bubble_w, bubble_h), bg_col)
	draw_rect(Rect2(bx, by, bubble_w, bubble_h), border_col, false, 1.0)

	# Tail (triangle pointing down)
	var tail_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-4, 0), Vector2(4, 0), Vector2(0, 7),
	])
	draw_colored_polygon(tail_pts, bg_col)

	# Text
	var text_x: float = -text_size.x * 0.5
	var text_y: float = -bubble_h * 0.5 + 4.0
	draw_string(mono, Vector2(text_x, text_y), _bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.15, 0.2, 0.3, bubble_alpha))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ======================== HELPERS ========================

func _draw_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(20):
		var a: float = TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

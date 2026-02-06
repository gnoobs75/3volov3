extends Control
## Observer Notes Pane — Alien cursive scribbles burned into a memory tablet.
## Notes appear as handwritten alien script that burns/etches into the surface.

const PANE_WIDTH: float = 320.0
const MAX_NOTES: int = 4  # Reduced to fit with CreatureViewer below
const NOTE_HEIGHT: float = 130.0
const WRITE_DURATION: float = 1.5  # Time to "write" the note
const BURN_DURATION: float = 2.5  # Time to burn into tablet
const EMBEDDED_DURATION: float = 12.0  # How long before fading

# Note states
enum NoteState { WRITING, BURNING, EMBEDDED, FADING }

# Alien cursive stroke patterns (bezier-like segments)
# Each pattern is array of {start, ctrl1, ctrl2, end} normalized 0-1
const CURSIVE_PATTERNS: Array = [
	# Flowing loops
	[{"s": Vector2(0, 0.5), "c1": Vector2(0.2, 0), "c2": Vector2(0.3, 1), "e": Vector2(0.5, 0.5)}],
	[{"s": Vector2(0, 0.3), "c1": Vector2(0.4, 0), "c2": Vector2(0.6, 1), "e": Vector2(1, 0.7)}],
	# Sharp angles with curves
	[{"s": Vector2(0, 0.8), "c1": Vector2(0.2, 0.2), "c2": Vector2(0.5, 0.8), "e": Vector2(0.7, 0.2)},
	 {"s": Vector2(0.7, 0.2), "c1": Vector2(0.8, 0.6), "c2": Vector2(0.9, 0.3), "e": Vector2(1, 0.5)}],
	# Spiral-ish
	[{"s": Vector2(0.5, 0), "c1": Vector2(0, 0.3), "c2": Vector2(0.2, 0.8), "e": Vector2(0.5, 0.5)},
	 {"s": Vector2(0.5, 0.5), "c1": Vector2(0.8, 0.2), "c2": Vector2(1, 0.7), "e": Vector2(0.7, 1)}],
	# Zigzag with flourish
	[{"s": Vector2(0, 0.5), "c1": Vector2(0.1, 0.1), "c2": Vector2(0.2, 0.9), "e": Vector2(0.4, 0.3)},
	 {"s": Vector2(0.4, 0.3), "c1": Vector2(0.6, 0.7), "c2": Vector2(0.8, 0.1), "e": Vector2(1, 0.6)}],
	# Wavy underscore
	[{"s": Vector2(0, 0.6), "c1": Vector2(0.25, 0.3), "c2": Vector2(0.5, 0.9), "e": Vector2(0.75, 0.4)},
	 {"s": Vector2(0.75, 0.4), "c1": Vector2(0.85, 0.7), "c2": Vector2(0.95, 0.5), "e": Vector2(1, 0.5)}],
	# Hook pattern
	[{"s": Vector2(0, 0.2), "c1": Vector2(0.3, 0.9), "c2": Vector2(0.5, 0.1), "e": Vector2(0.7, 0.8)},
	 {"s": Vector2(0.7, 0.8), "c1": Vector2(0.8, 0.4), "c2": Vector2(0.9, 0.6), "e": Vector2(1, 0.3)}],
	# Double loop
	[{"s": Vector2(0, 0.5), "c1": Vector2(0.15, 0), "c2": Vector2(0.25, 1), "e": Vector2(0.4, 0.5)},
	 {"s": Vector2(0.4, 0.5), "c1": Vector2(0.55, 0), "c2": Vector2(0.65, 1), "e": Vector2(0.8, 0.5)},
	 {"s": Vector2(0.8, 0.5), "c1": Vector2(0.9, 0.3), "c2": Vector2(1, 0.7), "e": Vector2(1, 0.5)}],
]

# Alien accent marks and diacritics
const ACCENT_GLYPHS: Array = ["'", "\"", "`", "~", "^", "*", "+"]

var _notes: Array[Dictionary] = []
var _time: float = 0.0
var _pending_note_queue: Array = []
var _note_cooldown: float = 0.0
var _tablet_scratches: Array = []  # Permanent background scratches

func _ready() -> void:
	# Add to group so CreatureViewer can notify us
	add_to_group("observer_notes")

	# Connect to game events
	if GameManager.has_signal("biomolecule_collected"):
		GameManager.biomolecule_collected.connect(_on_biomolecule_collected)
	if GameManager.has_signal("evolution_applied"):
		GameManager.evolution_applied.connect(_on_evolution_applied)
	call_deferred("_connect_player_signals")

	# Generate permanent tablet scratches/texture
	_generate_tablet_texture()

	# Initial observation
	call_deferred("_queue_note")

func _generate_tablet_texture() -> void:
	# Create some permanent faint scratches on the tablet
	for i in range(15):
		_tablet_scratches.append({
			"start": Vector2(randf() * PANE_WIDTH, randf() * 1080),
			"end": Vector2(randf() * PANE_WIDTH, randf() * 1080),
			"alpha": randf_range(0.02, 0.06),
		})

func _connect_player_signals() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node = players[0]
		if player.has_signal("damaged"):
			player.damaged.connect(_on_player_damaged)
		if player.has_signal("prey_killed"):
			player.prey_killed.connect(_on_prey_killed)
		if player.has_signal("reproduction_complete"):
			player.reproduction_complete.connect(_on_reproduction)

func _on_biomolecule_collected(_item: Dictionary) -> void:
	if randf() < 0.05:  # 5% chance
		_queue_note()

func _on_evolution_applied(_mutation: Dictionary) -> void:
	_queue_note()
	_queue_note()  # Double note for evolution

func _on_player_damaged(_amount: float) -> void:
	if randf() < 0.2:
		_queue_note()

func _on_prey_killed() -> void:
	if randf() < 0.25:
		_queue_note()

func _on_reproduction() -> void:
	_queue_note()

func _queue_note() -> void:
	_pending_note_queue.append(true)

func _generate_alien_scribble() -> Dictionary:
	# Generate a multi-line alien cursive scribble
	var lines: Array = []
	var num_lines: int = randi_range(2, 4)

	for _l in range(num_lines):
		var line: Array = []
		var num_words: int = randi_range(2, 5)
		var x_pos: float = randf_range(5, 20)

		for _w in range(num_words):
			var word_width: float = randf_range(25, 60)
			var pattern_idx: int = randi() % CURSIVE_PATTERNS.size()
			var word: Dictionary = {
				"pattern": pattern_idx,
				"x": x_pos,
				"width": word_width,
				"height": randf_range(12, 20),
				"y_offset": randf_range(-3, 3),
				"has_accent": randf() < 0.3,
				"accent_pos": randf(),
			}
			line.append(word)
			x_pos += word_width + randf_range(8, 15)

		lines.append(line)

	return {
		"lines": lines,
		"state": NoteState.WRITING,
		"timer": 0.0,
		"write_progress": 0.0,
		"burn_intensity": 0.0,
		"y_position": 0.0,
		"target_y": 0.0,
		"ember_particles": [],
	}

func _add_note() -> void:
	var note: Dictionary = _generate_alien_scribble()

	# Remove oldest if at max
	if _notes.size() >= MAX_NOTES:
		_notes.pop_back()

	# Insert at top
	_notes.insert(0, note)

	# Recalculate target positions
	for i in range(_notes.size()):
		_notes[i].target_y = 60.0 + i * NOTE_HEIGHT

func _process(delta: float) -> void:
	_time += delta

	# Process note cooldown and queue
	if _note_cooldown > 0:
		_note_cooldown -= delta
	elif _pending_note_queue.size() > 0:
		_pending_note_queue.pop_front()
		_add_note()
		_note_cooldown = 4.0

	# Update notes
	for note in _notes:
		note.timer += delta
		note.y_position = lerp(note.y_position, note.target_y, delta * 3.0)

		match note.state:
			NoteState.WRITING:
				note.write_progress = minf(note.timer / WRITE_DURATION, 1.0)
				if note.timer > WRITE_DURATION:
					note.state = NoteState.BURNING
					note.timer = 0.0

			NoteState.BURNING:
				note.burn_intensity = note.timer / BURN_DURATION
				# Generate ember particles
				if randf() < 0.3:
					note.ember_particles.append({
						"pos": Vector2(randf() * PANE_WIDTH * 0.8 + 20, note.y_position + randf() * 60),
						"life": 1.0,
						"vel": Vector2(randf_range(-20, 20), randf_range(-30, -10)),
					})
				if note.timer > BURN_DURATION:
					note.state = NoteState.EMBEDDED
					note.timer = 0.0
					note.ember_particles.clear()

			NoteState.EMBEDDED:
				if note.timer > EMBEDDED_DURATION:
					note.state = NoteState.FADING
					note.timer = 0.0

			NoteState.FADING:
				pass

		# Update ember particles
		var live_embers: Array = []
		for ember in note.ember_particles:
			ember.life -= delta * 2.0
			ember.pos += ember.vel * delta
			if ember.life > 0:
				live_embers.append(ember)
		note.ember_particles = live_embers

	# Remove fully faded notes
	_notes = _notes.filter(func(n): return n.state != NoteState.FADING or n.timer < 3.0)

	# Periodic random notes
	if fmod(_time, 35.0) < delta and _notes.size() < 3:
		_queue_note()

	queue_redraw()

func _draw() -> void:
	# Tablet scratches (permanent texture)
	for scratch in _tablet_scratches:
		draw_line(scratch.start, scratch.end, Color(0.3, 0.4, 0.5, scratch.alpha), 0.5)

	# Header area
	_draw_header()

	# Draw notes
	for note in _notes:
		_draw_note(note)

	# Status indicator
	_draw_status()

func _draw_header() -> void:
	# Alien header scribble (static)
	var header_color := Color(0.3, 0.5, 0.6, 0.6)

	# Draw some decorative alien marks
	for i in range(5):
		var x: float = 15 + i * 55
		var pattern: Array = CURSIVE_PATTERNS[i % CURSIVE_PATTERNS.size()]
		_draw_cursive_word(x, 25, 45, 15, pattern, header_color, 1.0)

	# Separator line (etched)
	draw_line(Vector2(10, 50), Vector2(PANE_WIDTH - 10, 50), Color(0.2, 0.4, 0.5, 0.4), 1.5)

func _draw_note(note: Dictionary) -> void:
	var y: float = note.y_position
	var alpha: float = 1.0

	# Calculate colors based on state
	var ink_color: Color
	var glow_color: Color

	match note.state:
		NoteState.WRITING:
			# Fresh ink - bright cyan
			ink_color = Color(0.4, 0.8, 1.0, 0.9)
			glow_color = Color(0.5, 0.9, 1.0, 0.4)

		NoteState.BURNING:
			# Transitioning from bright to burned-in
			var t: float = note.burn_intensity
			ink_color = Color(
				lerp(0.4, 0.6, t),
				lerp(0.8, 0.4, t),
				lerp(1.0, 0.3, t),
				lerp(0.9, 0.7, t)
			)
			glow_color = Color(1.0, 0.6, 0.2, (1.0 - t) * 0.5)

			# Draw burn glow behind text
			var burn_rect := Rect2(10, y - 5, PANE_WIDTH - 20, 80)
			draw_rect(burn_rect, Color(0.8, 0.4, 0.1, (1.0 - t) * 0.15))

		NoteState.EMBEDDED:
			# Burned into tablet - dim amber/brown
			ink_color = Color(0.5, 0.35, 0.2, 0.65)
			glow_color = Color(0, 0, 0, 0)

		NoteState.FADING:
			# Fading away
			alpha = 1.0 - (note.timer / 3.0)
			ink_color = Color(0.5, 0.35, 0.2, 0.65 * alpha)
			glow_color = Color(0, 0, 0, 0)

	# Draw lines of alien cursive
	var line_y: float = y
	var write_progress: float = note.write_progress
	var total_words: int = 0
	for line in note.lines:
		total_words += line.size()

	var words_drawn: int = 0
	for line_idx in range(note.lines.size()):
		var line: Array = note.lines[line_idx]

		for word in line:
			# Check if this word should be drawn based on write progress
			var word_progress: float = float(words_drawn) / float(total_words)
			if note.state == NoteState.WRITING and word_progress > write_progress:
				break

			var word_write_amt: float = 1.0
			if note.state == NoteState.WRITING:
				var next_word_progress: float = float(words_drawn + 1) / float(total_words)
				if write_progress < next_word_progress:
					word_write_amt = (write_progress - word_progress) / (next_word_progress - word_progress)

			var pattern: Array = CURSIVE_PATTERNS[word.pattern]
			_draw_cursive_word(
				word.x,
				line_y + word.y_offset,
				word.width,
				word.height,
				pattern,
				ink_color,
				word_write_amt
			)

			# Draw glow for fresh/burning text
			if glow_color.a > 0:
				_draw_cursive_word(
					word.x,
					line_y + word.y_offset,
					word.width,
					word.height,
					pattern,
					glow_color,
					word_write_amt,
					3.0  # Wider for glow
				)

			# Accent marks
			if word.has_accent and word_write_amt > 0.8:
				var ax: float = word.x + word.width * word.accent_pos
				var ay: float = line_y + word.y_offset - 8
				draw_circle(Vector2(ax, ay), 1.5, ink_color)

			words_drawn += 1

		line_y += 22

	# Draw ember particles
	for ember in note.ember_particles:
		var ember_color := Color(1.0, 0.5, 0.1, ember.life * 0.8)
		draw_circle(ember.pos, 1.5 + ember.life, ember_color)

func _draw_cursive_word(x: float, y: float, width: float, height: float, pattern: Array, color: Color, progress: float, line_width: float = 1.5) -> void:
	# Draw bezier curves for alien cursive
	var segments_to_draw: int = int(pattern.size() * progress)
	var partial_progress: float = fmod(progress * pattern.size(), 1.0)
	if progress >= 1.0:
		segments_to_draw = pattern.size()
		partial_progress = 1.0

	for i in range(segments_to_draw):
		var seg: Dictionary = pattern[i]
		var is_last: bool = (i == segments_to_draw - 1) and (progress < 1.0)
		var seg_progress: float = 1.0 if not is_last else partial_progress

		# Convert normalized coords to actual positions
		var start := Vector2(x + seg.s.x * width, y + seg.s.y * height)
		var ctrl1 := Vector2(x + seg.c1.x * width, y + seg.c1.y * height)
		var ctrl2 := Vector2(x + seg.c2.x * width, y + seg.c2.y * height)
		var end := Vector2(x + seg.e.x * width, y + seg.e.y * height)

		# Draw cubic bezier approximation
		var steps: int = int(8 * seg_progress)
		var prev: Vector2 = start
		for j in range(1, steps + 1):
			var t: float = float(j) / 8.0
			if t > seg_progress:
				t = seg_progress
			var pt: Vector2 = _cubic_bezier(start, ctrl1, ctrl2, end, t)
			draw_line(prev, pt, color, line_width, true)
			prev = pt

func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	var tt: float = t * t
	var uu: float = u * u
	var uuu: float = uu * u
	var ttt: float = tt * t
	return uuu * p0 + 3.0 * uu * t * p1 + 3.0 * u * tt * p2 + ttt * p3

func _draw_status() -> void:
	# Recording indicator at bottom
	var status_y: float = size.y - 25
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)

	# Etched recording symbol
	draw_circle(Vector2(20, status_y), 5.0, Color(0.6, 0.3, 0.1, 0.4 + pulse * 0.3))
	draw_circle(Vector2(20, status_y), 3.0, Color(0.8, 0.4, 0.1, 0.5 + pulse * 0.4))

	# Some decorative alien marks
	for i in range(3):
		var mx: float = 40 + i * 30
		var pattern: Array = CURSIVE_PATTERNS[(i + int(_time * 0.1)) % CURSIVE_PATTERNS.size()]
		_draw_cursive_word(mx, status_y - 5, 20, 10, pattern, Color(0.4, 0.3, 0.2, 0.4), 1.0, 1.0)

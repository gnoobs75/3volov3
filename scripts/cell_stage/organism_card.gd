extends Control
## Organism Overview Card — sci-fi baseball card showing stats and mutations.
## Displays alien-looking language, evolution level, stat bonuses, and alien abacus tallies.

const CARD_WIDTH: float = 288.0  # 15% of 1920
const CARD_HEIGHT: float = 1080.0  # Full height for left pane

# Alien alphabet glyphs (Unicode box-drawing + mathematical symbols)
const ALIEN_GLYPHS: Array = [
	"◊", "∆", "Ω", "Σ", "Φ", "Ψ", "λ", "π", "θ", "ξ",
	"╬", "╫", "╪", "┼", "╋", "╂", "╁", "╀", "┿", "┾",
	"⊕", "⊗", "⊙", "⊚", "⊛", "⊜", "⊝", "⊞", "⊟", "⊠",
	"⌬", "⌭", "⌮", "⌯", "⍟", "⎔", "⎕", "⏣", "⏢", "⏥",
]

# Alien numeral glyphs for abacus display
const ALIEN_NUMERALS: Array = [
	"○", "◐", "●", "◑", "◒", "◓", "◔", "◕", "◖", "◗",
]

var _time: float = 0.0
var _glitch_timer: float = 0.0
var _alien_id: String = ""
var _classification: String = ""

# Tally tracking for alien abacus
var _tallies: Dictionary = {
	"damage_dealt": 0.0,
	"damage_taken": 0.0,
	"food_eaten": 0,
	"kills": 0,
	"nucleotides": 0,
	"amino_acids": 0,
	"lipids": 0,
	"coenzymes": 0,
	"organelles": 0,
}

# Visual bead positions for smooth animation
var _bead_positions: Dictionary = {}
var _tally_flash: Dictionary = {}

func _ready() -> void:
	# Generate unique alien ID for this organism
	_regenerate_alien_text()
	GameManager.evolution_applied.connect(_on_evolution_applied)

	# Connect to biomolecule collection for abacus tracking
	if GameManager.has_signal("biomolecule_collected"):
		GameManager.biomolecule_collected.connect(_on_biomolecule_collected)

	# Connect to player signals
	call_deferred("_connect_player_signals")

	# Initialize bead positions
	for key in _tallies.keys():
		_bead_positions[key] = 0.0
		_tally_flash[key] = 0.0

func _connect_player_signals() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node = players[0]
		if player.has_signal("damaged"):
			player.damaged.connect(_on_damage_taken)
		if player.has_signal("damage_dealt"):
			player.damage_dealt.connect(_on_damage_dealt)
		if player.has_signal("prey_killed"):
			player.prey_killed.connect(_on_kill)
		if player.has_signal("food_consumed"):
			player.food_consumed.connect(_on_food_eaten)

func _on_biomolecule_collected(type: String, amount: int) -> void:
	match type:
		"nucleotide":
			_tallies.nucleotides += amount
			_tally_flash.nucleotides = 1.0
		"amino_acid":
			_tallies.amino_acids += amount
			_tally_flash.amino_acids = 1.0
		"lipid":
			_tallies.lipids += amount
			_tally_flash.lipids = 1.0
		"coenzyme":
			_tallies.coenzymes += amount
			_tally_flash.coenzymes = 1.0
		"organelle":
			_tallies.organelles += amount
			_tally_flash.organelles = 1.0

func _on_damage_taken(amount: float) -> void:
	_tallies.damage_taken += amount
	_tally_flash.damage_taken = 1.0

func _on_damage_dealt(amount: float) -> void:
	_tallies.damage_dealt += amount
	_tally_flash.damage_dealt = 1.0

func _on_kill() -> void:
	_tallies.kills += 1
	_tally_flash.kills = 1.0

func _on_food_eaten() -> void:
	_tallies.food_eaten += 1
	_tally_flash.food_eaten = 1.0

func _regenerate_alien_text() -> void:
	# Generate random alien designation
	_alien_id = ""
	for i in range(8):
		_alien_id += ALIEN_GLYPHS[randi() % ALIEN_GLYPHS.size()]

	# Classification in alien script
	_classification = ""
	for i in range(12):
		_classification += ALIEN_GLYPHS[randi() % ALIEN_GLYPHS.size()]

func _on_evolution_applied(_mutation: Dictionary) -> void:
	# Glitch effect on evolution
	_glitch_timer = 0.5
	# Regenerate some alien text for variety
	_classification = ""
	for i in range(12):
		_classification += ALIEN_GLYPHS[randi() % ALIEN_GLYPHS.size()]
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _glitch_timer > 0:
		_glitch_timer -= delta

	# Update bead animations
	for key in _tallies.keys():
		var target: float = float(_tallies[key]) if _tallies[key] is int else _tallies[key]
		_bead_positions[key] = lerp(_bead_positions[key], target, delta * 5.0)

		# Decay flash
		if _tally_flash.has(key) and _tally_flash[key] > 0:
			_tally_flash[key] = maxf(0.0, _tally_flash[key] - delta * 2.0)

	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Card background with tech border
	var bg_color := Color(0.02, 0.04, 0.08, 0.85)
	var border_color := Color(0.2, 0.6, 0.8, 0.6)
	var glow_color := Color(0.1, 0.4, 0.6, 0.15)

	# Outer glow
	draw_rect(Rect2(-4, -4, CARD_WIDTH + 8, CARD_HEIGHT + 8), glow_color)

	# Main card body
	draw_rect(Rect2(0, 0, CARD_WIDTH, CARD_HEIGHT), bg_color)

	# Tech border lines
	_draw_tech_border(border_color)

	# Glitch effect overlay
	if _glitch_timer > 0:
		var glitch_alpha: float = _glitch_timer * 0.4
		for i in range(3):
			var y: float = randf() * CARD_HEIGHT
			draw_rect(Rect2(0, y, CARD_WIDTH, 2 + randf() * 4), Color(0.3, 0.8, 1.0, glitch_alpha))

	var y: float = 12.0

	# Header: "SPECIMEN" in alien + English
	var specimen_alien := _make_alien_word(8)
	draw_string(font, Vector2(8, y), specimen_alien, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.7, 0.9, 0.5))
	y += 12
	draw_string(font, Vector2(8, y), "SPECIMEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.9, 1.0, 0.9))
	y += 16

	# Alien ID
	draw_string(font, Vector2(8, y), _alien_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.9, 0.5, 0.8))
	y += 18

	# Separator line
	draw_line(Vector2(8, y), Vector2(CARD_WIDTH - 8, y), Color(0.2, 0.5, 0.7, 0.4), 1.0)
	y += 10

	# Evolution level
	var evo_level: int = GameManager.evolution_level
	draw_string(font, Vector2(8, y), "EVO.LVL", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.6, 0.7))
	y += 12
	var evo_display := "%02d" % evo_level
	draw_string(font, Vector2(8, y), evo_display, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.3, 1.0, 0.5, 0.95))

	# Evolution pips
	for i in range(mini(evo_level, 10)):
		var px: float = 50 + i * 9
		var pip_color := Color(0.3, 0.9, 0.5, 0.7)
		if i >= 5:
			pip_color = Color(0.9, 0.7, 0.2, 0.8)
		draw_rect(Rect2(px, y - 12, 6, 10), pip_color)
	y += 18

	# Sensory level
	var sens_level: int = GameManager.sensory_level
	var sens_tier: Dictionary = GameManager.get_sensory_tier()
	draw_string(font, Vector2(8, y), "SENS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.6, 0.7))
	y += 10
	draw_string(font, Vector2(8, y), sens_tier.get("name", "Unknown"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.5, 1.0, 0.85))
	y += 16

	# Separator
	draw_line(Vector2(8, y), Vector2(CARD_WIDTH - 8, y), Color(0.2, 0.5, 0.7, 0.4), 1.0)
	y += 10

	# Stats section header
	draw_string(font, Vector2(8, y), _make_alien_word(6), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.4, 0.6, 0.8, 0.4))
	y += 10
	draw_string(font, Vector2(8, y), "AUGMENTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.8, 0.9, 0.8))
	y += 14

	# Calculate accumulated stats from mutations
	var accumulated_stats: Dictionary = _calculate_accumulated_stats()

	# Display stats
	var stat_order: Array = ["speed", "attack", "max_health", "armor", "beam_range", "detection", "energy_efficiency", "health_regen", "stealth"]
	for stat_key in stat_order:
		if accumulated_stats.has(stat_key) and accumulated_stats[stat_key] > 0:
			var val: float = accumulated_stats[stat_key]
			var stat_name: String = _get_stat_short_name(stat_key)
			var stat_icon: String = _get_stat_icon(stat_key)

			# Stat row
			var stat_text := "%s %s" % [stat_icon, stat_name]
			draw_string(font, Vector2(8, y), stat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.7, 0.8, 0.7))

			# Value with + sign
			var val_text := "+%.0f%%" % (val * 100.0)
			var val_width: float = font.get_string_size(val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(font, Vector2(CARD_WIDTH - 10 - val_width, y), val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 1.0, 0.5, 0.9))
			y += 12

	# If no stats yet
	if accumulated_stats.is_empty():
		draw_string(font, Vector2(8, y), "-- BASELINE --", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.5, 0.6, 0.5))
		y += 12

	y += 6

	# Active mutations count
	var mut_count: int = GameManager.active_mutations.size()
	if mut_count > 0:
		draw_line(Vector2(8, y), Vector2(CARD_WIDTH - 8, y), Color(0.2, 0.5, 0.7, 0.4), 1.0)
		y += 10
		draw_string(font, Vector2(8, y), "MUTATIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.6, 0.7))
		y += 12

		# List mutation names (scrolling if too many)
		var max_shown: int = 5
		var start_idx: int = 0
		if mut_count > max_shown:
			start_idx = int(_time * 0.5) % (mut_count - max_shown + 1)

		for i in range(mini(mut_count, max_shown)):
			var m: Dictionary = GameManager.active_mutations[start_idx + i]
			var mut_name: String = m.get("name", "Unknown")
			# Truncate long names
			if mut_name.length() > 16:
				mut_name = mut_name.substr(0, 14) + ".."
			draw_string(font, Vector2(10, y), "· " + mut_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.8, 0.9, 0.7))
			y += 10

	# Separator before abacus
	y += 10
	draw_line(Vector2(8, y), Vector2(CARD_WIDTH - 8, y), Color(0.2, 0.5, 0.7, 0.4), 1.0)
	y += 12

	# Alien Abacus section header
	draw_string(font, Vector2(8, y), _make_alien_word(6), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.4, 0.6, 0.8, 0.4))
	y += 10
	draw_string(font, Vector2(8, y), "TALLY RECORD", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.8, 0.9, 0.8))
	y += 16

	# Draw abacus tallies
	y = _draw_abacus_section(font, y)

	# Bottom classification in alien script
	var bottom_y: float = CARD_HEIGHT - 30
	draw_string(font, Vector2(8, bottom_y), _classification, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.3, 0.5, 0.6, 0.4))

	# Bottom scan line effect
	draw_line(Vector2(8, CARD_HEIGHT - 15), Vector2(CARD_WIDTH - 8, CARD_HEIGHT - 15), Color(0.2, 0.5, 0.7, 0.3), 1.0)

func _draw_tech_border(color: Color) -> void:
	var c := color
	var w: float = CARD_WIDTH
	var h: float = CARD_HEIGHT

	# Corner brackets
	var corner_len: float = 12.0
	# Top-left
	draw_line(Vector2(0, 0), Vector2(corner_len, 0), c, 1.5)
	draw_line(Vector2(0, 0), Vector2(0, corner_len), c, 1.5)
	# Top-right
	draw_line(Vector2(w, 0), Vector2(w - corner_len, 0), c, 1.5)
	draw_line(Vector2(w, 0), Vector2(w, corner_len), c, 1.5)
	# Bottom-left
	draw_line(Vector2(0, h), Vector2(corner_len, h), c, 1.5)
	draw_line(Vector2(0, h), Vector2(0, h - corner_len), c, 1.5)
	# Bottom-right
	draw_line(Vector2(w, h), Vector2(w - corner_len, h), c, 1.5)
	draw_line(Vector2(w, h), Vector2(w, h - corner_len), c, 1.5)

	# Animated scan line
	var scan_y: float = fmod(_time * 40.0, h)
	draw_line(Vector2(2, scan_y), Vector2(w - 2, scan_y), Color(c.r, c.g, c.b, 0.15), 1.0)

	# Side tick marks
	for i in range(5):
		var ty: float = 30.0 + i * 50.0
		if ty < h - 20:
			draw_line(Vector2(0, ty), Vector2(4, ty), Color(c.r, c.g, c.b, 0.3), 1.0)
			draw_line(Vector2(w, ty), Vector2(w - 4, ty), Color(c.r, c.g, c.b, 0.3), 1.0)

func _make_alien_word(length: int) -> String:
	var word: String = ""
	for i in range(length):
		word += ALIEN_GLYPHS[randi() % ALIEN_GLYPHS.size()]
	return word

func _calculate_accumulated_stats() -> Dictionary:
	var stats: Dictionary = {}
	for m in GameManager.active_mutations:
		var m_stats: Dictionary = m.get("stat", {})
		for key in m_stats:
			stats[key] = stats.get(key, 0.0) + m_stats[key]
	return stats

func _get_stat_short_name(key: String) -> String:
	match key:
		"speed": return "SPD"
		"attack": return "ATK"
		"max_health": return "HP"
		"armor": return "ARM"
		"beam_range": return "RNG"
		"detection": return "DET"
		"energy_efficiency": return "EFF"
		"health_regen": return "REG"
		"stealth": return "STL"
	return key.substr(0, 3).to_upper()

func _get_stat_icon(key: String) -> String:
	match key:
		"speed": return "⚡"
		"attack": return "⚔"
		"max_health": return "❤"
		"armor": return "🛡"
		"beam_range": return "🎯"
		"detection": return "🔍"
		"energy_efficiency": return "⚗"
		"health_regen": return "💚"
		"stealth": return "👻"
	return "◆"

func _draw_abacus_section(font: Font, start_y: float) -> float:
	var y: float = start_y

	# Define tally rows with display info
	var tally_rows: Array = [
		{"key": "kills", "label": "ELIM", "icon": "⚔", "color": Color(0.9, 0.3, 0.3)},
		{"key": "food_eaten", "label": "CONS", "icon": "◉", "color": Color(0.3, 0.9, 0.5)},
		{"key": "damage_dealt", "label": "DMG+", "icon": "↗", "color": Color(0.9, 0.6, 0.2)},
		{"key": "damage_taken", "label": "DMG-", "icon": "↘", "color": Color(0.8, 0.2, 0.3)},
	]

	var resource_rows: Array = [
		{"key": "nucleotides", "label": "NUC", "color": Color(0.3, 0.7, 1.0)},
		{"key": "amino_acids", "label": "AMI", "color": Color(0.2, 1.0, 0.5)},
		{"key": "lipids", "label": "LIP", "color": Color(1.0, 0.9, 0.3)},
		{"key": "coenzymes", "label": "COE", "color": Color(1.0, 0.5, 0.7)},
		{"key": "organelles", "label": "ORG", "color": Color(0.8, 0.4, 1.0)},
	]

	# Combat tallies
	for row in tally_rows:
		_draw_abacus_row(font, row, y)
		y += 24

	y += 8
	draw_line(Vector2(8, y), Vector2(CARD_WIDTH - 8, y), Color(0.2, 0.4, 0.5, 0.3), 1.0)
	y += 12

	# Resource collection sub-header
	draw_string(font, Vector2(8, y), "COLLECTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.6, 0.7, 0.6))
	y += 14

	# Resource tallies
	for row in resource_rows:
		_draw_abacus_row(font, row, y)
		y += 22

	return y

func _draw_abacus_row(font: Font, row: Dictionary, y: float) -> void:
	var key: String = row.key
	var label: String = row.label
	var color: Color = row.color
	var flash: float = _tally_flash.get(key, 0.0)
	var value: float = _bead_positions.get(key, 0.0)

	# Flash highlight
	if flash > 0:
		var flash_rect := Rect2(6, y - 8, CARD_WIDTH - 12, 18)
		draw_rect(flash_rect, Color(color.r, color.g, color.b, flash * 0.2))

	# Label with alien numeral
	var alien_num := _value_to_alien_numeral(int(value))
	var display_color := Color(color.r, color.g, color.b, 0.8 + flash * 0.2)

	# Icon if present
	var x_offset: float = 8.0
	if row.has("icon"):
		draw_string(font, Vector2(x_offset, y + 2), row.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, display_color)
		x_offset += 14

	# Label
	draw_string(font, Vector2(x_offset, y + 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.6, 0.7, 0.7))

	# Alien numeral
	draw_string(font, Vector2(x_offset + 35, y + 2), alien_num, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.6, 0.7, 0.5))

	# Abacus beads visualization
	var bead_start_x: float = x_offset + 70
	var bead_width: float = CARD_WIDTH - bead_start_x - 40
	_draw_abacus_beads(bead_start_x, y - 4, bead_width, value, color, flash)

	# Numeric value (right-aligned)
	var val_text: String
	if value >= 1000:
		val_text = "%.1fk" % (value / 1000.0)
	elif value == int(value):
		val_text = "%d" % int(value)
	else:
		val_text = "%.0f" % value
	var val_width: float = font.get_string_size(val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(font, Vector2(CARD_WIDTH - 10 - val_width, y + 2), val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, display_color)

func _draw_abacus_beads(x: float, y: float, width: float, value: float, color: Color, flash: float) -> void:
	# Draw abacus rail
	draw_line(Vector2(x, y + 6), Vector2(x + width, y + 6), Color(0.2, 0.3, 0.4, 0.4), 1.0)

	# Calculate bead count (log scale for large values)
	var bead_count: int = 0
	if value > 0:
		bead_count = mini(10, int(log(value + 1) / log(2.0)) + 1)

	var bead_spacing: float = width / 11.0
	var bead_radius: float = 4.0

	# Draw empty bead slots
	for i in range(10):
		var bx: float = x + (i + 0.5) * bead_spacing
		draw_circle(Vector2(bx, y + 6), bead_radius - 1, Color(0.1, 0.15, 0.2, 0.3))

	# Draw filled beads
	for i in range(bead_count):
		var bx: float = x + (i + 0.5) * bead_spacing
		var bead_color := Color(color.r, color.g, color.b, 0.7 + flash * 0.3)

		# Outer glow on flash
		if flash > 0 and i == bead_count - 1:
			draw_circle(Vector2(bx, y + 6), bead_radius + 2, Color(color.r, color.g, color.b, flash * 0.4))

		# Bead body
		draw_circle(Vector2(bx, y + 6), bead_radius, bead_color)

		# Bead highlight
		draw_circle(Vector2(bx - 1, y + 4), bead_radius * 0.4, Color(1.0, 1.0, 1.0, 0.3))

func _value_to_alien_numeral(value: int) -> String:
	# Convert value to alien numeral representation
	if value == 0:
		return ALIEN_NUMERALS[0]

	var result: String = ""
	var remaining: int = value

	# Use a base-10 style representation with alien numerals
	while remaining > 0 and result.length() < 4:
		var digit: int = remaining % 10
		result = ALIEN_NUMERALS[digit] + result
		remaining = remaining / 10

	if value >= 10000:
		result = "+" + result.substr(0, 3)

	return result

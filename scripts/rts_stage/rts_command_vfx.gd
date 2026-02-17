extends Node2D
## Draws command feedback VFX: expanding rings at move/attack targets,
## persistent waypoint chains for shift-queued commands, and attack-move VFX.
## Managed by stage manager, pooled indicators.

var _indicators: Array = []  # [{pos, time, type, color}]
const MAX_INDICATORS: int = 8
const INDICATOR_LIFE: float = 0.8

# Waypoint chains for shift-queued commands
# [{unit: Node2D, positions: Array[Vector2], is_attack_move: bool, time: float}]
var _waypoint_chains: Array = []
const WAYPOINT_CHAIN_MAX: int = 20
const WAYPOINT_DASH_LEN: float = 8.0
const WAYPOINT_GAP_LEN: float = 5.0
const WAYPOINT_DOT_RADIUS: float = 5.0

func add_move_indicator(world_pos: Vector2) -> void:
	_add_indicator(world_pos, "move", Color(0.2, 1.0, 0.4, 0.8))

func add_attack_indicator(world_pos: Vector2) -> void:
	_add_indicator(world_pos, "attack", Color(1.0, 0.3, 0.2, 0.8))

func add_attack_move_ring(world_pos: Vector2) -> void:
	_add_indicator(world_pos, "attack_move", Color(1.0, 0.5, 0.15, 0.9))

func add_gather_indicator(world_pos: Vector2) -> void:
	_add_indicator(world_pos, "gather", Color(0.3, 0.8, 1.0, 0.8))

func add_waypoint_chain(unit: Node2D, positions: Array, is_attack_move: bool = false) -> void:
	## Store a waypoint chain for a unit. Replaces any existing chain for the same unit.
	# Remove existing chain for this unit
	for i in range(_waypoint_chains.size() - 1, -1, -1):
		if _waypoint_chains[i]["unit"] == unit:
			_waypoint_chains.remove_at(i)
	if positions.size() < 1:
		return
	_waypoint_chains.append({
		"unit": unit,
		"positions": positions,
		"is_attack_move": is_attack_move,
		"time": 0.0,
	})
	if _waypoint_chains.size() > WAYPOINT_CHAIN_MAX:
		_waypoint_chains.pop_front()

func clear_waypoint_chain(unit: Node2D) -> void:
	## Remove waypoint chain for a specific unit (new non-shift command).
	for i in range(_waypoint_chains.size() - 1, -1, -1):
		if _waypoint_chains[i]["unit"] == unit:
			_waypoint_chains.remove_at(i)

func _add_indicator(pos: Vector2, type: String, color: Color) -> void:
	_indicators.append({"pos": pos, "time": 0.0, "type": type, "color": color})
	if _indicators.size() > MAX_INDICATORS:
		_indicators.pop_front()

func _process(delta: float) -> void:
	var had_indicators: bool = not _indicators.is_empty()
	var had_chains: bool = not _waypoint_chains.is_empty()
	var i: int = _indicators.size() - 1
	while i >= 0:
		_indicators[i]["time"] += delta
		if _indicators[i]["time"] >= INDICATOR_LIFE:
			_indicators.remove_at(i)
		i -= 1
	# Update waypoint chains: remove dead units or units with empty queues
	i = _waypoint_chains.size() - 1
	while i >= 0:
		var chain: Dictionary = _waypoint_chains[i]
		chain["time"] += delta
		var unit: Node2D = chain["unit"]
		if not is_instance_valid(unit):
			_waypoint_chains.remove_at(i)
		elif "health" in unit and unit.health <= 0:
			_waypoint_chains.remove_at(i)
		elif "_command_queue" in unit and unit._command_queue.is_empty():
			_waypoint_chains.remove_at(i)
		i -= 1
	if had_indicators or not _indicators.is_empty() or had_chains or not _waypoint_chains.is_empty():
		queue_redraw()

func _draw() -> void:
	# Draw indicators (expanding rings)
	for ind in _indicators:
		var t: float = ind["time"] / INDICATOR_LIFE
		var alpha: float = 1.0 - t
		var pos: Vector2 = ind["pos"]
		var c: Color = ind["color"]
		match ind["type"]:
			"move":
				# Expanding green circle with crosshair
				var r: float = 5.0 + t * 15.0
				draw_arc(pos, r, 0, TAU, 16, Color(c.r, c.g, c.b, alpha * 0.6), 1.5)
				# Small crosshair
				var cross_size: float = 4.0 * (1.0 - t)
				draw_line(pos + Vector2(-cross_size, 0), pos + Vector2(cross_size, 0), Color(c.r, c.g, c.b, alpha * 0.8), 1.0)
				draw_line(pos + Vector2(0, -cross_size), pos + Vector2(0, cross_size), Color(c.r, c.g, c.b, alpha * 0.8), 1.0)
			"attack":
				# Expanding red X with ring
				var r: float = 5.0 + t * 20.0
				draw_arc(pos, r, 0, TAU, 12, Color(c.r, c.g, c.b, alpha * 0.5), 2.0)
				var x_size: float = 5.0 * (1.0 - t * 0.5)
				draw_line(pos + Vector2(-x_size, -x_size), pos + Vector2(x_size, x_size), Color(c.r, c.g, c.b, alpha * 0.8), 1.5)
				draw_line(pos + Vector2(x_size, -x_size), pos + Vector2(-x_size, x_size), Color(c.r, c.g, c.b, alpha * 0.8), 1.5)
			"attack_move":
				# Red-orange expanding ring (distinct from regular attack)
				var r: float = 6.0 + t * 22.0
				draw_arc(pos, r, 0, TAU, 16, Color(c.r, c.g, c.b, alpha * 0.6), 2.5)
				# Inner ring
				var r2: float = 3.0 + t * 12.0
				draw_arc(pos, r2, 0, TAU, 12, Color(c.r, c.g, c.b, alpha * 0.4), 1.0)
				# Sword/X icon at center that fades
				if t < 0.6:
					var icon_alpha: float = alpha * 1.2
					var sz: float = 6.0 * (1.0 - t * 0.3)
					# X shape (crossed swords)
					draw_line(pos + Vector2(-sz, -sz), pos + Vector2(sz, sz), Color(1.0, 0.6, 0.2, icon_alpha), 2.0)
					draw_line(pos + Vector2(sz, -sz), pos + Vector2(-sz, sz), Color(1.0, 0.6, 0.2, icon_alpha), 2.0)
					# Sword guard bars (horizontal short lines at center)
					draw_line(pos + Vector2(-sz * 0.4, 0), pos + Vector2(sz * 0.4, 0), Color(1.0, 0.8, 0.3, icon_alpha * 0.7), 1.5)
				# "A" letter briefly visible
				if t < 0.4:
					var a_alpha: float = (0.4 - t) / 0.4
					var font: Font = ThemeDB.fallback_font
					if font:
						draw_string(font, pos + Vector2(-4.0, -12.0), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.7, 0.2, a_alpha * 0.9))
			"gather":
				# Pulsing blue circle
				var r: float = 8.0 + t * 10.0
				draw_arc(pos, r, 0, TAU, 16, Color(c.r, c.g, c.b, alpha * 0.5), 1.5)
				# Arrow pointing down
				var arrow_y: float = 3.0 * (1.0 - t)
				draw_line(pos + Vector2(0, -arrow_y - 3), pos + Vector2(0, arrow_y), Color(c.r, c.g, c.b, alpha * 0.7), 1.5)

	# Draw waypoint chains
	for chain in _waypoint_chains:
		_draw_waypoint_chain(chain)

func _draw_waypoint_chain(chain: Dictionary) -> void:
	var unit: Node2D = chain["unit"]
	if not is_instance_valid(unit):
		return
	var positions: Array = chain["positions"]
	var is_atk: bool = chain["is_attack_move"]
	var anim_time: float = chain["time"]

	# Colors: green for move, red-orange for attack-move
	var line_color: Color = Color(1.0, 0.45, 0.2, 0.35) if is_atk else Color(0.2, 1.0, 0.4, 0.35)
	var dot_color: Color = Color(1.0, 0.5, 0.25, 0.65) if is_atk else Color(0.3, 1.0, 0.5, 0.65)
	var dot_inner: Color = Color(0.15, 0.1, 0.05, 0.8) if is_atk else Color(0.05, 0.12, 0.08, 0.8)
	var num_color: Color = Color(1.0, 0.8, 0.5, 0.9) if is_atk else Color(0.8, 1.0, 0.9, 0.9)

	var prev_pos: Vector2 = unit.global_position
	for i in range(positions.size()):
		var wp: Vector2 = positions[i]
		# Draw dashed line from prev to current waypoint
		_draw_dashed_line(prev_pos, wp, line_color, 1.5, anim_time)
		# Draw numbered circle at waypoint
		draw_circle(wp, WAYPOINT_DOT_RADIUS, dot_color)
		draw_circle(wp, WAYPOINT_DOT_RADIUS - 2.0, dot_inner)
		# Queue number
		var font: Font = ThemeDB.fallback_font
		if font:
			draw_string(font, wp + Vector2(-3.0, 3.5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, num_color)
		prev_pos = wp

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, anim_time: float) -> void:
	var dir: Vector2 = to - from
	var total_len: float = dir.length()
	if total_len < 1.0:
		return
	var norm: Vector2 = dir / total_len
	var segment_len: float = WAYPOINT_DASH_LEN + WAYPOINT_GAP_LEN
	# Animate dash offset for marching-ants effect
	var offset: float = fmod(anim_time * 20.0, segment_len)
	var pos: float = -offset
	while pos < total_len:
		var dash_start: float = maxf(pos, 0.0)
		var dash_end: float = minf(pos + WAYPOINT_DASH_LEN, total_len)
		if dash_end > dash_start:
			draw_line(from + norm * dash_start, from + norm * dash_end, color, width)
		pos += segment_len

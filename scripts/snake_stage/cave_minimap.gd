extends Control
## Cave Minimap — Top-down star-pattern map with fog of war.
## Hubs shown as circles, tunnels as lines. Player as pulsing dot.
## Fog lifts per-hub/tunnel when player enters that area.

const MAP_PADDING: float = 20.0
const PLAYER_DOT_RADIUS: float = 5.0
const HUB_MIN_DRAW_RADIUS: float = 12.0
const TUNNEL_DRAW_WIDTH: float = 4.0
const FOG_COLOR: Color = Color(0.02, 0.03, 0.05, 0.92)
const BORDER_COLOR: Color = Color(0.12, 0.25, 0.35, 0.7)
const GRID_COLOR: Color = Color(0.08, 0.15, 0.2, 0.15)
const LABEL_FONT_SIZE: int = 9

# Biome display colors (brighter versions for minimap visibility)
const BIOME_MAP_COLORS: Dictionary = {
	0: Color(0.3, 0.5, 0.15, 0.6),   # STOMACH - green-yellow
	1: Color(0.7, 0.15, 0.1, 0.6),   # HEART_CHAMBER - red
	2: Color(0.5, 0.3, 0.2, 0.6),    # INTESTINAL_TRACT - pink-brown
	3: Color(0.5, 0.4, 0.5, 0.6),    # LUNG_TISSUE - pink-white
	4: Color(0.5, 0.45, 0.3, 0.6),   # BONE_MARROW - pale yellow
	5: Color(0.5, 0.15, 0.08, 0.6),  # LIVER - dark red-brown
	6: Color(0.2, 0.15, 0.35, 0.6),  # BRAIN - purple-grey
}

const BIOME_NAMES: Dictionary = {
	0: "Stomach",
	1: "Heart",
	2: "Intestine",
	3: "Lung",
	4: "Marrow",
	5: "Liver",
	6: "Brain",
}

# Fog of war state: which hubs/tunnels have been discovered
var _discovered_hubs: Dictionary = {}   # hub_id -> true
var _discovered_tunnels: Dictionary = {} # tunnel_id -> true

# References
var _cave_gen = null  # cave_generator reference
var _player: Node3D = null

# Cached map geometry (computed once from cave data)
var _map_center: Vector2 = Vector2.ZERO  # World XZ center of cave system
var _map_scale: float = 1.0              # World units -> pixel scale
var _hub_circles: Array = []             # [{center: Vector2, radius: float, biome: int, id: int}]
var _tunnel_lines: Array = []            # [{from: Vector2, to: Vector2, id: int}]
var _map_built: bool = false

var _time: float = 0.0
var _current_hub_id: int = -1  # Which hub the player is currently in

func setup(cave_gen, player: Node3D) -> void:
	_cave_gen = cave_gen
	_player = player
	# Spawn hub is always discovered
	_discovered_hubs[0] = true
	call_deferred("_build_map_geometry")

func _build_map_geometry() -> void:
	if not _cave_gen or _cave_gen.hubs.size() == 0:
		return

	# Compute bounding box of all hubs in XZ plane
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF

	for hub in _cave_gen.hubs:
		min_x = minf(min_x, hub.position.x - hub.radius)
		max_x = maxf(max_x, hub.position.x + hub.radius)
		min_z = minf(min_z, hub.position.z - hub.radius)
		max_z = maxf(max_z, hub.position.z + hub.radius)

	_map_center = Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)
	var world_width: float = max_x - min_x
	var world_height: float = max_z - min_z

	# Scale to fit inside the control with padding
	var draw_w: float = size.x - MAP_PADDING * 2
	var draw_h: float = size.y - MAP_PADDING * 2
	if draw_w <= 0 or draw_h <= 0:
		return
	_map_scale = minf(draw_w / maxf(world_width, 1.0), draw_h / maxf(world_height, 1.0))

	# Cache hub circles
	_hub_circles.clear()
	for hub in _cave_gen.hubs:
		var screen_pos: Vector2 = _world_to_map(Vector2(hub.position.x, hub.position.z))
		var screen_radius: float = maxf(hub.radius * _map_scale, HUB_MIN_DRAW_RADIUS)
		_hub_circles.append({
			"center": screen_pos,
			"radius": screen_radius,
			"biome": hub.biome,
			"id": hub.id,
		})

	# Cache tunnel lines (simplified: just from hub center to hub center)
	_tunnel_lines.clear()
	for tunnel in _cave_gen.tunnels:
		var hub_a = _cave_gen.hubs[tunnel.hub_a]
		var hub_b = _cave_gen.hubs[tunnel.hub_b]
		var from_pos: Vector2 = _world_to_map(Vector2(hub_a.position.x, hub_a.position.z))
		var to_pos: Vector2 = _world_to_map(Vector2(hub_b.position.x, hub_b.position.z))
		_tunnel_lines.append({
			"from": from_pos,
			"to": to_pos,
			"id": tunnel.id,
		})

	_map_built = true

func _world_to_map(world_xz: Vector2) -> Vector2:
	## Convert world XZ position to minimap pixel position.
	var offset: Vector2 = world_xz - _map_center
	var pixel: Vector2 = Vector2(offset.x, offset.y) * _map_scale
	return Vector2(size.x * 0.5 + pixel.x, size.y * 0.5 + pixel.y)

func _process(delta: float) -> void:
	_time += delta

	# Update discovery based on player position
	if _player and _cave_gen:
		_update_discovery()

	queue_redraw()

func _update_discovery() -> void:
	if not _player or not _cave_gen:
		return

	var pos: Vector3 = _player.global_position

	# Check which hub player is in
	_current_hub_id = -1
	for hub in _cave_gen.hubs:
		var flat_dist: float = Vector2(pos.x - hub.position.x, pos.z - hub.position.z).length()
		if flat_dist < hub.radius:
			_discovered_hubs[hub.id] = true
			_current_hub_id = hub.id
			break

	# Check which tunnel player is in (generous proximity)
	for tunnel in _cave_gen.tunnels:
		if tunnel.id in _discovered_tunnels:
			continue
		for path_point in tunnel.path:
			var dist: float = pos.distance_to(path_point)
			if dist < tunnel.width * 0.6:
				_discovered_tunnels[tunnel.id] = true
				# Also discover the hubs at both ends
				_discovered_hubs[tunnel.hub_a] = true
				_discovered_hubs[tunnel.hub_b] = true
				break

func _draw() -> void:
	if not _map_built:
		return

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.04, 0.85))

	# Subtle grid
	_draw_grid()

	# Draw tunnels (behind hubs)
	for tl in _tunnel_lines:
		var discovered: bool = tl.id in _discovered_tunnels
		if discovered:
			# Both endpoint hubs must also be discovered to draw the tunnel
			var color: Color = Color(0.2, 0.35, 0.3, 0.5)
			draw_line(tl.from, tl.to, color, TUNNEL_DRAW_WIDTH, true)
		else:
			# Check if EITHER endpoint hub is discovered (show as hint)
			var tunnel = _cave_gen.tunnels[tl.id]
			var a_known: bool = tunnel.hub_a in _discovered_hubs
			var b_known: bool = tunnel.hub_b in _discovered_hubs
			if a_known or b_known:
				# Draw a faded stub from the known hub
				var hint_color: Color = Color(0.15, 0.2, 0.2, 0.2)
				var mid: Vector2 = (tl.from + tl.to) * 0.5
				if a_known:
					draw_line(tl.from, mid, hint_color, TUNNEL_DRAW_WIDTH * 0.5, true)
				if b_known:
					draw_line(tl.to, mid, hint_color, TUNNEL_DRAW_WIDTH * 0.5, true)

	# Draw hubs
	for hc in _hub_circles:
		var discovered: bool = hc.id in _discovered_hubs
		if discovered:
			var biome_color: Color = BIOME_MAP_COLORS.get(hc.biome, Color(0.3, 0.3, 0.3, 0.5))
			# Filled circle
			draw_circle(hc.center, hc.radius, biome_color)
			# Border
			var border_col: Color = biome_color.lightened(0.3)
			border_col.a = 0.7
			_draw_circle_outline(hc.center, hc.radius, border_col, 1.5)
			# Biome label
			var label: String = BIOME_NAMES.get(hc.biome, "?")
			var font: Font = UIConstants.get_display_font()
			var label_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
			var label_pos: Vector2 = hc.center - label_size * 0.5 + Vector2(0, label_size.y * 0.3)
			draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color(0.8, 0.9, 0.8, 0.7))
		else:
			# Undiscovered: just a dim outline with "?"
			_draw_circle_outline(hc.center, hc.radius, Color(0.1, 0.15, 0.15, 0.25), 1.0)
			var font: Font = UIConstants.get_display_font()
			var q_size: Vector2 = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
			draw_string(font, hc.center - q_size * 0.5 + Vector2(0, q_size.y * 0.3), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color(0.3, 0.4, 0.4, 0.3))

	# Draw player dot
	if _player and _cave_gen:
		var player_map_pos: Vector2 = _world_to_map(Vector2(_player.global_position.x, _player.global_position.z))
		# Clamp to map bounds
		player_map_pos.x = clampf(player_map_pos.x, MAP_PADDING, size.x - MAP_PADDING)
		player_map_pos.y = clampf(player_map_pos.y, MAP_PADDING, size.y - MAP_PADDING)

		# Pulsing glow
		var pulse: float = 0.6 + 0.4 * sin(_time * 4.0)
		draw_circle(player_map_pos, PLAYER_DOT_RADIUS + 3.0, Color(0.2, 0.8, 0.5, 0.15 * pulse))
		draw_circle(player_map_pos, PLAYER_DOT_RADIUS + 1.5, Color(0.3, 0.9, 0.6, 0.25 * pulse))
		draw_circle(player_map_pos, PLAYER_DOT_RADIUS, Color(0.4, 1.0, 0.7, 0.9))

		# Direction indicator (small line showing facing direction)
		if _player.has_method("get_forward_direction"):
			var fwd: Vector3 = _player.get_forward_direction()
			var fwd_2d: Vector2 = Vector2(fwd.x, fwd.z).normalized() * (PLAYER_DOT_RADIUS + 4.0)
			draw_line(player_map_pos, player_map_pos + fwd_2d, Color(0.5, 1.0, 0.8, 0.8), 2.0, true)

	# Border frame
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.5)

	# Title
	var font: Font = UIConstants.get_display_font()
	draw_string(font, Vector2(8, 14), "NEURAL MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.6, 0.5, 0.6))

	# Discovery counter
	var discovered_count: int = _discovered_hubs.size()
	var total_count: int = _cave_gen.hubs.size() if _cave_gen else 0
	var counter_text: String = "%d/%d" % [discovered_count, total_count]
	draw_string(font, Vector2(size.x - 40, 14), counter_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.7, 0.6, 0.6))

func _draw_grid() -> void:
	# Subtle grid lines for visual reference
	var step: float = 50.0  # pixels between grid lines
	var x: float = fmod(size.x * 0.5, step)
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 0.5)
		x += step
	var y: float = fmod(size.y * 0.5, step)
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR, 0.5)
		y += step

func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float = 1.0) -> void:
	var segments: int = 32
	var prev: Vector2 = center + Vector2(radius, 0)
	for i in range(1, segments + 1):
		var angle: float = TAU * float(i) / segments
		var next: Vector2 = center + Vector2(cos(angle) * radius, sin(angle) * radius)
		draw_line(prev, next, color, width, true)
		prev = next

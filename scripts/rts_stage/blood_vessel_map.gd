extends Node2D
## Blood Vessel map: Elongated oval arena with 3 horizontal lanes connected by
## 4 vertical capillary passages. Resources at lane intersections.
## Visual theme: dark crimson with pulsing vessel walls and flowing red blood cells.

const MAP_HALF_W: float = 6000.0
const MAP_HALF_H: float = 2000.0
const LANE_WIDTH: float = 600.0
const CAPILLARY_WIDTH: float = 400.0
const NUM_AMBIENT_PARTICLES: int = 120

var _time: float = 0.0

# Spawn positions for 4 factions
var spawn_positions: Array[Vector2] = []

# References to spawned entities
var resource_nodes: Array[Node2D] = []
var titan_corpses: Array[Node2D] = []
var obstacles: Array[Node2D] = []
var npc_creatures: Array[Node2D] = []

# Blood cell particles (flowing left-to-right)
var _blood_cells: Array = []

# Lane Y positions
const LANE_Y: Array = [-1200.0, 0.0, 1200.0]
# Capillary X positions
const CAPILLARY_X: Array = [-3000.0, -1000.0, 1000.0, 3000.0]

# Wall segments (rectangles that block movement between lanes except at capillaries)
var _wall_segments: Array = []

# === MAP INTERFACE ===

func get_map_name() -> String:
	return "Blood Vessel"

func get_map_description() -> String:
	return "Elongated arena with 3 lanes connected by capillary passages"

func get_map_bounds_type() -> String:
	return "rect"

func get_map_radius() -> float:
	return MAP_HALF_W  # Approximate for systems that expect a radius

func get_map_rect() -> Rect2:
	return Rect2(-MAP_HALF_W, -MAP_HALF_H, MAP_HALF_W * 2.0, MAP_HALF_H * 2.0)

func get_map_polygon() -> PackedVector2Array:
	return PackedVector2Array()

func get_spawn_positions() -> Array:
	return spawn_positions

func get_background_color() -> Color:
	return Color(0.08, 0.02, 0.02)

func get_particle_colors() -> Array:
	return [Color(0.8, 0.15, 0.1), Color(0.6, 0.08, 0.05), Color(0.9, 0.3, 0.2)]

func get_nav_polygon() -> PackedVector2Array:
	## Returns rectangular outline for navigation baking.
	var inset: float = 100.0
	return PackedVector2Array([
		Vector2(-MAP_HALF_W + inset, -MAP_HALF_H + inset),
		Vector2(MAP_HALF_W - inset, -MAP_HALF_H + inset),
		Vector2(MAP_HALF_W - inset, MAP_HALF_H - inset),
		Vector2(-MAP_HALF_W + inset, MAP_HALF_H - inset),
	])

func _get_resource_layout() -> Array:
	return []

func _get_obstacle_layout() -> Array:
	return []

func _get_terrain_zone_layout() -> Array:
	## 4 elevated ridges along vessel walls
	return [
		{"center": Vector2(-4000, -600), "radius": 250.0, "elevation": 1},
		{"center": Vector2(4000, -600), "radius": 250.0, "elevation": 1},
		{"center": Vector2(-4000, 600), "radius": 250.0, "elevation": 1},
		{"center": Vector2(4000, 600), "radius": 250.0, "elevation": 1},
	]

# === INITIALIZATION ===

func _ready() -> void:
	# 4 spawn positions: 2 left, 2 right
	spawn_positions = [
		Vector2(-5000, -1200),  # Player (top-left)
		Vector2(5000, -1200),   # Swarm (top-right)
		Vector2(5000, 1200),    # Bulwark (bottom-right)
		Vector2(-5000, 1200),   # Predator (bottom-left)
	]

	# Build wall segments between lanes (excluding capillary openings)
	_build_wall_segments()

	# Generate blood cell particles
	var prng := RandomNumberGenerator.new()
	prng.seed = 88
	for i in range(NUM_AMBIENT_PARTICLES):
		var lane_idx: int = prng.randi_range(0, 2)
		var lane_y: float = LANE_Y[lane_idx]
		var px: float = prng.randf_range(-MAP_HALF_W * 0.95, MAP_HALF_W * 0.95)
		var py: float = lane_y + prng.randf_range(-LANE_WIDTH * 0.4, LANE_WIDTH * 0.4)
		_blood_cells.append({
			"pos": Vector2(px, py),
			"speed": prng.randf_range(15.0, 45.0),
			"size": prng.randf_range(3.0, 8.0),
			"alpha": prng.randf_range(0.04, 0.12),
			"wobble_phase": prng.randf() * TAU,
			"wobble_freq": prng.randf_range(0.3, 1.0),
			"type": prng.randi_range(0, 1),  # 0=disc, 1=biconcave
		})

func _build_wall_segments() -> void:
	## Create wall obstacle data between lanes.
	## Walls run horizontally between lane_y[-1200] and lane_y[0], and between lane_y[0] and lane_y[1200].
	## Gaps at each capillary X position.
	var wall_y_pairs: Array = [
		# Between top lane and middle lane: wall at y=-600
		{"y": -600.0, "half_h": 300.0 - LANE_WIDTH * 0.5 * 0.5},
		# Between middle lane and bottom lane: wall at y=+600
		{"y": 600.0, "half_h": 300.0 - LANE_WIDTH * 0.5 * 0.5},
	]
	for wp in wall_y_pairs:
		# Walk from left edge to right edge, skipping capillary gaps
		var segments: Array = _compute_wall_spans(-MAP_HALF_W + 200, MAP_HALF_W - 200)
		for seg in segments:
			_wall_segments.append({
				"x_start": seg[0],
				"x_end": seg[1],
				"y": wp["y"],
				"half_h": wp["half_h"],
			})

func _compute_wall_spans(x_min: float, x_max: float) -> Array:
	## Returns array of [x_start, x_end] wall spans, with gaps at capillary positions.
	var spans: Array = []
	var sorted_caps: Array = CAPILLARY_X.duplicate()
	sorted_caps.sort()
	var cursor: float = x_min
	for cx in sorted_caps:
		var gap_start: float = cx - CAPILLARY_WIDTH * 0.5
		var gap_end: float = cx + CAPILLARY_WIDTH * 0.5
		if cursor < gap_start:
			spans.append([cursor, gap_start])
		cursor = gap_end
	if cursor < x_max:
		spans.append([cursor, x_max])
	return spans

# === RESOURCE SPAWNING ===

func spawn_resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 456

	# 1. Starter resources near each spawn (4 per spawn, 200u radius)
	for si in range(spawn_positions.size()):
		var sp: Vector2 = spawn_positions[si]
		for ri in range(4):
			var angle: float = TAU * float(ri) / 4.0 + rng.randf_range(-0.4, 0.4)
			var dist: float = rng.randf_range(120.0, 250.0)
			var pos: Vector2 = sp + Vector2(cos(angle) * dist, sin(angle) * dist)
			var node: Node2D = _create_resource_node(100 + si * 10 + ri, 150)
			node.global_position = pos
			add_child(node)
			resource_nodes.append(node)

	# 2. Rich resource nodes at lane-capillary intersections (6 key positions)
	var intersection_idx: int = 0
	for cx in CAPILLARY_X:
		for ly in LANE_Y:
			# Skip corners near spawns
			if absf(cx) > 4500:
				continue
			var pos: Vector2 = Vector2(cx, ly) + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
			var amount: int = 300 if absf(cx) < 2000 else 200
			var node: Node2D = _create_resource_node(intersection_idx, amount)
			node.global_position = pos
			add_child(node)
			resource_nodes.append(node)
			intersection_idx += 1

	# 3. Titan corpses in center lane
	for i in range(6):
		var tx: float = lerpf(-3500.0, 3500.0, float(i) / 5.0)
		var ty: float = LANE_Y[rng.randi_range(0, 2)]
		var titan: Node2D = _create_titan_corpse(i)
		titan.global_position = Vector2(tx + rng.randf_range(-200, 200), ty + rng.randf_range(-100, 100))
		add_child(titan)
		titan_corpses.append(titan)

	# 4. Scattered resource caches along lanes
	for i in range(25):
		var lane_idx: int = rng.randi_range(0, 2)
		var px: float = rng.randf_range(-MAP_HALF_W * 0.85, MAP_HALF_W * 0.85)
		var py: float = LANE_Y[lane_idx] + rng.randf_range(-LANE_WIDTH * 0.3, LANE_WIDTH * 0.3)
		var pos: Vector2 = Vector2(px, py)
		# Avoid spawn areas
		var too_close: bool = false
		for sp in spawn_positions:
			if pos.distance_to(sp) < 400.0:
				too_close = true
				break
		if too_close:
			continue
		var node: Node2D = _create_resource_node(200 + i, rng.randi_range(50, 120))
		node.global_position = pos
		add_child(node)
		resource_nodes.append(node)

	# 5. NPC danger pockets at capillary chokepoints
	_spawn_npc_pockets(rng)

	# 6. Wall obstacles (physics bodies blocking between lanes)
	_spawn_wall_obstacles()

func _spawn_npc_pockets(rng: RandomNumberGenerator) -> void:
	var NpcCreature := preload("res://scripts/rts_stage/npc_creature.gd")
	# Place NPC guards at 2 center capillaries
	for ci in [1, 2]:  # -1000, +1000
		var cx: float = CAPILLARY_X[ci]
		for li in range(2):  # between lanes
			var gy: float = [-600.0, 600.0][li]
			var pocket_center: Vector2 = Vector2(cx, gy)
			var pocket_size: int = rng.randi_range(2, 3)
			for pi in range(pocket_size):
				var offset: Vector2 = Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50))
				var creature: CharacterBody2D = NpcCreature.new()
				creature.name = "NPC_%d_%d_%d" % [ci, li, pi]
				var ctype: int = 0 if pi > 0 else 1
				creature.global_position = pocket_center + offset
				add_child(creature)
				creature.setup(ctype, pocket_center)
				creature.setup_camp_guard(pocket_center)
				creature.died.connect(_on_npc_died)
				npc_creatures.append(creature)
			# Rich reward at pocket center
			var reward: Node2D = _create_resource_node(400 + ci * 10 + li, 250)
			reward.global_position = pocket_center
			add_child(reward)
			resource_nodes.append(reward)

func _spawn_wall_obstacles() -> void:
	## Create physics wall obstacles between lanes (except at capillaries).
	var obs_idx: int = 0
	for ws in _wall_segments:
		var x_start: float = ws["x_start"]
		var x_end: float = ws["x_end"]
		var wy: float = ws["y"]
		var half_h: float = ws["half_h"]
		var segment_len: float = x_end - x_start
		# Place obstacles every ~200 units along the wall segment
		var count: int = maxi(1, int(segment_len / 200.0))
		for i in range(count):
			var frac: float = (float(i) + 0.5) / float(count)
			var wx: float = lerpf(x_start, x_end, frac)
			var obs := StaticBody2D.new()
			obs.name = "WallObs_%d" % obs_idx
			obs.global_position = Vector2(wx, wy)
			obs.add_to_group("rts_obstacles")
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(minf(200.0, segment_len / count), half_h * 2.0)
			shape.shape = rect
			obs.add_child(shape)
			add_child(obs)
			obstacles.append(obs)
			obs_idx += 1

func _on_npc_died(_creature: Node2D) -> void:
	npc_creatures.erase(_creature)

func _create_titan_corpse(index: int) -> Node2D:
	var tc: Node2D = preload("res://scripts/rts_stage/titan_corpse.gd").new()
	tc.name = "TitanCorpse_%d" % index
	tc.add_to_group("rts_resources")
	tc.add_to_group("titan_corpses")
	return tc

func _create_resource_node(index: int, biomass_amount: int = 200) -> Node2D:
	var rn: Node2D = preload("res://scripts/rts_stage/resource_node.gd").new()
	rn.name = "ResourceNode_%d" % index
	rn.biomass_remaining = biomass_amount
	rn.max_biomass = biomass_amount
	rn.add_to_group("rts_resources")
	rn.add_to_group("resource_nodes")
	return rn

# === BOUNDS ===

func is_within_bounds(pos: Vector2) -> bool:
	var r: Rect2 = get_map_rect()
	return r.grow(-10.0).has_point(pos)

func clamp_to_bounds(pos: Vector2) -> Vector2:
	var r: Rect2 = get_map_rect()
	return Vector2(
		clampf(pos.x, r.position.x + 10.0, r.end.x - 10.0),
		clampf(pos.y, r.position.y + 10.0, r.end.y - 10.0)
	)

# === RENDERING ===

func _process(delta: float) -> void:
	_time += delta
	_update_blood_cells(delta)
	queue_redraw()

func _update_blood_cells(delta: float) -> void:
	for p in _blood_cells:
		# Flow left-to-right with wobble
		var wobble_y: float = sin(_time * p["wobble_freq"] + p["wobble_phase"]) * 5.0
		p["pos"] += Vector2(p["speed"] * delta, wobble_y * delta)
		# Wrap around when leaving right edge
		if p["pos"].x > MAP_HALF_W * 0.96:
			p["pos"].x = -MAP_HALF_W * 0.90

func _draw() -> void:
	# 1. Background fill (dark crimson)
	var bg_color: Color = get_background_color()
	draw_rect(Rect2(-MAP_HALF_W, -MAP_HALF_H, MAP_HALF_W * 2, MAP_HALF_H * 2), bg_color)

	# 2. Lane floors (slightly lighter)
	var lane_color := Color(0.12, 0.03, 0.03)
	for ly in LANE_Y:
		draw_rect(Rect2(-MAP_HALF_W + 50, ly - LANE_WIDTH * 0.5, MAP_HALF_W * 2 - 100, LANE_WIDTH), lane_color)

	# 3. Capillary passages (vertical connections)
	var cap_color := Color(0.10, 0.025, 0.025)
	for cx in CAPILLARY_X:
		draw_rect(Rect2(cx - CAPILLARY_WIDTH * 0.5, -MAP_HALF_H + 50, CAPILLARY_WIDTH, MAP_HALF_H * 2 - 100), cap_color)

	# 4. Vessel walls with pulsing red-pink sine wave
	_draw_vessel_walls()

	# 5. Wall segments between lanes (visual)
	var wall_color := Color(0.15, 0.04, 0.04, 0.6)
	for ws in _wall_segments:
		var x_start: float = ws["x_start"]
		var x_end: float = ws["x_end"]
		var wy: float = ws["y"]
		var hh: float = ws["half_h"]
		draw_rect(Rect2(x_start, wy - hh, x_end - x_start, hh * 2), wall_color)
		# Wall edge glow
		var edge_col := Color(0.3, 0.08, 0.08, 0.3)
		draw_line(Vector2(x_start, wy - hh), Vector2(x_end, wy - hh), edge_col, 2.0)
		draw_line(Vector2(x_start, wy + hh), Vector2(x_end, wy + hh), edge_col, 2.0)

	# 6. Blood cell particles
	for p in _blood_cells:
		var pos: Vector2 = p["pos"]
		var sz: float = p["size"]
		var alpha: float = p["alpha"]
		var col := Color(0.7, 0.1, 0.08, alpha)
		match p["type"]:
			0:  # disc (red blood cell)
				draw_circle(pos, sz, col)
				# Inner dimple for biconcave look
				draw_circle(pos, sz * 0.4, Color(0.5, 0.06, 0.05, alpha * 0.5))
			1:  # elongated rod
				var rod_dir := Vector2(1.0, sin(_time * 0.3 + pos.y * 0.01) * 0.2).normalized()
				draw_line(pos - rod_dir * sz, pos + rod_dir * sz, col, maxf(sz * 0.6, 1.0))

	# 7. Outer boundary
	var boundary := Rect2(-MAP_HALF_W, -MAP_HALF_H, MAP_HALF_W * 2, MAP_HALF_H * 2)
	var border_color := Color(0.5, 0.15, 0.1, 0.5)
	# Top
	draw_line(Vector2(boundary.position.x, boundary.position.y), Vector2(boundary.end.x, boundary.position.y), border_color, 4.0)
	# Bottom
	draw_line(Vector2(boundary.position.x, boundary.end.y), Vector2(boundary.end.x, boundary.end.y), border_color, 4.0)
	# Left
	draw_line(Vector2(boundary.position.x, boundary.position.y), Vector2(boundary.position.x, boundary.end.y), border_color, 4.0)
	# Right
	draw_line(Vector2(boundary.end.x, boundary.position.y), Vector2(boundary.end.x, boundary.end.y), border_color, 4.0)
	# Outer glow
	var glow_color := Color(0.3, 0.08, 0.05, 0.15)
	draw_line(Vector2(boundary.position.x - 4, boundary.position.y - 4), Vector2(boundary.end.x + 4, boundary.position.y - 4), glow_color, 8.0)
	draw_line(Vector2(boundary.position.x - 4, boundary.end.y + 4), Vector2(boundary.end.x + 4, boundary.end.y + 4), glow_color, 8.0)
	draw_line(Vector2(boundary.position.x - 4, boundary.position.y - 4), Vector2(boundary.position.x - 4, boundary.end.y + 4), glow_color, 8.0)
	draw_line(Vector2(boundary.end.x + 4, boundary.position.y - 4), Vector2(boundary.end.x + 4, boundary.end.y + 4), glow_color, 8.0)

	# 8. Spawn zone indicators
	for i in range(spawn_positions.size()):
		var sp: Vector2 = spawn_positions[i]
		var fc: Color = FactionData.get_faction_color(i)
		draw_arc(sp, 100.0, 0, TAU, 32, Color(fc.r, fc.g, fc.b, 0.15), 2.0)

func _draw_vessel_walls() -> void:
	## Draw pulsing organic vessel wall edges along the top and bottom.
	var pulse: float = 0.5 + 0.5 * sin(_time * 1.2)
	var wall_base := Color(0.25, 0.06, 0.05, 0.4)
	var wall_glow := Color(0.5 + 0.2 * pulse, 0.1, 0.08, 0.2 + 0.1 * pulse)
	var segments: int = 80
	# Top wall
	for i in range(segments):
		var frac: float = float(i) / float(segments)
		var x: float = lerpf(-MAP_HALF_W, MAP_HALF_W, frac)
		var x_next: float = lerpf(-MAP_HALF_W, MAP_HALF_W, float(i + 1) / float(segments))
		var wave: float = sin(_time * 0.8 + frac * TAU * 3.0) * 15.0
		var wave_next: float = sin(_time * 0.8 + float(i + 1) / float(segments) * TAU * 3.0) * 15.0
		var y_top: float = -MAP_HALF_H + 30.0 + wave
		var y_top_next: float = -MAP_HALF_H + 30.0 + wave_next
		draw_line(Vector2(x, y_top), Vector2(x_next, y_top_next), wall_glow, 6.0)
		draw_line(Vector2(x, y_top - 5), Vector2(x_next, y_top_next - 5), wall_base, 3.0)
	# Bottom wall
	for i in range(segments):
		var frac: float = float(i) / float(segments)
		var x: float = lerpf(-MAP_HALF_W, MAP_HALF_W, frac)
		var x_next: float = lerpf(-MAP_HALF_W, MAP_HALF_W, float(i + 1) / float(segments))
		var wave: float = sin(_time * 0.8 + frac * TAU * 3.0 + PI) * 15.0
		var wave_next: float = sin(_time * 0.8 + float(i + 1) / float(segments) * TAU * 3.0 + PI) * 15.0
		var y_bot: float = MAP_HALF_H - 30.0 + wave
		var y_bot_next: float = MAP_HALF_H - 30.0 + wave_next
		draw_line(Vector2(x, y_bot), Vector2(x_next, y_bot_next), wall_glow, 6.0)
		draw_line(Vector2(x, y_bot + 5), Vector2(x_next, y_bot_next + 5), wall_base, 3.0)

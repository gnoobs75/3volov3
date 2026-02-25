extends Node2D
## Brain Cortex map: Irregular blob ~10000x10000 shaped like brain folds.
## Central plateau with 6 gyri (ridges) at edges and narrow sulci (valleys) between them.
## Visual theme: grey-pink neural tissue with synapse sparks and neurotransmitter particles.

const MAP_EXTENT: float = 5000.0  # Half-extent of the bounding box
const CENTRAL_RADIUS: float = 2500.0
const GYRUS_RADIUS: float = 1500.0
const SULCUS_WIDTH: float = 400.0
const NUM_GYRI: int = 6
const NUM_AMBIENT_PARTICLES: int = 100
const NUM_SYNAPSE_SPARKS: int = 15

var _time: float = 0.0

# Boundary polygon (brain-fold shape with ~16 vertices)
var _boundary_polygon: PackedVector2Array = PackedVector2Array()

# Spawn positions for 4 factions
var spawn_positions: Array[Vector2] = []

# References to spawned entities
var resource_nodes: Array[Node2D] = []
var titan_corpses: Array[Node2D] = []
var obstacles: Array[Node2D] = []
var npc_creatures: Array[Node2D] = []

# Gyri data: {center, radius, angle}
var _gyri: Array = []

# Neural tissue decoration
var _neural_arcs: Array = []  # [{center, radius, start_angle, sweep}]
var _neurotransmitters: Array = []  # [{pos, vel, size, alpha, color_idx}]
var _synapse_sparks: Array = []  # [{pos, phase, speed, intensity}]
var _dendrite_clusters: Array = []  # [{pos, radius, branches}]

# === MAP INTERFACE ===

func get_map_name() -> String:
	return "Brain Cortex"

func get_map_description() -> String:
	return "Irregular brain-fold arena with central plateau and 6 ridge extensions"

func get_map_bounds_type() -> String:
	return "polygon"

func get_map_radius() -> float:
	return MAP_EXTENT + GYRUS_RADIUS  # Approximate for radius-based systems

func get_map_rect() -> Rect2:
	return Rect2(-MAP_EXTENT - GYRUS_RADIUS, -MAP_EXTENT - GYRUS_RADIUS,
		(MAP_EXTENT + GYRUS_RADIUS) * 2, (MAP_EXTENT + GYRUS_RADIUS) * 2)

func get_map_polygon() -> PackedVector2Array:
	return _boundary_polygon

func get_spawn_positions() -> Array:
	return spawn_positions

func get_background_color() -> Color:
	return Color(0.06, 0.04, 0.05)

func get_particle_colors() -> Array:
	return [Color(0.6, 0.4, 0.7), Color(0.4, 0.6, 0.8), Color(0.8, 0.5, 0.6)]

func get_nav_polygon() -> PackedVector2Array:
	## Shrink boundary polygon slightly for navigation.
	var shrunk := PackedVector2Array()
	for v in _boundary_polygon:
		var inward: Vector2 = -v.normalized() * 100.0
		shrunk.append(v + inward)
	return shrunk

func _get_resource_layout() -> Array:
	return []

func _get_obstacle_layout() -> Array:
	return []

func _get_terrain_zone_layout() -> Array:
	## Central plateau + elevated gyri edges
	var zones: Array = [
		{"center": Vector2.ZERO, "radius": CENTRAL_RADIUS * 0.6, "elevation": 2},
	]
	for g in _gyri:
		zones.append({
			"center": g["center"],
			"radius": g["radius"] * 0.4,
			"elevation": 1,
		})
	return zones

# === INITIALIZATION ===

func _ready() -> void:
	# Build gyri (6 semicircular bumps at 60-degree intervals around the center)
	for i in range(NUM_GYRI):
		var angle: float = TAU * float(i) / float(NUM_GYRI)
		var gyrus_center: Vector2 = Vector2(cos(angle), sin(angle)) * (MAP_EXTENT - 200.0)
		_gyri.append({
			"center": gyrus_center,
			"radius": GYRUS_RADIUS,
			"angle": angle,
		})

	# Build boundary polygon (~16+ vertices forming brain-fold edges)
	_build_boundary_polygon()

	# Spawn positions at 4 corners of the brain boundary
	var corner_angles: Array = [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]
	for i in range(4):
		var ca: float = corner_angles[i]
		# Place spawns in the sulci (valleys between gyri)
		var spawn_dist: float = MAP_EXTENT * 0.7
		spawn_positions.append(Vector2(cos(ca) * spawn_dist, sin(ca) * spawn_dist))

	# Generate neural arc decorations
	var prng := RandomNumberGenerator.new()
	prng.seed = 99
	for i in range(30):
		var arc_center: Vector2 = Vector2(
			prng.randf_range(-MAP_EXTENT * 0.7, MAP_EXTENT * 0.7),
			prng.randf_range(-MAP_EXTENT * 0.7, MAP_EXTENT * 0.7)
		)
		_neural_arcs.append({
			"center": arc_center,
			"radius": prng.randf_range(200.0, 800.0),
			"start_angle": prng.randf() * TAU,
			"sweep": prng.randf_range(PI * 0.3, PI * 1.2),
		})

	# Generate neurotransmitter particles
	for i in range(NUM_AMBIENT_PARTICLES):
		var pos: Vector2 = Vector2(
			prng.randf_range(-MAP_EXTENT * 0.8, MAP_EXTENT * 0.8),
			prng.randf_range(-MAP_EXTENT * 0.8, MAP_EXTENT * 0.8)
		)
		var vel_angle: float = prng.randf() * TAU
		var speed: float = prng.randf_range(3.0, 12.0)
		_neurotransmitters.append({
			"pos": pos,
			"vel": Vector2(cos(vel_angle) * speed, sin(vel_angle) * speed),
			"size": prng.randf_range(1.0, 3.5),
			"alpha": prng.randf_range(0.03, 0.08),
			"color_idx": prng.randi_range(0, 2),
			"wobble_phase": prng.randf() * TAU,
			"wobble_freq": prng.randf_range(0.4, 1.5),
		})

	# Generate synapse spark locations
	for i in range(NUM_SYNAPSE_SPARKS):
		_synapse_sparks.append({
			"pos": Vector2(
				prng.randf_range(-MAP_EXTENT * 0.7, MAP_EXTENT * 0.7),
				prng.randf_range(-MAP_EXTENT * 0.7, MAP_EXTENT * 0.7)
			),
			"phase": prng.randf() * TAU,
			"speed": prng.randf_range(1.5, 4.0),
			"intensity": prng.randf_range(0.3, 1.0),
		})

	# Generate dendrite obstacle clusters
	for i in range(12):
		var pos: Vector2 = Vector2(
			prng.randf_range(-MAP_EXTENT * 0.6, MAP_EXTENT * 0.6),
			prng.randf_range(-MAP_EXTENT * 0.6, MAP_EXTENT * 0.6)
		)
		# Skip if too close to center or spawns
		if pos.length() < 800.0:
			continue
		var too_close: bool = false
		for sp in spawn_positions:
			if pos.distance_to(sp) < 600.0:
				too_close = true
				break
		if too_close:
			continue
		var branches: Array = []
		var num_branches: int = prng.randi_range(3, 6)
		for b in range(num_branches):
			var bangle: float = prng.randf() * TAU
			var blen: float = prng.randf_range(40.0, 120.0)
			var brad: float = prng.randf_range(15.0, 35.0)
			branches.append({
				"offset": Vector2(cos(bangle), sin(bangle)) * blen,
				"radius": brad,
			})
		_dendrite_clusters.append({
			"pos": pos,
			"radius": prng.randf_range(30.0, 50.0),
			"branches": branches,
		})

func _build_boundary_polygon() -> void:
	## Build an irregular brain-fold boundary with ~16 vertices.
	## The shape has bumps at gyri angles and indentations at sulci.
	var points: Array = []
	var num_vertices: int = 48  # More vertices for smooth brain-fold shape
	for i in range(num_vertices):
		var angle: float = TAU * float(i) / float(num_vertices)
		# Base radius
		var r: float = MAP_EXTENT
		# Check if this angle is near a gyrus (bump outward)
		for g in _gyri:
			var gyrus_angle: float = g["angle"]
			var angle_diff: float = _angle_diff(angle, gyrus_angle)
			if absf(angle_diff) < PI / float(NUM_GYRI) * 0.7:
				# Bump outward for gyrus
				var bump_factor: float = cos(angle_diff / (PI / float(NUM_GYRI) * 0.7) * PI * 0.5)
				r += GYRUS_RADIUS * 0.5 * bump_factor
		# Add some irregularity for brain-fold look
		r += sin(angle * 5.0 + 1.3) * 150.0 + cos(angle * 7.0) * 100.0
		points.append(Vector2(cos(angle) * r, sin(angle) * r))

	_boundary_polygon = PackedVector2Array(points)

func _angle_diff(a: float, b: float) -> float:
	var diff: float = fmod(a - b + PI, TAU)
	if diff < 0:
		diff += TAU
	return diff - PI

# === RESOURCE SPAWNING ===

func spawn_resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 789

	# 1. Starter resources near each spawn (4 per spawn)
	for si in range(spawn_positions.size()):
		var sp: Vector2 = spawn_positions[si]
		for ri in range(4):
			var angle: float = TAU * float(ri) / 4.0 + rng.randf_range(-0.4, 0.4)
			var dist: float = rng.randf_range(120.0, 280.0)
			var pos: Vector2 = sp + Vector2(cos(angle) * dist, sin(angle) * dist)
			var node: Node2D = _create_resource_node(100 + si * 10 + ri, 150)
			node.global_position = pos
			add_child(node)
			resource_nodes.append(node)

	# 2. Rich resources at each gyrus (1 rich + 2 medium per gyrus)
	for gi in range(_gyri.size()):
		var g: Dictionary = _gyri[gi]
		var gc: Vector2 = g["center"]
		# Rich node at gyrus center
		var rich: Node2D = _create_resource_node(gi, 300)
		rich.global_position = gc + Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50))
		add_child(rich)
		resource_nodes.append(rich)
		# 2 medium nodes nearby
		for mi in range(2):
			var m_angle: float = g["angle"] + rng.randf_range(-0.5, 0.5)
			var m_dist: float = rng.randf_range(300.0, 700.0)
			var m_pos: Vector2 = gc + Vector2(cos(m_angle) * m_dist, sin(m_angle) * m_dist)
			var medium: Node2D = _create_resource_node(50 + gi * 10 + mi, 180)
			medium.global_position = m_pos
			add_child(medium)
			resource_nodes.append(medium)

	# 3. Titan corpses on central plateau
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0 + rng.randf_range(-0.2, 0.2)
		var dist: float = rng.randf_range(500.0, CENTRAL_RADIUS * 0.7)
		var pos: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
		var titan: Node2D = _create_titan_corpse(i)
		titan.global_position = pos
		add_child(titan)
		titan_corpses.append(titan)

	# 4. Scattered resource nodes across open central area
	for i in range(20):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(400.0, MAP_EXTENT * 0.6)
		var pos: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
		# Avoid spawns
		var too_close: bool = false
		for sp in spawn_positions:
			if pos.distance_to(sp) < 400.0:
				too_close = true
				break
		if too_close:
			continue
		var node: Node2D = _create_resource_node(200 + i, rng.randi_range(60, 150))
		node.global_position = pos
		add_child(node)
		resource_nodes.append(node)

	# 5. NPC pockets in sulci
	_spawn_npc_pockets(rng)

	# 6. Dendrite obstacles (physics bodies)
	_spawn_dendrite_obstacles()

func _spawn_npc_pockets(rng: RandomNumberGenerator) -> void:
	var NpcCreature := preload("res://scripts/rts_stage/npc_creature.gd")
	# Place NPCs in sulci between gyri
	for si in range(NUM_GYRI):
		var angle_between: float = (TAU * float(si) / float(NUM_GYRI)) + (TAU / float(NUM_GYRI) * 0.5)
		var sulcus_center: Vector2 = Vector2(cos(angle_between), sin(angle_between)) * MAP_EXTENT * 0.55
		# Skip if too close to spawn
		var too_close: bool = false
		for sp in spawn_positions:
			if sulcus_center.distance_to(sp) < 800.0:
				too_close = true
				break
		if too_close:
			continue
		var pocket_size: int = rng.randi_range(2, 3)
		for pi in range(pocket_size):
			var offset: Vector2 = Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60))
			var creature: CharacterBody2D = NpcCreature.new()
			creature.name = "NPC_%d_%d" % [si, pi]
			var ctype: int = rng.randi_range(0, 2)
			creature.global_position = sulcus_center + offset
			add_child(creature)
			creature.setup(ctype, sulcus_center)
			creature.setup_camp_guard(sulcus_center)
			creature.died.connect(_on_npc_died)
			npc_creatures.append(creature)
		# Reward resource
		var reward: Node2D = _create_resource_node(300 + si, 250)
		reward.global_position = sulcus_center
		add_child(reward)
		resource_nodes.append(reward)

func _spawn_dendrite_obstacles() -> void:
	var obs_idx: int = 0
	for dc in _dendrite_clusters:
		# Central node
		var obs := StaticBody2D.new()
		obs.name = "DendriteObs_%d" % obs_idx
		obs.global_position = dc["pos"]
		obs.add_to_group("rts_obstacles")
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = dc["radius"]
		shape.shape = circle
		obs.add_child(shape)
		var vis := Node2D.new()
		vis.set_script(preload("res://scripts/rts_stage/terrain_obstacle.gd"))
		vis.set_meta("radius", dc["radius"])
		obs.add_child(vis)
		add_child(obs)
		obstacles.append(obs)
		obs_idx += 1
		# Branch nodes
		for br in dc["branches"]:
			var br_obs := StaticBody2D.new()
			br_obs.name = "DendriteObs_%d" % obs_idx
			br_obs.global_position = dc["pos"] + br["offset"]
			br_obs.add_to_group("rts_obstacles")
			var br_shape := CollisionShape2D.new()
			var br_circle := CircleShape2D.new()
			br_circle.radius = br["radius"]
			br_shape.shape = br_circle
			br_obs.add_child(br_shape)
			add_child(br_obs)
			obstacles.append(br_obs)
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
	return Geometry2D.is_point_in_polygon(pos, _boundary_polygon)

func clamp_to_bounds(pos: Vector2) -> Vector2:
	if Geometry2D.is_point_in_polygon(pos, _boundary_polygon):
		return pos
	# Find closest point on polygon boundary
	var best_pos: Vector2 = pos
	var best_dist: float = INF
	for i in range(_boundary_polygon.size()):
		var a: Vector2 = _boundary_polygon[i]
		var b: Vector2 = _boundary_polygon[(i + 1) % _boundary_polygon.size()]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pos, a, b)
		var d: float = pos.distance_squared_to(closest)
		if d < best_dist:
			best_dist = d
			best_pos = closest
	# Nudge slightly inward
	var inward: Vector2 = (Vector2.ZERO - best_pos).normalized() * 10.0
	return best_pos + inward

# === RENDERING ===

func _process(delta: float) -> void:
	_time += delta
	_update_neurotransmitters(delta)
	queue_redraw()

func _update_neurotransmitters(delta: float) -> void:
	for p in _neurotransmitters:
		var wobble: Vector2 = Vector2(
			sin(_time * p["wobble_freq"] + p["wobble_phase"]) * 2.0,
			cos(_time * p["wobble_freq"] * 0.8 + p["wobble_phase"]) * 2.0
		)
		p["pos"] += (p["vel"] + wobble) * delta
		# Reflect if leaving bounds
		var pos: Vector2 = p["pos"]
		if pos.length() > MAP_EXTENT * 0.9:
			var inward: Vector2 = -pos.normalized()
			var new_angle: float = inward.angle() + randf_range(-0.5, 0.5)
			p["pos"] = pos.normalized() * MAP_EXTENT * 0.85
			p["vel"] = Vector2(cos(new_angle), sin(new_angle)) * p["vel"].length()

func _draw() -> void:
	# 1. Fill background (grey-pink)
	var bg: Color = get_background_color()
	# Draw a large filled circle as base
	draw_circle(Vector2.ZERO, MAP_EXTENT + GYRUS_RADIUS + 500, bg)

	# 2. Draw brain boundary polygon fill
	if _boundary_polygon.size() > 2:
		var fill_color := Color(0.07, 0.05, 0.06)
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(_boundary_polygon)
		if tris.size() >= 3:
			for ti in range(0, tris.size(), 3):
				var a: Vector2 = _boundary_polygon[tris[ti]]
				var b: Vector2 = _boundary_polygon[tris[ti + 1]]
				var c: Vector2 = _boundary_polygon[tris[ti + 2]]
				draw_polygon(PackedVector2Array([a, b, c]), PackedColorArray([fill_color, fill_color, fill_color]))

	# 3. Central plateau (elevated zone visual)
	draw_circle(Vector2.ZERO, CENTRAL_RADIUS, Color(0.09, 0.06, 0.07, 0.5))
	draw_arc(Vector2.ZERO, CENTRAL_RADIUS, 0, TAU, 64, Color(0.3, 0.2, 0.25, 0.2), 2.0)
	draw_arc(Vector2.ZERO, CENTRAL_RADIUS * 0.7, 0, TAU, 48, Color(0.25, 0.18, 0.22, 0.1), 1.0)

	# 4. Gyri (ridges) visual
	for g in _gyri:
		var gc: Vector2 = g["center"]
		var gr: float = g["radius"]
		draw_circle(gc, gr * 0.6, Color(0.08, 0.055, 0.065, 0.4))
		draw_arc(gc, gr * 0.6, 0, TAU, 32, Color(0.25, 0.18, 0.22, 0.15), 1.5)
		# Draw fold ridges as arcs
		for ri in range(3):
			var ridge_r: float = gr * (0.3 + float(ri) * 0.15)
			var start_a: float = g["angle"] - PI * 0.4 + float(ri) * 0.1
			draw_arc(gc, ridge_r, start_a, start_a + PI * 0.8, 24, Color(0.2, 0.15, 0.18, 0.08), 1.0)

	# 5. Neural tissue arcs (organic fold decoration)
	for arc in _neural_arcs:
		var ac: Vector2 = arc["center"]
		var ar: float = arc["radius"]
		var sa: float = arc["start_angle"] + _time * 0.02
		var sw: float = arc["sweep"]
		draw_arc(ac, ar, sa, sa + sw, 16, Color(0.15, 0.1, 0.13, 0.05), 1.0)

	# 6. Dendrite clusters (visual only - physics handled separately)
	for dc in _dendrite_clusters:
		var dpos: Vector2 = dc["pos"]
		var dr: float = dc["radius"]
		draw_circle(dpos, dr, Color(0.12, 0.08, 0.1, 0.3))
		for br in dc["branches"]:
			var bp: Vector2 = dpos + br["offset"]
			draw_circle(bp, br["radius"], Color(0.1, 0.07, 0.09, 0.25))
			# Connecting line (dendrite arm)
			draw_line(dpos, bp, Color(0.15, 0.1, 0.12, 0.15), 2.0)

	# 7. Synapse sparks (occasional bright flashes)
	for spark in _synapse_sparks:
		var sp: Vector2 = spark["pos"]
		var flash: float = maxf(0.0, sin(_time * spark["speed"] + spark["phase"]))
		if flash > 0.7:
			var flash_alpha: float = (flash - 0.7) / 0.3 * spark["intensity"]
			var spark_size: float = 8.0 + flash_alpha * 25.0
			draw_circle(sp, spark_size, Color(0.8, 0.7, 1.0, flash_alpha * 0.15))
			draw_circle(sp, spark_size * 0.3, Color(1.0, 0.9, 1.0, flash_alpha * 0.3))
			# Lightning-like branches
			if flash > 0.85:
				for bi in range(3):
					var branch_angle: float = _time * 2.0 + float(bi) * TAU / 3.0
					var branch_end: Vector2 = sp + Vector2(cos(branch_angle), sin(branch_angle)) * spark_size * 1.5
					draw_line(sp, branch_end, Color(0.7, 0.6, 1.0, flash_alpha * 0.2), 1.0)

	# 8. Neurotransmitter particles
	var nt_colors: Array = [
		Color(0.5, 0.3, 0.6),   # dopamine purple
		Color(0.3, 0.5, 0.7),   # serotonin blue
		Color(0.7, 0.4, 0.5),   # acetylcholine pink
	]
	for p in _neurotransmitters:
		var pos: Vector2 = p["pos"]
		var sz: float = p["size"]
		var col: Color = nt_colors[p["color_idx"]]
		col.a = p["alpha"]
		draw_circle(pos, sz, col)

	# 9. Boundary edge line
	if _boundary_polygon.size() > 2:
		for i in range(_boundary_polygon.size()):
			var a: Vector2 = _boundary_polygon[i]
			var b: Vector2 = _boundary_polygon[(i + 1) % _boundary_polygon.size()]
			draw_line(a, b, Color(0.35, 0.25, 0.3, 0.3), 3.0)
			# Subtle glow
			draw_line(a, b, Color(0.25, 0.18, 0.22, 0.1), 8.0)

	# 10. Spawn zone indicators
	for i in range(spawn_positions.size()):
		var sp: Vector2 = spawn_positions[i]
		var fc: Color = FactionData.get_faction_color(i)
		draw_arc(sp, 100.0, 0, TAU, 32, Color(fc.r, fc.g, fc.b, 0.15), 2.0)

extends Node2D
## Circular petri dish arena for the RTS stage.
## Draws the boundary, substrate, and spawns resources + obstacles.
## Enhanced with living liquid environment: ambient particles, currents, caustics.
## Serves as the base map pattern. New maps implement the same interface via duck typing.

const MAP_RADIUS: float = 8000.0

# === MAP INTERFACE (virtual methods — override in new map scripts) ===

func get_map_name() -> String:
	return "Petri Dish"

func get_map_description() -> String:
	return "Circular arena with scattered resources"

func get_map_bounds_type() -> String:
	return "circle"  # "circle", "rect", or "polygon"

func get_map_radius() -> float:
	return MAP_RADIUS

func get_map_rect() -> Rect2:
	return Rect2()  # Not used for circle maps

func get_map_polygon() -> PackedVector2Array:
	return PackedVector2Array()  # Not used for circle maps

func get_spawn_positions() -> Array:
	return spawn_positions

func get_background_color() -> Color:
	return Color(0.03, 0.05, 0.08)

func get_particle_colors() -> Array:
	return [Color(0.2, 0.8, 0.3), Color(0.3, 0.5, 0.9), Color(0.6, 0.3, 0.8)]

func get_nav_polygon() -> PackedVector2Array:
	## Returns the outline used for NavigationPolygon baking.
	var outline := PackedVector2Array()
	var num_pts: int = 64
	for i in range(num_pts):
		var angle: float = TAU * float(i) / float(num_pts)
		outline.append(Vector2(cos(angle), sin(angle)) * (MAP_RADIUS - 100.0))
	return outline

func _get_resource_layout() -> Array:
	## Returns [{pos: Vector2, type: String, amount: int}]
	## Override in subclasses for custom resource placement.
	return []  # Default: use spawn_resources() procedural generation

func _get_obstacle_layout() -> Array:
	## Returns [{pos: Vector2, radius: float}]
	return []

func _get_terrain_zone_layout() -> Array:
	## Returns [{center: Vector2, radius: float, elevation: int}]
	## Override to provide map-specific terrain zones.
	return []

const SPAWN_INSET: float = 0.7  # Spawn at 70% from center
const TITAN_RING_RADIUS: float = 0.45  # Titans at 45% radius
const NUM_RESOURCE_NODES: int = 45
const NUM_TITAN_CORPSES: int = 10
const NUM_OBSTACLES: int = 20
const NUM_STARTER_RESOURCES_PER_SPAWN: int = 4
const NUM_RESOURCE_CACHES: int = 30
const NUM_NPC_POCKETS: int = 8

var _time: float = 0.0
var _substrate_dots: Array[Vector2] = []

# Spawn positions for 4 factions at cardinal points
var spawn_positions: Array[Vector2] = []

# References to spawned entities
var resource_nodes: Array[Node2D] = []
var titan_corpses: Array[Node2D] = []
var obstacles: Array[Node2D] = []
var npc_creatures: Array[Node2D] = []

# Liquid environment
var _ambient_particles: Array = []  # [{pos, vel, size, alpha, type}]
var _current_field: Array = []  # [{pos, dir, strength}]
var _caustic_spots: Array = []  # [{pos, phase, speed, radius}]
const NUM_AMBIENT_PARTICLES: int = 150
const NUM_CURRENT_NODES: int = 12
const NUM_CAUSTIC_SPOTS: int = 20

func _ready() -> void:
	# Calculate spawn positions (N, E, S, W)
	var inset: float = MAP_RADIUS * SPAWN_INSET
	spawn_positions = [
		Vector2(0, -inset),   # North - Player
		Vector2(inset, 0),    # East - Swarm
		Vector2(0, inset),    # South - Bulwark
		Vector2(-inset, 0),   # West - Predator
	]
	# Generate substrate decoration dots
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(200):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf() * MAP_RADIUS * 0.98
		_substrate_dots.append(Vector2(cos(angle) * dist, sin(angle) * dist))

	# Generate ambient particles
	var prng := RandomNumberGenerator.new()
	prng.seed = 77
	for i in range(NUM_AMBIENT_PARTICLES):
		var angle: float = prng.randf() * TAU
		var dist: float = prng.randf() * MAP_RADIUS * 0.95
		var pos: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
		var speed: float = prng.randf_range(5.0, 20.0)
		var vel_angle: float = prng.randf() * TAU
		_ambient_particles.append({
			"pos": pos,
			"vel": Vector2(cos(vel_angle) * speed, sin(vel_angle) * speed),
			"size": prng.randf_range(1.0, 4.0),
			"alpha": prng.randf_range(0.03, 0.08),
			"type": prng.randi_range(0, 2),  # 0=dot, 1=squiggle, 2=rod
			"wobble_phase": prng.randf() * TAU,
			"wobble_freq": prng.randf_range(0.5, 2.0),
			"color_idx": prng.randi_range(0, 2),  # 0=green, 1=blue, 2=purple
		})

	# Generate current field nodes
	for i in range(NUM_CURRENT_NODES):
		var angle: float = prng.randf() * TAU
		var dist: float = prng.randf_range(MAP_RADIUS * 0.1, MAP_RADIUS * 0.85)
		var dir_angle: float = prng.randf() * TAU
		_current_field.append({
			"pos": Vector2(cos(angle) * dist, sin(angle) * dist),
			"dir": Vector2(cos(dir_angle), sin(dir_angle)),
			"strength": prng.randf_range(3.0, 12.0),
		})

	# Generate caustic light spots
	for i in range(NUM_CAUSTIC_SPOTS):
		var angle: float = prng.randf() * TAU
		var dist: float = prng.randf() * MAP_RADIUS * 0.9
		_caustic_spots.append({
			"pos": Vector2(cos(angle) * dist, sin(angle) * dist),
			"phase": prng.randf() * TAU,
			"speed": prng.randf_range(0.2, 0.8),
			"radius": prng.randf_range(40.0, 120.0),
		})

func spawn_resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123

	# 1. Starter resources near each spawn (close, easy to reach)
	for si in range(spawn_positions.size()):
		var sp: Vector2 = spawn_positions[si]
		for ri in range(NUM_STARTER_RESOURCES_PER_SPAWN):
			var angle: float = TAU * float(ri) / float(NUM_STARTER_RESOURCES_PER_SPAWN) + rng.randf_range(-0.3, 0.3)
			var dist: float = rng.randf_range(150.0, 350.0)
			var pos: Vector2 = sp + Vector2(cos(angle) * dist, sin(angle) * dist)
			var node: Node2D = _create_resource_node(100 + si * 10 + ri, 150)  # Medium-sized starter
			node.global_position = pos
			add_child(node)
			resource_nodes.append(node)

	# 2. Titan corpses in ring at ~45% radius
	for i in range(NUM_TITAN_CORPSES):
		var angle: float = TAU * float(i) / NUM_TITAN_CORPSES + PI / NUM_TITAN_CORPSES
		var pos: Vector2 = Vector2(cos(angle), sin(angle)) * MAP_RADIUS * TITAN_RING_RADIUS
		var titan: Node2D = _create_titan_corpse(i)
		titan.global_position = pos
		add_child(titan)
		titan_corpses.append(titan)

	# 3. Scattered standard biomolecule resource nodes (mid-map)
	for i in range(NUM_RESOURCE_NODES):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(MAP_RADIUS * 0.15, MAP_RADIUS * 0.85)
		var pos: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
		# Avoid spawning too close to spawn points
		var too_close: bool = false
		for sp in spawn_positions:
			if pos.distance_to(sp) < 400.0:
				too_close = true
				break
		if too_close:
			continue
		var node: Node2D = _create_resource_node(i)
		node.global_position = pos
		add_child(node)
		resource_nodes.append(node)

	# 4. Small resource caches scattered everywhere (quick pick-ups)
	for i in range(NUM_RESOURCE_CACHES):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(MAP_RADIUS * 0.1, MAP_RADIUS * 0.9)
		var pos: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
		var node: Node2D = _create_resource_node(200 + i, rng.randi_range(40, 80))  # Small caches
		node.global_position = pos
		add_child(node)
		resource_nodes.append(node)

	# 5. NPC danger pockets — clusters of hostile creatures at strategic mid-map positions
	_spawn_npc_pockets(rng)

	# 5b. Roaming predators — large NPCs on circular patrol paths at 50% radius
	_spawn_roaming_predators()

	# 6. Terrain obstacles
	for i in range(NUM_OBSTACLES):
		var angle: float = TAU * float(i) / NUM_OBSTACLES + randi() % 100 * 0.01
		var dist: float = MAP_RADIUS * rng.randf_range(0.3, 0.75)
		var pos: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
		var obs: Node2D = _create_obstacle(i)
		obs.global_position = pos
		add_child(obs)
		obstacles.append(obs)

func _spawn_npc_pockets(rng: RandomNumberGenerator) -> void:
	## Spawns isolated pockets of neutral hostile creatures at strategic locations.
	## Each pocket has 2-4 camp guard creatures defending a resource-rich area.
	var NpcCreature := preload("res://scripts/rts_stage/npc_creature.gd")
	# Place pockets in a ring between spawns and center, and along inter-faction borders
	for pi in range(NUM_NPC_POCKETS):
		var angle: float = TAU * float(pi) / float(NUM_NPC_POCKETS) + rng.randf_range(-0.2, 0.2)
		var dist: float = MAP_RADIUS * rng.randf_range(0.25, 0.6)
		var pocket_center: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
		# Avoid spawning too close to faction spawns
		var too_close: bool = false
		for sp in spawn_positions:
			if pocket_center.distance_to(sp) < 800.0:
				too_close = true
				break
		if too_close:
			continue
		# Determine pocket composition
		var pocket_size: int = rng.randi_range(2, 4)
		var has_brute: bool = rng.randf() < 0.35
		for ci in range(pocket_size):
			var offset: Vector2 = Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60))
			var creature: CharacterBody2D = NpcCreature.new()
			creature.name = "NPC_%d_%d" % [pi, ci]
			var ctype: int = 0  # SWARMLING
			if has_brute and ci == 0:
				ctype = 1  # BRUTE
			elif rng.randf() < 0.25:
				ctype = 2  # SPITTER
			creature.global_position = pocket_center + offset
			add_child(creature)
			creature.setup(ctype, pocket_center)
			creature.setup_camp_guard(pocket_center)
			creature.died.connect(_on_npc_died)
			npc_creatures.append(creature)
		# Place a rich resource node at the pocket center as reward
		var reward: Node2D = _create_resource_node(300 + pi, 300)  # Rich cache guarded by NPCs
		reward.global_position = pocket_center
		add_child(reward)
		resource_nodes.append(reward)

func _spawn_roaming_predators() -> void:
	## Spawns 4 large roaming predators at 50% map radius with circular patrol paths.
	## Each patrols a 4-waypoint circuit (90 degrees apart). XP reward = 3, visually 1.5x size.
	var NpcCreature := preload("res://scripts/rts_stage/npc_creature.gd")
	var roam_dist: float = MAP_RADIUS * 0.5
	var patrol_orbit: float = 600.0  # Distance between waypoints from roamer center

	for ri in range(4):
		var base_angle: float = TAU * float(ri) / 4.0 + PI / 4.0  # Offset 45 deg from faction spawns
		var roam_center: Vector2 = Vector2(cos(base_angle), sin(base_angle)) * roam_dist

		# Build 4 waypoints in a square pattern around the roam center
		var waypoints: Array = []
		for wi in range(4):
			var wp_angle: float = TAU * float(wi) / 4.0
			var wp_pos: Vector2 = roam_center + Vector2(cos(wp_angle), sin(wp_angle)) * patrol_orbit
			waypoints.append(wp_pos)

		# Create large brute-type roaming predator
		var creature: CharacterBody2D = NpcCreature.new()
		creature.name = "RoamingPredator_%d" % ri
		creature.global_position = roam_center
		add_child(creature)
		creature.setup(NpcCreature.CreatureType.BRUTE, roam_center)
		creature.setup_roaming(waypoints, 3)
		# Make visually larger (1.5x)
		creature._visual_scale = 1.5
		# Buff stats for roaming predator
		creature.health *= 1.5
		creature.max_health = creature.health
		creature.damage *= 1.3
		creature.detection_range = 200.0
		creature.drop_biomass = 80
		creature.drop_genes = 15
		creature.died.connect(_on_npc_died)
		npc_creatures.append(creature)

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

func _create_obstacle(index: int) -> Node2D:
	var obs := StaticBody2D.new()
	obs.name = "Obstacle_%d" % index
	obs.add_to_group("rts_obstacles")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = randf_range(30.0, 60.0)
	shape.shape = circle
	obs.add_child(shape)
	# Add visual script
	var vis := Node2D.new()
	vis.set_script(preload("res://scripts/rts_stage/terrain_obstacle.gd"))
	vis.set_meta("radius", circle.radius)
	obs.add_child(vis)
	return obs

func _process(delta: float) -> void:
	_time += delta
	_update_ambient_particles(delta)
	queue_redraw()

func _update_ambient_particles(delta: float) -> void:
	for p in _ambient_particles:
		# Find nearest current node and apply influence
		var best_dist: float = INF
		var best_idx: int = -1
		for ci in range(_current_field.size()):
			var d: float = (p["pos"] as Vector2).distance_squared_to(_current_field[ci]["pos"])
			if d < best_dist:
				best_dist = d
				best_idx = ci
		var current_push: Vector2 = Vector2.ZERO
		if best_idx >= 0:
			var cn: Dictionary = _current_field[best_idx]
			var falloff: float = 1.0 / (1.0 + sqrt(best_dist) * 0.001)
			current_push = cn["dir"] * cn["strength"] * falloff
		# Sine wobble
		var wobble: Vector2 = Vector2(
			sin(_time * p["wobble_freq"] + p["wobble_phase"]) * 3.0,
			cos(_time * p["wobble_freq"] * 0.7 + p["wobble_phase"]) * 3.0
		)
		# Update position
		p["pos"] += (p["vel"] + current_push + wobble) * delta
		# Wrap around if leaving map bounds
		var pos: Vector2 = p["pos"]
		if pos.length() > MAP_RADIUS * 0.96:
			# Reflect back toward center with random angle
			var inward: Vector2 = -pos.normalized()
			var new_angle: float = inward.angle() + randf_range(-0.5, 0.5)
			p["pos"] = pos.normalized() * MAP_RADIUS * 0.90
			p["vel"] = Vector2(cos(new_angle), sin(new_angle)) * p["vel"].length()

func _draw() -> void:
	# 1. Substrate background (dark)
	draw_circle(Vector2.ZERO, MAP_RADIUS, Color(0.03, 0.05, 0.08))

	# 2. Radial depth gradient (brighter center, darker edge)
	for i in range(6):
		var r_pct: float = float(6 - i) / 6.0
		var grad_r: float = MAP_RADIUS * r_pct
		var grad_alpha: float = 0.008 * (1.0 - r_pct)
		draw_circle(Vector2.ZERO, grad_r, Color(0.06, 0.12, 0.18, grad_alpha))

	# 3. Substrate dots (subtle visual texture)
	for dot in _substrate_dots:
		var brightness: float = 0.02 + 0.01 * sin(_time * 0.3 + dot.x * 0.01)
		draw_circle(dot, 2.0, Color(0.1, 0.2, 0.3, brightness))

	# 4. Caustic light patterns (slowly moving bright spots)
	for cs in _caustic_spots:
		var drift: Vector2 = Vector2(
			sin(_time * cs["speed"] + cs["phase"]) * 80.0,
			cos(_time * cs["speed"] * 0.7 + cs["phase"] + 1.3) * 80.0
		)
		var cpos: Vector2 = cs["pos"] + drift
		var pulse: float = 0.5 + 0.5 * sin(_time * cs["speed"] * 1.5 + cs["phase"])
		var c_alpha: float = 0.015 * pulse
		draw_circle(cpos, cs["radius"] * (0.8 + 0.2 * pulse), Color(0.15, 0.25, 0.35, c_alpha))
		# Inner bright core
		draw_circle(cpos, cs["radius"] * 0.3, Color(0.2, 0.35, 0.5, c_alpha * 1.5))

	# 5. Current flow lines (faint curved lines showing flow direction)
	for cn in _current_field:
		var cpos: Vector2 = cn["pos"]
		var cdir: Vector2 = cn["dir"]
		var cstr: float = cn["strength"]
		# Draw 3 short flow lines near each current node
		for j in range(3):
			var offset: Vector2 = Vector2(
				sin(_time * 0.4 + j * 2.1 + cpos.x * 0.001) * 150.0,
				cos(_time * 0.3 + j * 1.7 + cpos.y * 0.001) * 150.0
			)
			var start: Vector2 = cpos + offset
			if start.length() > MAP_RADIUS * 0.95:
				continue
			# Curved line via 3 points
			var p0: Vector2 = start
			var p1: Vector2 = start + cdir * cstr * 8.0 + Vector2(sin(_time + j), cos(_time + j)) * 10.0
			var p2: Vector2 = start + cdir * cstr * 16.0
			# Draw as 2 short segments (approximate curve)
			draw_line(p0, p1, Color(0.1, 0.2, 0.3, 0.02), 1.0)
			draw_line(p1, p2, Color(0.1, 0.2, 0.3, 0.015), 1.0)

	# 6. Ambient particles
	var particle_colors: Array = [
		Color(0.15, 0.5, 0.3),   # organic green
		Color(0.15, 0.3, 0.55),  # deep blue
		Color(0.35, 0.2, 0.5),   # purple
	]
	for p in _ambient_particles:
		var pos: Vector2 = p["pos"]
		var sz: float = p["size"]
		var alpha: float = p["alpha"]
		var col: Color = particle_colors[p["color_idx"]]
		col.a = alpha

		match p["type"]:
			0:  # dot
				draw_circle(pos, sz, col)
			1:  # squiggle - short curved line
				var ang: float = _time * 0.5 + pos.x * 0.01
				var p0: Vector2 = pos + Vector2(cos(ang), sin(ang)) * sz * 2.0
				var p1: Vector2 = pos
				var p2: Vector2 = pos - Vector2(cos(ang + 0.5), sin(ang + 0.5)) * sz * 2.0
				draw_line(p0, p1, col, maxf(sz * 0.4, 0.5))
				draw_line(p1, p2, col, maxf(sz * 0.3, 0.5))
			2:  # rod - thin rectangle
				var rod_angle: float = p["wobble_phase"] + _time * 0.2
				var rod_dir: Vector2 = Vector2(cos(rod_angle), sin(rod_angle))
				var rod_half: float = sz * 2.5
				draw_line(pos - rod_dir * rod_half, pos + rod_dir * rod_half, col, maxf(sz * 0.5, 0.5))

	# 7. Grid rings for depth
	for i in range(8):
		var r: float = MAP_RADIUS * float(i + 1) / 8.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.08, 0.15, 0.22, 0.08), 1.0)

	# 8. Glass rim boundary
	draw_arc(Vector2.ZERO, MAP_RADIUS, 0, TAU, 128, Color(0.4, 0.7, 0.9, 0.4), 4.0)
	draw_arc(Vector2.ZERO, MAP_RADIUS + 4, 0, TAU, 128, Color(0.3, 0.5, 0.7, 0.15), 8.0)
	draw_arc(Vector2.ZERO, MAP_RADIUS - 4, 0, TAU, 128, Color(0.5, 0.8, 1.0, 0.1), 2.0)

	# 9. Spawn zone indicators
	for i in range(spawn_positions.size()):
		var sp: Vector2 = spawn_positions[i]
		var fc: Color = FactionData.get_faction_color(i)
		draw_arc(sp, 120.0, 0, TAU, 32, Color(fc.r, fc.g, fc.b, 0.15), 2.0)

func is_within_bounds(pos: Vector2) -> bool:
	var bounds_type: String = get_map_bounds_type()
	match bounds_type:
		"rect":
			return get_map_rect().has_point(pos)
		"polygon":
			return Geometry2D.is_point_in_polygon(pos, get_map_polygon())
		_:  # "circle"
			return pos.length() < get_map_radius() - 10.0

func clamp_to_bounds(pos: Vector2) -> Vector2:
	var bounds_type: String = get_map_bounds_type()
	match bounds_type:
		"rect":
			var r: Rect2 = get_map_rect()
			return Vector2(
				clampf(pos.x, r.position.x + 10.0, r.end.x - 10.0),
				clampf(pos.y, r.position.y + 10.0, r.end.y - 10.0)
			)
		"polygon":
			if Geometry2D.is_point_in_polygon(pos, get_map_polygon()):
				return pos
			# Find closest point on polygon boundary
			var poly: PackedVector2Array = get_map_polygon()
			var best_pos: Vector2 = pos
			var best_dist: float = INF
			for i in range(poly.size()):
				var a: Vector2 = poly[i]
				var b: Vector2 = poly[(i + 1) % poly.size()]
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pos, a, b)
				var d: float = pos.distance_squared_to(closest)
				if d < best_dist:
					best_dist = d
					best_pos = closest
			# Nudge slightly inward
			var inward: Vector2 = (Vector2.ZERO - best_pos).normalized() * 10.0
			return best_pos + inward
		_:  # "circle"
			var radius: float = get_map_radius()
			if pos.length() > radius - 10.0:
				return pos.normalized() * (radius - 10.0)
			return pos

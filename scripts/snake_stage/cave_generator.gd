extends Node3D
## Parasite Mode: hub-and-spoke graph of organ caverns connected by vein/artery tunnels.
## The worm is inside a host animal's body. Biomes are organs.

signal cave_ready

# --- Organ biome definitions ---
enum Biome {
	STOMACH,           # Spawn, safe, acidic green-yellow glow
	HEART_CHAMBER,     # Pulsing red, rhythmic
	INTESTINAL_TRACT,  # Pink-brown, villi textures
	LUNG_TISSUE,       # Pink-white, spongy
	BONE_MARROW,       # Pale yellow-white
	LIVER,             # Dark red-brown, bile pools
	BRAIN              # Dark purple-grey, nerve tendrils
}

const BIOME_COLORS: Dictionary = {
	Biome.STOMACH: {
		"floor": Color(0.06, 0.08, 0.02),
		"wall": Color(0.05, 0.07, 0.02),
		"ceiling": Color(0.04, 0.06, 0.02),
		"emission": Color(0.3, 0.5, 0.1),
		"ambient": Color(0.08, 0.12, 0.03),
		"fog": Color(0.04, 0.06, 0.02),
	},
	Biome.HEART_CHAMBER: {
		"floor": Color(0.1, 0.02, 0.02),
		"wall": Color(0.08, 0.015, 0.02),
		"ceiling": Color(0.06, 0.01, 0.015),
		"emission": Color(0.7, 0.1, 0.08),
		"ambient": Color(0.18, 0.04, 0.03),
		"fog": Color(0.06, 0.015, 0.01),
	},
	Biome.INTESTINAL_TRACT: {
		"floor": Color(0.08, 0.05, 0.04),
		"wall": Color(0.07, 0.04, 0.035),
		"ceiling": Color(0.05, 0.03, 0.025),
		"emission": Color(0.4, 0.25, 0.2),
		"ambient": Color(0.1, 0.06, 0.05),
		"fog": Color(0.05, 0.03, 0.025),
	},
	Biome.LUNG_TISSUE: {
		"floor": Color(0.08, 0.06, 0.07),
		"wall": Color(0.07, 0.055, 0.065),
		"ceiling": Color(0.06, 0.05, 0.055),
		"emission": Color(0.5, 0.35, 0.4),
		"ambient": Color(0.1, 0.07, 0.08),
		"fog": Color(0.05, 0.04, 0.045),
	},
	Biome.BONE_MARROW: {
		"floor": Color(0.09, 0.08, 0.06),
		"wall": Color(0.08, 0.07, 0.055),
		"ceiling": Color(0.07, 0.06, 0.05),
		"emission": Color(0.5, 0.45, 0.3),
		"ambient": Color(0.12, 0.1, 0.07),
		"fog": Color(0.06, 0.055, 0.04),
	},
	Biome.LIVER: {
		"floor": Color(0.08, 0.03, 0.02),
		"wall": Color(0.06, 0.02, 0.015),
		"ceiling": Color(0.05, 0.018, 0.012),
		"emission": Color(0.5, 0.15, 0.08),
		"ambient": Color(0.12, 0.04, 0.025),
		"fog": Color(0.05, 0.02, 0.012),
	},
	Biome.BRAIN: {
		"floor": Color(0.04, 0.03, 0.05),
		"wall": Color(0.03, 0.025, 0.045),
		"ceiling": Color(0.025, 0.02, 0.04),
		"emission": Color(0.15, 0.1, 0.25),
		"ambient": Color(0.04, 0.03, 0.06),
		"fog": Color(0.02, 0.015, 0.03),
	},
}

# --- Hub data ---
class HubData:
	var id: int = 0
	var position: Vector3 = Vector3.ZERO
	var radius: float = 25.0
	var height: float = 15.0
	var biome: int = Biome.STOMACH  # Use int for Biome enum
	var depth_level: int = 0  # Graph distance from spawn
	var connections: Array[int] = []  # Connected hub IDs
	var node_3d: Node3D = null  # Runtime reference to cave_hub instance
	var is_active: bool = false

# --- Tunnel data ---
class TunnelData:
	var id: int = 0
	var hub_a: int = 0
	var hub_b: int = 0
	var path: Array[Vector3] = []  # Cubic Bezier sampled points
	var width: float = 3.0
	var biome_a: int = Biome.STOMACH
	var biome_b: int = Biome.STOMACH
	var dead_ends: Array = []  # Array of {branch_point: int, path: Array[Vector3]}
	var node_3d: Node3D = null
	var is_active: bool = false

# --- Generation parameters ---
const HUB_COUNT_MIN: int = 12
const HUB_COUNT_MAX: int = 16
const HUB_MIN_SPACING: float = 60.0
const HUB_MAX_SPACING: float = 200.0
const EXTRA_EDGE_RATIO: float = 0.35
const TUNNEL_SUBDIVISIONS: int = 24
const DEAD_END_MAX_PER_TUNNEL: int = 3
const SPAWN_HUB_RADIUS: float = 30.0
const SPAWN_HUB_HEIGHT: float = 18.0
const SPAWN_Y: float = -10.0

# Chunk activation
const ACTIVATE_DISTANCE: float = 120.0
const DEACTIVATE_DISTANCE: float = 160.0

# --- Runtime state ---
var hubs: Array[HubData] = []  # Use typed array but store as variant internally
var tunnels: Array[TunnelData] = []
var spawn_hub_id: int = 0
var _player: Node3D = null
var _chunk_timer: float = 0.0

func setup(player: Node3D) -> void:
	_player = player

func _ready() -> void:
	call_deferred("_generate_cave_system")

func _generate_cave_system() -> void:
	_place_hubs()
	_build_connectivity()
	_assign_depths()
	_assign_biomes()
	_generate_tunnel_paths()
	_add_dead_ends()
	_instantiate_geometry()
	cave_ready.emit()

# --- Hub Placement (Poisson-disc-like) ---
func _place_hubs() -> void:
	var target_count: int = randi_range(HUB_COUNT_MIN, HUB_COUNT_MAX)

	# Spawn hub at origin
	var spawn: HubData = HubData.new()
	spawn.id = 0
	spawn.position = Vector3(0, SPAWN_Y, 0)
	spawn.radius = SPAWN_HUB_RADIUS
	spawn.height = SPAWN_HUB_HEIGHT
	spawn.biome = Biome.STOMACH
	hubs.append(spawn)
	spawn_hub_id = 0

	# Place remaining hubs via rejection sampling
	var attempts: int = 0
	while hubs.size() < target_count and attempts < 500:
		attempts += 1
		var angle: float = randf() * TAU
		var dist: float = randf_range(HUB_MIN_SPACING, HUB_MAX_SPACING)
		# Bias placement around existing hubs for connectivity
		var ref_hub: HubData = hubs[randi_range(0, hubs.size() - 1)]
		var candidate: Vector3 = ref_hub.position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)

		# Check minimum spacing
		var too_close: bool = false
		for existing in hubs:
			var flat_dist: float = Vector2(candidate.x - existing.position.x, candidate.z - existing.position.z).length()
			if flat_dist < HUB_MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue

		var hub: HubData = HubData.new()
		hub.id = hubs.size()
		hub.position = candidate  # Y will be set by depth assignment
		hub.biome = Biome.STOMACH  # Will be reassigned

		# Random size category
		var size_roll: float = randf()
		if size_roll < 0.15:
			# Massive cathedral
			hub.radius = randf_range(60.0, 80.0)
			hub.height = randf_range(35.0, 50.0)
		elif size_roll < 0.45:
			# Medium
			hub.radius = randf_range(25.0, 40.0)
			hub.height = randf_range(15.0, 25.0)
		else:
			# Small cozy
			hub.radius = randf_range(15.0, 20.0)
			hub.height = randf_range(8.0, 12.0)

		hubs.append(hub)

# --- Connectivity (MST + extra edges) ---
func _build_connectivity() -> void:
	if hubs.size() < 2:
		return

	# Build all possible edges with distances
	var edges: Array = []  # {a: int, b: int, dist: float}
	for i in range(hubs.size()):
		for j in range(i + 1, hubs.size()):
			var d: float = Vector2(
				hubs[i].position.x - hubs[j].position.x,
				hubs[i].position.z - hubs[j].position.z
			).length()
			edges.append({"a": i, "b": j, "dist": d})

	# Sort by distance
	edges.sort_custom(func(x, y): return x.dist < y.dist)

	# Kruskal's MST
	var parent: Array[int] = []
	for i in range(hubs.size()):
		parent.append(i)
	var mst_edges: Array = []

	for edge in edges:
		var ra: int = _find_root(parent, edge.a)
		var rb: int = _find_root(parent, edge.b)
		if ra != rb:
			parent[ra] = rb
			mst_edges.append(edge)
			hubs[edge.a].connections.append(edge.b)
			hubs[edge.b].connections.append(edge.a)
			if mst_edges.size() == hubs.size() - 1:
				break

	# Add extra edges for loops (EXTRA_EDGE_RATIO of MST count)
	var extra_count: int = int(mst_edges.size() * EXTRA_EDGE_RATIO)
	var added: int = 0
	for edge in edges:
		if added >= extra_count:
			break
		if edge.b not in hubs[edge.a].connections:
			hubs[edge.a].connections.append(edge.b)
			hubs[edge.b].connections.append(edge.a)
			added += 1

func _find_root(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i

# --- Depth Assignment (BFS from spawn) ---
func _assign_depths() -> void:
	var visited: Array[bool] = []
	visited.resize(hubs.size())
	for i in range(hubs.size()):
		visited[i] = false

	var queue: Array[int] = [spawn_hub_id]
	visited[spawn_hub_id] = true
	hubs[spawn_hub_id].depth_level = 0

	while queue.size() > 0:
		var current: int = queue.pop_front()
		for neighbor_id in hubs[current].connections:
			if not visited[neighbor_id]:
				visited[neighbor_id] = true
				hubs[neighbor_id].depth_level = hubs[current].depth_level + 1
				queue.append(neighbor_id)

	# Set Y positions based on depth (deeper = lower Y)
	var max_depth: int = 0
	for hub in hubs:
		max_depth = maxi(max_depth, hub.depth_level)

	for hub in hubs:
		if hub.id == spawn_hub_id:
			continue
		var depth_fraction: float = float(hub.depth_level) / maxf(max_depth, 1.0)
		hub.position.y = lerpf(SPAWN_Y - 10.0, -120.0, depth_fraction) + randf_range(-5.0, 5.0)

# --- Organ Biome Assignment ---
func _assign_biomes() -> void:
	hubs[spawn_hub_id].biome = Biome.STOMACH

	for hub in hubs:
		if hub.id == spawn_hub_id:
			continue
		var depth: int = hub.depth_level
		if depth <= 1:
			# Near stomach: safe organs
			hub.biome = [Biome.STOMACH, Biome.INTESTINAL_TRACT][randi_range(0, 1)]
		elif depth <= 2:
			hub.biome = [Biome.INTESTINAL_TRACT, Biome.LUNG_TISSUE, Biome.HEART_CHAMBER][randi_range(0, 2)]
		elif depth <= 3:
			hub.biome = [Biome.LUNG_TISSUE, Biome.HEART_CHAMBER, Biome.BONE_MARROW][randi_range(0, 2)]
		elif depth <= 4:
			hub.biome = [Biome.BONE_MARROW, Biome.LIVER][randi_range(0, 1)]
		else:
			hub.biome = [Biome.LIVER, Biome.BRAIN][randi_range(0, 1)]

# --- Tunnel Path Generation ---
func _generate_tunnel_paths() -> void:
	var processed_pairs: Dictionary = {}

	for hub in hubs:
		for conn_id in hub.connections:
			var key: int = mini(hub.id, conn_id) * 1000 + maxi(hub.id, conn_id)
			if key in processed_pairs:
				continue
			processed_pairs[key] = true

			var tunnel: TunnelData = TunnelData.new()
			tunnel.id = tunnels.size()
			tunnel.hub_a = hub.id
			tunnel.hub_b = conn_id
			tunnel.biome_a = hub.biome
			tunnel.biome_b = hubs[conn_id].biome

			# Tunnel width: wider for navigability (vein/artery tubes)
			var min_radius: float = minf(hub.radius, hubs[conn_id].radius)
			tunnel.width = clampf(min_radius * 0.15, 3.0, 6.0)

			# Generate cubic Bezier path
			var p0: Vector3 = hub.position
			var p3: Vector3 = hubs[conn_id].position

			# Control points: offset perpendicular to the line + Y variation
			var flat_dir: Vector3 = (p3 - p0)
			var flat_length: float = flat_dir.length()
			flat_dir = flat_dir.normalized()

			var perp: Vector3 = flat_dir.cross(Vector3.UP)
			if perp.length() < 0.1:
				perp = flat_dir.cross(Vector3.RIGHT)
			perp = perp.normalized()

			var curve_amount: float = flat_length * 0.15  # Gentler curves for easier navigation
			var p1: Vector3 = p0 + flat_dir * flat_length * 0.33 + perp * randf_range(-curve_amount, curve_amount)
			p1.y = lerpf(p0.y, p3.y, 0.33) + randf_range(-curve_amount * 0.2, curve_amount * 0.2)
			var p2: Vector3 = p0 + flat_dir * flat_length * 0.66 + perp * randf_range(-curve_amount, curve_amount)
			p2.y = lerpf(p0.y, p3.y, 0.66) + randf_range(-curve_amount * 0.2, curve_amount * 0.2)

			# Sample cubic Bezier
			tunnel.path = _sample_cubic_bezier(p0, p1, p2, p3, TUNNEL_SUBDIVISIONS)
			tunnels.append(tunnel)

func _sample_cubic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, subdivisions: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in range(subdivisions + 1):
		var t: float = float(i) / subdivisions
		var it: float = 1.0 - t
		var pos: Vector3 = it * it * it * p0 + 3.0 * it * it * t * p1 + 3.0 * it * t * t * p2 + t * t * t * p3
		points.append(pos)
	return points

# --- Dead-End Branches ---
func _add_dead_ends() -> void:
	for tunnel in tunnels:
		var num_dead_ends: int = randi_range(0, DEAD_END_MAX_PER_TUNNEL)
		for _d in range(num_dead_ends):
			if tunnel.path.size() < 8:
				continue
			# Pick a random point along the tunnel (not at endpoints)
			var branch_idx: int = randi_range(3, tunnel.path.size() - 5)
			var branch_point: Vector3 = tunnel.path[branch_idx]

			# Generate a short branch
			var tunnel_dir: Vector3 = (tunnel.path[branch_idx + 1] - tunnel.path[branch_idx - 1]).normalized()
			var perp: Vector3 = tunnel_dir.cross(Vector3.UP)
			if perp.length() < 0.1:
				perp = tunnel_dir.cross(Vector3.RIGHT)
			perp = perp.normalized()

			var side: float = [-1.0, 1.0][randi_range(0, 1)]
			var branch_length: float = randf_range(8.0, 20.0)
			var end_point: Vector3 = branch_point + perp * side * branch_length + Vector3(0, randf_range(-3.0, 1.0), 0)
			var mid_point: Vector3 = (branch_point + end_point) * 0.5 + perp * side * randf_range(2.0, 5.0)

			var branch_path: Array[Vector3] = _sample_cubic_bezier(branch_point, mid_point, mid_point, end_point, 8)
			tunnel.dead_ends.append({"branch_idx": branch_idx, "path": branch_path})

# --- Geometry Instantiation ---
func _instantiate_geometry() -> void:
	var hub_script = load("res://scripts/snake_stage/cave_hub.gd")
	var tunnel_script = load("res://scripts/snake_stage/cave_tunnel_mesh.gd")

	# Create hub nodes (setup but don't add_child yet so we can register tunnel connections)
	for hub in hubs:
		var hub_node: Node3D = Node3D.new()
		hub_node.set_script(hub_script)
		hub_node.name = "Hub_%d" % hub.id
		hub_node.setup(hub)
		hub.node_3d = hub_node
		hub.is_active = true

	# Register tunnel mouth positions with hubs BEFORE they build geometry
	for tunnel in tunnels:
		if tunnel.path.size() >= 2:
			var hub_a = hubs[tunnel.hub_a]
			var hub_b = hubs[tunnel.hub_b]
			if hub_a.node_3d and hub_a.node_3d.has_method("add_tunnel_connection"):
				hub_a.node_3d.add_tunnel_connection(tunnel.path[0])
			if hub_b.node_3d and hub_b.node_3d.has_method("add_tunnel_connection"):
				hub_b.node_3d.add_tunnel_connection(tunnel.path[-1])

	# Now add hubs to tree (triggers _ready → _build_hub with tunnel info)
	for hub in hubs:
		add_child(hub.node_3d)

	for tunnel in tunnels:
		var tunnel_node: Node3D = Node3D.new()
		tunnel_node.set_script(tunnel_script)
		tunnel_node.name = "Tunnel_%d" % tunnel.id
		tunnel_node.setup(tunnel, self)
		add_child(tunnel_node)
		tunnel.node_3d = tunnel_node
		tunnel.is_active = true

# --- Chunk Management ---
func _process(delta: float) -> void:
	_chunk_timer += delta
	if _chunk_timer < 1.0:
		return
	_chunk_timer = 0.0
	_update_chunks()

func _update_chunks() -> void:
	if not _player:
		return
	var player_pos: Vector3 = _player.global_position

	for hub in hubs:
		var dist: float = hub.position.distance_to(player_pos)
		if dist < ACTIVATE_DISTANCE and not hub.is_active:
			_activate_hub(hub)
		elif dist > DEACTIVATE_DISTANCE and hub.is_active:
			_deactivate_hub(hub)

	for tunnel in tunnels:
		# Use midpoint of tunnel path for distance check
		var mid_idx: int = tunnel.path.size() / 2
		var mid_pos: Vector3 = tunnel.path[mid_idx] if tunnel.path.size() > 0 else Vector3.ZERO
		var dist: float = mid_pos.distance_to(player_pos)
		if dist < ACTIVATE_DISTANCE and not tunnel.is_active:
			_activate_tunnel(tunnel)
		elif dist > DEACTIVATE_DISTANCE and tunnel.is_active:
			_deactivate_tunnel(tunnel)

func _activate_hub(hub: HubData) -> void:
	if hub.node_3d:
		hub.node_3d.visible = true
		hub.node_3d.process_mode = Node.PROCESS_MODE_INHERIT
		# Re-enable collision
		for child in hub.node_3d.get_children():
			if child is StaticBody3D:
				child.process_mode = Node.PROCESS_MODE_INHERIT
	hub.is_active = true

func _deactivate_hub(hub: HubData) -> void:
	if hub.node_3d:
		hub.node_3d.visible = false
		hub.node_3d.process_mode = Node.PROCESS_MODE_DISABLED
	hub.is_active = false

func _activate_tunnel(tunnel: TunnelData) -> void:
	if tunnel.node_3d:
		tunnel.node_3d.visible = true
		tunnel.node_3d.process_mode = Node.PROCESS_MODE_INHERIT
	tunnel.is_active = true

func _deactivate_tunnel(tunnel: TunnelData) -> void:
	if tunnel.node_3d:
		tunnel.node_3d.visible = false
		tunnel.node_3d.process_mode = Node.PROCESS_MODE_DISABLED
	tunnel.is_active = false

# --- Queries ---
func get_spawn_position() -> Vector3:
	if hubs.size() > 0:
		var hub = hubs[spawn_hub_id]
		var center: Vector3 = hub.position
		# Query actual floor height to avoid spawning inside geometry
		if hub.node_3d and hub.node_3d.has_method("get_floor_y"):
			var floor_y: float = hub.node_3d.get_floor_y(center.x, center.z)
			return Vector3(center.x, floor_y + 3.0, center.z)
		return center + Vector3(0, 5.0, 0)
	return Vector3(0, SPAWN_Y + 5.0, 0)

func get_hub_at_position(pos: Vector3) -> HubData:
	for hub in hubs:
		var flat_dist: float = Vector2(pos.x - hub.position.x, pos.z - hub.position.z).length()
		if flat_dist < hub.radius and absf(pos.y - hub.position.y) < hub.height:
			return hub
	return null

func get_nearest_hub(pos: Vector3) -> HubData:
	var nearest: HubData = null
	var nearest_dist: float = INF
	for hub in hubs:
		var d: float = pos.distance_to(hub.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = hub
	return nearest

func get_biome_colors(biome: int) -> Dictionary:
	if biome in BIOME_COLORS:
		return BIOME_COLORS[biome]
	return BIOME_COLORS[Biome.STOMACH]

func get_floor_y_at(pos: Vector3) -> float:
	## Get approximate floor Y at a world XZ position.
	## Checks active hubs for floor height, falls back to nearest hub center Y.
	var hub: HubData = get_hub_at_position(pos)
	if hub and hub.node_3d and hub.node_3d.has_method("get_floor_y"):
		return hub.node_3d.get_floor_y(pos.x, pos.z)
	# Fallback: find nearest hub and estimate
	var nearest: HubData = get_nearest_hub(pos)
	if nearest:
		return nearest.position.y
	return SPAWN_Y

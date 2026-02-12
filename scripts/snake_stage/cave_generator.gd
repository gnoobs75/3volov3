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
const TUNNEL_SUBDIVISIONS: int = 32
const SPAWN_Y: float = -10.0

# Star-pattern layout: 1 central hub + 5 biome wings
const CENTER_RADIUS: float = 200.0   # Huge central cavern
const CENTER_HEIGHT: float = 55.0
const WING_RADIUS: float = 250.0     # Large biome caverns at each spoke tip
const WING_HEIGHT: float = 65.0
const SPOKE_LENGTH: float = 500.0    # Long distance from center to wing hub
const HALLWAY_WIDTH: float = 70.0    # Very wide hallways between rooms
const SPOKE_COUNT: int = 5           # 5 biome wings in star pattern

# The 5 spoke biomes (shuffled each playthrough for variety)
# Brain is always placed at the furthest spoke from starting direction
var SPOKE_BIOMES: Array = [
	Biome.HEART_CHAMBER,
	Biome.LUNG_TISSUE,
	Biome.INTESTINAL_TRACT,
	Biome.BONE_MARROW,
	Biome.BRAIN,
]

# Chunk activation (large for big layout)
const ACTIVATE_DISTANCE: float = 750.0
const DEACTIVATE_DISTANCE: float = 850.0

# --- Runtime state ---
var hubs: Array[HubData] = []
var tunnels: Array[TunnelData] = []
var spawn_hub_id: int = 0
var _player: Node3D = null
var _chunk_timer: float = 0.0

func setup(player: Node3D) -> void:
	_player = player

func _ready() -> void:
	call_deferred("_generate_cave_system")

func _generate_cave_system() -> void:
	_shuffle_biomes()
	_place_star_layout()
	_generate_tunnel_paths()
	_instantiate_geometry()
	_add_valve_gates()
	_build_containment_shell()
	cave_ready.emit()

func _shuffle_biomes() -> void:
	## Randomize biome placement each playthrough. Brain always goes to the last slot.
	var non_brain: Array = []
	for b in SPOKE_BIOMES:
		if b != Biome.BRAIN:
			non_brain.append(b)
	# Fisher-Yates shuffle
	for i in range(non_brain.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var temp = non_brain[i]
		non_brain[i] = non_brain[j]
		non_brain[j] = temp
	# Reassemble: Brain always at last position (furthest spoke)
	SPOKE_BIOMES.clear()
	for b in non_brain:
		SPOKE_BIOMES.append(b)
	SPOKE_BIOMES.append(Biome.BRAIN)

# --- Star-Pattern Hub Placement ---
func _place_star_layout() -> void:
	# Hub 0: Central spawn cavern (STOMACH)
	var center: HubData = HubData.new()
	center.id = 0
	center.position = Vector3(0, SPAWN_Y, 0)
	center.radius = CENTER_RADIUS
	center.height = CENTER_HEIGHT
	center.biome = Biome.STOMACH
	center.depth_level = 0
	hubs.append(center)
	spawn_hub_id = 0

	# Hubs 1-5: Wing caverns at star tips, evenly spaced at 72-degree intervals
	for i in range(SPOKE_COUNT):
		var angle: float = TAU * i / SPOKE_COUNT  # 0, 72, 144, 216, 288 degrees
		var wing: HubData = HubData.new()
		wing.id = i + 1
		wing.position = Vector3(cos(angle) * SPOKE_LENGTH, SPAWN_Y, sin(angle) * SPOKE_LENGTH)
		wing.radius = WING_RADIUS
		wing.height = WING_HEIGHT
		wing.biome = SPOKE_BIOMES[i]
		wing.depth_level = 1

		# Connect center <-> wing
		center.connections.append(wing.id)
		wing.connections.append(center.id)

		hubs.append(wing)

# --- Tunnel Path Generation (straight spokes with gentle curve) ---
func _generate_tunnel_paths() -> void:
	# One tunnel per spoke: center hub (0) to each wing hub (1-5)
	for i in range(SPOKE_COUNT):
		var wing_id: int = i + 1
		var tunnel: TunnelData = TunnelData.new()
		tunnel.id = tunnels.size()
		tunnel.hub_a = 0
		tunnel.hub_b = wing_id
		tunnel.biome_a = hubs[0].biome
		tunnel.biome_b = hubs[wing_id].biome
		tunnel.width = HALLWAY_WIDTH

		var hub_a_pos: Vector3 = hubs[0].position
		var hub_b_pos: Vector3 = hubs[wing_id].position

		# Clip endpoints to wall boundaries so tunnel mesh doesn't exist inside hubs.
		# Start at 0.85*radius to overlap with hub floor (which is skipped at 0.9*radius).
		# This ensures continuous floor coverage at tunnel mouths.
		var flat_dir: Vector3 = (hub_b_pos - hub_a_pos).normalized()
		var p0: Vector3 = hub_a_pos + flat_dir * hubs[0].radius * 0.85
		p0.y = SPAWN_Y
		var p3: Vector3 = hub_b_pos - flat_dir * hubs[wing_id].radius * 0.85
		p3.y = SPAWN_Y

		# Gentle S-curve: control points offset slightly perpendicular
		var flat_length: float = p0.distance_to(p3)
		var perp: Vector3 = flat_dir.cross(Vector3.UP)
		if perp.length() < 0.1:
			perp = flat_dir.cross(Vector3.RIGHT)
		perp = perp.normalized()

		var curve_amount: float = flat_length * 0.06  # Very gentle curve
		var p1: Vector3 = p0 + flat_dir * flat_length * 0.33 + perp * randf_range(-curve_amount, curve_amount)
		p1.y = SPAWN_Y
		var p2: Vector3 = p0 + flat_dir * flat_length * 0.66 + perp * randf_range(-curve_amount, curve_amount)
		p2.y = SPAWN_Y

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

	# Register tunnel mouth positions at wall boundary (NOT hub center)
	for tunnel in tunnels:
		if tunnel.path.size() >= 2:
			var hub_a = hubs[tunnel.hub_a]
			var hub_b = hubs[tunnel.hub_b]
			# Compute direction from hub A toward hub B (XZ plane)
			var dir_ab: Vector3 = hub_b.position - hub_a.position
			dir_ab.y = 0
			if dir_ab.length() > 0.1:
				dir_ab = dir_ab.normalized()
			else:
				dir_ab = Vector3.FORWARD
			# Wall intersection point for hub A (just inside wall boundary)
			var wall_pos_a: Vector3 = hub_a.position + dir_ab * hub_a.radius * 0.95
			wall_pos_a.y = hub_a.position.y
			if hub_a.node_3d and hub_a.node_3d.has_method("add_tunnel_connection"):
				hub_a.node_3d.add_tunnel_connection(wall_pos_a, tunnel.width)
			# Wall intersection point for hub B (reverse direction)
			var dir_ba: Vector3 = -dir_ab
			var wall_pos_b: Vector3 = hub_b.position + dir_ba * hub_b.radius * 0.95
			wall_pos_b.y = hub_b.position.y
			if hub_b.node_3d and hub_b.node_3d.has_method("add_tunnel_connection"):
				hub_b.node_3d.add_tunnel_connection(wall_pos_b, tunnel.width)

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

# --- Valve Gates: fleshy iris gates on ~20% of tunnels ---
func _add_valve_gates() -> void:
	var gate_script = load("res://scripts/snake_stage/valve_gate.gd")
	for tunnel in tunnels:
		if randf() > 0.2:  # 20% chance per tunnel
			continue
		if tunnel.path.size() < 6:
			continue
		var gate: Node3D = gate_script.create_gate(tunnel, self)
		if gate:
			add_child(gate)

# --- Containment Shell: solid rock around the entire cave system ---
func _build_containment_shell() -> void:
	## Computes the AABB of all hubs + tunnels and creates 6 massive box colliders
	## forming an inward-facing shell. This IS the solid rock the caves are carved into.
	## Nothing can exist outside this boundary.
	var min_pos: Vector3 = Vector3(INF, INF, INF)
	var max_pos: Vector3 = Vector3(-INF, -INF, -INF)

	for hub in hubs:
		var r: float = hub.radius + 10.0  # Padding beyond hub walls
		var h: float = hub.height + 10.0
		min_pos.x = minf(min_pos.x, hub.position.x - r)
		min_pos.z = minf(min_pos.z, hub.position.z - r)
		min_pos.y = minf(min_pos.y, hub.position.y - 10.0)
		max_pos.x = maxf(max_pos.x, hub.position.x + r)
		max_pos.z = maxf(max_pos.z, hub.position.z + r)
		max_pos.y = maxf(max_pos.y, hub.position.y + h)

	for tunnel in tunnels:
		for pt in tunnel.path:
			var w: float = tunnel.width + 5.0
			min_pos.x = minf(min_pos.x, pt.x - w)
			min_pos.z = minf(min_pos.z, pt.z - w)
			min_pos.y = minf(min_pos.y, pt.y - w)
			max_pos.x = maxf(max_pos.x, pt.x + w)
			max_pos.z = maxf(max_pos.z, pt.z + w)
			max_pos.y = maxf(max_pos.y, pt.y + w)

	# Add generous margin
	min_pos -= Vector3(20, 20, 20)
	max_pos += Vector3(20, 20, 20)

	var center: Vector3 = (min_pos + max_pos) * 0.5
	var size: Vector3 = max_pos - min_pos
	var wall_thickness: float = 10.0

	# 6 walls: top, bottom, left, right, front, back
	var walls: Array = [
		{"pos": Vector3(center.x, max_pos.y + wall_thickness * 0.5, center.z), "size": Vector3(size.x + wall_thickness * 2, wall_thickness, size.z + wall_thickness * 2)},  # Top
		{"pos": Vector3(center.x, min_pos.y - wall_thickness * 0.5, center.z), "size": Vector3(size.x + wall_thickness * 2, wall_thickness, size.z + wall_thickness * 2)},  # Bottom
		{"pos": Vector3(min_pos.x - wall_thickness * 0.5, center.y, center.z), "size": Vector3(wall_thickness, size.y + wall_thickness * 2, size.z + wall_thickness * 2)},  # Left
		{"pos": Vector3(max_pos.x + wall_thickness * 0.5, center.y, center.z), "size": Vector3(wall_thickness, size.y + wall_thickness * 2, size.z + wall_thickness * 2)},  # Right
		{"pos": Vector3(center.x, center.y, min_pos.z - wall_thickness * 0.5), "size": Vector3(size.x + wall_thickness * 2, size.y + wall_thickness * 2, wall_thickness)},  # Front
		{"pos": Vector3(center.x, center.y, max_pos.z + wall_thickness * 0.5), "size": Vector3(size.x + wall_thickness * 2, size.y + wall_thickness * 2, wall_thickness)},  # Back
	]

	var shell_container: Node3D = Node3D.new()
	shell_container.name = "ContainmentShell"
	add_child(shell_container)

	for i in range(walls.size()):
		var wall_data: Dictionary = walls[i]
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "ShellWall_%d" % i
		var col: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = wall_data.size
		col.shape = box
		body.add_child(col)
		body.position = wall_data.pos
		shell_container.add_child(body)

	print("[CAVE] Containment shell built: bounds [%s] to [%s]" % [str(min_pos), str(max_pos)])

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
			var spawn_pos: Vector3 = Vector3(center.x, floor_y + 5.0, center.z)
			print("[SPAWN] floor_y=%.2f  spawn_y=%.2f  hub_pos=%s  hub_global=%s" % [floor_y, spawn_pos.y, str(hub.position), str(hub.node_3d.global_position)])
			return spawn_pos
		print("[SPAWN] WARNING: no get_floor_y, using fallback")
		return center + Vector3(0, 8.0, 0)
	print("[SPAWN] WARNING: no hubs!")
	return Vector3(0, SPAWN_Y + 8.0, 0)

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

func is_inside_cave(pos: Vector3) -> bool:
	## Returns true if position is inside any hub or any tunnel tube.
	## Checks ALL hubs/tunnels regardless of active state (geometry still exists).
	for hub in hubs:
		var flat_dist: float = Vector2(pos.x - hub.position.x, pos.z - hub.position.z).length()
		if flat_dist < hub.radius and absf(pos.y - hub.position.y) < hub.height:
			return true
	# Check tunnels: is the position within tunnel width of any path point?
	for tunnel in tunnels:
		for path_point in tunnel.path:
			var dist: float = pos.distance_to(path_point)
			if dist < tunnel.width * 0.5:
				return true
	return false

func get_random_position_in_hub(near_pos: Vector3, max_dist: float = 500.0) -> Vector3:
	## Returns a random position guaranteed to be inside a nearby active hub.
	## Used for spawning creatures/items within cave geometry.
	var candidates: Array = []
	for hub in hubs:
		if not hub.is_active:
			continue
		var d: float = hub.position.distance_to(near_pos)
		if d < max_dist:
			candidates.append(hub)

	if candidates.is_empty():
		var nearest = get_nearest_hub(near_pos)
		if nearest:
			candidates.append(nearest)
		else:
			return near_pos

	var hub = candidates[randi_range(0, candidates.size() - 1)]

	# Random point inside hub circle (sqrt for uniform distribution, 0.7 to stay away from walls)
	var angle: float = randf() * TAU
	var r: float = hub.radius * 0.7 * sqrt(randf())
	var x: float = hub.position.x + cos(angle) * r
	var z: float = hub.position.z + sin(angle) * r
	var y: float = hub.position.y + 1.0

	# Get actual floor height
	if hub.node_3d and hub.node_3d.has_method("get_floor_y"):
		y = hub.node_3d.get_floor_y(x, z) + 0.5

	return Vector3(x, y, z)

func get_nearest_hub_center_on_floor(pos: Vector3) -> Vector3:
	## Returns the floor-level center of the nearest hub. Safe teleport target.
	var hub = get_nearest_hub(pos)
	if not hub:
		return Vector3(0, SPAWN_Y + 2.0, 0)
	var y: float = hub.position.y + 2.0
	if hub.node_3d and hub.node_3d.has_method("get_floor_y"):
		y = hub.node_3d.get_floor_y(hub.position.x, hub.position.z) + 2.0
	return Vector3(hub.position.x, y, hub.position.z)

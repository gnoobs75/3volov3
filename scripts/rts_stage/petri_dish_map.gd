extends Node2D
## Circular petri dish arena for the RTS stage.
## Draws the boundary, substrate, and spawns resources + obstacles.

const MAP_RADIUS: float = 8000.0
const SPAWN_INSET: float = 0.7  # Spawn at 70% from center
const TITAN_RING_RADIUS: float = 0.45  # Titans at 45% radius
const NUM_RESOURCE_NODES: int = 45
const NUM_TITAN_CORPSES: int = 10
const NUM_OBSTACLES: int = 20

var _time: float = 0.0
var _substrate_dots: Array[Vector2] = []

# Spawn positions for 4 factions at cardinal points
var spawn_positions: Array[Vector2] = []

# References to spawned entities
var resource_nodes: Array[Node2D] = []
var titan_corpses: Array[Node2D] = []
var obstacles: Array[Node2D] = []

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

func spawn_resources() -> void:
	# Spawn titan corpses in ring at ~45% radius, offset from cardinal axes
	var titan_scene: PackedScene = null  # Created programmatically
	for i in range(NUM_TITAN_CORPSES):
		var angle: float = TAU * float(i) / NUM_TITAN_CORPSES + PI / NUM_TITAN_CORPSES
		var pos: Vector2 = Vector2(cos(angle), sin(angle)) * MAP_RADIUS * TITAN_RING_RADIUS
		var titan: Node2D = _create_titan_corpse(i)
		titan.global_position = pos
		add_child(titan)
		titan_corpses.append(titan)

	# Spawn scattered biomolecule resource nodes
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	for i in range(NUM_RESOURCE_NODES):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(MAP_RADIUS * 0.15, MAP_RADIUS * 0.85)
		var pos: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
		# Avoid spawning too close to spawn points
		var too_close: bool = false
		for sp in spawn_positions:
			if pos.distance_to(sp) < 600.0:
				too_close = true
				break
		if too_close:
			continue
		var node: Node2D = _create_resource_node(i)
		node.global_position = pos
		add_child(node)
		resource_nodes.append(node)

	# Spawn terrain obstacles
	for i in range(NUM_OBSTACLES):
		var angle: float = TAU * float(i) / NUM_OBSTACLES + randi() % 100 * 0.01
		var dist: float = MAP_RADIUS * rng.randf_range(0.3, 0.75)
		var pos: Vector2 = Vector2(cos(angle) * dist, sin(angle) * dist)
		var obs: Node2D = _create_obstacle(i)
		obs.global_position = pos
		add_child(obs)
		obstacles.append(obs)

func _create_titan_corpse(index: int) -> Node2D:
	var tc: Node2D = preload("res://scripts/rts_stage/titan_corpse.gd").new()
	tc.name = "TitanCorpse_%d" % index
	tc.add_to_group("rts_resources")
	tc.add_to_group("titan_corpses")
	return tc

func _create_resource_node(index: int) -> Node2D:
	var rn: Node2D = preload("res://scripts/rts_stage/resource_node.gd").new()
	rn.name = "ResourceNode_%d" % index
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
	queue_redraw()

func _draw() -> void:
	# 1. Substrate background (dark)
	draw_circle(Vector2.ZERO, MAP_RADIUS, Color(0.03, 0.05, 0.08))

	# 2. Substrate dots (subtle visual texture)
	for dot in _substrate_dots:
		var brightness: float = 0.02 + 0.01 * sin(_time * 0.3 + dot.x * 0.01)
		draw_circle(dot, 2.0, Color(0.1, 0.2, 0.3, brightness))

	# 3. Grid rings for depth
	for i in range(8):
		var r: float = MAP_RADIUS * float(i + 1) / 8.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.08, 0.15, 0.22, 0.08), 1.0)

	# 4. Glass rim boundary
	draw_arc(Vector2.ZERO, MAP_RADIUS, 0, TAU, 128, Color(0.4, 0.7, 0.9, 0.4), 4.0)
	draw_arc(Vector2.ZERO, MAP_RADIUS + 4, 0, TAU, 128, Color(0.3, 0.5, 0.7, 0.15), 8.0)
	draw_arc(Vector2.ZERO, MAP_RADIUS - 4, 0, TAU, 128, Color(0.5, 0.8, 1.0, 0.1), 2.0)

	# 5. Spawn zone indicators
	for i in range(spawn_positions.size()):
		var sp: Vector2 = spawn_positions[i]
		var fc: Color = FactionData.get_faction_color(i)
		draw_arc(sp, 120.0, 0, TAU, 32, Color(fc.r, fc.g, fc.b, 0.15), 2.0)

func is_within_bounds(pos: Vector2) -> bool:
	return pos.length() < MAP_RADIUS - 10.0

func clamp_to_bounds(pos: Vector2) -> Vector2:
	if pos.length() > MAP_RADIUS - 10.0:
		return pos.normalized() * (MAP_RADIUS - 10.0)
	return pos

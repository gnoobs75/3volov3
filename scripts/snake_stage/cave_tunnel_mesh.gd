extends Node3D
## Procedural cave hallway: flat rectangular corridor along Bezier path.
## Floor has very subtle height variation. Walls and ceiling enclose the passage.
## Includes dead-end branches.

var _tunnel_data = null  # TunnelData from cave_generator
var _cave_gen = null  # Reference to cave_generator for biome colors
var _noise: FastNoiseLite = null

const HALLWAY_HEIGHT_RATIO: float = 0.6  # Ceiling height relative to width

func setup(tunnel_data, cave_gen) -> void:
	_tunnel_data = tunnel_data
	_cave_gen = cave_gen

func _ready() -> void:
	if _tunnel_data:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.04
		_noise.seed = _tunnel_data.id * 271 + 99
		_build_tunnel()

func _build_tunnel() -> void:
	var colors_a: Dictionary = _cave_gen.get_biome_colors(_tunnel_data.biome_a) if _cave_gen else _default_colors()
	var colors_b: Dictionary = _cave_gen.get_biome_colors(_tunnel_data.biome_b) if _cave_gen else _default_colors()

	# Build main hallway
	_build_hallway(_tunnel_data.path, _tunnel_data.width, colors_a, colors_b, "MainTunnel")

	# Build dead-end branches
	for i in range(_tunnel_data.dead_ends.size()):
		var dead_end: Dictionary = _tunnel_data.dead_ends[i]
		var branch_path: Array = dead_end.path
		if branch_path.size() < 2:
			continue
		var branch_width: float = _tunnel_data.width * 0.7
		_build_hallway(branch_path, branch_width, colors_a, colors_b, "DeadEnd_%d" % i)

	# Tunnel enhancements: vein ridges and glow veins
	TunnelEnhancer.enhance_tunnel(self, _tunnel_data, _cave_gen)

func _default_colors() -> Dictionary:
	return {
		"floor": Color(0.04, 0.08, 0.06),
		"wall": Color(0.03, 0.06, 0.05),
		"ceiling": Color(0.02, 0.05, 0.04),
		"emission": Color(0.1, 0.4, 0.3),
	}

func _build_hallway(path: Array, base_width: float, colors_a: Dictionary, colors_b: Dictionary, node_name: String) -> void:
	if path.size() < 2:
		return

	# Calculate total path length
	var total_len: float = 0.0
	for i in range(1, path.size()):
		total_len += path[i - 1].distance_to(path[i])
	if total_len < 0.5:
		return

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var path_length: float = 0.0
	var seg_lengths: Array[float] = [0.0]
	for i in range(1, path.size()):
		path_length += path[i - 1].distance_to(path[i])
		seg_lengths.append(path_length)

	var half_w: float = base_width * 0.5
	var hall_h: float = base_width * HALLWAY_HEIGHT_RATIO

	for s in range(path.size() - 1):
		var p0: Vector3 = path[s]
		var p1: Vector3 = path[s + 1]
		var seg_dir: Vector3 = (p1 - p0).normalized()

		# Build coordinate frame (right = perpendicular on XZ plane)
		var up: Vector3 = Vector3.UP
		if absf(seg_dir.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var right: Vector3 = seg_dir.cross(up).normalized()
		up = right.cross(seg_dir).normalized()

		# Biome color blend along path
		var t0: float = seg_lengths[s] / maxf(path_length, 0.01)
		var t1: float = seg_lengths[s + 1] / maxf(path_length, 0.01)
		var col_floor0: Color = colors_a.floor.lerp(colors_b.floor, t0)
		var col_floor1: Color = colors_a.floor.lerp(colors_b.floor, t1)
		var col_wall0: Color = colors_a.wall.lerp(colors_b.wall, t0)
		var col_wall1: Color = colors_a.wall.lerp(colors_b.wall, t1)
		var col_ceil0: Color = colors_a.ceiling.lerp(colors_b.ceiling, t0)
		var col_ceil1: Color = colors_a.ceiling.lerp(colors_b.ceiling, t1)

		# Subtle organic width variation
		var w0: float = half_w * (1.0 + sin(t0 * PI) * 0.08 + sin(t0 * 6.0) * 0.02)
		var w1: float = half_w * (1.0 + sin(t1 * PI) * 0.08 + sin(t1 * 6.0) * 0.02)

		# Very subtle floor height variation (just enough to feel interesting)
		var floor_y0: float = _noise.get_noise_2d(p0.x, p0.z) * 0.12
		var floor_y1: float = _noise.get_noise_2d(p1.x, p1.z) * 0.12

		# Next segment direction for smooth frame at p1
		var next_dir: Vector3 = seg_dir
		if s + 2 < path.size():
			next_dir = (path[s + 2] - p1).normalized()
		var right1: Vector3 = next_dir.cross(up).normalized()

		# 4 corners at each cross-section
		# BL=bottom-left, BR=bottom-right, TL=top-left, TR=top-right
		var bl0: Vector3 = p0 - right * w0 + Vector3(0, floor_y0, 0)
		var br0: Vector3 = p0 + right * w0 + Vector3(0, floor_y0, 0)
		var tl0: Vector3 = p0 - right * w0 + Vector3(0, floor_y0 + hall_h, 0)
		var tr0: Vector3 = p0 + right * w0 + Vector3(0, floor_y0 + hall_h, 0)

		var bl1: Vector3 = p1 - right1 * w1 + Vector3(0, floor_y1, 0)
		var br1: Vector3 = p1 + right1 * w1 + Vector3(0, floor_y1, 0)
		var tl1: Vector3 = p1 - right1 * w1 + Vector3(0, floor_y1 + hall_h, 0)
		var tr1: Vector3 = p1 + right1 * w1 + Vector3(0, floor_y1 + hall_h, 0)

		# --- Floor (2 triangles, normal UP, viewed from above) ---
		_add_quad(st, bl0, br0, bl1, br1, Vector3.UP, col_floor0, col_floor1)

		# --- Ceiling (2 triangles, normal DOWN, viewed from below) ---
		_add_quad(st, tr0, tl0, tr1, tl1, -Vector3.UP, col_ceil0, col_ceil1)

		# --- Left wall (2 triangles, normal pointing right/inward) ---
		var left_normal: Vector3 = right
		_add_quad(st, bl0, tl0, bl1, tl1, left_normal, col_wall0, col_wall1)

		# --- Right wall (2 triangles, normal pointing left/inward) ---
		var right_normal: Vector3 = -right
		_add_quad(st, tr0, br0, tr1, br1, right_normal, col_wall0, col_wall1)

	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		return

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = node_name

	# Material with vertex colors
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # See from inside
	mat.emission_enabled = true
	var avg_emission: Color = colors_a.emission.lerp(colors_b.emission, 0.5)
	mat.emission = avg_emission * 0.12
	mat.emission_energy_multiplier = 0.25
	mi.material_override = mat
	add_child(mi)

	# Collision from mesh faces
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = node_name + "_Collision"
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.set_faces(mesh.get_faces())
	concave.backface_collision = true
	col_shape.shape = concave
	static_body.add_child(col_shape)
	add_child(static_body)

	# Wall cap at dead-end terminations
	if node_name.begins_with("DeadEnd"):
		_build_end_wall(path[-1], path[-2], base_width, hall_h, colors_a.wall.lerp(colors_b.wall, 0.5))

func _add_quad(st: SurfaceTool, v00: Vector3, v01: Vector3, v10: Vector3, v11: Vector3, normal: Vector3, col0: Color, col1: Color) -> void:
	## Adds a quad as 2 triangles. v00/v01 are at segment start, v10/v11 at segment end.
	# Triangle 1
	st.set_normal(normal)
	st.set_color(col0)
	st.add_vertex(v00)
	st.set_normal(normal)
	st.set_color(col1)
	st.add_vertex(v10)
	st.set_normal(normal)
	st.set_color(col0)
	st.add_vertex(v01)
	# Triangle 2
	st.set_normal(normal)
	st.set_color(col0)
	st.add_vertex(v01)
	st.set_normal(normal)
	st.set_color(col1)
	st.add_vertex(v10)
	st.set_normal(normal)
	st.set_color(col1)
	st.add_vertex(v11)

func _build_end_wall(pos: Vector3, prev_pos: Vector3, width: float, height: float, col: Color) -> void:
	## Flat wall cap at dead-end terminus
	var dir: Vector3 = (pos - prev_pos).normalized()
	var up: Vector3 = Vector3.UP
	if absf(dir.dot(up)) > 0.95:
		up = Vector3.RIGHT
	var right: Vector3 = dir.cross(up).normalized()

	var half_w: float = width * 0.35  # Slightly narrower at dead end
	var bl: Vector3 = pos - right * half_w
	var br: Vector3 = pos + right * half_w
	var tl: Vector3 = pos - right * half_w + Vector3(0, height, 0)
	var tr: Vector3 = pos + right * half_w + Vector3(0, height, 0)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n: Vector3 = -dir  # Faces back toward the hallway
	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(bl)
	st.set_color(col)
	st.add_vertex(tl)
	st.set_color(col)
	st.add_vertex(br)

	st.set_normal(n)
	st.set_color(col)
	st.add_vertex(br)
	st.set_color(col)
	st.add_vertex(tl)
	st.set_color(col)
	st.add_vertex(tr)

	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		return

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "EndWall"
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)

	# Wall collision
	var static_body: StaticBody3D = StaticBody3D.new()
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.set_faces(mesh.get_faces())
	concave.backface_collision = true
	col_shape.shape = concave
	static_body.add_child(col_shape)
	add_child(static_body)

extends Node3D
## Procedural cave tunnel: tube mesh along cubic Bezier path.
## Bottom 120 degrees flattened for walkability. Organic radius variation.
## Includes dead-end branches.

var _tunnel_data = null  # TunnelData from cave_generator
var _cave_gen = null  # Reference to cave_generator for biome colors

const TUBE_SEGMENTS: int = 16  # Cross-section resolution
const FLOOR_FLATTEN_ANGLE: float = PI * 2.0 / 3.0  # 120 degrees flattened bottom

func setup(tunnel_data, cave_gen) -> void:
	_tunnel_data = tunnel_data
	_cave_gen = cave_gen

func _ready() -> void:
	if _tunnel_data:
		_build_tunnel()

func _build_tunnel() -> void:
	var colors_a: Dictionary = _cave_gen.get_biome_colors(_tunnel_data.biome_a) if _cave_gen else _default_colors()
	var colors_b: Dictionary = _cave_gen.get_biome_colors(_tunnel_data.biome_b) if _cave_gen else _default_colors()

	# Build main tunnel
	_build_tube(_tunnel_data.path, _tunnel_data.width, colors_a, colors_b, "MainTunnel")

	# Build dead-end branches
	for i in range(_tunnel_data.dead_ends.size()):
		var dead_end: Dictionary = _tunnel_data.dead_ends[i]
		var branch_path: Array = dead_end.path
		if branch_path.size() < 2:
			continue
		# Dead ends use narrower width and blend both biomes
		var branch_width: float = _tunnel_data.width * 0.7
		_build_tube(branch_path, branch_width, colors_a, colors_b, "DeadEnd_%d" % i)

func _default_colors() -> Dictionary:
	return {
		"floor": Color(0.04, 0.08, 0.06),
		"wall": Color(0.03, 0.06, 0.05),
		"ceiling": Color(0.02, 0.05, 0.04),
		"emission": Color(0.1, 0.4, 0.3),
	}

func _build_tube(path: Array, base_width: float, colors_a: Dictionary, colors_b: Dictionary, node_name: String) -> void:
	if path.size() < 2:
		return

	# Calculate total path length and skip degenerate paths
	var total_len: float = 0.0
	for i in range(1, path.size()):
		total_len += path[i - 1].distance_to(path[i])
	if total_len < 0.5:
		return  # Skip degenerate tunnels

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var path_length: float = 0.0
	var seg_lengths: Array[float] = [0.0]
	for i in range(1, path.size()):
		path_length += path[i - 1].distance_to(path[i])
		seg_lengths.append(path_length)

	# Generate cross-section rings along path
	for s in range(path.size() - 1):
		var p0: Vector3 = path[s]
		var p1: Vector3 = path[s + 1]
		var seg_dir: Vector3 = (p1 - p0).normalized()

		# Build coordinate frame
		var up: Vector3 = Vector3.UP
		if absf(seg_dir.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var right: Vector3 = seg_dir.cross(up).normalized()
		up = right.cross(seg_dir).normalized()

		# Organic radius variation along path
		var t0: float = seg_lengths[s] / maxf(path_length, 0.01)
		var t1: float = seg_lengths[s + 1] / maxf(path_length, 0.01)

		# Width narrows at endpoints, widens in middle
		var width_mult0: float = 0.85 + sin(t0 * PI) * 0.15 + sin(t0 * 8.0) * 0.04
		var width_mult1: float = 0.85 + sin(t1 * PI) * 0.15 + sin(t1 * 8.0) * 0.04

		var r0: float = base_width * 0.5 * width_mult0
		var r1: float = base_width * 0.5 * width_mult1

		# Height is taller than width for natural tunnel feel
		var h0: float = r0 * 1.3
		var h1: float = r1 * 1.3

		# Biome color blend
		var blend0: float = t0
		var blend1: float = t1
		var col0_wall: Color = colors_a.wall.lerp(colors_b.wall, blend0)
		var col1_wall: Color = colors_a.wall.lerp(colors_b.wall, blend1)
		var col0_floor: Color = colors_a.floor.lerp(colors_b.floor, blend0)
		var col1_floor: Color = colors_a.floor.lerp(colors_b.floor, blend1)

		# Next segment direction for smooth normals at p1
		var next_dir: Vector3 = seg_dir
		if s + 2 < path.size():
			next_dir = (path[s + 2] - p1).normalized()
		var right1: Vector3 = next_dir.cross(up).normalized()
		var up1: Vector3 = right1.cross(next_dir).normalized()

		for i in range(TUBE_SEGMENTS):
			var a0: float = TAU * i / TUBE_SEGMENTS
			var a1: float = TAU * (i + 1) / TUBE_SEGMENTS

			# Apply floor flattening: bottom 120 degrees gets squashed
			var eff_r0_a0: float = _get_effective_radius(a0, r0, h0)
			var eff_r0_a1: float = _get_effective_radius(a1, r0, h0)
			var eff_r1_a0: float = _get_effective_radius(a0, r1, h1)
			var eff_r1_a1: float = _get_effective_radius(a1, r1, h1)

			var eff_y0_a0: float = _get_effective_y(a0, r0, h0)
			var eff_y0_a1: float = _get_effective_y(a1, r0, h0)
			var eff_y1_a0: float = _get_effective_y(a0, r1, h1)
			var eff_y1_a1: float = _get_effective_y(a1, r1, h1)

			var v00: Vector3 = p0 + right * cos(a0) * eff_r0_a0 + up * eff_y0_a0
			var v01: Vector3 = p0 + right * cos(a1) * eff_r0_a1 + up * eff_y0_a1
			var v10: Vector3 = p1 + right1 * cos(a0) * eff_r1_a0 + up1 * eff_y1_a0
			var v11: Vector3 = p1 + right1 * cos(a1) * eff_r1_a1 + up1 * eff_y1_a1

			# Inward-facing normals
			var n00: Vector3 = -(right * cos(a0) + up * sin(a0)).normalized()
			var n01: Vector3 = -(right * cos(a1) + up * sin(a1)).normalized()

			# Color: floor sections get floor color, walls/ceiling get wall color
			var is_floor0: bool = _is_floor_angle(a0)
			var is_floor1: bool = _is_floor_angle(a1)
			var vc00: Color = col0_floor if is_floor0 else col0_wall
			var vc01: Color = col0_floor if is_floor1 else col0_wall
			var vc10: Color = col1_floor if is_floor0 else col1_wall
			var vc11: Color = col1_floor if is_floor1 else col1_wall

			# Triangle 1 (interior winding)
			st.set_normal(n00)
			st.set_color(vc00)
			st.add_vertex(v00)
			st.set_normal(n00)
			st.set_color(vc10)
			st.add_vertex(v10)
			st.set_normal(n01)
			st.set_color(vc01)
			st.add_vertex(v01)

			# Triangle 2
			st.set_normal(n01)
			st.set_color(vc01)
			st.add_vertex(v01)
			st.set_normal(n00)
			st.set_color(vc10)
			st.add_vertex(v10)
			st.set_normal(n01)
			st.set_color(vc11)
			st.add_vertex(v11)

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
	mat.cull_mode = BaseMaterial3D.CULL_FRONT  # See interior
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

	# Cap at dead-end terminations
	if node_name.begins_with("DeadEnd"):
		_build_end_cap(path[-1], path[-2], base_width * 0.7 * 0.5, colors_a.wall.lerp(colors_b.wall, 0.5))

func _get_effective_radius(angle: float, radius: float, height: float) -> float:
	# Bottom 120 degrees (centered at -PI/2 aka straight down) gets flattened
	var down_angle: float = -PI * 0.5
	var angle_from_down: float = _angle_diff(angle, down_angle)

	if absf(angle_from_down) < FLOOR_FLATTEN_ANGLE * 0.5:
		# In floor zone: use radius for horizontal, flatten vertical
		return radius
	return radius

func _get_effective_y(angle: float, radius: float, height: float) -> float:
	var down_angle: float = -PI * 0.5
	var angle_from_down: float = _angle_diff(angle, down_angle)

	if absf(angle_from_down) < FLOOR_FLATTEN_ANGLE * 0.5:
		# Floor zone: flatten Y to a consistent level
		var floor_y: float = -height * 0.65  # Floor slightly below center
		var blend: float = absf(angle_from_down) / (FLOOR_FLATTEN_ANGLE * 0.5)
		blend = blend * blend  # Smooth transition
		return lerpf(floor_y, sin(angle) * height, blend)
	return sin(angle) * height

func _is_floor_angle(angle: float) -> bool:
	var down_angle: float = -PI * 0.5
	var angle_from_down: float = _angle_diff(angle, down_angle)
	return absf(angle_from_down) < FLOOR_FLATTEN_ANGLE * 0.5

func _angle_diff(a: float, b: float) -> float:
	var diff: float = fmod(a - b + PI, TAU) - PI
	return diff

func _build_end_cap(pos: Vector3, prev_pos: Vector3, radius: float, col: Color) -> void:
	# Simple hemisphere cap at dead-end terminus
	var dir: Vector3 = (pos - prev_pos).normalized()
	var up: Vector3 = Vector3.UP
	if absf(dir.dot(up)) > 0.95:
		up = Vector3.RIGHT
	var right: Vector3 = dir.cross(up).normalized()
	up = right.cross(dir).normalized()

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var cap_rings: int = 6
	var cap_sectors: int = 8

	for ring in range(cap_rings):
		var theta0: float = PI * 0.5 * ring / cap_rings
		var theta1: float = PI * 0.5 * (ring + 1) / cap_rings
		for sector in range(cap_sectors):
			var phi0: float = TAU * sector / cap_sectors
			var phi1: float = TAU * (sector + 1) / cap_sectors

			var v00: Vector3 = pos + (dir * cos(theta0) + right * sin(theta0) * cos(phi0) + up * sin(theta0) * sin(phi0)) * radius
			var v01: Vector3 = pos + (dir * cos(theta0) + right * sin(theta0) * cos(phi1) + up * sin(theta0) * sin(phi1)) * radius
			var v10: Vector3 = pos + (dir * cos(theta1) + right * sin(theta1) * cos(phi0) + up * sin(theta1) * sin(phi0)) * radius
			var v11: Vector3 = pos + (dir * cos(theta1) + right * sin(theta1) * cos(phi1) + up * sin(theta1) * sin(phi1)) * radius

			var n: Vector3 = -dir
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(v00)
			st.set_color(col)
			st.add_vertex(v10)
			st.set_color(col)
			st.add_vertex(v01)

			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(v01)
			st.set_color(col)
			st.add_vertex(v10)
			st.set_color(col)
			st.add_vertex(v11)

	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		return

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "EndCap"

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mi.material_override = mat
	add_child(mi)

	# Cap collision
	var static_body: StaticBody3D = StaticBody3D.new()
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.set_faces(mesh.get_faces())
	concave.backface_collision = true
	col_shape.shape = concave
	static_body.add_child(col_shape)
	add_child(static_body)

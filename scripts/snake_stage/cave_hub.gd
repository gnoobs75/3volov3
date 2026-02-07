extends Node3D
## Procedural cave hub: floor, ceiling, walls as SurfaceTool meshes.
## Biome-colored materials, collision via ConcavePolygonShape3D.

var _hub_data = null  # HubData from cave_generator
var _floor_heightmap: Array = []  # 2D array of floor heights for queries
var _grid_size: int = 0
var _noise: FastNoiseLite = null
var _tunnel_connection_points: Array[Vector3] = []  # Local-space XZ of tunnel mouths

func setup(hub_data) -> void:
	_hub_data = hub_data

func add_tunnel_connection(world_pos: Vector3) -> void:
	_tunnel_connection_points.append(world_pos)

func _ready() -> void:
	if _hub_data:
		_build_hub()

func _build_hub() -> void:
	position = _hub_data.position

	# Noise for floor/ceiling variation
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.04
	_noise.seed = _hub_data.id * 137 + 42

	var biome_colors: Dictionary = _get_biome_colors()

	_build_floor(biome_colors)
	_build_ceiling(biome_colors)
	_build_walls(biome_colors)

	# Add tunnel mouth lights (deferred so tunnel connections are registered)
	call_deferred("_add_tunnel_mouth_lights", biome_colors)

func _add_tunnel_mouth_lights(colors: Dictionary) -> void:
	for conn_world_pos in _tunnel_connection_points:
		var local_pos: Vector3 = conn_world_pos - position
		# Place light at tunnel mouth, slightly above floor
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "TunnelMouthLight"
		light.light_color = colors.emission.lightened(0.3)
		light.light_energy = 0.3
		light.omni_range = 5.0
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.position = local_pos + Vector3(0, 1.5, 0)
		add_child(light)

func _get_biome_colors() -> Dictionary:
	var CaveGen = load("res://scripts/snake_stage/cave_generator.gd")
	if CaveGen:
		var biome_key: int = _hub_data.biome
		if biome_key in CaveGen.BIOME_COLORS:
			return CaveGen.BIOME_COLORS[biome_key]
	# Fallback (Stomach colors)
	return {
		"floor": Color(0.06, 0.08, 0.02),
		"wall": Color(0.05, 0.07, 0.02),
		"ceiling": Color(0.04, 0.06, 0.02),
		"emission": Color(0.3, 0.5, 0.1),
		"ambient": Color(0.08, 0.12, 0.03),
		"fog": Color(0.04, 0.06, 0.02),
	}

func _build_floor(colors: Dictionary) -> void:
	var radius: float = _hub_data.radius
	var subdivs: int = clampi(int(radius * 0.5), 12, 40)
	_grid_size = subdivs + 1

	# Generate heightmap
	_floor_heightmap.resize(_grid_size)
	for gx in range(_grid_size):
		_floor_heightmap[gx] = []
		_floor_heightmap[gx].resize(_grid_size)
		for gz in range(_grid_size):
			var wx: float = (float(gx) / subdivs - 0.5) * radius * 2.0
			var wz: float = (float(gz) / subdivs - 0.5) * radius * 2.0
			var dist_from_center: float = Vector2(wx, wz).length()
			var height_noise: float = _noise.get_noise_2d(wx, wz) * 2.0

			# Floor rises toward edges (bowl shape)
			var edge_factor: float = clampf(dist_from_center / radius, 0.0, 1.0)
			var edge_rise: float = edge_factor * edge_factor * edge_factor * _hub_data.height * 0.4

			_floor_heightmap[gx][gz] = height_noise + edge_rise

	# Flatten floor in 5-unit radius around tunnel connection points
	for conn_world_pos in _tunnel_connection_points:
		var local_x: float = conn_world_pos.x - _hub_data.position.x
		var local_z: float = conn_world_pos.z - _hub_data.position.z
		for gx2 in range(_grid_size):
			for gz2 in range(_grid_size):
				var wx2: float = (float(gx2) / subdivs - 0.5) * radius * 2.0
				var wz2: float = (float(gz2) / subdivs - 0.5) * radius * 2.0
				var d: float = Vector2(wx2 - local_x, wz2 - local_z).length()
				if d < 5.0:
					var blend: float = d / 5.0
					blend = blend * blend  # Smooth falloff
					_floor_heightmap[gx2][gz2] = lerpf(0.0, _floor_heightmap[gx2][gz2], blend)

	# Build mesh
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gx in range(subdivs):
		for gz in range(subdivs):
			var x0: float = (float(gx) / subdivs - 0.5) * radius * 2.0
			var x1: float = (float(gx + 1) / subdivs - 0.5) * radius * 2.0
			var z0: float = (float(gz) / subdivs - 0.5) * radius * 2.0
			var z1: float = (float(gz + 1) / subdivs - 0.5) * radius * 2.0

			# Skip cells outside circle
			var cx: float = (x0 + x1) * 0.5
			var cz: float = (z0 + z1) * 0.5
			if Vector2(cx, cz).length() > radius * 1.05:
				continue

			var y00: float = _floor_heightmap[gx][gz]
			var y10: float = _floor_heightmap[gx + 1][gz]
			var y01: float = _floor_heightmap[gx][gz + 1]
			var y11: float = _floor_heightmap[gx + 1][gz + 1]

			var v00: Vector3 = Vector3(x0, y00, z0)
			var v10: Vector3 = Vector3(x1, y10, z0)
			var v01: Vector3 = Vector3(x0, y01, z1)
			var v11: Vector3 = Vector3(x1, y11, z1)

			# Normals via cross product (CCW winding from above = upward normals)
			var n0: Vector3 = (v01 - v00).cross(v10 - v00).normalized()
			var n1: Vector3 = (v10 - v11).cross(v01 - v11).normalized()

			# Vertex colors based on height
			var col_base: Color = colors.floor
			var col_low: Color = col_base.lightened(0.1)
			var col_high: Color = col_base.darkened(0.2)

			# Triangle 1 (v00, v01, v10 — CCW from above)
			st.set_normal(n0)
			st.set_color(col_low.lerp(col_high, clampf(y00 / 3.0, 0.0, 1.0)))
			st.add_vertex(v00)
			st.set_color(col_low.lerp(col_high, clampf(y01 / 3.0, 0.0, 1.0)))
			st.add_vertex(v01)
			st.set_color(col_low.lerp(col_high, clampf(y10 / 3.0, 0.0, 1.0)))
			st.add_vertex(v10)

			# Triangle 2 (v01, v11, v10 — CCW from above)
			st.set_normal(n1)
			st.set_color(col_low.lerp(col_high, clampf(y01 / 3.0, 0.0, 1.0)))
			st.add_vertex(v01)
			st.set_color(col_low.lerp(col_high, clampf(y11 / 3.0, 0.0, 1.0)))
			st.add_vertex(v11)
			st.set_color(col_low.lerp(col_high, clampf(y10 / 3.0, 0.0, 1.0)))
			st.add_vertex(v10)

	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		return

	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	floor_mi.mesh = mesh
	floor_mi.name = "Floor"

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mat.emission_enabled = true
	mat.emission = colors.emission * 0.15
	mat.emission_energy_multiplier = 0.3
	floor_mi.material_override = mat
	add_child(floor_mi)

	# Floor collision
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "FloorCollision"
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.set_faces(mesh.get_faces())
	concave.backface_collision = true
	col_shape.shape = concave
	static_body.add_child(col_shape)
	add_child(static_body)

func _build_ceiling(colors: Dictionary) -> void:
	var radius: float = _hub_data.radius
	var height: float = _hub_data.height
	var subdivs: int = clampi(int(radius * 0.4), 10, 30)

	var ceiling_noise: FastNoiseLite = FastNoiseLite.new()
	ceiling_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ceiling_noise.frequency = 0.06
	ceiling_noise.seed = _hub_data.id * 271 + 99

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gx in range(subdivs):
		for gz in range(subdivs):
			var x0: float = (float(gx) / subdivs - 0.5) * radius * 2.0
			var x1: float = (float(gx + 1) / subdivs - 0.5) * radius * 2.0
			var z0: float = (float(gz) / subdivs - 0.5) * radius * 2.0
			var z1: float = (float(gz + 1) / subdivs - 0.5) * radius * 2.0

			var cx: float = (x0 + x1) * 0.5
			var cz: float = (z0 + z1) * 0.5
			if Vector2(cx, cz).length() > radius * 1.05:
				continue

			# Ceiling height: base height - stalactite noise - edge droop
			var edge00: float = clampf(Vector2(x0, z0).length() / radius, 0.0, 1.0)
			var edge10: float = clampf(Vector2(x1, z0).length() / radius, 0.0, 1.0)
			var edge01: float = clampf(Vector2(x0, z1).length() / radius, 0.0, 1.0)
			var edge11: float = clampf(Vector2(x1, z1).length() / radius, 0.0, 1.0)

			var y00: float = height - absf(ceiling_noise.get_noise_2d(x0, z0)) * 3.0 - edge00 * edge00 * height * 0.4
			var y10: float = height - absf(ceiling_noise.get_noise_2d(x1, z0)) * 3.0 - edge10 * edge10 * height * 0.4
			var y01: float = height - absf(ceiling_noise.get_noise_2d(x0, z1)) * 3.0 - edge01 * edge01 * height * 0.4
			var y11: float = height - absf(ceiling_noise.get_noise_2d(x1, z1)) * 3.0 - edge11 * edge11 * height * 0.4

			var v00: Vector3 = Vector3(x0, y00, z0)
			var v10: Vector3 = Vector3(x1, y10, z0)
			var v01: Vector3 = Vector3(x0, y01, z1)
			var v11: Vector3 = Vector3(x1, y11, z1)

			# Normals face DOWN for ceiling
			var n0: Vector3 = (v01 - v00).cross(v10 - v00).normalized()
			var n1: Vector3 = (v10 - v11).cross(v01 - v11).normalized()

			var col: Color = colors.ceiling

			# Triangle 1 (reversed winding for interior view)
			st.set_normal(n0)
			st.set_color(col)
			st.add_vertex(v00)
			st.set_color(col)
			st.add_vertex(v01)
			st.set_color(col)
			st.add_vertex(v10)

			# Triangle 2
			st.set_normal(n1)
			st.set_color(col)
			st.add_vertex(v01)
			st.set_color(col)
			st.add_vertex(v11)
			st.set_color(col)
			st.add_vertex(v10)

	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		return

	var ceil_mi: MeshInstance3D = MeshInstance3D.new()
	ceil_mi.mesh = mesh
	ceil_mi.name = "Ceiling"

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.emission_enabled = true
	mat.emission = colors.emission * 0.08
	mat.emission_energy_multiplier = 0.2
	ceil_mi.material_override = mat
	add_child(ceil_mi)

	# Ceiling collision
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "CeilingCollision"
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.set_faces(mesh.get_faces())
	concave.backface_collision = true
	col_shape.shape = concave
	static_body.add_child(col_shape)
	add_child(static_body)

func _build_walls(colors: Dictionary) -> void:
	var radius: float = _hub_data.radius
	var height: float = _hub_data.height
	var segments: int = clampi(int(radius * 0.8), 16, 48)
	var rings: int = clampi(int(height * 0.5), 4, 12)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for seg in range(segments):
		var angle0: float = TAU * seg / segments
		var angle1: float = TAU * (seg + 1) / segments

		for ring in range(rings):
			var t0: float = float(ring) / rings
			var t1: float = float(ring + 1) / rings
			var y0: float = lerpf(0, height, t0)
			var y1: float = lerpf(0, height, t1)

			# Wall radius varies: tighter at mid-height, wider at floor/ceiling
			var bulge0: float = 1.0 + sin(t0 * PI) * 0.08
			var bulge1: float = 1.0 + sin(t1 * PI) * 0.08

			# Add noise variation
			var n0_val: float = _noise.get_noise_2d(angle0 * 10.0, y0 * 0.5) * radius * 0.05
			var n1_val: float = _noise.get_noise_2d(angle1 * 10.0, y0 * 0.5) * radius * 0.05
			var n2_val: float = _noise.get_noise_2d(angle0 * 10.0, y1 * 0.5) * radius * 0.05
			var n3_val: float = _noise.get_noise_2d(angle1 * 10.0, y1 * 0.5) * radius * 0.05

			var r00: float = radius * bulge0 + n0_val
			var r10: float = radius * bulge0 + n1_val
			var r01: float = radius * bulge1 + n2_val
			var r11: float = radius * bulge1 + n3_val

			var v00: Vector3 = Vector3(cos(angle0) * r00, y0, sin(angle0) * r00)
			var v10: Vector3 = Vector3(cos(angle1) * r10, y0, sin(angle1) * r10)
			var v01: Vector3 = Vector3(cos(angle0) * r01, y1, sin(angle0) * r01)
			var v11: Vector3 = Vector3(cos(angle1) * r11, y1, sin(angle1) * r11)

			# Inward-facing normals
			var normal00: Vector3 = -Vector3(cos(angle0), 0, sin(angle0)).normalized()
			var normal10: Vector3 = -Vector3(cos(angle1), 0, sin(angle1)).normalized()

			var col: Color = colors.wall
			# Darken lower walls, lighter upper
			var shade0: Color = col.darkened(t0 * 0.15)
			var shade1: Color = col.darkened(t1 * 0.15)

			# Triangle 1 (reversed winding for interior)
			st.set_normal(normal00)
			st.set_color(shade0)
			st.add_vertex(v00)
			st.set_normal(normal00)
			st.set_color(shade1)
			st.add_vertex(v01)
			st.set_normal(normal10)
			st.set_color(shade0)
			st.add_vertex(v10)

			# Triangle 2
			st.set_normal(normal10)
			st.set_color(shade0)
			st.add_vertex(v10)
			st.set_normal(normal00)
			st.set_color(shade1)
			st.add_vertex(v01)
			st.set_normal(normal10)
			st.set_color(shade1)
			st.add_vertex(v11)

	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		return

	var wall_mi: MeshInstance3D = MeshInstance3D.new()
	wall_mi.mesh = mesh
	wall_mi.name = "Walls"

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.emission_enabled = true
	mat.emission = colors.emission * 0.1
	mat.emission_energy_multiplier = 0.25
	wall_mi.material_override = mat
	add_child(wall_mi)

	# Wall collision
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "WallCollision"
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.set_faces(mesh.get_faces())
	concave.backface_collision = true
	col_shape.shape = concave
	static_body.add_child(col_shape)
	add_child(static_body)

# --- Floor height query ---
func get_floor_y(world_x: float, world_z: float) -> float:
	if _floor_heightmap.size() == 0 or _grid_size <= 1:
		return global_position.y

	var local_x: float = world_x - global_position.x
	var local_z: float = world_z - global_position.z
	var radius: float = _hub_data.radius

	# Convert to grid coordinates
	var gx: float = (local_x / (radius * 2.0) + 0.5) * (_grid_size - 1)
	var gz: float = (local_z / (radius * 2.0) + 0.5) * (_grid_size - 1)

	var ix: int = clampi(int(gx), 0, _grid_size - 2)
	var iz: int = clampi(int(gz), 0, _grid_size - 2)
	var fx: float = clampf(gx - ix, 0.0, 1.0)
	var fz: float = clampf(gz - iz, 0.0, 1.0)

	# Bilinear interpolation
	var h00: float = _floor_heightmap[ix][iz]
	var h10: float = _floor_heightmap[ix + 1][iz]
	var h01: float = _floor_heightmap[ix][iz + 1]
	var h11: float = _floor_heightmap[ix + 1][iz + 1]

	var h: float = lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)
	return global_position.y + h

class_name TunnelEnhancer
extends RefCounted
## Adds organic details to tunnel tubes: vein ridges and glow veins.
## Called after tunnel mesh is built.

static func enhance_tunnel(parent: Node3D, tunnel_data, cave_gen) -> void:
	if tunnel_data.path.size() < 4:
		return

	var colors_a: Dictionary = cave_gen.get_biome_colors(tunnel_data.biome_a) if cave_gen else {}
	var colors_b: Dictionary = cave_gen.get_biome_colors(tunnel_data.biome_b) if cave_gen else {}
	if colors_a.is_empty() or colors_b.is_empty():
		return

	_add_vein_ridges(parent, tunnel_data, colors_a, colors_b)
	_add_glow_veins(parent, tunnel_data, colors_a, colors_b)

# --- Vein ridges: raised bumps along tunnel walls ---
static func _add_vein_ridges(parent: Node3D, td, colors_a: Dictionary, colors_b: Dictionary) -> void:
	var path: Array = td.path
	var width: float = td.width

	# Small bump mesh
	var bump_mesh: SphereMesh = SphereMesh.new()
	bump_mesh.radius = 0.15
	bump_mesh.height = 0.3
	bump_mesh.radial_segments = 4
	bump_mesh.rings = 2
	var bump_mat: StandardMaterial3D = StandardMaterial3D.new()
	bump_mat.roughness = 0.8
	bump_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Average emission of both biomes
	var avg_emission: Color = colors_a.get("emission", Color.WHITE).lerp(
		colors_b.get("emission", Color.WHITE), 0.5)
	var avg_wall: Color = colors_a.get("wall", Color(0.05, 0.05, 0.05)).lerp(
		colors_b.get("wall", Color(0.05, 0.05, 0.05)), 0.5)
	bump_mat.albedo_color = avg_wall.lightened(0.15)
	bump_mat.emission_enabled = true
	bump_mat.emission = avg_emission * 0.2
	bump_mat.emission_energy_multiplier = 0.2

	# Place bumps along path (skip first/last few points to avoid hub overlap)
	var ridge_count: int = clampi(int(path.size() * 0.6), 8, 40)
	var mm: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm.name = "VeinRidges"
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = ridge_count
	multimesh.mesh = bump_mesh
	mm.multimesh = multimesh
	mm.material_override = bump_mat

	for i in range(ridge_count):
		# Pick a point along the path
		var path_t: float = randf_range(0.15, 0.85)
		var path_idx: int = clampi(int(path_t * (path.size() - 1)), 1, path.size() - 2)
		var center: Vector3 = path[path_idx]

		# Direction along tunnel
		var fwd: Vector3 = (path[path_idx + 1] - path[path_idx - 1]).normalized()
		var up: Vector3 = Vector3.UP
		if absf(fwd.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var right: Vector3 = fwd.cross(up).normalized()
		up = right.cross(fwd).normalized()

		# Place on walls or ceiling of rectangular hallway
		var hall_h: float = width * 0.6
		var side: int = randi_range(0, 2)  # 0=left wall, 1=right wall, 2=ceiling
		var pos: Vector3
		if side == 0:
			pos = center - right * width * 0.48 + Vector3(0, randf_range(0.2, hall_h * 0.8), 0)
		elif side == 1:
			pos = center + right * width * 0.48 + Vector3(0, randf_range(0.2, hall_h * 0.8), 0)
		else:
			pos = center + right * randf_range(-width * 0.3, width * 0.3) + Vector3(0, hall_h * randf_range(0.85, 0.95), 0)

		var s: float = randf_range(0.5, 1.8)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(s, s * randf_range(0.5, 1.5), s))
		multimesh.set_instance_transform(i, Transform3D(basis, pos))

	parent.add_child(mm)

# --- Glow veins: small emissive lights along tunnel path ---
static func _add_glow_veins(parent: Node3D, td, colors_a: Dictionary, colors_b: Dictionary) -> void:
	var path: Array = td.path
	if path.size() < 6:
		return

	# Place a few lights along the tunnel to illuminate it
	var light_count: int = clampi(int(path.size() * 0.15), 2, 6)
	var container: Node3D = Node3D.new()
	container.name = "TunnelGlowVeins"

	for i in range(light_count):
		var t: float = float(i + 1) / (light_count + 1)
		var idx: int = clampi(int(t * (path.size() - 1)), 0, path.size() - 1)
		var pos: Vector3 = path[idx]

		# Blend biome colors along path
		var emission: Color = colors_a.get("emission", Color.WHITE).lerp(
			colors_b.get("emission", Color.WHITE), t)

		var light: OmniLight3D = OmniLight3D.new()
		light.name = "GlowVein_%d" % i
		light.light_color = emission.lightened(0.2)
		light.light_energy = randf_range(0.1, 0.25)
		light.omni_range = td.width * randf_range(0.6, 1.0)
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.position = pos + Vector3(0, td.width * 0.6 * 0.8, 0)  # Near ceiling of hallway
		container.add_child(light)

		# Small emissive sphere at light position
		var glow: MeshInstance3D = MeshInstance3D.new()
		var glow_mesh: SphereMesh = SphereMesh.new()
		glow_mesh.radius = 0.12
		glow_mesh.height = 0.24
		glow_mesh.radial_segments = 4
		glow_mesh.rings = 2
		glow.mesh = glow_mesh
		var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
		glow_mat.albedo_color = emission * 0.4
		glow_mat.emission_enabled = true
		glow_mat.emission = emission
		glow_mat.emission_energy_multiplier = 1.5
		glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		glow.material_override = glow_mat
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = light.position
		container.add_child(glow)

	parent.add_child(container)

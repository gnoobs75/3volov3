class_name BiomeDecorator
extends RefCounted
## Creates organ-specific MultiMesh decorations for cave hubs.
## Static factory: call decorate_hub() after hub geometry is built.

# Biome enum mirror (matches cave_generator.gd Biome enum values)
const STOMACH = 0
const HEART_CHAMBER = 1
const INTESTINAL_TRACT = 2
const LUNG_TISSUE = 3
const BONE_MARROW = 4
const LIVER = 5
const BRAIN = 6

static func decorate_hub(parent: Node3D, hub_data, biome_colors: Dictionary) -> void:
	var container: Node3D = Node3D.new()
	container.name = "Decorations"

	match hub_data.biome:
		STOMACH: _stomach(container, hub_data, biome_colors)
		HEART_CHAMBER: _heart(container, hub_data, biome_colors)
		INTESTINAL_TRACT: _intestine(container, hub_data, biome_colors)
		LUNG_TISSUE: _lung(container, hub_data, biome_colors)
		BONE_MARROW: _bone_marrow(container, hub_data, biome_colors)
		LIVER: _liver(container, hub_data, biome_colors)
		BRAIN: _brain(container, hub_data, biome_colors)

	parent.add_child(container)

# --- Stomach: gastric folds, mucus strands, acid pools ---
static func _stomach(c: Node3D, hd, colors: Dictionary) -> void:
	var r: float = hd.radius
	var h: float = hd.height

	# Gastric fold ridges on walls (flattened ellipsoids)
	var fold_mesh: SphereMesh = SphereMesh.new()
	fold_mesh.radius = 1.0
	fold_mesh.height = 2.0
	fold_mesh.radial_segments = 8
	fold_mesh.rings = 4
	var fold_mat: StandardMaterial3D = _make_mat(
		colors.wall.lightened(0.15), colors.emission * 0.3, 0.3)
	var fold_count: int = clampi(int(TAU * r * h * 0.008), 15, 60)
	var fold_mm: MultiMeshInstance3D = _create_mm(fold_mesh, fold_mat, fold_count)
	for i in range(fold_count):
		var angle: float = randf() * TAU
		var y: float = randf_range(0.5, h * 0.7)
		var pos: Vector3 = Vector3(cos(angle) * r * 0.96, y, sin(angle) * r * 0.96)
		var basis: Basis = _wall_basis(angle)
		basis = basis.scaled(Vector3(randf_range(1.5, 3.0), randf_range(0.2, 0.4), randf_range(0.8, 1.5)))
		fold_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(fold_mm)

	# Mucus strands hanging from ceiling
	var strand_mesh: CylinderMesh = CylinderMesh.new()
	strand_mesh.top_radius = 0.03
	strand_mesh.bottom_radius = 0.06
	strand_mesh.height = 1.0
	strand_mesh.radial_segments = 4
	var strand_mat: StandardMaterial3D = _make_mat(
		Color(0.15, 0.2, 0.05, 0.6), colors.emission * 0.5, 0.4)
	strand_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var strand_count: int = clampi(int(PI * r * r * 0.003), 5, 20)
	var strand_mm: MultiMeshInstance3D = _create_mm(strand_mesh, strand_mat, strand_count)
	for i in range(strand_count):
		var angle: float = randf() * TAU
		var dist: float = r * sqrt(randf()) * 0.7
		var strand_len: float = randf_range(1.5, minf(4.0, h * 0.4))
		var pos: Vector3 = Vector3(cos(angle) * dist, h - strand_len * 0.5, sin(angle) * dist)
		var s: float = randf_range(0.8, 1.2)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(s, strand_len, s))
		strand_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(strand_mm)

	# Acid pools on floor
	_add_floor_pools(c, hd, Color(0.2, 0.45, 0.08, 0.5), colors.emission,
		clampi(int(r * 0.12), 2, 6), 2.5)

# --- Heart Chamber: vein ridges, muscle fibers ---
static func _heart(c: Node3D, hd, colors: Dictionary) -> void:
	var r: float = hd.radius
	var h: float = hd.height

	# Vein ridges on walls (cylinders running tangent along wall)
	var vein_mesh: CylinderMesh = CylinderMesh.new()
	vein_mesh.top_radius = 0.1
	vein_mesh.bottom_radius = 0.12
	vein_mesh.height = 1.0
	vein_mesh.radial_segments = 6
	var vein_mat: StandardMaterial3D = _make_mat(
		Color(0.15, 0.02, 0.02), Color(0.7, 0.08, 0.05) * 0.5, 0.5)
	var vein_count: int = clampi(int(TAU * r * 0.3), 20, 80)
	var vein_mm: MultiMeshInstance3D = _create_mm(vein_mesh, vein_mat, vein_count)
	for i in range(vein_count):
		var angle: float = randf() * TAU
		var y: float = randf_range(0.5, h * 0.8)
		var pos: Vector3 = Vector3(cos(angle) * r * 0.95, y, sin(angle) * r * 0.95)
		# Cylinder Y-axis = tangent direction along wall
		var tangent: Vector3 = Vector3(-sin(angle), randf_range(-0.15, 0.15), cos(angle)).normalized()
		var inward: Vector3 = -Vector3(cos(angle), 0, sin(angle))
		var up_ax: Vector3 = inward.cross(tangent).normalized()
		var basis: Basis = Basis(inward, tangent, up_ax)
		var vlen: float = randf_range(2.0, 6.0)
		basis = basis.scaled(Vector3(randf_range(0.8, 1.5), vlen, randf_range(0.8, 1.5)))
		vein_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(vein_mm)

	# Cardiac muscle fiber bumps on walls
	var fiber_mesh: SphereMesh = SphereMesh.new()
	fiber_mesh.radius = 0.5
	fiber_mesh.height = 1.0
	fiber_mesh.radial_segments = 6
	fiber_mesh.rings = 3
	var fiber_mat: StandardMaterial3D = _make_mat(
		colors.wall.lightened(0.1), colors.emission * 0.3, 0.2)
	var fiber_count: int = clampi(int(TAU * r * h * 0.005), 10, 40)
	var fiber_mm: MultiMeshInstance3D = _create_mm(fiber_mesh, fiber_mat, fiber_count)
	for i in range(fiber_count):
		var angle: float = randf() * TAU
		var y: float = randf_range(0.3, h * 0.85)
		var pos: Vector3 = Vector3(cos(angle) * r * 0.94, y, sin(angle) * r * 0.94)
		var basis: Basis = _wall_basis(angle)
		basis = basis.scaled(Vector3(randf_range(0.4, 0.8), randf_range(1.5, 3.0), randf_range(0.3, 0.5)))
		fiber_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(fiber_mm)

	# Blood pools on floor
	_add_floor_pools(c, hd, Color(0.3, 0.02, 0.02, 0.4), Color(0.6, 0.05, 0.03),
		clampi(int(r * 0.08), 1, 4), 2.0)

# --- Intestinal Tract: dense villi on walls and floor ---
static func _intestine(c: Node3D, hd, colors: Dictionary) -> void:
	var r: float = hd.radius
	var h: float = hd.height

	# Dense villi on walls (finger-like projections pointing inward)
	var villi_mesh: CylinderMesh = CylinderMesh.new()
	villi_mesh.top_radius = 0.04
	villi_mesh.bottom_radius = 0.12
	villi_mesh.height = 0.6
	villi_mesh.radial_segments = 5
	var villi_mat: StandardMaterial3D = _make_mat(
		Color(0.12, 0.07, 0.06), colors.emission * 0.3, 0.25)
	var villi_count: int = clampi(int(TAU * r * h * 0.02), 40, 150)
	var villi_mm: MultiMeshInstance3D = _create_mm(villi_mesh, villi_mat, villi_count)
	for i in range(villi_count):
		var angle: float = randf() * TAU
		var y: float = randf_range(0.3, h * 0.8)
		var pos: Vector3 = Vector3(cos(angle) * r * 0.93, y, sin(angle) * r * 0.93)
		var basis: Basis = _wall_protrusion_basis(angle)
		var s: float = randf_range(0.6, 1.4)
		basis = basis.scaled(Vector3(s, randf_range(0.5, 1.5), s))
		villi_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(villi_mm)

	# Floor villi near edges (smaller, upright)
	var fv_count: int = clampi(int(r * 0.8), 10, 40)
	var fv_mm: MultiMeshInstance3D = _create_mm(villi_mesh, villi_mat, fv_count)
	for i in range(fv_count):
		var angle: float = randf() * TAU
		var dist: float = r * randf_range(0.4, 0.85)
		var pos: Vector3 = Vector3(cos(angle) * dist, 0.3, sin(angle) * dist)
		var s: float = randf_range(0.5, 1.0)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(s, randf_range(0.4, 1.0), s))
		fv_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(fv_mm)

# --- Lung Tissue: alveoli bubbles, bronchiole stubs ---
static func _lung(c: Node3D, hd, colors: Dictionary) -> void:
	var r: float = hd.radius
	var h: float = hd.height

	# Alveoli bubbles on walls (semi-transparent spheres)
	var alv_mesh: SphereMesh = SphereMesh.new()
	alv_mesh.radius = 0.4
	alv_mesh.height = 0.8
	alv_mesh.radial_segments = 8
	alv_mesh.rings = 4
	var alv_mat: StandardMaterial3D = _make_mat(
		Color(0.1, 0.07, 0.09, 0.4), colors.emission * 0.4, 0.35)
	alv_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	alv_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var alv_count: int = clampi(int(TAU * r * h * 0.01), 20, 80)
	var alv_mm: MultiMeshInstance3D = _create_mm(alv_mesh, alv_mat, alv_count)
	for i in range(alv_count):
		var angle: float = randf() * TAU
		var y: float = randf_range(0.5, h * 0.9)
		var wall_r: float = r * randf_range(0.88, 0.96)
		var pos: Vector3 = Vector3(cos(angle) * wall_r, y, sin(angle) * wall_r)
		var s: float = randf_range(0.5, 1.8)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(s, s * randf_range(0.7, 1.3), s))
		alv_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(alv_mm)

	# Bronchiole stubs from ceiling
	var bronch_mesh: CylinderMesh = CylinderMesh.new()
	bronch_mesh.top_radius = 0.15
	bronch_mesh.bottom_radius = 0.25
	bronch_mesh.height = 1.5
	bronch_mesh.radial_segments = 6
	var bronch_mat: StandardMaterial3D = _make_mat(
		colors.ceiling.lightened(0.2), colors.emission * 0.25, 0.2)
	var bronch_count: int = clampi(int(r * 0.15), 4, 15)
	var bronch_mm: MultiMeshInstance3D = _create_mm(bronch_mesh, bronch_mat, bronch_count)
	for i in range(bronch_count):
		var angle: float = randf() * TAU
		var dist: float = r * sqrt(randf()) * 0.6
		var bl: float = randf_range(1.5, minf(4.0, h * 0.35))
		var pos: Vector3 = Vector3(cos(angle) * dist, h - bl * 0.5, sin(angle) * dist)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(1.0, bl / 1.5, 1.0))
		bronch_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(bronch_mm)

# --- Bone Marrow: stalactites, stalagmites, trabecular struts ---
static func _bone_marrow(c: Node3D, hd, colors: Dictionary) -> void:
	var r: float = hd.radius
	var h: float = hd.height

	# Stalactites from ceiling (top wide, bottom pointed)
	var stal_mesh: CylinderMesh = CylinderMesh.new()
	stal_mesh.top_radius = 0.3
	stal_mesh.bottom_radius = 0.02
	stal_mesh.height = 1.0
	stal_mesh.radial_segments = 5
	var stal_mat: StandardMaterial3D = _make_mat(
		colors.ceiling.lightened(0.15), colors.emission * 0.2, 0.15)
	var stal_count: int = clampi(int(r * 0.3), 8, 30)
	var stal_mm: MultiMeshInstance3D = _create_mm(stal_mesh, stal_mat, stal_count)
	for i in range(stal_count):
		var angle: float = randf() * TAU
		var dist: float = r * sqrt(randf()) * 0.75
		var sl: float = randf_range(2.0, minf(6.0, h * 0.4))
		var pos: Vector3 = Vector3(cos(angle) * dist, h - sl * 0.5, sin(angle) * dist)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(randf_range(0.6, 1.4), sl, randf_range(0.6, 1.4)))
		stal_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(stal_mm)

	# Stalagmites from floor (bottom wide, top pointed)
	var stag_mesh: CylinderMesh = CylinderMesh.new()
	stag_mesh.top_radius = 0.02
	stag_mesh.bottom_radius = 0.25
	stag_mesh.height = 1.0
	stag_mesh.radial_segments = 5
	var stag_mat: StandardMaterial3D = _make_mat(
		colors.floor.lightened(0.1), colors.emission * 0.15, 0.1)
	var stag_count: int = clampi(int(r * 0.2), 5, 20)
	var stag_mm: MultiMeshInstance3D = _create_mm(stag_mesh, stag_mat, stag_count)
	for i in range(stag_count):
		var angle: float = randf() * TAU
		var dist: float = r * sqrt(randf()) * 0.7
		var sl: float = randf_range(1.0, minf(3.5, h * 0.3))
		var pos: Vector3 = Vector3(cos(angle) * dist, sl * 0.5, sin(angle) * dist)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(randf_range(0.6, 1.3), sl, randf_range(0.6, 1.3)))
		stag_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(stag_mm)

	# Trabecular struts (thin columns connecting floor to ceiling)
	var strut_mesh: CylinderMesh = CylinderMesh.new()
	strut_mesh.top_radius = 0.08
	strut_mesh.bottom_radius = 0.12
	strut_mesh.height = 1.0
	strut_mesh.radial_segments = 4
	var strut_mat: StandardMaterial3D = _make_mat(
		colors.wall.lightened(0.2), colors.emission * 0.1, 0.1)
	var strut_count: int = clampi(int(r * 0.08), 2, 8)
	var strut_mm: MultiMeshInstance3D = _create_mm(strut_mesh, strut_mat, strut_count)
	for i in range(strut_count):
		var angle: float = randf() * TAU
		var dist: float = r * randf_range(0.2, 0.65)
		var pos: Vector3 = Vector3(cos(angle) * dist, h * 0.5, sin(angle) * dist)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(randf_range(0.5, 1.0), h * 0.9, randf_range(0.5, 1.0)))
		strut_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(strut_mm)

# --- Liver: lobule bumps, bile duct lines, bile pools ---
static func _liver(c: Node3D, hd, colors: Dictionary) -> void:
	var r: float = hd.radius
	var h: float = hd.height

	# Lobule bumps on walls (flattened spheres in clusters)
	var lob_mesh: SphereMesh = SphereMesh.new()
	lob_mesh.radius = 0.6
	lob_mesh.height = 1.2
	lob_mesh.radial_segments = 6
	lob_mesh.rings = 3
	var lob_mat: StandardMaterial3D = _make_mat(
		colors.wall.lightened(0.12), colors.emission * 0.25, 0.2)
	var lob_count: int = clampi(int(TAU * r * h * 0.006), 15, 50)
	var lob_mm: MultiMeshInstance3D = _create_mm(lob_mesh, lob_mat, lob_count)
	for i in range(lob_count):
		var angle: float = randf() * TAU
		var y: float = randf_range(0.5, h * 0.8)
		var pos: Vector3 = Vector3(cos(angle) * r * 0.93, y, sin(angle) * r * 0.93)
		var basis: Basis = _wall_basis(angle)
		basis = basis.scaled(Vector3(randf_range(0.8, 1.5), randf_range(0.3, 0.6), randf_range(0.8, 1.5)))
		lob_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(lob_mm)

	# Bile duct tubes on floor (green-glowing thin cylinders laid flat)
	var bile_mesh: CylinderMesh = CylinderMesh.new()
	bile_mesh.top_radius = 0.06
	bile_mesh.bottom_radius = 0.06
	bile_mesh.height = 1.0
	bile_mesh.radial_segments = 4
	var bile_mat: StandardMaterial3D = _make_mat(
		Color(0.05, 0.08, 0.02), Color(0.2, 0.4, 0.05), 0.8)
	var bile_count: int = clampi(int(r * 0.2), 5, 18)
	var bile_mm: MultiMeshInstance3D = _create_mm(bile_mesh, bile_mat, bile_count)
	for i in range(bile_count):
		var angle: float = randf() * TAU
		var dist: float = r * randf_range(0.35, 0.7)  # Keep bile ducts away from center
		var rot_y: float = randf() * TAU
		var blen: float = randf_range(3.0, 8.0)
		var pos: Vector3 = Vector3(cos(angle) * dist, 0.08, sin(angle) * dist)
		# Lay cylinder flat: rotate 90deg around X, then random Y rotation
		var basis: Basis = Basis(Vector3.UP, rot_y) * Basis(Vector3.RIGHT, PI * 0.5)
		basis = basis.scaled(Vector3(1.0, blen, 1.0))
		bile_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(bile_mm)

	# Bile pools
	_add_floor_pools(c, hd, Color(0.1, 0.15, 0.02, 0.4), Color(0.15, 0.3, 0.05),
		clampi(int(r * 0.08), 1, 4), 2.0)

# --- Brain: nerve tendrils, synaptic bulbs, cortex ridges ---
static func _brain(c: Node3D, hd, colors: Dictionary) -> void:
	var r: float = hd.radius
	var h: float = hd.height

	# Nerve tendrils hanging from ceiling (thin wispy cylinders)
	var tend_mesh: CylinderMesh = CylinderMesh.new()
	tend_mesh.top_radius = 0.04
	tend_mesh.bottom_radius = 0.02
	tend_mesh.height = 1.0
	tend_mesh.radial_segments = 4
	var tend_mat: StandardMaterial3D = _make_mat(
		Color(0.06, 0.04, 0.08), Color(0.12, 0.08, 0.2), 0.5)
	var tend_count: int = clampi(int(PI * r * r * 0.005), 10, 40)
	var tend_mm: MultiMeshInstance3D = _create_mm(tend_mesh, tend_mat, tend_count)
	for i in range(tend_count):
		var angle: float = randf() * TAU
		var dist: float = r * sqrt(randf()) * 0.75
		var tlen: float = randf_range(2.0, minf(6.0, h * 0.5))
		var pos: Vector3 = Vector3(cos(angle) * dist, h - tlen * 0.5 - 0.3, sin(angle) * dist)
		# Slight organic sway
		var sway_x: float = randf_range(-0.15, 0.15)
		var sway_z: float = randf_range(-0.1, 0.1)
		var basis: Basis = Basis(Vector3.RIGHT, sway_x) * Basis(Vector3.FORWARD, sway_z)
		basis = basis.scaled(Vector3(randf_range(0.6, 1.0), tlen, randf_range(0.6, 1.0)))
		tend_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(tend_mm)

	# Synaptic bulbs (tiny glowing spheres scattered through volume)
	var bulb_mesh: SphereMesh = SphereMesh.new()
	bulb_mesh.radius = 0.1
	bulb_mesh.height = 0.2
	bulb_mesh.radial_segments = 6
	bulb_mesh.rings = 3
	var bulb_mat: StandardMaterial3D = _make_mat(
		Color(0.1, 0.06, 0.15), Color(0.3, 0.15, 0.5), 1.5)
	var bulb_count: int = clampi(int(PI * r * r * 0.008), 15, 60)
	var bulb_mm: MultiMeshInstance3D = _create_mm(bulb_mesh, bulb_mat, bulb_count)
	for i in range(bulb_count):
		var angle: float = randf() * TAU
		var dist: float = r * sqrt(randf()) * 0.8
		var y: float = randf_range(0.5, h * 0.9)
		var pos: Vector3 = Vector3(cos(angle) * dist, y, sin(angle) * dist)
		var s: float = randf_range(0.5, 2.0)
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(s, s, s))
		bulb_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(bulb_mm)

	# Cortex ridges on walls (elongated wavy bumps)
	var ridge_mesh: SphereMesh = SphereMesh.new()
	ridge_mesh.radius = 0.8
	ridge_mesh.height = 1.6
	ridge_mesh.radial_segments = 6
	ridge_mesh.rings = 3
	var ridge_mat: StandardMaterial3D = _make_mat(
		colors.wall.lightened(0.08), colors.emission * 0.2, 0.15)
	var ridge_count: int = clampi(int(TAU * r * 0.2), 10, 35)
	var ridge_mm: MultiMeshInstance3D = _create_mm(ridge_mesh, ridge_mat, ridge_count)
	for i in range(ridge_count):
		var angle: float = randf() * TAU
		var y: float = randf_range(0.5, h * 0.85)
		var pos: Vector3 = Vector3(cos(angle) * r * 0.94, y, sin(angle) * r * 0.94)
		var basis: Basis = _wall_basis(angle)
		basis = basis.scaled(Vector3(randf_range(1.5, 3.5), randf_range(0.15, 0.3), randf_range(0.6, 1.2)))
		ridge_mm.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	c.add_child(ridge_mm)

# ============================================================
# Utility functions
# ============================================================

static func _create_mm(mesh: Mesh, mat: Material, count: int) -> MultiMeshInstance3D:
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	mm.mesh = mesh
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi

static func _make_mat(albedo: Color, emission: Color, emission_energy: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission_energy > 0.01:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat

static func _wall_basis(angle: float) -> Basis:
	## Basis oriented to face inward from wall at given angle.
	## X = tangent along wall, Y = up, Z = inward toward center.
	var inward: Vector3 = -Vector3(cos(angle), 0, sin(angle))
	var up: Vector3 = Vector3.UP
	var right: Vector3 = up.cross(inward).normalized()
	return Basis(right, up, inward)

static func _wall_protrusion_basis(angle: float) -> Basis:
	## Basis for a cylinder protruding inward from wall.
	## CylinderMesh Y-axis points inward from wall surface.
	var inward: Vector3 = -Vector3(cos(angle), 0, sin(angle))
	var up: Vector3 = Vector3.UP
	var right: Vector3 = up.cross(inward).normalized()
	return Basis(right, inward, up)

static func _add_floor_pools(c: Node3D, hd, pool_color: Color, emission: Color,
		count: int, base_radius: float) -> void:
	var pool_mesh: CylinderMesh = CylinderMesh.new()
	pool_mesh.top_radius = 1.0
	pool_mesh.bottom_radius = 1.0
	pool_mesh.height = 0.08
	pool_mesh.radial_segments = 12
	var pool_mat: StandardMaterial3D = StandardMaterial3D.new()
	pool_mat.albedo_color = pool_color
	pool_mat.roughness = 0.3
	pool_mat.metallic = 0.2
	pool_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pool_mat.emission_enabled = true
	pool_mat.emission = emission
	pool_mat.emission_energy_multiplier = 0.6
	if pool_color.a < 0.99:
		pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for i in range(count):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = pool_mesh
		mi.material_override = pool_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle: float = randf() * TAU
		var dist: float = hd.radius * randf_range(0.35, 0.6)  # Keep pools away from center
		var pr: float = base_radius * randf_range(0.6, 1.4)
		mi.position = Vector3(cos(angle) * dist, 0.05, sin(angle) * dist)
		mi.scale = Vector3(pr, 1.0, pr * randf_range(0.7, 1.3))
		mi.name = "Pool_%d" % i
		c.add_child(mi)

		# Pool glow light
		var pool_light: OmniLight3D = OmniLight3D.new()
		pool_light.light_color = emission
		pool_light.light_energy = 0.3
		pool_light.omni_range = pr * 2.0
		pool_light.omni_attenuation = 2.0
		pool_light.shadow_enabled = false
		pool_light.position = mi.position + Vector3(0, 0.3, 0)
		c.add_child(pool_light)

extends Node3D
class_name CaveMoisture
## Static factory: adds moist cave atmosphere (drip particles, mucus strands, puddles).

static func add_moisture_effects(hub: Node3D, biome: int) -> void:
	var hub_data = hub._hub_data
	if not hub_data:
		return
	_add_drip_particles(hub, hub_data)
	_add_mucus_strands(hub, hub_data, biome)
	_add_slow_puddles(hub, hub_data, biome)

static func _add_drip_particles(hub: Node3D, hub_data) -> void:
	## Ceiling drip particles — water drops falling from above
	var drip_count: int = clampi(int(hub_data.radius * 0.04), 2, 8)
	for i in range(drip_count):
		var particles: GPUParticles3D = GPUParticles3D.new()
		particles.name = "CeilingDrip_%d" % i
		particles.emitting = true
		particles.amount = 6
		particles.lifetime = 2.5
		particles.explosiveness = 0.0
		particles.randomness = 0.8

		var proc_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		proc_mat.emission_box_extents = Vector3(2.0, 0.2, 2.0)
		proc_mat.direction = Vector3(0, -1, 0)
		proc_mat.spread = 5.0
		proc_mat.initial_velocity_min = 0.5
		proc_mat.initial_velocity_max = 1.5
		proc_mat.gravity = Vector3(0, -3.0, 0)
		proc_mat.scale_min = 0.3
		proc_mat.scale_max = 0.8
		proc_mat.color = Color(0.5, 0.6, 0.7, 0.6)
		particles.process_material = proc_mat

		# Water drop draw mesh
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.03, 0.08)
		particles.draw_pass_1 = quad

		var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		draw_mat.albedo_color = Color(0.6, 0.7, 0.8, 0.5)
		draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw_mat.emission_enabled = true
		draw_mat.emission = Color(0.4, 0.5, 0.6)
		draw_mat.emission_energy_multiplier = 0.5
		draw_mat.vertex_color_use_as_albedo = true
		particles.material_override = draw_mat
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# Position near ceiling at random XZ
		var angle: float = randf() * TAU
		var r: float = hub_data.radius * randf_range(0.1, 0.6)
		particles.position = Vector3(cos(angle) * r, hub_data.height * 0.85, sin(angle) * r)
		hub.add_child(particles)

static func _add_mucus_strands(hub: Node3D, hub_data, biome: int) -> void:
	## Mucus strands: thin translucent cylinders stretched floor-to-ceiling
	var strand_count: int = clampi(int(hub_data.radius * 0.02), 1, 6)
	# More mucus in organic biomes
	if biome in [0, 2, 5]:  # STOMACH, INTESTINE, LIVER
		strand_count = clampi(strand_count * 2, 2, 10)

	for i in range(strand_count):
		var strand: MeshInstance3D = MeshInstance3D.new()
		strand.name = "MucusStrand_%d" % i
		var cyl: CylinderMesh = CylinderMesh.new()
		var strand_height: float = hub_data.height * randf_range(0.4, 0.85)
		cyl.top_radius = randf_range(0.02, 0.06)
		cyl.bottom_radius = randf_range(0.03, 0.08)
		cyl.height = strand_height
		cyl.radial_segments = 4
		strand.mesh = cyl

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.7, 0.5, 0.25)
		mat.roughness = 0.2
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.5, 0.3)
		mat.emission_energy_multiplier = 0.3
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		strand.material_override = mat

		var angle: float = randf() * TAU
		var r: float = hub_data.radius * randf_range(0.15, 0.65)
		strand.position = Vector3(cos(angle) * r, strand_height * 0.5 + 0.5, sin(angle) * r)
		# Slight lean for organic feel
		strand.rotation.x = randf_range(-0.1, 0.1)
		strand.rotation.z = randf_range(-0.1, 0.1)
		hub.add_child(strand)

static func _add_slow_puddles(hub: Node3D, hub_data, biome: int) -> void:
	## Place slow-effect puddles on the floor. Blue-tinted water pools.
	var puddle_count: int = clampi(int(hub_data.radius * 0.015), 1, 5)
	# More puddles in wet biomes
	if biome in [0, 2, 3]:  # STOMACH, INTESTINE, LUNG
		puddle_count += 2

	var pool_script = load("res://scripts/snake_stage/fluid_pool.gd")
	if not pool_script:
		return

	for i in range(puddle_count):
		var pool: Node3D = Node3D.new()
		pool.set_script(pool_script)

		var pool_radius: float = randf_range(2.5, 5.0)
		var pool_color: Color = Color(0.2, 0.35, 0.5, 0.35)
		pool.setup(pool_radius, pool_color, "slow", 0.0, 0.5)

		var angle: float = randf() * TAU
		var r: float = hub_data.radius * randf_range(0.15, 0.55)
		var floor_y: float = 0.0
		if hub.has_method("get_floor_y"):
			floor_y = hub.get_floor_y(
				hub_data.position.x + cos(angle) * r,
				hub_data.position.z + sin(angle) * r
			) - hub_data.position.y
		pool.position = Vector3(cos(angle) * r, floor_y + 0.05, sin(angle) * r)
		hub.add_child(pool)

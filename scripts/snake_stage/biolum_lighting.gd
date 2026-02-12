class_name BiolumLighting
extends RefCounted
## Adds bioluminescent light patches to cave hubs.
## Scattered OmniLight3D nodes on walls with biome-colored glow patches.

const LIGHTS_PER_AREA: float = 0.0004  # lights per sq unit of wall area

static func add_lights(parent: Node3D, hub_data, biome_colors: Dictionary) -> void:
	var r: float = hub_data.radius
	var h: float = hub_data.height
	var wall_area: float = TAU * r * h
	var count: int = clampi(int(wall_area * LIGHTS_PER_AREA), 2, 8)

	var container: Node3D = Node3D.new()
	container.name = "BiolumLights"

	var emission_col: Color = biome_colors.emission

	for i in range(count):
		var angle: float = randf() * TAU
		var y: float = randf_range(h * 0.2, h * 0.7)
		var pos: Vector3 = Vector3(cos(angle) * r * 0.92, y, sin(angle) * r * 0.92)

		# OmniLight for actual illumination
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "BiolumLight_%d" % i
		light.light_color = emission_col.lightened(randf_range(-0.1, 0.2))
		var base_e: float = randf_range(0.15, 0.35)
		light.light_energy = base_e
		light.set_meta("base_energy", base_e)
		light.omni_range = randf_range(5.0, 12.0)
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.position = pos
		container.add_child(light)

		# Visual glow patch (emissive sphere on wall surface)
		var glow_size: float = randf_range(0.3, 0.8)
		var glow_mesh: SphereMesh = SphereMesh.new()
		glow_mesh.radius = glow_size
		glow_mesh.height = glow_size * 2.0
		glow_mesh.radial_segments = 6
		glow_mesh.rings = 3
		var glow_mi: MeshInstance3D = MeshInstance3D.new()
		glow_mi.mesh = glow_mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = emission_col * 0.5
		mat.emission_enabled = true
		mat.emission = emission_col
		mat.emission_energy_multiplier = 2.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		glow_mi.material_override = mat
		glow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow_mi.position = pos
		# Flatten against wall surface
		glow_mi.scale = Vector3(1.0, randf_range(0.8, 1.5), 0.3)
		container.add_child(glow_mi)

	# Add a few ceiling glow patches (dimmer, ambient)
	var ceil_count: int = clampi(int(count * 0.5), 1, 3)
	for i in range(ceil_count):
		var angle: float = randf() * TAU
		var dist: float = r * sqrt(randf()) * 0.5
		var pos: Vector3 = Vector3(cos(angle) * dist, h * randf_range(0.85, 0.95), sin(angle) * dist)

		var light: OmniLight3D = OmniLight3D.new()
		light.name = "CeilGlow_%d" % i
		light.light_color = emission_col.lightened(0.3)
		var ceil_e: float = randf_range(0.08, 0.15)
		light.light_energy = ceil_e
		light.set_meta("base_energy", ceil_e)
		light.omni_range = randf_range(8.0, 15.0)
		light.omni_attenuation = 1.8
		light.shadow_enabled = false
		light.position = pos
		container.add_child(light)

	parent.add_child(container)

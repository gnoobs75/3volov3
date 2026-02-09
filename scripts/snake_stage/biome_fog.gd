class_name BiomeFog
extends RefCounted
## Adds per-hub FogVolume with biome-specific color and density.
## Creates localized volumetric fog that makes each organ feel distinct.

# Per-biome fog parameters: {density, height_mult}
const FOG_PARAMS: Dictionary = {
	0: {"density": 0.035, "height_mult": 0.75},   # STOMACH - acidic haze, thicker
	1: {"density": 0.045, "height_mult": 0.85},   # HEART - warm blood mist
	2: {"density": 0.03, "height_mult": 0.65},    # INTESTINE - moderate mucous haze
	3: {"density": 0.02, "height_mult": 0.5},     # LUNG - thin, airy (gas clouds add local density)
	4: {"density": 0.025, "height_mult": 0.55},   # BONE_MARROW - cold crystalline haze
	5: {"density": 0.04, "height_mult": 0.75},    # LIVER - dark bile fog
	6: {"density": 0.05, "height_mult": 0.95},    # BRAIN - thick, disorienting
}

static func add_fog(parent: Node3D, hub_data, biome_colors: Dictionary) -> void:
	var params: Dictionary = FOG_PARAMS.get(hub_data.biome, FOG_PARAMS[0])

	var fog: FogVolume = FogVolume.new()
	fog.name = "BiomeFog"
	fog.size = Vector3(
		hub_data.radius * 2.0,
		hub_data.height * params.height_mult,
		hub_data.radius * 2.0
	)
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	# Center fog slightly below midpoint (hugs floor more)
	fog.position = Vector3(0, hub_data.height * 0.4, 0)

	var fog_mat: FogMaterial = FogMaterial.new()
	fog_mat.density = params.density
	fog_mat.albedo = biome_colors.fog
	fog.material = fog_mat

	parent.add_child(fog)

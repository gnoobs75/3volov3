class_name BiomeFog
extends RefCounted
## Adds per-hub FogVolume with biome-specific color and density.
## Creates localized volumetric fog that makes each organ feel distinct.

# Per-biome fog parameters: {density, height_mult}
const FOG_PARAMS: Dictionary = {
	0: {"density": 0.03, "height_mult": 0.7},    # STOMACH - moderate acidic haze
	1: {"density": 0.04, "height_mult": 0.8},    # HEART - thick warm blood mist
	2: {"density": 0.025, "height_mult": 0.6},   # INTESTINE - moderate
	3: {"density": 0.015, "height_mult": 0.5},   # LUNG - thin, airy
	4: {"density": 0.02, "height_mult": 0.5},    # BONE_MARROW - light haze
	5: {"density": 0.035, "height_mult": 0.7},   # LIVER - moderate dark
	6: {"density": 0.04, "height_mult": 0.9},    # BRAIN - thick, mysterious
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

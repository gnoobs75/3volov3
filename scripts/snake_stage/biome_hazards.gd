class_name BiomeHazards
extends RefCounted
## Creates environmental hazard zones per biome.
## Hazard nodes are plain Node3D with group "biome_hazard" + metadata.
## Player detects hazards via distance check in _physics_process.

const STOMACH = 0
const HEART_CHAMBER = 1
const INTESTINAL_TRACT = 2
const LUNG_TISSUE = 3
const BONE_MARROW = 4
const LIVER = 5
const BRAIN = 6

static func add_hazards(parent: Node3D, hub_data, biome_colors: Dictionary) -> void:
	var container: Node3D = Node3D.new()
	container.name = "Hazards"

	match hub_data.biome:
		STOMACH: _acid_zones(container, hub_data, biome_colors)
		HEART_CHAMBER: _pulse_zones(container, hub_data, biome_colors)
		LUNG_TISSUE: _lung_gas_clouds(container, hub_data, biome_colors)
		INTESTINAL_TRACT: _peristalsis_zones(container, hub_data, biome_colors)
		LIVER: _bile_zones(container, hub_data, biome_colors)
		BRAIN: _nerve_zones(container, hub_data, biome_colors)

	parent.add_child(container)

	# Add all hazard children to group after they're in tree
	for child in container.get_children():
		child.add_to_group("biome_hazard")

# --- Stomach: acid damage zones (interactive fluid pools) ---
static func _acid_zones(container: Node3D, hd, colors: Dictionary) -> void:
	var FluidPool = load("res://scripts/snake_stage/fluid_pool.gd")
	var count: int = clampi(int(hd.radius * 0.08), 1, 4)
	for i in range(count):
		var pool: Node3D = Node3D.new()
		pool.set_script(FluidPool)
		pool.name = "AcidPool_%d" % i
		var pool_radius: float = randf_range(2.5, 5.0)
		pool.setup(
			pool_radius,
			Color(0.25, 0.55, 0.08, 0.55),
			"acid",
			5.0,  # dps
			1.0   # no slow
		)
		var angle: float = randf() * TAU
		var dist: float = hd.radius * randf_range(0.35, 0.55)
		pool.position = Vector3(cos(angle) * dist, 0.2, sin(angle) * dist)
		container.add_child(pool)

# --- Heart: periodic knockback pulse zones ---
static func _pulse_zones(container: Node3D, hd, colors: Dictionary) -> void:
	# Heart has a single central pulse source
	var zone: Node3D = Node3D.new()
	zone.name = "PulseHazard"
	zone.position = Vector3(0, hd.height * 0.3, 0)
	zone.set_meta("hazard_type", "pulse")
	zone.set_meta("radius", hd.radius * 0.7)  # Affects most of the hub
	zone.set_meta("force", 6.0)
	zone.set_meta("period", 1.4)  # ~43 BPM, slow powerful beats
	container.add_child(zone)

# --- Liver: bile slow zones (interactive fluid pools) ---
static func _bile_zones(container: Node3D, hd, colors: Dictionary) -> void:
	var FluidPool = load("res://scripts/snake_stage/fluid_pool.gd")
	var count: int = clampi(int(hd.radius * 0.06), 1, 3)
	for i in range(count):
		var pool: Node3D = Node3D.new()
		pool.set_script(FluidPool)
		pool.name = "BilePool_%d" % i
		var pool_radius: float = randf_range(3.5, 6.0)
		pool.setup(
			pool_radius,
			Color(0.45, 0.25, 0.05, 0.5),
			"bile",
			0.0,  # no dps
			0.4   # 40% speed
		)
		var angle: float = randf() * TAU
		var dist: float = hd.radius * randf_range(0.35, 0.6)
		pool.position = Vector3(cos(angle) * dist, 0.2, sin(angle) * dist)
		container.add_child(pool)

# --- Brain: nerve zap zones ---
static func _nerve_zones(container: Node3D, hd, colors: Dictionary) -> void:
	var count: int = clampi(int(hd.radius * 0.1), 2, 5)
	for i in range(count):
		var zone: Node3D = Node3D.new()
		zone.name = "NerveHazard_%d" % i
		var angle: float = randf() * TAU
		var dist: float = hd.radius * randf_range(0.35, 0.7)
		var y: float = randf_range(0.5, hd.height * 0.6)
		zone.position = Vector3(cos(angle) * dist, y, sin(angle) * dist)
		zone.set_meta("hazard_type", "nerve")
		zone.set_meta("radius", randf_range(1.5, 3.0))
		zone.set_meta("zap_chance", 0.015)  # Per physics frame
		zone.set_meta("zap_damage", 8.0)

		# Visual: small spark light
		var spark: OmniLight3D = OmniLight3D.new()
		spark.light_color = Color(0.4, 0.2, 0.8)
		spark.light_energy = 0.2
		spark.omni_range = 2.0
		spark.shadow_enabled = false
		zone.add_child(spark)

		container.add_child(zone)

# --- Lung: drifting gas clouds (dense fog spheres that damage) ---
static func _lung_gas_clouds(container: Node3D, hd, colors: Dictionary) -> void:
	var count: int = clampi(int(hd.radius * 0.06), 2, 5)
	for i in range(count):
		var zone: Node3D = Node3D.new()
		zone.name = "GasCloud_%d" % i
		var angle: float = randf() * TAU
		var dist: float = hd.radius * randf_range(0.3, 0.65)
		var cloud_radius: float = randf_range(3.0, 6.0)
		var y: float = randf_range(1.0, hd.height * 0.5)
		zone.position = Vector3(cos(angle) * dist, y, sin(angle) * dist)
		zone.set_meta("hazard_type", "gas")
		zone.set_meta("radius", cloud_radius)
		zone.set_meta("dps", 2.0)

		# Visual: dense local FogVolume sphere
		var fog: FogVolume = FogVolume.new()
		fog.size = Vector3(cloud_radius * 2.0, cloud_radius * 1.5, cloud_radius * 2.0)
		fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		var fog_mat: FogMaterial = FogMaterial.new()
		fog_mat.density = 0.12
		fog_mat.albedo = Color(0.45, 0.35, 0.42, 0.8)
		fog.material = fog_mat
		zone.add_child(fog)

		# Subtle glow light inside cloud
		var cloud_light: OmniLight3D = OmniLight3D.new()
		cloud_light.light_color = Color(0.5, 0.4, 0.45)
		cloud_light.light_energy = 0.2
		cloud_light.omni_range = cloud_radius * 1.2
		cloud_light.shadow_enabled = false
		zone.add_child(cloud_light)

		container.add_child(zone)

# --- Intestine: peristalsis push zones (periodic horizontal wave) ---
static func _peristalsis_zones(container: Node3D, hd, colors: Dictionary) -> void:
	# 2-3 push zones along the intestinal tract hub
	var count: int = clampi(int(hd.radius * 0.04), 1, 3)
	for i in range(count):
		var zone: Node3D = Node3D.new()
		zone.name = "PeristalsisZone_%d" % i
		var angle: float = randf() * TAU
		var dist: float = hd.radius * randf_range(0.25, 0.5)
		zone.position = Vector3(cos(angle) * dist, 1.0, sin(angle) * dist)
		zone.set_meta("hazard_type", "peristalsis")
		zone.set_meta("radius", hd.radius * 0.4)
		zone.set_meta("force", 4.0)
		zone.set_meta("period", 2.5)  # Slow gut squeeze
		# Push direction: toward hub center then outward (radial wave)
		zone.set_meta("push_angle", angle + PI)  # Push away from zone origin
		container.add_child(zone)

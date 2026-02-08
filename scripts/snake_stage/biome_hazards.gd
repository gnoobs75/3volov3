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
		LIVER: _bile_zones(container, hub_data, biome_colors)
		BRAIN: _nerve_zones(container, hub_data, biome_colors)

	parent.add_child(container)

	# Add all hazard children to group after they're in tree
	for child in container.get_children():
		child.add_to_group("biome_hazard")

# --- Stomach: acid damage zones ---
static func _acid_zones(container: Node3D, hd, colors: Dictionary) -> void:
	var count: int = clampi(int(hd.radius * 0.08), 1, 4)
	for i in range(count):
		var zone: Node3D = Node3D.new()
		zone.name = "AcidHazard_%d" % i
		var angle: float = randf() * TAU
		var dist: float = hd.radius * randf_range(0.35, 0.55)
		zone.position = Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
		zone.set_meta("hazard_type", "acid")
		zone.set_meta("radius", randf_range(2.0, 4.0))
		zone.set_meta("dps", 5.0)

		# Visual: rising green particles (simple bubbles via small spheres)
		var bubble_mesh: SphereMesh = SphereMesh.new()
		bubble_mesh.radius = 0.08
		bubble_mesh.height = 0.16
		bubble_mesh.radial_segments = 4
		bubble_mesh.rings = 2
		var bubble_mat: StandardMaterial3D = StandardMaterial3D.new()
		bubble_mat.albedo_color = Color(0.3, 0.6, 0.1, 0.3)
		bubble_mat.emission_enabled = true
		bubble_mat.emission = colors.emission
		bubble_mat.emission_energy_multiplier = 1.0
		bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bubble_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Scatter a few visual bubbles
		for b in range(5):
			var bub: MeshInstance3D = MeshInstance3D.new()
			bub.mesh = bubble_mesh
			bub.material_override = bubble_mat
			bub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bub.position = Vector3(randf_range(-1.5, 1.5), randf_range(0.2, 1.5), randf_range(-1.5, 1.5))
			zone.add_child(bub)

		container.add_child(zone)

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

# --- Liver: bile slow zones ---
static func _bile_zones(container: Node3D, hd, colors: Dictionary) -> void:
	var count: int = clampi(int(hd.radius * 0.06), 1, 3)
	for i in range(count):
		var zone: Node3D = Node3D.new()
		zone.name = "BileHazard_%d" % i
		var angle: float = randf() * TAU
		var dist: float = hd.radius * randf_range(0.35, 0.6)
		zone.position = Vector3(cos(angle) * dist, 0.3, sin(angle) * dist)
		zone.set_meta("hazard_type", "bile")
		zone.set_meta("radius", randf_range(3.0, 5.0))
		zone.set_meta("slow_factor", 0.4)  # 40% speed while in bile
		container.add_child(zone)

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

class_name BiomeParticles
extends RefCounted
## Creates per-hub ambient particle effects using GPUParticles3D.
## Floating cells, spores, bubbles, etc. per biome.

const STOMACH = 0
const HEART_CHAMBER = 1
const INTESTINAL_TRACT = 2
const LUNG_TISSUE = 3
const BONE_MARROW = 4
const LIVER = 5
const BRAIN = 6

# Per-biome particle configs: {color, count, speed, size, lifetime}
const PARTICLE_CONFIGS: Dictionary = {
	STOMACH: {
		"color": Color(0.3, 0.5, 0.1, 0.45),
		"count": 50,
		"speed": 0.6,
		"size": 0.07,
		"lifetime": 6.0,
	},
	HEART_CHAMBER: {
		"color": Color(0.7, 0.08, 0.05, 0.55),
		"count": 60,
		"speed": 1.5,
		"size": 0.05,
		"lifetime": 3.5,
	},
	INTESTINAL_TRACT: {
		"color": Color(0.4, 0.25, 0.18, 0.4),
		"count": 40,
		"speed": 0.4,
		"size": 0.06,
		"lifetime": 8.0,
	},
	LUNG_TISSUE: {
		"color": Color(0.5, 0.4, 0.45, 0.3),
		"count": 80,
		"speed": 1.0,
		"size": 0.04,
		"lifetime": 4.5,
	},
	BONE_MARROW: {
		"color": Color(0.5, 0.45, 0.3, 0.35),
		"count": 30,
		"speed": 0.25,
		"size": 0.05,
		"lifetime": 10.0,
	},
	LIVER: {
		"color": Color(0.5, 0.12, 0.06, 0.45),
		"count": 40,
		"speed": 0.5,
		"size": 0.06,
		"lifetime": 7.0,
	},
	BRAIN: {
		"color": Color(0.2, 0.12, 0.35, 0.35),
		"count": 55,
		"speed": 0.8,
		"size": 0.035,
		"lifetime": 4.5,
	},
}

static func add_particles(parent: Node3D, hub_data, biome_colors: Dictionary) -> void:
	var config: Dictionary = PARTICLE_CONFIGS.get(hub_data.biome, PARTICLE_CONFIGS[STOMACH])
	var r: float = hub_data.radius
	var h: float = hub_data.height

	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "BiomeParticles"
	particles.amount = config.count
	particles.lifetime = config.lifetime
	particles.visibility_aabb = AABB(
		Vector3(-r, 0, -r),
		Vector3(r * 2.0, h, r * 2.0)
	)
	particles.position = Vector3(0, h * 0.5, 0)

	# Process material for particle behavior
	var proc_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc_mat.emission_sphere_radius = r * 0.7
	proc_mat.direction = Vector3(0, 1, 0)
	proc_mat.spread = 180.0
	proc_mat.initial_velocity_min = config.speed * 0.5
	proc_mat.initial_velocity_max = config.speed
	proc_mat.gravity = Vector3(0, config.speed * -0.1, 0)  # Near-zero gravity, slight drift
	proc_mat.scale_min = 0.5
	proc_mat.scale_max = 1.5
	proc_mat.color = config.color

	# Fade in/out
	var alpha_curve: CurveTexture = CurveTexture.new()
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(0.85, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	proc_mat.alpha_curve = alpha_curve

	particles.process_material = proc_mat

	# Draw pass: small quad billboard
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(config.size, config.size)
	particles.draw_pass_1 = quad

	# Material: additive glow billboard
	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.albedo_color = config.color
	draw_mat.emission_enabled = true
	draw_mat.emission = biome_colors.emission
	draw_mat.emission_energy_multiplier = 1.5
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = draw_mat

	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	parent.add_child(particles)

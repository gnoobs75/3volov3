extends Area3D
## Glowing trait orb dropped when a biome boss is defeated.
## Floats, pulses, and grants the boss's trait ability on contact.

var trait_id: String = ""
var _time: float = 0.0
var _base_y: float = 0.0
var _mesh: MeshInstance3D = null
var _light: OmniLight3D = null

const TRAIT_COLORS: Dictionary = {
	"pulse_wave": Color(0.9, 0.2, 0.3),     # Red — heart
	"acid_spit": Color(0.4, 0.9, 0.1),      # Green — gut
	"wind_gust": Color(0.5, 0.7, 0.9),      # Light blue — lung
	"bone_shield": Color(0.9, 0.85, 0.6),   # Bone white — marrow
	"summon_minions": Color(0.7, 0.3, 0.9),  # Purple — brain
}

const TRAIT_NAMES: Dictionary = {
	"pulse_wave": "PULSE WAVE",
	"acid_spit": "ACID SPIT",
	"wind_gust": "WIND GUST",
	"bone_shield": "BONE SHIELD",
	"summon_minions": "SUMMON MINIONS",
}

func _ready() -> void:
	_base_y = position.y
	_build_visuals()
	# Collision for pickup
	var col: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 2.0
	col.shape = sphere
	add_child(col)
	body_entered.connect(_on_body_entered)

func _build_visuals() -> void:
	var col: Color = TRAIT_COLORS.get(trait_id, Color(1, 1, 1))
	# Glowing icosphere
	_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	sphere.radial_segments = 16
	sphere.rings = 8
	_mesh.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 5.0
	mat.roughness = 0.1
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	_mesh.material_override = mat
	add_child(_mesh)

	# Bright glow light
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 3.0
	_light.omni_range = 10.0
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	_time += delta
	# Float and pulse
	position.y = _base_y + sin(_time * 2.0) * 0.5
	if _mesh:
		var scale_pulse: float = 1.0 + sin(_time * 3.0) * 0.15
		_mesh.scale = Vector3.ONE * scale_pulse
		_mesh.rotation.y += delta * 2.0
	if _light:
		_light.light_energy = 3.0 + sin(_time * 4.0) * 1.0

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_worm"):
		GameManager.unlock_trait(trait_id)
		# Gene fragment bonus for boss kill
		GameManager.add_gene_fragments(10)
		if AudioManager.has_method("play_evolution_fanfare"):
			AudioManager.play_evolution_fanfare()
		queue_free()

extends Area3D
## Collectible nutrient orb in the land stage.
## Bobs gently, rotates, and glows. Collected on contact with player worm.
## Feeds into GameManager inventory for the DNA helix HUD.

var _time: float = 0.0
var _bob_offset: float = 0.0
var _base_y: float = 0.0
var _initialized: bool = false

# Biomolecule category (set by snake_stage_manager before add_child)
var category_index: int = 0

# Golden nutrient: 3x value, flees from player
var is_golden: bool = false
var _flee_speed: float = 4.0
var _energy_value: float = 10.0
var _heal_value: float = 3.0
const GOLDEN_FLEE_RANGE: float = 30.0

const CATEGORY_KEYS: Array = [
	"nucleotide", "monosaccharide", "amino_acid", "coenzyme",
	"lipid", "nucleotide_base", "organic_acid"
]
const CATEGORY_NAMES: Array = [
	"Nucleotide", "Monosaccharide", "Amino Acid", "Coenzyme",
	"Lipid", "Nucleotide Base", "Organic Acid"
]

func _ready() -> void:
	add_to_group("nutrient")
	_bob_offset = randf() * TAU
	body_entered.connect(_on_body_entered)
	# Golden variant setup
	if is_golden:
		_energy_value = 30.0
		_heal_value = 10.0

func _process(delta: float) -> void:
	_time += delta
	if not _initialized:
		_base_y = position.y
		_initialized = true
	# Gentle bob
	position.y = _base_y + sin(_time * 2.5 + _bob_offset) * 0.3
	# Rotate mesh (golden spins faster)
	var mesh: MeshInstance3D = get_child(0) as MeshInstance3D
	if mesh:
		mesh.rotation.y += delta * (3.0 if is_golden else 1.5)
	# Golden nutrient: flee from nearby player
	if is_golden:
		_golden_flee(delta)

func _golden_flee(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player_worm")
	if players.is_empty():
		return
	var player: Node3D = players[0]
	var dist: float = position.distance_to(player.global_position)
	if dist < GOLDEN_FLEE_RANGE and dist > 0.5:
		var flee_dir: Vector3 = (position - player.global_position).normalized()
		flee_dir.y = 0  # Stay on floor
		position += flee_dir * _flee_speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_worm"):
		if body.has_method("restore_energy"):
			body.restore_energy(_energy_value)
		if body.has_method("heal"):
			body.heal(_heal_value)
		# Track growth progress
		if body.has_method("collect_nutrient_growth"):
			body.collect_nutrient_growth()
		# Feed into GameManager inventory for DNA helix HUD
		var idx: int = category_index % CATEGORY_KEYS.size()
		var item: Dictionary = {
			"id": CATEGORY_NAMES[idx] + "_" + str(randi()),
			"category": CATEGORY_KEYS[idx],
			"name": CATEGORY_NAMES[idx],
		}
		GameManager.collect_biomolecule(item)
		AudioManager.play_land_collect()
		if is_golden:
			_spawn_celebration_particles()
		queue_free()

func _spawn_celebration_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true
	particles.position = global_position

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -4.0, 0)
	mat.scale_min = 0.08
	mat.scale_max = 0.15
	mat.color = Color(1.0, 0.85, 0.2, 1.0)
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	color_ramp.set_color(1, Color(1.0, 0.6, 0.1, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	mat.color_ramp = color_tex
	particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)
	# Auto-free after particles finish
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

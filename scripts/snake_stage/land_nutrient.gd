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

const CATEGORY_KEYS: Array = [
	"nucleotide", "monosaccharide", "amino_acid", "coenzyme",
	"lipid", "nucleotide_base", "organic_acid"
]
const CATEGORY_NAMES: Array = [
	"Nucleotide", "Monosaccharide", "Amino Acid", "Coenzyme",
	"Lipid", "Nucleotide Base", "Organic Acid"
]

func _ready() -> void:
	_bob_offset = randf() * TAU
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	if not _initialized:
		_base_y = position.y
		_initialized = true
	# Gentle bob
	position.y = _base_y + sin(_time * 2.5 + _bob_offset) * 0.3
	# Rotate mesh
	var mesh: MeshInstance3D = get_child(0) as MeshInstance3D
	if mesh:
		mesh.rotation.y += delta * 1.5

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_worm"):
		if body.has_method("restore_energy"):
			body.restore_energy(10.0)
		if body.has_method("heal"):
			body.heal(3.0)
		# Feed into GameManager inventory for DNA helix HUD
		var idx: int = category_index % CATEGORY_KEYS.size()
		var item: Dictionary = {
			"id": CATEGORY_NAMES[idx] + "_" + str(randi()),
			"category": CATEGORY_KEYS[idx],
			"name": CATEGORY_NAMES[idx],
		}
		GameManager.collect_biomolecule(item)
		AudioManager.play_land_collect()
		queue_free()

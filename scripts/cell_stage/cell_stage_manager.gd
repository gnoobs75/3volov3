extends Node2D
## Manages the cell stage: HUD, player signals, world chunk delegation.
## Spawning is handled by WorldChunkManager.

@onready var player: CharacterBody2D = $PlayerCell
@onready var hud: CanvasLayer = $HUD
@onready var energy_bar: ProgressBar = $"HUD/ThreePaneLayout/MiddlePane/EnergyBar"
@onready var health_bar: ProgressBar = $"HUD/ThreePaneLayout/MiddlePane/HealthBar"
@onready var stats_label: Label = $"HUD/ThreePaneLayout/MiddlePane/StatsLabel"
@onready var parasite_label: Label = $"HUD/ThreePaneLayout/MiddlePane/ParasiteLabel"
@onready var helix_hud: Control = $"HUD/ThreePaneLayout/LeftPane/LeftVBox/HelixHUD"
@onready var crispr_layer: CanvasLayer = $CRISPREditor

const FOOD_SCENE := preload("res://scenes/food_particle.tscn")
const MUTATION_CHANCE: float = 0.05

var chunk_manager: Node2D = null
var _biome_label_timer: float = 0.0
var _current_biome_name: String = ""

func _ready() -> void:
	add_to_group("cell_stage_manager")
	player.reproduced.connect(_on_player_reproduced)
	player.organelle_collected.connect(_on_organelle_collected)
	player.died.connect(_on_player_died)
	player.parasites_changed.connect(_on_parasites_changed)

	# Create and setup chunk manager
	var ChunkManagerScript := preload("res://scripts/cell_stage/world_chunk_manager.gd")
	chunk_manager = Node2D.new()
	chunk_manager.set_script(ChunkManagerScript)
	chunk_manager.name = "WorldChunkManager"
	add_child(chunk_manager)
	chunk_manager.setup(player)

func _process(delta: float) -> void:
	# HUD bars
	energy_bar.value = player.energy
	energy_bar.max_value = player.max_energy
	health_bar.value = player.health
	health_bar.max_value = player.max_health

	var energy_status: String = ""
	if player.is_energy_depleted:
		energy_status = " [DEPLETED - 50% THRUST]"

	# Show biome name
	var biome_text: String = ""
	if chunk_manager:
		var biome: int = chunk_manager.get_biome_at(player.global_position)
		var biome_name: String = chunk_manager.get_biome_name(biome)
		if biome_name != _current_biome_name:
			_current_biome_name = biome_name
			_biome_label_timer = 3.0
		if _biome_label_timer > 0:
			_biome_label_timer -= delta
			biome_text = " | " + _current_biome_name

	stats_label.text = "Repros: %d/10 | Organelles: %d/5 | Collected: %d%s%s" % [
		GameManager.player_stats.reproductions,
		GameManager.player_stats.organelles_collected,
		GameManager.get_total_collected(),
		energy_status,
		biome_text,
	]

	# Toggle CRISPR editor
	if Input.is_action_just_pressed("toggle_crispr"):
		crispr_layer.visible = not crispr_layer.visible

func spawn_death_nutrients(pos: Vector2, count: int, base_color: Color) -> void:
	## Spawn food particles at the death location of an organism
	for i in range(count):
		var food := FOOD_SCENE.instantiate()
		food.setup(BiologyLoader.get_random_biomolecule(), false)
		food.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		food.add_to_group("food")
		add_child(food)
	# Notify chunk manager
	if chunk_manager:
		chunk_manager.notify_organism_died(pos)

func _on_player_reproduced() -> void:
	if randf() < MUTATION_CHANCE:
		print("CellStage: Mutation event! Random gene altered.")

func _on_organelle_collected() -> void:
	pass

func _on_parasites_changed(count: int) -> void:
	if count > 0:
		parasite_label.text = "PARASITES: %d/%d" % [count, 5]
		parasite_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.3, 0.9))
	else:
		parasite_label.text = ""

func _on_player_died() -> void:
	if player.attached_parasites.size() >= 5:
		stats_label.text = "PARASITIC TAKEOVER - Cell lost!"
	else:
		stats_label.text = "CELL DIED - Restarting..."
	await get_tree().create_timer(2.0).timeout
	GameManager.reset_stats()
	GameManager.go_to_cell_stage()

extends Node2D
## Manages the cell stage: HUD, player signals, world chunk delegation.
## Spawning is handled by WorldChunkManager.

@onready var player: CharacterBody2D = $PlayerCell
@onready var hud: CanvasLayer = $HUD
@onready var energy_bar: ProgressBar = $"HUD/ThreePaneLayout/MiddlePane/EnergyBar"
@onready var health_bar: ProgressBar = $"HUD/ThreePaneLayout/MiddlePane/HealthBar"
@onready var stats_label: Label = $"HUD/ThreePaneLayout/MiddlePane/StatsLabel"
@onready var parasite_label: Label = $"HUD/ThreePaneLayout/MiddlePane/ParasiteLabel"
@onready var fps_label: Label = $"HUD/ThreePaneLayout/MiddlePane/FPSLabel"
@onready var helix_hud: Control = $"HUD/ThreePaneLayout/LeftPane/LeftVBox/HelixHUD"
@onready var crispr_layer: CanvasLayer = $CRISPREditor
@onready var background: ColorRect = $Background

# FPS tracking and profiling
var _fps_update_timer: float = 0.0
var _target_fps: int = 120
var _show_profiler: bool = true  # Toggle with F3
var _entity_counts: Dictionary = {}
var _frame_times: Array[float] = []
var _avg_frame_time: float = 0.0

const FOOD_SCENE := preload("res://scenes/food_particle.tscn")
const MUTATION_CHANCE: float = 0.05

var chunk_manager: Node2D = null
var _biome_label_timer: float = 0.0
var _current_biome_name: String = ""

# Sensory upgrade notification
var _sensory_notify_text: String = ""
var _sensory_notify_timer: float = 0.0
var _sensory_notify_alpha: float = 0.0
var _last_sensory_level: int = 0

# Death recap
var _death_recap_active: bool = false
var _death_recap_timer: float = 0.0
var _death_recap_data: Dictionary = {}
var _session_time: float = 0.0
var _session_kills: int = 0
var _session_collections: int = 0

# Low health warning
var _low_health_pulse: float = 0.0
var _heartbeat_timer: float = 0.0
var _energy_warning_played: bool = false

var _overlay: Control = null  # For drawing screen-space effects

func _ready() -> void:
	add_to_group("cell_stage_manager")
	player.reproduced.connect(_on_player_reproduced)
	player.organelle_collected.connect(_on_organelle_collected)
	player.died.connect(_on_player_died)
	player.parasites_changed.connect(_on_parasites_changed)
	player.prey_killed.connect(_on_prey_killed)
	player.food_consumed.connect(_on_food_collected)

	# Connect evolution signals
	GameManager.evolution_applied.connect(_on_evolution_applied)
	_last_sensory_level = GameManager.sensory_level

	# Create overlay for screen-space effects (health pulse, sensory popup, death recap)
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 8
	overlay_layer.name = "OverlayLayer"
	add_child(overlay_layer)
	var OverlayScript := preload("res://scripts/cell_stage/screen_overlay.gd")
	_overlay = Control.new()
	_overlay.set_script(OverlayScript)
	_overlay.name = "ScreenOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw_callback = _draw_overlay
	overlay_layer.add_child(_overlay)

	# Create and setup chunk manager
	var ChunkManagerScript := preload("res://scripts/cell_stage/world_chunk_manager.gd")
	chunk_manager = Node2D.new()
	chunk_manager.set_script(ChunkManagerScript)
	chunk_manager.name = "WorldChunkManager"
	add_child(chunk_manager)
	chunk_manager.setup(player)

func _process(delta: float) -> void:
	# Toggle profiler with F3
	if Input.is_action_just_pressed("ui_page_down"):  # F3 or Page Down
		_show_profiler = not _show_profiler

	# Track frame times for averaging
	_frame_times.append(delta * 1000.0)  # Convert to ms
	if _frame_times.size() > 30:
		_frame_times.pop_front()
	_avg_frame_time = 0.0
	for ft in _frame_times:
		_avg_frame_time += ft
	_avg_frame_time /= _frame_times.size()

	# FPS display (update every 0.25 seconds for stability)
	_fps_update_timer -= delta
	if _fps_update_timer <= 0:
		_fps_update_timer = 0.25
		var current_fps: int = int(Engine.get_frames_per_second())
		var fps_color: Color
		if current_fps >= _target_fps:
			fps_color = Color(0.4, 0.95, 0.4, 0.9)
		elif current_fps >= _target_fps * 0.8:
			fps_color = Color(0.9, 0.9, 0.3, 0.9)
		else:
			fps_color = Color(0.95, 0.3, 0.3, 0.9)

		# Count entities for profiling
		_entity_counts = {
			"food": get_tree().get_nodes_in_group("food").size(),
			"enemies": get_tree().get_nodes_in_group("enemies").size(),
			"competitors": get_tree().get_nodes_in_group("competitors").size(),
			"prey": get_tree().get_nodes_in_group("prey").size(),
			"hazards": get_tree().get_nodes_in_group("hazards").size(),
			"parasites": get_tree().get_nodes_in_group("parasites").size(),
			"viruses": get_tree().get_nodes_in_group("viruses").size(),
		}
		var total_entities: int = 0
		for key in _entity_counts:
			total_entities += _entity_counts[key]

		# Build profiler text
		if _show_profiler:
			var profiler_text: String = "FPS: %d | %.1fms\n" % [current_fps, _avg_frame_time]
			profiler_text += "Entities: %d\n" % total_entities
			profiler_text += "Food:%d Enem:%d Comp:%d\n" % [_entity_counts["food"], _entity_counts["enemies"], _entity_counts["competitors"]]
			profiler_text += "Prey:%d Haz:%d Para:%d Vir:%d\n" % [_entity_counts["prey"], _entity_counts["hazards"], _entity_counts["parasites"], _entity_counts["viruses"]]
			profiler_text += "Draw: %d | Objects: %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]
			fps_label.text = profiler_text
		else:
			fps_label.text = "FPS: %d" % current_fps

		fps_label.add_theme_color_override("font_color", fps_color)

	# Session time
	if not _death_recap_active:
		_session_time += delta

	# Sensory notification fade
	if _sensory_notify_timer > 0:
		_sensory_notify_timer -= delta
		_sensory_notify_alpha = clampf(_sensory_notify_timer / 2.5, 0.0, 1.0)
		if _sensory_notify_timer < 0.5:
			_sensory_notify_alpha = _sensory_notify_timer / 0.5

	# Low health warning pulse
	if player.health > 0 and player.health / player.max_health < 0.3:
		_low_health_pulse += delta * 4.0
		_heartbeat_timer -= delta
		if _heartbeat_timer <= 0:
			_heartbeat_timer = 0.8
			AudioManager.play_heartbeat()
	else:
		_low_health_pulse = 0.0
		_heartbeat_timer = 0.0

	# Energy warning (one-shot when crossing 25% threshold)
	var energy_ratio: float = player.energy / player.max_energy
	if energy_ratio < 0.25 and not _energy_warning_played:
		_energy_warning_played = true
		AudioManager.play_energy_warning()
	elif energy_ratio > 0.35:
		_energy_warning_played = false

	# Request overlay redraw
	if _overlay:
		_overlay.queue_redraw()

	# Keep background centered on player for infinite world feel
	if background:
		background.global_position = player.global_position - Vector2(2000, 2000)

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

func _on_prey_killed() -> void:
	_session_kills += 1

func _on_food_collected() -> void:
	_session_collections += 1

func _on_evolution_applied(mutation: Dictionary) -> void:
	# Check if sensory level changed
	if GameManager.sensory_level > _last_sensory_level:
		var tier: Dictionary = GameManager.get_sensory_tier()
		_sensory_notify_text = tier.get("name", "Unknown") + " UNLOCKED"
		_sensory_notify_timer = 3.0
		_sensory_notify_alpha = 1.0
		AudioManager.play_sensory_upgrade()
		_last_sensory_level = GameManager.sensory_level

func _on_player_died() -> void:
	_death_recap_active = true
	_death_recap_timer = 3.5
	var cause: String = "Cell destroyed"
	if player.attached_parasites.size() >= 5:
		cause = "Parasitic takeover"
	_death_recap_data = {
		"cause": cause,
		"time": _session_time,
		"kills": _session_kills,
		"collections": _session_collections,
		"mutations": GameManager.active_mutations.size(),
	}
	# Wait for recap to display, then restart
	await get_tree().create_timer(3.5).timeout
	_death_recap_active = false
	_session_time = 0.0
	_session_kills = 0
	_session_collections = 0
	GameManager.reset_stats()
	GameManager.go_to_cell_stage()

func _draw_overlay(ctl: Control) -> void:
	var vp := ctl.get_viewport_rect().size
	var font := ThemeDB.fallback_font

	# --- Low health red pulse vignette ---
	if _low_health_pulse > 0:
		var pulse: float = 0.5 + 0.5 * sin(_low_health_pulse)
		var alpha: float = pulse * 0.25
		var grad_w: float = vp.x * 0.15
		var grad_h: float = vp.y * 0.15
		ctl.draw_rect(Rect2(0, 0, vp.x, grad_h), Color(0.8, 0.05, 0.05, alpha * 0.6))
		ctl.draw_rect(Rect2(0, vp.y - grad_h, vp.x, grad_h), Color(0.8, 0.05, 0.05, alpha * 0.6))
		ctl.draw_rect(Rect2(0, 0, grad_w, vp.y), Color(0.8, 0.05, 0.05, alpha * 0.4))
		ctl.draw_rect(Rect2(vp.x - grad_w, 0, grad_w, vp.y), Color(0.8, 0.05, 0.05, alpha * 0.4))

	# --- Sensory upgrade notification ---
	if _sensory_notify_timer > 0 and _sensory_notify_alpha > 0.01:
		var text_size := font.get_string_size(_sensory_notify_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
		var tx: float = (vp.x - text_size.x) * 0.5
		var ty: float = vp.y * 0.35
		var pill_w: float = text_size.x + 40.0
		var pill_h: float = 40.0
		ctl.draw_rect(Rect2(tx - 20, ty - 28, pill_w, pill_h), Color(0.05, 0.1, 0.2, 0.7 * _sensory_notify_alpha))
		ctl.draw_rect(Rect2(tx - 21, ty - 29, pill_w + 2, 1), Color(0.4, 0.7, 1.0, _sensory_notify_alpha * 0.5))
		ctl.draw_rect(Rect2(tx - 21, ty + 11, pill_w + 2, 1), Color(0.4, 0.7, 1.0, _sensory_notify_alpha * 0.5))
		ctl.draw_string(font, Vector2(tx, ty), _sensory_notify_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.5, 0.9, 1.0, _sensory_notify_alpha))

	# --- Death recap overlay ---
	if _death_recap_active and _death_recap_data.size() > 0:
		ctl.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.0, 0.0, 0.02, 0.6))
		var cy: float = vp.y * 0.35
		var title: String = _death_recap_data.get("cause", "Cell destroyed")
		var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
		ctl.draw_string(font, Vector2((vp.x - ts.x) * 0.5, cy), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.9, 0.2, 0.2, 0.95))
		cy += 50.0
		var time_s: float = _death_recap_data.get("time", 0.0)
		var time_str: String = "%d:%02d" % [int(time_s) / 60, int(time_s) % 60]
		var stats: Array = [
			"Time survived: " + time_str,
			"Kills: %d" % _death_recap_data.get("kills", 0),
			"Collections: %d" % _death_recap_data.get("collections", 0),
			"Mutations: %d" % _death_recap_data.get("mutations", 0),
		]
		for line in stats:
			var ls := font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			ctl.draw_string(font, Vector2((vp.x - ls.x) * 0.5, cy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.8, 0.9, 0.85))
			cy += 24.0

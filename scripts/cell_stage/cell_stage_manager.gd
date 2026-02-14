extends Node2D
## Manages the cell stage: HUD, player signals, world chunk delegation.
## Spawning is handled by WorldChunkManager.

@onready var player: CharacterBody2D = $PlayerCell
@onready var hud: CanvasLayer = $HUD
@onready var stats_label: Label = $"HUD/ThreePaneLayout/MiddlePane/StatsLabel"
@onready var parasite_label: Label = $"HUD/ThreePaneLayout/MiddlePane/ParasiteLabel"
@onready var fps_label: Label = $"HUD/ThreePaneLayout/MiddlePane/FPSLabel"
@onready var helix_hud: Control = $"HUD/ThreePaneLayout/LeftPane/LeftVBox/HelixHUD"
@onready var crispr_layer: CanvasLayer = $CRISPREditor
@onready var codex_layer: CanvasLayer = $OrganismCodex
@onready var background: ColorRect = $Background

# FPS tracking and profiling
var _fps_update_timer: float = 0.0
var _target_fps: int = 120
var _show_profiler: bool = true  # Toggle with F3
var _entity_counts: Dictionary = {}
var _frame_times: Array[float] = []
var _frame_time_index: int = 0
var _frame_time_sum: float = 0.0
var _avg_frame_time: float = 0.0
const FRAME_TIME_BUFFER_SIZE: int = 30

const FOOD_SCENE := preload("res://scenes/food_particle.tscn")
const OCULUS_SCENE := preload("res://scenes/oculus_titan.tscn")
const JUGGERNAUT_SCENE := preload("res://scenes/juggernaut.tscn")
const BASILISK_SCENE := preload("res://scenes/basilisk.tscn")
const MUTATION_CHANCE: float = 0.05

# Boss tracking
var _bosses_spawned: Dictionary = {}  # boss_name -> true
var _active_boss: Node2D = null

var chunk_manager: Node2D = null
var _biome_label_timer: float = 0.0
var _biome_label_alpha: float = 0.0
var _current_biome_name: String = ""
var _current_biome_color: Color = Color(0.5, 0.8, 0.9)
var _bg_shader_mat: ShaderMaterial = null
var _biome_tint_current: Color = Color(0, 0, 0, 0)
var _biome_tint_target: Color = Color(0, 0, 0, 0)
var _biome_strength_current: float = 0.0
var _biome_strength_target: float = 0.0

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

# Mutation popup
var _mutation_popup_timer: float = 0.0
var _mutation_popup_alpha: float = 0.0

# Generic popup (for cleaner feedback, etc.)
var _popup_text: String = ""
var _popup_timer: float = 0.0
var _popup_alpha: float = 0.0
var _popup_color: Color = Color(0.5, 0.9, 0.7)

# Low health warning
var _low_health_pulse: float = 0.0
var _heartbeat_timer: float = 0.0
var _energy_warning_played: bool = false

var _overlay: Control = null  # For drawing screen-space effects
var _pause_menu: Control = null
var _paused: bool = false
var _vitals_hud: Control = null  # Curved arc bars (health left, energy right)

# Victory screen
var _victory_active: bool = false
var _victory_timer: float = 0.0

var _competitor_scan_timer: float = 0.0
var _discovery_timer: float = 2.0  # Organism Codex scan timer (delay first scan)

# --- Population control ---
var _cleanup_timer: float = 3.0
const MAX_ENEMIES: int = 20
const MAX_PARASITES: int = 8
const MAX_FOOD: int = 80
const MAX_HAZARDS: int = 8
const MAX_VIRUSES: int = 6
const MAX_KIN: int = 12
const DESPAWN_DISTANCE: float = 1800.0  # Despawn orphans beyond this distance from player

# --- FEATURE: Dynamic World Events ---
var _world_event_timer: float = 0.0
var _world_event_active: bool = false
var _world_event_name: String = ""
var _world_event_duration: float = 0.0
var _world_event_remaining: float = 0.0
const WORLD_EVENT_INTERVAL_MIN: float = 120.0  # 2 min between events
const WORLD_EVENT_INTERVAL_MAX: float = 180.0  # 3 min max
const WORLD_EVENTS: Array = [
	{"name": "FEEDING FRENZY", "duration": 15.0, "color": Color(1.0, 0.5, 0.2), "desc": "Competitors converge on nearby food!"},
	{"name": "NUTRIENT BLOOM", "duration": 30.0, "color": Color(0.3, 1.0, 0.4), "desc": "Double food spawns!"},
	{"name": "PARASITE SWARM", "duration": 20.0, "color": Color(0.7, 0.2, 0.5), "desc": "Parasites surge from the deep!"},
	{"name": "THERMAL ERUPTION", "duration": 10.0, "color": Color(1.0, 0.4, 0.1), "desc": "Vent eruption! Damage pulse + bonus loot!"},
]
var _world_event_color: Color = Color.WHITE

# --- FEATURE: Chain Combo System ---
var _chain_category: String = ""
var _chain_count: int = 0
var _chain_timer: float = 0.0
var _chain_display_timer: float = 0.0
var _chain_display_alpha: float = 0.0
const CHAIN_TIMEOUT: float = 8.0  # Seconds before chain resets

# --- FEATURE: Kill Streak Announcements ---
var _kill_streak: int = 0
var _kill_streak_timer: float = 0.0  # Resets after 10 sec of no kills
var _streak_announce_text: String = ""
var _streak_announce_timer: float = 0.0
var _streak_announce_alpha: float = 0.0
var _streak_announce_color: Color = Color(1.0, 0.3, 0.3)
var _streak_announce_scale: float = 1.0
const KILL_STREAK_TIMEOUT: float = 10.0
const STREAK_ANNOUNCEMENTS: Dictionary = {
	1: {"text": "FIRST BLOOD!", "color": Color(0.9, 0.4, 0.3)},
	3: {"text": "TRIPLE KILL!", "color": Color(1.0, 0.5, 0.2)},
	5: {"text": "RAMPAGE!", "color": Color(1.0, 0.3, 0.1)},
	10: {"text": "UNSTOPPABLE!", "color": Color(1.0, 0.2, 0.6)},
	15: {"text": "APEX PREDATOR!", "color": Color(1.0, 0.1, 0.9)},
}

# --- FEATURE: Floating Text Popups ---
var _floating_texts: Array = []  # [{text, pos, life, color, size}]

func _ready() -> void:
	add_to_group("cell_stage_manager")
	player.organelle_collected.connect(_on_organelle_collected)
	player.died.connect(_on_player_died)
	player.parasites_changed.connect(_on_parasites_changed)
	player.prey_killed.connect(_on_prey_killed)
	player.food_consumed.connect(_on_food_collected)
	if player.has_signal("biomolecule_category_collected"):
		player.biomolecule_category_collected.connect(on_biomolecule_collected)

	# Start cell stage ambient soundscape
	AudioManager.start_cell_ambient()

	# Initialize world event timer
	_world_event_timer = randf_range(60.0, 90.0)  # First event after 1-1.5 min

	# Connect evolution signals
	GameManager.evolution_applied.connect(_on_evolution_applied)
	GameManager.cell_stage_won.connect(_on_cell_stage_won)
	GameManager.safe_zone_ended.connect(_on_safe_zone_ended)
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

	# Pause menu (on same overlay layer, hidden until ESC)
	var PauseScript := preload("res://scripts/cell_stage/pause_menu.gd")
	_pause_menu = Control.new()
	_pause_menu.set_script(PauseScript)
	_pause_menu.name = "PauseMenu"
	_pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_menu.visible = false
	_pause_menu.resumed.connect(_unpause)
	_pause_menu.quit_to_menu.connect(_quit_to_menu)
	overlay_layer.add_child(_pause_menu)

	# Creature showcase cinematic + tutorial (once per session)
	if not GameManager.get("tutorial_shown"):
		var ShowcaseScript := preload("res://scripts/cell_stage/creature_showcase.gd")
		var showcase := Node2D.new()
		showcase.set_script(ShowcaseScript)
		showcase.name = "CreatureShowcase"
		add_child(showcase)
		showcase.setup(player)
		showcase.showcase_finished.connect(_on_showcase_finished.bind(overlay_layer))
	else:
		# Returning player — no showcase or tutorial needed
		pass

	# Curved vitals arc bars (centered on screen, health left / energy right)
	var vitals_script := load("res://scripts/snake_stage/vitals_hud.gd")
	_vitals_hud = Control.new()
	_vitals_hud.set_script(vitals_script)
	_vitals_hud.name = "VitalsHUD"
	_vitals_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vitals_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_vitals_hud)

	# Grab background shader material for biome tinting
	if background and background.material is ShaderMaterial:
		_bg_shader_mat = background.material

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

	# Track frame times via circular buffer (no allocations)
	var frame_ms: float = delta * 1000.0
	if _frame_times.size() < FRAME_TIME_BUFFER_SIZE:
		_frame_times.append(frame_ms)
		_frame_time_sum += frame_ms
	else:
		_frame_time_sum -= _frame_times[_frame_time_index]
		_frame_times[_frame_time_index] = frame_ms
		_frame_time_sum += frame_ms
		_frame_time_index = (_frame_time_index + 1) % FRAME_TIME_BUFFER_SIZE
	_avg_frame_time = _frame_time_sum / _frame_times.size()

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

		# Build profiler text — only count entities when profiler is visible
		if _show_profiler:
			_entity_counts = {
				"food": get_tree().get_nodes_in_group("food").size(),
				"enemies": get_tree().get_nodes_in_group("enemies").size(),
				"competitors": get_tree().get_nodes_in_group("competitors").size(),
				"prey": get_tree().get_nodes_in_group("prey").size(),
				"hazards": get_tree().get_nodes_in_group("hazards").size(),
				"parasites": get_tree().get_nodes_in_group("parasites").size(),
				"viruses": get_tree().get_nodes_in_group("viruses").size(),
				"kin": get_tree().get_nodes_in_group("kin").size(),
			}
			var total_entities: int = 0
			for key in _entity_counts:
				total_entities += _entity_counts[key]
			var profiler_text: String = "FPS: %d | %.1fms\n" % [current_fps, _avg_frame_time]
			profiler_text += "Entities: %d\n" % total_entities
			profiler_text += "Food:%d Enem:%d Comp:%d Kin:%d\n" % [_entity_counts["food"], _entity_counts["enemies"], _entity_counts["competitors"], _entity_counts["kin"]]
			profiler_text += "Prey:%d Haz:%d Para:%d Vir:%d\n" % [_entity_counts["prey"], _entity_counts["hazards"], _entity_counts["parasites"], _entity_counts["viruses"]]
			profiler_text += "Draw: %d | Objects: %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]
			fps_label.text = profiler_text
		else:
			fps_label.text = "FPS: %d" % current_fps

		fps_label.add_theme_color_override("font_color", fps_color)

	# Session time
	if not _death_recap_active:
		_session_time += delta

	# Mutation popup fade
	if _mutation_popup_timer > 0:
		_mutation_popup_timer -= delta
		_mutation_popup_alpha = clampf(_mutation_popup_timer / 2.5, 0.0, 1.0)
		if _mutation_popup_timer < 0.5:
			_mutation_popup_alpha = _mutation_popup_timer / 0.5

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

	# Generic popup fade
	if _popup_timer > 0:
		_popup_timer -= delta
		_popup_alpha = clampf(_popup_timer / 2.0, 0.0, 1.0)
		if _popup_timer < 0.5:
			_popup_alpha = _popup_timer / 0.5

	# --- Dynamic World Events ---
	_world_event_timer -= delta
	if _world_event_timer <= 0 and not _world_event_active and not GameManager.safe_zone_active:
		_world_event_timer = randf_range(WORLD_EVENT_INTERVAL_MIN, WORLD_EVENT_INTERVAL_MAX)
		_trigger_world_event()
	if _world_event_active:
		_world_event_remaining -= delta
		if _world_event_remaining <= 0:
			_end_world_event()

	# --- Chain Combo ---
	if _chain_timer > 0:
		_chain_timer -= delta
		if _chain_timer <= 0:
			_chain_count = 0
			_chain_category = ""
	if _chain_display_timer > 0:
		_chain_display_timer -= delta
		_chain_display_alpha = clampf(_chain_display_timer / 1.5, 0.0, 1.0)
		if _chain_display_timer < 0.4:
			_chain_display_alpha = _chain_display_timer / 0.4

	# --- Kill Streak ---
	if _kill_streak > 0:
		_kill_streak_timer -= delta
		if _kill_streak_timer <= 0:
			_kill_streak = 0
	if _streak_announce_timer > 0:
		_streak_announce_timer -= delta
		_streak_announce_alpha = clampf(_streak_announce_timer / 2.0, 0.0, 1.0)
		if _streak_announce_timer < 0.5:
			_streak_announce_alpha = _streak_announce_timer / 0.5
		_streak_announce_scale = 1.0 + 0.3 * clampf((_streak_announce_timer - 1.5) / 0.5, 0.0, 1.0)

	# --- Floating Texts ---
	var ft_i: int = _floating_texts.size() - 1
	while ft_i >= 0:
		var ft: Dictionary = _floating_texts[ft_i]
		ft.life -= delta
		ft.pos.y -= 35.0 * delta  # Float upward
		ft.pos.x += ft.get("x_drift", 0.0) * delta  # Gentle horizontal drift
		ft.scale = lerpf(ft.get("scale", 1.0), 1.0, delta * 6.0)  # Bounce settle
		_floating_texts[ft_i] = ft
		if ft.life <= 0:
			_floating_texts.remove_at(ft_i)
		ft_i -= 1

	# Scan for new competitor cells to connect cleaner signal
	_competitor_scan_timer -= delta
	if _competitor_scan_timer <= 0:
		_competitor_scan_timer = 2.0
		for comp in get_tree().get_nodes_in_group("competitors"):
			if comp.has_signal("parasite_cleaned") and not comp.parasite_cleaned.is_connected(_on_parasite_cleaned):
				comp.parasite_cleaned.connect(_on_parasite_cleaned)

	# --- Population control: periodic cleanup sweep ---
	_cleanup_timer -= delta
	if _cleanup_timer <= 0:
		_cleanup_timer = 3.0
		_enforce_population_caps()

	# Victory timer
	if _victory_active:
		_victory_timer -= delta

	# Request overlay redraw only when an effect is active
	if _overlay and (_low_health_pulse > 0 or _sensory_notify_timer > 0 or _death_recap_active or _victory_active or _mutation_popup_timer > 0 or _popup_timer > 0 or _biome_label_timer > 0 or _chain_display_timer > 0 or _streak_announce_timer > 0 or _world_event_active or _floating_texts.size() > 0):
		_overlay.queue_redraw()

	# Keep background centered on player for infinite world feel
	if background:
		background.global_position = player.global_position - Vector2(2000, 2000)

	# HUD vitals arcs
	if _vitals_hud:
		_vitals_hud.health_ratio = player.health / player.max_health
		_vitals_hud.energy_ratio = player.energy / player.max_energy

	var energy_status: String = ""
	if player.is_energy_depleted:
		energy_status = " [DEPLETED - 50% THRUST]"

	# Biome name detection & fade
	if chunk_manager:
		var biome: int = chunk_manager.get_biome_at(player.global_position)
		var biome_name: String = chunk_manager.get_biome_name(biome)
		if biome_name != _current_biome_name:
			_current_biome_name = biome_name
			_biome_label_timer = 4.0
			_biome_label_alpha = 1.0
			match biome_name:
				"Open Waters":
					_current_biome_color = Color(0.4, 0.7, 0.9)
					_biome_tint_target = Color(0.1, 0.3, 0.6)
					_biome_strength_target = 0.15
				"Thermal Vent":
					_current_biome_color = Color(1.0, 0.5, 0.2)
					_biome_tint_target = Color(0.8, 0.3, 0.05)
					_biome_strength_target = 0.4
				"Deep Abyss":
					_current_biome_color = Color(0.3, 0.2, 0.6)
					_biome_tint_target = Color(0.15, 0.05, 0.4)
					_biome_strength_target = 0.5
				"Shallows":
					_current_biome_color = Color(0.4, 0.9, 0.7)
					_biome_tint_target = Color(0.2, 0.7, 0.4)
					_biome_strength_target = 0.3
				"Nutrient Garden":
					_current_biome_color = Color(0.5, 0.9, 0.3)
					_biome_tint_target = Color(0.4, 0.6, 0.1)
					_biome_strength_target = 0.35
				_:
					_current_biome_color = Color(0.5, 0.8, 0.9)
					_biome_tint_target = Color(0, 0, 0)
					_biome_strength_target = 0.0
	if _biome_label_timer > 0:
		_biome_label_timer -= delta
		if _biome_label_timer < 1.0:
			_biome_label_alpha = clampf(_biome_label_timer, 0.0, 1.0)

	# Smoothly interpolate biome shader tinting
	if _bg_shader_mat:
		_biome_tint_current = _biome_tint_current.lerp(_biome_tint_target, delta * 1.5)
		_biome_strength_current = lerpf(_biome_strength_current, _biome_strength_target, delta * 1.5)
		_bg_shader_mat.set_shader_parameter("biome_tint", _biome_tint_current)
		_bg_shader_mat.set_shader_parameter("biome_strength", _biome_strength_current)

	stats_label.text = "Organelles: %d/5 | Collected: %d%s" % [
		GameManager.player_stats.organelles_collected,
		GameManager.get_total_collected(),
		energy_status,
	]

	# Pause toggle (ESC)
	if Input.is_action_just_pressed("ui_cancel"):
		if _paused:
			_unpause()
		else:
			_pause()

	# Toggle CRISPR Mutation Workshop
	if Input.is_action_just_pressed("toggle_crispr") and not _paused:
		var crispr_panel := crispr_layer.get_node_or_null("CRISPRPanel")
		if crispr_panel:
			if crispr_layer.visible:
				crispr_panel.close()
				crispr_layer.visible = false
			else:
				# Close codex first if open
				var codex_panel := codex_layer.get_node_or_null("CodexPanel")
				if codex_panel and codex_panel.visible:
					codex_panel.toggle()
				crispr_layer.visible = true
				crispr_panel.open()

	# Toggle Organism Codex
	if Input.is_action_just_pressed("toggle_codex") and not _paused:
		# Close CRISPR first if open
		if crispr_layer.visible:
			var cp := crispr_layer.get_node_or_null("CRISPRPanel")
			if cp:
				cp.close()
			crispr_layer.visible = false
		var codex_panel := codex_layer.get_node_or_null("CodexPanel")
		if codex_panel:
			codex_panel.toggle()

	# Scan nearby organisms for codex discovery
	_discovery_timer -= delta
	if _discovery_timer <= 0:
		_discovery_timer = 1.5
		_scan_nearby_organisms()

func spawn_death_nutrients(pos: Vector2, count: int, base_color: Color) -> void:
	## Spawn food particles at the death location of an organism
	var current_food: int = get_tree().get_nodes_in_group("food").size()
	count = mini(count, maxi(0, MAX_FOOD - current_food))
	for i in range(count):
		var food := FOOD_SCENE.instantiate()
		food.setup(BiologyLoader.get_random_biomolecule(), false)
		food.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		food.add_to_group("food")
		add_child(food)
	# Notify chunk manager
	if chunk_manager:
		chunk_manager.notify_organism_died(pos)

func _spawn_boss_delayed(boss_name: String, delay: float) -> void:
	_bosses_spawned[boss_name] = true
	# Wait a few seconds after evolution before spawning
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or not player or not is_instance_valid(player):
		return
	# Spawn at a distance from the player
	var spawn_dir := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var spawn_pos: Vector2 = player.global_position + spawn_dir * 400.0
	var boss: Node2D = null
	match boss_name:
		"oculus_titan":
			boss = OCULUS_SCENE.instantiate()
		"juggernaut":
			boss = JUGGERNAUT_SCENE.instantiate()
		"basilisk":
			boss = BASILISK_SCENE.instantiate()
	if boss:
		boss.global_position = spawn_pos
		add_child(boss)
		_active_boss = boss
		# Announce the boss
		var boss_display: String = boss_name.replace("_", " ").to_upper()
		_popup_text = "BOSS: " + boss_display + " APPROACHES!"
		_popup_timer = 4.0
		_popup_alpha = 1.0
		_popup_color = Color(1.0, 0.3, 0.3)
		AudioManager.play_sensory_upgrade()
		var cam := player.get_node_or_null("Camera2D")
		if cam and cam.has_method("shake"):
			cam.shake(5.0, 0.5)

func _on_boss_defeated(boss_name: String) -> void:
	_active_boss = null
	var boss_display: String = boss_name.replace("_", " ").to_upper()
	_popup_text = boss_display + " DEFEATED!"
	_popup_timer = 4.0
	_popup_alpha = 1.0
	_popup_color = Color(0.3, 1.0, 0.5)
	AudioManager.play_evolution_fanfare()
	# Bonus gene fragments for boss kill
	GameManager.add_gene_fragments(randi_range(8, 15))
	var cam := player.get_node_or_null("Camera2D")
	if cam and cam.has_method("shake"):
		cam.shake(6.0, 0.6)

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
	# Gene fragment drop on kill (1-3 fragments)
	var fragments: int = randi_range(1, 3)
	GameManager.add_gene_fragments(fragments)
	# Kill streak tracking
	_kill_streak += 1
	_kill_streak_timer = KILL_STREAK_TIMEOUT
	if STREAK_ANNOUNCEMENTS.has(_kill_streak):
		var ann: Dictionary = STREAK_ANNOUNCEMENTS[_kill_streak]
		_streak_announce_text = ann.text
		_streak_announce_color = ann.color
		_streak_announce_timer = 2.5
		_streak_announce_alpha = 1.0
		AudioManager.play_sensory_upgrade()
		var cam := player.get_node_or_null("Camera2D")
		if cam and cam.has_method("shake"):
			cam.shake(5.0, 0.2)

func _on_food_collected() -> void:
	_session_collections += 1

func on_biomolecule_collected(category: String) -> void:
	## Chain combo: track consecutive same-category collections
	if category == _chain_category:
		_chain_count += 1
	else:
		_chain_category = category
		_chain_count = 1
	_chain_timer = CHAIN_TIMEOUT
	if _chain_count >= 2:
		_chain_display_timer = 2.0
		_chain_display_alpha = 1.0
		# Bonus energy for chains
		if _chain_count >= 3:
			player.energy = minf(player.energy + 5.0 * _chain_count, player.max_energy)
			_add_floating_text("+%d energy chain!" % (5 * _chain_count), player.global_position + Vector2(0, -40), Color(0.3, 1.0, 0.5), 14, _chain_count >= 5)

func _add_floating_text(text: String, world_pos: Vector2, color: Color, size: int = 14, critical: bool = false) -> void:
	_floating_texts.append({
		"text": text,
		"pos": world_pos + Vector2(randf_range(-12.0, 12.0), 0),  # Horizontal scatter
		"life": 2.5 if critical else 2.0,
		"max_life": 2.5 if critical else 2.0,
		"color": color,
		"size": size + (6 if critical else 0),
		"scale": 1.8 if critical else 1.4,  # Start large, bounces down
		"x_drift": randf_range(-8.0, 8.0),  # Gentle horizontal drift
		"critical": critical,
	})

func _on_evolution_applied(mutation: Dictionary) -> void:
	# Check if sensory level changed
	if GameManager.sensory_level > _last_sensory_level:
		var tier: Dictionary = GameManager.get_sensory_tier()
		_sensory_notify_text = tier.get("name", "Unknown") + " UNLOCKED"
		_sensory_notify_timer = 3.0
		_sensory_notify_alpha = 1.0
		AudioManager.play_sensory_upgrade()
		_last_sensory_level = GameManager.sensory_level

	# Boss spawns at evolution milestones
	var evo: int = GameManager.evolution_level
	if evo == 3 and not _bosses_spawned.has("oculus_titan"):
		_spawn_boss_delayed("oculus_titan", 5.0)
	elif evo == 6 and not _bosses_spawned.has("juggernaut"):
		_spawn_boss_delayed("juggernaut", 5.0)
	elif evo == 9 and not _bosses_spawned.has("basilisk"):
		_spawn_boss_delayed("basilisk", 5.0)

var _overlay_layer_ref: CanvasLayer = null

func _on_showcase_finished(overlay_layer: CanvasLayer) -> void:
	_overlay_layer_ref = overlay_layer
	# Open creature editor BEFORE revealing the player
	if not GameManager.initial_customization_done:
		var evo_ui := get_node_or_null("EvolutionUI")
		if is_instance_valid(evo_ui) and evo_ui.has_signal("initial_customization_completed"):
			evo_ui.initial_customization_completed.connect(_on_initial_customize_done, CONNECT_ONE_SHOT)
			evo_ui.open_initial_customization()
			return
	# Already customized — go straight to tutorial
	_reveal_player_and_start_tutorial(overlay_layer)

func _reveal_player_and_start_tutorial(overlay_layer: CanvasLayer) -> void:
	# Reveal the player (was hidden during showcase)
	if player and not player.visible:
		player.visible = true
		player.input_disabled = false
		if not player.is_in_group("player"):
			player.add_to_group("player")
		var col := player.get_node_or_null("CollisionShape2D")
		if col:
			col.disabled = false
		var cam := player.get_node_or_null("Camera2D")
		if cam:
			cam.set_process(true)
	# Refresh body shape from customization (shape is computed at _ready before editor opens)
	if player:
		player._compute_elongation()
		player._init_procedural_shape()
	_start_tutorial(overlay_layer)

func _on_initial_customize_done() -> void:
	if not is_inside_tree():
		return
	if _overlay_layer_ref and is_instance_valid(_overlay_layer_ref):
		_reveal_player_and_start_tutorial(_overlay_layer_ref)

func _start_tutorial(overlay_layer: CanvasLayer) -> void:
	hud.visible = true

	var TutorialScript := preload("res://scripts/cell_stage/tutorial_overlay.gd")
	var tut := Control.new()
	tut.set_script(TutorialScript)
	tut.name = "TutorialOverlay"
	tut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(tut)
	GameManager.tutorial_shown = true

func _on_safe_zone_ended() -> void:
	_popup_text = "Safe zone fading... organisms incoming!"
	_popup_timer = 3.5
	_popup_alpha = 1.0
	_popup_color = Color(1.0, 0.7, 0.3)
	AudioManager.play_sensory_upgrade()
	# Shake camera gently to signal the shift
	var cam := player.get_node_or_null("Camera2D")
	if cam and cam.has_method("shake"):
		cam.shake(3.0, 0.3)

func _on_parasite_cleaned() -> void:
	_popup_text = "Parasite removed!"
	_popup_timer = 2.5
	_popup_alpha = 1.0
	_popup_color = Color(0.4, 0.9, 0.5)
	AudioManager.play_ui_select()

func _on_cell_stage_won() -> void:
	if _victory_active:
		return
	_victory_active = true
	_victory_timer = 8.0
	AudioManager.play_evolution_fanfare()
	var cam := player.get_node_or_null("Camera2D")
	if cam and cam.has_method("shake"):
		cam.shake(4.0, 0.5)
	# Transition after displaying stats
	await get_tree().create_timer(8.0).timeout
	_victory_active = false
	AudioManager.stop_cell_ambient()
	GameManager.go_to_ocean_stub()

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

func _scan_nearby_organisms() -> void:
	## Discover organisms within scan range for the Organism Codex
	if not is_instance_valid(player):
		return
	var scan_range: float = 400.0
	var pp: Vector2 = player.global_position
	# Scan food
	for f in get_tree().get_nodes_in_group("food"):
		if is_instance_valid(f) and pp.distance_squared_to(f.global_position) < scan_range * scan_range:
			GameManager.discover_creature("food_particle")
			break
	# Scan prey
	for p in get_tree().get_nodes_in_group("prey"):
		if is_instance_valid(p) and pp.distance_squared_to(p.global_position) < scan_range * scan_range:
			GameManager.discover_creature("snake_prey")
			break
	# Scan enemies by script type
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or pp.distance_squared_to(e.global_position) > scan_range * scan_range:
			continue
		var script_path: String = e.get_script().resource_path if e.get_script() else ""
		if "enemy_cell" in script_path:
			GameManager.discover_creature("enemy_cell")
		elif "dart_predator" in script_path:
			GameManager.discover_creature("dart_predator")
		elif "siren_cell" in script_path:
			GameManager.discover_creature("siren_cell")
		elif "splitter_cell" in script_path:
			GameManager.discover_creature("splitter_cell")
		elif "electric_eel" in script_path:
			GameManager.discover_creature("electric_eel")
		elif "ink_bomber" in script_path:
			GameManager.discover_creature("ink_bomber")
		elif "leviathan" in script_path:
			GameManager.discover_creature("leviathan")
	# Scan parasites
	for p in get_tree().get_nodes_in_group("parasites"):
		if is_instance_valid(p) and pp.distance_squared_to(p.global_position) < scan_range * scan_range:
			GameManager.discover_creature("parasite_organism")
			break
	# Scan repellers
	for r in get_tree().get_nodes_in_group("repellers"):
		if is_instance_valid(r) and pp.distance_squared_to(r.global_position) < scan_range * scan_range:
			GameManager.discover_creature("repeller")
			break
	# Scan kin
	for k in get_tree().get_nodes_in_group("kin"):
		if is_instance_valid(k) and pp.distance_squared_to(k.global_position) < scan_range * scan_range:
			GameManager.discover_creature("kin_organism")
			break
	# Scan bosses
	for b in get_tree().get_nodes_in_group("bosses"):
		if not is_instance_valid(b) or pp.distance_squared_to(b.global_position) > scan_range * scan_range:
			continue
		var script_path: String = b.get_script().resource_path if b.get_script() else ""
		if "oculus_titan" in script_path:
			GameManager.discover_creature("oculus_titan")
		elif "juggernaut" in script_path:
			GameManager.discover_creature("juggernaut")
		elif "basilisk" in script_path:
			GameManager.discover_creature("basilisk")
	# Scan hazards (danger zones)
	for h in get_tree().get_nodes_in_group("hazards"):
		if is_instance_valid(h) and pp.distance_squared_to(h.global_position) < scan_range * scan_range:
			GameManager.discover_creature("danger_zone")
			break

func _draw_overlay(ctl: Control) -> void:
	var vp := ctl.get_viewport_rect().size
	var font := UIConstants.get_display_font()

	# --- Biome transition edge tint ---
	if _biome_label_timer > 2.5 and _biome_label_alpha > 0.5:
		var edge_a: float = (_biome_label_timer - 2.5) / 1.5 * 0.15
		var edge_w: float = vp.x * 0.05
		var edge_h: float = vp.y * 0.05
		var edge_col := Color(_current_biome_color.r, _current_biome_color.g, _current_biome_color.b, edge_a)
		ctl.draw_rect(Rect2(0, 0, vp.x, edge_h), edge_col)
		ctl.draw_rect(Rect2(0, vp.y - edge_h, vp.x, edge_h), edge_col)
		ctl.draw_rect(Rect2(0, 0, edge_w, vp.y), edge_col)
		ctl.draw_rect(Rect2(vp.x - edge_w, 0, edge_w, vp.y), edge_col)

	# --- Biome name banner ---
	if _biome_label_timer > 0 and _biome_label_alpha > 0.01:
		var biome_fs: int = 24
		var prefix_fs: int = 16
		var entering_text: String = "Entering:"
		var prefix_size := font.get_string_size(entering_text, HORIZONTAL_ALIGNMENT_CENTER, -1, prefix_fs)
		var biome_size := font.get_string_size(_current_biome_name, HORIZONTAL_ALIGNMENT_CENTER, -1, biome_fs)
		var total_w: float = maxf(prefix_size.x, biome_size.x)
		var bx: float = (vp.x - total_w) * 0.5
		var by: float = vp.y * 0.15
		# Subtle background pill
		var bpill_w: float = total_w + 50.0
		var bpill_h: float = 60.0
		ctl.draw_rect(Rect2(bx - 25, by - 28, bpill_w, bpill_h), Color(0.02, 0.04, 0.06, 0.5 * _biome_label_alpha))
		# Colored accent lines
		ctl.draw_rect(Rect2(bx - 25, by - 29, bpill_w, 1), Color(_current_biome_color.r, _current_biome_color.g, _current_biome_color.b, 0.5 * _biome_label_alpha))
		ctl.draw_rect(Rect2(bx - 25, by + 31, bpill_w, 1), Color(_current_biome_color.r, _current_biome_color.g, _current_biome_color.b, 0.5 * _biome_label_alpha))
		# "Entering:" prefix text
		var prefix_x: float = (vp.x - prefix_size.x) * 0.5
		ctl.draw_string(font, Vector2(prefix_x, by - 2), entering_text, HORIZONTAL_ALIGNMENT_LEFT, -1, prefix_fs, Color(0.6, 0.65, 0.7, 0.7 * _biome_label_alpha))
		# Biome name text
		var name_x: float = (vp.x - biome_size.x) * 0.5
		ctl.draw_string(font, Vector2(name_x, by + 22), _current_biome_name, HORIZONTAL_ALIGNMENT_LEFT, -1, biome_fs, Color(_current_biome_color.r, _current_biome_color.g, _current_biome_color.b, 0.9 * _biome_label_alpha))

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

	# --- Generic popup (cleaner feedback, etc.) ---
	if _popup_timer > 0 and _popup_alpha > 0.01:
		var pop_size := font.get_string_size(_popup_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		var px: float = (vp.x - pop_size.x) * 0.5
		var py: float = vp.y * 0.6
		var ppill_w: float = pop_size.x + 30.0
		var ppill_h: float = 32.0
		ctl.draw_rect(Rect2(px - 15, py - 22, ppill_w, ppill_h), Color(0.03, 0.08, 0.05, 0.7 * _popup_alpha))
		ctl.draw_string(font, Vector2(px, py), _popup_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(_popup_color.r, _popup_color.g, _popup_color.b, _popup_alpha))

	# --- Mutation popup ---
	if _mutation_popup_timer > 0 and _mutation_popup_alpha > 0.01:
		var mut_text := "MUTATION!"
		var mut_size := font.get_string_size(mut_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 26)
		var mx: float = (vp.x - mut_size.x) * 0.5
		var my: float = vp.y * 0.25
		var pill_w: float = mut_size.x + 40.0
		var pill_h: float = 44.0
		ctl.draw_rect(Rect2(mx - 20, my - 30, pill_w, pill_h), Color(0.15, 0.08, 0.02, 0.75 * _mutation_popup_alpha))
		ctl.draw_rect(Rect2(mx - 21, my - 31, pill_w + 2, 1), Color(1.0, 0.7, 0.2, _mutation_popup_alpha * 0.6))
		ctl.draw_rect(Rect2(mx - 21, my + 13, pill_w + 2, 1), Color(1.0, 0.7, 0.2, _mutation_popup_alpha * 0.6))
		ctl.draw_string(font, Vector2(mx, my), mut_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.8, 0.2, _mutation_popup_alpha))
		var sub_text := "Random gene alteration detected"
		var sub_size := font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		ctl.draw_string(font, Vector2((vp.x - sub_size.x) * 0.5, my + 22), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.65, 0.3, _mutation_popup_alpha * 0.7))

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

	# --- Victory overlay ---
	if _victory_active:
		var v_alpha: float = clampf((8.0 - _victory_timer) / 1.5, 0.0, 1.0)
		if _victory_timer < 1.5:
			v_alpha = clampf(_victory_timer / 1.5, 0.0, 1.0)
		ctl.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.0, 0.05, 0.1, 0.6 * v_alpha))
		var v_title := "CELL STAGE COMPLETE!"
		var vts := font.get_string_size(v_title, HORIZONTAL_ALIGNMENT_CENTER, -1, 30)
		ctl.draw_string(font, Vector2((vp.x - vts.x) * 0.5, vp.y * 0.28), v_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.3, 1.0, 0.5, v_alpha))
		# Stats summary
		var time_str: String = "%d:%02d" % [int(_session_time) / 60, int(_session_time) % 60]
		var v_stats: Array = [
			"Time: " + time_str,
			"Kills: %d" % _session_kills,
			"Collections: %d" % _session_collections,
			"Mutations: %d" % GameManager.active_mutations.size(),
			"Evolution Level: %d" % GameManager.evolution_level,
		]
		var vy: float = vp.y * 0.38
		for vline in v_stats:
			var vls := font.get_string_size(vline, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			ctl.draw_string(font, Vector2((vp.x - vls.x) * 0.5, vy), vline, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.9, 0.7, 0.85 * v_alpha))
			vy += 26.0
		var v_hint := "Advancing to next stage..."
		var vhs := font.get_string_size(v_hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		ctl.draw_string(font, Vector2((vp.x - vhs.x) * 0.5, vy + 20), v_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.7, 0.8, 0.5 * v_alpha))

	# --- Chain Combo Display ---
	if _chain_display_timer > 0 and _chain_display_alpha > 0.01 and _chain_count >= 2:
		var chain_text: String = "CHAIN x%d!" % _chain_count
		var chain_fs: int = 20 + mini(_chain_count, 5) * 2
		var chain_size := font.get_string_size(chain_text, HORIZONTAL_ALIGNMENT_CENTER, -1, chain_fs)
		var cx: float = (vp.x - chain_size.x) * 0.5
		var cy: float = vp.y * 0.7
		var chain_color := Color(0.3, 1.0, 0.5).lerp(Color(1.0, 0.9, 0.2), clampf((_chain_count - 2.0) / 5.0, 0.0, 1.0))
		ctl.draw_string(font, Vector2(cx + 1, cy + 1), chain_text, HORIZONTAL_ALIGNMENT_LEFT, -1, chain_fs, Color(0, 0, 0, 0.5 * _chain_display_alpha))
		ctl.draw_string(font, Vector2(cx, cy), chain_text, HORIZONTAL_ALIGNMENT_LEFT, -1, chain_fs, Color(chain_color.r, chain_color.g, chain_color.b, _chain_display_alpha))
		var cat_text: String = _chain_category.replace("_", " ").capitalize()
		var cat_size := font.get_string_size(cat_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		ctl.draw_string(font, Vector2((vp.x - cat_size.x) * 0.5, cy + 22), cat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.9, 0.7, _chain_display_alpha * 0.7))

	# --- Kill Streak Announcement ---
	if _streak_announce_timer > 0 and _streak_announce_alpha > 0.01:
		var s_fs: int = int(28 * _streak_announce_scale)
		var s_size := font.get_string_size(_streak_announce_text, HORIZONTAL_ALIGNMENT_CENTER, -1, s_fs)
		var sx: float = (vp.x - s_size.x) * 0.5
		var sy: float = vp.y * 0.42
		ctl.draw_rect(Rect2(sx - 20, sy - 30, s_size.x + 40, 46), Color(0.1, 0.02, 0.02, 0.6 * _streak_announce_alpha))
		ctl.draw_rect(Rect2(sx - 21, sy - 31, s_size.x + 42, 1), Color(_streak_announce_color.r, _streak_announce_color.g, _streak_announce_color.b, _streak_announce_alpha * 0.7))
		ctl.draw_rect(Rect2(sx - 21, sy + 15, s_size.x + 42, 1), Color(_streak_announce_color.r, _streak_announce_color.g, _streak_announce_color.b, _streak_announce_alpha * 0.7))
		ctl.draw_string(font, Vector2(sx, sy), _streak_announce_text, HORIZONTAL_ALIGNMENT_LEFT, -1, s_fs, Color(_streak_announce_color.r, _streak_announce_color.g, _streak_announce_color.b, _streak_announce_alpha))

	# --- World Event Banner ---
	if _world_event_active:
		var event_text: String = _world_event_name
		var remaining_text: String = "%ds" % ceili(_world_event_remaining)
		var e_fs: int = 16
		var e_size := font.get_string_size(event_text, HORIZONTAL_ALIGNMENT_CENTER, -1, e_fs)
		var r_size := font.get_string_size(remaining_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		var total_w: float = e_size.x + r_size.x + 20
		var ex: float = (vp.x - total_w) * 0.5
		var ey: float = 32.0
		# Animated background bar
		var bar_pulse: float = 0.5 + 0.2 * sin(_session_time * 4.0)
		ctl.draw_rect(Rect2(ex - 15, ey - 18, total_w + 30, 30), Color(0.05, 0.02, 0.02, 0.7))
		ctl.draw_rect(Rect2(ex - 15, ey + 12, total_w + 30, 2), Color(_world_event_color.r, _world_event_color.g, _world_event_color.b, bar_pulse))
		# Progress bar
		var progress: float = _world_event_remaining / _world_event_duration
		ctl.draw_rect(Rect2(ex - 15, ey + 12, (total_w + 30) * progress, 2), Color(_world_event_color.r * 1.5, _world_event_color.g * 1.5, _world_event_color.b * 1.5, 0.9))
		ctl.draw_string(font, Vector2(ex, ey), event_text, HORIZONTAL_ALIGNMENT_LEFT, -1, e_fs, Color(_world_event_color.r, _world_event_color.g, _world_event_color.b, 0.95))
		ctl.draw_string(font, Vector2(ex + e_size.x + 15, ey), remaining_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7, 0.7))

	# --- Floating Texts (world-space to screen-space) ---
	if _floating_texts.size() > 0:
		var cam := player.get_node_or_null("Camera2D")
		if cam:
			var cam_pos: Vector2 = cam.global_position
			var zoom: Vector2 = cam.zoom if cam.zoom.x > 0 else Vector2.ONE
			for ft in _floating_texts:
				var screen_pos: Vector2 = (ft.pos - cam_pos) * zoom + vp * 0.5
				var max_life: float = ft.get("max_life", 2.0)
				var ft_alpha: float = clampf(ft.life / 1.0, 0.0, 1.0)
				if ft.life > max_life - 0.5:
					ft_alpha = clampf((max_life - ft.life) / 0.5, 0.0, 1.0)
				var ft_scale: float = ft.get("scale", 1.0)
				var draw_size: int = int(ft.size * ft_scale)
				var ft_size := font.get_string_size(ft.text, HORIZONTAL_ALIGNMENT_CENTER, -1, draw_size)
				var tx: float = screen_pos.x - ft_size.x * 0.5
				var ty: float = screen_pos.y
				var is_crit: bool = ft.get("critical", false)
				# Color-coded outline (drawn in 4 directions)
				var outline_col: Color = Color(ft.color.r * 0.3, ft.color.g * 0.3, ft.color.b * 0.3, ft_alpha * 0.7)
				if is_crit:
					outline_col = Color(ft.color.r, ft.color.g * 0.2, ft.color.b * 0.2, ft_alpha * 0.8)
				for ox in [-1.0, 1.0]:
					for oy in [-1.0, 1.0]:
						ctl.draw_string(font, Vector2(tx + ox, ty + oy), ft.text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, outline_col)
				# Main text
				var text_col: Color = Color(ft.color.r, ft.color.g, ft.color.b, ft_alpha)
				if is_crit:
					# Pulsing brightness for critical hits
					var pulse: float = 0.8 + sin(_session_time * 8.0) * 0.2
					text_col = text_col.lightened(0.3 * pulse)
				ctl.draw_string(font, Vector2(tx, ty), ft.text, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_size, text_col)

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

func _trigger_world_event() -> void:
	var event: Dictionary = WORLD_EVENTS[randi() % WORLD_EVENTS.size()]
	_world_event_active = true
	_world_event_name = event.name
	_world_event_duration = event.duration
	_world_event_remaining = event.duration
	_world_event_color = event.color
	# Announce the event
	_popup_text = event.desc
	_popup_timer = 4.0
	_popup_alpha = 1.0
	_popup_color = event.color
	AudioManager.play_sensory_upgrade()
	var cam := player.get_node_or_null("Camera2D")
	if cam and cam.has_method("shake"):
		cam.shake(4.0, 0.3)
	# Apply event-specific effects
	match _world_event_name:
		"NUTRIENT BLOOM":
			_spawn_bloom_food(20)
		"PARASITE SWARM":
			_spawn_parasite_swarm(8)
		"THERMAL ERUPTION":
			_spawn_eruption_food(12)
			# Damage pulse to everything nearby
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and enemy.global_position.distance_to(player.global_position) < 400.0:
					if enemy.has_method("take_damage"):
						enemy.take_damage(15.0)

func _end_world_event() -> void:
	_world_event_active = false
	_world_event_name = ""

func _spawn_bloom_food(count: int) -> void:
	var current_food: int = get_tree().get_nodes_in_group("food").size()
	count = mini(count, maxi(0, MAX_FOOD - current_food))
	for i in range(count):
		var food := FOOD_SCENE.instantiate()
		food.setup(BiologyLoader.get_random_biomolecule(), false)
		food.global_position = player.global_position + Vector2(
			randf_range(-300, 300), randf_range(-300, 300)
		)
		food.add_to_group("food")
		add_child(food)

func _spawn_parasite_swarm(count: int) -> void:
	var ParasiteScene := preload("res://scenes/parasite_organism.tscn")
	var spawn_center: Vector2 = player.global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	var current_count: int = get_tree().get_nodes_in_group("parasites").size()
	var spawn_limit: int = mini(count, maxi(0, 8 - current_count))
	for i in range(spawn_limit):
		var p := ParasiteScene.instantiate()
		p.global_position = spawn_center + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		add_child(p)

func _spawn_eruption_food(count: int) -> void:
	var current_food: int = get_tree().get_nodes_in_group("food").size()
	count = mini(count, maxi(0, MAX_FOOD - current_food))
	for i in range(count):
		var food := FOOD_SCENE.instantiate()
		var is_rare: bool = randf() < 0.3  # Higher rare chance from eruptions
		if is_rare:
			food.setup(BiologyLoader.get_random_organelle(), true)
		else:
			food.setup(BiologyLoader.get_random_biomolecule(), false)
		food.global_position = player.global_position + Vector2(
			randf_range(-250, 250), randf_range(-250, 250)
		)
		food.add_to_group("food")
		add_child(food)

func _enforce_population_caps() -> void:
	## Periodic cleanup: despawn far-away orphans and enforce global entity caps.
	if not player or not is_instance_valid(player):
		return
	var player_pos: Vector2 = player.global_position
	var despawn_dist_sq: float = DESPAWN_DISTANCE * DESPAWN_DISTANCE

	# Helper: cull farthest entities beyond cap
	var _cull := func(group_name: String, cap: int) -> void:
		var nodes: Array = get_tree().get_nodes_in_group(group_name)
		# First pass: despawn anything very far from player (orphaned entities)
		for node in nodes:
			if is_instance_valid(node) and node.global_position.distance_squared_to(player_pos) > despawn_dist_sq:
				node.queue_free()
		# Second pass: if still over cap, remove farthest
		nodes = get_tree().get_nodes_in_group(group_name)
		if nodes.size() > cap:
			# Sort by distance (farthest first)
			nodes.sort_custom(func(a: Node2D, b: Node2D) -> bool:
				return a.global_position.distance_squared_to(player_pos) > b.global_position.distance_squared_to(player_pos)
			)
			var to_remove: int = nodes.size() - cap
			for i in range(to_remove):
				if is_instance_valid(nodes[i]):
					nodes[i].queue_free()

	_cull.call("enemies", MAX_ENEMIES)
	_cull.call("parasites", MAX_PARASITES)
	_cull.call("food", MAX_FOOD)
	_cull.call("hazards", MAX_HAZARDS)
	_cull.call("viruses", MAX_VIRUSES)
	_cull.call("kin", MAX_KIN)

func _pause() -> void:
	_paused = true
	get_tree().paused = true
	_pause_menu.visible = true
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	# Close codex if open
	var codex_panel := codex_layer.get_node_or_null("CodexPanel")
	if codex_panel and codex_panel.visible:
		codex_panel.toggle()
	AudioManager.play_ui_open()

func _unpause() -> void:
	_paused = false
	get_tree().paused = false
	_pause_menu.visible = false

func _quit_to_menu() -> void:
	_paused = false
	get_tree().paused = false
	GameManager.go_to_menu()

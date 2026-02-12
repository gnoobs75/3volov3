extends Node3D
## Cave Stage Manager: orchestrates the underground cave world.
## Sets up cave system, environment, player worm, camera, and resource spawning.

var _player: CharacterBody3D = null
var _camera: Camera3D = null
var _cave_gen: Node3D = null
var _environment: WorldEnvironment = null
var _creatures_container: Node3D = null
var _nutrients_container: Node3D = null

# Ambient sound timers
var _drip_timer: float = 0.0
var _drone_timer: float = 0.0

# Nutrient spawning
const NUTRIENT_TARGET_COUNT: int = 30
const NUTRIENT_DESPAWN_RADIUS: float = 350.0

# Prey spawning
const PREY_TARGET_COUNT: int = 10
const PREY_DESPAWN_RADIUS: float = 350.0
var _prey_check_timer: float = 0.0

# White Blood Cell spawning
const WBC_TARGET_COUNT: int = 10
const WBC_DESPAWN_RADIUS: float = 350.0
var _wbc_check_timer: float = 0.0
var _wbc_container: Node3D = null
var _spawn_floor_y: float = -10.0  # Expected floor Y for safety check
var _cave_check_timer: float = 0.0  # Timer for cave boundary validation

# New enemy spawning
const PHAGOCYTE_TARGET_COUNT: int = 4
const KILLER_T_TARGET_COUNT: int = 5
const MAST_CELL_TARGET_COUNT: int = 4
var _new_enemy_check_timer: float = 0.0

# Brain hallucination flicker
var _hallucination_overlay: ColorRect = null
var _hallucination_timer: float = 0.0

# Antibody Flyer spawning
const FLYER_TARGET_COUNT: int = 8
const FLYER_DESPAWN_RADIUS: float = 350.0
var _flyer_check_timer: float = 0.0

# --- HUD references ---
var _controls_label: Label = null
var _vitals_hud: Control = null  # Curved arc bars

# --- Pause menu ---
var _pause_menu: Control = null
var _paused: bool = false

# --- Macrophage Queen Boss ---
var _queen_spawned: bool = false
var _queen: CharacterBody3D = null

# --- Biome Bosses ---
var _bosses_defeated: Dictionary = {}  # biome_index -> bool
var _biome_bosses: Dictionary = {}  # biome_index -> CharacterBody3D
var _active_boss: CharacterBody3D = null  # Currently visible boss for HUD
var _prev_boss_hp: float = -1.0  # Track damage for HUD shake

# Boss intro state
var _boss_intro_active: bool = false
var _boss_intro_timer: float = 0.0
var _boss_intro_name: String = ""
var _boss_intro_color: Color = Color.RED
var _boss_intros_shown: Dictionary = {}  # biome_idx -> true

# --- Creature Codex ---
var _creature_codex: Control = null
var _creature_codex_debounce: bool = false
var _discovery_timer: float = 0.0
const DISCOVERY_RANGE: float = 40.0

# --- Danger Proximity Indicator ---
var _nearest_threat_dir: Vector3 = Vector3.ZERO
var _nearest_threat_dist: float = INF
var _threat_scan_timer: float = 0.0
const THREAT_SCAN_INTERVAL: float = 0.25
const THREAT_DETECT_RANGE: float = 100.0

# --- Dynamic Combat Music State ---
enum CombatState { CALM, ALERT, COMBAT, VICTORY }
var _combat_state: CombatState = CombatState.CALM
var _combat_timer: float = 0.0  # Time since last combat event
var _alert_timer: float = 0.0
const COMBAT_COOLDOWN: float = 5.0
const ALERT_RANGE: float = 80.0

# --- Venom Tick ---
var _venom_tick_timer: float = 0.0

# --- Metadata Key Constants (prevents silent typo failures) ---
const META_VENOMED: String = "venomed"
const META_VENOM_REMAINING: String = "venom_remaining"
const META_VENOM_DPS: String = "venom_dps"
const META_ORIGINAL_EMISSION: String = "original_emission"
const META_THREAT_DIR: String = "threat_dir"
const META_THREAT_DIST: String = "threat_dist"
const META_THREAT_RANGE: String = "threat_range"
const META_BOSS_HEALTH: String = "boss_health"
const META_BOSS_MAX_HEALTH: String = "boss_max_health"
const META_BOSS_NAME: String = "boss_name"
const META_BOSS_COLOR: String = "boss_color"
const META_COLLECTED: String = "collected"
const META_BOSS_INTRO_NAME: String = "boss_intro_name"
const META_BOSS_INTRO_SUBTITLE: String = "boss_intro_subtitle"
const META_BOSS_INTRO_COLOR: String = "boss_intro_color"
const META_BOSS_INTRO_T: String = "boss_intro_t"

# --- Cached Enemy Scan (shared by combat state, threat scan, venom tick) ---
const ENEMY_GROUPS: Array = ["white_blood_cell", "flyer", "phagocyte", "killer_t_cell", "mast_cell", "boss"]
const ALL_CREATURE_GROUPS: Array = ["white_blood_cell", "prey", "flyer", "phagocyte", "killer_t_cell", "mast_cell", "boss"]
var _cached_enemies: Array = []  # [{node, dist}] updated once per frame
var _enemy_cache_frame: int = -1

# --- Vision/Darkness System ---
var _vision_env: Environment = null  # Reference for dynamic fog/ambient updates
var _player_omni_light: OmniLight3D = null  # Reference for dynamic range updates
var _last_sensory_level: int = -1

# Vision tier parameters: [fog_density, player_light_range, eye_spot_range, biolum_mult, ambient_energy]
# DESIGN: Total darkness beyond the player's light sphere. Only the parasite's glow illuminates.
# Ambient = 0 at start (nothing visible without player light). Fog contains the light sphere.
# Biolum = 0 at start (cave lights invisible until sensory upgrades reveal them).
# Monsters lurk in pure black — sonar pulse briefly reveals them. That's the horror.
const VISION_TIERS: Array = [
	{"fog": 0.15, "light_range": 12.0, "spot_range": 8.0, "biolum": 0.0, "ambient": 0.0},
	{"fog": 0.08, "light_range": 18.0, "spot_range": 12.0, "biolum": 0.1, "ambient": 0.002},
	{"fog": 0.05, "light_range": 25.0, "spot_range": 16.0, "biolum": 0.3, "ambient": 0.005},
	{"fog": 0.03, "light_range": 32.0, "spot_range": 20.0, "biolum": 0.55, "ambient": 0.01},
	{"fog": 0.02, "light_range": 40.0, "spot_range": 25.0, "biolum": 0.8, "ambient": 0.015},
	{"fog": 0.01, "light_range": 50.0, "spot_range": 30.0, "biolum": 1.0, "ambient": 0.025},
]

func _ready() -> void:
	_setup_environment()
	_setup_player()
	_setup_camera()
	_setup_cave_system()
	_setup_containers()
	_setup_hud()
	# Connect vision upgrade signals
	GameManager.sensory_level_changed.connect(_on_sensory_level_changed)
	# Connect evolution trigger for snake stage evolution UI
	GameManager.evolution_triggered.connect(_on_snake_evolution_triggered)

func _setup_environment() -> void:
	_environment = WorldEnvironment.new()
	var env: Environment = Environment.new()

	# Pure black underground — no sky contribution at all
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)

	# Zero ambient light at start — ONLY the player's light sphere illuminates
	var tier: Dictionary = _get_vision_tier()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = tier.ambient
	env.ambient_light_color = Color(0.01, 0.02, 0.015)

	# Fog creates the light sphere edge — dense fog = tight sphere, thin fog = wider view
	env.fog_enabled = true
	env.fog_light_color = Color(0, 0, 0)  # Pure black fog (no color bleed)
	env.fog_density = tier.fog
	env.fog_aerial_perspective = 0.95

	# Strong glow (makes emissions pop in darkness)
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# SSAO for cave depth
	env.ssao_enabled = true
	env.ssao_radius = 3.0
	env.ssao_intensity = 2.0

	_vision_env = env
	_environment.environment = env
	add_child(_environment)

	_last_sensory_level = GameManager.sensory_level

func _setup_player() -> void:
	var worm_script = load("res://scripts/snake_stage/player_worm.gd")
	_player = CharacterBody3D.new()
	_player.set_script(worm_script)
	# Position will be set after cave generates
	_player.position = Vector3(0, -5, 0)

	# Collision shape for the worm head
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 1.4
	col_shape.shape = capsule
	_player.add_child(col_shape)

	add_child(_player)

	# Disable physics until cave is ready (prevent falling through void)
	_player.set_physics_process(false)

	# Connect signals
	_player.damaged.connect(_on_player_damaged)
	_player.died.connect(_on_player_died)

func _setup_camera() -> void:
	var cam_script = load("res://scripts/snake_stage/worm_camera.gd")
	_camera = Camera3D.new()
	_camera.set_script(cam_script)
	_camera.fov = 75.0
	_camera.near = 0.05
	_camera.far = 600.0  # Large far plane for big caverns
	add_child(_camera)
	_camera.setup(_player)
	_camera.current = true

func _setup_cave_system() -> void:
	var cave_script = load("res://scripts/snake_stage/cave_generator.gd")
	_cave_gen = Node3D.new()
	_cave_gen.set_script(cave_script)
	_cave_gen.name = "CaveSystem"
	_cave_gen.setup(_player)
	add_child(_cave_gen)

	# Wait for cave generation to place player at spawn
	_cave_gen.cave_ready.connect(_on_cave_ready)

func _on_cave_ready() -> void:
	# Move player to spawn hub
	if _cave_gen.has_method("get_spawn_position"):
		var spawn_pos: Vector3 = _cave_gen.get_spawn_position()
		_player.global_position = spawn_pos
		_player.velocity = Vector3.ZERO
		if _player.has_method("reset_position_history"):
			_player.reset_position_history()
		print("[CAVE] Player placed at: %s" % str(spawn_pos))
		# Record expected floor Y for safety check
		var hub = _cave_gen.hubs[_cave_gen.spawn_hub_id]
		if hub.node_3d and hub.node_3d.has_method("get_floor_y"):
			_spawn_floor_y = hub.node_3d.get_floor_y(hub.position.x, hub.position.z)
		if _camera and _camera.has_method("snap_to_target"):
			_camera.snap_to_target()
	# Defer physics enable by one frame so collision shapes are fully registered
	call_deferred("_enable_player_physics")

	# Initial spawns
	call_deferred("_spawn_initial_nutrients")
	call_deferred("_spawn_initial_prey")
	call_deferred("_spawn_initial_wbc")
	call_deferred("_spawn_initial_flyers")

	# Spawn Macrophage Queen in the Brain biome hub
	call_deferred("_spawn_macrophage_queen")

	# Spawn new enemy types in appropriate biomes
	call_deferred("_spawn_initial_new_enemies")

	# Spawn biome bosses in each wing hub
	call_deferred("_spawn_biome_bosses")

	# Wire minimap to cave system
	if _minimap and _minimap.has_method("setup"):
		_minimap.setup(_cave_gen, _player)

	# Add player light for cave visibility
	_add_player_light()

	# Connect combat signals
	if _player.has_signal("bite_performed"):
		_player.bite_performed.connect(_on_player_bite)
	if _player.has_signal("stun_burst_fired"):
		_player.stun_burst_fired.connect(_on_player_stun_burst)

	# Connect tail whip signal for VFX
	if _player.has_signal("tail_whip_performed"):
		_player.tail_whip_performed.connect(_on_player_tail_whip)

	# Setup sonar contour point system
	call_deferred("_setup_sonar")

func _enable_player_physics() -> void:
	_player.set_physics_process(true)
	# Schedule a safety check after 1 second
	get_tree().create_timer(1.0).timeout.connect(_safety_check_position)

func _safety_check_position() -> void:
	if not _player or not _cave_gen:
		return
	# Use cave-aware validation
	_validate_player_inside_cave()

func _add_player_light() -> void:
	if not _player:
		return
	# Warm bioluminescent glow on player — visible radius scales with vision tier
	var tier: Dictionary = _get_vision_tier()
	var heat_light: OmniLight3D = OmniLight3D.new()
	heat_light.name = "PlayerLight"
	heat_light.light_color = Color(0.25, 0.55, 0.4)  # Bright green-teal
	heat_light.light_energy = 2.5  # Strong core glow
	heat_light.omni_range = tier.light_range
	heat_light.omni_attenuation = 1.0  # Linear falloff (brighter further out)
	heat_light.shadow_enabled = true
	heat_light.position = Vector3(0, 0.8, 0)
	_player.add_child(heat_light)
	_player_omni_light = heat_light

	# Secondary wider ambient glow (softer, dimmer, fills the 50% zone)
	var ambient_glow: OmniLight3D = OmniLight3D.new()
	ambient_glow.name = "PlayerAmbientGlow"
	ambient_glow.light_color = Color(0.15, 0.35, 0.25)
	ambient_glow.light_energy = 1.0
	ambient_glow.omni_range = tier.light_range * 1.8  # Extends ~2x beyond the core
	ambient_glow.omni_attenuation = 2.0  # Soft falloff
	ambient_glow.shadow_enabled = false
	ambient_glow.position = Vector3(0, 0.8, 0)
	_player.add_child(ambient_glow)

	# Scan pulse light (periodic bright burst)
	var scan_light: OmniLight3D = OmniLight3D.new()
	scan_light.name = "ScanLight"
	scan_light.light_color = Color(0.15, 0.6, 0.3)  # Bright green scan
	scan_light.light_energy = 0.0
	scan_light.omni_range = 15.0
	scan_light.omni_attenuation = 0.8
	scan_light.shadow_enabled = false
	scan_light.position = Vector3(0, 0.8, 0)
	_player.add_child(scan_light)

	# Update player eye stalk light to match tier
	_update_player_flashlight()

func _setup_containers() -> void:
	_creatures_container = Node3D.new()
	_creatures_container.name = "Creatures"
	add_child(_creatures_container)

	_nutrients_container = Node3D.new()
	_nutrients_container.name = "Nutrients"
	add_child(_nutrients_container)

	_wbc_container = Node3D.new()
	_wbc_container.name = "WhiteBloodCells"
	add_child(_wbc_container)

var _minimap: Control = null

func _setup_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.layer = 5
	hud.name = "HUD"
	add_child(hud)

	# --- Curved vitals arc bars (centered on screen, outside layout) ---
	var vitals_script = load("res://scripts/snake_stage/vitals_hud.gd")
	_vitals_hud = Control.new()
	_vitals_hud.set_script(vitals_script)
	_vitals_hud.name = "VitalsHUD"
	_vitals_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vitals_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_vitals_hud)

	# --- Three-pane layout (matching cell stage) ---
	var layout: HBoxContainer = HBoxContainer.new()
	layout.name = "ThreePaneLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(layout)

	# === LEFT PANE (280px) ===
	var left_panel: Panel = Panel.new()
	left_panel.name = "LeftPane"
	left_panel.custom_minimum_size = Vector2(280, 0)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_style: StyleBoxFlat = StyleBoxFlat.new()
	left_style.bg_color = Color(0.015, 0.025, 0.04, 1.0)
	left_style.border_width_right = 2
	left_style.border_color = Color(0.12, 0.25, 0.35, 0.7)
	left_panel.add_theme_stylebox_override("panel", left_style)
	layout.add_child(left_panel)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.name = "LeftVBox"
	left_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_vbox.add_theme_constant_override("separation", 0)
	left_panel.add_child(left_vbox)

	# OrganismCard (top of left pane)
	var org_card_script = load("res://scripts/cell_stage/organism_card.gd")
	var organism_card: Control = Control.new()
	organism_card.set_script(org_card_script)
	organism_card.name = "OrganismCard"
	organism_card.custom_minimum_size = Vector2(280, 620)
	organism_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(organism_card)

	# HelixHUD (bottom of left pane, fills remaining space)
	var helix_script = load("res://scripts/cell_stage/test_tube_hud.gd")
	var helix_hud: Control = Control.new()
	helix_hud.set_script(helix_script)
	helix_hud.name = "HelixHUD"
	helix_hud.custom_minimum_size = Vector2(280, 460)
	helix_hud.size_flags_vertical = Control.SIZE_EXPAND_FILL
	helix_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(helix_hud)

	# === MIDDLE PANE (flex) ===
	var middle_pane: Control = Control.new()
	middle_pane.name = "MiddlePane"
	middle_pane.custom_minimum_size = Vector2(1320, 0)
	middle_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle_pane.size_flags_stretch_ratio = 70.0
	middle_pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(middle_pane)

	# Top bar in middle pane
	var top_bar: ColorRect = ColorRect.new()
	top_bar.color = Color(0.02, 0.05, 0.1, 0.7)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 80.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle_pane.add_child(top_bar)

	# Stage title (center top)
	var title: Label = Label.new()
	title.text = "PARASITE MODE - Inside the Host"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-140, 8)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.3, 0.6, 0.5, 0.7))
	middle_pane.add_child(title)

	# Depth indicator
	var depth_label: Label = Label.new()
	depth_label.name = "DepthLabel"
	depth_label.text = "DEPTH: 10m"
	depth_label.position = Vector2(240, 4)
	depth_label.add_theme_font_size_override("font_size", 10)
	depth_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.8, 0.7))
	middle_pane.add_child(depth_label)

	# Controls label (bottom of middle pane)
	_controls_label = Label.new()
	_controls_label.text = "WASD: Move | Shift: Sprint | RMB: Bite | LMB: Pull | E: Stun | F: Tail Whip | C: Camo | Hold Q: Traits | TAB: Codex"
	_controls_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_controls_label.position = Vector2(20, -30)
	_controls_label.add_theme_font_size_override("font_size", 12)
	_controls_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.4, 0.5))
	middle_pane.add_child(_controls_label)

	# === RIGHT PANE (320px) ===
	var right_panel: Panel = Panel.new()
	right_panel.name = "RightPane"
	right_panel.custom_minimum_size = Vector2(320, 0)
	right_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right_style: StyleBoxFlat = StyleBoxFlat.new()
	right_style.bg_color = Color(0.015, 0.025, 0.04, 1.0)
	right_style.border_width_left = 2
	right_style.border_color = Color(0.12, 0.25, 0.35, 0.7)
	right_panel.add_theme_stylebox_override("panel", right_style)
	layout.add_child(right_panel)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.name = "RightVBox"
	right_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_vbox.add_theme_constant_override("separation", 0)
	right_panel.add_child(right_vbox)

	# Cave Minimap (top of right pane)
	var minimap_script = load("res://scripts/snake_stage/cave_minimap.gd")
	_minimap = Control.new()
	_minimap.set_script(minimap_script)
	_minimap.name = "CaveMinimap"
	_minimap.custom_minimum_size = Vector2(320, 400)
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(_minimap)

	# ObserverNotes (bottom of right pane, fills remaining space)
	var notes_script = load("res://scripts/cell_stage/observer_notes.gd")
	var observer_notes: Control = Control.new()
	observer_notes.set_script(notes_script)
	observer_notes.name = "ObserverNotes"
	observer_notes.custom_minimum_size = Vector2(320, 400)
	observer_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	observer_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(observer_notes)

	# Pause menu (on HUD layer, hidden until ESC)
	var pause_script = load("res://scripts/snake_stage/pause_menu.gd")
	_pause_menu = Control.new()
	_pause_menu.set_script(pause_script)
	_pause_menu.name = "PauseMenu"
	_pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.visible = false
	_pause_menu.resumed.connect(_unpause)
	_pause_menu.quit_to_menu.connect(_quit_to_menu)
	hud.add_child(_pause_menu)

	# Creature Codex overlay
	var codex_layer: CanvasLayer = CanvasLayer.new()
	codex_layer.layer = 10
	codex_layer.name = "CodexLayer"
	add_child(codex_layer)
	var codex_script = load("res://scripts/snake_stage/creature_codex.gd")
	_creature_codex = Control.new()
	_creature_codex.set_script(codex_script)
	_creature_codex.name = "CreatureCodex"
	_creature_codex.set_anchors_preset(Control.PRESET_FULL_RECT)
	codex_layer.add_child(_creature_codex)

	# Trait Radial Menu overlay (Hold Q)
	var trait_layer: CanvasLayer = CanvasLayer.new()
	trait_layer.layer = 11
	trait_layer.name = "TraitMenuLayer"
	add_child(trait_layer)
	var radial_script = load("res://scripts/snake_stage/trait_radial_menu.gd")
	if radial_script:
		var radial: Control = Control.new()
		radial.set_script(radial_script)
		radial.name = "TraitRadialMenu"
		radial.set_anchors_preset(Control.PRESET_FULL_RECT)
		trait_layer.add_child(radial)

# --- Scan pulse timer ---
var _scan_timer: float = 0.0
var _scan_intensity: float = 0.0
const SCAN_INTERVAL: float = 3.5
const SCAN_DURATION: float = 1.5

# --- Sonar heightmap pointcloud system (Moondust-style) ---
const SONAR_POINT_COUNT: int = 8000
const SONAR_RANGE: float = 60.0
const SONAR_FADE_TIME: float = 25.0  # Terrain persists long
const SONAR_EXPAND_SPEED: float = 18.0  # units/sec ring expansion
const SONAR_RAIN_HEIGHT: float = 2.5  # subtle drop into position
const SONAR_RAIN_DURATION: float = 0.12  # quick snap-to-place

# Passive sonar: continuous terrain mapping near the player
var _passive_sonar_timer: float = 0.0
const PASSIVE_SONAR_INTERVAL: float = 1.5  # Cast rays every 1.5s
const PASSIVE_SONAR_RANGE: float = 20.0  # Close-range terrain mapping
const PASSIVE_SONAR_RAYS: int = 120  # Rays per passive tick
var _sonar_multimesh: MultiMeshInstance3D = null
var _sonar_mm: MultiMesh = null
var _sonar_points: Array = []  # {target_pos, active, life, rain_t, dist, color, rand_delay}
var _sonar_pulse_active: bool = false
var _sonar_pulse_radius: float = 0.0
var _sonar_pulse_origin: Vector3 = Vector3.ZERO
var _sonar_pending_hits: Array = []
var _sonar_ready: bool = false
var _sonar_ring: MeshInstance3D = null
var _sonar_ring_mat: StandardMaterial3D = null
var _sonar_next_free: int = 0  # fast free-slot search

func _process(delta: float) -> void:
	_handle_input()
	_update_spawn_timers(delta)
	_update_combat_systems(delta)
	_update_visual_systems(delta)
	_update_hud()
	_update_camera_context()
	_update_ending_sequence(delta)

func _handle_input() -> void:
	# Pause toggle (ESC)
	if Input.is_action_just_pressed("ui_cancel"):
		if _paused:
			_unpause()
		else:
			_pause()
	# Creature Codex toggle (TAB)
	if Input.is_key_pressed(KEY_TAB) and not _paused:
		if _creature_codex and not _creature_codex_debounce:
			_creature_codex.toggle()
			_creature_codex_debounce = true
	elif not Input.is_key_pressed(KEY_TAB):
		_creature_codex_debounce = false

func _update_spawn_timers(delta: float) -> void:
	_manage_nutrients()
	# Prey management
	_prey_check_timer += delta
	if _prey_check_timer >= 3.0:
		_prey_check_timer = 0.0
		_manage_prey()
	# WBC management
	_wbc_check_timer += delta
	if _wbc_check_timer >= 3.0:
		_wbc_check_timer = 0.0
		_manage_wbc()
	# Flyer management
	_flyer_check_timer += delta
	if _flyer_check_timer >= 3.0:
		_flyer_check_timer = 0.0
		_manage_flyers()
	# New enemy management
	_new_enemy_check_timer += delta
	if _new_enemy_check_timer >= 4.0:
		_new_enemy_check_timer = 0.0
		_manage_new_enemies()
	# Safety: full cave validation every 1 second
	_cave_check_timer += delta
	if _cave_check_timer >= 1.0:
		_cave_check_timer = 0.0
		_validate_player_inside_cave()
		_cleanup_out_of_bounds_creatures()
	# Creature discovery scan
	_discovery_timer += delta
	if _discovery_timer >= 1.0:
		_discovery_timer = 0.0
		_scan_creature_discovery()

func _update_combat_systems(delta: float) -> void:
	# Danger proximity indicator
	_threat_scan_timer += delta
	if _threat_scan_timer >= THREAT_SCAN_INTERVAL:
		_threat_scan_timer = 0.0
		_scan_nearest_threat()
	# Venom tick (apply DoT to venomed enemies)
	_venom_tick_timer += delta
	if _venom_tick_timer >= 0.5:
		_venom_tick_timer = 0.0
		_tick_venom_damage()
	# Recovery orb animation
	_update_recovery_orbs(delta)
	# Combat music state machine
	_update_combat_state(delta)
	# Boss intro title card
	_update_boss_intro(delta)

func _update_visual_systems(delta: float) -> void:
	# Stun burst VFX
	_update_stun_vfx(delta)
	# Bite flash VFX
	_update_bite_flash(delta)
	# Scan pulse + sonar
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_intensity = 1.0
		_trigger_sonar_pulse()
	if _scan_intensity > 0.01:
		_scan_intensity = lerpf(_scan_intensity, 0.0, delta * (1.0 / SCAN_DURATION) * 3.0)
		if _scan_intensity < 0.01:
			_scan_intensity = 0.0
	# Update scan light on player
	if _player:
		var scan_light: Node = _player.get_node_or_null("ScanLight")
		if scan_light:
			scan_light.light_energy = _scan_intensity * 1.2
			scan_light.omni_range = 15.0 * (0.5 + _scan_intensity * 0.3)
	# Update sonar contour points
	_update_sonar(delta)
	# Passive terrain sonar
	_passive_sonar_timer += delta
	if _passive_sonar_timer >= PASSIVE_SONAR_INTERVAL:
		_passive_sonar_timer = 0.0
		_cast_passive_sonar()
	# Brain hallucination flicker
	_update_hallucination(delta)

	# Ambient cave sounds
	_drip_timer += delta
	if _drip_timer > randf_range(2.0, 6.0):
		_drip_timer = 0.0
		if AudioManager.has_method("play_cave_drip"):
			AudioManager.play_cave_drip()

func _update_hud() -> void:
	if _player and _vitals_hud:
		_vitals_hud.health_ratio = _player.health / _player.max_health
		_vitals_hud.energy_ratio = _player.energy / _player.max_energy
	# Update depth label (now inside ThreePaneLayout/MiddlePane)
	if _player:
		var depth_label: Label = get_node_or_null("HUD/ThreePaneLayout/MiddlePane/DepthLabel")
		if depth_label:
			var depth: float = absf(_player.global_position.y)
			depth_label.text = "DEPTH: %dm" % int(depth)
	# Boss health bar: find nearest active boss and feed data to vitals HUD
	_update_boss_hud()

const BOSS_NAMES: Dictionary = {
	1: "CARDIAC COLOSSUS",
	2: "GUT WARDEN",
	3: "ALVEOLAR TITAN",
	4: "MARROW SENTINEL",
	6: "MACROPHAGE QUEEN",
	-1: "MIRROR PARASITE",
}
const BOSS_COLORS: Dictionary = {
	1: Color(0.85, 0.15, 0.1),   # Red (heart)
	2: Color(0.5, 0.35, 0.15),   # Brown (gut)
	3: Color(0.8, 0.5, 0.6),     # Pink (lung)
	4: Color(0.85, 0.8, 0.6),    # Bone white
	6: Color(0.8, 0.3, 0.6),     # Magenta (brain)
	-1: Color(0.45, 0.15, 0.6),  # Dark purple (mirror)
}
const BOSS_DETECT_RANGE: float = 80.0

func _update_boss_hud() -> void:
	if not _player or not _vitals_hud:
		return
	# Find the nearest living boss within detection range
	var closest_boss: CharacterBody3D = null
	var closest_dist: float = BOSS_DETECT_RANGE
	var closest_idx: int = -99

	for biome_idx in _biome_bosses:
		var boss: CharacterBody3D = _biome_bosses[biome_idx]
		if not is_instance_valid(boss) or not boss.is_inside_tree():
			continue
		var dist: float = _player.global_position.distance_to(boss.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_boss = boss
			closest_idx = biome_idx
	# Check queen
	if is_instance_valid(_queen) and _queen.is_inside_tree():
		var qdist: float = _player.global_position.distance_to(_queen.global_position)
		if qdist < closest_dist:
			closest_dist = qdist
			closest_boss = _queen
			closest_idx = 6
	# Check mirror parasite
	for node in _creatures_container.get_children():
		if node.has_meta("is_mirror_parasite"):
			var mdist: float = _player.global_position.distance_to(node.global_position)
			if mdist < closest_dist:
				closest_dist = mdist
				closest_boss = node
				closest_idx = -1

	_active_boss = closest_boss
	if closest_boss and closest_boss.get("health") != null:
		var hp: float = closest_boss.health
		var max_hp: float = closest_boss.max_health
		_vitals_hud.set_meta(META_BOSS_HEALTH, hp)
		_vitals_hud.set_meta(META_BOSS_MAX_HEALTH, max_hp)
		_vitals_hud.set_meta(META_BOSS_NAME, BOSS_NAMES.get(closest_idx, "BOSS"))
		_vitals_hud.set_meta(META_BOSS_COLOR, BOSS_COLORS.get(closest_idx, Color.RED))
		# Shake on damage
		if _prev_boss_hp > 0 and hp < _prev_boss_hp:
			_vitals_hud._boss_bar_shake = 1.0
		_prev_boss_hp = hp
		# Trigger boss intro if first encounter
		_try_boss_intro(closest_idx)
	else:
		_vitals_hud.set_meta(META_BOSS_HEALTH, -1.0)
		_prev_boss_hp = -1.0

const BOSS_SUBTITLES: Dictionary = {
	1: "Guardian of the Heart Chamber",
	2: "Warden of the Intestinal Tract",
	3: "Titan of the Lung Tissue",
	4: "Sentinel of the Bone Marrow",
	6: "Queen of the Brain",
	-1: "Your Dark Reflection",
}
const BOSS_INTRO_DURATION: float = 3.0

func _try_boss_intro(biome_idx: int) -> void:
	if _boss_intros_shown.get(biome_idx, false):
		return
	_boss_intros_shown[biome_idx] = true
	_boss_intro_active = true
	_boss_intro_timer = 0.0
	_boss_intro_name = BOSS_NAMES.get(biome_idx, "BOSS")
	_boss_intro_color = BOSS_COLORS.get(biome_idx, Color.RED)
	if _vitals_hud:
		_vitals_hud.set_meta(META_BOSS_INTRO_NAME, _boss_intro_name)
		_vitals_hud.set_meta(META_BOSS_INTRO_SUBTITLE, BOSS_SUBTITLES.get(biome_idx, ""))
		_vitals_hud.set_meta(META_BOSS_INTRO_COLOR, _boss_intro_color)
	if AudioManager.has_method("play_boss_intro_sting"):
		AudioManager.play_boss_intro_sting()
	# Dramatic slow-motion during intro
	Engine.time_scale = 0.4

func _update_boss_intro(delta: float) -> void:
	if not _boss_intro_active:
		return
	# Use unscaled delta so intro plays at real-time despite slow-mo
	_boss_intro_timer += delta / maxf(Engine.time_scale, 0.1)
	var t: float = clampf(_boss_intro_timer / BOSS_INTRO_DURATION, 0.0, 1.0)
	if _vitals_hud:
		_vitals_hud.set_meta(META_BOSS_INTRO_T, t)
	# Ease time_scale back to normal in the last 30%
	if t > 0.7:
		var restore_t: float = (t - 0.7) / 0.3
		Engine.time_scale = lerpf(0.4, 1.0, restore_t)
	if _boss_intro_timer >= BOSS_INTRO_DURATION:
		_boss_intro_active = false
		Engine.time_scale = 1.0
		if _vitals_hud:
			_vitals_hud.set_meta(META_BOSS_INTRO_T, 0.0)

func _update_camera_context() -> void:
	if not _player or not _camera or not _cave_gen:
		return
	if not _camera.has_method("set_cave_size"):
		return
	var hub = _cave_gen.get_hub_at_position(_player.global_position)
	if hub:
		_camera.set_cave_size(clampf(hub.radius / 120.0, 0.3, 1.0))
	else:
		# In tunnel: use moderate camera
		_camera.set_cave_size(0.15)

func _validate_player_inside_cave() -> void:
	if not _player or not _cave_gen:
		return
	if not _cave_gen.is_inside_cave(_player.global_position):
		# Player is outside cave geometry — teleport to nearest hub center
		var safe_pos: Vector3 = _cave_gen.get_nearest_hub_center_on_floor(_player.global_position)
		print("[SAFETY] Player outside cave at %s — teleporting to %s" % [str(_player.global_position), str(safe_pos)])
		_player.global_position = safe_pos
		_player.velocity = Vector3.ZERO
		if _player.has_method("reset_position_history"):
			_player.reset_position_history()
		if _camera and _camera.has_method("snap_to_target"):
			_camera.snap_to_target()

func _cleanup_out_of_bounds_creatures() -> void:
	if not _cave_gen:
		return
	# Remove any creatures that ended up outside cave geometry
	for child in _creatures_container.get_children():
		if not _cave_gen.is_inside_cave(child.global_position):
			child.queue_free()
	for child in _wbc_container.get_children():
		if not _cave_gen.is_inside_cave(child.global_position):
			child.queue_free()
	for child in _nutrients_container.get_children():
		if not _cave_gen.is_inside_cave(child.global_position):
			child.queue_free()

func _manage_nutrients() -> void:
	if not _player:
		return
	# Despawn far nutrients
	for child in _nutrients_container.get_children():
		if child.global_position.distance_to(_player.global_position) > NUTRIENT_DESPAWN_RADIUS:
			child.queue_free()
	# Spawn new nutrients if below target
	var current_count: int = _nutrients_container.get_child_count()
	if current_count < NUTRIENT_TARGET_COUNT:
		_spawn_nutrient()

func _spawn_nutrient() -> void:
	if not _player or not _cave_gen:
		return
	var nutrient: Node3D = _create_nutrient()
	# Spawn inside a nearby hub — guaranteed to be inside cave geometry
	var pos: Vector3 = _cave_gen.get_random_position_in_hub(_player.global_position)
	nutrient.position = pos
	_nutrients_container.add_child(nutrient)

func _create_nutrient() -> Node3D:
	var nutrient: Area3D = Area3D.new()

	# Visual: glowing orb
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh_instance.mesh = sphere

	# Cave-themed nutrient colors (more bioluminescent)
	var colors: Array = [
		Color(0.1, 0.5, 0.8),   # chitin - deep blue
		Color(0.7, 0.5, 0.1),   # sugars - amber
		Color(0.2, 0.8, 0.3),   # proteins - bright green
		Color(0.6, 0.3, 0.8),   # enzymes - purple
		Color(0.8, 0.6, 0.2),   # lipids - gold
		Color(0.2, 0.7, 0.7),   # genetic - cyan
		Color(0.8, 0.4, 0.15),  # metabolic - orange
		Color(0.4, 0.8, 0.5),   # cellular - jade
	]
	var col_index: int = randi_range(0, colors.size() - 1)
	var col: Color = colors[col_index]

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.0  # Brighter in dark caves
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	mesh_instance.material_override = mat
	nutrient.add_child(mesh_instance)

	# Point light so nutrients glow visibly in darkness
	var nutrient_light: OmniLight3D = OmniLight3D.new()
	nutrient_light.light_color = col
	nutrient_light.light_energy = 0.4
	nutrient_light.omni_range = 3.0
	nutrient_light.omni_attenuation = 2.0
	nutrient_light.shadow_enabled = false
	nutrient.add_child(nutrient_light)

	# Collision for pickup
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 0.8
	col_shape.shape = sphere_shape
	nutrient.add_child(col_shape)

	# Attach nutrient behavior script
	var nutrient_script = load("res://scripts/snake_stage/land_nutrient.gd")
	nutrient.set_script(nutrient_script)
	nutrient.category_index = col_index

	# 5% chance of golden nutrient (3x value, flees from player)
	if randf() < 0.05:
		nutrient.is_golden = true
		# Override color to gold
		mat.albedo_color = Color(1.0, 0.85, 0.2, 0.95)
		mat.emission = Color(1.0, 0.85, 0.2)
		mat.emission_energy_multiplier = 5.0
		nutrient_light.light_color = Color(1.0, 0.85, 0.2)
		nutrient_light.light_energy = 0.8

	return nutrient

func _spawn_initial_nutrients() -> void:
	for i in range(NUTRIENT_TARGET_COUNT):
		_spawn_nutrient()

func _manage_prey() -> void:
	if not _player:
		return
	# Despawn far prey
	for child in _creatures_container.get_children():
		if child.is_in_group("prey") and child.global_position.distance_to(_player.global_position) > PREY_DESPAWN_RADIUS:
			child.queue_free()
	# Count and spawn
	var prey_count: int = 0
	for child in _creatures_container.get_children():
		if child.is_in_group("prey"):
			prey_count += 1
	if prey_count < PREY_TARGET_COUNT:
		_spawn_prey()

func _spawn_initial_prey() -> void:
	for i in range(PREY_TARGET_COUNT):
		_spawn_prey()

func _spawn_prey() -> void:
	if not _player or not _cave_gen:
		return
	var bug_script = load("res://scripts/snake_stage/prey_bug.gd")
	var bug: CharacterBody3D = CharacterBody3D.new()
	bug.set_script(bug_script)

	# Spawn inside a nearby hub — guaranteed inside cave geometry
	var pos: Vector3 = _cave_gen.get_random_position_in_hub(_player.global_position)
	bug.position = pos
	_creatures_container.add_child(bug)
	if bug.has_signal("died"):
		bug.died.connect(_on_creature_died)

func _on_player_damaged(_amount: float) -> void:
	pass  # Future: screen shake, observer notes

func _on_player_died() -> void:
	# Spawn recovery orbs at death location
	if _player and _player.last_death_position != Vector3.ZERO:
		_spawn_recovery_orbs(_player.last_death_position)
	# Respawn player at center hub
	if _player and _cave_gen and _cave_gen.hubs.size() > 0:
		var hub = _cave_gen.hubs[0]
		_player.global_position = hub.position + Vector3(0, 2, 0)

func _update_recovery_orbs(delta: float) -> void:
	for orb in get_tree().get_nodes_in_group("recovery_orb"):
		if not is_instance_valid(orb):
			continue
		var t: float = orb.get_meta("time", 0.0) + delta
		orb.set_meta("time", t)
		var base_y: float = orb.get_meta("base_y", orb.position.y)
		orb.position.y = base_y + sin(t * 2.5) * 0.3
		var mesh: MeshInstance3D = orb.get_meta("mesh", null) as MeshInstance3D
		if mesh:
			mesh.rotation.y += delta * 2.0
		# Lifetime fade
		var life: float = orb.get_meta("lifetime", 60.0) - delta
		orb.set_meta("lifetime", life)
		if life <= 0:
			orb.queue_free()
		elif life < 5.0:
			# Fade out in last 5 seconds
			if mesh and mesh.material_override:
				mesh.material_override.albedo_color.a = life / 5.0

func _spawn_recovery_orbs(death_pos: Vector3) -> void:
	var orb_count: int = 4
	for i in range(orb_count):
		var orb := Area3D.new()
		orb.add_to_group("recovery_orb")
		# Scatter around death point
		var offset := Vector3(randf_range(-3.0, 3.0), 0.5, randf_range(-3.0, 3.0))
		orb.position = death_pos + offset
		# Collision
		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.5
		col.shape = sphere
		orb.add_child(col)
		# Glowing green mesh
		var mesh_inst := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.3
		sphere_mesh.height = 0.6
		mesh_inst.mesh = sphere_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 1.0, 0.4, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.9, 0.3)
		mat.emission_energy_multiplier = 3.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_inst.material_override = mat
		orb.add_child(mesh_inst)
		# Light
		var light := OmniLight3D.new()
		light.light_color = Color(0.3, 0.9, 0.4)
		light.light_energy = 1.5
		light.omni_range = 5.0
		light.shadow_enabled = false
		orb.add_child(light)
		# Store metadata for bob animation and lifetime
		orb.set_meta("base_y", orb.position.y)
		orb.set_meta("time", randf() * TAU)
		orb.set_meta("lifetime", 60.0)
		orb.set_meta("mesh", mesh_inst)
		# Pickup callback
		orb.body_entered.connect(func(body: Node3D):
			if orb.get_meta(META_COLLECTED, false):
				return
			if body.is_in_group("player_worm"):
				orb.set_meta(META_COLLECTED, true)
				if body.has_method("heal"):
					body.heal(body.max_health * 0.15)
				if body.has_method("restore_energy"):
					body.restore_energy(body.max_energy * 0.15)
				AudioManager.play_land_collect()
				orb.queue_free()
		)
		_creatures_container.add_child(orb)

# --- White Blood Cell Management ---
func _spawn_initial_wbc() -> void:
	for i in range(WBC_TARGET_COUNT):
		_spawn_wbc()

func _manage_wbc() -> void:
	if not _player or not _wbc_container:
		return
	# Despawn far WBCs
	for child in _wbc_container.get_children():
		if child.is_in_group("white_blood_cell") and child.global_position.distance_to(_player.global_position) > WBC_DESPAWN_RADIUS:
			child.queue_free()
	# Count and spawn
	var wbc_count: int = 0
	for child in _wbc_container.get_children():
		if child.is_in_group("white_blood_cell"):
			wbc_count += 1
	if wbc_count < WBC_TARGET_COUNT:
		_spawn_wbc()

func _spawn_wbc() -> void:
	if not _player or not _wbc_container or not _cave_gen:
		return
	var wbc_script = load("res://scripts/snake_stage/white_blood_cell.gd")
	var wbc: CharacterBody3D = CharacterBody3D.new()
	wbc.set_script(wbc_script)

	# Spawn inside a nearby hub — guaranteed inside cave geometry
	var pos: Vector3 = _cave_gen.get_random_position_in_hub(_player.global_position)
	wbc.position = pos
	_wbc_container.add_child(wbc)
	if wbc.has_signal("died"):
		wbc.died.connect(_on_creature_died)

# --- Antibody Flyer Management ---
func _spawn_initial_flyers() -> void:
	# Stagger initial spawns widely across the hub to avoid dog-piling the player
	for i in range(FLYER_TARGET_COUNT):
		_spawn_flyer(true)

func _manage_flyers() -> void:
	if not _player or not _creatures_container:
		return
	# Despawn far flyers
	for child in _creatures_container.get_children():
		if child.is_in_group("flyer") and child.global_position.distance_to(_player.global_position) > FLYER_DESPAWN_RADIUS:
			child.queue_free()
	# Count and spawn
	var flyer_count: int = 0
	for child in _creatures_container.get_children():
		if child.is_in_group("flyer"):
			flyer_count += 1
	if flyer_count < FLYER_TARGET_COUNT:
		_spawn_flyer(false)

func _spawn_flyer(initial_spread: bool = false) -> void:
	if not _player or not _cave_gen:
		return
	var flyer_script = load("res://scripts/snake_stage/antibody_flyer.gd")
	var flyer: CharacterBody3D = CharacterBody3D.new()
	flyer.set_script(flyer_script)

	var pos: Vector3 = Vector3.ZERO
	var min_dist: float = 100.0 if initial_spread else 80.0

	if initial_spread:
		# For initial spawns, push flyers to the FAR EDGES of the hub
		# so they're distant from the player who spawns near center
		var active_hubs: Array = []
		for hub in _cave_gen.hubs:
			if hub.is_active:
				active_hubs.append(hub)
		if active_hubs.is_empty():
			return
		var hub = active_hubs[randi_range(0, active_hubs.size() - 1)]
		var angle: float = randf() * TAU
		# Place at 75-95% of hub radius — always near the walls, far from center
		var r: float = hub.radius * randf_range(0.75, 0.95)
		pos = Vector3(
			hub.position.x + cos(angle) * r,
			hub.position.y + 1.0,
			hub.position.z + sin(angle) * r
		)
		if hub.node_3d and hub.node_3d.has_method("get_floor_y"):
			pos.y = hub.node_3d.get_floor_y(pos.x, pos.z) + 0.5
	else:
		# Runtime respawns: spawn in a nearby hub but away from the player
		for _attempt in range(8):
			pos = _cave_gen.get_random_position_in_hub(_player.global_position)
			var horiz_dist: float = Vector2(pos.x - _player.global_position.x, pos.z - _player.global_position.z).length()
			if horiz_dist > min_dist:
				break

	# Varied hover height so they don't all cluster at the same altitude
	pos.y += randf_range(6.0, 14.0)
	flyer.position = pos
	_creatures_container.add_child(flyer)
	if flyer.has_signal("died"):
		flyer.died.connect(_on_creature_died)

# --- New Enemy Spawning (Phagocyte, Killer T-Cell, Mast Cell) ---
func _spawn_initial_new_enemies() -> void:
	for i in range(PHAGOCYTE_TARGET_COUNT):
		_spawn_new_enemy("phagocyte")
	for i in range(KILLER_T_TARGET_COUNT):
		_spawn_new_enemy("killer_t_cell")
	for i in range(MAST_CELL_TARGET_COUNT):
		_spawn_new_enemy("mast_cell")

func _manage_new_enemies() -> void:
	if not _player or not _creatures_container:
		return
	# Count and respawn if below target
	var phago_count: int = 0
	var killer_count: int = 0
	var mast_count: int = 0
	for child in _creatures_container.get_children():
		if child.is_in_group("phagocyte"):
			phago_count += 1
			if child.global_position.distance_to(_player.global_position) > 350.0:
				child.queue_free()
		elif child.is_in_group("killer_t_cell"):
			killer_count += 1
			if child.global_position.distance_to(_player.global_position) > 350.0:
				child.queue_free()
		elif child.is_in_group("mast_cell"):
			mast_count += 1
			if child.global_position.distance_to(_player.global_position) > 350.0:
				child.queue_free()
	if phago_count < PHAGOCYTE_TARGET_COUNT:
		_spawn_new_enemy("phagocyte")
	if killer_count < KILLER_T_TARGET_COUNT:
		_spawn_new_enemy("killer_t_cell")
	if mast_count < MAST_CELL_TARGET_COUNT:
		_spawn_new_enemy("mast_cell")

func _spawn_new_enemy(enemy_type: String) -> void:
	if not _player or not _cave_gen:
		return

	var script_path: String = ""
	var biome_filter: Array = []
	match enemy_type:
		"phagocyte":
			script_path = "res://scripts/snake_stage/phagocyte.gd"
			biome_filter = [0, 2]  # STOMACH, INTESTINAL_TRACT
		"killer_t_cell":
			script_path = "res://scripts/snake_stage/killer_t_cell.gd"
			biome_filter = [4, 5]  # BONE_MARROW, LIVER
		"mast_cell":
			script_path = "res://scripts/snake_stage/mast_cell.gd"
			biome_filter = [3, 1]  # LUNG_TISSUE, HEART_CHAMBER

	var enemy_script = load(script_path)
	if not enemy_script:
		return

	# Find a hub with the right biome
	var valid_hubs: Array = []
	for hub in _cave_gen.hubs:
		if hub.is_active and hub.biome in biome_filter:
			valid_hubs.append(hub)
	# Fallback: spawn in any active hub
	if valid_hubs.is_empty():
		for hub in _cave_gen.hubs:
			if hub.is_active:
				valid_hubs.append(hub)
	if valid_hubs.is_empty():
		return

	var hub = valid_hubs[randi_range(0, valid_hubs.size() - 1)]
	var angle: float = randf() * TAU
	var r: float = hub.radius * 0.6 * sqrt(randf())
	var pos: Vector3 = Vector3(
		hub.position.x + cos(angle) * r,
		hub.position.y + 1.0,
		hub.position.z + sin(angle) * r
	)
	if hub.node_3d and hub.node_3d.has_method("get_floor_y"):
		pos.y = hub.node_3d.get_floor_y(pos.x, pos.z) + 0.5

	var enemy: CharacterBody3D = CharacterBody3D.new()
	enemy.set_script(enemy_script)
	enemy.position = pos
	_creatures_container.add_child(enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_creature_died)

# --- Macrophage Queen Boss Spawning ---
func _spawn_macrophage_queen() -> void:
	if _queen_spawned or not _cave_gen:
		return
	# Find the Brain biome hub (biome index 6)
	var brain_hub = null
	for hub in _cave_gen.hubs:
		if hub.is_active and hub.biome == 6:  # BRAIN
			brain_hub = hub
			break
	if not brain_hub:
		return

	var queen_script = load("res://scripts/snake_stage/macrophage_queen.gd")
	_queen = CharacterBody3D.new()
	_queen.set_script(queen_script)

	# Place queen at center of brain hub
	var queen_pos: Vector3 = brain_hub.position
	if brain_hub.node_3d and brain_hub.node_3d.has_method("get_floor_y"):
		queen_pos.y = brain_hub.node_3d.get_floor_y(queen_pos.x, queen_pos.z) + 0.5
	else:
		queen_pos.y += 0.5
	_queen.position = queen_pos
	_creatures_container.add_child(_queen)
	_queen_spawned = true

	if _queen.has_signal("died"):
		_queen.died.connect(_on_creature_died)
	if _queen.has_signal("defeated"):
		_queen.defeated.connect(_on_queen_defeated)

func _on_queen_defeated() -> void:
	# Queen killed — progression event
	var queen_pos: Vector3 = _queen.global_position if is_instance_valid(_queen) else Vector3.ZERO
	_queen = null
	_bosses_defeated[6] = true  # BRAIN
	GameManager.mark_boss_defeated(6)
	GameManager.upgrade_sensory_from_boss()
	_spawn_trait_orb(queen_pos, "summon_minions")
	GameManager.grant_queen_visual_upgrade()
	if AudioManager.has_method("play_victory_sting"):
		AudioManager.play_victory_sting()
	_check_mirror_boss_spawn()

# --- Biome Boss Spawning ---
func _spawn_biome_bosses() -> void:
	if not _cave_gen:
		return
	# Map biome index to boss script path
	# BRAIN(6) handled by _spawn_macrophage_queen, skip here
	var boss_map: Dictionary = {
		1: "res://scripts/snake_stage/cardiac_colossus.gd",    # HEART_CHAMBER
		2: "res://scripts/snake_stage/gut_warden.gd",          # INTESTINAL_TRACT
		3: "res://scripts/snake_stage/alveolar_titan.gd",      # LUNG_TISSUE
		4: "res://scripts/snake_stage/marrow_sentinel.gd",     # BONE_MARROW
	}
	for biome_idx in boss_map:
		if _bosses_defeated.get(biome_idx, false):
			continue  # Already defeated
		var hub = null
		for h in _cave_gen.hubs:
			if h.biome == biome_idx:
				hub = h
				break
		if not hub:
			continue
		var boss_script = load(boss_map[biome_idx])
		if not boss_script:
			continue
		var boss: CharacterBody3D = CharacterBody3D.new()
		boss.set_script(boss_script)
		# Place at hub center
		var boss_pos: Vector3 = hub.position
		if hub.node_3d and hub.node_3d.has_method("get_floor_y"):
			boss_pos.y = hub.node_3d.get_floor_y(boss_pos.x, boss_pos.z) + 0.5
		else:
			boss_pos.y += 0.5
		boss.position = boss_pos
		_creatures_container.add_child(boss)
		_biome_bosses[biome_idx] = boss
		if boss.has_signal("died"):
			boss.died.connect(_on_creature_died)
		if boss.has_signal("defeated"):
			var idx: int = biome_idx
			boss.defeated.connect(func(): _on_biome_boss_defeated(idx))

func _on_biome_boss_defeated(biome_idx: int) -> void:
	var boss = _biome_bosses.get(biome_idx)
	var boss_pos: Vector3 = boss.global_position if is_instance_valid(boss) else Vector3.ZERO
	_bosses_defeated[biome_idx] = true
	_biome_bosses.erase(biome_idx)
	GameManager.mark_boss_defeated(biome_idx)
	GameManager.upgrade_sensory_from_boss()
	# Drop trait orb
	var trait_id: String = BIOME_TRAIT_MAP.get(biome_idx, "")
	if trait_id != "":
		_spawn_trait_orb(boss_pos, trait_id)
	if AudioManager.has_method("play_victory_sting"):
		AudioManager.play_victory_sting()
	_check_mirror_boss_spawn()

# --- Combat VFX ---
var _bite_flash_alpha: float = 0.0
var _bite_flash_overlay: ColorRect = null
var _stun_sphere: MeshInstance3D = null
var _stun_sphere_tween: Tween = null

func _on_player_bite() -> void:
	# Venom is applied in do_bite_damage() (called during bite snap tween)
	# White screen flash
	_bite_flash_alpha = 0.4
	if not _bite_flash_overlay:
		_bite_flash_overlay = ColorRect.new()
		_bite_flash_overlay.color = Color(1, 1, 1, 0.4)
		_bite_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bite_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hud: Node = get_node_or_null("HUD")
		if hud:
			hud.add_child(_bite_flash_overlay)
	if _bite_flash_overlay:
		_bite_flash_overlay.visible = true
		_bite_flash_overlay.color.a = 0.4
	# Camera shake on bite
	if _camera and _camera.has_method("add_shake"):
		_camera.add_shake(0.3)
	# Sound
	if AudioManager and AudioManager.has_method("play_bite_snap"):
		AudioManager.play_bite_snap()

func _on_player_stun_burst() -> void:
	if not _player:
		return
	# Expanding sphere VFX
	if _stun_sphere_tween and _stun_sphere_tween.is_valid():
		_stun_sphere_tween.kill()
	if _stun_sphere:
		_stun_sphere.queue_free()

	_stun_sphere = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	_stun_sphere.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.6, 1.0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.5, 1.0) * 0.5
	mat.emission_energy_multiplier = 1.5
	_stun_sphere.material_override = mat
	_stun_sphere.global_position = _player.global_position + Vector3(0, 0.5, 0)
	_stun_sphere.scale = Vector3(0.5, 0.5, 0.5)
	add_child(_stun_sphere)

	_stun_sphere_tween = create_tween()
	_stun_sphere_tween.tween_property(_stun_sphere, "scale", Vector3(8.0, 8.0, 8.0), 0.4).set_ease(Tween.EASE_OUT)
	_stun_sphere_tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4)
	_stun_sphere_tween.tween_callback(func():
		if _stun_sphere:
			_stun_sphere.queue_free()
			_stun_sphere = null
	)

	# Stun all WBCs in radius
	for wbc in get_tree().get_nodes_in_group("white_blood_cell"):
		if wbc.global_position.distance_to(_player.global_position) < 8.0:
			if wbc.has_method("stun"):
				wbc.stun()

	# Sound
	if AudioManager and AudioManager.has_method("play_stun_burst"):
		AudioManager.play_stun_burst()

func _on_player_tail_whip() -> void:
	if not _player:
		return
	# Expanding ring VFX at tail position
	var tail_pos: Vector3 = _player.global_position
	if _player._body_sections.size() > 0:
		tail_pos = _player._body_sections[-1].global_position

	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = _create_ring_mesh()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.8, 0.3, 0.1, 0.6)
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	ring.global_position = tail_pos
	ring.scale = Vector3(0.5, 1.0, 0.5)
	add_child(ring)

	var tween: Tween = create_tween()
	tween.tween_property(ring, "scale", Vector3(6.0, 1.0, 6.0), 0.4).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)

	# Camera shake
	if _camera and _camera.has_method("add_shake"):
		_camera.add_shake(0.6)

	# Sound
	if AudioManager.has_method("play_stun_burst"):
		AudioManager.play_stun_burst()

func _update_stun_vfx(_delta: float) -> void:
	pass  # Tween handles the animation

func _update_bite_flash(delta: float) -> void:
	if _bite_flash_alpha > 0:
		_bite_flash_alpha = maxf(_bite_flash_alpha - delta * 4.0, 0.0)
		if _bite_flash_overlay:
			_bite_flash_overlay.color.a = _bite_flash_alpha
			if _bite_flash_alpha <= 0.01:
				_bite_flash_overlay.visible = false

# --- Sonar heightmap pointcloud system (Moondust-style) ---
# Points rain down from above, height-coded blue→green→yellow, expanding ring reveal

const SONAR_SHADER_CODE: String = """
shader_type spatial;
render_mode blend_add, cull_disabled, shadows_disabled, unshaded, depth_draw_never;

void vertex() {
	// Extract per-instance scale for rain stretching
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);

	// Apply scale to vertex
	VERTEX.x *= sx;
	VERTEX.y *= sy;
	VERTEX.z *= sx;

	// Billboard: face camera, keep instance world position
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
}

void fragment() {
	// Disc shape from quad UV
	vec2 uv = UV - 0.5;
	float r = length(uv);
	float disc = 1.0 - smoothstep(0.35, 0.5, r);

	// COLOR from MultiMesh instance color (height-based + alpha for fade)
	ALBEDO = COLOR.rgb * 3.5;
	ALPHA = COLOR.a * disc;
	if (ALPHA < 0.01) discard;
}
"""

func _setup_sonar() -> void:
	# --- MultiMesh pointcloud ---
	_sonar_multimesh = MultiMeshInstance3D.new()
	_sonar_multimesh.name = "SonarPointcloud"
	_sonar_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_sonar_mm = MultiMesh.new()
	_sonar_mm.transform_format = MultiMesh.TRANSFORM_3D
	_sonar_mm.use_colors = true
	_sonar_mm.instance_count = SONAR_POINT_COUNT

	# Base mesh: pixel-sized quad for billboard shader
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	_sonar_mm.mesh = quad

	# Shader material for additive glow + billboard + disc shape
	var shader: Shader = Shader.new()
	shader.code = SONAR_SHADER_CODE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	_sonar_multimesh.material_override = mat

	# Initialize all instances hidden (zero scale, far away)
	var hidden_xform: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -9999, 0))
	var hidden_color: Color = Color(0, 0, 0, 0)
	for i in range(SONAR_POINT_COUNT):
		_sonar_mm.set_instance_transform(i, hidden_xform)
		_sonar_mm.set_instance_color(i, hidden_color)

	_sonar_multimesh.multimesh = _sonar_mm
	add_child(_sonar_multimesh)

	# Initialize point data array
	for i in range(SONAR_POINT_COUNT):
		_sonar_points.append({
			"target_pos": Vector3.ZERO,
			"active": false,
			"life": 0.0,
			"rain_t": 1.0,
			"dist": 0.0,
			"color": Color.WHITE,
			"rand_delay": 0.0,
		})

	# --- Expanding ring mesh ---
	_sonar_ring = MeshInstance3D.new()
	_sonar_ring.name = "SonarRing"
	_sonar_ring.mesh = _create_ring_mesh()
	_sonar_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sonar_ring_mat = StandardMaterial3D.new()
	_sonar_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sonar_ring_mat.albedo_color = Color(0.15, 0.5, 0.35)
	_sonar_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_sonar_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sonar_ring_mat.render_priority = 1
	_sonar_ring.material_override = _sonar_ring_mat
	_sonar_ring.visible = false
	add_child(_sonar_ring)

	_sonar_ready = true

func _create_ring_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 64
	var inner_r: float = 0.97
	var outer_r: float = 1.0
	for i in range(segments):
		var a0: float = TAU * float(i) / segments
		var a1: float = TAU * float(i + 1) / segments
		var i0: Vector3 = Vector3(cos(a0) * inner_r, 0, sin(a0) * inner_r)
		var i1: Vector3 = Vector3(cos(a1) * inner_r, 0, sin(a1) * inner_r)
		var o0: Vector3 = Vector3(cos(a0) * outer_r, 0, sin(a0) * outer_r)
		var o1: Vector3 = Vector3(cos(a1) * outer_r, 0, sin(a1) * outer_r)
		st.set_normal(Vector3.UP)
		st.add_vertex(i0)
		st.add_vertex(o0)
		st.add_vertex(i1)
		st.set_normal(Vector3.UP)
		st.add_vertex(i1)
		st.add_vertex(o0)
		st.add_vertex(o1)
	return st.commit()

func _trigger_sonar_pulse() -> void:
	if not _player or not _sonar_ready:
		return
	_sonar_pulse_active = true
	_sonar_pulse_radius = 0.0
	_sonar_pulse_origin = _player.global_position + Vector3(0, 0.5, 0)
	_sonar_pending_hits.clear()
	_sonar_next_free = 0
	_cast_all_sonar_rays()
	if AudioManager.has_method("play_sonar_ping"):
		AudioManager.play_sonar_ping()
	# Show ring at pulse origin
	if _sonar_ring:
		_sonar_ring.global_position = _sonar_pulse_origin
		_sonar_ring.scale = Vector3(0.1, 1.0, 0.1)
		_sonar_ring.visible = true

func _get_tunnel_mouth_positions() -> Array[Vector3]:
	## Collect tunnel mouth positions at wall boundaries for sonar highlighting
	var positions: Array[Vector3] = []
	if not _cave_gen or not _cave_gen.tunnels:
		return positions
	for tunnel in _cave_gen.tunnels:
		if tunnel.path.size() < 2:
			continue
		var hub_a = _cave_gen.hubs[tunnel.hub_a]
		var hub_b = _cave_gen.hubs[tunnel.hub_b]
		# Compute wall intersection for hub A
		var dir_ab: Vector3 = hub_b.position - hub_a.position
		dir_ab.y = 0
		if dir_ab.length() > 0.1:
			dir_ab = dir_ab.normalized()
			var wall_a: Vector3 = hub_a.position + dir_ab * hub_a.radius * 0.95
			wall_a.y = hub_a.position.y
			positions.append(wall_a)
		# Compute wall intersection for hub B
		var dir_ba: Vector3 = hub_a.position - hub_b.position
		dir_ba.y = 0
		if dir_ba.length() > 0.1:
			dir_ba = dir_ba.normalized()
			var wall_b: Vector3 = hub_b.position + dir_ba * hub_b.radius * 0.95
			wall_b.y = hub_b.position.y
			positions.append(wall_b)
	return positions

func _is_near_tunnel_mouth(pos: Vector3, tunnel_mouths: Array[Vector3]) -> bool:
	for mouth_pos in tunnel_mouths:
		if pos.distance_to(mouth_pos) < 6.0:
			return true
	return false

const SONAR_TUNNEL_COLOR: Color = Color(0.3, 1.0, 0.9)  # Bright cyan for tunnel exits

func _cast_all_sonar_rays() -> void:
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return
	var origin: Vector3 = _sonar_pulse_origin
	var player_y: float = origin.y
	var exclude_rids: Array = []
	if _player:
		exclude_rids = [_player.get_rid()]

	var tunnel_mouths: Array[Vector3] = _get_tunnel_mouth_positions()

	# Dense ray pattern: 64 horizontal × 20 elevations = 1280 structured rays
	var h_count: int = 64
	var v_count: int = 20

	for h in range(h_count):
		var phi: float = TAU * float(h) / h_count + randf_range(-0.015, 0.015)
		for v in range(v_count):
			var elev: float = lerpf(-0.78, 0.85, float(v) / (v_count - 1)) + randf_range(-0.02, 0.02)
			var dir: Vector3 = Vector3(
				cos(phi) * cos(elev),
				sin(elev),
				sin(phi) * cos(elev)
			).normalized()

			var ray_end: Vector3 = origin + dir * SONAR_RANGE
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, ray_end)
			query.exclude = exclude_rids
			query.collide_with_areas = true  # Detect creatures with Area3D

			var result: Dictionary = space_state.intersect_ray(query)
			if result:
				var hit_pos: Vector3 = result.position
				var hit_dist: float = origin.distance_to(hit_pos)
				var col: Color = _height_color(hit_pos.y, player_y)
				# Check if we hit a creature — override color
				var creature_col: Color = _get_sonar_color_for_collider(result.collider)
				if creature_col.a > 0:
					col = creature_col
				elif _is_near_tunnel_mouth(hit_pos, tunnel_mouths):
					col = SONAR_TUNNEL_COLOR
				_sonar_pending_hits.append({
					"position": hit_pos,
					"distance": hit_dist,
					"color": col,
				})

	# Additional 200 random-direction rays for gap filling
	for _r in range(200):
		var phi: float = randf() * TAU
		var elev: float = randf_range(-0.8, 0.85)
		var dir: Vector3 = Vector3(
			cos(phi) * cos(elev),
			sin(elev),
			sin(phi) * cos(elev)
		).normalized()
		var ray_end: Vector3 = origin + dir * SONAR_RANGE
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, ray_end)
		query.exclude = exclude_rids
		query.collide_with_areas = true
		var result: Dictionary = space_state.intersect_ray(query)
		if result:
			var hit_pos: Vector3 = result.position
			var hit_dist: float = origin.distance_to(hit_pos)
			var col: Color = _height_color(hit_pos.y, player_y)
			var creature_col: Color = _get_sonar_color_for_collider(result.collider)
			if creature_col.a > 0:
				col = creature_col
			elif _is_near_tunnel_mouth(hit_pos, tunnel_mouths):
				col = SONAR_TUNNEL_COLOR
			_sonar_pending_hits.append({
				"position": hit_pos,
				"distance": hit_dist,
				"color": col,
			})

	# Targeted rays aimed at nearby tunnel mouths (guaranteed visibility)
	for mouth_pos in tunnel_mouths:
		var mouth_dist: float = origin.distance_to(mouth_pos)
		if mouth_dist > SONAR_RANGE or mouth_dist < 0.5:
			continue
		for _t in range(4):
			var jitter: Vector3 = Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 1.0), randf_range(-1.5, 1.5))
			var target: Vector3 = mouth_pos + jitter
			var dir: Vector3 = (target - origin).normalized()
			var ray_end: Vector3 = origin + dir * SONAR_RANGE
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, ray_end)
			query.exclude = exclude_rids
			var result: Dictionary = space_state.intersect_ray(query)
			if result:
				var hit_pos: Vector3 = result.position
				var hit_dist: float = origin.distance_to(hit_pos)
				_sonar_pending_hits.append({
					"position": hit_pos,
					"distance": hit_dist,
					"color": SONAR_TUNNEL_COLOR,
				})

func _height_color(world_y: float, player_y: float) -> Color:
	# Normalize relative height: -10 to +10 maps to 0..1
	var rel_y: float = world_y - player_y
	var t: float = clampf((rel_y + 10.0) / 20.0, 0.0, 1.0)
	var col_low: Color = Color(0.0, 0.4, 1.0)    # Blue (floor/below)
	var col_mid: Color = Color(0.0, 0.9, 0.4)    # Green (level)
	var col_high: Color = Color(0.9, 0.85, 0.15)  # Yellow (ceiling/above)
	if t < 0.5:
		return col_low.lerp(col_mid, t * 2.0)
	else:
		return col_mid.lerp(col_high, (t - 0.5) * 2.0)

const SONAR_COLOR_AGGRESSIVE: Color = Color(1.0, 0.15, 0.1)  # Red — hostile
const SONAR_COLOR_ALERT: Color = Color(1.0, 0.8, 0.1)        # Yellow — alert range
const SONAR_COLOR_PASSIVE: Color = Color(0.1, 1.0, 0.3)      # Green — food/passive

func _get_sonar_color_for_collider(collider: Node) -> Color:
	## Returns creature outline color based on threat. Alpha=0 means not a creature.
	if not collider:
		return Color(0, 0, 0, 0)
	# Walk up parent chain to find group membership
	var node: Node = collider
	for _i in range(5):
		if not node:
			break
		# Aggressive enemies — red
		if node.is_in_group("white_blood_cell") or node.is_in_group("phagocyte") or \
		   node.is_in_group("killer_t_cell") or node.is_in_group("mast_cell") or \
		   node.is_in_group("flyer") or node.is_in_group("boss"):
			return SONAR_COLOR_AGGRESSIVE
		# Passive/food — green
		if node.is_in_group("prey") or node.is_in_group("nutrient") or \
		   node.is_in_group("ambient_life"):
			return SONAR_COLOR_PASSIVE
		node = node.get_parent()
	return Color(0, 0, 0, 0)  # Not a creature — use terrain color

func _update_sonar(delta: float) -> void:
	if not _sonar_ready:
		return

	var hidden_xform: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -9999, 0))

	# Update all active points
	for i in range(SONAR_POINT_COUNT):
		var pt = _sonar_points[i]
		if not pt.active:
			continue

		# Snap-to-place animation (subtle drop)
		if pt.rain_t < 1.0:
			pt.rain_t = minf(pt.rain_t + delta / SONAR_RAIN_DURATION, 1.0)
			var eased: float = 1.0 - pow(1.0 - pt.rain_t, 3.0)
			var y_offset: float = SONAR_RAIN_HEIGHT * (1.0 - eased)
			var current_pos: Vector3 = pt.target_pos + Vector3(0, y_offset, 0)

			# Subtle vertical stretch during drop
			var stretch_blend: float = clampf(pt.rain_t / 0.5, 0.0, 1.0)
			var y_scale: float = lerpf(1.5, 1.0, stretch_blend)
			var basis: Basis = Basis.IDENTITY.scaled(Vector3(1.0, y_scale, 1.0))
			_sonar_mm.set_instance_transform(i, Transform3D(basis, current_pos))

			# Quick fade in + color snap to height color
			var rain_alpha: float = eased
			var color_blend: float = clampf(pt.rain_t / 0.3, 0.0, 1.0)
			var display_col: Color = Color(0.4, 0.9, 0.8).lerp(pt.color, color_blend)
			display_col.a = rain_alpha
			_sonar_mm.set_instance_color(i, display_col)
		else:
			# Landed: fade out over time
			pt.life -= delta
			if pt.life <= 0:
				pt.active = false
				_sonar_mm.set_instance_transform(i, hidden_xform)
				_sonar_mm.set_instance_color(i, Color(0, 0, 0, 0))
				continue

			var fade: float = pt.life / SONAR_FADE_TIME
			fade = fade * fade  # Quadratic smooth fade
			var col: Color = pt.color
			col.a = fade
			_sonar_mm.set_instance_color(i, col)

	# Expand pulse ring and reveal pending hits progressively
	if _sonar_pulse_active:
		_sonar_pulse_radius += SONAR_EXPAND_SPEED * delta

		# Reveal hits that the pulse ring has reached
		var remaining: Array = []
		for hit in _sonar_pending_hits:
			if hit.distance <= _sonar_pulse_radius:
				_place_sonar_point(hit.position, hit.color, hit.distance)
			else:
				remaining.append(hit)
		_sonar_pending_hits = remaining

		# Update ring visual
		if _sonar_ring:
			_sonar_ring.scale = Vector3(_sonar_pulse_radius, 1.0, _sonar_pulse_radius)
			# Fade ring as it expands
			var ring_alpha: float = clampf(1.0 - _sonar_pulse_radius / SONAR_RANGE, 0.0, 1.0)
			_sonar_ring_mat.albedo_color = Color(0.15, 0.5, 0.35) * (0.3 + ring_alpha * 0.4)

		if _sonar_pulse_radius >= SONAR_RANGE:
			_sonar_pulse_active = false
			_sonar_pending_hits.clear()
			if _sonar_ring:
				_sonar_ring.visible = false

func _place_sonar_point(pos: Vector3, col: Color, dist: float = 0.0) -> void:
	# Distance LOD: skip some far points for sparser coverage
	var dist_ratio: float = clampf(dist / SONAR_RANGE, 0.0, 1.0)
	if dist_ratio > 0.6 and randf() < 0.4:
		return  # Skip 40% of points beyond 60% range

	# Fast search: start from _sonar_next_free
	for _j in range(SONAR_POINT_COUNT):
		var i: int = (_sonar_next_free + _j) % SONAR_POINT_COUNT
		if not _sonar_points[i].active:
			_activate_sonar_point(i, pos, col, dist_ratio)
			_sonar_next_free = (i + 1) % SONAR_POINT_COUNT
			return

	# All full: recycle oldest (lowest life)
	var oldest_idx: int = 0
	var oldest_life: float = INF
	for i in range(SONAR_POINT_COUNT):
		if _sonar_points[i].life < oldest_life:
			oldest_life = _sonar_points[i].life
			oldest_idx = i
	_activate_sonar_point(oldest_idx, pos, col, dist_ratio)

func _activate_sonar_point(idx: int, pos: Vector3, col: Color, dist_ratio: float = 0.0) -> void:
	var pt = _sonar_points[idx]
	pt.target_pos = pos
	pt.active = true
	# Distance LOD: far points fade faster and are smaller
	var life_scale: float = lerpf(1.0, 0.5, dist_ratio * dist_ratio)
	var size_scale: float = lerpf(1.0, 0.4, dist_ratio * dist_ratio)
	pt.life = SONAR_FADE_TIME * life_scale
	pt.rain_t = 0.0
	pt.color = col
	pt.rand_delay = randf() * 0.12

	# Start position: slightly above target (subtle drop)
	var start_pos: Vector3 = pos + Vector3(0, SONAR_RAIN_HEIGHT, 0)
	var basis: Basis = Basis.IDENTITY.scaled(Vector3(size_scale, 1.5 * size_scale, size_scale))
	_sonar_mm.set_instance_transform(idx, Transform3D(basis, start_pos))
	_sonar_mm.set_instance_color(idx, Color(0.4, 0.9, 0.8, 0.0))

func _cast_passive_sonar() -> void:
	## Continuous close-range terrain mapping — keeps floor/walls visible near player
	if not _player or not _sonar_ready:
		return
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return
	var origin: Vector3 = _player.global_position + Vector3(0, 0.5, 0)
	var player_y: float = origin.y
	var exclude_rids: Array = [_player.get_rid()]

	# Cast rays in a hemisphere around the player (mostly downward for floor mapping)
	for _r in range(PASSIVE_SONAR_RAYS):
		var phi: float = randf() * TAU
		var elev: float = randf_range(-0.9, 0.5)  # Bias toward floor
		var dir: Vector3 = Vector3(
			cos(phi) * cos(elev),
			sin(elev),
			sin(phi) * cos(elev)
		).normalized()
		var ray_end: Vector3 = origin + dir * PASSIVE_SONAR_RANGE
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, ray_end)
		query.exclude = exclude_rids
		var result: Dictionary = space_state.intersect_ray(query)
		if result:
			var hit_pos: Vector3 = result.position
			var hit_dist: float = origin.distance_to(hit_pos)
			var col: Color = _height_color(hit_pos.y, player_y)
			# Dim passive points slightly vs active sonar pulse
			col = col.darkened(0.15)
			var dist_ratio: float = clampf(hit_dist / PASSIVE_SONAR_RANGE, 0.0, 1.0)
			_place_sonar_point(hit_pos, col, hit_dist)

# --- Death VFX: blood particle burst + nutrient drops ---

func _spawn_blood_burst(pos: Vector3) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.global_position = pos

	var proc_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc_mat.emission_sphere_radius = 0.3
	proc_mat.direction = Vector3(0, 1, 0)
	proc_mat.spread = 180.0
	proc_mat.initial_velocity_min = 3.0
	proc_mat.initial_velocity_max = 8.0
	proc_mat.gravity = Vector3(0, -6.0, 0)
	proc_mat.scale_min = 0.5
	proc_mat.scale_max = 1.5
	proc_mat.color = Color(0.8, 0.1, 0.05, 0.9)
	particles.process_material = proc_mat

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	particles.draw_pass_1 = quad

	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.albedo_color = Color(0.9, 0.15, 0.05, 0.9)
	draw_mat.emission_enabled = true
	draw_mat.emission = Color(0.9, 0.2, 0.05)
	draw_mat.emission_energy_multiplier = 3.0
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = draw_mat
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(particles)
	# Auto-free after particles expire
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

func _spawn_death_drops(pos: Vector3, count: int = 3) -> void:
	for i in range(count):
		var nutrient: Node3D = _create_nutrient()
		var offset: Vector3 = Vector3(randf_range(-1.5, 1.5), 0.5, randf_range(-1.5, 1.5))
		nutrient.position = pos + offset
		_nutrients_container.add_child(nutrient)

func _on_creature_died(pos: Vector3) -> void:
	_spawn_blood_burst(pos)
	_spawn_death_drops(pos, randi_range(2, 4))
	# Camera shake on kill
	if _camera and _camera.has_method("add_shake"):
		_camera.add_shake(0.5)

# --- Brain hallucination flicker ---
func _update_hallucination(delta: float) -> void:
	if not _player or not _cave_gen:
		return
	# Check if player is in BRAIN biome
	var hub = _cave_gen.get_hub_at_position(_player.global_position)
	if not hub or hub.biome != 6:  # 6 = BRAIN
		if _hallucination_overlay and _hallucination_overlay.visible:
			_hallucination_overlay.visible = false
		return

	# 5% chance per second (check each frame scaled by delta)
	_hallucination_timer += delta
	if _hallucination_timer >= 1.0:
		_hallucination_timer = 0.0
		if randf() < 0.05:
			_trigger_hallucination_flash()

	# Fade out overlay
	if _hallucination_overlay and _hallucination_overlay.visible:
		_hallucination_overlay.color.a -= delta * 10.0
		if _hallucination_overlay.color.a <= 0.01:
			_hallucination_overlay.visible = false

func _trigger_hallucination_flash() -> void:
	if not _hallucination_overlay:
		_hallucination_overlay = ColorRect.new()
		_hallucination_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hallucination_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hud: Node = get_node_or_null("HUD")
		if hud:
			hud.add_child(_hallucination_overlay)
	if _hallucination_overlay:
		# Purple-tinted flash
		_hallucination_overlay.color = Color(0.4, 0.1, 0.5, 0.25)
		_hallucination_overlay.visible = true

# --- Pause menu functions ---
func _pause() -> void:
	_paused = true
	get_tree().paused = true
	_pause_menu.visible = true
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.play_ui_open()

func _unpause() -> void:
	_paused = false
	get_tree().paused = false
	_pause_menu.visible = false

func _quit_to_menu() -> void:
	_paused = false
	get_tree().paused = false
	GameManager.go_to_menu()

# --- Danger Proximity Indicator: scan for nearest threat ---
func _refresh_enemy_cache() -> void:
	## Build a cached list of all enemies with distances to player. Called once per frame max.
	var frame: int = Engine.get_process_frames()
	if frame == _enemy_cache_frame:
		return
	_enemy_cache_frame = frame
	_cached_enemies.clear()
	if not _player:
		return
	var ppos: Vector3 = _player.global_position
	for group_name in ENEMY_GROUPS:
		for creature in get_tree().get_nodes_in_group(group_name):
			var dist: float = ppos.distance_to(creature.global_position)
			_cached_enemies.append({"node": creature, "dist": dist})

func _scan_nearest_threat() -> void:
	if not _player:
		_nearest_threat_dist = INF
		_nearest_threat_dir = Vector3.ZERO
		return
	_refresh_enemy_cache()
	var best_dist: float = INF
	var best_dir: Vector3 = Vector3.ZERO
	for entry in _cached_enemies:
		var dist: float = entry.dist
		if dist < THREAT_DETECT_RANGE and dist < best_dist:
			best_dist = dist
			best_dir = (entry.node.global_position - _player.global_position).normalized()
	_nearest_threat_dist = best_dist
	_nearest_threat_dir = best_dir
	# Feed into vitals HUD for danger indicator drawing
	if _vitals_hud and best_dist < THREAT_DETECT_RANGE:
		_vitals_hud.set_meta(META_THREAT_DIR, best_dir)
		_vitals_hud.set_meta(META_THREAT_DIST, best_dist)
		_vitals_hud.set_meta(META_THREAT_RANGE, THREAT_DETECT_RANGE)
	elif _vitals_hud:
		_vitals_hud.set_meta(META_THREAT_DIST, INF)

# --- Venom Tick: apply DoT to all venomed creatures ---
func _tick_venom_damage() -> void:
	for group_name in ["white_blood_cell", "prey", "flyer", "phagocyte", "killer_t_cell", "mast_cell", "boss"]:
		for creature in get_tree().get_nodes_in_group(group_name):
			if not creature.has_meta(META_VENOMED) or not creature.get_meta(META_VENOMED):
				continue
			var remaining: float = creature.get_meta(META_VENOM_REMAINING, 0.0)
			var dps: float = creature.get_meta(META_VENOM_DPS, 2.0)
			if remaining <= 0:
				creature.set_meta(META_VENOMED, false)
				_restore_venom_visual(creature)
				continue
			# Apply tick damage (0.5 sec interval)
			if creature.has_method("take_damage"):
				creature.take_damage(dps * 0.5)
			creature.set_meta(META_VENOM_REMAINING, remaining - 0.5)
			# Visual: green tint on venomed enemies
			_apply_venom_visual(creature)

func _apply_venom_visual(creature: Node3D) -> void:
	# Save original emission before first venom application
	if not creature.has_meta(META_ORIGINAL_EMISSION):
		for child in creature.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				creature.set_meta(META_ORIGINAL_EMISSION, child.material_override.emission)
				break
	# Find body mesh and tint it green
	for child in creature.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = child.material_override
			mat.emission = mat.emission.lerp(Color(0.1, 0.8, 0.2), 0.1)
			break

func _restore_venom_visual(creature: Node3D) -> void:
	if not creature.has_meta(META_ORIGINAL_EMISSION):
		return
	var original: Color = creature.get_meta(META_ORIGINAL_EMISSION)
	for child in creature.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			child.material_override.emission = original
			break
	creature.remove_meta(META_ORIGINAL_EMISSION)

# --- Dynamic Combat Music State Machine ---
func _update_combat_state(delta: float) -> void:
	_combat_timer += delta
	var enemies_near: int = 0
	var enemies_close: int = 0
	if _player:
		_refresh_enemy_cache()
		for entry in _cached_enemies:
			if entry.dist < ALERT_RANGE:
				enemies_near += 1
			if entry.dist < 15.0:
				enemies_close += 1

	var prev_state: CombatState = _combat_state
	match _combat_state:
		CombatState.CALM:
			if enemies_close > 0:
				_combat_state = CombatState.COMBAT
				_combat_timer = 0.0
			elif enemies_near > 0:
				_combat_state = CombatState.ALERT
				_combat_timer = 0.0
		CombatState.ALERT:
			if enemies_close > 0:
				_combat_state = CombatState.COMBAT
				_combat_timer = 0.0
			elif enemies_near == 0 and _combat_timer > 3.0:
				_combat_state = CombatState.CALM
		CombatState.COMBAT:
			if enemies_close == 0 and enemies_near == 0:
				if _combat_timer > COMBAT_COOLDOWN:
					_combat_state = CombatState.VICTORY
					_combat_timer = 0.0
			else:
				_combat_timer = 0.0  # Reset cooldown while enemies present
		CombatState.VICTORY:
			if _combat_timer > 2.0:
				_combat_state = CombatState.CALM

	# Audio response to combat state changes
	if _combat_state != prev_state:
		match _combat_state:
			CombatState.ALERT:
				if AudioManager.has_method("set_combat_intensity"):
					AudioManager.set_combat_intensity(0.3)
			CombatState.COMBAT:
				if AudioManager.has_method("set_combat_intensity"):
					AudioManager.set_combat_intensity(1.0)
			CombatState.VICTORY:
				if AudioManager.has_method("play_victory_sting"):
					AudioManager.play_victory_sting()
			CombatState.CALM:
				if AudioManager.has_method("set_combat_intensity"):
					AudioManager.set_combat_intensity(0.0)

# --- Creature Discovery ---
const CREATURE_GROUP_MAP: Dictionary = {
	"white_blood_cell": "white_blood_cell",
	"flyer": "antibody_flyer",
	"prey": "prey_bug",
	"phagocyte": "phagocyte",
	"killer_t_cell": "killer_t_cell",
	"mast_cell": "mast_cell",
	"boss": "",  # Bosses have individual IDs
}

# Metadata creature_id -> codex creature_id for ambient life
const AMBIENT_ID_MAP: Dictionary = {
	"red_blood_cell": "red_blood_cell",
	"platelet": "platelet",
	"bacteria": "microbiome_bacteria",
	"cilia_plankton": "cilia_plankton",
}

func _scan_creature_discovery() -> void:
	if not _player:
		return
	# Scan combat/prey creature groups
	for group_name in CREATURE_GROUP_MAP:
		var creature_id: String = CREATURE_GROUP_MAP[group_name]
		for creature in get_tree().get_nodes_in_group(group_name):
			var dist: float = _player.global_position.distance_to(creature.global_position)
			if dist < DISCOVERY_RANGE:
				if group_name == "boss":
					# Bosses have unique IDs based on script
					var script_path: String = ""
					if creature.get_script():
						script_path = creature.get_script().resource_path
					if "macrophage_queen" in script_path:
						GameManager.discover_creature("macrophage_queen")
					elif "cardiac_colossus" in script_path:
						GameManager.discover_creature("cardiac_colossus")
					elif "gut_warden" in script_path:
						GameManager.discover_creature("gut_warden")
					elif "alveolar_titan" in script_path:
						GameManager.discover_creature("alveolar_titan")
					elif "marrow_sentinel" in script_path:
						GameManager.discover_creature("marrow_sentinel")
				elif creature_id != "":
					GameManager.discover_creature(creature_id)

	# Scan ambient life (uses "ambient_life" group + creature_id metadata)
	for creature in get_tree().get_nodes_in_group("ambient_life"):
		var dist: float = _player.global_position.distance_to(creature.global_position)
		if dist < DISCOVERY_RANGE:
			var meta_id: String = creature.get_meta("creature_id", "")
			if meta_id in AMBIENT_ID_MAP:
				GameManager.discover_creature(AMBIENT_ID_MAP[meta_id])

	# Discover nutrients when nearby
	for child in _nutrients_container.get_children():
		if child.global_position.distance_to(_player.global_position) < DISCOVERY_RANGE:
			if child.get("is_golden"):
				GameManager.discover_creature("golden_nutrient")
			else:
				GameManager.discover_creature("land_nutrient")

# --- Vision/Darkness System ---

func _get_vision_tier() -> Dictionary:
	var level: int = clampi(GameManager.sensory_level, 0, VISION_TIERS.size() - 1)
	return VISION_TIERS[level]

func _on_sensory_level_changed(new_level: int) -> void:
	_update_vision_level()

func _update_vision_level() -> void:
	var tier: Dictionary = _get_vision_tier()
	# Update fog density
	if _vision_env:
		_vision_env.fog_density = tier.fog
		_vision_env.ambient_light_energy = tier.ambient
	# Update player omni light range
	if _player_omni_light:
		_player_omni_light.omni_range = tier.light_range
	# Update ambient glow range
	if _player:
		var amb_glow: Node = _player.get_node_or_null("PlayerAmbientGlow")
		if amb_glow:
			amb_glow.omni_range = tier.light_range * 1.8
	# Update player flashlight (eye stalk spotlight)
	_update_player_flashlight()
	# Update bioluminescent lights throughout cave
	_update_biolum_brightness(tier.biolum)

func _update_player_flashlight() -> void:
	if not _player:
		return
	var tier: Dictionary = _get_vision_tier()
	if _player._eye_light:
		_player._eye_light.spot_range = tier.spot_range
		_player._eye_light_base_energy = 1.5 + tier.biolum * 2.0
	if _player._lure_light:
		_player._lure_light.omni_range = 3.0 + tier.biolum * 5.0
		_player._lure_light.light_energy = 1.5

func _update_biolum_brightness(mult: float) -> void:
	## Scale all BiolumLights in the cave to match vision tier
	if not _cave_gen:
		return
	for hub in _cave_gen.hubs:
		if not hub.is_active or not hub.node_3d:
			continue
		var biolum_container: Node = hub.node_3d.get_node_or_null("BiolumLights")
		if not biolum_container:
			continue
		for child in biolum_container.get_children():
			if child is OmniLight3D:
				child.light_energy = child.get_meta("base_energy", 0.25) * mult
			elif child is MeshInstance3D and child.material_override is StandardMaterial3D:
				var mat: StandardMaterial3D = child.material_override
				mat.emission_energy_multiplier = 2.0 * mult
				mat.albedo_color.a = clampf(mult, 0.0, 0.8)

# --- Snake Stage Evolution (vial fill → sensory upgrade) ---

var _evolution_ui = null

func _on_snake_evolution_triggered(category_key: String) -> void:
	## When a biomolecule vial fills up in snake stage, trigger evolution UI
	# Wire up the evolution UI (same as cell stage)
	if not _evolution_ui:
		var evo_script = load("res://scripts/cell_stage/evolution_ui.gd")
		if not evo_script:
			# Fallback: just consume vial and bump sensory
			GameManager.consume_vial_for_evolution(category_key)
			GameManager.upgrade_sensory_from_vial()
			return
		_evolution_ui = CanvasLayer.new()
		_evolution_ui.layer = 10
		_evolution_ui.name = "EvolutionUI"
		_evolution_ui.set_script(evo_script)
		add_child(_evolution_ui)
		# Connect evolution applied to bump sensory level
		if not GameManager.evolution_applied.is_connected(_on_snake_evolution_applied):
			GameManager.evolution_applied.connect(_on_snake_evolution_applied)
	# The evolution_ui auto-triggers from GameManager.evolution_triggered
	# which it's already connected to in its _ready()

func _on_snake_evolution_applied(_mutation: Dictionary) -> void:
	## After picking a mutation in snake stage, bump sensory level
	if GameManager.sensory_level > _last_sensory_level:
		_last_sensory_level = GameManager.sensory_level
		# Vision already updated via sensory_level_changed signal
	else:
		# Non-sensory mutation: still give a small vision bump
		GameManager.upgrade_sensory_from_vial()

# --- Boss Defeat → Trait Orb Drop ---

const BIOME_TRAIT_MAP: Dictionary = {
	1: "pulse_wave",       # HEART_CHAMBER → Cardiac Colossus
	2: "acid_spit",        # INTESTINAL_TRACT → Gut Warden
	3: "wind_gust",        # LUNG_TISSUE → Alveolar Titan
	4: "bone_shield",      # BONE_MARROW → Marrow Sentinel
	6: "summon_minions",   # BRAIN → Macrophage Queen
}

var _mirror_spawned: bool = false

func _spawn_trait_orb(pos: Vector3, trait_id: String) -> void:
	## Spawn a glowing trait orb at the boss death position
	var orb_script = load("res://scripts/snake_stage/boss_trait_orb.gd")
	if not orb_script:
		# Fallback: just unlock directly
		GameManager.unlock_trait(trait_id)
		return
	var orb: Area3D = Area3D.new()
	orb.set_script(orb_script)
	orb.trait_id = trait_id
	orb.position = pos + Vector3(0, 1.5, 0)
	_creatures_container.add_child(orb)

func _check_mirror_boss_spawn() -> void:
	## After all 5 wing bosses defeated, spawn the Mirror Parasite in the Stomach
	if _mirror_spawned:
		return
	# Check all 5 wing bosses (biomes 1-4 + 6)
	for idx in [1, 2, 3, 4, 6]:
		if not _bosses_defeated.get(idx, false):
			return
	_mirror_spawned = true
	# Find the Stomach hub (biome 0 = center hub)
	var stomach_hub = null
	for hub in _cave_gen.hubs:
		if hub.biome == 0:
			stomach_hub = hub
			break
	if not stomach_hub:
		return
	var mirror_script = load("res://scripts/snake_stage/mirror_parasite.gd")
	if not mirror_script:
		return
	var mirror: CharacterBody3D = CharacterBody3D.new()
	mirror.set_script(mirror_script)
	var mirror_pos: Vector3 = stomach_hub.position
	if stomach_hub.node_3d and stomach_hub.node_3d.has_method("get_floor_y"):
		mirror_pos.y = stomach_hub.node_3d.get_floor_y(mirror_pos.x, mirror_pos.z) + 0.5
	else:
		mirror_pos.y += 0.5
	mirror.position = mirror_pos
	mirror.set_meta("is_mirror_parasite", true)
	_creatures_container.add_child(mirror)
	if mirror.has_signal("died"):
		mirror.died.connect(_on_creature_died)
	if mirror.has_signal("defeated"):
		mirror.defeated.connect(_on_mirror_defeated)

var _ending_active: bool = false
var _ending_timer: float = 0.0
var _ending_overlay: ColorRect = null
var _ending_label: Label = null
var _ending_stats_label: Label = null

func _on_mirror_defeated() -> void:
	## Final boss defeated — game complete!
	if AudioManager.has_method("play_victory_sting"):
		AudioManager.play_victory_sting()
	_start_ending_sequence()

func _start_ending_sequence() -> void:
	_ending_active = true
	_ending_timer = 0.0
	# Slow-motion
	Engine.time_scale = 0.3

	# Full-screen overlay for fade
	_ending_overlay = ColorRect.new()
	_ending_overlay.color = Color(0, 0, 0, 0)
	_ending_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ending_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var end_layer: CanvasLayer = CanvasLayer.new()
	end_layer.layer = 20
	end_layer.name = "EndingLayer"
	add_child(end_layer)
	end_layer.add_child(_ending_overlay)

	# Victory title
	_ending_label = Label.new()
	_ending_label.text = "EVOLUTION COMPLETE"
	_ending_label.set_anchors_preset(Control.PRESET_CENTER)
	_ending_label.position = Vector2(-200, -60)
	_ending_label.add_theme_font_size_override("font_size", 40)
	_ending_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 0.0))
	_ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ending_label.custom_minimum_size = Vector2(400, 60)
	end_layer.add_child(_ending_label)

	# Stats summary
	_ending_stats_label = Label.new()
	_ending_stats_label.set_anchors_preset(Control.PRESET_CENTER)
	_ending_stats_label.position = Vector2(-200, 20)
	_ending_stats_label.add_theme_font_size_override("font_size", 16)
	_ending_stats_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.75, 0.0))
	_ending_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ending_stats_label.custom_minimum_size = Vector2(400, 200)
	var bosses_killed: int = _bosses_defeated.size()
	var traits_found: int = GameManager.unlocked_traits.size()
	var sensory: int = GameManager.sensory_level
	var fragments: int = GameManager.gene_fragments
	_ending_stats_label.text = "Bosses Defeated: %d / 6\nTraits Acquired: %d / 5\nSensory Level: %d\nGene Fragments: %d\n\nThe parasite has conquered the host.\nA new organism emerges." % [bosses_killed, traits_found, sensory, fragments]
	end_layer.add_child(_ending_stats_label)

func _update_ending_sequence(delta: float) -> void:
	if not _ending_active:
		return
	# Use unscaled delta since time_scale is low
	_ending_timer += delta / maxf(Engine.time_scale, 0.1)

	# Phase 1 (0-2s): Slow-mo holds, screen starts fading to black
	if _ending_timer < 2.0:
		var fade: float = _ending_timer / 2.0
		if _ending_overlay:
			_ending_overlay.color.a = fade * 0.7

	# Phase 2 (2-3s): Restore time scale, show title
	elif _ending_timer < 3.0:
		var unscaled_delta: float = delta / maxf(Engine.time_scale, 0.1)
		Engine.time_scale = lerpf(Engine.time_scale, 1.0, unscaled_delta * 3.0)
		if _ending_overlay:
			_ending_overlay.color.a = 0.85
		if _ending_label:
			var t: float = (_ending_timer - 2.0) / 1.0
			_ending_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, t))

	# Phase 3 (3-5s): Show stats
	elif _ending_timer < 5.0:
		Engine.time_scale = 1.0
		if _ending_overlay:
			_ending_overlay.color.a = 0.9
		if _ending_stats_label:
			var t: float = clampf((_ending_timer - 3.0) / 1.0, 0.0, 1.0)
			_ending_stats_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.75, t))

	# Phase 4 (5-8s): Hold stats, then add "Press any key" prompt
	elif _ending_timer < 8.0:
		pass  # Hold visible

	# Phase 5 (8s+): Wait for input, return to menu
	else:
		if Input.is_anything_pressed():
			_ending_active = false
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

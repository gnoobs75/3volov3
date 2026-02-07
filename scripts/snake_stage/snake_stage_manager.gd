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
const NUTRIENT_TARGET_COUNT: int = 20
const NUTRIENT_SPAWN_RADIUS: float = 50.0
const NUTRIENT_DESPAWN_RADIUS: float = 70.0

# Prey spawning
const PREY_TARGET_COUNT: int = 6
const PREY_SPAWN_RADIUS: float = 45.0
const PREY_DESPAWN_RADIUS: float = 65.0
var _prey_check_timer: float = 0.0

# White Blood Cell spawning
const WBC_TARGET_COUNT: int = 8
const WBC_SPAWN_RADIUS: float = 50.0
const WBC_DESPAWN_RADIUS: float = 70.0
var _wbc_check_timer: float = 0.0
var _wbc_container: Node3D = null

# --- HUD references ---
var _energy_bar: ProgressBar = null
var _health_bar: ProgressBar = null
var _controls_label: Label = null

func _ready() -> void:
	_setup_environment()
	_setup_player()
	_setup_camera()
	_setup_cave_system()
	_setup_containers()
	_setup_hud()

func _setup_environment() -> void:
	_environment = WorldEnvironment.new()
	var env: Environment = Environment.new()

	# Pitch black underground sky
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.005, 0.003, 0.01)
	sky_mat.sky_horizon_color = Color(0.008, 0.005, 0.012)
	sky_mat.ground_bottom_color = Color(0.002, 0.003, 0.005)
	sky_mat.ground_horizon_color = Color(0.005, 0.003, 0.008)
	sky_mat.sky_energy_multiplier = 0.05
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Near-zero ambient light (caves are DARK)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.03
	env.ambient_light_color = Color(0.02, 0.04, 0.03)

	# Dense fog for claustrophobic feel
	env.fog_enabled = true
	env.fog_light_color = Color(0.01, 0.015, 0.01)
	env.fog_density = 0.04
	env.fog_aerial_perspective = 0.8

	# Strong glow (makes emissions pop in darkness)
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# SSAO for cave depth
	env.ssao_enabled = true
	env.ssao_radius = 3.0
	env.ssao_intensity = 2.0

	_environment.environment = env
	add_child(_environment)

	# No sun underground - only local lights
	# Player heat light
	# (Added by player_worm.gd itself now)

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
	_camera.far = 200.0  # Shorter far plane for caves
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
		if _camera and _camera.has_method("snap_to_target"):
			_camera.snap_to_target()
	# Always re-enable physics (must not be inside conditional)
	_player.set_physics_process(true)

	# Initial spawns
	call_deferred("_spawn_initial_nutrients")
	call_deferred("_spawn_initial_prey")
	call_deferred("_spawn_initial_wbc")

	# Add player light for cave visibility
	_add_player_light()

	# Connect combat signals
	if _player.has_signal("bite_performed"):
		_player.bite_performed.connect(_on_player_bite)
	if _player.has_signal("stun_burst_fired"):
		_player.stun_burst_fired.connect(_on_player_stun_burst)

	# Setup sonar contour point system
	call_deferred("_setup_sonar")

func _add_player_light() -> void:
	if not _player:
		return
	# Warm bioluminescent glow on player
	var heat_light: OmniLight3D = OmniLight3D.new()
	heat_light.name = "PlayerLight"
	heat_light.light_color = Color(0.2, 0.5, 0.35)  # Green-teal
	heat_light.light_energy = 0.8
	heat_light.omni_range = 10.0
	heat_light.omni_attenuation = 1.5
	heat_light.shadow_enabled = true
	heat_light.position = Vector3(0, 0.8, 0)
	_player.add_child(heat_light)

	# Scan pulse light (periodic bright burst)
	var scan_light: OmniLight3D = OmniLight3D.new()
	scan_light.name = "ScanLight"
	scan_light.light_color = Color(0.15, 0.6, 0.3)  # Bright green scan
	scan_light.light_energy = 0.0
	scan_light.omni_range = 20.0
	scan_light.omni_attenuation = 0.8
	scan_light.shadow_enabled = false
	scan_light.position = Vector3(0, 0.8, 0)
	_player.add_child(scan_light)

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

func _setup_hud() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.layer = 5
	hud.name = "HUD"
	add_child(hud)

	# Semi-transparent top bar
	var top_bar: ColorRect = ColorRect.new()
	top_bar.color = Color(0.01, 0.02, 0.04, 0.75)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 85.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top_bar)

	# Energy label
	var energy_label: Label = Label.new()
	energy_label.text = "ENERGY"
	energy_label.position = Vector2(20, 6)
	energy_label.add_theme_font_size_override("font_size", 11)
	energy_label.add_theme_color_override("font_color", Color(0.2, 0.7, 0.5, 0.8))
	hud.add_child(energy_label)

	# Energy bar
	_energy_bar = ProgressBar.new()
	_energy_bar.position = Vector2(20, 22)
	_energy_bar.size = Vector2(200, 16)
	_energy_bar.value = 100
	_energy_bar.show_percentage = false
	hud.add_child(_energy_bar)

	# Health label
	var health_label: Label = Label.new()
	health_label.text = "HEALTH"
	health_label.position = Vector2(20, 40)
	health_label.add_theme_font_size_override("font_size", 11)
	health_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 0.8))
	hud.add_child(health_label)

	# Health bar
	_health_bar = ProgressBar.new()
	_health_bar.position = Vector2(20, 56)
	_health_bar.size = Vector2(200, 16)
	_health_bar.value = 100
	_health_bar.show_percentage = false
	hud.add_child(_health_bar)

	# Controls label
	_controls_label = Label.new()
	_controls_label.text = "WASD: Move | Shift: Sprint | Space: Creep | LMB: Bite | E: Stun | ESC: Menu"
	_controls_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_controls_label.position = Vector2(20, -30)
	_controls_label.add_theme_font_size_override("font_size", 12)
	_controls_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.4, 0.5))
	hud.add_child(_controls_label)

	# Stage title
	var title: Label = Label.new()
	title.text = "PARASITE MODE - Inside the Host"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-140, 8)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.3, 0.6, 0.5, 0.7))
	hud.add_child(title)

	# Depth indicator
	var depth_label: Label = Label.new()
	depth_label.name = "DepthLabel"
	depth_label.text = "DEPTH: 10m"
	depth_label.position = Vector2(240, 6)
	depth_label.add_theme_font_size_override("font_size", 11)
	depth_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.8, 0.7))
	hud.add_child(depth_label)

	# DNA helix HUD panel (right side of screen)
	var helix_panel: PanelContainer = PanelContainer.new()
	helix_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	helix_panel.offset_left = -180.0
	helix_panel.offset_top = 10.0
	helix_panel.offset_bottom = -10.0
	helix_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.025, 0.04, 0.6)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.12, 0.25, 0.35, 0.4)
	helix_panel.add_theme_stylebox_override("panel", panel_style)
	hud.add_child(helix_panel)

	# Load and add the DNA helix HUD control
	var helix_script = load("res://scripts/cell_stage/test_tube_hud.gd")
	var helix_hud: Control = Control.new()
	helix_hud.set_script(helix_script)
	helix_hud.name = "HelixHUD"
	helix_hud.custom_minimum_size = Vector2(160, 400)
	helix_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	helix_hud.size_flags_vertical = Control.SIZE_EXPAND_FILL
	helix_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	helix_panel.add_child(helix_hud)

# --- Scan pulse timer ---
var _scan_timer: float = 0.0
var _scan_intensity: float = 0.0
const SCAN_INTERVAL: float = 3.5
const SCAN_DURATION: float = 1.5

# --- Sonar heightmap pointcloud system (Moondust-style) ---
const SONAR_POINT_COUNT: int = 5000
const SONAR_RANGE: float = 35.0
const SONAR_FADE_TIME: float = 8.0
const SONAR_EXPAND_SPEED: float = 18.0  # units/sec ring expansion
const SONAR_RAIN_HEIGHT: float = 2.5  # subtle drop into position
const SONAR_RAIN_DURATION: float = 0.12  # quick snap-to-place
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
	_update_hud()
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

	# Update stun burst VFX
	_update_stun_vfx(delta)

	# Update bite flash VFX
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

	# Ambient cave sounds
	_drip_timer += delta
	if _drip_timer > randf_range(2.0, 6.0):
		_drip_timer = 0.0
		if AudioManager.has_method("play_cave_drip"):
			AudioManager.play_cave_drip()

func _update_hud() -> void:
	if _player and _energy_bar:
		_energy_bar.value = (_player.energy / _player.max_energy) * 100.0
	if _player and _health_bar:
		_health_bar.value = (_player.health / _player.max_health) * 100.0
	# Update depth label
	if _player:
		var depth_label: Label = get_node_or_null("HUD/DepthLabel")
		if depth_label:
			var depth: float = absf(_player.global_position.y)
			depth_label.text = "DEPTH: %dm" % int(depth)

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
	if not _player:
		return
	var nutrient: Node3D = _create_nutrient()
	# Random position around player on cave floor
	var angle: float = randf() * TAU
	var dist: float = randf_range(10.0, NUTRIENT_SPAWN_RADIUS)
	var x: float = _player.global_position.x + cos(angle) * dist
	var z: float = _player.global_position.z + sin(angle) * dist
	# Approximate floor Y: use player Y - small offset (gravity will settle it)
	var y: float = _player.global_position.y + randf_range(-2.0, 1.0)

	# Try to get floor Y from cave system
	if _cave_gen and _cave_gen.has_method("get_floor_y_at"):
		y = _cave_gen.get_floor_y_at(Vector3(x, _player.global_position.y, z)) + 0.8

	nutrient.position = Vector3(x, y, z)
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
	if not _player:
		return
	var bug_script = load("res://scripts/snake_stage/prey_bug.gd")
	var bug: CharacterBody3D = CharacterBody3D.new()
	bug.set_script(bug_script)

	var angle: float = randf() * TAU
	var dist: float = randf_range(12.0, PREY_SPAWN_RADIUS)
	var x: float = _player.global_position.x + cos(angle) * dist
	var z: float = _player.global_position.z + sin(angle) * dist
	var y: float = _player.global_position.y + 1.0

	if _cave_gen and _cave_gen.has_method("get_floor_y_at"):
		y = _cave_gen.get_floor_y_at(Vector3(x, _player.global_position.y, z)) + 0.5

	bug.position = Vector3(x, y, z)
	_creatures_container.add_child(bug)
	# No terrain ref needed - bugs use gravity + collision

func _on_player_damaged(_amount: float) -> void:
	pass  # Future: screen shake, observer notes

func _on_player_died() -> void:
	pass  # Future: death recap, respawn at last hub

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
	if not _player or not _wbc_container:
		return
	var wbc_script = load("res://scripts/snake_stage/white_blood_cell.gd")
	var wbc: CharacterBody3D = CharacterBody3D.new()
	wbc.set_script(wbc_script)

	var angle: float = randf() * TAU
	var dist: float = randf_range(15.0, WBC_SPAWN_RADIUS)
	var x: float = _player.global_position.x + cos(angle) * dist
	var z: float = _player.global_position.z + sin(angle) * dist
	var y: float = _player.global_position.y + 1.0

	if _cave_gen and _cave_gen.has_method("get_floor_y_at"):
		y = _cave_gen.get_floor_y_at(Vector3(x, _player.global_position.y, z)) + 0.5

	wbc.position = Vector3(x, y, z)
	_wbc_container.add_child(wbc)

# --- Combat VFX ---
var _bite_flash_alpha: float = 0.0
var _bite_flash_overlay: ColorRect = null
var _stun_sphere: MeshInstance3D = null
var _stun_sphere_tween: Tween = null

func _on_player_bite() -> void:
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

			var result: Dictionary = space_state.intersect_ray(query)
			if result:
				var hit_pos: Vector3 = result.position
				var hit_dist: float = origin.distance_to(hit_pos)
				var col: Color = _height_color(hit_pos.y, player_y)
				# Override color to bright cyan near tunnel mouths
				if _is_near_tunnel_mouth(hit_pos, tunnel_mouths):
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
		var result: Dictionary = space_state.intersect_ray(query)
		if result:
			var hit_pos: Vector3 = result.position
			var hit_dist: float = origin.distance_to(hit_pos)
			var col: Color = _height_color(hit_pos.y, player_y)
			if _is_near_tunnel_mouth(hit_pos, tunnel_mouths):
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
		# Fire 4 rays toward each nearby tunnel mouth with slight jitter
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
				_place_sonar_point(hit.position, hit.color)
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

func _place_sonar_point(pos: Vector3, col: Color) -> void:
	# Fast search: start from _sonar_next_free
	for _j in range(SONAR_POINT_COUNT):
		var i: int = (_sonar_next_free + _j) % SONAR_POINT_COUNT
		if not _sonar_points[i].active:
			_activate_sonar_point(i, pos, col)
			_sonar_next_free = (i + 1) % SONAR_POINT_COUNT
			return

	# All full: recycle oldest (lowest life)
	var oldest_idx: int = 0
	var oldest_life: float = INF
	for i in range(SONAR_POINT_COUNT):
		if _sonar_points[i].life < oldest_life:
			oldest_life = _sonar_points[i].life
			oldest_idx = i
	_activate_sonar_point(oldest_idx, pos, col)

func _activate_sonar_point(idx: int, pos: Vector3, col: Color) -> void:
	var pt = _sonar_points[idx]
	pt.target_pos = pos
	pt.active = true
	pt.life = SONAR_FADE_TIME
	pt.rain_t = 0.0  # Start rain animation from top
	pt.color = col
	pt.rand_delay = randf() * 0.12  # Slight organic timing variation

	# Start position: slightly above target (subtle drop)
	var start_pos: Vector3 = pos + Vector3(0, SONAR_RAIN_HEIGHT, 0)
	var basis: Basis = Basis.IDENTITY.scaled(Vector3(1.0, 1.5, 1.0))
	_sonar_mm.set_instance_transform(idx, Transform3D(basis, start_pos))
	_sonar_mm.set_instance_color(idx, Color(0.4, 0.9, 0.8, 0.0))

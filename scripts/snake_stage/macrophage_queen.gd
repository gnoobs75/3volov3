extends CharacterBody3D
## Macrophage Queen: Boss encounter in the Brain biome.
## Massive immune cell (3x WBC size) with phased AI.
## Phases: PATROL -> ALERT -> SUMMON -> RAGE
## Summons mini-WBCs, has area attacks, drops unique reward on death.

signal died(pos: Vector3)
signal defeated  # Emitted when queen is killed (game progression)

enum Phase { PATROL, ALERT, SUMMON, RAGE }

var phase: Phase = Phase.PATROL
var _time: float = 0.0
var _phase_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var _vertical_velocity: float = 0.0

# Stats
var health: float = 300.0
var max_health: float = 300.0
var _damage_flash: float = 0.0

# Detection
const DETECT_RADIUS: float = 40.0
const CHASE_SPEED: float = 4.0
const PATROL_SPEED: float = 1.5
const RAGE_SPEED: float = 7.0
const ATTACK_RANGE: float = 5.0
const ATTACK_DAMAGE: float = 15.0
const GRAVITY: float = 20.0
const SUMMON_INTERVAL: float = 20.0
const RAGE_THRESHOLD: float = 0.3  # Enter rage at 30% health

# Summon tracking
var _summon_timer: float = 0.0
var _minions_alive: int = 0
const MAX_MINIONS: int = 6

# Attack
var _attack_cooldown: float = 0.0
var _slam_cooldown: float = 0.0
var _voice_cooldown: float = 0.0
const SLAM_COOLDOWN_TIME: float = 6.0
const SLAM_DAMAGE: float = 25.0
const SLAM_RADIUS: float = 8.0

# Visual refs
var _body_mesh: MeshInstance3D = null
var _crown_mesh: MeshInstance3D = null
var _eye_l: MeshInstance3D = null
var _eye_r: MeshInstance3D = null
var _eye_center: MeshInstance3D = null  # Third eye for queen
var _aura_light: OmniLight3D = null
var _body_mat: StandardMaterial3D = null
var _pseudopods: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("white_blood_cell")
	add_to_group("boss")
	_heading = randf() * TAU
	_phase_timer = randf_range(3.0, 5.0)
	_build_body()

func _build_body() -> void:
	# Massive translucent body (3x WBC size)
	_body_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 2.4
	sphere.height = 4.8
	sphere.radial_segments = 24
	sphere.rings = 12
	_body_mesh.mesh = sphere

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.95, 0.85, 0.9, 0.65)
	_body_mat.roughness = 0.2
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.8, 0.5, 0.7) * 0.2
	_body_mat.emission_energy_multiplier = 0.5
	_body_mesh.material_override = _body_mat
	_body_mesh.position = Vector3(0, 2.4, 0)
	add_child(_body_mesh)

	# Crown: ring of spikes on top
	_crown_mesh = MeshInstance3D.new()
	var crown_torus: TorusMesh = TorusMesh.new()
	crown_torus.inner_radius = 1.2
	crown_torus.outer_radius = 1.6
	crown_torus.rings = 16
	crown_torus.ring_segments = 8
	_crown_mesh.mesh = crown_torus
	var crown_mat: StandardMaterial3D = StandardMaterial3D.new()
	crown_mat.albedo_color = Color(1.0, 0.8, 0.3, 0.8)
	crown_mat.roughness = 0.3
	crown_mat.emission_enabled = true
	crown_mat.emission = Color(1.0, 0.7, 0.2)
	crown_mat.emission_energy_multiplier = 2.0
	crown_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crown_mesh.material_override = crown_mat
	_crown_mesh.position = Vector3(0, 4.2, 0)
	add_child(_crown_mesh)

	# Three eyes (center is queen's third eye)
	_eye_l = _build_queen_eye(Vector3(-0.8, 3.2, 1.4), Color(0.9, 0.2, 0.3))
	_eye_r = _build_queen_eye(Vector3(0.8, 3.2, 1.4), Color(0.9, 0.2, 0.3))
	_eye_center = _build_queen_eye(Vector3(0, 3.8, 1.2), Color(1.0, 0.3, 0.8), 0.5)

	# Pseudopod tentacles
	for i in range(6):
		var pod: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.4
		cyl.height = 1.5
		cyl.radial_segments = 8
		pod.mesh = cyl
		var pod_mat: StandardMaterial3D = StandardMaterial3D.new()
		pod_mat.albedo_color = Color(0.9, 0.8, 0.85, 0.5)
		pod_mat.roughness = 0.3
		pod_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pod_mat.emission_enabled = true
		pod_mat.emission = Color(0.7, 0.5, 0.6) * 0.15
		pod_mat.emission_energy_multiplier = 0.3
		pod.material_override = pod_mat
		var angle: float = TAU * i / 6.0
		pod.position = Vector3(cos(angle) * 1.5, 1.0, sin(angle) * 1.5)
		pod.rotation.z = cos(angle) * 0.3
		pod.rotation.x = sin(angle) * 0.3
		add_child(pod)
		_pseudopods.append(pod)

	# Aura glow light
	_aura_light = OmniLight3D.new()
	_aura_light.light_color = Color(0.9, 0.5, 0.7)
	_aura_light.light_energy = 1.5
	_aura_light.omni_range = 15.0
	_aura_light.omni_attenuation = 1.5
	_aura_light.shadow_enabled = true
	_aura_light.position = Vector3(0, 2.5, 0)
	add_child(_aura_light)

	# Collision shape
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 2.0
	capsule.height = 4.5
	col_shape.shape = capsule
	col_shape.position = Vector3(0, 2.4, 0)
	add_child(col_shape)

func _build_queen_eye(pos: Vector3, iris_color: Color, scale_mult: float = 0.4) -> MeshInstance3D:
	# Sclera
	var sclera: MeshInstance3D = MeshInstance3D.new()
	var s_mesh: SphereMesh = SphereMesh.new()
	s_mesh.radius = scale_mult
	s_mesh.height = scale_mult * 2.0
	s_mesh.radial_segments = 14
	s_mesh.rings = 7
	sclera.mesh = s_mesh
	var s_mat: StandardMaterial3D = StandardMaterial3D.new()
	s_mat.albedo_color = Color(1.0, 0.95, 0.95)
	s_mat.roughness = 0.2
	s_mat.emission_enabled = true
	s_mat.emission = Color(1.0, 0.9, 0.95) * 0.4
	s_mat.emission_energy_multiplier = 0.8
	sclera.material_override = s_mat
	sclera.position = pos
	add_child(sclera)

	# Iris
	var iris: MeshInstance3D = MeshInstance3D.new()
	var i_mesh: SphereMesh = SphereMesh.new()
	i_mesh.radius = scale_mult * 0.6
	i_mesh.height = scale_mult * 0.3
	i_mesh.radial_segments = 12
	i_mesh.rings = 4
	iris.mesh = i_mesh
	var i_mat: StandardMaterial3D = StandardMaterial3D.new()
	i_mat.albedo_color = iris_color
	i_mat.roughness = 0.2
	i_mat.emission_enabled = true
	i_mat.emission = iris_color
	i_mat.emission_energy_multiplier = 2.0
	iris.material_override = i_mat
	iris.position = pos + Vector3(0, 0, scale_mult * 0.7)
	add_child(iris)

	# Eye light
	var eye_light: OmniLight3D = OmniLight3D.new()
	eye_light.light_color = iris_color
	eye_light.light_energy = 0.6
	eye_light.omni_range = 4.0
	eye_light.shadow_enabled = false
	eye_light.position = pos + Vector3(0, 0, scale_mult * 0.5)
	add_child(eye_light)

	return sclera

func _physics_process(delta: float) -> void:
	_time += delta
	_phase_timer -= delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_slam_cooldown = maxf(_slam_cooldown - delta, 0.0)
	_voice_cooldown = maxf(_voice_cooldown - delta, 0.0)
	_summon_timer += delta

	# Find player
	var players: Array = get_tree().get_nodes_in_group("player_worm")
	var player: Node3D = players[0] if players.size() > 0 else null
	var player_dist: float = INF
	if player:
		player_dist = global_position.distance_to(player.global_position)

	# Check rage threshold
	if health / max_health <= RAGE_THRESHOLD and phase != Phase.RAGE:
		phase = Phase.RAGE
		_phase_timer = 0.0
		if _voice_cooldown <= 0:
			AudioManager.play_creature_voice("macrophage_queen", "attack", 2.0, 0.9, 0.8)
			_voice_cooldown = 4.0

	# Phase machine
	match phase:
		Phase.PATROL:
			_speed = lerpf(_speed, PATROL_SPEED, delta * 3.0)
			_heading += sin(_time * 0.5) * delta * 0.5
			if _phase_timer <= 0:
				_heading += randf_range(-PI * 0.3, PI * 0.3)
				_phase_timer = randf_range(3.0, 6.0)
			if player and player_dist < DETECT_RADIUS:
				phase = Phase.ALERT
				_phase_timer = 1.5

		Phase.ALERT:
			_speed = lerpf(_speed, 0.0, delta * 4.0)
			if player:
				var to_player: Vector3 = player.global_position - global_position
				var target_heading: float = atan2(to_player.x, to_player.z)
				_heading = lerp_angle(_heading, target_heading, delta * 3.0)
			if _phase_timer <= 0:
				if player and player_dist < DETECT_RADIUS * 1.2:
					phase = Phase.SUMMON
					_phase_timer = 2.0
				else:
					phase = Phase.PATROL
					_phase_timer = randf_range(3.0, 5.0)

		Phase.SUMMON:
			_speed = lerpf(_speed, CHASE_SPEED * 0.5, delta * 3.0)
			if player:
				var to_player: Vector3 = player.global_position - global_position
				var target_heading: float = atan2(to_player.x, to_player.z)
				_heading = lerp_angle(_heading, target_heading, delta * 3.0)

			# Summon minions periodically
			if _summon_timer >= SUMMON_INTERVAL and _minions_alive < MAX_MINIONS:
				_summon_timer = 0.0
				_summon_minions()

			# Slam attack when close
			if player and player_dist < SLAM_RADIUS and _slam_cooldown <= 0:
				_ground_slam(player)

			# Melee attack
			if player and player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
				if player.has_method("take_damage"):
					player.take_damage(ATTACK_DAMAGE)
				_attack_cooldown = 1.2

			# Lost player
			if player and player_dist > DETECT_RADIUS * 2.0:
				phase = Phase.PATROL
				_phase_timer = randf_range(3.0, 5.0)

		Phase.RAGE:
			_speed = lerpf(_speed, RAGE_SPEED, delta * 4.0)
			if player:
				var to_player: Vector3 = player.global_position - global_position
				var target_heading: float = atan2(to_player.x, to_player.z)
				_heading = lerp_angle(_heading, target_heading, delta * 6.0)

			# Faster summons in rage
			if _summon_timer >= SUMMON_INTERVAL * 0.5 and _minions_alive < MAX_MINIONS:
				_summon_timer = 0.0
				_summon_minions()

			# Rapid slam
			if player and player_dist < SLAM_RADIUS and _slam_cooldown <= 0:
				_ground_slam(player)

			# Melee
			if player and player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
				if player.has_method("take_damage"):
					player.take_damage(ATTACK_DAMAGE * 1.5)
				_attack_cooldown = 0.8

	# Movement
	var forward: Vector3 = Vector3(sin(_heading), 0, cos(_heading))
	var move_vel: Vector3 = forward * _speed

	if not is_on_floor():
		_vertical_velocity -= GRAVITY * delta
	else:
		_vertical_velocity = -0.5

	velocity = Vector3(move_vel.x, _vertical_velocity, move_vel.z)
	move_and_slide()
	rotation.y = _heading

	# Damage flash
	if _damage_flash > 0:
		_damage_flash = maxf(_damage_flash - delta * 3.0, 0.0)
		if _body_mat:
			_body_mat.emission_energy_multiplier = 0.5 + _damage_flash * 6.0
			_body_mat.emission = Color(1.0, 0.2, 0.1).lerp(Color(0.8, 0.5, 0.7) * 0.2, 1.0 - _damage_flash)

	# Update visuals
	_update_visuals(delta)

func _update_visuals(delta: float) -> void:
	# Body pulse (faster in rage)
	var pulse_speed: float = 3.0 if phase != Phase.RAGE else 6.0
	var pulse: float = 1.0 + sin(_time * pulse_speed) * 0.05
	if _body_mesh:
		_body_mesh.scale = Vector3(pulse, pulse * 0.95, pulse)

	# Crown rotation
	if _crown_mesh:
		_crown_mesh.rotation.y += delta * (1.0 if phase != Phase.RAGE else 4.0)
		# Crown bobs
		_crown_mesh.position.y = 4.2 + sin(_time * 2.0) * 0.1

	# Pseudopod wobble
	for i in range(_pseudopods.size()):
		var pod: MeshInstance3D = _pseudopods[i]
		var angle: float = TAU * i / _pseudopods.size()
		var wobble: float = sin(_time * 2.0 + i * 1.3) * 0.2
		var reach: float = 1.5 + sin(_time * 1.5 + i * 0.8) * 0.3
		pod.position = Vector3(cos(angle + wobble) * reach, 1.0, sin(angle + wobble) * reach)
		pod.rotation.z = cos(angle + wobble) * 0.4
		pod.rotation.x = sin(angle + wobble) * 0.4

	# Aura intensity by phase
	if _aura_light:
		var target_energy: float = 1.5
		match phase:
			Phase.ALERT:
				target_energy = 2.5
			Phase.SUMMON:
				target_energy = 2.0
			Phase.RAGE:
				target_energy = 4.0 + sin(_time * 8.0) * 1.0
		_aura_light.light_energy = lerpf(_aura_light.light_energy, target_energy, delta * 3.0)
		# Color shifts to red in rage
		if phase == Phase.RAGE:
			_aura_light.light_color = _aura_light.light_color.lerp(Color(1.0, 0.2, 0.1), delta * 2.0)

	# Body color in rage: shifts toward angry red
	if phase == Phase.RAGE and _body_mat:
		_body_mat.albedo_color = _body_mat.albedo_color.lerp(Color(1.0, 0.6, 0.6, 0.7), delta * 1.0)

func _summon_minions() -> void:
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("macrophage_queen", "attack", 2.0, 0.9, 0.8)
		_voice_cooldown = 4.0
	# Spawn 3 mini-WBCs around the queen
	# Note: WBC creates its own collision shape in _build_body() called from _ready()
	var wbc_script = load("res://scripts/snake_stage/white_blood_cell.gd")
	for i in range(3):
		var wbc: CharacterBody3D = CharacterBody3D.new()
		wbc.set_script(wbc_script)
		var angle: float = TAU * i / 3.0 + randf() * 0.5
		var spawn_pos: Vector3 = global_position + Vector3(cos(angle) * 4.0, 0.5, sin(angle) * 4.0)
		wbc.position = spawn_pos
		get_parent().add_child(wbc)
		_minions_alive += 1

		# Track minion death
		if wbc.has_signal("died"):
			wbc.died.connect(func(_pos): _minions_alive = maxi(_minions_alive - 1, 0))

func _ground_slam(player: Node3D) -> void:
	_slam_cooldown = SLAM_COOLDOWN_TIME
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("macrophage_queen", "attack", 2.0, 0.9, 0.8)
		_voice_cooldown = 4.0
	# Damage and knockback everything in radius
	for group_name in ["player_worm"]:
		for target in get_tree().get_nodes_in_group(group_name):
			var dist: float = global_position.distance_to(target.global_position)
			if dist < SLAM_RADIUS:
				var falloff: float = 1.0 - (dist / SLAM_RADIUS)
				if target.has_method("take_damage"):
					target.take_damage(SLAM_DAMAGE * falloff)
				if target is CharacterBody3D:
					var push: Vector3 = (target.global_position - global_position).normalized()
					push.y = 0.6
					target.velocity += push * 15.0 * falloff

func stun(duration: float = 2.0) -> void:
	# Queen resists stuns (halved duration)
	phase = Phase.ALERT
	_phase_timer = duration * 0.5
	_speed = 0.0

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("macrophage_queen", "hurt", 2.0, 0.9, 0.8)
		_voice_cooldown = 3.0
	if phase == Phase.PATROL:
		phase = Phase.ALERT
		_phase_timer = 1.0
	if health <= 0:
		_die()

func _die() -> void:
	AudioManager.play_creature_voice("macrophage_queen", "death", 2.0, 0.9, 0.8)
	died.emit(global_position)
	defeated.emit()
	queue_free()

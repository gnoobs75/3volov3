extends CharacterBody3D
## Killer T-Cell: Assassin enemy. Semi-transparent when stalking, fast lunge.
## States: STEALTH → STALK → LUNGE → ATTACK → RETREAT
## Biomes: BONE_MARROW, LIVER

signal died(pos: Vector3)

enum State { STEALTH, STALK, LUNGE, ATTACK, RETREAT, STUNNED }

var state: State = State.STEALTH
var _time: float = 0.0
var _state_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var health: float = 25.0
var _vertical_velocity: float = 0.0
var _stun_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _voice_cooldown: float = 0.0
var _damage_flash: float = 0.0
var _alpha: float = 0.3  # Semi-transparent in stealth

# Detection
const BASE_DETECT_RADIUS: float = 25.0
const STALK_SPEED: float = 4.0
const STEALTH_SPEED: float = 1.5
const LUNGE_SPEED: float = 16.0
const RETREAT_SPEED: float = 8.0
const ATTACK_RANGE: float = 2.5
const ATTACK_DAMAGE: float = 18.0
const LUNGE_RANGE: float = 8.0
const STUN_DURATION: float = 2.5
const GRAVITY: float = 20.0

# Visual refs
var _body_mesh: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _receptor_spikes: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("killer_t_cell")
	_heading = randf() * TAU
	_state_timer = randf_range(3.0, 6.0)
	_build_body()

func _build_body() -> void:
	# Sleek angular body
	_body_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.4
	sphere.radial_segments = 14
	sphere.rings = 7
	_body_mesh.mesh = sphere

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.3, 0.25, 0.5, 0.3)
	_body_mat.roughness = 0.2
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.4, 0.2, 0.6) * 0.3
	_body_mat.emission_energy_multiplier = 0.6
	_body_mesh.material_override = _body_mat
	_body_mesh.position = Vector3(0, 0.7, 0)
	add_child(_body_mesh)

	# Receptor spikes (surface proteins)
	for i in range(6):
		var spike: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.01
		cyl.bottom_radius = 0.06
		cyl.height = 0.3
		cyl.radial_segments = 4
		spike.mesh = cyl

		var spike_mat: StandardMaterial3D = StandardMaterial3D.new()
		spike_mat.albedo_color = Color(0.5, 0.3, 0.7, 0.5)
		spike_mat.roughness = 0.3
		spike_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spike_mat.emission_enabled = true
		spike_mat.emission = Color(0.6, 0.3, 0.8)
		spike_mat.emission_energy_multiplier = 1.0
		spike.material_override = spike_mat

		var angle: float = TAU * i / 6.0
		spike.position = Vector3(cos(angle) * 0.5, 0.7, sin(angle) * 0.5)
		spike.rotation.z = cos(angle) * 0.6
		spike.rotation.x = sin(angle) * 0.6
		add_child(spike)
		_receptor_spikes.append(spike)

	# Eye glow
	var eye_light: OmniLight3D = OmniLight3D.new()
	eye_light.light_color = Color(0.6, 0.2, 0.8)
	eye_light.light_energy = 0.3
	eye_light.omni_range = 3.0
	eye_light.shadow_enabled = false
	eye_light.position = Vector3(0, 0.9, 0.4)
	add_child(eye_light)

	# Collision shape
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.2
	col_shape.shape = capsule
	col_shape.position = Vector3(0, 0.7, 0)
	add_child(col_shape)

func _physics_process(delta: float) -> void:
	_time += delta
	_state_timer -= delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_voice_cooldown = maxf(_voice_cooldown - delta, 0.0)

	var players: Array = get_tree().get_nodes_in_group("player_worm")
	var player: Node3D = players[0] if players.size() > 0 else null
	var player_dist: float = INF
	var player_noise: float = 0.5
	if player:
		player_dist = global_position.distance_to(player.global_position)
		if "noise_level" in player:
			player_noise = player.noise_level

	var detect_radius: float = BASE_DETECT_RADIUS * (0.4 + player_noise * 0.6)

	match state:
		State.STEALTH:
			_speed = lerpf(_speed, STEALTH_SPEED, delta * 3.0)
			_alpha = lerpf(_alpha, 0.15, delta * 3.0)
			_heading += sin(_time * 0.7) * delta * 0.5
			if _state_timer <= 0:
				_heading += randf_range(-PI * 0.5, PI * 0.5)
				_state_timer = randf_range(3.0, 6.0)
			if player and player_dist < detect_radius:
				state = State.STALK
				_state_timer = 2.0
				if _voice_cooldown <= 0.0 and AudioManager and AudioManager.has_method("play_creature_voice"):
					AudioManager.play_creature_voice("killer_t_cell", "alert", 1.0, 0.9, 1.0)
					_voice_cooldown = 3.0

		State.STALK:
			_speed = lerpf(_speed, STALK_SPEED, delta * 4.0)
			_alpha = lerpf(_alpha, 0.35, delta * 2.0)
			if player:
				var to_player: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_player.x, to_player.z), delta * 4.0)
				if player_dist < LUNGE_RANGE:
					state = State.LUNGE
					_state_timer = 0.3
					if _voice_cooldown <= 0.0 and AudioManager and AudioManager.has_method("play_creature_voice"):
						AudioManager.play_creature_voice("killer_t_cell", "alert", 1.0, 0.9, 1.0)
						_voice_cooldown = 3.0
				elif player_dist > detect_radius * 1.5:
					state = State.STEALTH
					_state_timer = randf_range(3.0, 5.0)

		State.LUNGE:
			_speed = lerpf(_speed, LUNGE_SPEED, delta * 12.0)
			_alpha = lerpf(_alpha, 0.9, delta * 10.0)
			if player:
				var to_player: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_player.x, to_player.z), delta * 8.0)
				if player_dist < ATTACK_RANGE:
					state = State.ATTACK
					_state_timer = 0.2

			if _state_timer <= 0:
				state = State.RETREAT
				_state_timer = 2.0

		State.ATTACK:
			_speed = lerpf(_speed, 0.0, delta * 10.0)
			_alpha = 1.0
			if _state_timer <= 0 and _attack_cooldown <= 0:
				if player and player_dist < ATTACK_RANGE * 1.5:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE)
					_attack_cooldown = 2.0
				state = State.RETREAT
				_state_timer = 3.0

		State.RETREAT:
			_alpha = lerpf(_alpha, 0.25, delta * 4.0)
			_speed = lerpf(_speed, RETREAT_SPEED, delta * 6.0)
			if player:
				# Run away from player
				var away: Vector3 = global_position - player.global_position
				_heading = lerp_angle(_heading, atan2(away.x, away.z), delta * 5.0)
			if _state_timer <= 0:
				state = State.STEALTH
				_state_timer = randf_range(4.0, 7.0)

		State.STUNNED:
			_speed = lerpf(_speed, 0.0, delta * 10.0)
			_alpha = 0.8
			_stun_timer -= delta
			if _stun_timer <= 0:
				state = State.RETREAT
				_state_timer = 2.0

	# Movement
	var forward: Vector3 = Vector3(sin(_heading), 0, cos(_heading))
	if not is_on_floor():
		_vertical_velocity -= GRAVITY * delta
	else:
		_vertical_velocity = -0.5
	velocity = Vector3(forward.x * _speed, _vertical_velocity, forward.z * _speed)
	move_and_slide()
	rotation.y = _heading

	# Apply transparency
	if _body_mat:
		_body_mat.albedo_color.a = _alpha
		for spike in _receptor_spikes:
			if spike.material_override is StandardMaterial3D:
				spike.material_override.albedo_color.a = _alpha * 1.2

	# Damage flash
	if _damage_flash > 0:
		_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
		if _body_mat:
			_body_mat.emission_energy_multiplier = 0.6 + _damage_flash * 5.0

	# Visuals
	var pulse: float = 1.0 + sin(_time * 4.0) * 0.03
	if _body_mesh:
		_body_mesh.scale = Vector3(pulse, pulse, pulse)

func stun(duration: float = STUN_DURATION) -> void:
	state = State.STUNNED
	_stun_timer = duration
	_speed = 0.0

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	_alpha = 1.0  # Reveal on hit
	if _voice_cooldown <= 0.0 and AudioManager and AudioManager.has_method("play_creature_voice"):
		AudioManager.play_creature_voice("killer_t_cell", "hurt", 1.0, 0.9, 1.0)
		_voice_cooldown = 2.5
	if state == State.STEALTH:
		state = State.RETREAT
		_state_timer = 2.0
	if health <= 0:
		_die()

func _die() -> void:
	if AudioManager and AudioManager.has_method("play_creature_voice"):
		AudioManager.play_creature_voice("killer_t_cell", "death", 1.0, 0.9, 1.0)
	died.emit(global_position)
	queue_free()

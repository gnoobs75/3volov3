extends CharacterBody3D
## Phagocyte: Tank enemy. Large, slow, high HP, engulf attack.
## States: PATROL → CHASE → ENGULF → DIGEST → STUNNED
## Biomes: STOMACH, INTESTINAL_TRACT

signal died(pos: Vector3)

enum State { PATROL, ALERT, CHASE, ENGULF, DIGEST, STUNNED }

var state: State = State.PATROL
var _time: float = 0.0
var _state_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var health: float = 60.0
var _vertical_velocity: float = 0.0
var _stun_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _voice_cooldown: float = 0.0
var _damage_flash: float = 0.0

# Detection
const BASE_DETECT_RADIUS: float = 18.0
const CHASE_SPEED: float = 3.5
const PATROL_SPEED: float = 1.2
const ENGULF_RANGE: float = 3.0
const ENGULF_DURATION: float = 2.0
const DIGEST_DPS: float = 2.5  # Reduced: annoying not deadly
const STUN_DURATION: float = 3.0
const GRAVITY: float = 20.0

# Visual refs
var _body_mesh: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _pseudopods: Array[MeshInstance3D] = []
var _engulf_target: Node3D = null

func _ready() -> void:
	add_to_group("phagocyte")
	_heading = randf() * TAU
	_state_timer = randf_range(2.0, 4.0)
	_build_body()

func _build_body() -> void:
	# Large translucent blob body (bigger than WBC)
	_body_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.2
	sphere.height = 2.4
	sphere.radial_segments = 18
	sphere.rings = 9
	_body_mesh.mesh = sphere

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.85, 0.8, 0.7, 0.6)
	_body_mat.roughness = 0.3
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.6, 0.5, 0.4) * 0.15
	_body_mat.emission_energy_multiplier = 0.4
	_body_mesh.material_override = _body_mat
	_body_mesh.position = Vector3(0, 1.2, 0)
	add_child(_body_mesh)

	# Thick pseudopods (engulfing arms)
	for i in range(4):
		var pod: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.35
		cyl.height = 1.0
		cyl.radial_segments = 8
		pod.mesh = cyl
		var pod_mat: StandardMaterial3D = StandardMaterial3D.new()
		pod_mat.albedo_color = Color(0.8, 0.75, 0.65, 0.5)
		pod_mat.roughness = 0.3
		pod_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pod_mat.emission_enabled = true
		pod_mat.emission = Color(0.5, 0.45, 0.35) * 0.1
		pod_mat.emission_energy_multiplier = 0.3
		pod.material_override = pod_mat
		var angle: float = TAU * i / 4.0
		pod.position = Vector3(cos(angle) * 0.8, 0.8, sin(angle) * 0.8)
		add_child(pod)
		_pseudopods.append(pod)

	# Aura light
	var aura: OmniLight3D = OmniLight3D.new()
	aura.light_color = Color(0.7, 0.6, 0.5)
	aura.light_energy = 0.4
	aura.omni_range = 5.0
	aura.shadow_enabled = false
	aura.position = Vector3(0, 1.2, 0)
	add_child(aura)

	# Collision shape
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 1.0
	capsule.height = 2.2
	col_shape.shape = capsule
	col_shape.position = Vector3(0, 1.2, 0)
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

	var detect_radius: float = BASE_DETECT_RADIUS * (0.3 + player_noise * 0.7)

	match state:
		State.PATROL:
			_speed = lerpf(_speed, PATROL_SPEED, delta * 3.0)
			_heading += sin(_time * 0.6) * delta * 0.6
			if _state_timer <= 0:
				_heading += randf_range(-PI * 0.4, PI * 0.4)
				_state_timer = randf_range(3.0, 6.0)
			if player and player_dist < detect_radius:
				state = State.ALERT
				_state_timer = 1.0

		State.ALERT:
			_speed = lerpf(_speed, 0.0, delta * 5.0)
			if player:
				var to_player: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_player.x, to_player.z), delta * 3.0)
			if _state_timer <= 0:
				if player and player_dist < detect_radius * 1.2:
					state = State.CHASE
					if _voice_cooldown <= 0.0 and AudioManager and AudioManager.has_method("play_creature_voice"):
						AudioManager.play_creature_voice("phagocyte", "alert", 1.5, 0.7, 1.0)
						_voice_cooldown = 3.0
				else:
					state = State.PATROL
					_state_timer = randf_range(2.0, 4.0)

		State.CHASE:
			_speed = lerpf(_speed, CHASE_SPEED, delta * 4.0)
			if player:
				var to_player: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_player.x, to_player.z), delta * 4.0)
				if player_dist < ENGULF_RANGE and _attack_cooldown <= 0:
					state = State.ENGULF
					_state_timer = ENGULF_DURATION
					_engulf_target = player
					_attack_cooldown = 5.0
					if _voice_cooldown <= 0.0 and AudioManager and AudioManager.has_method("play_creature_voice"):
						AudioManager.play_creature_voice("phagocyte", "alert", 1.5, 0.7, 1.0)
						_voice_cooldown = 3.0
				elif player_dist > detect_radius * 1.5:
					state = State.PATROL
					_state_timer = randf_range(2.0, 4.0)
			else:
				state = State.PATROL
				_state_timer = randf_range(2.0, 4.0)

		State.ENGULF:
			_speed = lerpf(_speed, 0.0, delta * 8.0)
			# Engulf: damage player over time, lock in place
			if _engulf_target and is_instance_valid(_engulf_target):
				if _engulf_target.has_method("take_damage"):
					_engulf_target.take_damage(DIGEST_DPS * delta)
				# Pull target toward center
				var pull_dir: Vector3 = (global_position - _engulf_target.global_position)
				if pull_dir.length() > 0.3 and _engulf_target is CharacterBody3D:
					_engulf_target.velocity += pull_dir.normalized() * 3.0 * delta
			if _state_timer <= 0:
				state = State.DIGEST
				_state_timer = 1.0
				_engulf_target = null

		State.DIGEST:
			_speed = lerpf(_speed, 0.0, delta * 6.0)
			if _state_timer <= 0:
				state = State.CHASE

		State.STUNNED:
			_speed = lerpf(_speed, 0.0, delta * 10.0)
			_stun_timer -= delta
			if _stun_timer <= 0:
				state = State.ALERT
				_state_timer = 0.5
				_engulf_target = null

	# Movement
	var forward: Vector3 = Vector3(sin(_heading), 0, cos(_heading))
	if not is_on_floor():
		_vertical_velocity -= GRAVITY * delta
	else:
		_vertical_velocity = -0.5
	velocity = Vector3(forward.x * _speed, _vertical_velocity, forward.z * _speed)
	move_and_slide()
	rotation.y = _heading

	# Damage flash
	if _damage_flash > 0:
		_damage_flash = maxf(_damage_flash - delta * 3.0, 0.0)
		if _body_mat:
			_body_mat.emission_energy_multiplier = 0.4 + _damage_flash * 5.0

	# Visual updates
	_update_visuals(delta)

func _update_visuals(delta: float) -> void:
	var pulse: float = 1.0 + sin(_time * 2.0) * 0.04
	if _body_mesh:
		_body_mesh.scale = Vector3(pulse, pulse * 0.95, pulse)
		# Expand during engulf
		if state == State.ENGULF:
			_body_mesh.scale *= 1.15

	for i in range(_pseudopods.size()):
		var pod: MeshInstance3D = _pseudopods[i]
		var angle: float = TAU * i / _pseudopods.size()
		var wobble: float = sin(_time * 2.0 + i * 1.5) * 0.15
		var reach: float = 0.8
		if state == State.ENGULF:
			reach = 1.5  # Arms reach out during engulf
		pod.position = Vector3(cos(angle + wobble) * reach, 0.8, sin(angle + wobble) * reach)

func stun(duration: float = STUN_DURATION) -> void:
	state = State.STUNNED
	_stun_timer = duration
	_speed = 0.0
	_engulf_target = null

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if _voice_cooldown <= 0.0 and AudioManager and AudioManager.has_method("play_creature_voice"):
		AudioManager.play_creature_voice("phagocyte", "hurt", 1.5, 0.7, 1.0)
		_voice_cooldown = 2.5
	if state == State.PATROL:
		state = State.CHASE
	if health <= 0:
		_die()

func _die() -> void:
	if AudioManager and AudioManager.has_method("play_creature_voice"):
		AudioManager.play_creature_voice("phagocyte", "death", 1.5, 0.7, 1.0)
	died.emit(global_position)
	queue_free()

extends CharacterBody3D
## White Blood Cell: enemy of the parasite worm.
## Translucent white body with HUGE googly eyes, pseudopod wobble.
## 5-state AI: PATROL → ALERT → CHASE → ATTACK → STUNNED.

enum State { PATROL, ALERT, CHASE, ATTACK, STUNNED }

var state: State = State.PATROL
var _time: float = 0.0
var _state_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var health: float = 50.0

# Detection
const BASE_DETECT_RADIUS: float = 15.0
const ALERT_HOLD_TIME: float = 1.0
const CHASE_SPEED: float = 6.0
const PATROL_SPEED: float = 2.0
const ATTACK_RANGE: float = 2.0
const ATTACK_DAMAGE: float = 10.0
const STUN_DURATION: float = 3.0
const GRAVITY: float = 20.0

var _vertical_velocity: float = 0.0
var _stun_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _alert_target_pos: Vector3 = Vector3.ZERO

# Visual refs
var _body_mesh: MeshInstance3D = null
var _eye_l: MeshInstance3D = null
var _eye_r: MeshInstance3D = null
var _iris_l: MeshInstance3D = null
var _iris_r: MeshInstance3D = null
var _pupil_l: MeshInstance3D = null
var _pupil_r: MeshInstance3D = null
var _highlight_l: MeshInstance3D = null
var _highlight_r: MeshInstance3D = null
var _eye_light_l: OmniLight3D = null
var _eye_light_r: OmniLight3D = null
var _pseudopods: Array[MeshInstance3D] = []
var _iris_color: Color = Color.WHITE

# Googly eye jiggle state
var _eye_jiggle_l: Vector3 = Vector3.ZERO
var _eye_jiggle_r: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("white_blood_cell")
	_heading = randf() * TAU
	_state_timer = randf_range(1.0, 3.0)
	_iris_color = [
		Color(0.2, 0.6, 1.0),   # Blue
		Color(0.1, 0.8, 0.3),   # Green
		Color(0.9, 0.3, 0.8),   # Pink
		Color(1.0, 0.6, 0.1),   # Orange
		Color(0.6, 0.2, 0.9),   # Purple
	][randi_range(0, 4)]
	_build_body()

func _build_body() -> void:
	# Main body: translucent white-pink sphere
	_body_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	sphere.radial_segments = 16
	sphere.rings = 8
	_body_mesh.mesh = sphere

	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.9, 0.85, 0.88, 0.75)
	body_mat.roughness = 0.3
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mat.emission_enabled = true
	body_mat.emission = Color(0.7, 0.65, 0.7) * 0.15
	body_mat.emission_energy_multiplier = 0.3
	_body_mesh.material_override = body_mat
	_body_mesh.position = Vector3(0, 0.8, 0)
	add_child(_body_mesh)

	# 2-4 pseudopod wobble spheres
	var pod_count: int = randi_range(2, 4)
	for i in range(pod_count):
		var pod: MeshInstance3D = MeshInstance3D.new()
		var pod_sphere: SphereMesh = SphereMesh.new()
		pod_sphere.radius = randf_range(0.25, 0.4)
		pod_sphere.height = pod_sphere.radius * 2.0
		pod_sphere.radial_segments = 10
		pod_sphere.rings = 5
		pod.mesh = pod_sphere
		var pod_mat: StandardMaterial3D = StandardMaterial3D.new()
		pod_mat.albedo_color = Color(0.85, 0.8, 0.83, 0.6)
		pod_mat.roughness = 0.3
		pod_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pod_mat.emission_enabled = true
		pod_mat.emission = Color(0.6, 0.55, 0.6) * 0.1
		pod_mat.emission_energy_multiplier = 0.2
		pod.material_override = pod_mat
		var angle: float = TAU * i / pod_count
		pod.position = Vector3(cos(angle) * 0.5, 0.6 + randf_range(-0.2, 0.2), sin(angle) * 0.5)
		add_child(pod)
		_pseudopods.append(pod)

	# --- HUGE GOOGLY EYES ---
	_build_eye(true)   # Left
	_build_eye(false)  # Right

	# Collision shape
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.7
	capsule.height = 1.6
	col_shape.shape = capsule
	col_shape.position = Vector3(0, 0.8, 0)
	add_child(col_shape)

func _build_eye(is_left: bool) -> void:
	var side: float = 0.3 if is_left else -0.3
	var base_pos: Vector3 = Vector3(side, 1.2, 0.5)

	# Sclera (white of eye) — BIG
	var sclera: MeshInstance3D = MeshInstance3D.new()
	var s_sphere: SphereMesh = SphereMesh.new()
	s_sphere.radius = 0.35
	s_sphere.height = 0.7
	s_sphere.radial_segments = 14
	s_sphere.rings = 7
	sclera.mesh = s_sphere
	var s_mat: StandardMaterial3D = StandardMaterial3D.new()
	s_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	s_mat.roughness = 0.2
	s_mat.emission_enabled = true
	s_mat.emission = Color(0.9, 0.9, 0.95) * 0.3
	s_mat.emission_energy_multiplier = 0.6
	sclera.material_override = s_mat
	sclera.position = base_pos
	add_child(sclera)

	# Iris disc
	var iris: MeshInstance3D = MeshInstance3D.new()
	var i_sphere: SphereMesh = SphereMesh.new()
	i_sphere.radius = 0.25
	i_sphere.height = 0.12
	i_sphere.radial_segments = 12
	i_sphere.rings = 2
	iris.mesh = i_sphere
	var i_mat: StandardMaterial3D = StandardMaterial3D.new()
	i_mat.albedo_color = _iris_color
	i_mat.roughness = 0.3
	i_mat.emission_enabled = true
	i_mat.emission = _iris_color * 0.4
	i_mat.emission_energy_multiplier = 1.0
	iris.material_override = i_mat
	iris.position = base_pos + Vector3(0, 0, 0.18)
	add_child(iris)

	# Pupil disc
	var pupil: MeshInstance3D = MeshInstance3D.new()
	var p_sphere: SphereMesh = SphereMesh.new()
	p_sphere.radius = 0.12
	p_sphere.height = 0.06
	p_sphere.radial_segments = 10
	p_sphere.rings = 2
	pupil.mesh = p_sphere
	var p_mat: StandardMaterial3D = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.02, 0.02, 0.05)
	p_mat.roughness = 0.1
	pupil.material_override = p_mat
	pupil.position = base_pos + Vector3(0, 0, 0.22)
	add_child(pupil)

	# Highlight
	var highlight: MeshInstance3D = MeshInstance3D.new()
	var h_sphere: SphereMesh = SphereMesh.new()
	h_sphere.radius = 0.06
	h_sphere.height = 0.04
	h_sphere.radial_segments = 6
	h_sphere.rings = 2
	highlight.mesh = h_sphere
	var h_mat: StandardMaterial3D = StandardMaterial3D.new()
	h_mat.albedo_color = Color(1.0, 1.0, 1.0)
	h_mat.roughness = 0.0
	h_mat.emission_enabled = true
	h_mat.emission = Color(1.0, 1.0, 1.0) * 0.8
	h_mat.emission_energy_multiplier = 2.0
	highlight.material_override = h_mat
	highlight.position = base_pos + Vector3(-0.08, 0.1, 0.26)
	add_child(highlight)

	# OmniLight per eye for visibility in dark
	var eye_light: OmniLight3D = OmniLight3D.new()
	eye_light.light_color = Color(0.9, 0.9, 1.0)
	eye_light.light_energy = 0.5
	eye_light.omni_range = 3.0
	eye_light.omni_attenuation = 2.0
	eye_light.shadow_enabled = false
	eye_light.position = base_pos + Vector3(0, 0, 0.1)
	add_child(eye_light)

	if is_left:
		_eye_l = sclera
		_iris_l = iris
		_pupil_l = pupil
		_highlight_l = highlight
		_eye_light_l = eye_light
	else:
		_eye_r = sclera
		_iris_r = iris
		_pupil_r = pupil
		_highlight_r = highlight
		_eye_light_r = eye_light

func _physics_process(delta: float) -> void:
	_time += delta
	_state_timer -= delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)

	# Find player
	var players: Array = get_tree().get_nodes_in_group("player_worm")
	var player: Node3D = players[0] if players.size() > 0 else null
	var player_dist: float = INF
	var player_noise: float = 0.5
	if player:
		player_dist = global_position.distance_to(player.global_position)
		if player.has_method("get") and "noise_level" in player:
			player_noise = player.noise_level

	# Effective detection radius based on player noise
	var detect_radius: float = BASE_DETECT_RADIUS * (0.3 + player_noise * 0.7)

	# State machine
	match state:
		State.PATROL:
			_speed = lerpf(_speed, PATROL_SPEED, delta * 4.0)
			# Gentle meandering
			_heading += sin(_time * 0.8) * delta * 0.8
			if _state_timer <= 0:
				_heading += randf_range(-PI * 0.5, PI * 0.5)
				_state_timer = randf_range(2.0, 5.0)
			# Check for player
			if player and player_dist < detect_radius:
				state = State.ALERT
				_state_timer = ALERT_HOLD_TIME
				_alert_target_pos = player.global_position

		State.ALERT:
			_speed = lerpf(_speed, 0.0, delta * 6.0)
			# Face player
			if player:
				var to_player: Vector3 = player.global_position - global_position
				var target_heading: float = atan2(to_player.x, to_player.z)
				_heading = lerp_angle(_heading, target_heading, delta * 3.0)
			if _state_timer <= 0:
				if player and player_dist < detect_radius * 1.2:
					state = State.CHASE
					if AudioManager and AudioManager.has_method("play_wbc_alert"):
						AudioManager.play_wbc_alert()
				else:
					state = State.PATROL
					_state_timer = randf_range(2.0, 4.0)

		State.CHASE:
			_speed = lerpf(_speed, CHASE_SPEED, delta * 5.0)
			if player:
				var to_player: Vector3 = player.global_position - global_position
				var target_heading: float = atan2(to_player.x, to_player.z)
				_heading = lerp_angle(_heading, target_heading, delta * 5.0)
				if player_dist < ATTACK_RANGE:
					state = State.ATTACK
					_state_timer = 0.3
				elif player_dist > detect_radius * 1.5:
					state = State.PATROL
					_state_timer = randf_range(2.0, 4.0)
			else:
				state = State.PATROL
				_state_timer = randf_range(2.0, 4.0)

		State.ATTACK:
			_speed = lerpf(_speed, 0.0, delta * 8.0)
			if _state_timer <= 0 and _attack_cooldown <= 0:
				if player and player_dist < ATTACK_RANGE * 1.5:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE)
					_attack_cooldown = 1.5
				state = State.CHASE

		State.STUNNED:
			_speed = lerpf(_speed, 0.0, delta * 10.0)
			_stun_timer -= delta
			if _stun_timer <= 0:
				state = State.ALERT
				_state_timer = 0.5

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

	# Update visuals
	_update_eyes(delta, player)
	_update_pseudopods(delta)
	_update_body_visual(delta)

func _update_eyes(delta: float, player: Node3D) -> void:
	# Googly eye jiggle: random offset each frame
	_eye_jiggle_l = _eye_jiggle_l.lerp(
		Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), 0),
		delta * 15.0
	)
	_eye_jiggle_r = _eye_jiggle_r.lerp(
		Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), 0),
		delta * 15.0
	)

	# Iris/pupil look toward player
	var look_offset: Vector3 = Vector3.ZERO
	if player:
		var to_player: Vector3 = (player.global_position - global_position).normalized()
		var local_dir: Vector3 = to_player.rotated(Vector3.UP, -_heading)
		look_offset = Vector3(local_dir.x, local_dir.y, 0) * 0.06

	# Apply jiggle + look
	if _iris_l:
		_iris_l.position = Vector3(0.3, 1.2, 0.68) + _eye_jiggle_l + look_offset
	if _iris_r:
		_iris_r.position = Vector3(-0.3, 1.2, 0.68) + _eye_jiggle_r + look_offset
	if _pupil_l:
		_pupil_l.position = Vector3(0.3, 1.2, 0.72) + _eye_jiggle_l * 1.3 + look_offset * 1.2
	if _pupil_r:
		_pupil_r.position = Vector3(-0.3, 1.2, 0.72) + _eye_jiggle_r * 1.3 + look_offset * 1.2

	# Eye scale: widen during ALERT/CHASE
	var eye_scale: float = 1.0
	match state:
		State.ALERT:
			eye_scale = 1.3
		State.CHASE:
			eye_scale = 1.15
		State.STUNNED:
			eye_scale = 0.8
	if _eye_l:
		_eye_l.scale = _eye_l.scale.lerp(Vector3.ONE * eye_scale, delta * 8.0)
	if _eye_r:
		_eye_r.scale = _eye_r.scale.lerp(Vector3.ONE * eye_scale, delta * 8.0)

	# Spiral eyes when stunned
	if state == State.STUNNED:
		var spiral: float = _time * 12.0
		if _iris_l:
			_iris_l.position += Vector3(cos(spiral) * 0.08, sin(spiral) * 0.08, 0)
		if _iris_r:
			_iris_r.position += Vector3(cos(spiral + PI) * 0.08, sin(spiral + PI) * 0.08, 0)

	# Eye lights brighter when alert/chasing
	var light_energy: float = 0.5
	if state == State.ALERT:
		light_energy = 0.8
	elif state == State.CHASE:
		light_energy = 1.0
	elif state == State.STUNNED:
		light_energy = 0.2
	if _eye_light_l:
		_eye_light_l.light_energy = lerpf(_eye_light_l.light_energy, light_energy, delta * 5.0)
	if _eye_light_r:
		_eye_light_r.light_energy = lerpf(_eye_light_r.light_energy, light_energy, delta * 5.0)

func _update_pseudopods(delta: float) -> void:
	for i in range(_pseudopods.size()):
		var pod: MeshInstance3D = _pseudopods[i]
		var angle: float = TAU * i / _pseudopods.size()
		var wobble: float = sin(_time * 2.5 + i * 1.8) * 0.15
		var wobble_y: float = sin(_time * 1.8 + i * 2.3) * 0.1
		pod.position = Vector3(
			cos(angle + wobble) * 0.55,
			0.6 + wobble_y,
			sin(angle + wobble) * 0.55
		)

func _update_body_visual(delta: float) -> void:
	if not _body_mesh:
		return
	# Pulse body slightly
	var pulse: float = 1.0 + sin(_time * 3.0) * 0.03
	_body_mesh.scale = Vector3(pulse, pulse * 0.95, pulse)

	# Color shifts by state
	var body_mat: StandardMaterial3D = _body_mesh.material_override
	if body_mat:
		match state:
			State.CHASE:
				body_mat.albedo_color = body_mat.albedo_color.lerp(Color(1.0, 0.7, 0.7, 0.75), delta * 3.0)
			State.STUNNED:
				body_mat.albedo_color = body_mat.albedo_color.lerp(Color(0.6, 0.6, 0.8, 0.5), delta * 3.0)
			_:
				body_mat.albedo_color = body_mat.albedo_color.lerp(Color(0.9, 0.85, 0.88, 0.75), delta * 2.0)

func stun(duration: float = STUN_DURATION) -> void:
	state = State.STUNNED
	_stun_timer = duration
	_speed = 0.0

func take_damage(amount: float) -> void:
	health -= amount
	if state != State.STUNNED:
		state = State.CHASE  # Getting hit makes them aggressive
	if health <= 0:
		_die()

func _die() -> void:
	# Death particles could be added by stage manager
	queue_free()

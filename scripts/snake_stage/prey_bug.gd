extends CharacterBody3D
## Small alien bug: scurries around, flees from the player worm.
## Has an expressive face (scared when fleeing, calm when idle).

enum State { IDLE, WANDER, FLEE }
var state: State = State.IDLE

var _time: float = 0.0
var _state_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var _panic: float = 0.0  # 0-1
var health: float = 20.0
var _damage_flash: float = 0.0


# Visuals
var _body_mesh: MeshInstance3D = null
var _eye_l: MeshInstance3D = null
var _eye_r: MeshInstance3D = null
var _iris_l: MeshInstance3D = null
var _iris_r: MeshInstance3D = null
var _pupil_l: MeshInstance3D = null
var _pupil_r: MeshInstance3D = null
var _highlight_l: MeshInstance3D = null
var _highlight_r: MeshInstance3D = null
var _mouth_mesh: MeshInstance3D = null
var _antenna_tips: Array[MeshInstance3D] = []
var _legs: Array[MeshInstance3D] = []

const WANDER_SPEED: float = 3.0
const FLEE_SPEED: float = 7.0
const DETECT_RADIUS: float = 12.0
const GRAVITY: float = 20.0

var _vertical_velocity: float = 0.0
var _body_color: Color

func _ready() -> void:
	add_to_group("prey")
	_heading = randf() * TAU
	_state_timer = randf_range(1.0, 4.0)

	# Randomize color
	_body_color = Color(
		randf_range(0.3, 0.6),
		randf_range(0.4, 0.7),
		randf_range(0.2, 0.5)
	)
	_build_body()


func _build_body() -> void:
	# Main body: slightly flattened capsule
	_body_mesh = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 0.8
	capsule.radial_segments = 8
	capsule.rings = 4
	_body_mesh.mesh = capsule
	_body_mesh.rotation.z = PI * 0.5  # Lay on side (horizontal)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _body_color
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = _body_color * 0.2
	mat.emission_energy_multiplier = 0.4
	_body_mesh.material_override = mat
	_body_mesh.position.y = 0.3
	add_child(_body_mesh)

	# Eyes (BIG anime style! - oversized for expressiveness)
	var eye_mat: StandardMaterial3D = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 1.0, 1.0)
	eye_mat.emission_energy_multiplier = 0.4

	var iris_mat: StandardMaterial3D = StandardMaterial3D.new()
	iris_mat.albedo_color = Color(0.3, 0.5, 0.2)  # Green bug eyes
	iris_mat.emission_enabled = true
	iris_mat.emission = Color(0.3, 0.5, 0.2) * 0.3
	iris_mat.emission_energy_multiplier = 0.3

	var pupil_mat: StandardMaterial3D = StandardMaterial3D.new()
	pupil_mat.albedo_color = Color(0.02, 0.02, 0.05)

	var highlight_mat: StandardMaterial3D = StandardMaterial3D.new()
	highlight_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	highlight_mat.emission_enabled = true
	highlight_mat.emission = Color(1.0, 1.0, 1.0)
	highlight_mat.emission_energy_multiplier = 1.0

	for side in [-1, 1]:
		# Big white eye
		var eye: MeshInstance3D = MeshInstance3D.new()
		var eye_sphere: SphereMesh = SphereMesh.new()
		eye_sphere.radius = 0.22  # Much bigger!
		eye_sphere.height = 0.4
		eye_sphere.radial_segments = 12
		eye_sphere.rings = 6
		eye.mesh = eye_sphere
		eye.material_override = eye_mat
		eye.position = Vector3(0.2, 0.42, side * 0.18)
		add_child(eye)

		# Colored iris
		var iris: MeshInstance3D = MeshInstance3D.new()
		var iris_sphere: SphereMesh = SphereMesh.new()
		iris_sphere.radius = 0.14
		iris_sphere.height = 0.28
		iris_sphere.radial_segments = 10
		iris_sphere.rings = 5
		iris.mesh = iris_sphere
		iris.material_override = iris_mat
		iris.position = Vector3(0.3, 0.42, side * 0.18)
		add_child(iris)

		# Dark pupil
		var pupil: MeshInstance3D = MeshInstance3D.new()
		var pupil_sphere: SphereMesh = SphereMesh.new()
		pupil_sphere.radius = 0.07
		pupil_sphere.height = 0.14
		pupil_sphere.radial_segments = 8
		pupil_sphere.rings = 4
		pupil.mesh = pupil_sphere
		pupil.material_override = pupil_mat
		pupil.position = Vector3(0.34, 0.42, side * 0.18)
		add_child(pupil)

		# Anime highlight sparkle
		var highlight: MeshInstance3D = MeshInstance3D.new()
		var hl_sphere: SphereMesh = SphereMesh.new()
		hl_sphere.radius = 0.04
		hl_sphere.height = 0.08
		hl_sphere.radial_segments = 6
		hl_sphere.rings = 4
		highlight.mesh = hl_sphere
		highlight.material_override = highlight_mat
		highlight.position = Vector3(0.28, 0.48, side * 0.14)
		add_child(highlight)

		if side == -1:
			_eye_l = eye
			_iris_l = iris
			_pupil_l = pupil
			_highlight_l = highlight
		else:
			_eye_r = eye
			_iris_r = iris
			_pupil_r = pupil
			_highlight_r = highlight

	# Small mouth (simple sphere, changes color with mood)
	var mouth: MeshInstance3D = MeshInstance3D.new()
	var mouth_sphere: SphereMesh = SphereMesh.new()
	mouth_sphere.radius = 0.06
	mouth_sphere.height = 0.08
	mouth_sphere.radial_segments = 8
	mouth_sphere.rings = 4
	mouth.mesh = mouth_sphere
	var mouth_mat: StandardMaterial3D = StandardMaterial3D.new()
	mouth_mat.albedo_color = Color(0.15, 0.08, 0.1)
	mouth.material_override = mouth_mat
	mouth.position = Vector3(0.38, 0.3, 0)
	add_child(mouth)
	_mouth_mesh = mouth

	# Antennae (longer, with bobbing tips)
	var ant_mat: StandardMaterial3D = StandardMaterial3D.new()
	ant_mat.albedo_color = _body_color.darkened(0.15)
	ant_mat.emission_enabled = true
	ant_mat.emission = _body_color * 0.1
	ant_mat.emission_energy_multiplier = 0.2
	for side in [-1, 1]:
		var antenna: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.008
		cyl.bottom_radius = 0.025
		cyl.height = 0.4
		cyl.radial_segments = 4
		antenna.mesh = cyl
		antenna.material_override = ant_mat
		antenna.position = Vector3(0.3, 0.6, side * 0.08)
		antenna.rotation.z = side * 0.5
		antenna.rotation.x = -0.4
		add_child(antenna)

		# Antenna tip (glowing ball)
		var tip: MeshInstance3D = MeshInstance3D.new()
		var tip_sphere: SphereMesh = SphereMesh.new()
		tip_sphere.radius = 0.03
		tip_sphere.height = 0.06
		tip_sphere.radial_segments = 6
		tip_sphere.rings = 4
		tip.mesh = tip_sphere
		var tip_mat: StandardMaterial3D = StandardMaterial3D.new()
		tip_mat.albedo_color = Color(0.4, 0.8, 0.5)
		tip_mat.emission_enabled = true
		tip_mat.emission = Color(0.4, 0.8, 0.5)
		tip_mat.emission_energy_multiplier = 2.0
		tip.material_override = tip_mat
		tip.position = Vector3(0, 0.2, 0)
		antenna.add_child(tip)
		_antenna_tips.append(tip)

	# Small legs (3 pairs)
	var leg_mat: StandardMaterial3D = StandardMaterial3D.new()
	leg_mat.albedo_color = _body_color.darkened(0.3)
	for li in range(3):
		for side in [-1, 1]:
			var leg: MeshInstance3D = MeshInstance3D.new()
			var leg_cyl: CylinderMesh = CylinderMesh.new()
			leg_cyl.top_radius = 0.012
			leg_cyl.bottom_radius = 0.018
			leg_cyl.height = 0.2
			leg_cyl.radial_segments = 4
			leg.mesh = leg_cyl
			leg.material_override = leg_mat
			leg.position = Vector3(-0.05 + li * 0.15, 0.12, side * 0.22)
			leg.rotation.z = side * 0.8
			add_child(leg)
			_legs.append(leg)

	# Collision
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 0.8
	col_shape.shape = shape
	col_shape.rotation.z = PI * 0.5
	col_shape.position.y = 0.3
	add_child(col_shape)

func _physics_process(delta: float) -> void:
	_time += delta
	_state_timer -= delta

	# Find player
	var player: Node3D = null
	var players: Array = get_tree().get_nodes_in_group("player_worm")
	if players.size() > 0:
		player = players[0]

	var dist_to_player: float = INF
	if player:
		dist_to_player = global_position.distance_to(player.global_position)

	# State transitions
	match state:
		State.IDLE:
			_speed = lerpf(_speed, 0.0, delta * 5.0)
			_panic = lerpf(_panic, 0.0, delta * 2.0)
			if dist_to_player < DETECT_RADIUS:
				state = State.FLEE
				_state_timer = randf_range(2.0, 4.0)
			elif _state_timer <= 0:
				state = State.WANDER
				_state_timer = randf_range(2.0, 5.0)
				_heading += randf_range(-1.0, 1.0)

		State.WANDER:
			_speed = lerpf(_speed, WANDER_SPEED, delta * 3.0)
			_panic = lerpf(_panic, 0.0, delta * 2.0)
			_heading += sin(_time * 0.8) * delta * 0.5  # Gentle meandering
			if dist_to_player < DETECT_RADIUS:
				state = State.FLEE
				_state_timer = randf_range(2.0, 4.0)
			elif _state_timer <= 0:
				state = State.IDLE
				_state_timer = randf_range(1.0, 3.0)

		State.FLEE:
			_panic = lerpf(_panic, 1.0, delta * 4.0)
			_speed = lerpf(_speed, FLEE_SPEED, delta * 6.0)
			if player:
				# Run away from player
				var away: Vector3 = (global_position - player.global_position).normalized()
				var target_heading: float = atan2(away.x, away.z)
				_heading = lerp_angle(_heading, target_heading, delta * 5.0)
			if dist_to_player > DETECT_RADIUS * 1.5:
				state = State.WANDER
				_state_timer = randf_range(2.0, 4.0)
			elif _state_timer <= 0:
				# Change flee direction slightly
				_heading += randf_range(-0.8, 0.8)
				_state_timer = randf_range(1.0, 2.0)

	# Movement
	var forward: Vector3 = Vector3(sin(_heading), 0, cos(_heading))
	var move_vel: Vector3 = forward * _speed

	# Gravity (pure physics, no terrain snapping - works with cave collision)
	if not is_on_floor():
		_vertical_velocity -= GRAVITY * delta
	else:
		_vertical_velocity = -0.5  # Stay grounded

	velocity = Vector3(move_vel.x, _vertical_velocity, move_vel.z)
	move_and_slide()

	rotation.y = _heading

	# Damage flash decay
	if _damage_flash > 0:
		_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
		if _body_mesh and _body_mesh.material_override is StandardMaterial3D:
			var bmat: StandardMaterial3D = _body_mesh.material_override
			bmat.emission_energy_multiplier = 0.4 + _damage_flash * 5.0
			bmat.emission = Color(1.0, 0.2, 0.1).lerp(_body_color * 0.2, 1.0 - _damage_flash)

	# Update face expressions
	_update_face(delta)

func _update_face(delta: float) -> void:
	if not _eye_l or not _eye_r:
		return

	# Eye size based on panic (big scared anime eyes!)
	var eye_scale: float = 1.0 + _panic * 0.6
	var eye_squash_y: float = eye_scale * (1.0 - _panic * 0.1)
	_eye_l.scale = Vector3(eye_scale, eye_squash_y, eye_scale)
	_eye_r.scale = Vector3(eye_scale, eye_squash_y, eye_scale)

	# Iris tracks toward threat when scared, wanders when calm
	var iris_offset_z: float = 0.0
	var iris_offset_y: float = 0.0
	if _panic > 0.5:
		# Darting eyes - rapid random movement
		iris_offset_z = sin(_time * 12.0) * 0.04
		iris_offset_y = cos(_time * 10.0) * 0.02
	elif state == State.WANDER:
		# Gentle look around
		iris_offset_z = sin(_time * 1.5) * 0.02
		iris_offset_y = cos(_time * 1.2) * 0.01
	if _iris_l:
		_iris_l.position.z = -0.18 + iris_offset_z
		_iris_l.position.y = 0.42 + iris_offset_y
		_iris_l.scale = Vector3(eye_scale * 0.95, eye_squash_y * 0.95, eye_scale * 0.95)
	if _iris_r:
		_iris_r.position.z = 0.18 + iris_offset_z
		_iris_r.position.y = 0.42 + iris_offset_y
		_iris_r.scale = Vector3(eye_scale * 0.95, eye_squash_y * 0.95, eye_scale * 0.95)

	# Pupil size (shrink to pinpricks when scared)
	var pupil_scale: float = 1.0 - _panic * 0.6
	if _pupil_l:
		_pupil_l.scale = Vector3(pupil_scale, pupil_scale, pupil_scale)
		_pupil_l.position.z = -0.18 + iris_offset_z * 1.2
		_pupil_l.position.y = 0.42 + iris_offset_y * 1.2
	if _pupil_r:
		_pupil_r.scale = Vector3(pupil_scale, pupil_scale, pupil_scale)
		_pupil_r.position.z = 0.18 + iris_offset_z * 1.2
		_pupil_r.position.y = 0.42 + iris_offset_y * 1.2

	# Highlights pulse and shimmer
	var highlight_scale: float = 1.0 + sin(_time * 4.0) * 0.3
	var highlight_alpha: float = 0.7 + sin(_time * 5.0) * 0.25
	if _highlight_l:
		_highlight_l.scale = Vector3(highlight_scale, highlight_scale, highlight_scale)
		if _highlight_l.material_override:
			_highlight_l.material_override.albedo_color.a = highlight_alpha
	if _highlight_r:
		_highlight_r.scale = Vector3(highlight_scale, highlight_scale, highlight_scale)
		if _highlight_r.material_override:
			_highlight_r.material_override.albedo_color.a = highlight_alpha

	# Mouth: grows into scared "O" shape when panicking
	if _mouth_mesh:
		var mouth_scale: float = 1.0 + _panic * 1.8
		var mouth_open: float = 1.0 + _panic * 0.6
		_mouth_mesh.scale = Vector3(mouth_scale, mouth_open, mouth_scale)
		# Drop mouth down when scared
		_mouth_mesh.position.y = 0.3 - _panic * 0.05

	# Antenna tips glow brighter when scared
	for tip in _antenna_tips:
		if tip.material_override:
			var glow: float = 2.0 + _panic * 4.0 + sin(_time * 6.0) * 0.5
			tip.material_override.emission_energy_multiplier = glow

	# Legs animate - scurry motion
	var leg_speed: float = 8.0 + _panic * 12.0
	for li in range(_legs.size()):
		var leg: MeshInstance3D = _legs[li]
		var phase: float = float(li) * PI / 3.0
		leg.rotation.x = sin(_time * leg_speed + phase) * 0.4 * clampf(_speed / WANDER_SPEED, 0.1, 1.0)

	# Body squash/stretch when moving
	if _body_mesh:
		var stretch: float = 1.0 + absf(_speed) / FLEE_SPEED * 0.15
		_body_mesh.scale = Vector3(1.0, 1.0 / stretch, stretch)

		# Wobble when fleeing
		if _panic > 0.3:
			_body_mesh.rotation.x = sin(_time * 15.0) * 0.1 * _panic

signal died(pos: Vector3)

func take_damage(amount: float) -> void:
	health -= amount
	_panic = 1.0
	_damage_flash = 1.0
	state = State.FLEE
	_state_timer = 3.0
	if health <= 0:
		_die()

func _die() -> void:
	died.emit(global_position)
	queue_free()

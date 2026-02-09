extends CharacterBody3D
## Antibody Flyer: immune system harasser that hovers, dives, and stabs.
## 4-state AI: HOVER → DIVE → STAB → RETREAT.
## Y-shaped body with glowing arm tips, single red eye.

enum State { HOVER, DIVE, STAB, RETREAT }

signal died(pos: Vector3)

var state: State = State.HOVER
var _time: float = 0.0
var _state_timer: float = 0.0
var health: float = 30.0

# Hover parameters
const HOVER_HEIGHT: float = 10.0
const HOVER_SPEED: float = 2.0
const HOVER_CIRCLE_RADIUS: float = 6.0
const DIVE_SPEED: float = 20.0
const RETREAT_SPEED: float = 8.0
const DIVE_RANGE: float = 25.0
const DIVE_COOLDOWN: float = 3.0
const STAB_DURATION: float = 0.5  # Stuck longer = more vulnerable to bite
const STAB_DAMAGE: float = 8.0
const STAB_RADIUS: float = 2.0
const GRAVITY: float = 0.5
const STEALTH_DETECT_THRESHOLD: float = 0.2  # Player noise below this = invisible

var _hover_angle: float = 0.0
var _dive_target: Vector3 = Vector3.ZERO
var _dive_cooldown: float = 0.0
var _vertical_velocity: float = 0.0
var _damage_flash: float = 0.0

# Visuals
var _body_mesh: MeshInstance3D = null
var _arm_l: MeshInstance3D = null
var _arm_r: MeshInstance3D = null
var _eye_mesh: MeshInstance3D = null
var _tip_l: MeshInstance3D = null
var _tip_r: MeshInstance3D = null

func _ready() -> void:
	add_to_group("flyer")
	_hover_angle = randf() * TAU
	_state_timer = randf_range(1.0, 3.0)
	_build_body()

func _build_body() -> void:
	# Central body: vertical cylinder (antibody stem)
	_body_mesh = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.25
	cyl.height = 1.2
	cyl.radial_segments = 8
	_body_mesh.mesh = cyl

	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.85, 0.8, 0.65)
	body_mat.roughness = 0.4
	body_mat.emission_enabled = true
	body_mat.emission = Color(0.6, 0.5, 0.3) * 0.2
	body_mat.emission_energy_multiplier = 0.5
	_body_mesh.material_override = body_mat
	_body_mesh.position = Vector3(0, 0.6, 0)
	add_child(_body_mesh)

	# Left arm (angled cylinder)
	_arm_l = MeshInstance3D.new()
	var arm_cyl: CylinderMesh = CylinderMesh.new()
	arm_cyl.top_radius = 0.06
	arm_cyl.bottom_radius = 0.12
	arm_cyl.height = 0.8
	arm_cyl.radial_segments = 6
	_arm_l.mesh = arm_cyl
	_arm_l.material_override = body_mat
	_arm_l.position = Vector3(-0.35, 1.0, 0)
	_arm_l.rotation.z = deg_to_rad(40.0)
	add_child(_arm_l)

	# Right arm
	_arm_r = MeshInstance3D.new()
	_arm_r.mesh = arm_cyl
	_arm_r.material_override = body_mat
	_arm_r.position = Vector3(0.35, 1.0, 0)
	_arm_r.rotation.z = deg_to_rad(-40.0)
	add_child(_arm_r)

	# Glowing arm tips
	var tip_mat: StandardMaterial3D = StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.3, 0.8, 1.0)
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(0.3, 0.8, 1.0)
	tip_mat.emission_energy_multiplier = 3.0

	var tip_sphere: SphereMesh = SphereMesh.new()
	tip_sphere.radius = 0.1
	tip_sphere.height = 0.2
	tip_sphere.radial_segments = 8
	tip_sphere.rings = 4

	_tip_l = MeshInstance3D.new()
	_tip_l.mesh = tip_sphere
	_tip_l.material_override = tip_mat
	_tip_l.position = Vector3(0, 0.45, 0)
	_arm_l.add_child(_tip_l)

	_tip_r = MeshInstance3D.new()
	_tip_r.mesh = tip_sphere
	_tip_r.material_override = tip_mat
	_tip_r.position = Vector3(0, 0.45, 0)
	_arm_r.add_child(_tip_r)

	# Single red eye
	_eye_mesh = MeshInstance3D.new()
	var eye_sphere: SphereMesh = SphereMesh.new()
	eye_sphere.radius = 0.12
	eye_sphere.height = 0.24
	eye_sphere.radial_segments = 10
	eye_sphere.rings = 5
	_eye_mesh.mesh = eye_sphere
	var eye_mat: StandardMaterial3D = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.15, 0.05)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.1, 0.05)
	eye_mat.emission_energy_multiplier = 4.0
	_eye_mesh.material_override = eye_mat
	_eye_mesh.position = Vector3(0, 1.2, 0.18)
	add_child(_eye_mesh)

	# Eye light
	var eye_light: OmniLight3D = OmniLight3D.new()
	eye_light.light_color = Color(1.0, 0.2, 0.1)
	eye_light.light_energy = 0.6
	eye_light.omni_range = 4.0
	eye_light.shadow_enabled = false
	_eye_mesh.add_child(eye_light)

	# Collision shape
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.4
	col_shape.shape = capsule
	col_shape.position = Vector3(0, 0.7, 0)
	add_child(col_shape)

func _physics_process(delta: float) -> void:
	_time += delta
	_state_timer -= delta
	_dive_cooldown = maxf(_dive_cooldown - delta, 0.0)

	# Find player
	var players: Array = get_tree().get_nodes_in_group("player_worm")
	var player: Node3D = players[0] if players.size() > 0 else null
	var player_dist: float = INF
	var player_noise: float = 0.5
	if player:
		player_dist = global_position.distance_to(player.global_position)
		if "noise_level" in player:
			player_noise = player.noise_level

	# Player is stealthed if noise is below threshold
	var player_stealthed: bool = player_noise < STEALTH_DETECT_THRESHOLD

	# State machine
	match state:
		State.HOVER:
			if player:
				# Circle above player
				_hover_angle += HOVER_SPEED * delta
				var target_pos: Vector3 = player.global_position
				target_pos.x += cos(_hover_angle) * HOVER_CIRCLE_RADIUS
				target_pos.z += sin(_hover_angle) * HOVER_CIRCLE_RADIUS
				target_pos.y += HOVER_HEIGHT + sin(_time * 2.0) * 1.5  # Bob

				var dir: Vector3 = (target_pos - global_position)
				velocity = dir * 3.0
			else:
				velocity = Vector3(sin(_time * 0.5), 0, cos(_time * 0.5)) * HOVER_SPEED

			# Check dive trigger — only if player isn't sneaking
			if player and player_dist < DIVE_RANGE and _dive_cooldown <= 0 and not player_stealthed:
				state = State.DIVE
				_dive_target = player.global_position + Vector3(0, 0.5, 0)

		State.DIVE:
			var to_target: Vector3 = (_dive_target - global_position)
			var dist: float = to_target.length()
			if dist > 0.5:
				velocity = to_target.normalized() * DIVE_SPEED
			else:
				# Arrived at target — stab
				state = State.STAB
				_state_timer = STAB_DURATION
				velocity = Vector3.ZERO
				# Deal damage
				if player and global_position.distance_to(player.global_position) < STAB_RADIUS:
					if player.has_method("take_damage"):
						player.take_damage(STAB_DAMAGE)

		State.STAB:
			# Stuck in place — vulnerable to player bite!
			velocity = Vector3(0, -0.3, 0)
			# Can't move horizontally while stuck
			velocity.x = 0.0
			velocity.z = 0.0
			if _state_timer <= 0:
				state = State.RETREAT
				_dive_cooldown = DIVE_COOLDOWN

		State.RETREAT:
			# Fly back up
			var retreat_target_y: float = HOVER_HEIGHT
			if player:
				retreat_target_y = player.global_position.y + HOVER_HEIGHT
			var up_dir: Vector3 = Vector3(0, retreat_target_y - global_position.y, 0).normalized()
			# Also move horizontally away from dive point
			var horiz: Vector3 = Vector3(sin(_hover_angle), 0, cos(_hover_angle)) * 3.0
			velocity = (up_dir * RETREAT_SPEED + horiz)
			if global_position.y > retreat_target_y - 2.0:
				state = State.HOVER

	# Minimal gravity for floating feel
	if not is_on_floor():
		_vertical_velocity -= GRAVITY * delta
	else:
		_vertical_velocity = 0.0

	if state != State.DIVE and state != State.RETREAT:
		velocity.y += _vertical_velocity

	move_and_slide()

	# Damage flash decay
	if _damage_flash > 0:
		_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
		if _body_mesh and _body_mesh.material_override is StandardMaterial3D:
			var bmat: StandardMaterial3D = _body_mesh.material_override
			bmat.emission_energy_multiplier = 0.5 + _damage_flash * 5.0
			bmat.emission = Color(1.0, 0.2, 0.1).lerp(Color(0.6, 0.5, 0.3) * 0.2, 1.0 - _damage_flash)

	# Visual updates
	_update_visuals(delta)

func _update_visuals(delta: float) -> void:
	# Body bob
	var bob: float = sin(_time * 4.0) * 0.05
	if _body_mesh:
		_body_mesh.position.y = 0.6 + bob

	# Arms spread wider during dive
	var arm_spread: float = 0.0
	if state == State.DIVE:
		arm_spread = 20.0
	elif state == State.STAB:
		arm_spread = -10.0

	if _arm_l:
		var target_rot: float = deg_to_rad(40.0 + arm_spread)
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, target_rot, delta * 8.0)
	if _arm_r:
		var target_rot: float = deg_to_rad(-40.0 - arm_spread)
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, target_rot, delta * 8.0)

	# Tip glow pulse
	var tip_glow: float = 3.0 + sin(_time * 6.0) * 1.0
	if state == State.DIVE:
		tip_glow = 6.0
	elif state == State.STAB:
		tip_glow = 8.0
	if _tip_l and _tip_l.material_override:
		_tip_l.material_override.emission_energy_multiplier = tip_glow
	if _tip_r and _tip_r.material_override:
		_tip_r.material_override.emission_energy_multiplier = tip_glow

	# Eye intensity by state
	if _eye_mesh and _eye_mesh.material_override:
		var eye_energy: float = 4.0
		if state == State.DIVE:
			eye_energy = 8.0
		elif state == State.STAB:
			eye_energy = 2.0
		_eye_mesh.material_override.emission_energy_multiplier = lerpf(
			_eye_mesh.material_override.emission_energy_multiplier, eye_energy, delta * 6.0
		)

	# Face player
	var players: Array = get_tree().get_nodes_in_group("player_worm")
	if players.size() > 0:
		var to_player: Vector3 = players[0].global_position - global_position
		to_player.y = 0
		if to_player.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z), delta * 4.0)

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if health <= 0:
		_die()

func _die() -> void:
	died.emit(global_position)
	queue_free()

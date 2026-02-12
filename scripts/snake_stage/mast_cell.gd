extends CharacterBody3D
## Mast Cell: Ranged enemy. Fires histamine projectiles, stays at distance.
## States: PATROL → ALERT → FIRE → RETREAT
## Biomes: LUNG_TISSUE, HEART_CHAMBER

signal died(pos: Vector3)

enum State { PATROL, ALERT, FIRE, RETREAT, STUNNED }

var state: State = State.PATROL
var _time: float = 0.0
var _state_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var health: float = 30.0
var _vertical_velocity: float = 0.0
var _stun_timer: float = 0.0
var _fire_cooldown: float = 0.0
var _damage_flash: float = 0.0

# Detection
const BASE_DETECT_RADIUS: float = 30.0
const PATROL_SPEED: float = 1.5
const RETREAT_SPEED: float = 5.0
const RETREAT_RANGE: float = 8.0
const FIRE_RANGE: float = 20.0
const FIRE_INTERVAL: float = 3.0
const PROJECTILE_SPEED: float = 12.0
const PROJECTILE_DAMAGE: float = 10.0
const STUN_DURATION: float = 3.0
const GRAVITY: float = 20.0

# Visual refs
var _body_mesh: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _granules: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("mast_cell")
	_heading = randf() * TAU
	_state_timer = randf_range(2.0, 5.0)
	_build_body()

func _build_body() -> void:
	# Round granular body with surface bumps
	_body_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.4
	sphere.radial_segments = 16
	sphere.rings = 8
	_body_mesh.mesh = sphere

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.8, 0.5, 0.7, 0.7)
	_body_mat.roughness = 0.4
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.7, 0.3, 0.5) * 0.2
	_body_mat.emission_energy_multiplier = 0.5
	_body_mesh.material_override = _body_mat
	_body_mesh.position = Vector3(0, 0.7, 0)
	add_child(_body_mesh)

	# Histamine granules (small bright spheres on surface)
	for i in range(8):
		var granule: MeshInstance3D = MeshInstance3D.new()
		var g_sphere: SphereMesh = SphereMesh.new()
		g_sphere.radius = 0.1
		g_sphere.height = 0.2
		g_sphere.radial_segments = 8
		g_sphere.rings = 4
		granule.mesh = g_sphere

		var g_mat: StandardMaterial3D = StandardMaterial3D.new()
		g_mat.albedo_color = Color(1.0, 0.6, 0.2, 0.8)
		g_mat.roughness = 0.2
		g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g_mat.emission_enabled = true
		g_mat.emission = Color(1.0, 0.5, 0.15)
		g_mat.emission_energy_multiplier = 2.0
		granule.material_override = g_mat

		var angle: float = TAU * i / 8.0
		var elev: float = randf_range(-0.3, 0.3)
		granule.position = Vector3(cos(angle) * 0.55, 0.7 + elev, sin(angle) * 0.55)
		add_child(granule)
		_granules.append(granule)

	# Glow
	var aura: OmniLight3D = OmniLight3D.new()
	aura.light_color = Color(0.8, 0.4, 0.6)
	aura.light_energy = 0.4
	aura.omni_range = 4.0
	aura.shadow_enabled = false
	aura.position = Vector3(0, 0.7, 0)
	add_child(aura)

	# Collision shape
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 1.3
	col_shape.shape = capsule
	col_shape.position = Vector3(0, 0.7, 0)
	add_child(col_shape)

func _physics_process(delta: float) -> void:
	_time += delta
	_state_timer -= delta
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)

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
			_heading += sin(_time * 0.5) * delta * 0.7
			if _state_timer <= 0:
				_heading += randf_range(-PI * 0.4, PI * 0.4)
				_state_timer = randf_range(3.0, 6.0)
			if player and player_dist < detect_radius:
				state = State.ALERT
				_state_timer = 0.8

		State.ALERT:
			_speed = lerpf(_speed, 0.0, delta * 5.0)
			if player:
				var to_player: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_player.x, to_player.z), delta * 3.0)
			if _state_timer <= 0:
				if player and player_dist < FIRE_RANGE:
					state = State.FIRE
				elif player and player_dist < RETREAT_RANGE:
					state = State.RETREAT
					_state_timer = 2.0
				else:
					state = State.PATROL
					_state_timer = randf_range(2.0, 4.0)

		State.FIRE:
			_speed = lerpf(_speed, 0.5, delta * 3.0)
			if player:
				var to_player: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_player.x, to_player.z), delta * 3.0)

				# Fire projectile when ready
				if _fire_cooldown <= 0 and player_dist < FIRE_RANGE:
					_fire_projectile(player)
					_fire_cooldown = FIRE_INTERVAL

				# Retreat if player gets too close
				if player_dist < RETREAT_RANGE:
					state = State.RETREAT
					_state_timer = 2.5

				# Lost player
				if player_dist > detect_radius * 1.5:
					state = State.PATROL
					_state_timer = randf_range(2.0, 4.0)
			else:
				state = State.PATROL
				_state_timer = randf_range(2.0, 4.0)

		State.RETREAT:
			_speed = lerpf(_speed, RETREAT_SPEED, delta * 5.0)
			if player:
				var away: Vector3 = global_position - player.global_position
				_heading = lerp_angle(_heading, atan2(away.x, away.z), delta * 5.0)
			if _state_timer <= 0:
				if player and player_dist > RETREAT_RANGE * 1.5:
					state = State.FIRE
				else:
					state = State.PATROL
					_state_timer = randf_range(2.0, 4.0)

		State.STUNNED:
			_speed = lerpf(_speed, 0.0, delta * 10.0)
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

	# Damage flash
	if _damage_flash > 0:
		_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
		if _body_mat:
			_body_mat.emission_energy_multiplier = 0.5 + _damage_flash * 5.0

	# Granule pulse
	for i in range(_granules.size()):
		var g: MeshInstance3D = _granules[i]
		var pulse: float = 1.0 + sin(_time * 3.0 + i * 0.8) * 0.15
		g.scale = Vector3.ONE * pulse

func _fire_projectile(target: Node3D) -> void:
	## Launch a histamine projectile toward the player
	var proj: Area3D = Area3D.new()
	proj.name = "HistamineProjectile"
	proj.add_to_group("enemy_projectile")

	# Visual: small glowing sphere
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh.mesh = sphere

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.15, 0.9)
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	proj.add_child(mesh)

	# Light
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.1)
	light.light_energy = 0.5
	light.omni_range = 3.0
	light.shadow_enabled = false
	proj.add_child(light)

	# Collision
	var col: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 0.2
	col.shape = sphere_shape
	proj.add_child(col)

	# Direction toward target with slight arc
	var to_target: Vector3 = (target.global_position - global_position).normalized()
	to_target.y += 0.15  # Slight upward arc

	proj.global_position = global_position + Vector3(0, 0.8, 0) + to_target * 0.5
	proj.set_meta("direction", to_target)
	proj.set_meta("speed", PROJECTILE_SPEED)
	proj.set_meta("damage", PROJECTILE_DAMAGE)
	proj.set_meta("lifetime", 3.0)

	# Add projectile behavior via script
	var proj_script: GDScript = GDScript.new()
	proj_script.source_code = _PROJECTILE_CODE
	proj_script.reload()
	proj.set_script(proj_script)

	get_tree().root.add_child(proj)

const _PROJECTILE_CODE: String = """
extends Area3D

var _dir: Vector3 = Vector3.FORWARD
var _spd: float = 12.0
var _dmg: float = 10.0
var _life: float = 3.0

func _ready() -> void:
	_dir = get_meta(\"direction\", Vector3.FORWARD)
	_spd = get_meta(\"speed\", 12.0)
	_dmg = get_meta(\"damage\", 10.0)
	_life = get_meta(\"lifetime\", 3.0)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	global_position += _dir * _spd * delta
	_dir.y -= 1.5 * delta  # Gravity arc
	_life -= delta
	if _life <= 0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(\"player_worm\"):
		if body.has_method(\"take_damage\"):
			body.take_damage(_dmg)
		queue_free()
	elif not body.is_in_group(\"mast_cell\") and not body.is_in_group(\"enemy_projectile\"):
		queue_free()
"""

func stun(duration: float = STUN_DURATION) -> void:
	state = State.STUNNED
	_stun_timer = duration
	_speed = 0.0

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if state == State.PATROL:
		state = State.RETREAT
		_state_timer = 2.0
	if health <= 0:
		_die()

func _die() -> void:
	died.emit(global_position)
	queue_free()

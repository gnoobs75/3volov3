extends CharacterBody3D
## Alveolar Titan: Boss of the LUNG_TISSUE biome.
## Spongy, inflatable creature. Wind gust knockback, oxygen bubble traps.
## Phases: PATROL → ALERT → GUST → BUBBLE → RAGE

signal died(pos: Vector3)
signal defeated

enum Phase { PATROL, ALERT, GUST, BUBBLE, RAGE }

var phase: Phase = Phase.PATROL
var _time: float = 0.0
var _phase_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var _vertical_velocity: float = 0.0

var health: float = 220.0
var max_health: float = 220.0
var _damage_flash: float = 0.0
var _inflate: float = 1.0  # 1.0 = normal, 1.4 = inflated

const DETECT_RADIUS: float = 45.0
const PATROL_SPEED: float = 2.0
const CHASE_SPEED: float = 4.5
const RAGE_SPEED: float = 7.0
const ATTACK_RANGE: float = 4.0
const ATTACK_DAMAGE: float = 10.0
const GUST_DAMAGE: float = 8.0
const GUST_RADIUS: float = 15.0
const GUST_KNOCKBACK: float = 20.0
const GRAVITY: float = 20.0

var _attack_cooldown: float = 0.0
var _gust_cooldown: float = 0.0
var _bubble_cooldown: float = 0.0

var _body_mesh: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _aura_light: OmniLight3D = null
var _alveoli: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("boss")
	_heading = randf() * TAU
	_phase_timer = randf_range(3.0, 5.0)
	_build_body()

func _build_body() -> void:
	_body_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.8
	sphere.height = 3.6
	sphere.radial_segments = 20
	sphere.rings = 10
	_body_mesh.mesh = sphere

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.75, 0.65, 0.7, 0.6)
	_body_mat.roughness = 0.3
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.6, 0.5, 0.55) * 0.2
	_body_mat.emission_energy_multiplier = 0.5
	_body_mesh.material_override = _body_mat
	_body_mesh.position = Vector3(0, 1.8, 0)
	add_child(_body_mesh)

	# Alveolar sacs (spongy bumps)
	for i in range(10):
		var sac: MeshInstance3D = MeshInstance3D.new()
		var s: SphereMesh = SphereMesh.new()
		s.radius = randf_range(0.3, 0.5)
		s.height = s.radius * 2.0
		s.radial_segments = 10
		s.rings = 5
		sac.mesh = s
		var s_mat: StandardMaterial3D = StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.8, 0.7, 0.75, 0.4)
		s_mat.roughness = 0.2
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s_mat.emission_enabled = true
		s_mat.emission = Color(0.7, 0.6, 0.65)
		s_mat.emission_energy_multiplier = 0.8
		sac.material_override = s_mat
		var phi: float = TAU * i / 10.0
		var elev: float = randf_range(-0.5, 0.5)
		sac.position = Vector3(cos(phi) * 1.5, 1.8 + elev, sin(phi) * 1.5)
		add_child(sac)
		_alveoli.append(sac)

	_aura_light = OmniLight3D.new()
	_aura_light.light_color = Color(0.7, 0.6, 0.65)
	_aura_light.light_energy = 1.5
	_aura_light.omni_range = 15.0
	_aura_light.shadow_enabled = true
	_aura_light.position = Vector3(0, 2.0, 0)
	add_child(_aura_light)

	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 1.6
	cap.height = 3.5
	col.shape = cap
	col.position = Vector3(0, 1.8, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	_time += delta
	_phase_timer -= delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_gust_cooldown = maxf(_gust_cooldown - delta, 0.0)
	_bubble_cooldown = maxf(_bubble_cooldown - delta, 0.0)

	var players: Array = get_tree().get_nodes_in_group("player_worm")
	var player: Node3D = players[0] if players.size() > 0 else null
	var player_dist: float = INF
	if player:
		player_dist = global_position.distance_to(player.global_position)

	if health / max_health <= 0.25 and phase != Phase.RAGE:
		phase = Phase.RAGE

	match phase:
		Phase.PATROL:
			_inflate = lerpf(_inflate, 1.0, delta * 2.0)
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
			_inflate = lerpf(_inflate, 1.2, delta * 3.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 3.0)
			if _phase_timer <= 0:
				phase = Phase.GUST

		Phase.GUST:
			_speed = lerpf(_speed, CHASE_SPEED, delta * 3.0)
			_inflate = lerpf(_inflate, 1.0, delta * 2.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 4.0)
				if _gust_cooldown <= 0 and player_dist < GUST_RADIUS:
					_do_wind_gust()
					_gust_cooldown = 5.0
					_inflate = 1.4
				if player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE)
					_attack_cooldown = 1.3
			if _bubble_cooldown <= 0:
				_spawn_bubble_trap()
				_bubble_cooldown = 8.0
				phase = Phase.BUBBLE
				_phase_timer = 3.0

		Phase.BUBBLE:
			_speed = lerpf(_speed, CHASE_SPEED * 0.6, delta * 3.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 3.0)
			if _phase_timer <= 0:
				phase = Phase.GUST

		Phase.RAGE:
			_speed = lerpf(_speed, RAGE_SPEED, delta * 4.0)
			_inflate = 1.0 + sin(_time * 5.0) * 0.15
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 6.0)
				if _gust_cooldown <= 0 and player_dist < GUST_RADIUS * 1.3:
					_do_wind_gust()
					_gust_cooldown = 3.0
				if player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE * 1.5)
					_attack_cooldown = 0.7

	var forward: Vector3 = Vector3(sin(_heading), 0, cos(_heading))
	if not is_on_floor():
		_vertical_velocity -= GRAVITY * delta
	else:
		_vertical_velocity = -0.5
	velocity = Vector3(forward.x * _speed, _vertical_velocity, forward.z * _speed)
	move_and_slide()
	rotation.y = _heading

	if _damage_flash > 0:
		_damage_flash = maxf(_damage_flash - delta * 3.0, 0.0)
		if _body_mat:
			_body_mat.emission_energy_multiplier = 0.5 + _damage_flash * 5.0

	_update_visuals(delta)

func _update_visuals(delta: float) -> void:
	# Breathing inflation
	var breath: float = sin(_time * 1.8) * 0.03
	var scale_val: float = _inflate + breath
	if _body_mesh:
		_body_mesh.scale = Vector3(scale_val, scale_val * 0.9, scale_val)
	for i in range(_alveoli.size()):
		var sac: MeshInstance3D = _alveoli[i]
		var sac_pulse: float = 1.0 + sin(_time * 2.5 + i * 0.6) * 0.1 * _inflate
		sac.scale = Vector3.ONE * sac_pulse

func _do_wind_gust() -> void:
	for target in get_tree().get_nodes_in_group("player_worm"):
		var dist: float = global_position.distance_to(target.global_position)
		if dist < GUST_RADIUS:
			var falloff: float = 1.0 - dist / GUST_RADIUS
			if target.has_method("take_damage"):
				target.take_damage(GUST_DAMAGE * falloff)
			if target is CharacterBody3D:
				var push: Vector3 = (target.global_position - global_position).normalized()
				push.y = 0.8
				target.velocity += push * GUST_KNOCKBACK * falloff

func _spawn_bubble_trap() -> void:
	# Oxygen bubble: slowing hazard area
	var pool_script = load("res://scripts/snake_stage/fluid_pool.gd")
	if not pool_script:
		return
	var bubble: Node3D = Node3D.new()
	bubble.set_script(pool_script)
	bubble.setup(4.0, Color(0.6, 0.8, 0.9, 0.25), "slow", 0.0, 0.4)
	var offset: Vector3 = Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	bubble.global_position = global_position + offset
	bubble.global_position.y = global_position.y - 1.5
	get_parent().add_child(bubble)
	get_tree().create_timer(12.0).timeout.connect(bubble.queue_free)

func stun(duration: float = 2.0) -> void:
	phase = Phase.ALERT
	_phase_timer = duration * 0.5
	_speed = 0.0

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if phase == Phase.PATROL:
		phase = Phase.ALERT
		_phase_timer = 1.0
	if health <= 0:
		_die()

func _die() -> void:
	died.emit(global_position)
	defeated.emit()
	queue_free()

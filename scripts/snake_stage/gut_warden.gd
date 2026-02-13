extends CharacterBody3D
## Gut Warden: Boss of the INTESTINAL_TRACT biome.
## Tentacle-covered, acid-spewing guardian. Creates acid pools, vine grabs.
## Phases: PATROL → ALERT → ATTACK → ACID_SPRAY → RAGE

signal died(pos: Vector3)
signal defeated

enum Phase { PATROL, ALERT, ATTACK, ACID_SPRAY, RAGE }

var phase: Phase = Phase.PATROL
var _time: float = 0.0
var _phase_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var _vertical_velocity: float = 0.0

var health: float = 280.0
var max_health: float = 280.0
var _damage_flash: float = 0.0

const DETECT_RADIUS: float = 40.0
const PATROL_SPEED: float = 1.2
const CHASE_SPEED: float = 3.5
const RAGE_SPEED: float = 5.5
const ATTACK_RANGE: float = 4.5
const ATTACK_DAMAGE: float = 12.0
const SPRAY_DAMAGE: float = 8.0
const SPRAY_RADIUS: float = 10.0
const GRAVITY: float = 20.0

var _attack_cooldown: float = 0.0
var _spray_cooldown: float = 0.0
var _pool_cooldown: float = 0.0
var _voice_cooldown: float = 0.0

var _body_mesh: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _aura_light: OmniLight3D = null
var _tentacles: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("boss")
	_heading = randf() * TAU
	_phase_timer = randf_range(3.0, 5.0)
	_build_body()

func _build_body() -> void:
	_body_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 2.2
	sphere.height = 4.0
	sphere.radial_segments = 20
	sphere.rings = 10
	_body_mesh.mesh = sphere

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.45, 0.3, 0.2, 0.7)
	_body_mat.roughness = 0.6
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.4, 0.25, 0.15) * 0.2
	_body_mat.emission_energy_multiplier = 0.5
	_body_mesh.material_override = _body_mat
	_body_mesh.position = Vector3(0, 2.0, 0)
	add_child(_body_mesh)

	# Tentacle vines
	for i in range(8):
		var tent: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.25
		cyl.height = 2.0
		cyl.radial_segments = 6
		tent.mesh = cyl
		var t_mat: StandardMaterial3D = StandardMaterial3D.new()
		t_mat.albedo_color = Color(0.35, 0.25, 0.15, 0.6)
		t_mat.roughness = 0.5
		t_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		t_mat.emission_enabled = true
		t_mat.emission = Color(0.3, 0.5, 0.1)
		t_mat.emission_energy_multiplier = 0.4
		tent.material_override = t_mat
		var angle: float = TAU * i / 8.0
		tent.position = Vector3(cos(angle) * 1.6, 1.0, sin(angle) * 1.6)
		tent.rotation.z = cos(angle) * 0.4
		tent.rotation.x = sin(angle) * 0.4
		add_child(tent)
		_tentacles.append(tent)

	# Acid-green mouth glow
	var mouth_light: OmniLight3D = OmniLight3D.new()
	mouth_light.light_color = Color(0.3, 0.7, 0.1)
	mouth_light.light_energy = 1.0
	mouth_light.omni_range = 6.0
	mouth_light.shadow_enabled = false
	mouth_light.position = Vector3(0, 1.5, 1.5)
	add_child(mouth_light)

	_aura_light = OmniLight3D.new()
	_aura_light.light_color = Color(0.4, 0.3, 0.15)
	_aura_light.light_energy = 1.5
	_aura_light.omni_range = 15.0
	_aura_light.shadow_enabled = true
	_aura_light.position = Vector3(0, 2.0, 0)
	add_child(_aura_light)

	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 1.8
	cap.height = 3.8
	col.shape = cap
	col.position = Vector3(0, 2.0, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	_time += delta
	_phase_timer -= delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_spray_cooldown = maxf(_spray_cooldown - delta, 0.0)
	_pool_cooldown = maxf(_pool_cooldown - delta, 0.0)
	_voice_cooldown = maxf(_voice_cooldown - delta, 0.0)

	var players: Array = get_tree().get_nodes_in_group("player_worm")
	var player: Node3D = players[0] if players.size() > 0 else null
	var player_dist: float = INF
	if player:
		player_dist = global_position.distance_to(player.global_position)

	if health / max_health <= 0.25 and phase != Phase.RAGE:
		phase = Phase.RAGE
		_phase_timer = 0.0
		if _voice_cooldown <= 0:
			AudioManager.play_creature_voice("gut_warden", "attack", 1.8, 0.8, 0.8)
			_voice_cooldown = 4.0

	match phase:
		Phase.PATROL:
			_speed = lerpf(_speed, PATROL_SPEED, delta * 3.0)
			_heading += sin(_time * 0.4) * delta * 0.5
			if _phase_timer <= 0:
				_heading += randf_range(-PI * 0.3, PI * 0.3)
				_phase_timer = randf_range(3.0, 6.0)
			if player and player_dist < DETECT_RADIUS:
				phase = Phase.ALERT
				_phase_timer = 1.5

		Phase.ALERT:
			_speed = lerpf(_speed, 0.0, delta * 4.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 3.0)
			if _phase_timer <= 0:
				phase = Phase.ATTACK

		Phase.ATTACK:
			_speed = lerpf(_speed, CHASE_SPEED, delta * 3.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 4.0)
				if player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE)
					_attack_cooldown = 1.5
				# Spray acid at range
				if _spray_cooldown <= 0 and player_dist < SPRAY_RADIUS:
					_spray_acid(player)
					_spray_cooldown = 4.0
				# Drop acid pools periodically
				if _pool_cooldown <= 0:
					_drop_acid_pool()
					_pool_cooldown = 8.0
			if player and player_dist > DETECT_RADIUS * 2.0:
				phase = Phase.PATROL
				_phase_timer = 3.0

		Phase.RAGE:
			_speed = lerpf(_speed, RAGE_SPEED, delta * 4.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 6.0)
				if player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE * 1.5)
					_attack_cooldown = 0.8
				if _spray_cooldown <= 0 and player_dist < SPRAY_RADIUS * 1.3:
					_spray_acid(player)
					_spray_cooldown = 2.5
				if _pool_cooldown <= 0:
					_drop_acid_pool()
					_pool_cooldown = 5.0

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
	var pulse: float = 1.0 + sin(_time * 1.5) * 0.04
	if _body_mesh:
		_body_mesh.scale = Vector3(pulse, pulse * 0.95, pulse)
	for i in range(_tentacles.size()):
		var t: MeshInstance3D = _tentacles[i]
		var angle: float = TAU * i / _tentacles.size()
		var wobble: float = sin(_time * 2.0 + i * 1.2) * 0.2
		var reach: float = 1.6 + sin(_time * 1.3 + i * 0.7) * 0.3
		t.position = Vector3(cos(angle + wobble) * reach, 1.0, sin(angle + wobble) * reach)
		t.rotation.z = cos(angle + wobble) * 0.5
		t.rotation.x = sin(angle + wobble) * 0.5

func _spray_acid(player: Node3D) -> void:
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("gut_warden", "attack", 1.8, 0.8, 0.8)
		_voice_cooldown = 4.0
	var dist: float = global_position.distance_to(player.global_position)
	if dist < SPRAY_RADIUS:
		var falloff: float = 1.0 - dist / SPRAY_RADIUS
		if player.has_method("take_damage"):
			player.take_damage(SPRAY_DAMAGE * falloff)

func _drop_acid_pool() -> void:
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("gut_warden", "attack", 1.8, 0.8, 0.8)
		_voice_cooldown = 4.0
	var pool_script = load("res://scripts/snake_stage/fluid_pool.gd")
	if not pool_script:
		return
	var pool: Node3D = Node3D.new()
	pool.set_script(pool_script)
	pool.setup(3.0, Color(0.3, 0.5, 0.1, 0.5), "acid", 4.0, 1.0)
	pool.global_position = global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
	pool.global_position.y = global_position.y - 1.5
	get_parent().add_child(pool)
	# Auto-remove after 15s
	get_tree().create_timer(15.0).timeout.connect(pool.queue_free)

func stun(duration: float = 2.0) -> void:
	phase = Phase.ALERT
	_phase_timer = duration * 0.5
	_speed = 0.0

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("gut_warden", "hurt", 1.8, 0.8, 0.8)
		_voice_cooldown = 3.0
	if phase == Phase.PATROL:
		phase = Phase.ALERT
		_phase_timer = 1.0
	if health <= 0:
		_die()

func _die() -> void:
	AudioManager.play_creature_voice("gut_warden", "death", 1.8, 0.8, 0.8)
	died.emit(global_position)
	defeated.emit()
	queue_free()

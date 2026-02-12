extends CharacterBody3D
## Marrow Sentinel: Boss of the BONE_MARROW biome.
## Armored bone construct. Bone spike eruptions, calcium shield, summons T-cells.
## Phases: PATROL → ALERT → SPIKES → SHIELD → RAGE
## Hardest boss: highest HP, temporary invulnerability.

signal died(pos: Vector3)
signal defeated

enum Phase { PATROL, ALERT, SPIKES, SHIELD, RAGE }

var phase: Phase = Phase.PATROL
var _time: float = 0.0
var _phase_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var _vertical_velocity: float = 0.0

var health: float = 300.0
var max_health: float = 300.0
var _damage_flash: float = 0.0
var _shielded: bool = false
var _shield_timer: float = 0.0

const DETECT_RADIUS: float = 40.0
const PATROL_SPEED: float = 1.0
const CHASE_SPEED: float = 3.0
const RAGE_SPEED: float = 5.0
const ATTACK_RANGE: float = 5.0
const ATTACK_DAMAGE: float = 15.0
const SPIKE_DAMAGE: float = 20.0
const SPIKE_RADIUS: float = 10.0
const SHIELD_DURATION: float = 4.0
const GRAVITY: float = 20.0

var _attack_cooldown: float = 0.0
var _spike_cooldown: float = 0.0
var _shield_cooldown: float = 0.0
var _summon_timer: float = 0.0
var _minions_alive: int = 0

var _body_mesh: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _shield_mesh: MeshInstance3D = null
var _aura_light: OmniLight3D = null
var _bone_plates: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("boss")
	_heading = randf() * TAU
	_phase_timer = randf_range(3.0, 5.0)
	_build_body()

func _build_body() -> void:
	_body_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 2.0
	sphere.height = 4.2
	sphere.radial_segments = 18
	sphere.rings = 9
	_body_mesh.mesh = sphere

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.85, 0.8, 0.65, 0.8)
	_body_mat.roughness = 0.7
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.7, 0.65, 0.45) * 0.15
	_body_mat.emission_energy_multiplier = 0.4
	_body_mesh.material_override = _body_mat
	_body_mesh.position = Vector3(0, 2.1, 0)
	add_child(_body_mesh)

	# Bone armor plates
	for i in range(6):
		var plate: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.8, 1.2, 0.15)
		plate.mesh = box
		var p_mat: StandardMaterial3D = StandardMaterial3D.new()
		p_mat.albedo_color = Color(0.9, 0.88, 0.75)
		p_mat.roughness = 0.8
		p_mat.emission_enabled = true
		p_mat.emission = Color(0.8, 0.75, 0.5)
		p_mat.emission_energy_multiplier = 0.3
		plate.material_override = p_mat
		var angle: float = TAU * i / 6.0
		plate.position = Vector3(cos(angle) * 1.7, 2.1 + sin(i) * 0.3, sin(angle) * 1.7)
		plate.rotation.y = angle
		add_child(plate)
		_bone_plates.append(plate)

	# Shield sphere (hidden until activated)
	_shield_mesh = MeshInstance3D.new()
	var shield_s: SphereMesh = SphereMesh.new()
	shield_s.radius = 3.0
	shield_s.height = 6.0
	shield_s.radial_segments = 24
	shield_s.rings = 12
	_shield_mesh.mesh = shield_s
	var shield_mat: StandardMaterial3D = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.95, 0.9, 0.7, 0.2)
	shield_mat.roughness = 0.1
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.emission_enabled = true
	shield_mat.emission = Color(0.9, 0.85, 0.6)
	shield_mat.emission_energy_multiplier = 2.0
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield_mesh.material_override = shield_mat
	_shield_mesh.position = Vector3(0, 2.1, 0)
	_shield_mesh.visible = false
	add_child(_shield_mesh)

	_aura_light = OmniLight3D.new()
	_aura_light.light_color = Color(0.8, 0.75, 0.5)
	_aura_light.light_energy = 1.5
	_aura_light.omni_range = 15.0
	_aura_light.shadow_enabled = true
	_aura_light.position = Vector3(0, 2.5, 0)
	add_child(_aura_light)

	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 1.8
	cap.height = 4.0
	col.shape = cap
	col.position = Vector3(0, 2.1, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	_time += delta
	_phase_timer -= delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_spike_cooldown = maxf(_spike_cooldown - delta, 0.0)
	_shield_cooldown = maxf(_shield_cooldown - delta, 0.0)
	_summon_timer += delta

	# Shield timer
	if _shielded:
		_shield_timer -= delta
		if _shield_timer <= 0:
			_shielded = false
			_shield_mesh.visible = false

	var players: Array = get_tree().get_nodes_in_group("player_worm")
	var player: Node3D = players[0] if players.size() > 0 else null
	var player_dist: float = INF
	if player:
		player_dist = global_position.distance_to(player.global_position)

	if health / max_health <= 0.25 and phase != Phase.RAGE:
		phase = Phase.RAGE

	match phase:
		Phase.PATROL:
			_speed = lerpf(_speed, PATROL_SPEED, delta * 3.0)
			_heading += sin(_time * 0.4) * delta * 0.4
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
				phase = Phase.SPIKES

		Phase.SPIKES:
			_speed = lerpf(_speed, CHASE_SPEED, delta * 3.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 4.0)
				if _spike_cooldown <= 0 and player_dist < SPIKE_RADIUS:
					_eruption_spikes()
					_spike_cooldown = 6.0
				if player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE)
					_attack_cooldown = 1.5
			# Shield phase on timer
			if _shield_cooldown <= 0 and health / max_health < 0.7:
				phase = Phase.SHIELD
				_phase_timer = SHIELD_DURATION + 1.0
				_activate_shield()
				_shield_cooldown = 20.0
			# Summon minions
			if _summon_timer >= 18.0 and _minions_alive < 4:
				_summon_timer = 0.0
				_summon_t_cells()

		Phase.SHIELD:
			_speed = lerpf(_speed, 0.0, delta * 5.0)
			if _phase_timer <= 0 or not _shielded:
				phase = Phase.SPIKES

		Phase.RAGE:
			_speed = lerpf(_speed, RAGE_SPEED, delta * 4.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 6.0)
				if _spike_cooldown <= 0 and player_dist < SPIKE_RADIUS * 1.3:
					_eruption_spikes()
					_spike_cooldown = 3.0
				if player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE * 1.5)
					_attack_cooldown = 0.8
			if _summon_timer >= 12.0 and _minions_alive < 6:
				_summon_timer = 0.0
				_summon_t_cells()

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
			_body_mat.emission_energy_multiplier = 0.4 + _damage_flash * 5.0

	_update_visuals(delta)

func _update_visuals(delta: float) -> void:
	var pulse: float = 1.0 + sin(_time * 1.2) * 0.03
	if _body_mesh:
		_body_mesh.scale = Vector3(pulse, pulse, pulse)
	# Shield glow pulse
	if _shield_mesh and _shielded:
		_shield_mesh.scale = Vector3.ONE * (1.0 + sin(_time * 4.0) * 0.05)
	# Bone plates rattle in rage
	if phase == Phase.RAGE:
		for i in range(_bone_plates.size()):
			_bone_plates[i].position.y = 2.1 + sin(i) * 0.3 + sin(_time * 8.0 + i) * 0.1

func _eruption_spikes() -> void:
	for target in get_tree().get_nodes_in_group("player_worm"):
		var dist: float = global_position.distance_to(target.global_position)
		if dist < SPIKE_RADIUS:
			var falloff: float = 1.0 - dist / SPIKE_RADIUS
			if target.has_method("take_damage"):
				target.take_damage(SPIKE_DAMAGE * falloff)
			if target is CharacterBody3D:
				target.velocity.y += 8.0 * falloff

func _activate_shield() -> void:
	_shielded = true
	_shield_timer = SHIELD_DURATION
	_shield_mesh.visible = true

func _summon_t_cells() -> void:
	var ktc_script = load("res://scripts/snake_stage/killer_t_cell.gd")
	if not ktc_script:
		return
	for i in range(2):
		var minion: CharacterBody3D = CharacterBody3D.new()
		minion.set_script(ktc_script)
		var angle: float = TAU * i / 2.0 + randf() * 0.5
		minion.position = global_position + Vector3(cos(angle) * 5.0, 0.5, sin(angle) * 5.0)
		var col: CollisionShape3D = CollisionShape3D.new()
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.5
		cap.height = 1.2
		col.shape = cap
		col.position = Vector3(0, 0.7, 0)
		minion.add_child(col)
		get_parent().add_child(minion)
		_minions_alive += 1
		if minion.has_signal("died"):
			minion.died.connect(func(_pos): _minions_alive = maxi(_minions_alive - 1, 0))

func stun(duration: float = 2.0) -> void:
	if _shielded:
		return  # Shield blocks stuns
	phase = Phase.ALERT
	_phase_timer = duration * 0.5
	_speed = 0.0

func take_damage(amount: float) -> void:
	if _shielded:
		return  # Shield blocks all damage
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

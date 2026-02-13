extends CharacterBody3D
## Cardiac Colossus: Boss of the HEART_CHAMBER biome.
## Massive pulsing heart-muscle creature. Rhythmic pulse attacks, blood wave knockback.
## Phases: PATROL → PULSE → SUMMON → RAGE (at 25% HP)

signal died(pos: Vector3)
signal defeated

enum Phase { PATROL, ALERT, PULSE, SUMMON, RAGE }

var phase: Phase = Phase.PATROL
var _time: float = 0.0
var _phase_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var _vertical_velocity: float = 0.0

var health: float = 250.0
var max_health: float = 250.0
var _damage_flash: float = 0.0

const DETECT_RADIUS: float = 45.0
const PATROL_SPEED: float = 1.5
const CHASE_SPEED: float = 4.0
const RAGE_SPEED: float = 6.0
const ATTACK_RANGE: float = 5.0
const ATTACK_DAMAGE: float = 12.0
const PULSE_DAMAGE: float = 15.0
const PULSE_RADIUS: float = 12.0
const PULSE_KNOCKBACK: float = 15.0
const GRAVITY: float = 20.0

var _attack_cooldown: float = 0.0
var _pulse_cooldown: float = 0.0
var _voice_cooldown: float = 0.0
var _summon_timer: float = 0.0
var _minions_alive: int = 0

var _body_mesh: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _aura_light: OmniLight3D = null
var _ventricles: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("boss")
	_heading = randf() * TAU
	_phase_timer = randf_range(3.0, 5.0)
	_build_body()

func _build_body() -> void:
	# Massive heart-shaped body
	_body_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 2.0
	sphere.height = 4.5
	sphere.radial_segments = 20
	sphere.rings = 10
	_body_mesh.mesh = sphere

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.7, 0.15, 0.12, 0.75)
	_body_mat.roughness = 0.4
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.8, 0.15, 0.1) * 0.3
	_body_mat.emission_energy_multiplier = 0.8
	_body_mesh.material_override = _body_mat
	_body_mesh.position = Vector3(0, 2.2, 0)
	add_child(_body_mesh)

	# Ventricle bulges
	for i in range(4):
		var vent: MeshInstance3D = MeshInstance3D.new()
		var v_sphere: SphereMesh = SphereMesh.new()
		v_sphere.radius = 0.8
		v_sphere.height = 1.6
		v_sphere.radial_segments = 12
		v_sphere.rings = 6
		vent.mesh = v_sphere
		var v_mat: StandardMaterial3D = StandardMaterial3D.new()
		v_mat.albedo_color = Color(0.6, 0.1, 0.08, 0.65)
		v_mat.roughness = 0.5
		v_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		v_mat.emission_enabled = true
		v_mat.emission = Color(0.7, 0.12, 0.08)
		v_mat.emission_energy_multiplier = 1.2
		vent.material_override = v_mat
		var angle: float = TAU * i / 4.0
		vent.position = Vector3(cos(angle) * 1.4, 2.2 + sin(i * 1.5) * 0.5, sin(angle) * 1.4)
		add_child(vent)
		_ventricles.append(vent)

	# Arteries (tubes extending outward)
	for i in range(3):
		var artery: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.3
		cyl.height = 1.5
		cyl.radial_segments = 8
		artery.mesh = cyl
		var a_mat: StandardMaterial3D = StandardMaterial3D.new()
		a_mat.albedo_color = Color(0.6, 0.08, 0.05, 0.6)
		a_mat.roughness = 0.4
		a_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		a_mat.emission_enabled = true
		a_mat.emission = Color(0.5, 0.1, 0.05) * 0.2
		a_mat.emission_energy_multiplier = 0.4
		artery.material_override = a_mat
		var angle: float = TAU * i / 3.0
		artery.position = Vector3(cos(angle) * 1.8, 3.5, sin(angle) * 1.8)
		artery.rotation.z = cos(angle) * 0.5
		artery.rotation.x = sin(angle) * 0.5
		add_child(artery)

	# Aura
	_aura_light = OmniLight3D.new()
	_aura_light.light_color = Color(0.8, 0.15, 0.1)
	_aura_light.light_energy = 2.0
	_aura_light.omni_range = 18.0
	_aura_light.shadow_enabled = true
	_aura_light.position = Vector3(0, 2.5, 0)
	add_child(_aura_light)

	# Collision
	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 1.8
	cap.height = 4.0
	col.shape = cap
	col.position = Vector3(0, 2.2, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	_time += delta
	_phase_timer -= delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_pulse_cooldown = maxf(_pulse_cooldown - delta, 0.0)
	_voice_cooldown = maxf(_voice_cooldown - delta, 0.0)
	_summon_timer += delta

	var players: Array = get_tree().get_nodes_in_group("player_worm")
	var player: Node3D = players[0] if players.size() > 0 else null
	var player_dist: float = INF
	if player:
		player_dist = global_position.distance_to(player.global_position)

	if health / max_health <= 0.25 and phase != Phase.RAGE:
		phase = Phase.RAGE
		_phase_timer = 0.0
		if _voice_cooldown <= 0:
			AudioManager.play_creature_voice("cardiac_colossus", "attack", 2.0, 0.85, 0.7)
			_voice_cooldown = 4.0

	match phase:
		Phase.PATROL:
			_speed = lerpf(_speed, PATROL_SPEED, delta * 3.0)
			_heading += sin(_time * 0.5) * delta * 0.4
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
				phase = Phase.PULSE
				_phase_timer = 3.0

		Phase.PULSE:
			_speed = lerpf(_speed, CHASE_SPEED, delta * 3.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 3.0)
				# Rhythmic pulse attack (synced to heartbeat ~1.2s)
				if _pulse_cooldown <= 0 and player_dist < PULSE_RADIUS:
					_do_pulse_attack()
					_pulse_cooldown = 1.4
				if player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE)
					_attack_cooldown = 1.2
			if _summon_timer >= 15.0 and _minions_alive < 4:
				_summon_timer = 0.0
				phase = Phase.SUMMON
				_phase_timer = 2.0

		Phase.SUMMON:
			_speed = lerpf(_speed, 0.0, delta * 5.0)
			if _phase_timer <= 0:
				_summon_rbc_swarm()
				phase = Phase.PULSE
				_phase_timer = 5.0

		Phase.RAGE:
			_speed = lerpf(_speed, RAGE_SPEED, delta * 4.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 6.0)
				if _pulse_cooldown <= 0 and player_dist < PULSE_RADIUS * 1.3:
					_do_pulse_attack()
					_pulse_cooldown = 0.8
				if player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE * 1.5)
					_attack_cooldown = 0.8
			if _summon_timer >= 10.0 and _minions_alive < 6:
				_summon_timer = 0.0
				_summon_rbc_swarm()

	# Movement
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
			_body_mat.emission_energy_multiplier = 0.8 + _damage_flash * 5.0

	_update_visuals(delta)

func _update_visuals(delta: float) -> void:
	# Heartbeat pulse (expands on beat)
	var beat: float = sin(_time * 4.5)
	var pulse_scale: float = 1.0 + maxf(beat, 0.0) * 0.08
	if phase == Phase.RAGE:
		pulse_scale = 1.0 + maxf(sin(_time * 7.0), 0.0) * 0.12
	if _body_mesh:
		_body_mesh.scale = Vector3(pulse_scale, pulse_scale * 0.95, pulse_scale)
	for i in range(_ventricles.size()):
		var v: MeshInstance3D = _ventricles[i]
		var v_pulse: float = 1.0 + maxf(sin(_time * 4.5 + i * 0.3), 0.0) * 0.15
		v.scale = Vector3.ONE * v_pulse
	if _aura_light:
		var target_e: float = 2.0 + maxf(beat, 0.0) * 1.5
		if phase == Phase.RAGE:
			target_e = 3.5 + sin(_time * 8.0) * 1.5
		_aura_light.light_energy = lerpf(_aura_light.light_energy, target_e, delta * 4.0)

func _do_pulse_attack() -> void:
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("cardiac_colossus", "attack", 2.0, 0.85, 0.7)
		_voice_cooldown = 4.0
	for target in get_tree().get_nodes_in_group("player_worm"):
		var dist: float = global_position.distance_to(target.global_position)
		if dist < PULSE_RADIUS:
			var falloff: float = 1.0 - dist / PULSE_RADIUS
			if target.has_method("take_damage"):
				target.take_damage(PULSE_DAMAGE * falloff)
			if target is CharacterBody3D:
				var push: Vector3 = (target.global_position - global_position).normalized()
				push.y = 0.5
				target.velocity += push * PULSE_KNOCKBACK * falloff

func _summon_rbc_swarm() -> void:
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("cardiac_colossus", "attack", 2.0, 0.85, 0.7)
		_voice_cooldown = 4.0
	# Summon red blood cell swarm (uses WBC script as fast weak minions)
	var wbc_script = load("res://scripts/snake_stage/white_blood_cell.gd")
	for i in range(3):
		var minion: CharacterBody3D = CharacterBody3D.new()
		minion.set_script(wbc_script)
		var angle: float = TAU * i / 3.0 + randf() * 0.5
		minion.position = global_position + Vector3(cos(angle) * 5.0, 0.5, sin(angle) * 5.0)
		var col: CollisionShape3D = CollisionShape3D.new()
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.7
		cap.height = 1.6
		col.shape = cap
		col.position = Vector3(0, 0.8, 0)
		minion.add_child(col)
		get_parent().add_child(minion)
		_minions_alive += 1
		if minion.has_signal("died"):
			minion.died.connect(func(_pos): _minions_alive = maxi(_minions_alive - 1, 0))

func stun(duration: float = 2.0) -> void:
	phase = Phase.ALERT
	_phase_timer = duration * 0.5
	_speed = 0.0

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("cardiac_colossus", "hurt", 2.0, 0.85, 0.7)
		_voice_cooldown = 3.0
	if phase == Phase.PATROL:
		phase = Phase.ALERT
		_phase_timer = 1.0
	if health <= 0:
		_die()

func _die() -> void:
	AudioManager.play_creature_voice("cardiac_colossus", "death", 2.0, 0.85, 0.7)
	died.emit(global_position)
	defeated.emit()
	queue_free()

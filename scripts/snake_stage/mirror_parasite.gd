extends CharacterBody3D
## Mirror Parasite: Final boss of the game.
## A dark copy of the player that uses all 5 boss traits.
## Spawns in the Stomach hub after all 5 wing bosses are defeated.
## Phases: STALK → FIGHT → RAGE (at 30% HP)

signal died(pos: Vector3)
signal defeated

enum Phase { STALK, FIGHT, RAGE }

var phase: Phase = Phase.STALK
var _time: float = 0.0
var _phase_timer: float = 0.0
var _heading: float = 0.0
var _speed: float = 0.0
var _vertical_velocity: float = 0.0

var health: float = 400.0
var max_health: float = 400.0
var _damage_flash: float = 0.0
var _shielded: bool = false
var _shield_timer: float = 0.0

const DETECT_RADIUS: float = 60.0
const PATROL_SPEED: float = 2.5
const CHASE_SPEED: float = 7.0
const RAGE_SPEED: float = 10.0
const ATTACK_RANGE: float = 4.0
const ATTACK_DAMAGE: float = 15.0
const GRAVITY: float = 20.0

var _attack_cooldown: float = 0.0
var _voice_cooldown: float = 0.0
var _trait_cooldowns: Dictionary = {
	"pulse_wave": 0.0,
	"acid_spit": 0.0,
	"wind_gust": 0.0,
	"bone_shield": 0.0,
	"summon_minions": 0.0,
}
var _minions_alive: int = 0

var _body_mesh: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _aura_light: OmniLight3D = null
var _shield_mesh: MeshInstance3D = null
var _body_sections: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("boss")
	_heading = randf() * TAU
	_phase_timer = 3.0
	_build_body()

func _build_body() -> void:
	# Dark worm-like body — mirror of the player
	_body_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.8
	sphere.radial_segments = 16
	sphere.rings = 8
	_body_mesh.mesh = sphere

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.15, 0.08, 0.2, 0.9)
	_body_mat.roughness = 0.3
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(0.4, 0.1, 0.5)
	_body_mat.emission_energy_multiplier = 1.5
	_body_mesh.material_override = _body_mat
	_body_mesh.position = Vector3(0, 0.9, 0)
	add_child(_body_mesh)

	# Dark body sections (tail)
	for i in range(6):
		var section: MeshInstance3D = MeshInstance3D.new()
		var sec_sphere: SphereMesh = SphereMesh.new()
		var t: float = float(i + 1) / 7.0
		sec_sphere.radius = 0.6 * (1.0 - t * 0.5)
		sec_sphere.height = sec_sphere.radius * 2.5
		sec_sphere.radial_segments = 10
		sec_sphere.rings = 5
		section.mesh = sec_sphere
		var sec_mat: StandardMaterial3D = StandardMaterial3D.new()
		sec_mat.albedo_color = Color(0.12, 0.06, 0.18, 0.85)
		sec_mat.roughness = 0.4
		sec_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sec_mat.emission_enabled = true
		sec_mat.emission = Color(0.35, 0.08, 0.45)
		sec_mat.emission_energy_multiplier = 1.0
		section.material_override = sec_mat
		section.position = Vector3(0, 0.7, -(i + 1) * 0.6)
		add_child(section)
		_body_sections.append(section)

	# Shield sphere (hidden)
	_shield_mesh = MeshInstance3D.new()
	var shield_s: SphereMesh = SphereMesh.new()
	shield_s.radius = 2.5
	shield_s.height = 5.0
	shield_s.radial_segments = 20
	shield_s.rings = 10
	_shield_mesh.mesh = shield_s
	var shield_mat: StandardMaterial3D = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.5, 0.2, 0.6, 0.15)
	shield_mat.roughness = 0.1
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.emission_enabled = true
	shield_mat.emission = Color(0.4, 0.15, 0.5)
	shield_mat.emission_energy_multiplier = 2.0
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield_mesh.material_override = shield_mat
	_shield_mesh.position = Vector3(0, 0.9, 0)
	_shield_mesh.visible = false
	add_child(_shield_mesh)

	# Eerie dark aura
	_aura_light = OmniLight3D.new()
	_aura_light.light_color = Color(0.5, 0.15, 0.6)
	_aura_light.light_energy = 2.0
	_aura_light.omni_range = 20.0
	_aura_light.shadow_enabled = true
	_aura_light.position = Vector3(0, 1.0, 0)
	add_child(_aura_light)

	# Collision
	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	_time += delta
	_phase_timer -= delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_voice_cooldown = maxf(_voice_cooldown - delta, 0.0)
	for key in _trait_cooldowns:
		_trait_cooldowns[key] = maxf(_trait_cooldowns[key] - delta, 0.0)

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

	if health / max_health <= 0.3 and phase != Phase.RAGE:
		phase = Phase.RAGE
		if _voice_cooldown <= 0:
			AudioManager.play_creature_voice("mirror_parasite", "attack", 1.5, 1.0, 1.2)
			_voice_cooldown = 4.0

	match phase:
		Phase.STALK:
			_speed = lerpf(_speed, PATROL_SPEED, delta * 3.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 1.5)
			if player and player_dist < DETECT_RADIUS * 0.5:
				phase = Phase.FIGHT
				_phase_timer = 0.0
				if _voice_cooldown <= 0:
					AudioManager.play_creature_voice("mirror_parasite", "attack", 1.5, 1.0, 1.2)
					_voice_cooldown = 4.0

		Phase.FIGHT:
			_speed = lerpf(_speed, CHASE_SPEED, delta * 3.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 4.0)
				# Melee attack
				if player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE)
					_attack_cooldown = 1.2
				# Use traits strategically
				_use_traits(player, player_dist)

		Phase.RAGE:
			_speed = lerpf(_speed, RAGE_SPEED, delta * 5.0)
			if player:
				var to_p: Vector3 = player.global_position - global_position
				_heading = lerp_angle(_heading, atan2(to_p.x, to_p.z), delta * 6.0)
				if player_dist < ATTACK_RANGE and _attack_cooldown <= 0:
					if player.has_method("take_damage"):
						player.take_damage(ATTACK_DAMAGE * 1.5)
					_attack_cooldown = 0.6
				_use_traits(player, player_dist)

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
			_body_mat.emission_energy_multiplier = 1.5 + _damage_flash * 5.0

	_update_visuals(delta)

func _use_traits(player: Node3D, dist: float) -> void:
	var is_rage: bool = phase == Phase.RAGE
	var cd_mult: float = 0.5 if is_rage else 1.0

	# Pulse Wave — when player is close
	if dist < 12.0 and _trait_cooldowns["pulse_wave"] <= 0:
		_do_pulse_wave()
		_trait_cooldowns["pulse_wave"] = 6.0 * cd_mult

	# Acid Spit — ranged, when player is medium distance
	if dist > 6.0 and dist < 30.0 and _trait_cooldowns["acid_spit"] <= 0:
		_do_acid_spit(player)
		_trait_cooldowns["acid_spit"] = 4.0 * cd_mult

	# Wind Gust — push player away when close
	if dist < 15.0 and _trait_cooldowns["wind_gust"] <= 0:
		_do_wind_gust()
		_trait_cooldowns["wind_gust"] = 5.0 * cd_mult

	# Bone Shield — when taking damage (low HP threshold)
	if health / max_health < 0.5 and not _shielded and _trait_cooldowns["bone_shield"] <= 0:
		_do_bone_shield()
		_trait_cooldowns["bone_shield"] = 15.0 * cd_mult

	# Summon Minions
	if _minions_alive < 3 and _trait_cooldowns["summon_minions"] <= 0:
		_do_summon_minions()
		_trait_cooldowns["summon_minions"] = 20.0 * cd_mult

func _do_pulse_wave() -> void:
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("mirror_parasite", "attack", 1.5, 1.0, 1.2)
		_voice_cooldown = 4.0
	for target in get_tree().get_nodes_in_group("player_worm"):
		var dist: float = global_position.distance_to(target.global_position)
		if dist < 12.0:
			var falloff: float = 1.0 - dist / 12.0
			if target.has_method("take_damage"):
				target.take_damage(15.0 * falloff)
			if target is CharacterBody3D:
				var push: Vector3 = (target.global_position - global_position).normalized()
				push.y = 0.5
				target.velocity += push * 15.0 * falloff

func _do_acid_spit(player: Node3D) -> void:
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("mirror_parasite", "attack", 1.5, 1.0, 1.2)
		_voice_cooldown = 4.0
	var proj_script = load("res://scripts/snake_stage/acid_projectile.gd")
	if not proj_script:
		return
	var proj: Area3D = Area3D.new()
	proj.set_script(proj_script)
	proj.direction = (player.global_position - global_position).normalized()
	proj.speed = 20.0
	proj.damage = 10.0
	proj.dot_dps = 5.0
	proj.dot_duration = 3.0
	proj.position = global_position + Vector3(0, 1.0, 0)
	get_parent().add_child(proj)

func _do_wind_gust() -> void:
	for target in get_tree().get_nodes_in_group("player_worm"):
		var dist: float = global_position.distance_to(target.global_position)
		if dist < 15.0:
			var dir: Vector3 = (target.global_position - global_position).normalized()
			var dot: float = dir.dot(Vector3(sin(_heading), 0, cos(_heading)))
			if dot > 0.3:
				var falloff: float = 1.0 - dist / 15.0
				if target.has_method("take_damage"):
					target.take_damage(8.0 * falloff)
				if target is CharacterBody3D:
					target.velocity += dir * 20.0 * falloff

func _do_bone_shield() -> void:
	_shielded = true
	_shield_timer = 3.0
	_shield_mesh.visible = true

func _do_summon_minions() -> void:
	var bug_script = load("res://scripts/snake_stage/prey_bug.gd")
	if not bug_script:
		return
	for i in range(2):
		var minion: CharacterBody3D = CharacterBody3D.new()
		minion.set_script(bug_script)
		var angle: float = TAU * i / 2.0 + randf() * 0.5
		minion.position = global_position + Vector3(cos(angle) * 4.0, 0.5, sin(angle) * 4.0)
		# Make them aggressive toward player (override behavior)
		minion.add_to_group("mirror_minion")
		get_parent().add_child(minion)
		_minions_alive += 1
		if minion.has_signal("died"):
			minion.died.connect(func(_pos): _minions_alive = maxi(_minions_alive - 1, 0))

func _update_visuals(delta: float) -> void:
	# Dark pulse
	var pulse: float = 1.0 + sin(_time * 2.0) * 0.05
	if _body_mesh:
		_body_mesh.scale = Vector3(pulse, pulse, pulse)
	# Body sections sway
	for i in range(_body_sections.size()):
		var section: MeshInstance3D = _body_sections[i]
		var sway: float = sin(_time * 2.0 + i * 0.8) * 0.15
		section.position.x = sway
	# Shield pulse
	if _shield_mesh and _shielded:
		_shield_mesh.scale = Vector3.ONE * (1.0 + sin(_time * 4.0) * 0.05)
	# Rage visual: faster flicker, redder glow
	if phase == Phase.RAGE:
		if _aura_light:
			_aura_light.light_energy = 2.5 + sin(_time * 8.0) * 0.5
			_aura_light.light_color = Color(0.7, 0.1, 0.4)
		if _body_mat:
			_body_mat.emission = Color(0.6, 0.1, 0.3)

func stun(duration: float = 2.0) -> void:
	if _shielded:
		return
	_speed = 0.0
	_attack_cooldown = duration

func take_damage(amount: float) -> void:
	if _shielded:
		return
	health -= amount
	_damage_flash = 1.0
	if _voice_cooldown <= 0:
		AudioManager.play_creature_voice("mirror_parasite", "hurt", 1.5, 1.0, 1.2)
		_voice_cooldown = 3.0
	if phase == Phase.STALK:
		phase = Phase.FIGHT
	if health <= 0:
		_die()

func _die() -> void:
	AudioManager.play_creature_voice("mirror_parasite", "death", 1.5, 1.0, 1.2)
	died.emit(global_position)
	defeated.emit()
	queue_free()

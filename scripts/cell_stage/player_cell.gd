extends CharacterBody2D
## Player cell with comical expressive face, biomolecule collection, parasite system.

@onready var camera: Camera2D = $Camera2D

signal reproduced
signal organelle_collected
signal died
signal parasites_changed(count: int)
signal damaged(amount: float)
signal damage_dealt(amount: float)
signal prey_killed
signal food_consumed
signal reproduction_complete
signal biomolecule_category_collected(category: String)

var max_energy: float = 100.0
var energy: float = 100.0
var max_health: float = 100.0
var health: float = 100.0
var move_speed: float = 200.0
var toxin_damage: float = 20.0
var toxin_cost: float = 15.0
var repro_cost: float = 60.0

const ENERGY_DRAIN_RATE: float = 5.0
const ENERGY_REGEN_RATE: float = 2.0
const TOXIN_COOLDOWN: float = 1.0
const LOW_ENERGY_THRESHOLD: float = 0.15  # Below this = depleted state
const DEPLETED_SPEED_MULT: float = 0.5
const SPRINT_SPEED_MULT: float = 1.8
const SPRINT_ENERGY_MULT: float = 3.0  # Energy drains 3x faster while sprinting
const METABOLIZE_COOLDOWN: float = 1.0
const METABOLIZE_ENERGY_GAIN: float = 20.0  # Energy restored per metabolize
const EAT_RANGE: float = 35.0  # Distance to eat prey (generous — touching body = easy eat)

var is_sprinting: bool = false
var metabolize_timer: float = 0.0

var toxin_timer: float = 0.0

# Tractor beam system
const BEAM_RANGE: float = 250.0  # Max distance to lock on
const BEAM_COLLECT_DIST: float = 30.0  # Distance at which item is consumed (generous for easy absorption)
const BEAM_ENERGY_COST: float = 2.0  # Energy per second while beaming
var _beam_target: Node2D = null  # Currently beamed node
var _beam_active: bool = false
var _beam_particles: Array = []  # [{pos, vel, life, color}]

# Jet stream system
const JET_RANGE: float = 150.0
const JET_CONE_ANGLE: float = 0.4  # Radians half-angle (~23 degrees)
const JET_PUSH_FORCE: float = 400.0
const JET_CONSUME_INTERVAL: float = 0.5
const JET_CONFUSE_DURATION: float = 2.0
var _jet_active: bool = false
var _jet_consume_timer: float = 0.0
var _jet_particles: Array = []  # [{pos, vel, life, color, size}]
var _jet_colors: Array = [Color(0.3, 0.7, 1.0)]  # Current spray colors

# Targeting reticle
var _target_candidate: Node2D = null  # What cursor is hovering near
var _target_type: String = ""  # "food" or "prey"
var _target_scan_timer: float = 0.0

# Inertial movement (ice/space feel)
const ACCEL_TIME: float = 1.0  # Seconds to reach max speed
const DECEL_TIME: float = 0.8  # Seconds to stop after releasing input
var _current_velocity: Vector2 = Vector2.ZERO  # Smoothed velocity

# Wake trail
var _wake_particles: Array = []  # [{pos, life, size, color}]
const MAX_WAKE: int = 25  # Reduced for performance

# Sound state
var _was_sprinting: bool = false
var _was_beaming: bool = false
var collected_components: Array = []
var is_energy_depleted: bool = false  # True when energy critically low
var input_disabled: bool = false  # Disable during cinematic showcase

# Parasite system
var attached_parasites: Array = []  # Array of parasite node refs
var _parasite_cleanup_timer: float = 0.0
const MAX_PARASITES: int = 5  # This many = takeover

# Procedural graphics
var _time: float = 0.0
var _cell_radius: float = 18.0
var _membrane_points: Array[Vector2] = []
var _organelle_positions: Array[Vector2] = []
var _cilia_angles: Array[float] = []
var _toxin_flash: float = 0.0
var _feed_flash: float = 0.0
var _damage_flash: float = 0.0
const NUM_MEMBRANE_PTS: int = 32
const NUM_CILIA: int = 12
const NUM_ORGANELLES: int = 5
var _elongation: float = 1.0  # X-axis stretch factor, grows with evolution level
var _elongation_offset: float = 0.0
var _bulge: float = 1.0

# Camera zoom (sensory-based)
const ZOOM_LEVELS: Array = [1.6, 1.4, 1.23, 1.07, 0.93, 0.8]  # Sensory 0-5 (zoomed out 50% more)
var _target_zoom: float = 2.0
var _current_zoom: float = 2.0

# Directional combat system
# Golden card AOE ability
var _golden_cooldown: float = 0.0
const GOLDEN_COOLDOWN_MAX: float = 15.0
var _golden_aura_active: bool = false  # Healing aura invulnerability
var _golden_aura_timer: float = 0.0
var _golden_vfx_timer: float = 0.0  # Active VFX countdown
var _golden_vfx_type: String = ""  # "flee", "stun", "heal"
var _golden_vfx_particles: Array = []  # [{pos, vel, life, color, size}]
var _golden_flash: float = 0.0  # Screen flash alpha

var _has_directional_front: bool = false
var _has_directional_rear: bool = false
var _has_directional_sides: bool = false
var _directional_front_damage: float = 0.0
var _directional_rear_damage: float = 0.0
var _directional_sides_damage: float = 0.0
var _directional_contact_timer: float = 0.0
const DIRECTIONAL_CONTACT_COOLDOWN: float = 0.4
var _tail_hit_flash: float = 0.0  # Separate visual feedback for rear hits
var _front_hit_flash: float = 0.0  # Separate visual feedback for front hits

# Face / mood system - Anime-style expressive eyes
enum Mood { IDLE, HAPPY, EXCITED, STRESSED, SCARED, ANGRY, EATING, HURT, DEPLETED, ZOOM, SICK }
var mood: Mood = Mood.IDLE
var _mood_timer: float = 0.0
var _blink_timer: float = 0.0
var _is_blinking: bool = false
var _eye_spacing: float = 0.0
var _eye_size: float = 0.0
var _pupil_size: float = 0.0
var _has_eyebrows: bool = true

# Anime eye effects
var _eye_sparkle_timer: float = 0.0
var _eye_shake: Vector2 = Vector2.ZERO
var _sweat_drop_y: float = 0.0
var _spiral_angle: float = 0.0  # For sick/confused spiral eyes

# Creature vocalization
var _idle_voice_timer: float = 3.0  # Delay before first idle vocalization

func _ready() -> void:
	_apply_gene_traits()
	_apply_mutation_stats()
	_compute_elongation()
	_init_procedural_shape()
	_randomize_face()
	add_to_group("player")
	GameManager.evolution_applied.connect(_on_evolution_applied)
	_update_sensory_zoom(false)  # Set initial zoom instantly

func _randomize_face() -> void:
	_eye_spacing = randf_range(4.5, 7.0)
	_eye_size = GameManager.creature_customization.get("eye_size", 3.5)
	_pupil_size = randf_range(1.2, 2.2)
	_has_eyebrows = randf() > 0.3

func _init_procedural_shape() -> void:
	_membrane_points.clear()
	for i in range(NUM_MEMBRANE_PTS):
		var angle: float = TAU * i / NUM_MEMBRANE_PTS
		var bulge_factor: float = 1.0 + (absf(sin(angle)) * (_bulge - 1.0))
		var rx: float = _cell_radius * _elongation + randf_range(-2.0, 2.0)
		var ry: float = _cell_radius * bulge_factor + randf_range(-2.0, 2.0)
		_membrane_points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	# Tightened organelles — stay in center 35% to avoid eye area
	_organelle_positions.clear()
	for i in range(NUM_ORGANELLES):
		var a: float = randf() * TAU
		var dx: float = randf_range(2.0, _cell_radius * _elongation * 0.35)
		var dy: float = randf_range(2.0, _cell_radius * 0.35)
		_organelle_positions.append(Vector2(cos(a) * dx, sin(a) * dy))
	_cilia_angles.clear()
	for i in range(NUM_CILIA):
		_cilia_angles.append(TAU * i / NUM_CILIA + randf_range(-0.1, 0.1))

func _apply_gene_traits() -> void:
	for gene_id in GameManager.player_stats.genes:
		var gene: Dictionary = BiologyLoader.get_gene(gene_id)
		var impact: Dictionary = gene.get("trait_impact", {})
		if "energy_efficiency" in impact:
			max_energy *= (1.0 + impact.energy_efficiency)
			energy = max_energy
		if "speed" in impact:
			move_speed *= (1.0 + impact.speed)
		if "hostility_damage" in impact:
			toxin_damage *= (1.0 + impact.hostility_damage)
		if "armor" in impact:
			max_health *= (1.0 + impact.armor)
			health = max_health
		if "offspring_survival" in impact:
			repro_cost *= (1.0 - impact.offspring_survival)
	for key in GameManager.player_stats.spliced_traits:
		var val: float = GameManager.player_stats.spliced_traits[key]
		match key:
			"speed": move_speed *= (1.0 + val)
			"armor": max_health *= (1.0 + val)
			"energy_efficiency": max_energy *= (1.0 + val)

func _physics_process(delta: float) -> void:
	# Smooth camera zoom transition for sensory upgrades
	if camera and abs(_current_zoom - _target_zoom) > 0.01:
		_current_zoom = lerpf(_current_zoom, _target_zoom, delta * 2.0)
		camera.zoom = Vector2(_current_zoom, _current_zoom)

	if input_disabled:
		_time += delta
		queue_redraw()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Sprint
	is_sprinting = Input.is_action_pressed("sprint") and not is_energy_depleted and energy > 5.0

	# Energy depletion mechanic
	var energy_ratio: float = energy / max_energy
	is_energy_depleted = energy_ratio < LOW_ENERGY_THRESHOLD
	var speed_mult: float = DEPLETED_SPEED_MULT if is_energy_depleted else 1.0
	if is_sprinting:
		speed_mult *= SPRINT_SPEED_MULT
	# Extra slowdown from parasites
	var parasite_slow: float = 1.0 - attached_parasites.size() * 0.1
	speed_mult *= maxf(parasite_slow, 0.3)

	# Inertial movement — accelerate toward desired velocity, decelerate when no input
	var target_vel: Vector2 = input_dir * move_speed * speed_mult
	if input_dir.length() > 0.1:
		# Accelerate toward target
		var accel_rate: float = move_speed * speed_mult / ACCEL_TIME
		_current_velocity = _current_velocity.move_toward(target_vel, accel_rate * delta)
		var drain: float = ENERGY_DRAIN_RATE
		if is_sprinting:
			drain *= SPRINT_ENERGY_MULT
		energy -= drain * delta
	else:
		# Decelerate (glide to stop)
		var decel_rate: float = _current_velocity.length() / DECEL_TIME
		_current_velocity = _current_velocity.move_toward(Vector2.ZERO, decel_rate * delta)
		if _current_velocity.length() < 5.0:
			# Full regen when stopped
			energy = minf(energy + ENERGY_REGEN_RATE * delta, max_energy)
		elif _current_velocity.length() < move_speed * 0.3:
			# Partial regen when moving slowly (1/sec)
			energy = minf(energy + 1.0 * delta, max_energy)
	energy = maxf(energy, 0.0)

	velocity = _current_velocity
	look_at(get_global_mouse_position())
	move_and_slide()

	# Wake trail particles when moving
	if velocity.length() > 20.0:
		_spawn_wake_particle()

	# Biomolecule magnet: pull nearby food toward player when sensory >= 2
	if GameManager.sensory_level >= 2:
		_update_biomolecule_magnet(delta)

	# Try to eat nearby prey after moving
	_try_eat_prey()

	# Directional contact damage
	_directional_contact_timer -= delta
	_check_directional_contact_damage()

	# Tractor beam + jet stream (throttle targeting scan)
	_target_scan_timer -= delta
	if _target_scan_timer <= 0:
		_target_scan_timer = 0.1
		_update_targeting()
	_update_beam(delta)
	_update_jet(delta)
	_update_beam_particles(delta)
	_update_jet_particles(delta)

	if toxin_timer > 0:
		toxin_timer -= delta
	if metabolize_timer > 0:
		metabolize_timer -= delta
	if Input.is_action_just_pressed("combat_toxin") and toxin_timer <= 0 and energy >= toxin_cost:
		_fire_toxin()
	if Input.is_action_just_pressed("reproduce") and energy >= repro_cost:
		_reproduce()
	if Input.is_action_just_pressed("metabolize") and metabolize_timer <= 0:
		_metabolize()
	# Golden card AOE ability (middle mouse button)
	if Input.is_action_just_pressed("golden_ability") and GameManager.equipped_golden_card != "":
		_try_golden_ability()
	if health <= 0:
		died.emit()

	# Clean up dead parasite refs (throttled to avoid per-frame allocation)
	_parasite_cleanup_timer -= delta
	if _parasite_cleanup_timer <= 0:
		_parasite_cleanup_timer = 0.5
		var i: int = attached_parasites.size() - 1
		while i >= 0:
			if not is_instance_valid(attached_parasites[i]):
				attached_parasites.remove_at(i)
			i -= 1
	# Check parasite takeover
	if attached_parasites.size() >= MAX_PARASITES:
		died.emit()  # Takeover = death

	# Mutation: health regen
	if _health_regen_rate > 0:
		health = minf(health + _health_regen_rate * delta, max_health)

	# Golden card cooldown and aura timer
	_golden_cooldown = maxf(_golden_cooldown - delta, 0.0)
	_golden_flash = maxf(_golden_flash - delta * 4.0, 0.0)
	if _golden_aura_active:
		_golden_aura_timer -= delta
		if _golden_aura_timer <= 0:
			_golden_aura_active = false
	if _golden_vfx_timer > 0:
		_golden_vfx_timer -= delta
		if _golden_vfx_timer <= 0:
			_golden_vfx_type = ""
	_update_golden_vfx_particles(delta)

	_time += delta
	_toxin_flash = maxf(_toxin_flash - delta * 3.0, 0.0)
	_feed_flash = maxf(_feed_flash - delta * 2.5, 0.0)
	_damage_flash = maxf(_damage_flash - delta * 4.0, 0.0)
	_tail_hit_flash = maxf(_tail_hit_flash - delta * 4.0, 0.0)
	_front_hit_flash = maxf(_front_hit_flash - delta * 4.0, 0.0)
	_update_mood(delta)
	_update_wake_particles(delta)

	# Sound triggers
	if is_sprinting and not _was_sprinting:
		AudioManager.play_sprint()
	_was_sprinting = is_sprinting
	if _beam_active and not _was_beaming:
		AudioManager.start_beam()
	elif not _beam_active and _was_beaming:
		AudioManager.stop_beam()
	_was_beaming = _beam_active

	# Creature idle vocalizations (evolve with evolution level)
	_idle_voice_timer -= delta
	if _idle_voice_timer <= 0:
		_idle_voice_timer = randf_range(4.0, 8.0)
		AudioManager.play_player_voice("idle")

	queue_redraw()

func _update_mood(delta: float) -> void:
	_mood_timer -= delta
	_blink_timer -= delta
	if _blink_timer <= 0:
		if _is_blinking:
			_is_blinking = false
			_blink_timer = randf_range(2.0, 5.0)
		else:
			_is_blinking = true
			_blink_timer = 0.12

	# Anime eye effects
	_eye_sparkle_timer += delta
	_sweat_drop_y = fmod(_sweat_drop_y + delta * 2.0, 1.0)
	_spiral_angle += delta * 4.0

	# Eye shake when stressed/hurt
	if mood in [Mood.HURT, Mood.SCARED, Mood.STRESSED]:
		_eye_shake = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * 0.5
	else:
		_eye_shake = _eye_shake.lerp(Vector2.ZERO, delta * 5.0)

	if _mood_timer <= 0:
		var energy_ratio: float = energy / max_energy
		var health_ratio: float = health / max_health
		# Priority-based mood selection (check higher counts first)
		if attached_parasites.size() >= 4:
			mood = Mood.SCARED  # Near death from parasites
		elif attached_parasites.size() >= 2:
			mood = Mood.SICK  # Parasites make you look sick
		elif is_sprinting and velocity.length() > move_speed * SPRINT_SPEED_MULT * 0.7:
			mood = Mood.ZOOM  # Speed lines and focused face
		elif is_energy_depleted:
			mood = Mood.DEPLETED
		elif health_ratio < 0.3:
			mood = Mood.SCARED
		elif energy_ratio < 0.25:
			mood = Mood.STRESSED
		elif velocity.length() > move_speed * 0.8:
			mood = Mood.EXCITED
		else:
			mood = Mood.IDLE

func _set_mood(new_mood: Mood, duration: float = 0.8) -> void:
	mood = new_mood
	_mood_timer = duration

func _draw() -> void:
	var energy_ratio: float = energy / max_energy
	var health_ratio: float = health / max_health

	# Outer glow (dims when depleted) — elliptical when elongated
	var custom_glow: Color = GameManager.creature_customization.get("glow_color", Color(0.3, 0.7, 1.0))
	var glow_base: float = 0.08 if not is_energy_depleted else 0.03
	var glow_alpha: float = glow_base + 0.06 * sin(_time * 2.0)
	var glow_color := custom_glow if not is_energy_depleted else Color(0.3, 0.3, 0.4)
	_draw_ellipse(Vector2.ZERO, _cell_radius * _elongation * 2.2, _cell_radius * 2.2, Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha))
	_draw_ellipse(Vector2.ZERO, _cell_radius * _elongation * 1.6, _cell_radius * 1.6, Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha * 1.5))

	# Cilia (sluggish when depleted) — use cilia_color
	var custom_cilia: Color = GameManager.creature_customization.get("cilia_color", Color(0.4, 0.7, 1.0))
	var is_moving: bool = velocity.length() > 10.0
	var cilia_speed: float = 8.0 if not is_energy_depleted else 2.0
	var cilia_amp: float = (0.3 if is_moving else 0.12) if not is_energy_depleted else 0.05
	for i in range(NUM_CILIA):
		var base_angle: float = _cilia_angles[i]
		var wave: float = sin(_time * cilia_speed + i * 1.3) * cilia_amp
		var angle: float = base_angle + wave
		var base_pt := Vector2(cos(base_angle) * _cell_radius * _elongation, sin(base_angle) * _cell_radius)
		var tip_len: float = 8.0 + 3.0 * sin(_time * 5.0 + i)
		if is_energy_depleted:
			tip_len *= 0.6
		var tip_pt := base_pt + Vector2(cos(angle) * tip_len, sin(angle) * tip_len)
		var cilia_col := Color(custom_cilia.r * 1.2, custom_cilia.g * 1.1, custom_cilia.b, 0.7) if not is_energy_depleted else Color(0.35, 0.4, 0.5, 0.4)
		draw_line(base_pt, tip_pt, cilia_col, 1.2, true)

	# Membrane — use customization color
	var custom_membrane: Color = GameManager.creature_customization.get("membrane_color", Color(0.3, 0.6, 1.0))
	var membrane_color := Color(custom_membrane.r, custom_membrane.g, custom_membrane.b, 0.9)
	if is_energy_depleted:
		membrane_color = Color(custom_membrane.r * 0.6, custom_membrane.g * 0.6, custom_membrane.b * 0.7, 0.7)
	if _damage_flash > 0:
		membrane_color = membrane_color.lerp(Color(1.0, 0.2, 0.2), _damage_flash)
	if _feed_flash > 0:
		membrane_color = membrane_color.lerp(Color(0.3, 1.0, 0.5), _feed_flash)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(NUM_MEMBRANE_PTS):
		var wobble := sin(_time * 3.0 + i * 0.7) * 1.5
		pts.append(_membrane_points[i] + _membrane_points[i].normalized() * wobble)
	var custom_interior: Color = GameManager.creature_customization.get("interior_color", Color(0.15, 0.25, 0.5))
	var fill_color := Color(custom_interior.r, custom_interior.g, custom_interior.b, 0.7)
	if is_energy_depleted:
		fill_color = Color(custom_interior.r * 0.6, custom_interior.g * 0.6, custom_interior.b * 0.7, 0.6)
	if _toxin_flash > 0:
		fill_color = fill_color.lerp(Color(0.6, 0.1, 0.6, 0.8), _toxin_flash)
	draw_colored_polygon(pts, fill_color)
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], membrane_color, 1.5, true)

	# --- MEMBRANE HEALTH VISUALIZATION ---
	if health_ratio < 0.75:
		_draw_membrane_damage(pts, health_ratio)

	# Internal organelles — tinted by organelle_tint
	var org_tint: Color = GameManager.creature_customization.get("organelle_tint", Color(0.3, 0.8, 0.5))
	var base_org_colors: Array[Color] = [
		Color(0.2, 0.9, 0.3, 0.7), Color(0.9, 0.6, 0.1, 0.7),
		Color(0.7, 0.2, 0.8, 0.6), Color(0.1, 0.8, 0.8, 0.6), Color(0.9, 0.9, 0.2, 0.5),
	]
	for i in range(_organelle_positions.size()):
		var wobble_v := Vector2(sin(_time * 2.0 + i), cos(_time * 1.8 + i * 0.7)) * 1.5
		var oc: Color = base_org_colors[i % base_org_colors.size()]
		var tinted: Color = oc.lerp(org_tint, 0.4)
		tinted.a = oc.a
		draw_circle(_organelle_positions[i] + wobble_v, 2.5, tinted)

	# --- MUTATION VISUALS ---
	_draw_mutations()

	# --- COMICAL FACE ---
	_draw_face()

	# Energy/health arcs
	var energy_arc_color := Color(0.3, 0.8, 1.0, 0.15 + energy_ratio * 0.25)
	if is_energy_depleted:
		energy_arc_color = Color(0.8, 0.3, 0.2, 0.15 + 0.2 * sin(_time * 4.0))  # Flashing red
	var arc_r: float = _cell_radius * (1.0 + (_elongation - 1.0) * 0.5)  # Average radius for arcs
	draw_arc(Vector2.ZERO, arc_r + 3.0, 0, TAU * energy_ratio, 48, energy_arc_color, 2.0, true)
	if health_ratio < 1.0:
		draw_arc(Vector2.ZERO, arc_r + 5.0, 0, TAU * health_ratio, 48, Color(1.0, 0.3, 0.3, 0.4), 1.5, true)

	# Parasite count warning
	if attached_parasites.size() > 0:
		var warn_a: float = 0.1 + 0.1 * sin(_time * 6.0)
		var warn_color := Color(0.6, 0.1, 0.4, warn_a * attached_parasites.size() / MAX_PARASITES)
		draw_arc(Vector2.ZERO, _cell_radius + 7.0, 0, TAU, 32, warn_color, 2.0, true)

	# --- WAKE TRAIL ---
	for wp in _wake_particles:
		var wp_local: Vector2 = (wp.pos - global_position).rotated(-rotation)
		var wa: float = wp.life * wp.color.a
		draw_circle(wp_local, wp.size * wp.life, Color(wp.color.r, wp.color.g, wp.color.b, wa))
		draw_circle(wp_local, wp.size * wp.life * 2.0, Color(wp.color.r, wp.color.g, wp.color.b, wa * 0.2))

	# --- TRACTOR BEAM VISUALS ---
	if _beam_active and is_instance_valid(_beam_target):
		var target_local: Vector2 = (_beam_target.global_position - global_position).rotated(-rotation)
		# Main beam line (pulsing)
		var beam_alpha: float = 0.25 + 0.15 * sin(_time * 12.0)
		var beam_col := Color(0.3, 0.8, 1.0, beam_alpha)
		draw_line(Vector2.ZERO, target_local, beam_col, 2.0, true)
		# Thinner bright core
		draw_line(Vector2.ZERO, target_local, Color(0.6, 0.9, 1.0, beam_alpha * 1.5), 0.8, true)
		# Suction rings along beam (moving toward player)
		var beam_len: float = target_local.length()
		for r_i in range(3):
			var t_offset: float = fmod(_time * 3.0 + r_i * 0.33, 1.0)
			var ring_pos: Vector2 = target_local * (1.0 - t_offset)
			var ring_r: float = 4.0 * (1.0 - t_offset) + 1.0
			draw_arc(ring_pos, ring_r, 0, TAU, 12, Color(0.4, 0.85, 1.0, (1.0 - t_offset) * 0.4), 1.0, true)

	# Beam particles (drawn in world-local space)
	for p in _beam_particles:
		var p_local: Vector2 = (p.pos - global_position).rotated(-rotation)
		var alpha: float = p.life * 0.8
		draw_circle(p_local, p.size, Color(p.color.r, p.color.g, p.color.b, alpha))

	# --- JET STREAM VISUALS ---
	if _jet_active:
		var jet_dir_local := (get_global_mouse_position() - global_position).normalized().rotated(-rotation)
		# Cone glow
		var cone_a: float = 0.06 + 0.04 * sin(_time * 8.0)
		var cone_left: Vector2 = jet_dir_local.rotated(-JET_CONE_ANGLE) * JET_RANGE
		var cone_right: Vector2 = jet_dir_local.rotated(JET_CONE_ANGLE) * JET_RANGE
		var cone_pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO, cone_left, cone_right])
		draw_colored_polygon(cone_pts, Color(0.4, 0.7, 1.0, cone_a))

	# Jet particles
	for p in _jet_particles:
		var p_local: Vector2 = (p.pos - global_position).rotated(-rotation)
		var alpha: float = p.life * 0.7
		draw_circle(p_local, p.size, Color(p.color.r, p.color.g, p.color.b, alpha))
		# Trail
		if p.life > 0.3:
			var trail_dir: Vector2 = p.vel.normalized().rotated(-rotation) * p.size * 2.0
			draw_line(p_local, p_local - trail_dir, Color(p.color.r, p.color.g, p.color.b, alpha * 0.4), p.size * 0.5, true)

	# --- TARGETING RETICLE ---
	if _target_candidate and is_instance_valid(_target_candidate) and not _beam_active:
		var reticle_pos: Vector2 = (_target_candidate.global_position - global_position).rotated(-rotation)
		var reticle_col := Color(0.3, 1.0, 0.4, 0.7) if _target_type == "food" else Color(1.0, 0.7, 0.2, 0.7)
		var reticle_r: float = 10.0 + 2.0 * sin(_time * 6.0)
		# Animated targeting ring
		draw_arc(reticle_pos, reticle_r, _time * 3.0, _time * 3.0 + TAU * 0.75, 16, reticle_col, 1.5, true)
		draw_arc(reticle_pos, reticle_r, _time * 3.0 + PI, _time * 3.0 + PI + TAU * 0.75, 16, reticle_col, 1.5, true)
		# Crosshair lines
		for c_i in range(4):
			var ca: float = TAU * c_i / 4.0 + _time * 2.0
			var inner: Vector2 = reticle_pos + Vector2(cos(ca), sin(ca)) * (reticle_r - 3.0)
			var outer: Vector2 = reticle_pos + Vector2(cos(ca), sin(ca)) * (reticle_r + 4.0)
			draw_line(inner, outer, reticle_col, 1.2, true)

	# --- GOLDEN CARD VFX ---
	_draw_golden_vfx()

func _draw_membrane_damage(pts: PackedVector2Array, health_ratio: float) -> void:
	## Draw cracks and tears on the membrane as health drops
	var crack_intensity: float = 1.0 - health_ratio / 0.75  # 0 at 75%, 1 at 0%
	var num_cracks: int = int(crack_intensity * 8.0) + 1
	var crack_color := Color(0.9, 0.2, 0.15, 0.3 + crack_intensity * 0.5)

	for c_idx in range(num_cracks):
		# Deterministic crack positions based on index (no randomness per frame)
		var seed_val: float = float(c_idx) * 2.7 + 0.5
		var pt_index: int = int(fmod(seed_val * 7.3, pts.size()))
		var start: Vector2 = pts[pt_index]
		var inward: Vector2 = -start.normalized()
		# Crack extends inward with jagged path
		var crack_len: float = (5.0 + crack_intensity * 10.0) * (0.7 + 0.3 * sin(seed_val * 3.1))
		var segments: int = 3
		var prev_pt: Vector2 = start
		for seg in range(segments):
			var t: float = float(seg + 1) / segments
			var next_pt: Vector2 = start + inward * crack_len * t
			# Jag perpendicular
			var perp := Vector2(-inward.y, inward.x)
			next_pt += perp * sin(seed_val * 5.0 + seg * 2.1) * 3.0
			var seg_alpha: float = crack_color.a * (1.0 - t * 0.5)
			draw_line(prev_pt, next_pt, Color(crack_color.r, crack_color.g, crack_color.b, seg_alpha), 1.0 + crack_intensity, true)
			prev_pt = next_pt

	# Low health: flickering membrane with breathing pulse
	if health_ratio < 0.25:
		var pulse: float = 0.1 + 0.15 * sin(_time * 4.0)
		var warning_r: float = _cell_radius * _elongation + 2.0
		draw_arc(Vector2.ZERO, warning_r, 0, TAU, 32, Color(0.9, 0.1, 0.1, pulse), 2.0, true)

func _draw_face() -> void:
	# --- EXPRESSIVE EYES (no mouth) ---
	# Eye position uses customization angle + spacing
	var eye_y_offset: float = 0.0
	var custom_spacing: float = GameManager.creature_customization.get("eye_spacing", 5.5)
	var custom_angle: float = GameManager.creature_customization.get("eye_angle", 0.0)
	var base_spacing: float = custom_spacing * 1.2
	var face_fwd: float = _cell_radius * (_elongation - 1.0) * 0.4
	var face_center := Vector2(_cell_radius * 0.25 + face_fwd, 0)
	var perp := Vector2(-sin(custom_angle), cos(custom_angle))
	var left_eye := face_center + perp * (-base_spacing * 0.4) + Vector2(0, eye_y_offset) + _eye_shake
	var right_eye := face_center + perp * (base_spacing * 0.4) + Vector2(0, eye_y_offset) + _eye_shake

	# Anime eye colors — use customization iris color
	var custom_iris: Color = GameManager.creature_customization.get("iris_color", Color(0.2, 0.5, 0.9))
	var eye_white_color := Color(1.0, 1.0, 1.0, 1.0)
	var iris_color := Color(custom_iris.r, custom_iris.g, custom_iris.b, 1.0)
	var pupil_color := Color(0.02, 0.02, 0.08, 1.0)
	var eye_r: float = _eye_size * 1.4  # Bigger eyes
	var pupil_r: float = _pupil_size * 1.2
	var iris_r: float = eye_r * 0.7
	var eye_squash_y: float = 1.0
	var pupil_offset := Vector2.ZERO
	var eyebrow_angle_l: float = 0.0
	var eyebrow_angle_r: float = 0.0
	var show_sparkles: bool = false
	var show_speed_lines: bool = false
	var show_sweat: bool = false
	var show_spiral: bool = false

	match mood:
		Mood.IDLE:
			eye_squash_y = 0.9
			show_sparkles = true
		Mood.HAPPY:
			eye_squash_y = 0.5  # Closed happy eyes (anime ^_^)
			eyebrow_angle_l = 0.2
			eyebrow_angle_r = 0.2
			show_sparkles = true
		Mood.EXCITED:
			eye_r *= 1.2
			pupil_r *= 1.3
			iris_r *= 1.2
			pupil_offset = Vector2(0.5, 0)
			eyebrow_angle_l = 0.3
			eyebrow_angle_r = 0.3
			show_sparkles = true
		Mood.ZOOM:
			# Focused, intense sprint face
			eye_squash_y = 0.7
			pupil_r *= 0.7  # Focused small pupils
			eyebrow_angle_l = -0.3
			eyebrow_angle_r = 0.3
			pupil_offset = Vector2(1.5, 0)  # Looking forward intently
			show_speed_lines = true
		Mood.STRESSED:
			eye_squash_y = 0.8
			eyebrow_angle_l = -0.4
			eyebrow_angle_r = 0.4
			pupil_r *= 0.75
			show_sweat = true
		Mood.SCARED:
			eye_r *= 1.5  # Huge eyes
			pupil_r *= 0.4  # Tiny pinprick pupils
			eye_squash_y = 1.3
			eyebrow_angle_l = 0.5
			eyebrow_angle_r = 0.5
			show_sweat = true
		Mood.ANGRY:
			eye_squash_y = 0.55
			eyebrow_angle_l = -0.6
			eyebrow_angle_r = 0.6
			pupil_r *= 0.85
			iris_color = Color(0.8, 0.3, 0.2, 1.0)  # Red-tinted iris when angry
		Mood.EATING:
			eye_squash_y = 0.4  # Happy closed
			eyebrow_angle_l = 0.15
			eyebrow_angle_r = 0.15
		Mood.HURT:
			# X_X or >_< style hurt
			eye_squash_y = 0.3
			eyebrow_angle_l = -0.5
			eyebrow_angle_r = -0.5
			show_sweat = true
		Mood.DEPLETED:
			eye_squash_y = 0.5
			eye_r *= 0.85
			eyebrow_angle_l = -0.4
			eyebrow_angle_r = -0.4
			pupil_r *= 0.65
			pupil_offset = Vector2(-0.3, 0.5)  # Looking down sadly
			iris_color = Color(0.4, 0.5, 0.6, 1.0)  # Dull color
			show_sweat = true
		Mood.SICK:
			# Spiral/swirly eyes when parasites attached
			eye_squash_y = 1.0
			eye_r *= 1.1
			show_spiral = true
			iris_color = Color(0.5, 0.7, 0.3, 1.0)  # Sickly green

	# Apply eye style from customization
	var eye_style: String = GameManager.creature_customization.get("eye_style", "anime")
	match eye_style:
		"round":
			eye_squash_y = clampf(eye_squash_y * 1.0, 0.05, 1.3)
			iris_r = eye_r * 0.55
			pupil_r *= 1.2
		"compound":
			eye_r *= 0.7
		"googly":
			eye_r *= 1.3
			pupil_r *= 0.8
			iris_r = eye_r * 0.5
		"slit":
			eye_squash_y *= 0.6
			pupil_r *= 0.6
		"lashed":
			eye_r *= 1.05
			iris_r = eye_r * 0.6
		"fierce":
			eye_squash_y *= 0.65
			eye_r *= 1.1
			iris_r = eye_r * 0.55
		"dot":
			eye_r *= 0.5
			pupil_r *= 1.8
			iris_r = eye_r * 0.3
		"star":
			iris_r = eye_r * 0.7

	if _is_blinking:
		eye_squash_y = 0.05

	# --- DRAW EYES ---
	var mouse_local := (get_global_mouse_position() - global_position).rotated(-rotation)
	var look_dir := mouse_local.normalized() * minf(eye_r * 0.25, mouse_local.length() * 0.015)
	# Googly eyes: pupil rolls with gravity-like jiggle
	if eye_style == "googly":
		look_dir += Vector2(sin(_time * 3.7) * eye_r * 0.15, cos(_time * 2.9) * eye_r * 0.15)

	# Compound eyes: draw cluster of small facets instead of two big eyes
	if eye_style == "compound" and not _is_blinking:
		for eye_pos_v: Vector2 in [left_eye, right_eye]:
			var facet_r: float = eye_r * 0.35
			for row in range(3):
				for col in range(3):
					if row == 0 and (col == 0 or col == 2):
						continue
					if row == 2 and (col == 0 or col == 2):
						continue
					var c_offset: Vector2 = Vector2((col - 1) * facet_r * 1.8, (row - 1) * facet_r * 1.6)
					var fp: Vector2 = eye_pos_v + c_offset
					draw_circle(fp, facet_r, Color(iris_color.r * 0.8, iris_color.g * 0.8, iris_color.b, 0.7))
					draw_circle(fp, facet_r * 0.5, Color(0.05, 0.05, 0.1, 0.9))
					draw_arc(fp, facet_r, 0, TAU, 8, Color(0.2, 0.2, 0.3, 0.5), 0.5, true)
	elif eye_style == "dot" and not _is_blinking:
		# Minimalist dot eyes — just solid dark circles with subtle highlight
		for eye_pos_v: Vector2 in [left_eye, right_eye]:
			draw_circle(eye_pos_v, eye_r, pupil_color)
			draw_circle(eye_pos_v + Vector2(-eye_r * 0.2, -eye_r * 0.25), eye_r * 0.3, Color(1, 1, 1, 0.35))
	elif eye_style == "fierce" and not _is_blinking:
		# Angular aggressive eyes with heavy brow ridge
		for idx in range(2):
			var eye_pos: Vector2 = left_eye if idx == 0 else right_eye
			var hw: float = eye_r * 1.1
			var hh: float = eye_r * eye_squash_y * 0.7
			var side_flip: float = -1.0 if idx == 0 else 1.0
			# Angular eye shape
			var eye_pts: PackedVector2Array = PackedVector2Array([
				eye_pos + Vector2(-hw, 0),
				eye_pos + Vector2(-hw * 0.5, -hh),
				eye_pos + Vector2(hw * 0.7, -hh * 0.6),
				eye_pos + Vector2(hw, 0),
				eye_pos + Vector2(hw * 0.5, hh * 0.7),
				eye_pos + Vector2(-hw * 0.4, hh * 0.5),
			])
			draw_colored_polygon(eye_pts, eye_white_color)
			if eye_squash_y > 0.15:
				var p_pos: Vector2 = eye_pos + look_dir + pupil_offset
				draw_circle(p_pos, iris_r * 0.8, iris_color)
				draw_circle(p_pos, pupil_r, pupil_color)
				draw_circle(p_pos + Vector2(-pupil_r * 0.4, -pupil_r * 0.4), pupil_r * 0.3, Color(1, 1, 1, 0.7))
			# Heavy brow line
			draw_line(eye_pos + Vector2(-hw, -hh * 1.1), eye_pos + Vector2(hw * 0.8, -hh * 1.3), Color(0.1, 0.1, 0.18, 0.85), 2.5, true)
			# Eye outline
			for i in range(eye_pts.size()):
				draw_line(eye_pts[i], eye_pts[(i + 1) % eye_pts.size()], Color(0.1, 0.1, 0.2, 0.6), 0.8, true)
	elif eye_style == "star" and not _is_blinking:
		# Star-shaped decorative iris
		for idx in range(2):
			var eye_pos: Vector2 = left_eye if idx == 0 else right_eye
			var ew: float = eye_r
			var eh: float = eye_r * eye_squash_y
			# White sclera
			var eye_pts: PackedVector2Array = PackedVector2Array()
			for i in range(16):
				var a: float = TAU * i / 16.0
				eye_pts.append(eye_pos + Vector2(cos(a) * ew, sin(a) * eh))
			draw_colored_polygon(eye_pts, eye_white_color)
			if eye_squash_y > 0.15:
				var p_pos: Vector2 = eye_pos + look_dir + pupil_offset
				# Star iris
				var star_pts: PackedVector2Array = PackedVector2Array()
				for i in range(10):
					var a: float = -PI * 0.5 + TAU * i / 10.0
					var r_v: float = iris_r if i % 2 == 0 else iris_r * 0.4
					star_pts.append(p_pos + Vector2(cos(a) * r_v, sin(a) * r_v * eye_squash_y))
				draw_colored_polygon(star_pts, Color(iris_color.r, iris_color.g * 0.8, iris_color.b * 0.3, 0.9))
				draw_circle(p_pos, pupil_r * 0.8, pupil_color)
				draw_circle(p_pos + Vector2(-iris_r * 0.3, -iris_r * 0.3), pupil_r * 0.3, Color(1, 1, 1, 0.6))
			for i in range(eye_pts.size()):
				draw_line(eye_pts[i], eye_pts[(i + 1) % eye_pts.size()], Color(0.1, 0.15, 0.25, 0.6), 0.8, true)
	else:
		for idx in range(2):
			var eye_pos: Vector2 = left_eye if idx == 0 else right_eye
			var ew: float = eye_r
			var eh: float = eye_r * eye_squash_y
			# Slit pupil: override pupil shape to vertical slit
			var _slit_style: bool = eye_style == "slit"

			# Eye white (sclera) - clean oval
			var eye_pts: PackedVector2Array = PackedVector2Array()
			for i in range(16):
				var a: float = TAU * i / 16.0
				eye_pts.append(eye_pos + Vector2(cos(a) * ew, sin(a) * eh))

			# Slight shadow under eye for depth
			draw_colored_polygon(eye_pts, Color(0.85, 0.85, 0.9, 0.3))
			# Main white
			var offset_pts: PackedVector2Array = PackedVector2Array()
			for p in eye_pts:
				offset_pts.append(p + Vector2(-0.3, -0.3))
			draw_colored_polygon(offset_pts, eye_white_color)

			# Only draw iris/pupil if not fully squashed (blinking)
			if eye_squash_y > 0.15:
				var p_pos: Vector2 = eye_pos + look_dir + pupil_offset

				if show_spiral:
					# Spiral dizzy eyes for sick mood
					_draw_spiral_eye(p_pos, iris_r * 0.8, iris_color)
				else:
					# Iris (colored part)
					var iris_pts: PackedVector2Array = PackedVector2Array()
					var i_eh: float = iris_r * eye_squash_y
					for i in range(16):
						var a: float = TAU * i / 16.0
						iris_pts.append(p_pos + Vector2(cos(a) * iris_r, sin(a) * i_eh))
					draw_colored_polygon(iris_pts, iris_color)

					# Iris gradient/depth - darker ring
					draw_arc(p_pos, iris_r * 0.9, 0, TAU, 16, Color(iris_color.r * 0.6, iris_color.g * 0.6, iris_color.b * 0.8, 0.5), iris_r * 0.2, true)

					# Pupil - slit or round
					if _slit_style:
						# Vertical slit pupil
						var slit_h: float = pupil_r * eye_squash_y * 1.8
						var slit_w: float = pupil_r * 0.35
						var slit_pts: PackedVector2Array = PackedVector2Array([
							p_pos + Vector2(-slit_w, 0),
							p_pos + Vector2(0, -slit_h),
							p_pos + Vector2(slit_w, 0),
							p_pos + Vector2(0, slit_h),
						])
						draw_colored_polygon(slit_pts, pupil_color)
					else:
						var p_eh: float = pupil_r * eye_squash_y
						var pupil_pts: PackedVector2Array = PackedVector2Array()
						for i in range(12):
							var a: float = TAU * i / 12.0
							pupil_pts.append(p_pos + Vector2(cos(a) * pupil_r, sin(a) * p_eh))
						draw_colored_polygon(pupil_pts, pupil_color)

					# Anime sparkle highlights - two white dots
					if show_sparkles or mood == Mood.IDLE:
						var sparkle1 := p_pos + Vector2(-iris_r * 0.35, -iris_r * 0.35)
						var sparkle2 := p_pos + Vector2(iris_r * 0.2, iris_r * 0.3)
						var sparkle_pulse: float = 0.7 + 0.3 * sin(_eye_sparkle_timer * 3.0 + idx)
						draw_circle(sparkle1, pupil_r * 0.5 * sparkle_pulse, Color(1, 1, 1, 0.95))
						draw_circle(sparkle2, pupil_r * 0.25 * sparkle_pulse, Color(1, 1, 1, 0.8))
					else:
						# Basic highlight
						draw_circle(p_pos + Vector2(-pupil_r * 0.4, -pupil_r * 0.4), pupil_r * 0.35, Color(1, 1, 1, 0.8))

			# Eye outline for definition
			for i in range(eye_pts.size()):
				draw_line(eye_pts[i], eye_pts[(i + 1) % eye_pts.size()], Color(0.1, 0.15, 0.25, 0.6), 0.8, true)

			# Lashed style: add eyelashes on top arc
			if eye_style == "lashed" and not _is_blinking:
				for li in range(3):
					var la: float = -PI * 0.6 + li * PI * 0.3
					var lash_base: Vector2 = eye_pos + Vector2(cos(la) * ew, sin(la) * eh)
					var lash_tip: Vector2 = eye_pos + Vector2(cos(la) * (ew + 2.5), sin(la) * (eh + 2.5))
					draw_line(lash_base, lash_tip, Color(0.08, 0.08, 0.12, 0.9), 1.3, true)
				# Subtle lower lash line
				draw_arc(eye_pos, ew * 0.95, PI * 0.15, PI * 0.85, 6, Color(0.1, 0.1, 0.15, 0.4), 0.7, true)

	# --- EYEBROWS ---
	if _has_eyebrows:
		var brow_len: float = eye_r * 1.6
		var brow_y: float = eye_y_offset - eye_r * eye_squash_y - 3.0
		var brow_color := Color(0.12, 0.25, 0.5, 0.95)
		var lb_start := Vector2(left_eye.x - brow_len * 0.3, left_eye.y + brow_y)
		var lb_end := lb_start + Vector2(brow_len, 0).rotated(eyebrow_angle_l)
		draw_line(lb_start, lb_end, brow_color, 2.2, true)
		var rb_start := Vector2(right_eye.x - brow_len * 0.3, right_eye.y + brow_y)
		var rb_end := rb_start + Vector2(brow_len, 0).rotated(eyebrow_angle_r)
		draw_line(rb_start, rb_end, brow_color, 2.2, true)

	# --- SPEED LINES for ZOOM mood ---
	if show_speed_lines:
		for i in range(4):
			var line_y: float = -8.0 + i * 4.0
			var line_start := Vector2(-_cell_radius - 5.0 - i * 2.0, line_y)
			var line_end := Vector2(-_cell_radius - 15.0 - i * 3.0, line_y)
			var line_alpha: float = 0.4 + 0.2 * sin(_time * 10.0 + i)
			draw_line(line_start, line_end, Color(0.5, 0.8, 1.0, line_alpha), 1.5, true)

	# --- SWEAT DROPS ---
	if show_sweat:
		var sweat_x: float = right_eye.y + eye_r + 3.0
		var sweat_y: float = right_eye.x - eye_r * 0.5 + _sweat_drop_y * 8.0
		var sweat_alpha: float = 1.0 - _sweat_drop_y
		# Teardrop shape
		draw_circle(Vector2(sweat_y, sweat_x), 1.8 * sweat_alpha, Color(0.6, 0.8, 1.0, sweat_alpha * 0.7))
		draw_circle(Vector2(sweat_y - 1.0, sweat_x - 0.5), 1.0 * sweat_alpha, Color(0.7, 0.9, 1.0, sweat_alpha * 0.5))

	# Mouth removed — creature expression is all about the eyes

func _draw_spiral_eye(center: Vector2, size: float, color: Color) -> void:
	# Draw spiral/swirly eye for sick/dizzy state
	var spiral_col := Color(color.r * 0.8, color.g, color.b * 0.5, 0.9)
	var points: int = 24
	var turns: float = 2.5
	var prev_pt := center
	for i in range(1, points + 1):
		var t: float = float(i) / float(points)
		var angle: float = t * turns * TAU + _spiral_angle
		var r: float = t * size
		var pt := center + Vector2(cos(angle) * r, sin(angle) * r)
		draw_line(prev_pt, pt, spiral_col, 1.5 + (1.0 - t) * 1.5, true)
		prev_pt = pt

func _fire_toxin() -> void:
	energy -= toxin_cost
	toxin_timer = TOXIN_COOLDOWN
	_toxin_flash = 1.0
	_set_mood(Mood.ANGRY, 0.8)
	AudioManager.play_toxin()
	if camera and camera.has_method("shake"):
		camera.shake(4.0, 0.2)
	for body in $ToxinArea.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(toxin_damage)
			damage_dealt.emit(toxin_damage)
	# Toxin also detaches one parasite
	if attached_parasites.size() > 0:
		var p = attached_parasites.pop_back()
		if is_instance_valid(p) and p.has_method("force_detach"):
			p.force_detach()
		parasites_changed.emit(attached_parasites.size())

func _reproduce() -> void:
	energy -= repro_cost
	_set_mood(Mood.EXCITED, 1.2)
	reproduced.emit()
	reproduction_complete.emit()
	GameManager.add_reproduction()

func take_damage(amount: float) -> void:
	if _golden_aura_active:
		return  # Invulnerable during healing aura
	health -= amount
	_damage_flash = 1.0
	_set_mood(Mood.HURT, 0.6)
	AudioManager.play_hurt()
	AudioManager.play_player_voice("hurt")
	if camera and camera.has_method("shake"):
		camera.shake(clampf(amount * 0.4, 2.0, 8.0), 0.25)
	damaged.emit(amount)
	if health <= 0:
		AudioManager.play_death()
		AudioManager.play_player_voice("death")
		if camera and camera.has_method("shake"):
			camera.shake(12.0, 0.5)
		died.emit()

func heal(amount: float) -> void:
	health = minf(health + amount, max_health)

func attach_parasite(parasite: Node2D) -> void:
	attached_parasites.append(parasite)
	_set_mood(Mood.SCARED, 1.0)
	parasites_changed.emit(attached_parasites.size())

func feed(component: Dictionary) -> void:
	var energy_value: float = component.get("energy_value", 15.0)
	energy = minf(energy + energy_value, max_energy)
	_feed_flash = 1.0
	_set_mood(Mood.EATING, 0.6)
	var is_rare: bool = component.get("rarity", "common") in ["rare", "legendary"]
	AudioManager.play_collect(is_rare)
	food_consumed.emit()

	var comp_id: String = component.get("id", "")

	# Spawn collection VFX
	_spawn_collection_vfx(component)

	# Track in inventory by type
	if component.has("category"):
		GameManager.collect_biomolecule(component)
		biomolecule_category_collected.emit(component.get("category", ""))
	elif comp_id in ["Mitochondrion", "Chloroplast", "Ribosome", "Nucleus", "ER", "Flagellum", "Vacuole"]:
		GameManager.collect_organelle_item(component)
		organelle_collected.emit()

	collected_components.append(comp_id)

func _update_biomolecule_magnet(delta: float) -> void:
	## Gently pull nearby food particles toward the player based on sensory level
	var magnet_range: float = 60.0 + GameManager.sensory_level * 20.0  # 100-160 range
	var magnet_strength: float = 30.0 + GameManager.sensory_level * 15.0  # Gentle pull
	var food_nodes := get_tree().get_nodes_in_group("food")
	for food in food_nodes:
		if not is_instance_valid(food):
			continue
		if food.get("is_being_beamed"):  # Don't interfere with beam
			continue
		var dist: float = global_position.distance_to(food.global_position)
		if dist < magnet_range and dist > 10.0:
			var pull: float = magnet_strength * (1.0 - dist / magnet_range) * delta
			var dir: Vector2 = (global_position - food.global_position).normalized()
			food.global_position += dir * pull

func _try_eat_prey() -> void:
	var prey_nodes := get_tree().get_nodes_in_group("prey")
	for prey in prey_nodes:
		if not is_instance_valid(prey):
			continue
		if global_position.distance_to(prey.global_position) < EAT_RANGE:
			# Must be facing the prey to eat it (mouth is at front)
			if not _is_target_in_front(prey.global_position, 1.3):  # ~150 degree cone (easy eat when touching)
				continue
			if prey.has_method("get_eaten"):
				var nutrition: Dictionary = prey.get_eaten()
				heal(nutrition.get("health_restore", 10.0))
				energy = minf(energy + nutrition.get("energy_restore", 5.0), max_energy)
				_feed_flash = 1.0
				_set_mood(Mood.EATING, 0.8)
				_spawn_collection_vfx(nutrition)
				AudioManager.play_eat()
				if camera and camera.has_method("shake"):
					camera.shake(3.0, 0.15)
				prey_killed.emit()
				prey.queue_free()
				break  # One per frame

## --- DIRECTIONAL COMBAT HELPERS ---

func _is_target_in_front(target_pos: Vector2, arc: float = 0.5) -> bool:
	## Check if target is within the front arc (arc is in radians, 0.5 = ~60 degrees)
	var to_target: Vector2 = (target_pos - global_position).normalized()
	var facing: Vector2 = Vector2.RIGHT.rotated(rotation)
	var dot: float = to_target.dot(facing)
	return dot > cos(arc)

func _is_target_in_rear(target_pos: Vector2, arc: float = 0.5) -> bool:
	## Check if target is behind us
	var to_target: Vector2 = (target_pos - global_position).normalized()
	var facing: Vector2 = Vector2.RIGHT.rotated(rotation)
	var dot: float = to_target.dot(facing)
	return dot < -cos(arc)

func _is_target_on_sides(target_pos: Vector2, arc: float = 0.4) -> bool:
	## Check if target is on either side (perpendicular)
	var to_target: Vector2 = (target_pos - global_position).normalized()
	var facing: Vector2 = Vector2.RIGHT.rotated(rotation)
	var dot: float = abs(to_target.dot(facing))
	return dot < sin(arc)  # Near perpendicular

func _check_directional_contact_damage() -> void:
	## Check for directional damage against nearby enemies
	if _directional_contact_timer > 0:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	var competitors := get_tree().get_nodes_in_group("competitors")
	var all_targets: Array = []
	all_targets.append_array(enemies)
	all_targets.append_array(competitors)

	# Different ranges for different directions (tail extends further)
	var front_range: float = _cell_radius + 35.0  # Spikes/horns
	var rear_range: float = _cell_radius + 45.0   # Stingers/clubs extend far
	var side_range: float = _cell_radius + 30.0   # Barbs

	for target in all_targets:
		if not is_instance_valid(target):
			continue
		var dist: float = global_position.distance_to(target.global_position)
		# Skip if too far for any attack
		if dist > rear_range:
			continue

		var damage: float = 0.0
		var hit_type: String = ""

		# Front spike/horn damage - wider arc (0.7 radians = ~80 degrees)
		if _has_directional_front and dist <= front_range and _is_target_in_front(target.global_position, 0.7):
			damage += _directional_front_damage
			hit_type = "front"

		# Rear stinger damage - wider arc for tail sweep (0.8 radians = ~90 degrees)
		if _has_directional_rear and dist <= rear_range and _is_target_in_rear(target.global_position, 0.8):
			damage += _directional_rear_damage
			hit_type = "rear" if hit_type == "" else hit_type

		# Side barb damage
		if _has_directional_sides and dist <= side_range and _is_target_on_sides(target.global_position, 0.5):
			damage += _directional_sides_damage
			hit_type = "sides" if hit_type == "" else hit_type

		if hit_type != "" and damage > 0 and target.has_method("take_damage"):
			# Rear attacks use take_damage_from_behind if available (e.g. Basilisk)
			if hit_type == "rear" and target.has_method("take_damage_from_behind"):
				target.take_damage_from_behind(damage)
			else:
				target.take_damage(damage)
			damage_dealt.emit(damage)
			_directional_contact_timer = DIRECTIONAL_CONTACT_COOLDOWN
			# Visual feedback based on hit type
			match hit_type:
				"front":
					_front_hit_flash = 1.0
					_set_mood(Mood.ANGRY, 0.4)
				"rear":
					_tail_hit_flash = 1.0
					_set_mood(Mood.EXCITED, 0.3)
				"sides":
					_toxin_flash = 0.5
			AudioManager.play_toxin()  # Impact sound
			break  # One target per check

func _metabolize() -> void:
	# Convert some collected nutrients into energy
	var consumed: int = GameManager.metabolize_nutrients(3)  # Try to consume 3 items
	if consumed > 0:
		var gain: float = METABOLIZE_ENERGY_GAIN * consumed
		energy = minf(energy + gain, max_energy)
		metabolize_timer = METABOLIZE_COOLDOWN
		_feed_flash = 0.6
		_set_mood(Mood.HAPPY, 0.5)

## --- WAKE TRAIL ---

func _spawn_wake_particle() -> void:
	if _wake_particles.size() >= MAX_WAKE:
		return
	var behind: Vector2 = -velocity.normalized() * (_cell_radius + 2.0)
	var perp := Vector2(-behind.y, behind.x).normalized()
	_wake_particles.append({
		"pos": global_position + behind + perp * randf_range(-5.0, 5.0),
		"life": 1.0,
		"size": randf_range(1.5, 3.5),
		"color": Color(0.4, 0.7, 1.0, 0.3) if not is_sprinting else Color(0.6, 0.9, 1.0, 0.5),
	})

func _update_wake_particles(delta: float) -> void:
	var alive: Array = []
	for p in _wake_particles:
		p.life -= delta * 1.5
		if p.life > 0:
			alive.append(p)
	_wake_particles = alive

## --- TRACTOR BEAM + JET STREAM ---

func _update_targeting() -> void:
	## Find nearest beamable target near the mouse cursor
	var mouse_pos := get_global_mouse_position()
	_target_candidate = null
	_target_type = ""
	var best_dist: float = 60.0  # Cursor must be within 60px of a target

	# Check food particles
	for food in get_tree().get_nodes_in_group("food"):
		if not is_instance_valid(food):
			continue
		var d_to_cursor: float = mouse_pos.distance_to(food.global_position)
		var d_to_player: float = global_position.distance_to(food.global_position)
		if d_to_cursor < best_dist and d_to_player < BEAM_RANGE:
			best_dist = d_to_cursor
			_target_candidate = food
			_target_type = "food"

	# Check prey
	for prey in get_tree().get_nodes_in_group("prey"):
		if not is_instance_valid(prey):
			continue
		var d_to_cursor: float = mouse_pos.distance_to(prey.global_position)
		var d_to_player: float = global_position.distance_to(prey.global_position)
		if d_to_cursor < best_dist and d_to_player < BEAM_RANGE:
			best_dist = d_to_cursor
			_target_candidate = prey
			_target_type = "prey"

func _update_beam(delta: float) -> void:
	var wants_beam: bool = Input.is_action_just_pressed("beam_collect")

	# Start new beam on click (only if not already pulling something)
	if wants_beam and _target_candidate and energy > 1.0 and not _beam_active:
		_beam_target = _target_candidate
		_beam_active = true
		_set_mood(Mood.EXCITED, 0.3)

	# Auto-pull active beam target (no need to hold button)
	if _beam_active:
		if not is_instance_valid(_beam_target):
			_beam_active = false
			_beam_target = null
			return

		if energy <= 0.0:
			# Out of energy — release beam
			if _beam_target.has_method("beam_release"):
				_beam_target.beam_release()
			_beam_active = false
			_beam_target = null
			return

		# Pull target toward us
		if _beam_target.has_method("beam_pull_toward"):
			_beam_target.beam_pull_toward(global_position, delta)
			energy -= BEAM_ENERGY_COST * delta
			energy = maxf(energy, 0.0)

			# Spawn beam particles (fluid stream from target to player)
			var target_pos: Vector2 = _beam_target.global_position
			var beam_color: Color = _beam_target.get_beam_color() if _beam_target.has_method("get_beam_color") else Color(0.5, 0.8, 1.0)
			_spawn_beam_particles(target_pos, beam_color)

			# Check if close enough to consume (auto-consume regardless of facing)
			var dist: float = global_position.distance_to(target_pos)
			if dist < BEAM_COLLECT_DIST:
				_consume_beam_target()

func _consume_beam_target() -> void:
	if not is_instance_valid(_beam_target):
		_beam_active = false
		_beam_target = null
		return

	if _beam_target.is_in_group("boss_eyes"):
		# Boss eye — let the boss handle it via beam_pull_toward, don't consume
		_beam_active = false
		_beam_target = null
		return
	if _beam_target.has_method("feed") or _beam_target.is_in_group("food"):
		# It's a food particle — use feed()
		if _beam_target.has_method("setup"):
			feed(_beam_target.component_data)
		_beam_target.queue_free()
	elif _beam_target.has_method("get_eaten"):
		# It's prey
		var nutrition: Dictionary = _beam_target.get_eaten()
		heal(nutrition.get("health_restore", 10.0))
		energy = minf(energy + nutrition.get("energy_restore", 5.0), max_energy)
		_feed_flash = 1.0
		_set_mood(Mood.EATING, 0.8)
		_spawn_collection_vfx(nutrition)
		_beam_target.queue_free()

	_beam_active = false
	_beam_target = null

func _spawn_beam_particles(target_pos: Vector2, color: Color) -> void:
	# Spawn 2-3 particles per frame along the beam path
	for i in range(randi_range(2, 3)):
		var t: float = randf()
		var pos: Vector2 = target_pos.lerp(global_position, t)
		# Add perpendicular wobble for fluid look
		var beam_dir: Vector2 = (global_position - target_pos).normalized()
		var perp := Vector2(-beam_dir.y, beam_dir.x)
		pos += perp * randf_range(-6.0, 6.0) * (1.0 - t)  # More wobble near target
		_beam_particles.append({
			"pos": pos,
			"vel": beam_dir * randf_range(80.0, 160.0) + perp * randf_range(-20.0, 20.0),
			"life": 1.0,
			"color": color.lerp(Color(0.6, 0.9, 1.0), randf_range(0.0, 0.3)),
			"size": randf_range(1.0, 2.5),
		})

func _update_beam_particles(delta: float) -> void:
	var alive: Array = []
	for p in _beam_particles:
		p.life -= delta * 2.5
		p.pos += p.vel * delta
		p.vel *= 0.92
		if p.life > 0:
			alive.append(p)
	_beam_particles = alive

func _update_jet(delta: float) -> void:
	_jet_active = Input.is_action_pressed("jet_stream") and GameManager.get_total_collected() > GameManager.inventory.organelles.size()

	if _jet_active:
		# Consume nutrients periodically
		_jet_consume_timer -= delta
		if _jet_consume_timer <= 0:
			_jet_consume_timer = JET_CONSUME_INTERVAL
			var colors: Array = GameManager.consume_for_jet(1)
			if colors.size() > 0:
				_jet_colors = colors
				AudioManager.play_jet()
			else:
				_jet_active = false
				return

		# Spray direction = toward cursor
		var jet_dir := (get_global_mouse_position() - global_position).normalized()
		var jet_origin := global_position + jet_dir * (_cell_radius + 2.0)

		# Spawn jet particles (reduced for performance)
		for i in range(2):
			var spread: float = randf_range(-JET_CONE_ANGLE, JET_CONE_ANGLE)
			var p_dir: Vector2 = jet_dir.rotated(spread)
			var col: Color = _jet_colors[randi() % _jet_colors.size()] if _jet_colors.size() > 0 else Color(0.5, 0.8, 1.0)
			_jet_particles.append({
				"pos": jet_origin + p_dir * randf_range(0, 5),
				"vel": p_dir * randf_range(200.0, 350.0),
				"life": 1.0,
				"color": col.lerp(Color.WHITE, randf_range(0.0, 0.2)),
				"size": randf_range(1.5, 3.5),
			})

		# Push enemies in cone
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var to_enemy: Vector2 = enemy.global_position - global_position
			var dist: float = to_enemy.length()
			if dist > JET_RANGE or dist < 1.0:
				continue
			var angle_to: float = absf(jet_dir.angle_to(to_enemy.normalized()))
			if angle_to < JET_CONE_ANGLE * 1.5:
				# Push and confuse
				if enemy is CharacterBody2D:
					enemy.velocity += jet_dir * JET_PUSH_FORCE * delta
				if enemy.has_method("confuse"):
					enemy.confuse(JET_CONFUSE_DURATION)
				# Jet damages rear-vulnerable enemies from behind
				if enemy.has_method("take_damage_from_behind"):
					var to_enemy_dir: Vector2 = to_enemy.normalized()
					var enemy_facing: Vector2 = Vector2.RIGHT.rotated(enemy.rotation)
					if to_enemy_dir.dot(enemy_facing) < -0.3:  # Hitting from behind
						enemy.take_damage_from_behind(3.0 * delta)

		# Small energy cost on top of nutrient consumption
		energy -= 1.0 * delta
		energy = maxf(energy, 0.0)

func _update_jet_particles(delta: float) -> void:
	var alive: Array = []
	for p in _jet_particles:
		p.life -= delta * 2.0
		p.pos += p.vel * delta
		p.vel *= 0.95
		p.size *= 0.98
		if p.life > 0:
			alive.append(p)
	_jet_particles = alive

func _spawn_collection_vfx(component: Dictionary) -> void:
	var vfx_scene := preload("res://scenes/collection_vfx.tscn")
	var vfx := vfx_scene.instantiate()
	var display_name: String = component.get("short_name", component.get("display_name", component.get("id", "")))
	var c: Array = component.get("color", [1.0, 1.0, 1.0])
	var color := Color(c[0], c[1], c[2]) if c.size() >= 3 else Color.WHITE
	var is_rare: bool = component.get("rarity", "common") in ["rare", "legendary"]
	vfx.setup(display_name, color, is_rare)
	vfx.global_position = global_position
	get_parent().add_child(vfx)

# --- MUTATION SYSTEM ---

var _health_regen_rate: float = 0.0

func _apply_mutation_stats() -> void:
	for m in GameManager.active_mutations:
		_apply_single_mutation_stats(m)

func _apply_single_mutation_stats(m: Dictionary) -> void:
	var stat: Dictionary = m.get("stat", {})
	if "speed" in stat:
		move_speed *= (1.0 + stat.speed)
	if "attack" in stat:
		toxin_damage *= (1.0 + stat.attack)
	if "max_health" in stat:
		max_health *= (1.0 + stat.max_health)
		health = minf(health + max_health * stat.max_health, max_health)
	if "armor" in stat:
		max_health *= (1.0 + stat.armor * 0.5)
	if "energy_efficiency" in stat:
		max_energy *= (1.0 + stat.energy_efficiency)
		energy = minf(energy + max_energy * stat.energy_efficiency, max_energy)
	if "beam_range" in stat:
		# Can't modify const but we track it
		pass
	if "health_regen" in stat:
		_health_regen_rate += stat.health_regen * 2.0
	if "detection" in stat:
		pass  # Handled by sensory system
	if "stealth" in stat:
		pass  # Future use

	# Directional damage mutations
	var directional: String = m.get("directional", "")
	if directional != "":
		var attack_bonus: float = stat.get("attack", 0.2) * toxin_damage
		match directional:
			"front":
				_has_directional_front = true
				_directional_front_damage += attack_bonus
			"rear":
				_has_directional_rear = true
				_directional_rear_damage += attack_bonus
			"sides":
				_has_directional_sides = true
				_directional_sides_damage += attack_bonus

func _on_evolution_applied(mutation: Dictionary) -> void:
	_apply_single_mutation_stats(mutation)
	# Visual feedback: flash and grow briefly
	_feed_flash = 1.0
	_set_mood(Mood.EXCITED, 2.0)
	if camera and camera.has_method("shake"):
		camera.shake(6.0, 0.4)
	# Grow cell slightly for larger_membrane
	if mutation.get("visual", "") == "larger_membrane":
		_cell_radius += 3.0
	# Elongate cell with each evolution
	_compute_elongation()
	_init_procedural_shape()
	# Update camera zoom for sensory upgrades
	if mutation.get("sensory_upgrade", false):
		_update_sensory_zoom(true)

func _update_sensory_zoom(animate: bool) -> void:
	var sens_level: int = clampi(GameManager.sensory_level, 0, ZOOM_LEVELS.size() - 1)
	_target_zoom = ZOOM_LEVELS[sens_level]
	if not animate and camera:
		_current_zoom = _target_zoom
		camera.zoom = Vector2(_current_zoom, _current_zoom)

func _compute_elongation() -> void:
	_elongation_offset = GameManager.creature_customization.get("body_elongation_offset", 0.0)
	_bulge = GameManager.creature_customization.get("body_bulge", 1.0)
	_elongation = clampf(1.0 + GameManager.evolution_level * 0.15 + _elongation_offset, 0.5, 2.5)
	_update_collision_shape()

func _update_collision_shape() -> void:
	var coll := get_node_or_null("CollisionShape2D")
	if not coll:
		return
	if _elongation > 1.1:
		var cap := CapsuleShape2D.new()
		cap.radius = _cell_radius
		cap.height = _cell_radius * _elongation * 2.0
		coll.shape = cap
		coll.rotation = PI / 2.0
	else:
		var circle := CircleShape2D.new()
		circle.radius = _cell_radius
		coll.shape = circle
		coll.rotation = 0.0

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, segments: int = 24) -> void:
	if absf(rx - ry) < 0.5:
		draw_circle(center, rx, color)
		return
	var pts := PackedVector2Array()
	for i in range(segments):
		var a: float = TAU * i / segments
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)

## Mutations that draw around the whole body — always at default position
const GLOBAL_MUTATIONS: Array = [
	"extra_cilia", "spikes", "armor_plates", "color_shift", "bioluminescence",
	"thick_membrane", "regeneration", "pili_network", "absorption_villi",
	"electroreceptors", "electric_organ", "side_barbs", "lateral_line",
	"larger_membrane",
]

func _draw_mutation_visual(vis: String) -> void:
	match vis:
		"extra_cilia": _draw_mut_extra_cilia()
		"spikes": _draw_mut_spikes()
		"armor_plates": _draw_mut_armor_plates()
		"color_shift": _draw_mut_color_shift()
		"bioluminescence": _draw_mut_bioluminescence()
		"flagellum": _draw_mut_flagellum()
		"third_eye": _draw_mut_third_eye()
		"eye_stalks": _draw_mut_eye_stalks()
		"tentacles": _draw_mut_tentacles()
		"larger_membrane": pass
		"toxin_glands": _draw_mut_toxin_glands()
		"photoreceptor": _draw_mut_photoreceptor()
		"thick_membrane": _draw_mut_thick_membrane()
		"enzyme_boost": _draw_mut_enzyme_boost()
		"regeneration": _draw_mut_regeneration()
		"sprint_boost": _draw_mut_sprint_boost()
		"compound_eye": _draw_mut_compound_eye()
		"absorption_villi": _draw_mut_absorption_villi()
		"dorsal_fin": _draw_mut_dorsal_fin()
		"ink_sac": _draw_mut_ink_sac()
		"electric_organ": _draw_mut_electric_organ()
		"symbiont_pouch": _draw_mut_symbiont_pouch()
		"hardened_nucleus": _draw_mut_hardened_nucleus()
		"pili_network": _draw_mut_pili_network()
		"chrono_enzyme": _draw_mut_chrono_enzyme()
		"thermal_vent_organ": _draw_mut_thermal_vent_organ()
		"lateral_line": _draw_mut_lateral_line()
		"beak": _draw_mut_beak()
		"gas_vacuole": _draw_mut_gas_vacuole()
		"front_spike": _draw_mut_front_spike()
		"mandibles": _draw_mut_mandibles()
		"side_barbs": _draw_mut_side_barbs()
		"rear_stinger": _draw_mut_rear_stinger()
		"ramming_crest": _draw_mut_ramming_crest()
		"proboscis": _draw_mut_proboscis()
		"tail_club": _draw_mut_tail_club()
		"electroreceptors": _draw_mut_electroreceptors()
		"antenna": _draw_mut_antenna()

func _draw_mutations() -> void:
	for m in GameManager.active_mutations:
		var vis: String = m.get("visual", "")
		var mid: String = m.get("id", "")
		# Global mutations always draw at default position
		if vis in GLOBAL_MUTATIONS:
			_draw_mutation_visual(vis)
			continue
		# Check if this mutation has placement data
		var placement: Dictionary = GameManager.mutation_placements.get(mid, {})
		if placement.is_empty():
			_draw_mutation_visual(vis)
			continue
		# Angular placement system (new)
		if placement.has("angle"):
			var angle: float = placement.get("angle", 0.0)
			var distance: float = placement.get("distance", 1.0)
			var mirrored: bool = placement.get("mirrored", false)
			var mut_scale: float = placement.get("scale", 1.0)
			var rot_offset: float = placement.get("rotation_offset", 0.0)
			var pos: Vector2 = SnapPointSystem.angle_to_perimeter_position(angle, _cell_radius, _elongation, distance)
			var outward_rot: float = SnapPointSystem.get_outward_rotation(angle) + rot_offset
			draw_set_transform(pos, outward_rot, Vector2(mut_scale, mut_scale))
			_draw_mutation_visual(vis)
			if mirrored:
				var mirror_angle: float = SnapPointSystem.get_mirror_angle(angle)
				var mirror_pos: Vector2 = SnapPointSystem.angle_to_perimeter_position(mirror_angle, _cell_radius, _elongation, distance)
				var mirror_rot: float = SnapPointSystem.get_outward_rotation(mirror_angle) - rot_offset
				draw_set_transform(mirror_pos, mirror_rot, Vector2(mut_scale, mut_scale))
				_draw_mutation_visual(vis)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		# Legacy snap_slot fallback
		var slot: int = placement.get("snap_slot", -1)
		var mirrored: bool = placement.get("mirrored", false)
		if slot < 0:
			_draw_mutation_visual(vis)
			continue
		var snap_pos: Vector2 = SnapPointSystem.get_snap_position(slot, _cell_radius, _elongation)
		var mut_scale: float = placement.get("scale", 1.0)
		var scale_vec: Vector2 = Vector2(mut_scale, mut_scale)
		draw_set_transform(snap_pos, 0.0, scale_vec)
		_draw_mutation_visual(vis)
		if mirrored:
			var mirror_slot: int = SnapPointSystem.get_mirrored_slot(slot)
			if mirror_slot >= 0:
				var mirror_pos: Vector2 = SnapPointSystem.get_snap_position(mirror_slot, _cell_radius, _elongation)
				draw_set_transform(mirror_pos, 0.0, scale_vec)
				_draw_mutation_visual(vis)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_mut_extra_cilia() -> void:
	for i in range(8):
		var a: float = TAU * i / 8.0 + 0.2
		var wave: float = sin(_time * 10.0 + i * 1.5) * 0.3
		var base := Vector2(cos(a) * _cell_radius, sin(a) * _cell_radius)
		var tip := base + Vector2(cos(a + wave) * 14.0, sin(a + wave) * 14.0)
		draw_line(base, tip, Color(0.4, 0.9, 1.0, 0.6), 1.0, true)

func _draw_mut_spikes() -> void:
	for i in range(8):
		var a: float = TAU * i / 8.0
		var base := Vector2(cos(a) * _cell_radius, sin(a) * _cell_radius)
		var tip := base + Vector2(cos(a), sin(a)) * (10.0 + sin(_time * 2.0 + i) * 2.0)
		draw_line(base, tip, Color(0.9, 0.3, 0.2, 0.8), 2.0, true)
		# Barb
		var mid := (base + tip) * 0.5
		var perp := Vector2(-sin(a), cos(a))
		draw_line(mid, mid + perp * 3.0, Color(0.9, 0.3, 0.2, 0.5), 1.0, true)

func _draw_mut_armor_plates() -> void:
	for i in range(5):
		var a: float = TAU * i / 5.0 + PI * 0.3
		var p := Vector2(cos(a), sin(a)) * (_cell_radius - 2.0)
		var perp := Vector2(-sin(a), cos(a))
		var pts: PackedVector2Array = PackedVector2Array([
			p + perp * 5.0, p - perp * 5.0,
			p - perp * 4.0 + Vector2(cos(a), sin(a)) * 4.0,
			p + perp * 4.0 + Vector2(cos(a), sin(a)) * 4.0,
		])
		draw_colored_polygon(pts, Color(0.4, 0.5, 0.6, 0.5))

func _draw_mut_color_shift() -> void:
	var hue: float = fmod(_time * 0.15, 1.0)
	var col := Color.from_hsv(hue, 0.4, 0.8, 0.15)
	draw_circle(Vector2.ZERO, _cell_radius * 0.9, col)

func _draw_mut_bioluminescence() -> void:
	var pulse: float = 0.3 + 0.2 * sin(_time * 3.0)
	draw_circle(Vector2.ZERO, _cell_radius * 1.8, Color(0.2, 0.8, 1.0, pulse * 0.1))
	draw_circle(Vector2.ZERO, _cell_radius * 1.2, Color(0.3, 0.9, 0.6, pulse * 0.15))

func _draw_mut_flagellum() -> void:
	var base := Vector2(-_cell_radius * _elongation - 2.0, 0)
	for i in range(14):
		var t: float = float(i) / 13.0
		var px: float = base.x - t * 28.0
		var py: float = sin(_time * 8.0 + t * 5.0) * 8.0 * t
		if i > 0:
			var pt: float = float(i - 1) / 13.0
			var ppx: float = base.x - pt * 28.0
			var ppy: float = sin(_time * 8.0 + pt * 5.0) * 8.0 * pt
			draw_line(Vector2(ppx, ppy), Vector2(px, py), Color(0.5, 0.8, 0.4, 0.7), 2.0 - t * 1.2, true)

func _draw_mut_third_eye() -> void:
	var pos := Vector2(_cell_radius * 0.2, 0)
	draw_circle(pos, 3.5, Color(0.95, 0.95, 1.0, 0.9))
	var look := (get_global_mouse_position() - global_position).normalized().rotated(-rotation)
	draw_circle(pos + look * 1.0, 1.8, Color(0.6, 0.1, 0.8, 1.0))
	draw_circle(pos + look * 1.0 + Vector2(-0.3, -0.3), 0.6, Color(1, 1, 1, 0.6))

func _draw_mut_eye_stalks() -> void:
	for side in [-1.0, 1.0]:
		var base := Vector2(2.0, side * _cell_radius * 0.7)
		var tip := base + Vector2(10.0, side * 12.0 + sin(_time * 2.5 + side) * 2.0)
		draw_line(base, tip, Color(0.4, 0.6, 0.3, 0.7), 1.5, true)
		draw_circle(tip, 3.0, Color(0.95, 0.95, 1.0, 0.9))
		var look := (get_global_mouse_position() - global_position).normalized().rotated(-rotation)
		draw_circle(tip + look * 0.8, 1.5, Color(0.1, 0.3, 0.1, 1.0))

func _draw_mut_tentacles() -> void:
	for i in range(3):
		var base_a: float = PI + (i - 1) * 0.4
		var base := Vector2(cos(base_a), sin(base_a)) * _cell_radius
		for s in range(10):
			var t: float = float(s) / 9.0
			var px: float = base.x + cos(base_a) * t * 25.0 + sin(_time * 3.0 + i + t * 3.0) * 5.0 * t
			var py: float = base.y + sin(base_a) * t * 25.0 + cos(_time * 2.5 + i * 2.0 + t * 2.0) * 4.0 * t
			if s > 0:
				var pt: float = float(s - 1) / 9.0
				var ppx: float = base.x + cos(base_a) * pt * 25.0 + sin(_time * 3.0 + i + pt * 3.0) * 5.0 * pt
				var ppy: float = base.y + sin(base_a) * pt * 25.0 + cos(_time * 2.5 + i * 2.0 + pt * 2.0) * 4.0 * pt
				draw_line(Vector2(ppx, ppy), Vector2(px, py), Color(0.6, 0.4, 0.8, 0.6 - t * 0.3), 2.0 - t * 1.5, true)

func _draw_mut_toxin_glands() -> void:
	for i in range(3):
		var a: float = TAU * i / 3.0 + PI * 0.5
		var p := Vector2(cos(a), sin(a)) * (_cell_radius * 0.75)
		var pulse: float = 0.6 + 0.3 * sin(_time * 4.0 + i * 2.0)
		draw_circle(p, 3.0 * pulse, Color(0.5, 0.9, 0.1, 0.5))

func _draw_mut_photoreceptor() -> void:
	for i in range(3):
		var a: float = -0.4 + i * 0.4
		var p := Vector2(cos(a), sin(a)) * (_cell_radius * 0.6)
		var glow: float = 0.4 + 0.3 * sin(_time * 3.0 + i)
		draw_circle(p, 2.5, Color(0.8, 0.9, 1.0, glow))

func _draw_mut_thick_membrane() -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(NUM_MEMBRANE_PTS):
		var wobble := sin(_time * 3.0 + i * 0.7) * 1.0
		pts.append(_membrane_points[i].normalized() * (_cell_radius + 3.0 + wobble))
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.4, 0.6, 0.9, 0.35), 2.5, true)

func _draw_mut_enzyme_boost() -> void:
	for i in range(4):
		var a: float = TAU * i / 4.0 + _time * 1.5
		var r: float = _cell_radius * 0.4 + sin(_time * 4.0 + i) * 3.0
		var p := Vector2(cos(a), sin(a)) * r
		draw_circle(p, 1.8, Color(1.0, 0.8, 0.2, 0.4 + 0.2 * sin(_time * 5.0 + i)))

func _draw_mut_regeneration() -> void:
	var pulse: float = 0.15 + 0.1 * sin(_time * 2.0)
	draw_circle(Vector2.ZERO, _cell_radius * 1.3, Color(0.2, 0.9, 0.3, pulse))

func _draw_mut_sprint_boost() -> void:
	if velocity.length() > move_speed * 0.5:
		for i in range(3):
			var trail_pos := Vector2(-_cell_radius - 4.0 - i * 6.0, (i - 1) * 3.0)
			draw_line(trail_pos, trail_pos + Vector2(-8.0, 0), Color(0.4, 0.8, 1.0, 0.3 - i * 0.08), 1.5, true)

func _draw_mut_compound_eye() -> void:
	for row in range(2):
		for col in range(2):
			var p := Vector2(_cell_radius * 0.3 + col * 4.0, (row - 0.5) * 5.0)
			draw_circle(p, 2.0, Color(0.85, 0.85, 1.0, 0.6))
			draw_circle(p, 1.0, Color(0.1, 0.1, 0.3, 0.8))

func _draw_mut_absorption_villi() -> void:
	for i in range(10):
		var a: float = TAU * i / 10.0 + 0.15
		var base := Vector2(cos(a), sin(a)) * _cell_radius
		var tip := base + Vector2(cos(a), sin(a)) * (6.0 + sin(_time * 3.0 + i) * 2.0)
		draw_line(base, tip, Color(0.8, 0.6, 0.3, 0.5), 1.0, true)
		draw_circle(tip, 1.2, Color(0.9, 0.7, 0.4, 0.6))

func _draw_mut_dorsal_fin() -> void:
	# Triangular fin on top
	var wave: float = sin(_time * 3.0) * 2.0
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(4.0, -_cell_radius),
		Vector2(-6.0, -_cell_radius - 10.0 + wave),
		Vector2(-8.0, -_cell_radius),
	])
	draw_colored_polygon(pts, Color(0.3, 0.6, 0.9, 0.5))
	draw_line(pts[0], pts[1], Color(0.4, 0.7, 1.0, 0.7), 1.0, true)
	draw_line(pts[1], pts[2], Color(0.4, 0.7, 1.0, 0.7), 1.0, true)

func _draw_mut_ink_sac() -> void:
	# Dark sac visible inside body
	var p := Vector2(-_cell_radius * 0.4, 0)
	var pulse: float = 0.5 + 0.2 * sin(_time * 2.0)
	draw_circle(p, 4.0, Color(0.1, 0.05, 0.15, pulse))
	draw_circle(p, 2.5, Color(0.2, 0.1, 0.3, pulse * 0.8))

func _draw_mut_electric_organ() -> void:
	# Crackling arcs around body
	for i in range(3):
		var a: float = TAU * i / 3.0 + _time * 5.0
		var p1 := Vector2(cos(a), sin(a)) * _cell_radius
		var jitter := Vector2(sin(_time * 20.0 + i * 7.0) * 4.0, cos(_time * 18.0 + i * 5.0) * 4.0)
		var p2 := p1 + Vector2(cos(a), sin(a)) * 8.0 + jitter
		draw_line(p1, p2, Color(0.5, 0.8, 1.0, 0.6), 1.0, true)

func _draw_mut_symbiont_pouch() -> void:
	# Tiny orbiting dots (symbiotic bacteria)
	for i in range(4):
		var a: float = _time * 1.5 + TAU * i / 4.0
		var p := Vector2(cos(a), sin(a)) * (_cell_radius * 0.5)
		draw_circle(p, 1.5, Color(0.3, 0.9, 0.5, 0.5))

func _draw_mut_hardened_nucleus() -> void:
	# Bright core with hexagonal outline
	draw_circle(Vector2.ZERO, 5.0, Color(0.4, 0.3, 0.6, 0.3))
	for i in range(6):
		var a1: float = TAU * i / 6.0
		var a2: float = TAU * (i + 1) / 6.0
		draw_line(Vector2(cos(a1), sin(a1)) * 5.0, Vector2(cos(a2), sin(a2)) * 5.0, Color(0.6, 0.5, 0.9, 0.5), 1.0, true)

func _draw_mut_pili_network() -> void:
	# Fine hair-like projections
	for i in range(16):
		var a: float = TAU * i / 16.0
		var base := Vector2(cos(a), sin(a)) * _cell_radius
		var tip := base + Vector2(cos(a), sin(a)) * (4.0 + sin(_time * 2.0 + i) * 1.5)
		draw_line(base, tip, Color(0.6, 0.7, 0.5, 0.3), 0.5, true)

func _draw_mut_chrono_enzyme() -> void:
	# Swirling internal particles (fast orbiting)
	for i in range(5):
		var a: float = _time * 4.0 + TAU * i / 5.0
		var r: float = _cell_radius * 0.35 + sin(_time * 6.0 + i) * 2.0
		var p := Vector2(cos(a), sin(a)) * r
		draw_circle(p, 1.2, Color(1.0, 0.6, 0.2, 0.5))

func _draw_mut_thermal_vent_organ() -> void:
	# Warm glow patches
	for i in range(3):
		var a: float = TAU * i / 3.0 + 0.5
		var p := Vector2(cos(a), sin(a)) * (_cell_radius * 0.6)
		var pulse: float = 0.3 + 0.15 * sin(_time * 2.5 + i)
		draw_circle(p, 3.0, Color(0.9, 0.4, 0.1, pulse))

func _draw_mut_lateral_line() -> void:
	# Dotted line along the equator
	for i in range(8):
		var t: float = float(i) / 7.0
		var px: float = lerpf(-_cell_radius, _cell_radius, t)
		var pulse: float = 0.3 + 0.2 * sin(_time * 3.0 + i)
		draw_circle(Vector2(px, 0), 1.0, Color(0.5, 0.7, 1.0, pulse))

func _draw_mut_beak() -> void:
	# Pointed beak at front
	var fr: float = _cell_radius * _elongation
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(fr + 1.0, -3.0),
		Vector2(fr + 9.0, 0),
		Vector2(fr + 1.0, 3.0),
	])
	draw_colored_polygon(pts, Color(0.7, 0.5, 0.2, 0.8))
	draw_line(pts[0], pts[1], Color(0.5, 0.35, 0.1, 0.9), 1.0, true)
	draw_line(pts[1], pts[2], Color(0.5, 0.35, 0.1, 0.9), 1.0, true)

func _draw_mut_gas_vacuole() -> void:
	# Translucent internal bubble
	var bob: float = sin(_time * 1.5) * 2.0
	draw_circle(Vector2(0, bob), 5.0, Color(0.7, 0.85, 1.0, 0.12))
	draw_arc(Vector2(0, bob), 5.0, 0, TAU, 12, Color(0.7, 0.9, 1.0, 0.2), 0.8, true)

## --- DIRECTIONAL MUTATION VISUALS ---

func _draw_mut_front_spike() -> void:
	# Big horn at front of cell
	var spike_col := Color(0.85, 0.75, 0.5, 0.9)
	var edge_col := Color(0.7, 0.5, 0.2, 1.0)
	# Flash on impact
	if _front_hit_flash > 0:
		spike_col = spike_col.lerp(Color(1.0, 0.9, 0.6, 1.0), _front_hit_flash)
		edge_col = edge_col.lerp(Color(1.0, 0.8, 0.4, 1.0), _front_hit_flash)
	var fr: float = _cell_radius * _elongation
	var base1 := Vector2(fr - 2.0, -4.0)
	var base2 := Vector2(fr - 2.0, 4.0)
	# Jab forward on hit
	var jab: float = _front_hit_flash * 6.0 * sin(_front_hit_flash * PI)
	var tip := Vector2(fr + 18.0 + sin(_time * 3.0) * 2.0 + jab, 0)
	var pts: PackedVector2Array = PackedVector2Array([base1, tip, base2])
	draw_colored_polygon(pts, spike_col)
	draw_line(base1, tip, edge_col, 1.5, true)
	draw_line(base2, tip, edge_col, 1.5, true)
	# Danger glow when moving fast or hitting
	if velocity.length() > 100 or _front_hit_flash > 0:
		var glow_size: float = 4.0 + _front_hit_flash * 6.0
		var glow_col := Color(1.0, 0.3, 0.1, 0.3 + _front_hit_flash * 0.5)
		draw_circle(tip, glow_size, glow_col)
	# Impact burst
	if _front_hit_flash > 0.5:
		for i in range(5):
			var a: float = -0.6 + i * 0.3
			var burst_len: float = 10.0 * _front_hit_flash
			var burst_end := tip + Vector2(cos(a) * burst_len, sin(a) * burst_len)
			draw_line(tip, burst_end, Color(1.0, 0.8, 0.3, _front_hit_flash), 1.5, true)

func _draw_mut_mandibles() -> void:
	# Two pincer jaws at front
	var open: float = 0.2 + abs(sin(_time * 4.0)) * 0.3
	var fr: float = _cell_radius * _elongation
	for side in [-1.0, 1.0]:
		var base := Vector2(fr - 1.0, side * 5.0)
		var mid := Vector2(fr + 8.0, side * (4.0 + open * 6.0))
		var tip := Vector2(fr + 14.0, side * (2.0 + open * 3.0))
		draw_line(base, mid, Color(0.6, 0.4, 0.2, 0.9), 2.5, true)
		draw_line(mid, tip, Color(0.5, 0.3, 0.15, 0.9), 2.0, true)
		# Serrated edge
		for i in range(3):
			var t: float = 0.3 + i * 0.25
			var sp := base.lerp(mid, t)
			draw_circle(sp, 1.0, Color(0.7, 0.5, 0.25, 0.7))

func _draw_mut_side_barbs() -> void:
	# Barbs along both sides
	var er: float = _cell_radius * _elongation
	for side in [-1.0, 1.0]:
		for i in range(4):
			var x: float = -er * 0.5 + i * (er * 0.4)
			var base := Vector2(x, side * _cell_radius)
			var tip := base + Vector2(0, side * (8.0 + sin(_time * 5.0 + i) * 2.0))
			draw_line(base, tip, Color(0.9, 0.4, 0.3, 0.8), 1.5, true)
			# Small hook
			var hook := tip + Vector2(side * 2.0, side * -2.0)
			draw_line(tip, hook, Color(0.9, 0.4, 0.3, 0.6), 1.0, true)

func _draw_mut_rear_stinger() -> void:
	# Scorpion-like stinger at back
	var rr: float = _cell_radius * _elongation
	var segments: int = 5
	var prev := Vector2(-rr, 0)
	var base_color := Color(0.3, 0.7, 0.2, 0.9)
	var tip_color := Color(0.2, 0.8, 0.1, 1.0)
	var glow_color := Color(0.1, 0.9, 0.2, 0.6 + sin(_time * 6.0) * 0.3)
	# Flash white/yellow when hitting
	if _tail_hit_flash > 0:
		base_color = base_color.lerp(Color(1.0, 1.0, 0.5, 1.0), _tail_hit_flash)
		tip_color = tip_color.lerp(Color(1.0, 1.0, 0.3, 1.0), _tail_hit_flash)
		glow_color = Color(1.0, 1.0, 0.2, 0.9 * _tail_hit_flash)
	for i in range(segments):
		var t: float = float(i + 1) / segments
		var wave: float = sin(_time * 3.0 + t * 2.0) * 4.0
		# Quick jab motion on hit
		var jab_offset: float = _tail_hit_flash * -8.0 * sin(_tail_hit_flash * PI)
		var cur := Vector2(-rr - t * 16.0 + jab_offset * t, wave * t)
		var width: float = 3.0 * (1.0 - t * 0.6)
		draw_line(prev, cur, base_color, width, true)
		prev = cur
	# Stinger tip
	var jab_offset: float = _tail_hit_flash * -8.0 * sin(_tail_hit_flash * PI)
	var stinger_tip := prev + Vector2(-6.0 + jab_offset, 0)
	draw_line(prev, stinger_tip, tip_color, 1.5, true)
	draw_circle(stinger_tip, 2.0 + _tail_hit_flash * 3.0, glow_color)
	# Impact burst on hit
	if _tail_hit_flash > 0.5:
		for i in range(6):
			var a: float = TAU * i / 6.0
			var burst_r: float = 8.0 * _tail_hit_flash
			var burst_end := stinger_tip + Vector2(cos(a) * burst_r, sin(a) * burst_r)
			draw_line(stinger_tip, burst_end, Color(1.0, 0.9, 0.3, _tail_hit_flash), 1.5, true)

func _draw_mut_ramming_crest() -> void:
	# Armored head plate
	var fr: float = _cell_radius * _elongation
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(7):
		var t: float = float(i) / 6.0
		var a: float = lerpf(-0.6, 0.6, t)
		var r: float = fr + 4.0 + sin(t * PI) * 6.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	pts.append(Vector2(fr - 2.0, sin(0.6) * _cell_radius))
	pts.append(Vector2(fr - 2.0, sin(-0.6) * _cell_radius))
	draw_colored_polygon(pts, Color(0.5, 0.55, 0.6, 0.7))
	# Ridge lines
	for i in range(3):
		var a: float = -0.3 + i * 0.3
		var p1 := Vector2(cos(a) * fr, sin(a) * _cell_radius)
		var p2 := Vector2(cos(a) * (fr + 8.0), sin(a) * (_cell_radius + 8.0) * 0.7)
		draw_line(p1, p2, Color(0.4, 0.45, 0.5, 0.8), 1.5, true)

func _draw_mut_proboscis() -> void:
	# Long feeding needle at front
	var fr: float = _cell_radius * _elongation
	var wave: float = sin(_time * 8.0) * 1.5
	var base := Vector2(fr, 0)
	var segments: int = 6
	var prev := base
	for i in range(segments):
		var t: float = float(i + 1) / segments
		var cur := Vector2(fr + t * 20.0, sin(_time * 4.0 + t * 3.0) * 2.0 * t)
		var width: float = 2.0 * (1.0 - t * 0.7)
		draw_line(prev, cur, Color(0.8, 0.5, 0.6, 0.8), width, true)
		prev = cur
	# Needle tip
	draw_line(prev, prev + Vector2(5.0, 0), Color(0.9, 0.3, 0.4, 0.9), 1.0, true)

func _draw_mut_tail_club() -> void:
	# Heavy club at back
	var rr: float = _cell_radius * _elongation
	var stem_col := Color(0.6, 0.5, 0.4, 0.9)
	var club_col := Color(0.55, 0.45, 0.35, 0.85)
	var outline_col := Color(0.4, 0.35, 0.3, 0.9)
	# Flash on hit
	if _tail_hit_flash > 0:
		stem_col = stem_col.lerp(Color(1.0, 0.8, 0.4, 1.0), _tail_hit_flash)
		club_col = club_col.lerp(Color(1.0, 0.9, 0.5, 1.0), _tail_hit_flash)
		outline_col = outline_col.lerp(Color(1.0, 0.7, 0.3, 1.0), _tail_hit_flash)
	var base := Vector2(-rr, 0)
	# Swing motion on hit
	var swing: float = sin(_time * 2.0) * 3.0
	if _tail_hit_flash > 0:
		swing += sin(_tail_hit_flash * PI * 2.0) * 12.0 * _tail_hit_flash
	var stem := base + Vector2(-10.0, swing)
	draw_line(base, stem, stem_col, 3.0, true)
	# Club head - grows slightly on impact
	var club_pts: PackedVector2Array = PackedVector2Array()
	var size_boost: float = 1.0 + _tail_hit_flash * 0.4
	for i in range(8):
		var a: float = TAU * i / 8.0
		var r: float = (5.0 + sin(a * 2.0 + _time * 3.0) * 1.5) * size_boost
		club_pts.append(stem + Vector2(cos(a) * r - 3.0, sin(a) * r))
	draw_colored_polygon(club_pts, club_col)
	draw_arc(stem + Vector2(-3.0, 0), 5.5 * size_boost, 0, TAU, 12, outline_col, 1.0, true)
	# Impact shockwave on hit
	if _tail_hit_flash > 0.3:
		var ring_r: float = 15.0 * (1.0 - _tail_hit_flash)
		draw_arc(stem + Vector2(-3.0, 0), ring_r, 0, TAU, 16, Color(1.0, 0.9, 0.6, _tail_hit_flash * 0.7), 2.0, true)

func _draw_mut_electroreceptors() -> void:
	# Sensory pits around the body
	for i in range(6):
		var a: float = TAU * i / 6.0 + _time * 0.2
		var pos := Vector2(cos(a) * (_cell_radius - 3.0), sin(a) * (_cell_radius - 3.0))
		var pulse: float = 0.3 + 0.4 * sin(_time * 5.0 + i * 1.2)
		draw_circle(pos, 2.5, Color(0.4, 0.7, 1.0, pulse))
		# Electric arc effect
		if randf() < 0.1:
			var arc_end := pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
			draw_line(pos, arc_end, Color(0.5, 0.8, 1.0, 0.4), 0.8, true)

func _draw_mut_antenna() -> void:
	# Two long antennae at front
	var fr: float = _cell_radius * _elongation
	for side in [-1.0, 1.0]:
		var base := Vector2(fr - 2.0, side * 4.0)
		var segments: int = 8
		var prev := base
		for i in range(segments):
			var t: float = float(i + 1) / segments
			var wave: float = sin(_time * 6.0 + t * 4.0 + side) * 3.0 * t
			var cur := Vector2(fr + t * 25.0, side * 4.0 + wave)
			var width: float = 1.5 * (1.0 - t * 0.8)
			draw_line(prev, cur, Color(0.6, 0.7, 0.5, 0.7), width, true)
			prev = cur
		# Sensor tip
		draw_circle(prev, 1.5, Color(0.5, 0.9, 0.6, 0.5 + sin(_time * 4.0) * 0.3))

# --- GOLDEN CARD AOE ABILITY ---

func _try_golden_ability() -> void:
	if _golden_cooldown > 0:
		return
	var card: Dictionary = GoldenCardData.get_card_by_id(GameManager.equipped_golden_card)
	if card.is_empty():
		return
	_golden_cooldown = card.get("cooldown", GOLDEN_COOLDOWN_MAX)
	_golden_flash = 1.0
	_golden_vfx_timer = card.get("duration", 2.5)
	_golden_vfx_type = card.get("effect_type", "")
	match card.get("effect_type", ""):
		"flee":
			_execute_poison_cloud(card)
			AudioManager.play_toxic_miasma()
		"stun":
			_execute_electric_shock(card)
			AudioManager.play_chain_lightning()
		"heal":
			_execute_healing_aura(card)
			AudioManager.play_regenerative_burst()
	AudioManager.play_player_voice("attack")

func _execute_poison_cloud(card: Dictionary) -> void:
	var radius: float = card.get("aoe_radius", 150.0)
	var duration: float = card.get("duration", 3.5)
	var vfx_col: Color = card.get("vfx_color", Color(0.3, 0.9, 0.2, 0.6))
	# Spawn cloud particles
	for i in range(40):
		var angle: float = randf() * TAU
		var dist: float = randf() * radius * 0.8
		var pos: Vector2 = global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		_golden_vfx_particles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-15, 15), randf_range(-25, -5)),
			"life": randf_range(1.5, 3.5),
			"color": Color(vfx_col.r + randf_range(-0.1, 0.1), vfx_col.g, vfx_col.b, 0.5),
			"size": randf_range(8.0, 20.0),
		})
	# Apply flee to all enemies in radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= radius:
			if enemy.has_method("force_flee"):
				enemy.force_flee(duration)
			elif enemy.has_method("confuse"):
				enemy.confuse(duration)

func _execute_electric_shock(card: Dictionary) -> void:
	var radius: float = card.get("aoe_radius", 140.0)
	var duration: float = card.get("duration", 2.5)
	var vfx_col: Color = card.get("vfx_color", Color(0.4, 0.7, 1.0, 0.8))
	# Spawn lightning bolt particles (radial burst)
	for i in range(24):
		var angle: float = TAU * i / 24.0
		var speed: float = randf_range(200, 400)
		_golden_vfx_particles.append({
			"pos": global_position,
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed),
			"life": randf_range(0.3, 0.7),
			"color": Color(vfx_col.r, vfx_col.g, vfx_col.b, 0.9),
			"size": randf_range(2.0, 5.0),
		})
	# Chain lightning arcs (extra VFX particles connecting to enemies)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= radius:
			if enemy.has_method("confuse"):
				enemy.confuse(duration)
			# Lightning arc particles toward enemy
			var dir: Vector2 = (enemy.global_position - global_position).normalized()
			for j in range(6):
				var t: float = float(j) / 6.0
				var arc_pos: Vector2 = global_position.lerp(enemy.global_position, t)
				arc_pos += Vector2(randf_range(-10, 10), randf_range(-10, 10))
				_golden_vfx_particles.append({
					"pos": arc_pos,
					"vel": Vector2(randf_range(-30, 30), randf_range(-30, 30)),
					"life": randf_range(0.2, 0.5),
					"color": Color(0.6, 0.85, 1.0, 0.9),
					"size": randf_range(1.5, 3.0),
				})

func _execute_healing_aura(card: Dictionary) -> void:
	var duration: float = card.get("duration", 2.5)
	var vfx_col: Color = card.get("vfx_color", Color(1.0, 0.9, 0.3, 0.8))
	# Activate invulnerability
	_golden_aura_active = true
	_golden_aura_timer = duration
	# Instant heal: 30% max health
	health = minf(health + max_health * 0.3, max_health)
	_feed_flash = 0.8
	_set_mood(Mood.HAPPY, duration)
	# Spawn upward-floating golden sparkles
	for i in range(30):
		var angle: float = randf() * TAU
		var dist: float = randf() * 30.0
		var pos: Vector2 = global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		_golden_vfx_particles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-15, 15), randf_range(-80, -30)),
			"life": randf_range(1.0, 2.5),
			"color": Color(vfx_col.r, vfx_col.g + randf_range(-0.1, 0.1), vfx_col.b, 0.7),
			"size": randf_range(2.0, 5.0),
		})

func _update_golden_vfx_particles(delta: float) -> void:
	var alive: Array = []
	for p in _golden_vfx_particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.96
		if p.life > 0:
			alive.append(p)
	_golden_vfx_particles = alive

func _draw_golden_vfx() -> void:
	# Draw golden VFX particles
	for p in _golden_vfx_particles:
		var p_local: Vector2 = (p.pos - global_position).rotated(-rotation)
		var alpha: float = p.life * p.color.a
		draw_circle(p_local, p.size * clampf(p.life, 0.3, 1.0), Color(p.color.r, p.color.g, p.color.b, alpha))

	# Golden flash overlay
	if _golden_flash > 0.01:
		var card: Dictionary = GoldenCardData.get_card_by_id(GameManager.equipped_golden_card)
		var flash_col: Color = card.get("color", Color(1.0, 0.9, 0.3))
		var r: float = _cell_radius * _elongation * (3.0 + (1.0 - _golden_flash) * 4.0)
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(flash_col.r, flash_col.g, flash_col.b, _golden_flash * 0.4), 3.0, true)

	# Healing aura shimmer while active
	if _golden_aura_active:
		var shimmer: float = 0.15 + 0.1 * sin(_time * 8.0)
		var shield_r: float = _cell_radius * _elongation * 1.5
		draw_arc(Vector2.ZERO, shield_r, 0, TAU, 32, Color(1.0, 0.9, 0.3, shimmer), 2.5, true)
		draw_arc(Vector2.ZERO, shield_r + 3.0, _time * 2.0, _time * 2.0 + PI, 16, Color(1.0, 0.95, 0.5, shimmer * 0.5), 1.5, true)

	# Cooldown indicator near the cell (small arc below)
	if GameManager.equipped_golden_card != "":
		var cd_r: float = _cell_radius * _elongation + 12.0
		var cd_center := Vector2(0, _cell_radius + 16.0)
		if _golden_cooldown > 0:
			var progress: float = 1.0 - _golden_cooldown / GOLDEN_COOLDOWN_MAX
			draw_arc(cd_center, 8.0, -PI, -PI + TAU * progress, 16, Color(0.5, 0.5, 0.5, 0.4), 2.0, true)
			draw_arc(cd_center, 8.0, -PI, -PI + TAU * progress, 16, Color(1.0, 0.9, 0.3, 0.3 * progress), 1.5, true)
		else:
			# Ready indicator - pulsing golden dot
			var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
			draw_circle(cd_center, 4.0 + pulse * 2.0, Color(1.0, 0.85, 0.2, 0.4 + pulse * 0.3))

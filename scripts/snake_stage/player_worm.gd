extends CharacterBody3D
## Player worm: segmented body, expressive face, WASD movement, sprint/creep.
## Segments follow the head in a chain (follow-the-leader using position history).
## Adapted for cave environment: pure gravity + collision, no terrain snapping.

signal damaged(amount: float)
signal died
signal nutrient_collected(item: Dictionary)
signal stun_burst_fired
signal bite_performed

# --- Movement ---
const BASE_SPEED: float = 8.0
const SPRINT_SPEED: float = 14.0
const CREEP_SPEED: float = 3.0
const TURN_SPEED: float = 3.0
const GRAVITY: float = 6.0

var _heading: float = 0.0  # Y-axis rotation in radians
var _vertical_velocity: float = 0.0
var _is_sprinting: bool = false
var _is_creeping: bool = false
var _current_speed: float = 0.0

# --- Stats ---
var health: float = 100.0
var max_health: float = 100.0
var energy: float = 100.0
var max_energy: float = 100.0
const ENERGY_REGEN: float = 8.0  # Per second while not sprinting
const SPRINT_DRAIN: float = 15.0  # Per second
const HEALTH_REGEN: float = 1.0

# --- Segments ---
const INITIAL_SEGMENTS: int = 10
const SEGMENT_SPACING: float = 0.7
const HISTORY_RESOLUTION: float = 0.1

var _segments: Array[MeshInstance3D] = []
var _connectors: Array[MeshInstance3D] = []
var _position_history: Array[Vector3] = []
var _rotation_history: Array[float] = []
var _total_distance: float = 0.0
var _last_record_pos: Vector3 = Vector3.ZERO

# --- Face ---
var _face_viewport: SubViewport = null
var _face_billboard: Sprite3D = null
var _face_canvas: Control = null
var _head_mesh: MeshInstance3D = null
var _head_node: Node3D = null  # Root of imported Blender head model

# --- Trifold Jaw ---
var _jaw_petals: Array[Node3D] = []  # 3 pivot nodes holding jaw cone + teeth
var _jaw_open_amount: float = 0.0  # 0 = closed, 1 = full open
var _jaw_state: int = 0  # 0=closed, 1=open, 2=bite
var _bite_cooldown: float = 0.0
var _bite_tween: Tween = null
const BITE_COOLDOWN_TIME: float = 0.5

# --- Stealth & Combat ---
var noise_level: float = 0.0  # 0.0-1.0 for WBC detection
var _noise_spike: float = 0.0
var _noise_spike_timer: float = 0.0
var _stun_cooldown: float = 0.0
const STUN_COOLDOWN_TIME: float = 4.0
const STUN_ENERGY_COST: float = 15.0

# --- Tractor Beam ---
const TRACTOR_RANGE: float = 12.0  # Max pull distance
const TRACTOR_FORCE: float = 15.0  # Pull speed
const TRACTOR_CONE: float = 0.3    # Dot product threshold (wide cone)
var _tractor_active: bool = false
var _rmb_just_pressed: bool = false

# --- Visuals ---
var _eye_light: SpotLight3D = null
var _time: float = 0.0
var _body_color: Color = Color(0.55, 0.35, 0.45)  # Pink-brown worm
var _belly_color: Color = Color(0.7, 0.55, 0.5)
var _damage_flash: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_just_pressed = true

func _ready() -> void:
	add_to_group("player_worm")
	# Smoother traversal over cave geometry
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 1.0
	floor_stop_on_slope = true
	max_slides = 6
	_build_head()
	_build_face()
	_build_segments()
	# Initialize position history
	for i in range(INITIAL_SEGMENTS * 10):
		_position_history.append(global_position)
		_rotation_history.append(_heading)
	_last_record_pos = global_position

func reset_position_history() -> void:
	## Re-fill position history with current position (call after teleporting)
	for i in range(_position_history.size()):
		_position_history[i] = global_position
		_rotation_history[i] = _heading
	_last_record_pos = global_position

func _build_head() -> void:
	# Load the Blender head model with trifold jaw
	var head_scene: PackedScene = load("res://models/worm_head.glb")
	if head_scene:
		_head_node = head_scene.instantiate()
		_head_node.name = "HeadModel"
		# Blender Z-up export to Y-up: jaw (Blender +Z) becomes +Y in Godot
		# Rotate -90° around X to point jaw forward (-Z in Godot = forward)
		_head_node.position = Vector3(0, 0.6, 0)
		_head_node.rotation.x = -PI * 0.5
		add_child(_head_node)

		# Find the WormHead MeshInstance3D for material/transparency control
		_head_mesh = _head_node.find_child("WormHead", true, false) as MeshInstance3D
		if not _head_mesh:
			# Fallback: first MeshInstance3D child
			for child in _head_node.get_children():
				if child is MeshInstance3D:
					_head_mesh = child
					break

		# Find jaw pivots for animation
		_jaw_petals.clear()
		for i in range(3):
			var pivot: Node3D = _head_node.find_child("JawPivot_%d" % i, true, false)
			if pivot:
				_jaw_petals.append(pivot)
	else:
		# Fallback: procedural head if GLB not found
		_build_head_procedural()

func _build_head_procedural() -> void:
	_head_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 1.5
	sphere.radial_segments = 20
	sphere.rings = 10
	_head_mesh.mesh = sphere

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _body_color
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = _body_color * 0.3
	mat.emission_energy_multiplier = 0.8
	_head_mesh.material_override = mat

	_head_mesh.position = Vector3(0, 0.6, 0)
	_head_mesh.rotation.x = PI * 0.5
	add_child(_head_mesh)

	# Trifold jaw: 3 petals at 120° intervals (procedural fallback)
	var petal_color: Color = _body_color.lightened(0.1)
	var tooth_color: Color = Color(0.95, 0.9, 0.75)
	for i in range(3):
		var angle_offset: float = TAU / 3.0 * i
		var pivot: Node3D = Node3D.new()
		pivot.name = "JawPetal_%d" % i
		pivot.position = Vector3(0, 0.6, 0.55)
		pivot.rotation.z = angle_offset
		add_child(pivot)
		var petal: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.03
		cone.bottom_radius = 0.25
		cone.height = 0.6
		cone.radial_segments = 8
		petal.mesh = cone
		var petal_mat: StandardMaterial3D = StandardMaterial3D.new()
		petal_mat.albedo_color = petal_color
		petal_mat.roughness = 0.5
		petal.material_override = petal_mat
		petal.position = Vector3(0, 0.25, 0.2)
		petal.rotation.x = -PI * 0.35
		pivot.add_child(petal)
		_jaw_petals.append(pivot)

func _trigger_bite() -> void:
	if _bite_cooldown > 0 or _jaw_state == 2:
		return
	_jaw_state = 2
	_bite_cooldown = BITE_COOLDOWN_TIME
	# Kill existing tween
	if _bite_tween and _bite_tween.is_valid():
		_bite_tween.kill()
	_bite_tween = create_tween()
	# Rip open wide (fast, aggressive)
	_bite_tween.tween_property(self, "_jaw_open_amount", 1.0, 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Brief hold at full open
	_bite_tween.tween_interval(0.04)
	# SNAP shut — deal damage at the snap moment
	_bite_tween.tween_callback(do_bite_damage)
	_bite_tween.tween_property(self, "_jaw_open_amount", 0.0, 0.06).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	# Slight rebound — jaw bounces open a tiny bit from impact
	_bite_tween.tween_property(self, "_jaw_open_amount", 0.08, 0.08)
	_bite_tween.tween_property(self, "_jaw_open_amount", 0.0, 0.15)
	_bite_tween.tween_callback(func(): _jaw_state = 0)
	# Noise spike from bite
	_noise_spike = 1.0
	_noise_spike_timer = 1.0
	bite_performed.emit()

func _update_jaw() -> void:
	# Idle breathing: gentle open/close when not biting
	if _jaw_state == 0:
		var breath_cycle: float = sin(_time * 1.8) * 0.5 + 0.5  # 0-1 smooth
		_jaw_open_amount = breath_cycle * 0.12  # Subtle 12% max open during breathing

	# Apply jaw_open_amount to petal rotations
	for i in range(_jaw_petals.size()):
		var pivot: Node3D = _jaw_petals[i]
		# When closed: petals together. When open: splay outward 90 degrees
		var splay_angle: float = _jaw_open_amount * deg_to_rad(90.0)
		# Splay outward from center — local X axis for both model types
		pivot.rotation.x = splay_angle

func _build_face() -> void:
	if _head_node:
		# Blender model has 3D eyes — skip the 2D face billboard
		return

	_face_viewport = SubViewport.new()
	_face_viewport.size = Vector2i(128, 128)
	_face_viewport.transparent_bg = true
	_face_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_face_viewport.gui_disable_input = true
	add_child(_face_viewport)

	var face_script = load("res://scripts/snake_stage/worm_face.gd")
	_face_canvas = Control.new()
	_face_canvas.set_script(face_script)
	_face_viewport.add_child(_face_canvas)

	_face_billboard = Sprite3D.new()
	_face_billboard.texture = _face_viewport.get_texture()
	_face_billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_face_billboard.pixel_size = 0.02
	_face_billboard.position = Vector3(0, 0.9, 0.85)
	_face_billboard.modulate = Color(1, 1, 1, 0.95)
	_face_billboard.no_depth_test = false
	_face_billboard.render_priority = 1
	_face_billboard.transparent = true
	add_child(_face_billboard)

	# Eye flashlight: dim neon glow pointing forward, stomach-colored
	_eye_light = SpotLight3D.new()
	_eye_light.light_color = Color(0.35, 0.55, 0.15)  # Stomach green-yellow neon
	_eye_light.light_energy = 0.6
	_eye_light.spot_range = 8.0  # Short range initially
	_eye_light.spot_angle = 55.0  # Wide angle cone
	_eye_light.spot_attenuation = 1.5
	_eye_light.shadow_enabled = false
	_eye_light.position = Vector3(0, 0.85, 0.7)  # From the eye area
	_eye_light.rotation.x = deg_to_rad(-15.0)  # Angled slightly downward to illuminate floor ahead
	add_child(_eye_light)

func _build_segments() -> void:
	for i in range(INITIAL_SEGMENTS):
		var t: float = float(i + 1) / (INITIAL_SEGMENTS + 1)
		var seg_radius: float = lerpf(0.55, 0.18, t * t)

		var seg: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = seg_radius
		sphere.height = seg_radius * 2.4
		sphere.radial_segments = 14
		sphere.rings = 7
		seg.mesh = sphere

		var band: float = sin(i * 1.0) * 0.15 + 0.3
		var col: Color = _body_color.lerp(_belly_color, band)
		col = col.darkened(t * 0.2)

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.65
		mat.emission_enabled = true
		mat.emission = col * 0.2  # Increased emission for cave visibility
		mat.emission_energy_multiplier = 0.5
		seg.material_override = mat

		seg.position = Vector3(0, 0.4, -(i + 1) * SEGMENT_SPACING)
		add_child(seg)
		_segments.append(seg)

		# Connector cylinder
		var connector: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		var prev_radius: float = lerpf(0.55, 0.18, (float(i) / (INITIAL_SEGMENTS + 1)) ** 2)
		cyl.top_radius = seg_radius * 0.85
		cyl.bottom_radius = prev_radius * 0.85
		cyl.height = SEGMENT_SPACING * 0.8
		cyl.radial_segments = 10
		connector.mesh = cyl

		var conn_mat: StandardMaterial3D = StandardMaterial3D.new()
		conn_mat.albedo_color = col.darkened(0.05)
		conn_mat.roughness = 0.7
		conn_mat.emission_enabled = true
		conn_mat.emission = col.darkened(0.05) * 0.15
		conn_mat.emission_energy_multiplier = 0.35
		connector.material_override = conn_mat

		connector.position = Vector3(0, 0.4, -(i + 0.5) * SEGMENT_SPACING)
		add_child(connector)
		_connectors.append(connector)

	# Tail tip
	var tail: MeshInstance3D = MeshInstance3D.new()
	var tail_mesh: CylinderMesh = CylinderMesh.new()
	tail_mesh.top_radius = 0.01
	tail_mesh.bottom_radius = 0.15
	tail_mesh.height = 0.6
	tail_mesh.radial_segments = 8
	tail.mesh = tail_mesh
	var tail_mat: StandardMaterial3D = StandardMaterial3D.new()
	tail_mat.albedo_color = _body_color.darkened(0.25)
	tail_mat.roughness = 0.7
	tail_mat.emission_enabled = true
	tail_mat.emission = _body_color.darkened(0.25) * 0.12
	tail_mat.emission_energy_multiplier = 0.3
	tail.material_override = tail_mat
	tail.position = Vector3(0, 0.3, -(INITIAL_SEGMENTS + 0.8) * SEGMENT_SPACING)
	add_child(tail)
	_connectors.append(tail)

func _physics_process(delta: float) -> void:
	_time += delta

	# --- Input ---
	var input_forward: float = Input.get_axis("move_down", "move_up")
	var input_turn: float = Input.get_axis("move_right", "move_left")
	_is_sprinting = Input.is_action_pressed("sprint") and energy > 1.0
	_is_creeping = Input.is_key_pressed(KEY_SPACE) and not _is_sprinting

	# --- Turning ---
	if absf(input_turn) > 0.1:
		_heading += input_turn * TURN_SPEED * delta

	# --- Speed ---
	var target_speed: float = 0.0
	if absf(input_forward) > 0.1:
		if _is_sprinting:
			target_speed = SPRINT_SPEED * input_forward
		elif _is_creeping:
			target_speed = CREEP_SPEED * input_forward
		else:
			target_speed = BASE_SPEED * input_forward
	_current_speed = lerpf(_current_speed, target_speed * _hazard_slow, delta * 8.0)

	# --- Direction ---
	var forward: Vector3 = Vector3(sin(_heading), 0, cos(_heading))
	var move_vel: Vector3 = forward * _current_speed

	# --- Slope-aligned movement: project onto floor plane when grounded ---
	if is_on_floor() and move_vel.length() > 0.1:
		var floor_normal: Vector3 = get_floor_normal()
		# Project horizontal velocity onto the floor plane
		move_vel = move_vel - floor_normal * move_vel.dot(floor_normal)

	# --- Gravity (pure physics, no terrain snapping) ---
	if not is_on_floor():
		_vertical_velocity -= GRAVITY * delta
	else:
		_vertical_velocity = -0.5  # Small downward to stay grounded

	velocity = Vector3(move_vel.x, move_vel.y + _vertical_velocity, move_vel.z)
	move_and_slide()

	# --- Rotation ---
	rotation.y = _heading

	# --- Record position history ---
	var dist_from_last: float = global_position.distance_to(_last_record_pos)
	if dist_from_last >= HISTORY_RESOLUTION:
		_position_history.push_front(global_position)
		_rotation_history.push_front(_heading)
		_last_record_pos = global_position
		var max_history: int = (INITIAL_SEGMENTS + 5) * int(SEGMENT_SPACING / HISTORY_RESOLUTION) + 20
		while _position_history.size() > max_history:
			_position_history.pop_back()
			_rotation_history.pop_back()

	# --- Update segments ---
	_update_segments(delta)

	# --- Hazard damage ---
	_check_hazards(delta)

	# --- Energy / Health ---
	if _is_sprinting:
		energy = maxf(energy - SPRINT_DRAIN * delta, 0.0)
		if energy <= 0:
			_is_sprinting = false
	else:
		energy = minf(energy + ENERGY_REGEN * delta, max_energy)

	health = minf(health + HEALTH_REGEN * delta, max_health)

	# --- Damage flash ---
	_damage_flash = maxf(_damage_flash - delta * 3.0, 0.0)

	# --- Cooldowns ---
	_bite_cooldown = maxf(_bite_cooldown - delta, 0.0)
	_stun_cooldown = maxf(_stun_cooldown - delta, 0.0)

	# --- Noise level ---
	_noise_spike_timer = maxf(_noise_spike_timer - delta, 0.0)
	if _noise_spike_timer <= 0:
		_noise_spike = 0.0
	var base_noise: float = 0.0
	if _is_creeping:
		base_noise = 0.15
	elif _is_sprinting:
		base_noise = 1.0
	elif absf(_current_speed) > 0.5:
		base_noise = 0.5
	noise_level = maxf(base_noise, _noise_spike)

	# --- Bite attack (RMB) ---
	if _rmb_just_pressed and _bite_cooldown <= 0:
		_trigger_bite()
	_rmb_just_pressed = false

	# --- Tractor beam (LMB / beam_collect) — pull nutrients ---
	_update_tractor_beam(delta)

	# --- Stun burst (E key) ---
	if Input.is_action_just_pressed("stun_burst") and _stun_cooldown <= 0 and energy >= STUN_ENERGY_COST:
		_trigger_stun_burst()

	# --- Update jaw visual ---
	_update_jaw()

	# --- Creep opacity ---
	if _head_node:
		# Blender model: modulate the whole head node for transparency
		var target_alpha: float = 0.7 if _is_creeping else 1.0
		# Smoothly adjust transparency on all mesh children
		_set_head_transparency(_is_creeping)
	elif _head_mesh:
		var head_mat: StandardMaterial3D = _head_mesh.material_override
		if head_mat:
			if _is_creeping and head_mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
				head_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				head_mat.albedo_color.a = 0.7
			elif not _is_creeping and head_mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				head_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				head_mat.albedo_color.a = 1.0

	# --- Update face ---
	_update_face(delta)

	# --- Head bob ---
	var bob: float = sin(_time * 8.0) * 0.05 * clampf(absf(_current_speed) / BASE_SPEED, 0.0, 1.0)
	if _head_node:
		_head_node.position.y = 0.6 + bob
	elif _head_mesh:
		_head_mesh.position.y = 0.6 + bob

	# --- Eye flashlight pulse (organic flicker) ---
	if _eye_light:
		var pulse: float = sin(_time * 2.5) * 0.15 + sin(_time * 7.3) * 0.05  # Slow breath + fast flicker
		_eye_light.light_energy = 0.6 + pulse
		# Dim during creep for stealth
		if _is_creeping:
			_eye_light.light_energy *= 0.3

func _update_segments(delta: float) -> void:
	var prev_pos: Vector3 = _head_node.position if _head_node else _head_mesh.position
	for i in range(_segments.size()):
		var seg: MeshInstance3D = _segments[i]
		var desired_dist: float = (i + 1) * SEGMENT_SPACING
		var target_pos: Vector3 = _get_history_position(desired_dist)
		var local_target: Vector3 = to_local(target_pos)

		seg.position = seg.position.lerp(local_target, delta * 14.0)

		# Wobble animation
		var wobble: float = sin(_time * 3.0 + i * 1.5) * 0.06
		seg.position.y += wobble

		# Update connector
		if i < _connectors.size() - 1:
			var conn: MeshInstance3D = _connectors[i]
			var mid: Vector3 = (prev_pos + seg.position) * 0.5
			conn.position = conn.position.lerp(mid, delta * 14.0)
			var dir: Vector3 = (seg.position - prev_pos)
			if dir.length() > 0.01:
				var up_vec: Vector3 = Vector3.UP
				conn.look_at_from_position(conn.position, conn.position + dir, up_vec)
				conn.rotation.x += PI * 0.5

		prev_pos = seg.position

	# Update tail tip
	if _connectors.size() > 0 and _segments.size() > 0:
		var tail: MeshInstance3D = _connectors[-1]
		var tail_dist: float = (INITIAL_SEGMENTS + 0.5) * SEGMENT_SPACING
		var tail_target: Vector3 = to_local(_get_history_position(tail_dist))
		tail.position = tail.position.lerp(tail_target, delta * 12.0)
		var last_seg: Vector3 = _segments[-1].position
		var tail_dir: Vector3 = (tail.position - last_seg)
		if tail_dir.length() > 0.01:
			tail.look_at_from_position(tail.position, tail.position + tail_dir, Vector3.UP)
			tail.rotation.x += PI * 0.5

func _get_history_position(distance: float) -> Vector3:
	if _position_history.size() < 2:
		return global_position - Vector3(sin(_heading), 0, cos(_heading)) * distance

	var accumulated: float = 0.0
	for i in range(_position_history.size() - 1):
		var seg_len: float = _position_history[i].distance_to(_position_history[i + 1])
		if accumulated + seg_len >= distance:
			var t: float = (distance - accumulated) / maxf(seg_len, 0.001)
			return _position_history[i].lerp(_position_history[i + 1], t)
		accumulated += seg_len
	return _position_history[-1]

func _update_face(_delta: float) -> void:
	if not _face_canvas:
		return

	var face = _face_canvas
	var speed_ratio: float = absf(_current_speed) / SPRINT_SPEED

	if _damage_flash > 0.3:
		face.set_mood(face.Mood.HURT, 0.5)
	elif health < max_health * 0.2:
		face.set_mood(face.Mood.STRESSED, 0.3)
	elif _is_sprinting and speed_ratio > 0.5:
		face.set_mood(face.Mood.ZOOM, 0.2)
	elif _is_creeping:
		face.set_mood(face.Mood.STEALTH, 0.2)
	elif energy < max_energy * 0.15:
		face.set_mood(face.Mood.DEPLETED, 0.3)
	elif speed_ratio > 0.3:
		face.set_mood(face.Mood.IDLE, 0.2)

	face.speed_ratio = speed_ratio
	face.look_direction = Vector2(0, 0)

	if _damage_flash > 0:
		face.trigger_damage_flash()

func take_damage(amount: float) -> void:
	health -= amount
	_damage_flash = 1.0
	if _face_canvas:
		_face_canvas.set_mood(_face_canvas.Mood.HURT, 0.8)
		_face_canvas.trigger_damage_flash()
	damaged.emit(amount)
	if health <= 0:
		_die()

func _die() -> void:
	died.emit()
	health = max_health * 0.5
	energy = max_energy * 0.5
	global_position = Vector3(0, -5, 0)  # Will be repositioned by stage manager

func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	if _face_canvas:
		_face_canvas.set_mood(_face_canvas.Mood.HAPPY, 0.5)

func restore_energy(amount: float) -> void:
	energy = minf(energy + amount, max_energy)

func _trigger_stun_burst() -> void:
	energy -= STUN_ENERGY_COST
	_stun_cooldown = STUN_COOLDOWN_TIME
	_noise_spike = 0.8
	_noise_spike_timer = 2.0
	# VFX and damage handled by snake_stage_manager listening for signal
	stun_burst_fired.emit()

func get_bite_targets() -> Array:
	## Returns WBCs within bite range and forward cone
	var targets: Array = []
	var forward: Vector3 = Vector3(sin(_heading), 0, cos(_heading))
	for wbc in get_tree().get_nodes_in_group("white_blood_cell"):
		var to_target: Vector3 = wbc.global_position - global_position
		var dist: float = to_target.length()
		if dist > 2.0:
			continue
		var dot: float = forward.dot(to_target.normalized())
		if dot > 0.7:
			targets.append(wbc)
	return targets

var _hazard_slow: float = 1.0  # Multiplied into speed (1.0 = normal, <1 = slowed)

func _check_hazards(delta: float) -> void:
	_hazard_slow = 1.0  # Reset each frame
	for node in get_tree().get_nodes_in_group("biome_hazard"):
		var dist: float = global_position.distance_to(node.global_position)
		var hz_radius: float = node.get_meta("radius", 2.0)
		if dist > hz_radius:
			continue
		var hz_type: String = node.get_meta("hazard_type", "")
		match hz_type:
			"acid":
				take_damage(node.get_meta("dps", 5.0) * delta)
			"bile":
				_hazard_slow = minf(_hazard_slow, node.get_meta("slow_factor", 0.4))
			"nerve":
				if randf() < node.get_meta("zap_chance", 0.015):
					take_damage(node.get_meta("zap_damage", 8.0))
			"pulse":
				var period: float = node.get_meta("period", 1.4)
				var cycle: float = fmod(Time.get_ticks_msec() / 1000.0, period) / period
				if cycle < 0.08:  # Brief knockback window
					var push_dir: Vector3 = (global_position - node.global_position)
					push_dir.y = 0
					if push_dir.length() > 0.1:
						push_dir = push_dir.normalized()
					else:
						push_dir = Vector3.FORWARD
					velocity += push_dir * node.get_meta("force", 6.0)

var _creep_transparent: bool = false

func _set_head_transparency(creeping: bool) -> void:
	if creeping == _creep_transparent:
		return
	_creep_transparent = creeping
	if not _head_node:
		return
	# Walk all MeshInstance3D children and adjust transparency
	var meshes: Array = []
	_collect_meshes(_head_node, meshes)
	for mesh_inst: MeshInstance3D in meshes:
		var mat: Material = mesh_inst.get_active_material(0)
		if mat is StandardMaterial3D:
			var smat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
			if creeping:
				smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				smat.albedo_color.a = 0.5
			else:
				smat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				smat.albedo_color.a = 1.0
			mesh_inst.material_override = smat

func _collect_meshes(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)

func _update_tractor_beam(delta: float) -> void:
	_tractor_active = Input.is_action_pressed("beam_collect")
	if not _tractor_active:
		return
	# Pull nearby nutrients toward the worm (not creatures)
	var forward: Vector3 = Vector3(sin(_heading), 0, cos(_heading))
	for node in get_tree().get_nodes_in_group("nutrient"):
		var to_item: Vector3 = node.global_position - global_position
		var dist: float = to_item.length()
		if dist > TRACTOR_RANGE or dist < 0.3:
			continue
		# Wide forward cone check
		var dot: float = forward.dot(to_item.normalized())
		if dot < TRACTOR_CONE:
			continue
		# Pull toward player
		var pull_dir: Vector3 = -to_item.normalized()
		var strength: float = TRACTOR_FORCE * (1.0 - dist / TRACTOR_RANGE)
		if node is CharacterBody3D:
			node.velocity += pull_dir * strength * delta * 60.0
		elif node is RigidBody3D:
			node.apply_central_force(pull_dir * strength * 5.0)
		else:
			node.global_position += pull_dir * strength * delta

func do_bite_damage() -> void:
	## Called during bite snap — deals damage to WBCs in range
	var targets: Array = get_bite_targets()
	for target in targets:
		if target.has_method("take_damage"):
			target.take_damage(25.0)
	# Brief forward lunge
	var forward: Vector3 = Vector3(sin(_heading), 0, cos(_heading))
	velocity += forward * 8.0

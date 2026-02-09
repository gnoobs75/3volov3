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
var _head_wrapper: Node3D = null  # Orientation wrapper (rotation.y=PI to face forward)

# --- Trifold Jaw ---
var _jaw_petals: Array[Node3D] = []  # 3 pivot nodes holding jaw cone + teeth
var _jaw_initial_rotations: Array[Vector3] = []  # Store Blender-baked rotations so we add splay on top
var _jaw_open_amount: float = 0.0  # 0 = closed, 1 = full open
var _jaw_state: int = 0  # 0=closed, 1=open, 2=bite
var _bite_cooldown: float = 0.0
var _bite_tween: Tween = null
var _lunge_tween: Tween = null
var _lunge_offset: float = 0.0  # Forward head offset during bite
const BITE_COOLDOWN_TIME: float = 0.5
const LUNGE_VELOCITY: float = 18.0  # Forward impulse on bite

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

# --- Head direction ---
var _head_flip: float = 0.0  # 0 = facing forward, PI = facing backward (smooth)

# --- Visuals ---
var _eye_light: SpotLight3D = null
var _time: float = 0.0
var _body_color: Color = Color(0.55, 0.35, 0.45)  # Pink-brown worm
var _belly_color: Color = Color(0.7, 0.55, 0.5)
var _vein_meshes: Array[MeshInstance3D] = []  # Purple vein details on segments
var _synapse_lights: Array[OmniLight3D] = []  # Firing synapse pulses
const GLOW_COLOR: Color = Color(0.15, 0.45, 0.1)  # Eerie green glow
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
	floor_snap_length = 2.0
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
		# Wrapper node: rotation.y=PI flips the model so jaw faces +Z (movement direction)
		# Without this, rotation.x=-PI/2 maps jaw to -Z (backward toward camera)
		_head_wrapper = Node3D.new()
		_head_wrapper.name = "HeadWrapper"
		_head_wrapper.position = Vector3(0, 0.6, 0)
		_head_wrapper.rotation.y = PI
		add_child(_head_wrapper)

		_head_node = head_scene.instantiate()
		_head_node.name = "HeadModel"
		_head_node.rotation.x = -PI * 0.5
		_head_wrapper.add_child(_head_node)

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
		_jaw_initial_rotations.clear()
		for i in range(3):
			var pivot: Node3D = _head_node.find_child("JawPivot_%d" % i, true, false)
			if pivot:
				_jaw_petals.append(pivot)
				_jaw_initial_rotations.append(pivot.rotation)

		# Eye flashlight — proper beam with bright spotlight on target surface
		# Main beam: long range spotlight from the eyes
		_eye_light = SpotLight3D.new()
		_eye_light.name = "Flashlight"
		_eye_light.light_color = Color(0.3, 0.6, 0.15)
		_eye_light.light_energy = 3.5
		_eye_light.spot_range = 25.0
		_eye_light.spot_angle = 18.0  # Tight beam for flashlight feel
		_eye_light.spot_attenuation = 0.8  # Bright center, soft falloff
		_eye_light.shadow_enabled = true
		_eye_light.position = Vector3(0, 0.3, 0.5)
		_eye_light.rotation.x = deg_to_rad(-5.0)  # Slight downward to hit floor ahead
		_head_wrapper.add_child(_eye_light)

		# Secondary wide fill light (subtle ambient around the beam)
		var fill_light: SpotLight3D = SpotLight3D.new()
		fill_light.name = "FlashlightFill"
		fill_light.light_color = Color(0.2, 0.4, 0.1)
		fill_light.light_energy = 0.4
		fill_light.spot_range = 12.0
		fill_light.spot_angle = 45.0  # Wide halo around the beam
		fill_light.spot_attenuation = 2.0
		fill_light.shadow_enabled = false
		fill_light.position = Vector3(0, 0.3, 0.5)
		fill_light.rotation.x = deg_to_rad(-5.0)
		_head_wrapper.add_child(fill_light)

		# Visible beam: long narrow cone mesh with very low alpha additive blend
		var beam_mesh: CylinderMesh = CylinderMesh.new()
		beam_mesh.top_radius = 0.03  # Pinpoint at source
		beam_mesh.bottom_radius = 1.8  # Spreads to match spot angle at range
		beam_mesh.height = 18.0  # Length of visible beam
		beam_mesh.radial_segments = 12
		var beam_mi: MeshInstance3D = MeshInstance3D.new()
		beam_mi.name = "LightCone"
		beam_mi.mesh = beam_mesh
		beam_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
		beam_mat.albedo_color = Color(0.25, 0.5, 0.1, 0.015)  # Very subtle
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam_mat.no_depth_test = true
		beam_mi.material_override = beam_mat
		# Rotate cylinder so it extends along +Z (forward) from the head
		beam_mi.position = Vector3(0, 0.3, 9.5)  # Midpoint of 18-unit cone
		beam_mi.rotation.x = deg_to_rad(90.0)  # Align cylinder along Z
		_head_wrapper.add_child(beam_mi)
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
	# Each petal is a tapered cone pointing forward along Z, with a tooth tip.
	# Pivots are at the mouth opening; Z rotation spaces them 120° apart.
	# Splaying rotates each petal outward from center via local X axis.
	var petal_color: Color = _body_color.lightened(0.1)
	var tooth_color: Color = Color(0.95, 0.9, 0.75)
	_jaw_initial_rotations.clear()
	for i in range(3):
		var angle_offset: float = TAU / 3.0 * i
		var pivot: Node3D = Node3D.new()
		pivot.name = "JawPetal_%d" % i
		# Pivot at the mouth ring, facing forward
		pivot.position = Vector3(0, 0.6, 0.55)
		pivot.rotation.z = angle_offset
		add_child(pivot)

		# Petal: tapered cone extending outward from pivot
		var petal: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = 0.22
		cone.height = 0.55
		cone.radial_segments = 6
		petal.mesh = cone
		var petal_mat: StandardMaterial3D = StandardMaterial3D.new()
		petal_mat.albedo_color = petal_color
		petal_mat.roughness = 0.5
		petal_mat.emission_enabled = true
		petal_mat.emission = petal_color * 0.15
		petal_mat.emission_energy_multiplier = 0.3
		petal.material_override = petal_mat
		# Cone extends along local Y; rotate so it points forward along Z
		petal.position = Vector3(0, 0.0, 0.25)
		petal.rotation.x = -PI * 0.5  # Tip points forward (+Z)
		pivot.add_child(petal)

		# Tooth at tip
		var tooth: MeshInstance3D = MeshInstance3D.new()
		var tooth_mesh: CylinderMesh = CylinderMesh.new()
		tooth_mesh.top_radius = 0.005
		tooth_mesh.bottom_radius = 0.03
		tooth_mesh.height = 0.15
		tooth_mesh.radial_segments = 4
		tooth.mesh = tooth_mesh
		var tooth_mat: StandardMaterial3D = StandardMaterial3D.new()
		tooth_mat.albedo_color = tooth_color
		tooth_mat.roughness = 0.3
		tooth_mat.emission_enabled = true
		tooth_mat.emission = tooth_color * 0.1
		tooth_mat.emission_energy_multiplier = 0.2
		tooth.material_override = tooth_mat
		tooth.position = Vector3(0, 0.0, 0.5)
		tooth.rotation.x = -PI * 0.5
		pivot.add_child(tooth)

		_jaw_petals.append(pivot)
		_jaw_initial_rotations.append(pivot.rotation)

func _trigger_bite() -> void:
	if _bite_cooldown > 0 or _jaw_state == 2:
		return
	_jaw_state = 2
	_bite_cooldown = BITE_COOLDOWN_TIME

	# --- LUNGE: thrust in direction the head is facing ---
	var head_dir: float = _heading + _head_flip
	var lunge_dir: Vector3 = Vector3(sin(head_dir), 0, cos(head_dir))
	velocity += lunge_dir * LUNGE_VELOCITY

	# Head lunge animation (offset head forward then back)
	if _lunge_tween and _lunge_tween.is_valid():
		_lunge_tween.kill()
	_lunge_tween = create_tween()
	_lunge_tween.tween_property(self, "_lunge_offset", 0.6, 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_lunge_tween.tween_property(self, "_lunge_offset", 0.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# --- JAW: rip open then snap shut ---
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
	# Each petal splays outward along its own radial axis (120° apart)
	var splay_angle: float = _jaw_open_amount * deg_to_rad(75.0)
	for i in range(_jaw_petals.size()):
		var pivot: Node3D = _jaw_petals[i]
		if i < _jaw_initial_rotations.size():
			# Blender model: add splay on top of baked rotation
			# The pivots are already rotated around Z at 120° intervals in Blender.
			# Splay on local X axis rotates each petal outward from mouth center.
			pivot.rotation = _jaw_initial_rotations[i]
			pivot.rotation.x += splay_angle
		else:
			# Procedural fallback: each petal's Z rotation is already set at creation
			# Splay on local X splays outward because local X is radial
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
	var vein_color: Color = Color(0.35, 0.08, 0.45)  # Purple veins

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
		mat.emission = GLOW_COLOR  # Eerie green glow
		mat.emission_energy_multiplier = 0.8
		seg.material_override = mat

		seg.position = Vector3(0, 0.4, -(i + 1) * SEGMENT_SPACING)
		add_child(seg)
		_segments.append(seg)

		# Purple veins: 2-3 thin tubes wrapping around each segment
		var vein_count: int = 2 if i % 2 == 0 else 3
		for v in range(vein_count):
			var vein: MeshInstance3D = MeshInstance3D.new()
			var vein_cyl: CylinderMesh = CylinderMesh.new()
			vein_cyl.top_radius = seg_radius * 0.06
			vein_cyl.bottom_radius = seg_radius * 0.06
			vein_cyl.height = seg_radius * 1.8
			vein_cyl.radial_segments = 4
			vein.mesh = vein_cyl

			var vein_mat: StandardMaterial3D = StandardMaterial3D.new()
			vein_mat.albedo_color = vein_color
			vein_mat.roughness = 0.3
			vein_mat.emission_enabled = true
			vein_mat.emission = vein_color
			vein_mat.emission_energy_multiplier = 1.5
			vein.material_override = vein_mat

			# Position veins around the segment at different angles
			var angle: float = (TAU / vein_count) * v + i * 0.7
			var offset_r: float = seg_radius * 0.85
			vein.position = Vector3(cos(angle) * offset_r, sin(angle) * offset_r, 0)
			# Tilt vein to wrap along body axis
			vein.rotation.x = randf_range(-0.4, 0.4)
			vein.rotation.z = angle + PI * 0.5
			seg.add_child(vein)
			_vein_meshes.append(vein)

		# Synapse light on every 3rd segment
		if i % 3 == 0:
			var synapse: OmniLight3D = OmniLight3D.new()
			synapse.light_color = vein_color
			synapse.light_energy = 0.0  # Starts off, pulses on
			synapse.omni_range = seg_radius * 3.0
			synapse.shadow_enabled = false
			seg.add_child(synapse)
			_synapse_lights.append(synapse)

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
		conn_mat.emission = GLOW_COLOR * 0.7  # Green glow on connectors too
		conn_mat.emission_energy_multiplier = 0.6
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
	tail_mat.emission = GLOW_COLOR * 0.5
	tail_mat.emission_energy_multiplier = 0.4
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

	# --- Head faces movement direction (hold direction until opposite key) ---
	var head_flip_target: float = _head_flip  # Hold current facing when idle
	if input_forward < -0.1:
		head_flip_target = PI  # S key: head faces backward
	elif input_forward > 0.1:
		head_flip_target = 0.0  # W key: head faces forward
	_head_flip = lerp_angle(_head_flip, head_flip_target, delta * 8.0)

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

	# --- Head bob + lunge offset + direction flip ---
	var bob: float = sin(_time * 8.0) * 0.05 * clampf(absf(_current_speed) / BASE_SPEED, 0.0, 1.0)
	if _head_wrapper:
		_head_wrapper.position.y = 0.6 + bob
		_head_wrapper.position.z = _lunge_offset
		_head_wrapper.rotation.y = PI + _head_flip  # PI = base forward flip, + _head_flip for backward
	elif _head_node:
		_head_node.position.y = 0.6 + bob
	elif _head_mesh:
		_head_mesh.position.y = 0.6 + bob

	# --- Eye flashlight pulse (organic flicker) ---
	if _eye_light:
		var pulse: float = sin(_time * 2.5) * 0.4 + sin(_time * 7.3) * 0.15
		var beam_energy: float = 3.5 + pulse
		# Dim during creep for stealth
		if _is_creeping:
			beam_energy *= 0.15  # Nearly off when sneaking
		_eye_light.light_energy = beam_energy
		# Match fill light
		if _head_wrapper:
			var fill: SpotLight3D = _head_wrapper.get_node_or_null("FlashlightFill") as SpotLight3D
			if fill:
				fill.light_energy = beam_energy * 0.12
			# Animate beam cone visibility
			var cone_node: MeshInstance3D = _head_wrapper.get_node_or_null("LightCone") as MeshInstance3D
			if cone_node and cone_node.material_override is StandardMaterial3D:
				var cone_mat: StandardMaterial3D = cone_node.material_override
				var cone_alpha: float = 0.015 + (pulse * 0.003)
				if _is_creeping:
					cone_alpha *= 0.15
				cone_mat.albedo_color.a = cone_alpha

func _update_segments(delta: float) -> void:
	var prev_pos: Vector3
	if _head_wrapper:
		prev_pos = _head_wrapper.position
	elif _head_node:
		prev_pos = _head_node.position
	else:
		prev_pos = _head_mesh.position
	for i in range(_segments.size()):
		var seg: MeshInstance3D = _segments[i]
		var desired_dist: float = (i + 1) * SEGMENT_SPACING
		var target_pos: Vector3 = _get_history_position(desired_dist)
		var local_target: Vector3 = to_local(target_pos)

		seg.position = seg.position.lerp(local_target, delta * 14.0)

		# Wobble animation
		var wobble: float = sin(_time * 3.0 + i * 1.5) * 0.06
		seg.position.y += wobble

		# Green glow breathing per segment (staggered wave)
		if seg.material_override:
			var glow_wave: float = sin(_time * 2.0 + i * 0.6) * 0.2 + 0.8
			seg.material_override.emission_energy_multiplier = glow_wave

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

	# Synapse firing: purple pulse wave traveling head-to-tail
	var synapse_wave: float = fmod(_time * 1.5, 4.0)  # Wave every ~4 seconds
	for si in range(_synapse_lights.size()):
		var light: OmniLight3D = _synapse_lights[si]
		var seg_index: float = float(si) / maxf(_synapse_lights.size() - 1, 1)
		var wave_dist: float = absf(synapse_wave - seg_index * 3.0)
		if wave_dist < 0.5:
			var pulse: float = 1.0 - wave_dist * 2.0  # 0-1 peak
			light.light_energy = pulse * 2.5
		else:
			light.light_energy = lerpf(light.light_energy, 0.0, delta * 6.0)

	# Vein glow pulse — subtle breathing
	var vein_pulse: float = sin(_time * 2.5) * 0.3 + 1.2
	for vein in _vein_meshes:
		if vein and vein.material_override:
			vein.material_override.emission_energy_multiplier = vein_pulse

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
	## Returns creatures within bite range and head-facing cone (WBCs, prey, flyers)
	var targets: Array = []
	var head_dir: float = _heading + _head_flip
	var forward: Vector3 = Vector3(sin(head_dir), 0, cos(head_dir))
	for group_name in ["white_blood_cell", "prey", "flyer"]:
		for creature in get_tree().get_nodes_in_group(group_name):
			var to_target: Vector3 = creature.global_position - global_position
			var dist: float = to_target.length()
			if dist > 2.5:
				continue
			var dot: float = forward.dot(to_target.normalized())
			if dot > 0.6:
				targets.append(creature)
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
			"gas":
				take_damage(node.get_meta("dps", 2.0) * delta)
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
			"peristalsis":
				var period: float = node.get_meta("period", 2.5)
				var cycle: float = fmod(Time.get_ticks_msec() / 1000.0, period) / period
				if cycle < 0.15:  # Longer push window than heartbeat
					var push_angle: float = node.get_meta("push_angle", 0.0)
					var push_dir: Vector3 = Vector3(cos(push_angle), 0, sin(push_angle))
					velocity += push_dir * node.get_meta("force", 4.0) * delta * 10.0

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
	# Pull nearby nutrients toward the worm (in head-facing direction)
	var head_dir: float = _heading + _head_flip
	var forward: Vector3 = Vector3(sin(head_dir), 0, cos(head_dir))
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
	## Called during bite snap — deals damage to creatures in range with knockback
	var targets: Array = get_bite_targets()
	for target in targets:
		if target.has_method("take_damage"):
			target.take_damage(25.0)
		# Knockback: push target away from player + upward
		if target is CharacterBody3D:
			var push: Vector3 = (target.global_position - global_position).normalized()
			target.velocity += push * 12.0 + Vector3(0, 3.0, 0)

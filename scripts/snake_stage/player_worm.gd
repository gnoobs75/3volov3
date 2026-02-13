extends CharacterBody3D
## Player worm: segmented body, expressive face, WASD movement, sprint/creep.
## Segments follow the head in a chain (follow-the-leader using position history).
## Adapted for cave environment: pure gravity + collision, no terrain snapping.

signal damaged(amount: float)
signal died
signal nutrient_collected(item: Dictionary)
signal stun_burst_fired
signal bite_performed
signal tail_whip_performed

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

# --- Body Sections (continuous, no growth) ---
const BODY_SECTION_COUNT: int = 10
const SECTION_SPACING: float = 0.7
const HISTORY_RESOLUTION: float = 0.1

var _body_sections: Array[MeshInstance3D] = []
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

# --- Tail Whip Attack ---
var _tail_whip_cooldown: float = 0.0
var _tail_whip_active: bool = false
var _tail_whip_timer: float = 0.0
const TAIL_WHIP_COOLDOWN_TIME: float = 8.0
const TAIL_WHIP_ENERGY_COST: float = 15.0
const TAIL_WHIP_RANGE: float = 5.0
const TAIL_WHIP_DAMAGE: float = 20.0
const TAIL_WHIP_KNOCKBACK: float = 12.0
const TAIL_WHIP_DURATION: float = 0.5
var _tail_whip_angle: float = 0.0  # Sweep progress: 0 → PI over duration
var _tail_whip_hit_targets: Array = []  # Prevents double-hit during sweep

# --- Venom Bite ---
var _venom_damage_per_sec: float = 2.0
var _venom_duration: float = 4.0

# --- Camouflage ---
var _is_camouflaged: bool = false
var _camo_energy_drain: float = 3.0  # Energy per second
var _camo_alpha: float = 1.0  # 1=visible, 0.2=camo

# --- Boss Trait Activation ---
var _trait_cooldown: float = 0.0
var _bone_shield_active: bool = false
var _bone_shield_timer: float = 0.0
var _shield_mesh: MeshInstance3D = null

# --- Trait VFX ---
var _pulse_ring: MeshInstance3D = null
var _pulse_ring_scale: float = 0.0
var _pulse_ring_active: bool = false
var _wind_cone: MeshInstance3D = null
var _wind_cone_alpha: float = 0.0
var _trait_flash: float = 0.0  # Screen flash on activation

# --- Creature Vocalization ---
var _idle_voice_timer: float = 4.0  # Delay before first idle vocalization
var _trait_flash_color: Color = Color.WHITE

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
var _eye_light_base_energy: float = 1.5  # Stored base energy for pulse animation
var _eye_stalk: Node3D = null  # Anglerfish lure stalk
var _eye_lure: MeshInstance3D = null  # Glowing lure at stalk tip
var _lure_light: OmniLight3D = null  # Ambient glow from the lure
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
	_build_body_sections()
	# Initialize position history
	for i in range(BODY_SECTION_COUNT * 10):
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

		# --- Anglerfish Eye Stalk ---
		# A bioluminescent lure stalk rising from the head, with a dim spotlight
		# The wrapper has rotation.y=PI, so wrapper -Z = worm forward.
		# SpotLight3D default direction is -Z, so rotation (0,0,0) = forward.
		var evo: int = 0
		if has_node("/root/GameManager"):
			evo = get_node("/root/GameManager").get("evolution_level")
		var evo_boost: float = evo * 0.08  # Subtle growth per evolution

		# Stalk root — positioned on top of the head
		_eye_stalk = Node3D.new()
		_eye_stalk.name = "EyeStalk"
		_eye_stalk.position = Vector3(0, 0.4, 0)
		_head_wrapper.add_child(_eye_stalk)

		# Lower stalk segment: thicker base
		var stalk_lower: MeshInstance3D = MeshInstance3D.new()
		var stalk_cyl: CylinderMesh = CylinderMesh.new()
		stalk_cyl.top_radius = 0.04
		stalk_cyl.bottom_radius = 0.08
		stalk_cyl.height = 0.5
		stalk_cyl.radial_segments = 6
		stalk_lower.mesh = stalk_cyl
		var stalk_mat: StandardMaterial3D = StandardMaterial3D.new()
		stalk_mat.albedo_color = _body_color.darkened(0.1)
		stalk_mat.roughness = 0.7
		stalk_mat.emission_enabled = true
		stalk_mat.emission = GLOW_COLOR * 0.3
		stalk_mat.emission_energy_multiplier = 0.4
		stalk_lower.material_override = stalk_mat
		stalk_lower.position = Vector3(0, 0.25, 0)
		_eye_stalk.add_child(stalk_lower)

		# Upper stalk: thinner, slight forward lean (toward wrapper -Z = worm forward)
		var stalk_upper_pivot: Node3D = Node3D.new()
		stalk_upper_pivot.name = "StalkBend"
		stalk_upper_pivot.position = Vector3(0, 0.5, 0)
		stalk_upper_pivot.rotation.x = deg_to_rad(15.0)  # Lean forward slightly
		_eye_stalk.add_child(stalk_upper_pivot)

		var stalk_upper: MeshInstance3D = MeshInstance3D.new()
		var stalk_upper_cyl: CylinderMesh = CylinderMesh.new()
		stalk_upper_cyl.top_radius = 0.03
		stalk_upper_cyl.bottom_radius = 0.05
		stalk_upper_cyl.height = 0.4
		stalk_upper_cyl.radial_segments = 6
		stalk_upper.mesh = stalk_upper_cyl
		stalk_upper.material_override = stalk_mat
		stalk_upper.position = Vector3(0, 0.2, 0)
		stalk_upper_pivot.add_child(stalk_upper)

		# Lure eye: glowing bioluminescent bulb at the tip
		_eye_lure = MeshInstance3D.new()
		_eye_lure.name = "LureEye"
		var lure_sphere: SphereMesh = SphereMesh.new()
		lure_sphere.radius = 0.1 + evo_boost * 0.3
		lure_sphere.height = (0.1 + evo_boost * 0.3) * 2.0
		lure_sphere.radial_segments = 12
		lure_sphere.rings = 6
		_eye_lure.mesh = lure_sphere
		var lure_mat: StandardMaterial3D = StandardMaterial3D.new()
		lure_mat.albedo_color = Color(0.85, 0.75, 0.4)
		lure_mat.roughness = 0.2
		lure_mat.emission_enabled = true
		lure_mat.emission = Color(0.8, 0.65, 0.25)
		lure_mat.emission_energy_multiplier = 2.5
		_eye_lure.material_override = lure_mat
		_eye_lure.position = Vector3(0, 0.45, 0)
		stalk_upper_pivot.add_child(_eye_lure)

		# Lure ambient glow (soft omni light from the eye itself)
		_lure_light = OmniLight3D.new()
		_lure_light.name = "LureGlow"
		_lure_light.light_color = Color(0.85, 0.7, 0.35)
		_lure_light.light_energy = 0.6
		_lure_light.omni_range = 4.0
		_lure_light.shadow_enabled = false
		_eye_lure.add_child(_lure_light)

		# Main spotlight — dim, warm, forward-facing
		# In wrapper space: default SpotLight3D faces -Z = worm forward
		_eye_light = SpotLight3D.new()
		_eye_light.name = "Flashlight"
		_eye_light.light_color = Color(0.8, 0.7, 0.4)  # Warm bioluminescent amber
		_eye_light_base_energy = 1.5 + evo_boost
		_eye_light.light_energy = _eye_light_base_energy
		_eye_light.spot_range = 13.0 + evo * 1.0  # 12-15m range
		_eye_light.spot_angle = 28.0  # Focused spotlight cone
		_eye_light.spot_attenuation = 1.2  # Smooth falloff
		_eye_light.shadow_enabled = true
		_eye_light.rotation.x = deg_to_rad(-15.0)  # Tilt down slightly to hit ground
		_eye_lure.add_child(_eye_light)
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

	# Procedural eye stalk + dim spotlight (fallback version)
	_eye_stalk = Node3D.new()
	_eye_stalk.name = "EyeStalk"
	_eye_stalk.position = Vector3(0, 1.0, 0)
	add_child(_eye_stalk)

	var p_stalk: MeshInstance3D = MeshInstance3D.new()
	var p_cyl: CylinderMesh = CylinderMesh.new()
	p_cyl.top_radius = 0.03
	p_cyl.bottom_radius = 0.06
	p_cyl.height = 0.6
	p_cyl.radial_segments = 6
	p_stalk.mesh = p_cyl
	var p_mat: StandardMaterial3D = StandardMaterial3D.new()
	p_mat.albedo_color = _body_color.darkened(0.1)
	p_mat.roughness = 0.7
	p_mat.emission_enabled = true
	p_mat.emission = GLOW_COLOR * 0.3
	p_mat.emission_energy_multiplier = 0.4
	p_stalk.material_override = p_mat
	p_stalk.position = Vector3(0, 0.3, 0)
	_eye_stalk.add_child(p_stalk)

	_eye_lure = MeshInstance3D.new()
	var p_lure: SphereMesh = SphereMesh.new()
	p_lure.radius = 0.08
	p_lure.height = 0.16
	p_lure.radial_segments = 10
	p_lure.rings = 5
	_eye_lure.mesh = p_lure
	var p_lure_mat: StandardMaterial3D = StandardMaterial3D.new()
	p_lure_mat.albedo_color = Color(0.85, 0.75, 0.4)
	p_lure_mat.roughness = 0.2
	p_lure_mat.emission_enabled = true
	p_lure_mat.emission = Color(0.8, 0.65, 0.25)
	p_lure_mat.emission_energy_multiplier = 2.5
	_eye_lure.material_override = p_lure_mat
	_eye_lure.position = Vector3(0, 0.65, 0)
	_eye_stalk.add_child(_eye_lure)

	_lure_light = OmniLight3D.new()
	_lure_light.light_color = Color(0.85, 0.7, 0.35)
	_lure_light.light_energy = 0.5
	_lure_light.omni_range = 3.0
	_lure_light.shadow_enabled = false
	_eye_lure.add_child(_lure_light)

	_eye_light = SpotLight3D.new()
	_eye_light.light_color = Color(0.8, 0.7, 0.4)
	_eye_light_base_energy = 1.2
	_eye_light.light_energy = _eye_light_base_energy
	_eye_light.spot_range = 10.0
	_eye_light.spot_angle = 30.0
	_eye_light.spot_attenuation = 1.2
	_eye_light.shadow_enabled = false
	_eye_light.position = Vector3(0, 0, 0.1)
	_eye_light.rotation.x = deg_to_rad(-20.0)
	_eye_lure.add_child(_eye_light)

func _build_body_sections() -> void:
	var vein_color: Color = Color(0.35, 0.08, 0.45)  # Purple veins

	for i in range(BODY_SECTION_COUNT):
		var t: float = float(i + 1) / (BODY_SECTION_COUNT + 1)
		var seg_radius: float = lerpf(0.55, 0.15, t * t)  # Smooth taper head→tail

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
		mat.emission = GLOW_COLOR
		mat.emission_energy_multiplier = 0.8
		seg.material_override = mat

		seg.position = Vector3(0, 0.4, -(i + 1) * SECTION_SPACING)
		add_child(seg)
		_body_sections.append(seg)

		# Purple veins: 2-3 thin tubes wrapping around each section
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

			var angle: float = (TAU / vein_count) * v + i * 0.7
			var offset_r: float = seg_radius * 0.85
			vein.position = Vector3(cos(angle) * offset_r, sin(angle) * offset_r, 0)
			vein.rotation.x = randf_range(-0.4, 0.4)
			vein.rotation.z = angle + PI * 0.5
			seg.add_child(vein)
			_vein_meshes.append(vein)

		# Synapse light on every 3rd section
		if i % 3 == 0:
			var synapse: OmniLight3D = OmniLight3D.new()
			synapse.light_color = vein_color
			synapse.light_energy = 0.0
			synapse.omni_range = seg_radius * 3.0
			synapse.shadow_enabled = false
			seg.add_child(synapse)
			_synapse_lights.append(synapse)

		# Connector cylinder between sections
		var connector: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		var prev_radius: float = lerpf(0.55, 0.15, (float(i) / (BODY_SECTION_COUNT + 1)) ** 2)
		cyl.top_radius = seg_radius * 0.85
		cyl.bottom_radius = prev_radius * 0.85
		cyl.height = SECTION_SPACING * 0.8
		cyl.radial_segments = 10
		connector.mesh = cyl

		var conn_mat: StandardMaterial3D = StandardMaterial3D.new()
		conn_mat.albedo_color = col.darkened(0.05)
		conn_mat.roughness = 0.7
		conn_mat.emission_enabled = true
		conn_mat.emission = GLOW_COLOR * 0.7
		conn_mat.emission_energy_multiplier = 0.6
		connector.material_override = conn_mat

		connector.position = Vector3(0, 0.4, -(i + 0.5) * SECTION_SPACING)
		add_child(connector)
		_connectors.append(connector)

	# Tail tip
	var tail: MeshInstance3D = MeshInstance3D.new()
	var tail_mesh: CylinderMesh = CylinderMesh.new()
	tail_mesh.top_radius = 0.01
	tail_mesh.bottom_radius = 0.12
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
	tail.position = Vector3(0, 0.3, -(BODY_SECTION_COUNT + 0.8) * SECTION_SPACING)
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
		var max_history: int = (BODY_SECTION_COUNT + 5) * int(SECTION_SPACING / HISTORY_RESOLUTION) + 20
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

	# --- Tail Whip (F key) ---
	_tail_whip_cooldown = maxf(_tail_whip_cooldown - delta, 0.0)
	if Input.is_key_pressed(KEY_F) and _tail_whip_cooldown <= 0 and energy >= TAIL_WHIP_ENERGY_COST and not _tail_whip_active:
		_trigger_tail_whip()
	if _tail_whip_active:
		_tail_whip_timer -= delta
		_update_tail_whip_sweep(delta)
		if _tail_whip_timer <= 0:
			_tail_whip_active = false
			_tail_whip_hit_targets.clear()

	# --- Camouflage (C key near wall) ---
	if Input.is_key_pressed(KEY_C) and energy > _camo_energy_drain * delta and not _is_sprinting:
		if not _is_camouflaged:
			_is_camouflaged = true
		energy -= _camo_energy_drain * delta
		_camo_alpha = lerpf(_camo_alpha, 0.2, delta * 5.0)
		noise_level = minf(noise_level, 0.05)  # Nearly silent when camo'd
	else:
		if _is_camouflaged:
			_is_camouflaged = false
		_camo_alpha = lerpf(_camo_alpha, 1.0, delta * 5.0)
	# Apply camo transparency to segments
	if absf(_camo_alpha - 1.0) > 0.02:
		_apply_camo_transparency(_camo_alpha)

	# --- Boss Trait Activation (1-5 keys or auto from equipped) ---
	_trait_cooldown = maxf(_trait_cooldown - delta, 0.0)
	if _bone_shield_active:
		_bone_shield_timer -= delta
		if _bone_shield_timer <= 0:
			_bone_shield_active = false
			if _shield_mesh:
				_shield_mesh.visible = false
	# Number keys 1-5 activate traits directly
	for key_idx in range(5):
		if Input.is_key_pressed(KEY_1 + key_idx) and _trait_cooldown <= 0:
			var all_traits: Array = GameManager.unlocked_traits
			if key_idx < all_traits.size():
				_activate_trait(all_traits[key_idx])

	# Update trait VFX (shield pulse, flash decay)
	_update_trait_vfx(delta)

	# --- Creature idle vocalizations ---
	_idle_voice_timer -= delta
	if _idle_voice_timer <= 0:
		_idle_voice_timer = randf_range(5.0, 10.0)
		AudioManager.play_player_voice("idle")

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

	# --- Eye stalk pulse (organic bioluminescent flicker) ---
	if _eye_light:
		var pulse: float = sin(_time * 2.0) * 0.25 + sin(_time * 5.7) * 0.1
		var beam_energy: float = _eye_light_base_energy + pulse
		# Dim during creep for stealth
		if _is_creeping:
			beam_energy *= 0.1  # Nearly off when sneaking
		_eye_light.light_energy = beam_energy
		# Lure glow pulses with the light
		if _lure_light:
			_lure_light.light_energy = 0.4 + pulse * 0.3
			if _is_creeping:
				_lure_light.light_energy *= 0.15
		# Lure emission pulses
		if _eye_lure and _eye_lure.material_override is StandardMaterial3D:
			var lure_mat: StandardMaterial3D = _eye_lure.material_override
			var lure_glow: float = 2.0 + pulse * 1.5
			if _is_creeping:
				lure_glow *= 0.15
			lure_mat.emission_energy_multiplier = lure_glow

	# --- Eye stalk sway (organic wobble) ---
	if _eye_stalk:
		_eye_stalk.rotation.x = sin(_time * 1.3) * 0.08
		_eye_stalk.rotation.z = sin(_time * 0.9 + 1.0) * 0.06
		# More sway when moving fast
		var speed_sway: float = clampf(absf(_current_speed) / BASE_SPEED, 0.0, 1.0)
		_eye_stalk.rotation.x += sin(_time * 4.0) * 0.04 * speed_sway

func _update_segments(delta: float) -> void:
	var prev_pos: Vector3
	if _head_wrapper:
		prev_pos = _head_wrapper.position
	elif _head_node:
		prev_pos = _head_node.position
	else:
		prev_pos = _head_mesh.position
	for i in range(_body_sections.size()):
		var seg: MeshInstance3D = _body_sections[i]
		var desired_dist: float = (i + 1) * SECTION_SPACING
		var target_pos: Vector3 = _get_history_position(desired_dist)
		var local_target: Vector3 = to_local(target_pos)

		seg.position = seg.position.lerp(local_target, delta * 14.0)

		# Wobble animation
		var wobble: float = sin(_time * 3.0 + i * 1.5) * 0.06
		seg.position.y += wobble

		# Green glow breathing per section (staggered wave)
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
	if _connectors.size() > 0 and _body_sections.size() > 0:
		var tail: MeshInstance3D = _connectors[-1]
		var tail_dist: float = (BODY_SECTION_COUNT + 0.5) * SECTION_SPACING
		var tail_target: Vector3 = to_local(_get_history_position(tail_dist))
		tail.position = tail.position.lerp(tail_target, delta * 12.0)
		var last_seg: Vector3 = _body_sections[-1].position
		var tail_dir: Vector3 = (tail.position - last_seg)
		if tail_dir.length() > 0.01:
			tail.look_at_from_position(tail.position, tail.position + tail_dir, Vector3.UP)
			tail.rotation.x += PI * 0.5

	# Synapse firing: purple pulse wave traveling head-to-tail
	var synapse_wave: float = fmod(_time * 1.5, 4.0)
	for si in range(_synapse_lights.size()):
		var light: OmniLight3D = _synapse_lights[si]
		var seg_index: float = float(si) / maxf(_synapse_lights.size() - 1, 1)
		var wave_dist: float = absf(synapse_wave - seg_index * 3.0)
		if wave_dist < 0.5:
			var pulse: float = 1.0 - wave_dist * 2.0
			light.light_energy = pulse * 2.5
		else:
			light.light_energy = lerpf(light.light_energy, 0.0, delta * 6.0)

	# Vein glow pulse
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

func collect_nutrient_growth() -> void:
	## Called when a nutrient is collected. Heals and restores energy instead of growing.
	heal(5.0)
	restore_energy(3.0)

# --- Boss Trait Execution ---

func _activate_trait(trait_id: String) -> void:
	var data: Dictionary = BossTraitSystem.get_trait(trait_id)
	if data.is_empty():
		return
	var cost: float = BossTraitSystem.get_energy_cost(trait_id)
	if energy < cost:
		return
	energy -= cost
	_trait_cooldown = BossTraitSystem.get_cooldown(trait_id)
	_noise_spike = 1.0
	_noise_spike_timer = 2.0
	# Break camo
	if _is_camouflaged:
		_is_camouflaged = false
		_camo_alpha = 1.0
	match trait_id:
		"pulse_wave":
			_do_pulse_wave()
			AudioManager.play_pulse_wave()
		"acid_spit":
			_do_acid_spit()
			AudioManager.play_acid_spit_muzzle()
		"wind_gust":
			_do_wind_gust()
			AudioManager.play_wind_gust()
		"bone_shield":
			_do_bone_shield(data)
			AudioManager.play_bone_shield()
		"summon_minions":
			_do_summon_minions()
			AudioManager.play_summon_minions()
	AudioManager.play_player_voice("attack")

func _do_pulse_wave() -> void:
	var radius: float = BossTraitSystem.get_radius("pulse_wave")
	var dmg: float = BossTraitSystem.get_damage("pulse_wave")
	var mult: float = GameManager.get_trait_multiplier("pulse_wave")
	var knockback: float = 15.0 * mult
	for group in ["white_blood_cell", "phagocyte", "killer_t_cell", "mast_cell", "flyer", "boss"]:
		for enemy in get_tree().get_nodes_in_group(group):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < radius:
				var falloff: float = 1.0 - dist / radius
				if enemy.has_method("take_damage"):
					enemy.take_damage(dmg * falloff)
				if enemy is CharacterBody3D:
					var push: Vector3 = (enemy.global_position - global_position).normalized()
					push.y = 0.5
					enemy.velocity += push * knockback * falloff
				if enemy.has_method("stun"):
					enemy.stun(1.0)
	# VFX: expanding shockwave ring
	_spawn_pulse_ring(radius, Color(0.9, 0.2, 0.1))
	_trait_flash = 0.5
	_trait_flash_color = Color(1.0, 0.3, 0.1)

func _do_acid_spit() -> void:
	var proj_script = load("res://scripts/snake_stage/acid_projectile.gd")
	if not proj_script:
		return
	var mult: float = GameManager.get_trait_multiplier("acid_spit")
	var proj: Area3D = Area3D.new()
	proj.set_script(proj_script)
	var forward: Vector3 = Vector3(sin(_heading + _head_flip), 0, cos(_heading + _head_flip)).normalized()
	proj.direction = forward
	proj.speed = 25.0
	proj.damage = 8.0 * mult
	proj.dot_dps = 5.0 * mult
	proj.dot_duration = 4.0
	proj.position = global_position + Vector3(0, 0.8, 0) + forward * 1.5
	get_parent().add_child(proj)
	# VFX: muzzle flash at mouth
	_spawn_muzzle_flash(forward, Color(0.3, 0.9, 0.1))
	_trait_flash = 0.3
	_trait_flash_color = Color(0.3, 1.0, 0.1)

func _do_wind_gust() -> void:
	var mult: float = GameManager.get_trait_multiplier("wind_gust")
	var forward: Vector3 = Vector3(sin(_heading + _head_flip), 0, cos(_heading + _head_flip)).normalized()
	for group in ["white_blood_cell", "phagocyte", "killer_t_cell", "mast_cell", "flyer", "boss"]:
		for enemy in get_tree().get_nodes_in_group(group):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < 15.0 * mult:
				var to_enemy: Vector3 = (enemy.global_position - global_position).normalized()
				var dot: float = to_enemy.dot(forward)
				if dot > 0.3:
					var falloff: float = 1.0 - dist / (15.0 * mult)
					if enemy.has_method("take_damage"):
						enemy.take_damage(8.0 * mult * falloff)
					if enemy is CharacterBody3D:
						enemy.velocity += to_enemy * 20.0 * mult * falloff
	# VFX: cone sweep
	_spawn_wind_cone(forward, 15.0 * mult, Color(0.4, 0.7, 1.0))
	_trait_flash = 0.3
	_trait_flash_color = Color(0.5, 0.8, 1.0)

func _do_bone_shield(data: Dictionary) -> void:
	var mult: float = GameManager.get_trait_multiplier("bone_shield")
	_bone_shield_active = true
	_bone_shield_timer = data.get("base_duration", 3.0) * (1.0 + (mult - 1.0) * 0.4)
	if not _shield_mesh:
		_shield_mesh = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 2.0
		sphere.height = 4.0
		sphere.radial_segments = 20
		sphere.rings = 10
		_shield_mesh.mesh = sphere
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.85, 0.6, 0.15)
		mat.roughness = 0.1
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.75, 0.5)
		mat.emission_energy_multiplier = 2.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shield_mesh.material_override = mat
		_shield_mesh.position = Vector3(0, 0.8, 0)
		add_child(_shield_mesh)
	_shield_mesh.visible = true
	_trait_flash = 0.4
	_trait_flash_color = Color(0.9, 0.85, 0.5)

func _do_summon_minions() -> void:
	var mult: float = GameManager.get_trait_multiplier("summon_minions")
	var count: int = 2 + int(mult - 1.0)
	var bug_script = load("res://scripts/snake_stage/prey_bug.gd")
	if not bug_script:
		return
	for i in range(count):
		var ally: CharacterBody3D = CharacterBody3D.new()
		ally.set_script(bug_script)
		var angle: float = TAU * i / count + randf() * 0.5
		ally.position = global_position + Vector3(cos(angle) * 3.0, 0.5, sin(angle) * 3.0)
		ally.add_to_group("player_ally")
		get_tree().current_scene.add_child(ally)
		# Spawn particle burst at each ally position
		_spawn_summon_burst(ally.position)
	_trait_flash = 0.4
	_trait_flash_color = Color(0.6, 0.2, 0.8)

# --- Trait VFX Helpers ---

func _spawn_pulse_ring(max_radius: float, color: Color) -> void:
	## Expanding shockwave ring for pulse_wave
	if _pulse_ring and is_instance_valid(_pulse_ring):
		_pulse_ring.queue_free()
	_pulse_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.2
	torus.rings = 24
	torus.ring_segments = 16
	_pulse_ring.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	_pulse_ring.material_override = mat
	_pulse_ring.position = Vector3(0, 0.5, 0)
	_pulse_ring.scale = Vector3(0.1, 0.1, 0.1)
	add_child(_pulse_ring)
	_pulse_ring_active = true
	_pulse_ring_scale = 0.1
	# Tween the ring outward then free
	var tw: Tween = create_tween()
	tw.tween_property(_pulse_ring, "scale", Vector3(max_radius, 0.3, max_radius), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.tween_callback(_pulse_ring.queue_free)
	tw.tween_callback(func(): _pulse_ring = null; _pulse_ring_active = false)

func _spawn_muzzle_flash(forward: Vector3, color: Color) -> void:
	## Brief flash + light at mouth for acid spit
	var flash: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	flash.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = mat
	flash.position = Vector3(0, 0.8, 0) + forward * 1.5
	add_child(flash)
	# Flash light
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 8.0
	light.position = flash.position
	add_child(light)
	# Fade out
	var tw: Tween = create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.25)
	tw.tween_callback(flash.queue_free)
	tw.tween_callback(light.queue_free)

func _spawn_wind_cone(forward: Vector3, range_dist: float, color: Color) -> void:
	## Cone sweep particles for wind gust
	var cone: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = range_dist * 0.4
	cylinder.height = range_dist * 0.8
	cylinder.radial_segments = 12
	cone.mesh = cylinder
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.15)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material_override = mat
	# Orient cone along forward direction
	cone.position = global_position + Vector3(0, 0.8, 0) + forward * range_dist * 0.4
	var up: Vector3 = Vector3.UP
	if absf(forward.dot(up)) > 0.99:
		up = Vector3.RIGHT
	cone.look_at_from_position(cone.position, cone.position + forward, up)
	cone.rotate_object_local(Vector3.RIGHT, PI * 0.5)  # Align cylinder axis with forward
	get_parent().add_child(cone)
	# Fade out
	var tw: Tween = create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(cone.queue_free)

func _spawn_summon_burst(pos: Vector3) -> void:
	## Purple sparkle burst at summon position
	var burst: OmniLight3D = OmniLight3D.new()
	burst.light_color = Color(0.6, 0.2, 0.8)
	burst.light_energy = 4.0
	burst.omni_range = 5.0
	burst.position = pos + Vector3(0, 1.0, 0)
	get_parent().add_child(burst)
	var tw: Tween = get_tree().create_tween()
	tw.tween_property(burst, "light_energy", 0.0, 0.8)
	tw.tween_callback(burst.queue_free)

func _update_trait_vfx(delta: float) -> void:
	# Trait activation flash (overlay handled in HUD via metadata)
	if _trait_flash > 0:
		_trait_flash = maxf(_trait_flash - delta * 3.0, 0.0)
	# Bone shield pulse
	if _bone_shield_active and _shield_mesh and _shield_mesh.visible:
		var pulse: float = 1.0 + sin(_time * 4.0) * 0.05
		_shield_mesh.scale = Vector3(pulse, pulse, pulse)
		var smat = _shield_mesh.material_override
		if smat:
			smat.emission_energy_multiplier = 2.0 + sin(_time * 3.0) * 0.5

func _trigger_tail_whip() -> void:
	## Spin-slam tail in 360 arc, damaging and knocking back nearby enemies
	# Break camouflage — tail whip is loud
	if _is_camouflaged:
		_is_camouflaged = false
		_camo_alpha = 1.0
	_tail_whip_active = true
	_tail_whip_timer = TAIL_WHIP_DURATION
	_tail_whip_cooldown = TAIL_WHIP_COOLDOWN_TIME
	energy -= TAIL_WHIP_ENERGY_COST
	_noise_spike = 1.0
	_noise_spike_timer = 2.0
	AudioManager.play_tail_whip()
	AudioManager.play_player_voice("attack")
	tail_whip_performed.emit()
	# Damage is now dealt per-frame during sweep in _update_tail_whip_sweep()
	_tail_whip_hit_targets.clear()
	_tail_whip_angle = 0.0

func _update_tail_whip_sweep(delta: float) -> void:
	## Animated sweep: advance angle, offset tail sections, check for hits
	_tail_whip_angle += (PI / TAIL_WHIP_DURATION) * delta
	_tail_whip_angle = minf(_tail_whip_angle, PI)

	# Sweep progress 0→1
	var sweep_t: float = _tail_whip_angle / PI

	# Offset tail body sections perpendicular to body direction during sweep
	var perp: Vector3 = Vector3(cos(_heading), 0, -sin(_heading))
	var sweep_offset_strength: float = sin(sweep_t * PI) * 2.0  # Peaks at midpoint
	var sweep_side: float = lerpf(-1.0, 1.0, sweep_t)  # Swings from left to right

	# Find tail world positions for damage check
	var tail_positions: Array[Vector3] = []
	for i in range(_body_sections.size()):
		var sec: MeshInstance3D = _body_sections[i]
		var t: float = float(i) / maxf(_body_sections.size() - 1, 1)
		# Only offset the back half of the body
		if t > 0.4:
			var offset_amount: float = sweep_side * sweep_offset_strength * (t - 0.4) * 2.5
			sec.position.x += perp.x * offset_amount * delta * 8.0
			sec.position.z += perp.z * offset_amount * delta * 8.0
		if t > 0.6:
			tail_positions.append(sec.global_position)

	# Check for enemy hits along tail sweep arc (excludes prey - tail whip is defensive)
	for group_name in ["white_blood_cell", "flyer", "phagocyte", "killer_t_cell", "mast_cell", "boss"]:
		for creature in get_tree().get_nodes_in_group(group_name):
			if creature in _tail_whip_hit_targets:
				continue
			for tail_pos in tail_positions:
				var dist: float = tail_pos.distance_to(creature.global_position)
				if dist < TAIL_WHIP_RANGE:
					_tail_whip_hit_targets.append(creature)
					if creature.has_method("take_damage"):
						creature.take_damage(TAIL_WHIP_DAMAGE)
					var knockback_dir: Vector3 = (creature.global_position - global_position).normalized()
					knockback_dir.y = 0.5
					if creature is CharacterBody3D:
						creature.velocity += knockback_dir * TAIL_WHIP_KNOCKBACK
					break

func apply_venom(target: Node3D) -> void:
	## Apply venom DoT to a target (called after bite hits)
	if not target.has_meta("venomed"):
		target.set_meta("venomed", true)
		target.set_meta("venom_remaining", _venom_duration)
		target.set_meta("venom_dps", _venom_damage_per_sec)
		AudioManager.play_venom_spit()
		# Venom ticks handled by snake_stage_manager

func get_camo_critical_mult() -> float:
	## Returns damage multiplier for camo-break attacks
	if _is_camouflaged:
		return 3.0  # Triple damage from stealth
	return 1.0

func _apply_camo_transparency(alpha: float) -> void:
	## Set transparency on all body sections for camouflage effect
	for seg in _body_sections:
		var mat: StandardMaterial3D = seg.material_override
		if mat:
			if alpha < 0.9:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = alpha
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.albedo_color.a = 1.0

func take_damage(amount: float) -> void:
	# Bone shield blocks all damage
	if _bone_shield_active:
		return
	# Camo breaks on damage
	if _is_camouflaged:
		_is_camouflaged = false
		_camo_alpha = 1.0
	health -= amount
	_damage_flash = 1.0
	if _face_canvas:
		_face_canvas.set_mood(_face_canvas.Mood.HURT, 0.8)
		_face_canvas.trigger_damage_flash()
	AudioManager.play_player_voice("hurt")
	damaged.emit(amount)
	if health <= 0:
		_die()

var last_death_position: Vector3 = Vector3.ZERO

func _die() -> void:
	# Death penalty: lose half nutrients/health
	last_death_position = global_position
	AudioManager.play_player_voice("death")
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
			"slow":
				_hazard_slow = minf(_hazard_slow, node.get_meta("slow_factor", 0.5))
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
	var crit_mult: float = get_camo_critical_mult()
	var targets: Array = get_bite_targets()
	for target in targets:
		if target.has_method("take_damage"):
			target.take_damage(25.0 * crit_mult)
		# Apply venom DoT
		apply_venom(target)
		# Knockback: push target away from player + upward
		if target is CharacterBody3D:
			var push: Vector3 = (target.global_position - global_position).normalized()
			target.velocity += push * 12.0 + Vector3(0, 3.0, 0)

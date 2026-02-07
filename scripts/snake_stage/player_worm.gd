extends CharacterBody3D
## Player worm: segmented body, expressive face, WASD movement, sprint/creep.
## Segments follow the head in a chain (follow-the-leader using position history).
## Adapted for cave environment: pure gravity + collision, no terrain snapping.

signal damaged(amount: float)
signal died
signal nutrient_collected(item: Dictionary)

# --- Movement ---
const BASE_SPEED: float = 8.0
const SPRINT_SPEED: float = 14.0
const CREEP_SPEED: float = 3.0
const TURN_SPEED: float = 3.0
const GRAVITY: float = 20.0

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

# --- Visuals ---
var _time: float = 0.0
var _body_color: Color = Color(0.55, 0.35, 0.45)  # Pink-brown worm
var _belly_color: Color = Color(0.7, 0.55, 0.5)
var _damage_flash: float = 0.0

func _ready() -> void:
	add_to_group("player_worm")
	_build_head()
	_build_face()
	_build_segments()
	# Initialize position history
	for i in range(INITIAL_SEGMENTS * 10):
		_position_history.append(global_position)
		_rotation_history.append(_heading)
	_last_record_pos = global_position

func _build_head() -> void:
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
	mat.emission = _body_color * 0.3  # Slightly brighter emission for cave visibility
	mat.emission_energy_multiplier = 0.8
	_head_mesh.material_override = mat

	_head_mesh.position = Vector3(0, 0.6, 0)
	_head_mesh.rotation.x = PI * 0.5
	add_child(_head_mesh)

	# Nose bump
	var nose: MeshInstance3D = MeshInstance3D.new()
	var nose_sphere: SphereMesh = SphereMesh.new()
	nose_sphere.radius = 0.25
	nose_sphere.height = 0.45
	nose_sphere.radial_segments = 10
	nose_sphere.rings = 6
	nose.mesh = nose_sphere
	var nose_mat: StandardMaterial3D = StandardMaterial3D.new()
	nose_mat.albedo_color = _body_color.lightened(0.1)
	nose_mat.roughness = 0.5
	nose_mat.emission_enabled = true
	nose_mat.emission = _body_color.lightened(0.1) * 0.25
	nose_mat.emission_energy_multiplier = 0.5
	nose.material_override = nose_mat
	nose.position = Vector3(0, 0.6, 0.5)
	add_child(nose)

func _build_face() -> void:
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
	_face_billboard.position = Vector3(0, 0.75, 0.65)
	_face_billboard.modulate = Color(1, 1, 1, 0.95)
	_face_billboard.no_depth_test = false
	_face_billboard.render_priority = 1
	_face_billboard.transparent = true
	add_child(_face_billboard)

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
	_current_speed = lerpf(_current_speed, target_speed, delta * 8.0)

	# --- Direction ---
	var forward: Vector3 = Vector3(sin(_heading), 0, cos(_heading))
	var move_vel: Vector3 = forward * _current_speed

	# --- Gravity (pure physics, no terrain snapping) ---
	if not is_on_floor():
		_vertical_velocity -= GRAVITY * delta
	else:
		_vertical_velocity = -0.5  # Small downward to stay grounded

	velocity = Vector3(move_vel.x, _vertical_velocity, move_vel.z)
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

	# --- Update face ---
	_update_face(delta)

	# --- Head bob ---
	var bob: float = sin(_time * 8.0) * 0.05 * clampf(absf(_current_speed) / BASE_SPEED, 0.0, 1.0)
	_head_mesh.position.y = 0.6 + bob

func _update_segments(delta: float) -> void:
	var prev_pos: Vector3 = _head_mesh.position
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

extends Camera3D
## Cave camera: always underground style, dynamic distance based on cave size.
## Ceiling clip prevention via raycast, smooth follow, movement bob.

# Cave camera settings (always underground)
const DEFAULT_BACK: float = 5.0
const DEFAULT_UP: float = 3.0
const DEFAULT_LOOK_AHEAD: float = 3.5
const DEFAULT_FOV: float = 80.0

# Dynamic range based on cave size
const TUNNEL_BACK: float = 8.0
const TUNNEL_UP: float = 5.0
const TUNNEL_FOV: float = 80.0  # Wide for hallway context

const HUB_SMALL_BACK: float = 15.0
const HUB_SMALL_UP: float = 8.0
const HUB_SMALL_FOV: float = 75.0

const HUB_LARGE_BACK: float = 30.0
const HUB_LARGE_UP: float = 15.0
const HUB_LARGE_FOV: float = 70.0  # Wide enough to see the cavern

const FOLLOW_SPEED: float = 6.0
const ROTATION_SPEED: float = 5.0
const CEILING_CHECK_MARGIN: float = 0.8

# Zoom control
const ZOOM_MIN: float = 0.3   # Closest zoom (30% of context distance)
const ZOOM_MAX: float = 1.2   # Furthest zoom (120% of context distance)
const ZOOM_STEP: float = 0.08 # Per scroll click
const ZOOM_SMOOTH: float = 6.0

var _target: Node3D = null
var _smooth_pos: Vector3 = Vector3.ZERO
var _smooth_look: Vector3 = Vector3.ZERO
var _time: float = 0.0

# Current interpolated camera parameters
var _current_back: float = DEFAULT_BACK
var _current_up: float = DEFAULT_UP
var _current_fov: float = DEFAULT_FOV
var _current_look_ahead: float = DEFAULT_LOOK_AHEAD

# Zoom
var _zoom_factor: float = 1.0  # User-controlled zoom multiplier
var _zoom_target: float = 1.0

# Raycast for ceiling detection
var _ray_query: PhysicsRayQueryParameters3D = null

func setup(target: Node3D) -> void:
	_target = target
	if _target:
		snap_to_target()

func snap_to_target() -> void:
	if not _target:
		return
	var heading: float = _target.rotation.y
	var back: Vector3 = Vector3(-sin(heading) * _current_back, _current_up, -cos(heading) * _current_back)
	_smooth_pos = _target.global_position + back
	_smooth_look = _target.global_position + Vector3(sin(heading) * _current_look_ahead, 0.5, cos(heading) * _current_look_ahead)
	global_position = _smooth_pos
	look_at(_smooth_look, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_target = clampf(_zoom_target - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_target = clampf(_zoom_target + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)

func _physics_process(delta: float) -> void:
	if not _target:
		return

	_time += delta

	# Smooth zoom interpolation
	_zoom_factor = lerpf(_zoom_factor, _zoom_target, delta * ZOOM_SMOOTH)

	var heading: float = _target.rotation.y

	# Desired camera position (zoom applied to back distance and height)
	var back_dir: Vector3 = Vector3(-sin(heading), 0, -cos(heading))
	var zoomed_back: float = _current_back * _zoom_factor
	var zoomed_up: float = _current_up * _zoom_factor
	var desired_pos: Vector3 = _target.global_position + back_dir * zoomed_back + Vector3(0, zoomed_up, 0)
	var desired_look: Vector3 = _target.global_position + Vector3(sin(heading), 0, cos(heading)) * _current_look_ahead + Vector3(0, 0.5, 0)

	# Smooth interpolation
	_smooth_pos = _smooth_pos.lerp(desired_pos, delta * FOLLOW_SPEED)
	_smooth_look = _smooth_look.lerp(desired_look, delta * ROTATION_SPEED)

	# Ceiling clip prevention: raycast upward from player
	_prevent_ceiling_clip()

	# Movement bob (subtle in caves)
	var worm_speed: float = _target.velocity.length() if _target is CharacterBody3D else 0.0
	var bob_intensity: float = clampf(worm_speed / 8.0, 0.0, 1.0) * 0.04
	var bob: Vector3 = Vector3(0, sin(_time * 4.0) * bob_intensity, 0)

	global_position = _smooth_pos + bob
	look_at(_smooth_look, Vector3.UP)

	# Smooth FOV transitions
	fov = lerpf(fov, _current_fov, delta * 3.0)

func _prevent_ceiling_clip() -> void:
	if not _target:
		return

	# Check if camera position is too close to ceiling
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return

	# Raycast upward from camera position
	var from: Vector3 = _smooth_pos - Vector3(0, 0.5, 0)
	var to: Vector3 = _smooth_pos + Vector3(0, 1.5, 0)

	if not _ray_query:
		_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.from = from
	_ray_query.to = to
	_ray_query.collision_mask = 0xFFFFFFFF

	var result: Dictionary = space_state.intersect_ray(_ray_query)
	if result.size() > 0:
		# Ceiling hit - push camera down
		var hit_y: float = result.position.y
		if _smooth_pos.y > hit_y - CEILING_CHECK_MARGIN:
			_smooth_pos.y = hit_y - CEILING_CHECK_MARGIN

	# Also raycast from player toward camera to prevent wall clipping
	var player_pos: Vector3 = _target.global_position + Vector3(0, 0.5, 0)
	_ray_query.from = player_pos
	_ray_query.to = _smooth_pos

	# Exclude player from collision check
	var exclude: Array[RID] = []
	if _target is CollisionObject3D:
		exclude.append(_target.get_rid())
	_ray_query.exclude = exclude

	result = space_state.intersect_ray(_ray_query)
	if result.size() > 0:
		# Wall between player and camera - move camera closer
		_smooth_pos = result.position + (player_pos - _smooth_pos).normalized() * 0.5

## Call from stage manager to adjust camera based on location type.
## cave_size: 0=narrow tunnel, 0.5=small hub, 1.0=massive cavern
func set_cave_size(cave_size: float) -> void:
	if cave_size < 0.2:
		# Narrow tunnel
		_current_back = TUNNEL_BACK
		_current_up = TUNNEL_UP
		_current_fov = TUNNEL_FOV
		_current_look_ahead = 2.5
	elif cave_size < 0.5:
		# Small hub
		_current_back = lerpf(TUNNEL_BACK, HUB_SMALL_BACK, (cave_size - 0.2) / 0.3)
		_current_up = lerpf(TUNNEL_UP, HUB_SMALL_UP, (cave_size - 0.2) / 0.3)
		_current_fov = lerpf(TUNNEL_FOV, HUB_SMALL_FOV, (cave_size - 0.2) / 0.3)
		_current_look_ahead = lerpf(2.5, 3.5, (cave_size - 0.2) / 0.3)
	else:
		# Large hub / cathedral
		_current_back = lerpf(HUB_SMALL_BACK, HUB_LARGE_BACK, (cave_size - 0.5) / 0.5)
		_current_up = lerpf(HUB_SMALL_UP, HUB_LARGE_UP, (cave_size - 0.5) / 0.5)
		_current_fov = lerpf(HUB_SMALL_FOV, HUB_LARGE_FOV, (cave_size - 0.5) / 0.5)
		_current_look_ahead = lerpf(3.5, 5.0, (cave_size - 0.5) / 0.5)

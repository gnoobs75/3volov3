extends Camera2D
## Top-down RTS camera with WASD pan, edge scroll, and mouse wheel zoom.

const PAN_SPEED: float = 600.0
const EDGE_SCROLL_MARGIN: float = 30.0
const EDGE_SCROLL_SPEED: float = 500.0
const ZOOM_MIN: float = 0.3
const ZOOM_MAX: float = 1.5
const ZOOM_STEP: float = 0.1
const ZOOM_LERP_SPEED: float = 8.0
const MAP_RADIUS: float = 8000.0

var _target_zoom: float = 0.6
var _pan_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	zoom = Vector2(_target_zoom, _target_zoom)
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0

func _process(delta: float) -> void:
	# WASD pan
	var pan_dir: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		pan_dir.y -= 1.0
	if Input.is_action_pressed("move_down"):
		pan_dir.y += 1.0
	if Input.is_action_pressed("move_left"):
		pan_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		pan_dir.x += 1.0

	# Edge scroll
	var vp_size: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_viewport().get_mouse_position()
	if mouse.x < EDGE_SCROLL_MARGIN:
		pan_dir.x -= 1.0
	elif mouse.x > vp_size.x - EDGE_SCROLL_MARGIN:
		pan_dir.x += 1.0
	if mouse.y < EDGE_SCROLL_MARGIN:
		pan_dir.y -= 1.0
	elif mouse.y > vp_size.y - EDGE_SCROLL_MARGIN:
		pan_dir.y += 1.0

	# Apply pan (scale speed by inverse zoom for consistent feel)
	if pan_dir.length() > 0:
		pan_dir = pan_dir.normalized()
		var speed: float = PAN_SPEED / zoom.x
		global_position += pan_dir * speed * delta

	# Clamp to map bounds
	if global_position.length() > MAP_RADIUS:
		global_position = global_position.normalized() * MAP_RADIUS

	# Smooth zoom
	var current_z: float = zoom.x
	current_z = lerpf(current_z, _target_zoom, ZOOM_LERP_SPEED * delta)
	zoom = Vector2(current_z, current_z)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_zoom = clampf(_target_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_zoom = clampf(_target_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)

func focus_position(pos: Vector2) -> void:
	global_position = pos

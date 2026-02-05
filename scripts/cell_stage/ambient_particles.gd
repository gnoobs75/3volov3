extends Node2D
## Vibrant bioluminescent ambient particles — OPTIMIZED for performance.
## Viewport culling and simplified drawing.

var _particles: Array[Dictionary] = []
var _time: float = 0.0
var _player: Node2D = null
var _camera_pos: Vector2 = Vector2.ZERO
var _camera_zoom: float = 1.0

const NUM_PARTICLES: int = 50  # Further reduced for performance
const SPAWN_RANGE: float = 500.0  # Smaller range, denser feel
const VIEWPORT_MARGIN: float = 80.0
const VIEWPORT_SIZE: Vector2 = Vector2(1920, 1080)

func _ready() -> void:
	for i in range(NUM_PARTICLES):
		_particles.append(_make_particle())
	call_deferred("_find_player")

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _make_particle() -> Dictionary:
	var type: int = randi() % 5  # Reduced variety
	var size: float = randf_range(1.0, 3.0)
	if type == 4:
		size = randf_range(3.5, 6.0)  # Larger jellyfish plankton
	return {
		"pos": Vector2(randf_range(-SPAWN_RANGE, SPAWN_RANGE), randf_range(-SPAWN_RANGE, SPAWN_RANGE)),
		"size": size,
		"alpha": randf_range(0.08, 0.2),
		"drift": Vector2(randf_range(-8.0, 8.0), randf_range(-15.0, -3.0)),
		"type": type,
		"phase": randf() * TAU,
		"pulse_speed": randf_range(1.5, 3.0),
	}

func _process(delta: float) -> void:
	_time += delta

	if not _player:
		_find_player()
		return

	# Cache camera info
	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam:
		_camera_pos = _player.global_position
		_camera_zoom = cam.zoom.x

	# Update positions
	for p in _particles:
		p.pos += p.drift * delta
		# Respawn if too far - randomize position to avoid horizontal bands
		if p.pos.length() > SPAWN_RANGE or _player and p.pos.distance_to(_player.global_position - global_position) > SPAWN_RANGE:
			# Spawn at random edge position, not fixed y
			var edge: int = randi() % 4
			match edge:
				0: p.pos = Vector2(randf_range(-SPAWN_RANGE, SPAWN_RANGE), -SPAWN_RANGE * 0.9)  # Top
				1: p.pos = Vector2(randf_range(-SPAWN_RANGE, SPAWN_RANGE), SPAWN_RANGE * 0.9)   # Bottom
				2: p.pos = Vector2(-SPAWN_RANGE * 0.9, randf_range(-SPAWN_RANGE, SPAWN_RANGE))  # Left
				3: p.pos = Vector2(SPAWN_RANGE * 0.9, randf_range(-SPAWN_RANGE, SPAWN_RANGE))   # Right
			if _player:
				p.pos += _player.global_position - global_position
			# Randomize drift direction to avoid uniform movement
			p.drift = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))

	queue_redraw()

func _is_visible(pos: Vector2) -> bool:
	if not _player:
		return true
	var world_pos: Vector2 = global_position + pos
	var half_view: Vector2 = (VIEWPORT_SIZE / _camera_zoom) * 0.5 + Vector2(VIEWPORT_MARGIN, VIEWPORT_MARGIN)
	var rel: Vector2 = world_pos - _camera_pos
	return abs(rel.x) < half_view.x and abs(rel.y) < half_view.y

func _draw() -> void:
	var colors: Array[Color] = [
		Color(0.3, 0.7, 1.0),   # Cyan
		Color(0.2, 1.0, 0.5),   # Green
		Color(1.0, 0.5, 0.7),   # Pink
		Color(0.6, 0.4, 1.0),   # Purple
		Color(0.4, 0.9, 0.9),   # Teal jellyfish
	]

	for p in _particles:
		if not _is_visible(p.pos):
			continue

		var c: Color = colors[p.type]
		var pulse: float = 0.7 + 0.3 * sin(_time * p.pulse_speed + p.phase)
		var alpha: float = p.alpha * pulse
		c.a = alpha

		var pos: Vector2 = p.pos
		# Simplified wobble
		pos.x += sin(_time * 1.5 + p.phase) * 2.0
		pos.y += sin(_time * 0.7 + p.phase * 2.0) * 1.0

		# All particles are simple dots now for performance
		draw_circle(pos, p.size, c)
		# Glow halo only for type 4 (jellyfish)
		if p.type == 4:
			draw_circle(pos, p.size * 2.0, Color(c.r, c.g, c.b, alpha * 0.15))

extends Area2D
## Environmental danger zones that add tactical depth to the cell stage.
## Types: ACID_POOL (damage over time), STATIC_FIELD (stun + damage pulse)

enum ZoneType { ACID_POOL, STATIC_FIELD }

var zone_type: ZoneType = ZoneType.ACID_POOL
var zone_radius: float = 80.0
var _time: float = 0.0
var _damage_timer: float = 0.0
var _pulse_timer: float = 0.0

# Acid pool settings
const ACID_DPS: float = 8.0  # Damage per second while inside
const ACID_SLOW: float = 0.6  # Movement multiplier while inside

# Static field settings
const STATIC_PULSE_INTERVAL: float = 3.0
const STATIC_PULSE_DAMAGE: float = 12.0
const STATIC_STUN_DURATION: float = 0.8

var _base_color: Color = Color(0.3, 0.8, 0.1, 0.2)
var _spark_positions: Array = []  # For static field visual

func setup(type: ZoneType, radius: float = 80.0) -> void:
	zone_type = type
	zone_radius = radius

func _ready() -> void:
	add_to_group("danger_zones")
	match zone_type:
		ZoneType.ACID_POOL:
			_base_color = Color(0.3, 0.75, 0.1, 0.15)
		ZoneType.STATIC_FIELD:
			_base_color = Color(0.4, 0.6, 1.0, 0.12)
			# Pre-compute spark positions
			for i in range(6):
				_spark_positions.append({
					"angle": randf() * TAU,
					"dist": randf_range(0.3, 0.9),
					"phase": randf() * TAU,
				})
	# Set collision shape radius
	var shape := $CollisionShape2D.shape as CircleShape2D
	if shape:
		shape.radius = zone_radius
	_pulse_timer = STATIC_PULSE_INTERVAL

func _physics_process(delta: float) -> void:
	_time += delta
	_damage_timer += delta

	match zone_type:
		ZoneType.ACID_POOL:
			# Continuous damage to bodies inside
			if _damage_timer >= 0.25:  # Tick every 0.25s
				_damage_timer = 0.0
				for body in get_overlapping_bodies():
					if body.is_in_group("player") and body.has_method("take_damage"):
						body.take_damage(ACID_DPS * 0.25)
		ZoneType.STATIC_FIELD:
			_pulse_timer -= delta
			if _pulse_timer <= 0:
				_pulse_timer = STATIC_PULSE_INTERVAL
				# Damage pulse to all inside
				for body in get_overlapping_bodies():
					if body.is_in_group("player") and body.has_method("take_damage"):
						body.take_damage(STATIC_PULSE_DAMAGE)

	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _draw() -> void:
	match zone_type:
		ZoneType.ACID_POOL:
			_draw_acid_pool()
		ZoneType.STATIC_FIELD:
			_draw_static_field()

func _draw_acid_pool() -> void:
	# Bubbling green pool
	var pulse: float = 0.02 * sin(_time * 1.5)
	draw_circle(Vector2.ZERO, zone_radius, Color(_base_color.r, _base_color.g, _base_color.b, _base_color.a + pulse))
	draw_circle(Vector2.ZERO, zone_radius * 0.7, Color(_base_color.r * 1.3, _base_color.g * 1.2, _base_color.b, _base_color.a * 1.5 + pulse))
	# Boundary
	draw_arc(Vector2.ZERO, zone_radius, 0, TAU, 32, Color(0.4, 0.85, 0.15, 0.2 + 0.05 * sin(_time * 2.0)), 1.5, true)
	# Bubbles
	for i in range(5):
		var bubble_t: float = fmod(_time * 0.4 + i * 1.3, 1.0)
		var bx: float = sin(i * 2.7 + _time * 0.3) * zone_radius * 0.5
		var by: float = zone_radius * 0.3 - bubble_t * zone_radius * 0.8
		var bubble_r: float = 2.0 + sin(bubble_t * PI) * 2.0
		var bubble_a: float = (1.0 - bubble_t) * 0.4
		draw_circle(Vector2(bx, by), bubble_r, Color(0.5, 0.9, 0.2, bubble_a))

func _draw_static_field() -> void:
	# Pulsing electrical zone
	var pulse_progress: float = 1.0 - _pulse_timer / STATIC_PULSE_INTERVAL
	var field_alpha: float = _base_color.a + 0.08 * pulse_progress
	draw_circle(Vector2.ZERO, zone_radius, Color(_base_color.r, _base_color.g, _base_color.b, field_alpha))
	# Boundary with electrical crackle
	var arc_alpha: float = 0.15 + 0.15 * pulse_progress
	draw_arc(Vector2.ZERO, zone_radius, 0, TAU, 32, Color(0.5, 0.7, 1.0, arc_alpha), 1.0 + pulse_progress, true)
	# Sparks
	for sp in _spark_positions:
		var spark_angle: float = sp.angle + sin(_time * 3.0 + sp.phase) * 0.3
		var spark_dist: float = sp.dist * zone_radius
		var spark_pos := Vector2(cos(spark_angle) * spark_dist, sin(spark_angle) * spark_dist)
		var spark_brightness: float = 0.3 + 0.7 * sin(_time * 8.0 + sp.phase)
		if spark_brightness > 0.6:
			draw_circle(spark_pos, 1.5, Color(0.7, 0.85, 1.0, spark_brightness * 0.6))
			# Lightning bolt to nearby spark
			var next_angle: float = spark_angle + randf_range(0.5, 1.5)
			var next_dist: float = randf_range(0.2, 0.8) * zone_radius
			var end_pos := Vector2(cos(next_angle) * next_dist, sin(next_angle) * next_dist)
			draw_line(spark_pos, end_pos, Color(0.6, 0.8, 1.0, spark_brightness * 0.3), 0.8, true)
	# Pulse flash when about to discharge
	if pulse_progress > 0.85:
		var flash: float = (pulse_progress - 0.85) / 0.15
		draw_circle(Vector2.ZERO, zone_radius * 0.9, Color(0.5, 0.7, 1.0, flash * 0.15))

extends Area2D
## Microfluidic current zone: applies directional force to all bodies inside.
## Simulates convection currents, thermal vents, and laminar flow in the petri dish.
## Visually shows streaming particle lines in the flow direction.

enum FlowType { LAMINAR, VORTEX, THERMAL_VENT }

var flow_type: FlowType = FlowType.LAMINAR
var flow_direction: Vector2 = Vector2.RIGHT
var flow_strength: float = 80.0
var zone_radius: float = 120.0
var _time: float = 0.0
var _particles: Array = []  # Visual streaming particles
const NUM_STREAM_PARTICLES: int = 20
var _base_color: Color = Color(0.3, 0.6, 0.9, 0.3)

func setup(type: FlowType, direction: Vector2 = Vector2.RIGHT, strength: float = 80.0, radius: float = 120.0) -> void:
	flow_type = type
	flow_direction = direction.normalized()
	flow_strength = strength
	zone_radius = radius

func _ready() -> void:
	add_to_group("currents")
	match flow_type:
		FlowType.LAMINAR:
			_base_color = Color(0.2, 0.5, 0.9, 0.15)
		FlowType.VORTEX:
			_base_color = Color(0.4, 0.8, 0.6, 0.15)
		FlowType.THERMAL_VENT:
			_base_color = Color(0.9, 0.4, 0.15, 0.15)
			flow_direction = Vector2.UP
	# Init visual particles
	for i in range(NUM_STREAM_PARTICLES):
		_particles.append({
			"pos": Vector2(randf_range(-zone_radius, zone_radius), randf_range(-zone_radius, zone_radius)),
			"life": randf(),
		})

func _physics_process(delta: float) -> void:
	_time += delta
	# Apply force to all overlapping bodies
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			var force: Vector2 = _get_flow_at(body.global_position - global_position) * flow_strength
			body.velocity += force * delta

	# Update visual particles
	for p in _particles:
		var flow: Vector2 = _get_flow_at(p.pos)
		p.pos += flow * 60.0 * delta
		p.life -= delta * 0.3
		if p.life <= 0 or p.pos.length() > zone_radius * 1.2:
			# Reset particle
			match flow_type:
				FlowType.LAMINAR:
					p.pos = Vector2(-zone_radius + randf() * 20, randf_range(-zone_radius, zone_radius) * 0.8)
				FlowType.VORTEX:
					p.pos = Vector2(randf_range(-zone_radius, zone_radius), randf_range(-zone_radius, zone_radius)) * 0.3
				FlowType.THERMAL_VENT:
					p.pos = Vector2(randf_range(-zone_radius * 0.3, zone_radius * 0.3), zone_radius * 0.5)
			p.life = 1.0
	var _vp_cam := get_viewport().get_camera_2d()
	if not _vp_cam or global_position.distance_squared_to(_vp_cam.global_position) < 1440000.0:
		queue_redraw()

func _get_flow_at(local_pos: Vector2) -> Vector2:
	var dist: float = local_pos.length()
	var falloff: float = clampf(1.0 - dist / zone_radius, 0.0, 1.0)
	match flow_type:
		FlowType.LAMINAR:
			return flow_direction * falloff
		FlowType.VORTEX:
			# Tangential force (clockwise)
			var tangent := Vector2(-local_pos.y, local_pos.x).normalized()
			return tangent * falloff * (0.5 + 0.5 * (1.0 - dist / zone_radius))
		FlowType.THERMAL_VENT:
			# Upward with spread
			var spread: float = local_pos.x / zone_radius * 0.3
			return Vector2(spread, -1.0).normalized() * falloff
	return Vector2.ZERO

func _draw() -> void:
	# Zone boundary (subtle)
	var boundary_a: float = 0.06 + 0.03 * sin(_time * 1.5)
	draw_arc(Vector2.ZERO, zone_radius, 0, TAU, 32, Color(_base_color.r, _base_color.g, _base_color.b, boundary_a), 1.0, true)

	# Zone fill
	draw_circle(Vector2.ZERO, zone_radius, Color(_base_color.r, _base_color.g, _base_color.b, 0.03))

	# Streaming particles (flow lines)
	for p in _particles:
		if p.pos.length() > zone_radius:
			continue
		var alpha: float = p.life * 0.5
		var flow: Vector2 = _get_flow_at(p.pos)
		var tail: Vector2 = p.pos - flow * 8.0
		draw_line(p.pos, tail, Color(_base_color.r, _base_color.g, _base_color.b, alpha), 1.0, true)
		draw_circle(p.pos, 1.2, Color(_base_color.r * 1.5, _base_color.g * 1.5, _base_color.b * 1.5, alpha * 0.8))

	# Type-specific visuals
	match flow_type:
		FlowType.VORTEX:
			# Spiral hint
			for s in range(2):
				var spiral_a: float = _time * 0.5 + s * PI
				var pts: int = 12
				var prev := Vector2.ZERO
				for i in range(pts):
					var t: float = float(i) / pts
					var r: float = t * zone_radius * 0.6
					var a: float = spiral_a + t * TAU * 1.5
					var pt := Vector2(cos(a) * r, sin(a) * r)
					if i > 0:
						draw_line(prev, pt, Color(_base_color.r, _base_color.g, _base_color.b, 0.08 * (1.0 - t)), 1.0, true)
					prev = pt
		FlowType.THERMAL_VENT:
			# Vent source glow at bottom
			var vent_y: float = zone_radius * 0.4
			var vent_pulse: float = 0.1 + 0.05 * sin(_time * 3.0)
			draw_circle(Vector2(0, vent_y), 8.0, Color(0.9, 0.3, 0.05, vent_pulse))
			draw_circle(Vector2(0, vent_y), 4.0, Color(1.0, 0.6, 0.2, vent_pulse * 2.0))

extends Node2D
## Small scattered biomolecule harvest point.
## Workers gather biomass from these nodes until depleted.

signal depleted(node: Node2D)

var biomass_remaining: int = 200
var max_biomass: int = 200
var _time: float = 0.0
var _pulse_offset: float = 0.0

# Particle streams toward gathering workers
var _gather_particles: Array = []  # [{pos, target_pos, progress, speed}]
var _particle_spawn_timer: float = 0.0
const PARTICLE_SPAWN_INTERVAL: float = 0.15

func _ready() -> void:
	_pulse_offset = randf() * TAU
	# Add collision area for detection
	var area := Area2D.new()
	area.name = "ResourceArea"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 0
	add_child(area)

func harvest(amount: int) -> Dictionary:
	## Returns {biomass: int, genes: int} actually harvested
	var actual: int = mini(amount, biomass_remaining)
	biomass_remaining -= actual
	if biomass_remaining <= 0:
		depleted.emit(self)
	queue_redraw()
	return {"biomass": actual, "genes": 0}

func is_depleted() -> bool:
	return biomass_remaining <= 0

func _process(delta: float) -> void:
	_time += delta
	_update_gather_particles(delta)
	queue_redraw()

func _update_gather_particles(delta: float) -> void:
	# Find nearest gathering worker
	var nearest_worker: Node2D = _find_nearest_gathering_worker()
	# Spawn new particles if workers are gathering
	if nearest_worker and biomass_remaining > 0:
		_particle_spawn_timer += delta
		if _particle_spawn_timer >= PARTICLE_SPAWN_INTERVAL:
			_particle_spawn_timer = 0.0
			var offset: Vector2 = Vector2(randf_range(-6, 6), randf_range(-6, 6))
			_gather_particles.append({
				"pos": offset,
				"target_pos": nearest_worker.global_position - global_position,
				"progress": 0.0,
				"speed": randf_range(1.5, 3.0),
			})
	# Update existing particles
	var i: int = _gather_particles.size() - 1
	while i >= 0:
		var p: Dictionary = _gather_particles[i]
		p["progress"] += delta * p["speed"]
		if nearest_worker and is_instance_valid(nearest_worker):
			p["target_pos"] = nearest_worker.global_position - global_position
		if p["progress"] >= 1.0:
			_gather_particles.remove_at(i)
		i -= 1

func _find_nearest_gathering_worker() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = 80.0  # Only show particles for workers within range
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		if "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
			if "state" in unit and unit.state == 2:  # GATHERING (typical enum value)
				var dist: float = global_position.distance_to(unit.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest = unit
	return nearest

func _draw() -> void:
	if biomass_remaining <= 0:
		return
	var fill: float = float(biomass_remaining) / float(max_biomass)
	var pulse: float = 1.0 + 0.15 * sin(_time * 2.0 + _pulse_offset)
	var radius: float = 8.0 + 6.0 * fill

	# Outer pulsing glow ring (oscillating alpha 0.05-0.15)
	var glow_alpha: float = 0.05 + 0.10 * (0.5 + 0.5 * sin(_time * 1.5 + _pulse_offset))
	var glow_radius: float = radius * 3.0 * pulse
	draw_arc(Vector2.ZERO, glow_radius, 0, TAU, 32, Color(0.2, 0.8, 0.4, glow_alpha), 2.0)
	draw_arc(Vector2.ZERO, glow_radius * 0.85, 0, TAU, 32, Color(0.15, 0.7, 0.35, glow_alpha * 0.5), 1.0)

	# Inner soft glow
	draw_circle(Vector2.ZERO, radius * 2.5 * pulse, Color(0.2, 0.8, 0.4, 0.06))

	# Main blob
	var pts := PackedVector2Array()
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		var r: float = radius * pulse + sin(_time * 3.0 + i * 0.8) * 1.5
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(pts, Color(0.15, 0.6, 0.3, 0.7 * fill + 0.3))

	# Sparkle
	var sparkle_pos: Vector2 = Vector2(cos(_time * 1.5) * 3.0, sin(_time * 1.5) * 3.0)
	draw_circle(sparkle_pos, 1.5, Color(0.4, 1.0, 0.6, 0.5))

	# Gather particle streams
	for p in _gather_particles:
		var t: float = p["progress"]
		var start: Vector2 = p["pos"]
		var target: Vector2 = p["target_pos"]
		# Cubic ease-in for acceleration effect
		var eased_t: float = t * t
		var draw_pos: Vector2 = start.lerp(target, eased_t)
		# Add slight sine curve to path
		var perp: Vector2 = (target - start).normalized().rotated(PI * 0.5)
		draw_pos += perp * sin(t * PI * 2.0) * 4.0
		var p_alpha: float = (1.0 - t) * 0.5
		var p_size: float = 1.5 * (1.0 - t * 0.5)
		draw_circle(draw_pos, p_size, Color(0.3, 0.9, 0.5, p_alpha))

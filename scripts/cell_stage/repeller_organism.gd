extends Area2D
## Repeller organism: emits a biochemical force field that pushes nearby cells away.
## Visually: pulsing anemone-like creature with radiating wave rings.

var _time: float = 0.0
var _radius: float = 12.0
var repel_force: float = 300.0
var repel_range: float = 80.0
var _tentacle_count: int = 0
var _base_color: Color
var _tentacle_offsets: Array[float] = []

# Tiny annoyed face
var _eye_size: float = 2.0

func _ready() -> void:
	_radius = randf_range(10.0, 14.0)
	_tentacle_count = randi_range(8, 14)
	_base_color = Color(randf_range(0.8, 1.0), randf_range(0.2, 0.5), randf_range(0.6, 1.0), 0.8)
	for i in range(_tentacle_count):
		_tentacle_offsets.append(randf_range(-0.3, 0.3))
	add_to_group("repellers")

func _physics_process(delta: float) -> void:
	_time += delta
	# Push away all nearby bodies
	for body in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(body):
			_apply_repel(body, delta)
			# Strip parasites off player when they pass through
			if body.has_method("attach_parasite") and global_position.distance_to(body.global_position) < repel_range * 0.7:
				_strip_parasites(body)
	for body in get_tree().get_nodes_in_group("competitors"):
		if is_instance_valid(body):
			_apply_repel(body, delta)
	# Also repel parasites themselves
	for p in get_tree().get_nodes_in_group("parasites"):
		if is_instance_valid(p):
			var dist: float = global_position.distance_to(p.global_position)
			if dist < repel_range and dist > 1.0:
				var strength: float = (1.0 - dist / repel_range) * repel_force * 1.5
				var push_dir: Vector2 = (p.global_position - global_position).normalized()
				p.global_position += push_dir * strength * delta
	queue_redraw()

func _strip_parasites(player: Node2D) -> void:
	if not player.has_method("attach_parasite"):
		return
	var parasites: Array = player.get("attached_parasites") if "attached_parasites" in player else []
	for p in parasites.duplicate():
		if is_instance_valid(p) and p.has_method("force_detach"):
			p.force_detach()
			# Fling the parasite away from the repeller
			var fling_dir: Vector2 = (p.global_position - global_position).normalized()
			p.global_position += fling_dir * 60.0
	if parasites.size() > 0 and "attached_parasites" in player:
		player.attached_parasites = player.attached_parasites.filter(func(pp): return is_instance_valid(pp) and pp.state == 2)
		if player.has_signal("parasites_changed"):
			player.parasites_changed.emit(player.attached_parasites.size())

func _apply_repel(body: Node2D, delta: float) -> void:
	var dist: float = global_position.distance_to(body.global_position)
	if dist < repel_range and dist > 1.0:
		var strength: float = (1.0 - dist / repel_range) * repel_force
		var push_dir: Vector2 = (body.global_position - global_position).normalized()
		if body is CharacterBody2D:
			body.velocity += push_dir * strength * delta

func _draw() -> void:
	# Repulsion wave rings
	for ring in range(3):
		var ring_phase: float = fmod(_time * 1.5 + ring * 0.8, 2.0)
		var ring_r: float = _radius + ring_phase * (repel_range - _radius) * 0.5
		var ring_a: float = (1.0 - ring_phase * 0.5) * 0.12
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 20, Color(_base_color.r, _base_color.g, _base_color.b, ring_a), 1.0, true)

	# Glow
	draw_circle(Vector2.ZERO, _radius * 2.0, Color(_base_color.r, _base_color.g, _base_color.b, 0.06))

	# Body (anemone dome)
	var body_pts: PackedVector2Array = PackedVector2Array()
	var n: int = 16
	for i in range(n):
		var a: float = TAU * i / n
		var wobble: float = sin(_time * 3.0 + i * 0.9) * 1.5
		body_pts.append(Vector2(cos(a) * (_radius + wobble), sin(a) * (_radius + wobble)))
	draw_colored_polygon(body_pts, Color(_base_color.r * 0.3, _base_color.g * 0.2, _base_color.b * 0.4, 0.6))
	for i in range(n):
		draw_line(body_pts[i], body_pts[(i + 1) % n], _base_color, 1.2, true)

	# Tentacles (radiating outward, waving)
	for t in range(_tentacle_count):
		var base_a: float = TAU * t / _tentacle_count + _tentacle_offsets[t]
		var base_pt := Vector2(cos(base_a) * _radius, sin(base_a) * _radius)
		var prev: Vector2 = base_pt
		for s in range(4):
			var wave: float = sin(_time * 4.0 + t * 0.8 + s) * 2.5
			var extend: float = 4.0 + s * 2.0
			var next_a: float = base_a + wave * 0.05
			var next: Vector2 = prev + Vector2(cos(next_a) * extend, sin(next_a) * extend)
			var alpha: float = 0.5 - s * 0.1
			draw_line(prev, next, Color(_base_color.r, _base_color.g, _base_color.b, alpha), 1.2 - s * 0.2, true)
			prev = next

	# Annoyed face
	var le := Vector2(-_eye_size * 0.7, -_eye_size * 0.5)
	var re := Vector2(-_eye_size * 0.7, _eye_size * 0.5)
	# Squinting annoyed eyes
	for ep in [le, re]:
		var eye_pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var a: float = TAU * i / 10.0
			eye_pts.append(ep + Vector2(cos(a) * _eye_size, sin(a) * _eye_size * 0.5))
		draw_colored_polygon(eye_pts, Color(0.95, 0.9, 0.95, 0.9))
		draw_circle(ep, _eye_size * 0.4, Color(0.15, 0.0, 0.1, 0.9))
	# Angry brows angled down
	draw_line(le + Vector2(-_eye_size, -_eye_size * 0.8), le + Vector2(_eye_size, -_eye_size * 0.3), Color(0.3, 0.1, 0.2, 0.8), 1.5, true)
	draw_line(re + Vector2(-_eye_size, -_eye_size * 0.3), re + Vector2(_eye_size, -_eye_size * 0.8), Color(0.3, 0.1, 0.2, 0.8), 1.5, true)
	# Pursed grumpy mouth
	var mp := Vector2(_radius * 0.25, 0)
	draw_line(mp + Vector2(0, -2), mp + Vector2(1.5, 0), Color(0.2, 0.05, 0.1, 0.8), 1.5, true)
	draw_line(mp + Vector2(1.5, 0), mp + Vector2(0, 2), Color(0.2, 0.05, 0.1, 0.8), 1.5, true)

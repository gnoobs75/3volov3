extends Node2D
## Large "gold mine" harvest zone — dead titan body.
## Provides both biomass and gene fragments. Max 4 simultaneous workers.

signal depleted(node: Node2D)

var biomass_remaining: int = 2000
var genes_remaining: int = 500
var max_biomass: int = 2000
var max_genes: int = 500
const MAX_WORKERS: int = 4
var current_workers: int = 0
var _time: float = 0.0
var _bone_angles: Array[float] = []

# Tendril state
var _tendril_phases: Array[float] = []
const NUM_TENDRILS: int = 4

func _ready() -> void:
	# Generate bone/rib decoration angles
	for i in range(6):
		_bone_angles.append(TAU * float(i) / 6.0 + randf_range(-0.2, 0.2))
	# Generate tendril start phases
	for i in range(NUM_TENDRILS):
		_tendril_phases.append(randf() * TAU)
	# Add collision area for detection
	var area := Area2D.new()
	area.name = "TitanArea"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 50.0
	shape.shape = circle
	area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 0
	add_child(area)

func can_add_worker() -> bool:
	return current_workers < MAX_WORKERS and not is_depleted()

func add_worker() -> void:
	current_workers += 1

func remove_worker() -> void:
	current_workers = maxi(current_workers - 1, 0)

func harvest(amount: int) -> Dictionary:
	## Returns {biomass: int, genes: int} actually harvested
	var bio_actual: int = mini(amount, biomass_remaining)
	biomass_remaining -= bio_actual
	# Gene fragments at ~25% rate of biomass
	var gene_amount: int = maxi(amount / 4, 1)
	var gene_actual: int = mini(gene_amount, genes_remaining)
	genes_remaining -= gene_actual
	if biomass_remaining <= 0 and genes_remaining <= 0:
		depleted.emit(self)
	queue_redraw()
	return {"biomass": bio_actual, "genes": gene_actual}

func is_depleted() -> bool:
	return biomass_remaining <= 0 and genes_remaining <= 0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _is_on_screen() -> bool:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return true
	var cam_pos: Vector2 = camera.global_position
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: float = camera.zoom.x if camera.zoom.x > 0 else 1.0
	var half_view: Vector2 = vp_size / (2.0 * zoom) + Vector2(120, 120)
	var diff: Vector2 = (global_position - cam_pos).abs()
	return diff.x < half_view.x and diff.y < half_view.y

func _draw() -> void:
	if not _is_on_screen():
		return
	var fill: float = float(biomass_remaining + genes_remaining) / float(max_biomass + max_genes)
	if fill <= 0:
		# Draw depleted husk
		draw_circle(Vector2.ZERO, 30.0, Color(0.1, 0.08, 0.06, 0.3))
		return

	# Resource aura ring — shrinks as resources deplete
	var aura_radius: float = 90.0 * fill + 20.0
	var aura_pulse: float = 0.5 + 0.5 * sin(_time * 0.8)
	var aura_alpha: float = (0.04 + 0.04 * aura_pulse) * fill
	draw_arc(Vector2.ZERO, aura_radius, 0, TAU, 48, Color(0.6, 0.35, 0.1, aura_alpha), 2.5)
	draw_arc(Vector2.ZERO, aura_radius + 4.0, 0, TAU, 48, Color(0.5, 0.3, 0.1, aura_alpha * 0.4), 1.0)

	# Large dramatic pulsing glow
	var glow_pulse: float = 1.0 + 0.1 * sin(_time * 1.2)
	var glow_alpha: float = 0.06 + 0.06 * sin(_time * 0.9)
	draw_circle(Vector2.ZERO, 80.0 * glow_pulse, Color(0.6, 0.35, 0.15, glow_alpha * fill))
	draw_circle(Vector2.ZERO, 55.0 * glow_pulse, Color(0.5, 0.3, 0.1, glow_alpha * 0.7 * fill))

	# Slowly rotating organic tendrils (4 tendrils, sine-driven)
	for ti in range(NUM_TENDRILS):
		var base_angle: float = TAU * float(ti) / float(NUM_TENDRILS) + _time * 0.15
		var phase: float = _tendril_phases[ti]
		# Draw tendril as chain of 6 segments with sine displacement
		var prev_pt: Vector2 = Vector2(cos(base_angle), sin(base_angle)) * 30.0 * (0.5 + fill * 0.5)
		for si in range(6):
			var seg_t: float = float(si + 1) / 6.0
			var seg_dist: float = (30.0 + seg_t * 35.0) * (0.5 + fill * 0.5)
			var wave: float = sin(_time * 1.5 + phase + seg_t * PI * 2.0) * 8.0 * seg_t
			var seg_angle: float = base_angle + wave * 0.02
			var seg_pt: Vector2 = Vector2(cos(seg_angle), sin(seg_angle)) * seg_dist
			# Perpendicular displacement for organic wave
			var perp: Vector2 = Vector2(-sin(seg_angle), cos(seg_angle))
			seg_pt += perp * wave
			var seg_alpha: float = (0.3 - seg_t * 0.2) * fill
			var seg_width: float = (2.5 - seg_t * 1.5) * (0.5 + fill * 0.5)
			draw_line(prev_pt, seg_pt, Color(0.45, 0.25, 0.12, seg_alpha), maxf(seg_width, 0.5))
			prev_pt = seg_pt

	# Outer glow (original)
	draw_circle(Vector2.ZERO, 70.0, Color(0.5, 0.3, 0.1, 0.04))

	# Main body (irregular blob)
	var pts := PackedVector2Array()
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		var r: float = 35.0 + sin(angle * 3.0 + _time * 0.2) * 8.0 + sin(angle * 5.0) * 5.0
		r *= (0.5 + fill * 0.5)
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	draw_colored_polygon(pts, Color(0.35, 0.2, 0.1, 0.6 + fill * 0.4))

	# Bone/rib structures
	for ba in _bone_angles:
		var start: Vector2 = Vector2(cos(ba), sin(ba)) * 10.0
		var end: Vector2 = Vector2(cos(ba), sin(ba)) * (25.0 + fill * 10.0)
		draw_line(start, end, Color(0.7, 0.65, 0.5, 0.5 * fill), 2.0)

	# Gene fragment sparkles
	if genes_remaining > 0:
		var gene_fill: float = float(genes_remaining) / float(max_genes)
		for i in range(3):
			var angle: float = _time * 0.5 + TAU * float(i) / 3.0
			var sp: Vector2 = Vector2(cos(angle) * 15.0, sin(angle) * 15.0)
			draw_circle(sp, 2.5, Color(0.8, 0.4, 1.0, 0.4 * gene_fill))

	# Resource amount indicator
	var font: Font = UIConstants.get_mono_font()
	var label: String = "%d / %d" % [biomass_remaining, genes_remaining]
	var ls: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_TINY)
	draw_string(font, Vector2(-ls.x * 0.5, 50.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, Color(0.7, 0.6, 0.4, 0.6))

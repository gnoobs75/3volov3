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

func _ready() -> void:
	# Generate bone/rib decoration angles
	for i in range(6):
		_bone_angles.append(TAU * float(i) / 6.0 + randf_range(-0.2, 0.2))
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

func _draw() -> void:
	var fill: float = float(biomass_remaining + genes_remaining) / float(max_biomass + max_genes)
	if fill <= 0:
		# Draw depleted husk
		draw_circle(Vector2.ZERO, 30.0, Color(0.1, 0.08, 0.06, 0.3))
		return

	# Outer glow
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

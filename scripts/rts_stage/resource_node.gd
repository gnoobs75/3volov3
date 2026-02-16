extends Node2D
## Small scattered biomolecule harvest point.
## Workers gather biomass from these nodes until depleted.

signal depleted(node: Node2D)

var biomass_remaining: int = 200
var max_biomass: int = 200
var _time: float = 0.0
var _pulse_offset: float = 0.0

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
	queue_redraw()

func _draw() -> void:
	if biomass_remaining <= 0:
		return
	var fill: float = float(biomass_remaining) / float(max_biomass)
	var pulse: float = 1.0 + 0.15 * sin(_time * 2.0 + _pulse_offset)
	var radius: float = 8.0 + 6.0 * fill

	# Glow
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

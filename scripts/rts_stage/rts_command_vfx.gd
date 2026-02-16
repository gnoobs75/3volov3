extends Node2D
## Draws command feedback VFX: expanding rings at move/attack targets.
## Managed by stage manager, pooled indicators.

var _indicators: Array = []  # [{pos, time, type, color}]
const MAX_INDICATORS: int = 8
const INDICATOR_LIFE: float = 0.8

func add_move_indicator(world_pos: Vector2) -> void:
	_add_indicator(world_pos, "move", Color(0.2, 1.0, 0.4, 0.8))

func add_attack_indicator(world_pos: Vector2) -> void:
	_add_indicator(world_pos, "attack", Color(1.0, 0.3, 0.2, 0.8))

func add_gather_indicator(world_pos: Vector2) -> void:
	_add_indicator(world_pos, "gather", Color(0.3, 0.8, 1.0, 0.8))

func _add_indicator(pos: Vector2, type: String, color: Color) -> void:
	_indicators.append({"pos": pos, "time": 0.0, "type": type, "color": color})
	if _indicators.size() > MAX_INDICATORS:
		_indicators.pop_front()

func _process(delta: float) -> void:
	var had_indicators: bool = not _indicators.is_empty()
	var i: int = _indicators.size() - 1
	while i >= 0:
		_indicators[i]["time"] += delta
		if _indicators[i]["time"] >= INDICATOR_LIFE:
			_indicators.remove_at(i)
		i -= 1
	if had_indicators or not _indicators.is_empty():
		queue_redraw()

func _draw() -> void:
	for ind in _indicators:
		var t: float = ind["time"] / INDICATOR_LIFE
		var alpha: float = 1.0 - t
		var pos: Vector2 = ind["pos"]
		var c: Color = ind["color"]
		match ind["type"]:
			"move":
				# Expanding green circle with crosshair
				var r: float = 5.0 + t * 15.0
				draw_arc(pos, r, 0, TAU, 16, Color(c.r, c.g, c.b, alpha * 0.6), 1.5)
				# Small crosshair
				var cross_size: float = 4.0 * (1.0 - t)
				draw_line(pos + Vector2(-cross_size, 0), pos + Vector2(cross_size, 0), Color(c.r, c.g, c.b, alpha * 0.8), 1.0)
				draw_line(pos + Vector2(0, -cross_size), pos + Vector2(0, cross_size), Color(c.r, c.g, c.b, alpha * 0.8), 1.0)
			"attack":
				# Expanding red X with ring
				var r: float = 5.0 + t * 20.0
				draw_arc(pos, r, 0, TAU, 12, Color(c.r, c.g, c.b, alpha * 0.5), 2.0)
				var x_size: float = 5.0 * (1.0 - t * 0.5)
				draw_line(pos + Vector2(-x_size, -x_size), pos + Vector2(x_size, x_size), Color(c.r, c.g, c.b, alpha * 0.8), 1.5)
				draw_line(pos + Vector2(x_size, -x_size), pos + Vector2(-x_size, x_size), Color(c.r, c.g, c.b, alpha * 0.8), 1.5)
			"gather":
				# Pulsing blue circle
				var r: float = 8.0 + t * 10.0
				draw_arc(pos, r, 0, TAU, 16, Color(c.r, c.g, c.b, alpha * 0.5), 1.5)
				# Arrow pointing down
				var arrow_y: float = 3.0 * (1.0 - t)
				draw_line(pos + Vector2(0, -arrow_y - 3), pos + Vector2(0, arrow_y), Color(c.r, c.g, c.b, alpha * 0.7), 1.5)

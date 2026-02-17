extends Node2D
## Floating damage/heal numbers that rise and fade. Drawn in world space.
## Added as child of rts_stage_manager with z_index=8.

const MAX_NUMBERS: int = 50
const LIFETIME: float = 0.6
const RISE_SPEED: float = 40.0

var _numbers: Array = []

func _ready() -> void:
	z_index = 8

func add_damage(pos: Vector2, value: int, is_crit: bool = false) -> void:
	if _numbers.size() >= MAX_NUMBERS:
		_numbers.pop_front()
	_numbers.append({
		"pos": pos,
		"value": value,
		"time": 0.0,
		"color": Color(1.0, 0.9, 0.1) if is_crit else Color(1.0, 0.3, 0.1),
		"is_crit": is_crit,
		"offset_x": randf_range(-8.0, 8.0),
		"text": str(value),
	})

func add_heal(pos: Vector2, value: int) -> void:
	if _numbers.size() >= MAX_NUMBERS:
		_numbers.pop_front()
	_numbers.append({
		"pos": pos,
		"value": value,
		"time": 0.0,
		"color": Color(0.2, 1.0, 0.4),
		"is_crit": false,
		"offset_x": randf_range(-8.0, 8.0),
		"text": "+" + str(value),
	})

func _process(delta: float) -> void:
	var changed: bool = false
	for i in range(_numbers.size() - 1, -1, -1):
		_numbers[i]["time"] += delta
		if _numbers[i]["time"] >= LIFETIME:
			_numbers.remove_at(i)
		changed = true
	if changed:
		queue_redraw()

func _draw() -> void:
	for num in _numbers:
		var t: float = num["time"] / LIFETIME
		var alpha: float = 1.0 - t * t
		var y_offset: float = -t * RISE_SPEED
		var draw_pos: Vector2 = num["pos"] + Vector2(num["offset_x"], y_offset)
		var color: Color = num["color"]
		color.a = alpha
		var font_size: int = 12 if num["is_crit"] else 9
		draw_string(ThemeDB.fallback_font, draw_pos, num["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

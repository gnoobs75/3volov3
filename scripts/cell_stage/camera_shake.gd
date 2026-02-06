extends Camera2D
## Camera shake utility. Attach this script to a Camera2D node.
## Call shake() with intensity and duration to trigger screen shake.
## Supports multiple overlapping shakes (uses strongest active).

var _shakes: Array = []  # [{intensity, duration, elapsed}]

func shake(intensity: float, duration: float = 0.3) -> void:
	_shakes.append({"intensity": intensity, "duration": duration, "elapsed": 0.0})

func _process(delta: float) -> void:
	var max_intensity: float = 0.0
	var alive: Array = []
	for s in _shakes:
		s.elapsed += delta
		if s.elapsed < s.duration:
			# Decay over time
			var t: float = 1.0 - s.elapsed / s.duration
			var current: float = s.intensity * t * t  # Quadratic falloff
			max_intensity = maxf(max_intensity, current)
			alive.append(s)
	_shakes = alive

	if max_intensity > 0.01:
		offset = Vector2(
			randf_range(-max_intensity, max_intensity),
			randf_range(-max_intensity, max_intensity)
		)
	else:
		offset = offset.lerp(Vector2.ZERO, delta * 10.0)

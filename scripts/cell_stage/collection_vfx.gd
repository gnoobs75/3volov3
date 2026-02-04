extends Node2D
## Spawned at collection point: burst of particles, expanding ring, floating text.
## Self-destructs after animation completes.

var item_name: String = ""
var item_color: Color = Color.WHITE
var is_rare: bool = false
var _time: float = 0.0
var _duration: float = 1.2
var _particles: Array = []  # Array of {pos, vel, color, size, life}

func setup(name: String, color: Color, rare: bool = false) -> void:
	item_name = name
	item_color = color
	is_rare = rare

func _ready() -> void:
	# Spawn burst particles
	var count: int = 12 if not is_rare else 24
	for i in range(count):
		var angle: float = TAU * i / count + randf_range(-0.2, 0.2)
		var speed: float = randf_range(40.0, 120.0) if not is_rare else randf_range(60.0, 180.0)
		_particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"color": item_color.lerp(Color.WHITE, randf_range(0.0, 0.4)),
			"size": randf_range(1.5, 3.5),
			"life": 1.0,
		})

func _process(delta: float) -> void:
	_time += delta
	for p in _particles:
		p.pos += p.vel * delta
		p.vel *= 0.94  # Drag
		p.life -= delta * 1.5
	if _time >= _duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var progress: float = _time / _duration
	var alpha: float = 1.0 - progress

	# Expanding ring
	var ring_r: float = 10.0 + progress * 50.0
	var ring_a: float = alpha * 0.6
	draw_arc(Vector2.ZERO, ring_r, 0, TAU, 24, Color(item_color, ring_a), 2.0, true)
	if is_rare:
		# Second golden ring
		var ring_r2: float = 5.0 + progress * 65.0
		draw_arc(Vector2.ZERO, ring_r2, 0, TAU, 24, Color(1.0, 0.9, 0.3, ring_a * 0.5), 1.5, true)

	# Central flash
	if _time < 0.3:
		var flash_a: float = (1.0 - _time / 0.3) * 0.8
		draw_circle(Vector2.ZERO, 8.0 + _time * 30.0, Color(item_color.r, item_color.g, item_color.b, flash_a))

	# Particles
	for p in _particles:
		if p.life > 0:
			var pa: float = clampf(p.life, 0.0, 1.0)
			var pc: Color = p.color
			pc.a = pa * 0.9
			draw_circle(p.pos, p.size * pa, pc)
			# Sparkle trail
			if is_rare:
				draw_circle(p.pos - p.vel.normalized() * 2.0, p.size * 0.4 * pa, Color(1, 1, 0.8, pa * 0.4))

	# Floating text
	if item_name != "":
		var text_y: float = -15.0 - _time * 25.0
		var text_alpha: float = alpha
		var font := ThemeDB.fallback_font
		var fsize: int = 10 if not is_rare else 12
		var tw: float = font.get_string_size(item_name, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x
		# Text shadow
		draw_string(font, Vector2(-tw * 0.5 + 1, text_y + 1), item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0, 0, 0, text_alpha * 0.5))
		# Text
		var text_color := Color(item_color.r, item_color.g, item_color.b, text_alpha)
		if is_rare:
			text_color = text_color.lerp(Color(1.0, 1.0, 0.5, text_alpha), 0.3)
		draw_string(font, Vector2(-tw * 0.5, text_y), item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, text_color)

	# "+" energy text slightly below
	if _time < 0.6:
		var ea: float = 1.0 - _time / 0.6
		var font2 := ThemeDB.fallback_font
		var etxt: String = "+FUEL"
		var etw: float = font2.get_string_size(etxt, HORIZONTAL_ALIGNMENT_CENTER, -1, 8).x
		draw_string(font2, Vector2(-etw * 0.5, -5.0 - _time * 10.0), etxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 1.0, 0.6, ea * 0.7))

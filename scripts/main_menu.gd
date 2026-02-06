extends Control
## Main menu with procedural animated background (floating cells).

var _time: float = 0.0
var _bg_cells: Array[Dictionary] = []

func _ready() -> void:
	$VBoxContainer/StartButton.pressed.connect(_on_start)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit)
	# Music toggle
	var music_toggle: CheckButton = $VBoxContainer/MusicToggle
	music_toggle.button_pressed = AudioManager.is_using_music_files()
	music_toggle.toggled.connect(_on_music_toggle)
	# Generate background decorative cells
	for i in range(20):
		_bg_cells.append({
			"pos": Vector2(randf_range(0, 1280), randf_range(0, 720)),
			"radius": randf_range(5.0, 25.0),
			"speed": Vector2(randf_range(-15, 15), randf_range(-10, 10)),
			"color": Color(randf_range(0.1, 0.3), randf_range(0.3, 0.7), randf_range(0.5, 1.0), randf_range(0.05, 0.15)),
			"phase": randf() * TAU,
		})

func _process(delta: float) -> void:
	_time += delta
	for c in _bg_cells:
		c.pos += c.speed * delta
		if c.pos.x < -30: c.pos.x = 1310
		if c.pos.x > 1310: c.pos.x = -30
		if c.pos.y < -30: c.pos.y = 750
		if c.pos.y > 750: c.pos.y = -30
	queue_redraw()

func _draw() -> void:
	# Draw background cells behind the UI
	for c in _bg_cells:
		var r: float = c.radius + sin(_time * 1.5 + c.phase) * 2.0
		var col: Color = c.color
		# Outer glow
		draw_circle(c.pos, r * 2.0, Color(col.r, col.g, col.b, col.a * 0.3))
		# Body
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(12):
			var angle: float = TAU * i / 12.0
			var wobble: float = sin(_time * 2.0 + c.phase + i * 0.8) * 1.5
			pts.append(c.pos + Vector2(cos(angle) * (r + wobble), sin(angle) * (r + wobble)))
		draw_colored_polygon(pts, col)

func _on_start() -> void:
	GameManager.reset_stats()
	GameManager.go_to_intro()

func _on_quit() -> void:
	get_tree().quit()

func _on_music_toggle(enabled: bool) -> void:
	AudioManager.set_use_music_files(enabled)

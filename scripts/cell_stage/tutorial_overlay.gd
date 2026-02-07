extends Control
## First-play tutorial: animated key prompts that fade in, hold, then fade out.
## Shown once per session via GameManager.tutorial_shown flag.

var _time: float = 0.0
var _total_duration: float = 25.0
var _fade_in: float = 1.5
var _hold_until: float = 20.0  # Start fading out here
var _fade_out: float = 5.0  # Duration of fade-out

var _prompts: Array = [
	{"keys": "WASD", "label": "Move / Thrust", "delay": 0.0},
	{"keys": "SHIFT", "label": "Sprint (costs more energy)", "delay": 2.0},
	{"keys": "LMB", "label": "Tractor Beam (collect)", "delay": 4.0},
	{"keys": "RMB", "label": "Jet Stream (push away)", "delay": 6.0},
	{"keys": "E", "label": "Fire Toxin (attack)", "delay": 8.0},
	{"keys": "Q", "label": "Reproduce (costs energy)", "delay": 10.0},
	{"keys": "F", "label": "Metabolize (restore energy)", "delay": 12.0},
	{"keys": "TAB", "label": "CRISPR Gene Editor", "delay": 14.0},
]

func _process(delta: float) -> void:
	_time += delta
	if _time > _total_duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	# Global alpha: fade in then fade out
	var global_alpha: float = 1.0
	if _time < _fade_in:
		global_alpha = _time / _fade_in
	elif _time > _hold_until:
		global_alpha = clampf(1.0 - (_time - _hold_until) / _fade_out, 0.0, 1.0)

	# Title
	var title := "CONTROLS"
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	var base_x: float = vp.x * 0.5 - 140.0
	var base_y: float = vp.y * 0.55

	# Dim pill behind all prompts
	var pill_h: float = _prompts.size() * 28.0 + 50.0
	draw_rect(Rect2(base_x - 20, base_y - 35, 320, pill_h), Color(0.02, 0.04, 0.08, 0.6 * global_alpha))

	draw_string(font, Vector2(base_x, base_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.4, 0.8, 1.0, 0.9 * global_alpha))

	# Draw each prompt with staggered fade-in
	for i in range(_prompts.size()):
		var p: Dictionary = _prompts[i]
		var prompt_alpha: float = clampf((_time - p.delay) / 0.8, 0.0, 1.0) * global_alpha
		if prompt_alpha <= 0.01:
			continue

		var y: float = base_y + 30.0 + i * 28.0

		# Key box
		var key_text: String = p.keys
		var key_w: float = font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12.0
		draw_rect(Rect2(base_x, y - 14, key_w, 20), Color(0.15, 0.3, 0.5, 0.7 * prompt_alpha))
		draw_string(font, Vector2(base_x + 6, y), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.95, 1.0, prompt_alpha))

		# Label
		draw_string(font, Vector2(base_x + key_w + 10, y), p.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.75, 0.85, 0.8 * prompt_alpha))

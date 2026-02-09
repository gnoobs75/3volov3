extends Control
## Tutorial overlay: controls panel anchored at bottom-right of the play area.
## Large, translucent, and easy to read. Stays visible for 20 seconds then fades.

var _time: float = 0.0
var _alpha: float = 0.0

const HOLD_DURATION: float = 20.0
const FADE_DURATION: float = 2.0

var _prompts: Array = [
	{"keys": "WASD", "label": "Move / Thrust"},
	{"keys": "SHIFT", "label": "Sprint (costs energy)"},
	{"keys": "LMB", "label": "Tractor Beam (collect)"},
	{"keys": "RMB", "label": "Jet Stream (push away)"},
	{"keys": "E", "label": "Fire Toxin (attack)"},
	{"keys": "Q", "label": "Reproduce (costs energy)"},
	{"keys": "F", "label": "Metabolize (restore energy)"},
	{"keys": "TAB", "label": "CRISPR Gene Editor"},
]

func _process(delta: float) -> void:
	_time += delta

	# Fade in quickly
	if _time < 1.0:
		_alpha = move_toward(_alpha, 1.0, delta * 2.5)
	# Hold
	elif _time < HOLD_DURATION:
		_alpha = 1.0
	# Fade out
	elif _time < HOLD_DURATION + FADE_DURATION:
		_alpha = move_toward(_alpha, 0.0, delta / FADE_DURATION)
	else:
		queue_free()
		return

	queue_redraw()

func _draw() -> void:
	if _alpha <= 0.01:
		return

	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	# Panel sizing — generous and readable
	var panel_w: float = 380.0
	var line_h: float = 32.0
	var panel_h: float = _prompts.size() * line_h + 52.0
	var margin: float = 16.0

	# Anchor bottom-right of the viewport
	var px: float = vp.x - panel_w - margin
	var py: float = vp.y - panel_h - margin

	# Background — translucent dark
	draw_rect(Rect2(px, py, panel_w, panel_h), Color(0.02, 0.04, 0.08, 0.55 * _alpha))
	# Top/bottom accent borders
	draw_rect(Rect2(px, py, panel_w, 1), Color(0.4, 0.7, 1.0, 0.35 * _alpha))
	draw_rect(Rect2(px, py + panel_h - 1, panel_w, 1), Color(0.4, 0.7, 1.0, 0.35 * _alpha))

	# Title
	var title_fs: int = 22
	draw_string(font, Vector2(px + 14, py + 28), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs, Color(0.4, 0.8, 1.0, 0.95 * _alpha))

	# Each prompt row
	var key_fs: int = 16
	var label_fs: int = 15
	for i in range(_prompts.size()):
		var p: Dictionary = _prompts[i]
		# Stagger fade-in on first appearance
		var row_alpha: float = clampf((_time - 0.2 - i * 0.15) / 0.5, 0.0, 1.0) * _alpha
		if row_alpha <= 0.01:
			continue

		var ry: float = py + 46.0 + i * line_h

		# Key box
		var key_text: String = p.keys
		var key_w: float = font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs).x + 14.0
		draw_rect(Rect2(px + 14, ry - 16, key_w, 24), Color(0.15, 0.3, 0.5, 0.7 * row_alpha))
		draw_string(font, Vector2(px + 21, ry + 2), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_fs, Color(0.7, 0.95, 1.0, row_alpha))

		# Label
		draw_string(font, Vector2(px + 21 + key_w + 10, ry + 2), p.label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs, Color(0.5, 0.75, 0.85, 0.85 * row_alpha))

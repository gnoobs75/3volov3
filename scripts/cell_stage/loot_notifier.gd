extends Control
## Floating loot notifications — shows collection progress in corner, fades quickly.

const MAX_NOTIFICATIONS: int = 6
const NOTIFICATION_LIFETIME: float = 2.0
const FADE_START: float = 1.2  # Start fading after this time
const SLIDE_SPEED: float = 30.0
const NOTIFICATION_HEIGHT: float = 24.0

# Category display info
const CATEGORY_INFO: Dictionary = {
	"nucleotides": {"label": "Nucleotides", "icon": "⚛", "color": Color(1.0, 0.9, 0.1)},
	"monosaccharides": {"label": "Sugars", "icon": "◇", "color": Color(0.9, 0.7, 0.2)},
	"amino_acids": {"label": "Amino Acids", "icon": "⬡", "color": Color(0.6, 0.9, 0.4)},
	"coenzymes": {"label": "Coenzymes", "icon": "◈", "color": Color(0.4, 0.6, 1.0)},
	"lipids": {"label": "Lipids", "icon": "◉", "color": Color(0.3, 0.7, 0.9)},
	"nucleotide_bases": {"label": "Nucleobases", "icon": "◆", "color": Color(0.9, 0.3, 0.3)},
	"organic_acids": {"label": "Organic Acids", "icon": "◊", "color": Color(0.8, 0.5, 0.1)},
	"organelles": {"label": "Organelles", "icon": "★", "color": Color(0.2, 0.9, 0.3)},
}

var _notifications: Array = []  # [{text, color, life, y_offset, icon}]
var _last_category: String = ""
var _combo_count: int = 0
var _combo_timer: float = 0.0

func _ready() -> void:
	GameManager.biomolecule_collected.connect(_on_biomolecule_collected)

func _on_biomolecule_collected(item: Dictionary) -> void:
	var cat: String = item.get("category", "")
	if cat == "":
		return

	# Map singular to plural key
	var inv_key: String = _get_inv_key(cat)
	if inv_key == "":
		return

	var count: int = GameManager.inventory[inv_key].size()
	var max_count: int = GameManager.MAX_VIAL
	var info: Dictionary = CATEGORY_INFO.get(inv_key, {"label": inv_key, "icon": "●", "color": Color.WHITE})

	# Build notification text
	var remaining: int = max_count - count
	var text: String = ""
	if remaining <= 0:
		text = "%s FULL! EVOLVE!" % info.label
	elif remaining <= 3:
		text = "%s %d/%d — %d more!" % [info.label, count, max_count, remaining]
	else:
		text = "%s %d/%d" % [info.label, count, max_count]

	# Combo detection - same category in quick succession
	if inv_key == _last_category and _combo_timer > 0:
		_combo_count += 1
		if _combo_count >= 3:
			text += " 🔥"
	else:
		_combo_count = 1
	_last_category = inv_key
	_combo_timer = 1.5

	# Add notification, remove oldest if too many
	_notifications.append({
		"text": text,
		"color": info.color,
		"icon": info.icon,
		"life": NOTIFICATION_LIFETIME,
		"y_offset": 0.0,
		"scale": 1.2,  # Start slightly larger
		"is_full": remaining <= 0,
	})

	if _notifications.size() > MAX_NOTIFICATIONS:
		_notifications.pop_front()

func _get_inv_key(cat: String) -> String:
	match cat:
		"nucleotide": return "nucleotides"
		"monosaccharide": return "monosaccharides"
		"amino_acid": return "amino_acids"
		"coenzyme": return "coenzymes"
		"lipid": return "lipids"
		"nucleotide_base": return "nucleotide_bases"
		"organic_acid": return "organic_acids"
	return ""

func _process(delta: float) -> void:
	_combo_timer -= delta

	# Update notifications
	var alive: Array = []
	for n in _notifications:
		n.life -= delta
		n.y_offset += SLIDE_SPEED * delta
		n.scale = lerpf(n.scale, 1.0, delta * 8.0)  # Shrink to normal size
		if n.life > 0:
			alive.append(n)
	_notifications = alive

	queue_redraw()

func _draw() -> void:
	if _notifications.is_empty():
		return

	var font := UIConstants.get_display_font()
	var start_y: float = 10.0

	for i in range(_notifications.size()):
		var n: Dictionary = _notifications[i]
		var alpha: float = 1.0
		if n.life < FADE_START:
			alpha = n.life / FADE_START

		var y: float = start_y + i * NOTIFICATION_HEIGHT - n.y_offset * 0.3
		var col: Color = n.color
		col.a = alpha

		# Background pill
		var text: String = "%s %s" % [n.icon, n.text]
		var font_size: int = int(13 * n.scale)
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		var bg_rect := Rect2(8, y - 14, text_width + 16, 20)
		var bg_color := Color(0.0, 0.0, 0.0, 0.5 * alpha)
		if n.is_full:
			bg_color = Color(0.1, 0.3, 0.1, 0.7 * alpha)
		draw_rect(bg_rect, bg_color)

		# Glow for "full" notifications
		if n.is_full:
			draw_rect(Rect2(bg_rect.position.x - 2, bg_rect.position.y - 2, bg_rect.size.x + 4, bg_rect.size.y + 4), Color(col.r, col.g, col.b, 0.3 * alpha))

		# Text with slight shadow
		draw_string(font, Vector2(17, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, alpha * 0.5))
		draw_string(font, Vector2(16, y - 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)

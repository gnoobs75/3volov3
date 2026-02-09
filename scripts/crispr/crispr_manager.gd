extends Control
## CRISPR Editor: Visual gene splicing with animated DNA helix background.
## Color-coded viability, splice VFX, and confirmation for risky splices.

signal splice_applied(new_traits: Dictionary)

@onready var gene_scroll: ScrollContainer = $PanelContainer/VBoxContainer/GeneScroll
@onready var gene_cards_container: VBoxContainer = $PanelContainer/VBoxContainer/GeneScroll/GeneCards
@onready var splice_slot_1: Button = $PanelContainer/VBoxContainer/SpliceArea/Slot1
@onready var splice_slot_2: Button = $PanelContainer/VBoxContainer/SpliceArea/Slot2
@onready var viability_label: Label = $PanelContainer/VBoxContainer/ViabilityLabel
@onready var preview_label: Label = $PanelContainer/VBoxContainer/PreviewLabel
@onready var inject_button: Button = $PanelContainer/VBoxContainer/InjectButton

var selected_gene_1: String = ""
var selected_gene_2: String = ""
var current_splice_result: Dictionary = {}

# Visual state
var _time: float = 0.0
var _flash_timer: float = 0.0
var _flash_color: Color = Color.WHITE
var _awaiting_confirm: bool = false

# Card state
var _card_data: Array = []  # [{id, type, function, trait_impact, node}]
var _hovered_card: Control = null
var _selected_card: Control = null

# Trait category colors
const TRAIT_COLORS: Dictionary = {
	"speed": Color(0.3, 0.9, 0.9),
	"movement": Color(0.3, 0.9, 0.9),
	"energy_efficiency": Color(1.0, 0.9, 0.2),
	"energy_processing": Color(1.0, 0.9, 0.2),
	"armor": Color(0.9, 0.5, 0.2),
	"damage_reduction": Color(0.9, 0.5, 0.2),
	"defense": Color(0.9, 0.5, 0.2),
	"offspring_survival": Color(0.9, 0.4, 0.7),
	"reproduction": Color(0.9, 0.4, 0.7),
	"detection_range": Color(0.4, 0.6, 1.0),
	"perception": Color(0.4, 0.6, 1.0),
	"sensing": Color(0.4, 0.6, 1.0),
	"hostility_damage": Color(1.0, 0.3, 0.3),
	"offensive_capability": Color(1.0, 0.3, 0.3),
	"hunt_success": Color(1.0, 0.3, 0.3),
	"stealth": Color(0.6, 0.3, 0.9),
	"invisibility": Color(0.6, 0.3, 0.9),
	"self_healing": Color(0.3, 1.0, 0.5),
	"mutation_resistance": Color(0.7, 0.7, 0.7),
}

func _ready() -> void:
	_populate_gene_cards()
	inject_button.pressed.connect(_on_inject)
	inject_button.disabled = true

func _process(delta: float) -> void:
	_time += delta
	if _flash_timer > 0:
		_flash_timer -= delta
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size

	# Dim background
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.0, 0.02, 0.05, 0.7))

	# Animated DNA double helix strands
	_draw_helix(vp)

	# Tech grid overlay (subtle)
	var grid_alpha: float = 0.04
	for gx in range(0, int(vp.x), 40):
		draw_line(Vector2(gx, 0), Vector2(gx, vp.y), Color(0.2, 0.5, 0.7, grid_alpha), 0.5)
	for gy in range(0, int(vp.y), 40):
		draw_line(Vector2(0, gy), Vector2(vp.x, gy), Color(0.2, 0.5, 0.7, grid_alpha), 0.5)

	# Flash overlay for splice feedback
	if _flash_timer > 0:
		var flash_a: float = _flash_timer * 0.6
		draw_rect(Rect2(0, 0, vp.x, vp.y), Color(_flash_color.r, _flash_color.g, _flash_color.b, flash_a))

func _draw_helix(vp: Vector2) -> void:
	var cx: float = vp.x * 0.5
	var helix_amplitude: float = vp.x * 0.3
	var phase_speed: float = _time * 0.8
	var num_rungs: int = 20
	var y_spacing: float = vp.y / float(num_rungs)

	for i in range(num_rungs + 1):
		var y: float = i * y_spacing
		var phase: float = phase_speed + float(i) * 0.35
		var sx: float = sin(phase) * helix_amplitude
		var depth: float = cos(phase) * 0.5 + 0.5

		# Left strand position
		var lx: float = cx + sx
		# Right strand position (opposite phase)
		var rx: float = cx - sx

		var strand_alpha: float = 0.12 + 0.08 * depth
		var strand_color := Color(0.2, 0.5, 0.8, strand_alpha)
		var rung_color := Color(0.3, 0.7, 0.5, strand_alpha * 0.7)

		# Backbone connections to next rung
		if i < num_rungs:
			var ny: float = (i + 1) * y_spacing
			var np: float = phase_speed + float(i + 1) * 0.35
			var nlx: float = cx + sin(np) * helix_amplitude
			var nrx: float = cx - sin(np) * helix_amplitude
			draw_line(Vector2(lx, y), Vector2(nlx, ny), strand_color, 2.0, true)
			draw_line(Vector2(rx, y), Vector2(nrx, ny), strand_color, 2.0, true)

		# Rung (base pair) connecting the strands
		if depth > 0.3:
			draw_line(Vector2(lx, y), Vector2(rx, y), rung_color, 1.5, true)

		# Node dots at strand connections
		var dot_size: float = 2.0 + depth * 2.0
		draw_circle(Vector2(lx, y), dot_size, Color(0.3, 0.6, 0.9, strand_alpha))
		draw_circle(Vector2(rx, y), dot_size, Color(0.3, 0.6, 0.9, strand_alpha))

## --- Gene Card System ---

func _populate_gene_cards() -> void:
	_card_data.clear()
	for child in gene_cards_container.get_children():
		child.queue_free()

	for gene in BiologyLoader.genes:
		_add_gene_card(gene, "gene")
	for protein in BiologyLoader.proteins:
		_add_gene_card(protein, "protein")

func _add_gene_card(component: Dictionary, type: String) -> void:
	var card := Control.new()
	card.custom_minimum_size = Vector2(0, 52)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var comp_id: String = component.get("id", "?")
	var comp_func: String = component.get("function", "Unknown")
	var impact: Dictionary = component.get("trait_impact", {})

	var data := {
		"id": comp_id,
		"type": type,
		"function": comp_func,
		"trait_impact": impact,
		"node": card,
		"hovered": false,
		"selected": false,
	}
	_card_data.append(data)

	# Store index for lookup
	var idx: int = _card_data.size() - 1
	card.set_meta("card_index", idx)

	# Connect input
	card.gui_input.connect(_on_card_input.bind(idx))
	card.mouse_entered.connect(_on_card_hover.bind(idx, true))
	card.mouse_exited.connect(_on_card_hover.bind(idx, false))

	# Connect draw
	card.draw.connect(_draw_card.bind(card, data))

	gene_cards_container.add_child(card)

func _on_card_hover(idx: int, entered: bool) -> void:
	if idx < _card_data.size():
		_card_data[idx]["hovered"] = entered
		_card_data[idx]["node"].queue_redraw()
		if entered:
			AudioManager.play_ui_hover()

func _on_card_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_card_selected(idx)

func _on_card_selected(idx: int) -> void:
	if idx >= _card_data.size():
		return
	var comp_id: String = _card_data[idx]["id"]

	# Deselect previous
	if _selected_card:
		for d in _card_data:
			if d["node"] == _selected_card:
				d["selected"] = false
				_selected_card.queue_redraw()

	_selected_card = _card_data[idx]["node"]
	_card_data[idx]["selected"] = true
	_selected_card.queue_redraw()

	_awaiting_confirm = false

	if selected_gene_1.is_empty():
		selected_gene_1 = comp_id
		splice_slot_1.text = comp_id
		AudioManager.play_ui_select()
	elif selected_gene_2.is_empty():
		selected_gene_2 = comp_id
		splice_slot_2.text = comp_id
		AudioManager.play_ui_select()
		_check_compatibility()
	else:
		# Reset and start over
		selected_gene_1 = comp_id
		selected_gene_2 = ""
		splice_slot_1.text = comp_id
		splice_slot_2.text = "[Empty]"
		viability_label.text = "Select two genes to splice"
		viability_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		preview_label.text = ""
		inject_button.disabled = true
		AudioManager.play_ui_select()

func _draw_card(card: Control, data: Dictionary) -> void:
	var w: float = card.size.x
	var h: float = card.size.y
	var is_hovered: bool = data.get("hovered", false)
	var is_selected: bool = data.get("selected", false)
	var comp_type: String = data.get("type", "gene")
	var comp_id: String = data.get("id", "?")
	var comp_func: String = data.get("function", "")
	var impact: Dictionary = data.get("trait_impact", {})

	# Background
	var bg_color := Color(0.06, 0.08, 0.12, 0.85)
	if is_selected:
		bg_color = Color(0.1, 0.15, 0.25, 0.95)
	elif is_hovered:
		bg_color = Color(0.08, 0.12, 0.18, 0.9)
	card.draw_rect(Rect2(0, 0, w, h), bg_color)

	# Type stripe on left edge
	var stripe_color := Color(0.3, 0.5, 0.9) if comp_type == "gene" else Color(0.3, 0.9, 0.5)
	card.draw_rect(Rect2(0, 0, 4, h), stripe_color)

	# Selection highlight border
	if is_selected:
		card.draw_rect(Rect2(0, 0, w, 1), stripe_color.lightened(0.3))
		card.draw_rect(Rect2(0, h - 1, w, 1), stripe_color.lightened(0.3))

	var font := ThemeDB.fallback_font

	# Type badge
	var badge_text: String = "GENE" if comp_type == "gene" else "PROT"
	var badge_color := stripe_color.darkened(0.3)
	var badge_w: float = 38.0
	card.draw_rect(Rect2(10, 6, badge_w, 16), Color(badge_color.r, badge_color.g, badge_color.b, 0.4))
	card.draw_string(font, Vector2(13, 18), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, stripe_color)

	# ID
	card.draw_string(font, Vector2(54, 18), comp_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.95, 1.0, 0.95))

	# Function (smaller, dimmer)
	card.draw_string(font, Vector2(10, 36), comp_func, HORIZONTAL_ALIGNMENT_LEFT, int(w * 0.55), 11, Color(0.6, 0.7, 0.8, 0.75))

	# Trait bars on the right
	var bar_x: float = w * 0.6
	var bar_w: float = w * 0.3
	var bar_y: float = 8.0
	var bar_h: float = 10.0
	var bar_spacing: float = 14.0

	for key in impact:
		var value: float = impact[key]
		var trait_color: Color = TRAIT_COLORS.get(key, Color(0.5, 0.6, 0.7))

		# Trait name (abbreviated)
		var short_name: String = _short_trait_name(key)
		card.draw_string(font, Vector2(bar_x, bar_y + 8), short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(trait_color.r, trait_color.g, trait_color.b, 0.7))

		# Bar background
		var bx: float = bar_x + bar_w * 0.45
		var bw: float = bar_w * 0.55
		card.draw_rect(Rect2(bx, bar_y, bw, bar_h), Color(0.15, 0.18, 0.22, 0.8))

		# Bar fill (clamped to reasonable display range)
		var fill: float = clampf(absf(value) / 0.25, 0.05, 1.0)
		var fill_color := trait_color if value >= 0 else Color(0.9, 0.3, 0.3)
		card.draw_rect(Rect2(bx + 1, bar_y + 1, (bw - 2) * fill, bar_h - 2), Color(fill_color.r, fill_color.g, fill_color.b, 0.7))

		# Value label
		var val_text: String = "%+.0f%%" % (value * 100)
		card.draw_string(font, Vector2(bx + bw + 3, bar_y + 8), val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(trait_color.r, trait_color.g, trait_color.b, 0.8))

		bar_y += bar_spacing
		if bar_y > h - 6:
			break

func _short_trait_name(key: String) -> String:
	match key:
		"energy_efficiency": return "ENRG"
		"energy_processing": return "ENRG"
		"detection_range": return "SENS"
		"perception": return "SENS"
		"sensing": return "SENS"
		"offspring_survival": return "REPR"
		"reproduction": return "REPR"
		"armor": return "ARMR"
		"damage_reduction": return "ARMR"
		"defense": return "ARMR"
		"speed": return "SPD"
		"movement": return "SPD"
		"hostility_damage": return "ATK"
		"offensive_capability": return "ATK"
		"hunt_success": return "HUNT"
		"stealth": return "STLH"
		"invisibility": return "STLH"
		"self_healing": return "HEAL"
		"mutation_resistance": return "MRES"
		"alliance_formation": return "ALLY"
		"symbiotic_links": return "SYMB"
		"size_increase": return "SIZE"
		"scaling": return "SIZE"
		"herd_efficiency": return "HERD"
		"famine_resistance": return "FRES"
		"environmental_response": return "ENV"
		"photosynthesis": return "PHOT"
		"complexity": return "CPLX"
		"cell_complexity": return "CPLX"
		"random_boost": return "WILD"
		"novel_trait_chance": return "INNV"
		"mutation_rate": return "MRAT"
		"extreme_survival": return "SURV"
		"structure_integrity": return "STRC"
		"symbiosis_strength": return "SYMB"
		"resource_flow": return "FLOW"
		"reactions": return "RXNS"
		"mutations": return "MUTN"
		"damage": return "DMG"
	return key.substr(0, 4).to_upper()

## --- Compatibility & Splice ---

func _format_impact(impact: Dictionary) -> String:
	var parts: Array = []
	for key in impact:
		parts.append("%s: %+.0f%%" % [key, impact[key] * 100])
	return ", ".join(parts)

func _check_compatibility() -> void:
	current_splice_result = BiologyLoader.check_splice(selected_gene_1, selected_gene_2)
	var viability: float = current_splice_result.get("viability", 0.0)
	viability_label.text = "Viability: %.0f%%" % (viability * 100)

	# Color-code viability
	var viability_color: Color
	if viability >= 0.7:
		viability_color = Color(0.3, 1.0, 0.4)
	elif viability >= 0.4:
		viability_color = Color(1.0, 0.9, 0.3)
	else:
		viability_color = Color(1.0, 0.3, 0.3)
	viability_label.add_theme_color_override("font_color", viability_color)

	# Color-code slot borders
	splice_slot_1.modulate = viability_color
	splice_slot_2.modulate = viability_color

	# Preview new traits
	var new_trait: Dictionary = current_splice_result.get("new_trait", {})
	preview_label.text = "Preview: " + _format_impact(new_trait)

	if viability < 0.4:
		viability_label.text += " [HIGH RISK]"

	inject_button.disabled = false
	inject_button.text = "INJECT SPLICE"

func _on_inject() -> void:
	if current_splice_result.is_empty():
		return

	var viability: float = current_splice_result.get("viability", 0.0)

	# Confirmation for low viability
	if viability < 0.4 and not _awaiting_confirm:
		_awaiting_confirm = true
		inject_button.text = "CONFIRM RISKY SPLICE?"
		viability_label.text = "WARNING: High risk of rejection! Click again to confirm."
		viability_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		_flash_timer = 0.3
		_flash_color = Color(1.0, 0.2, 0.1)
		AudioManager.play_energy_warning()
		return

	_awaiting_confirm = false

	# Roll for success based on viability
	if randf() > viability:
		preview_label.text = "SPLICE FAILED! Incompatible genes caused rejection."
		preview_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_flash_timer = 0.5
		_flash_color = Color(0.8, 0.1, 0.1)
		AudioManager.play_splice_fail()
		# Shake camera if available
		var cam := get_viewport().get_camera_2d()
		if cam and cam.has_method("shake"):
			cam.shake(6.0, 0.3)
		return

	# Apply new traits
	var new_trait: Dictionary = current_splice_result.get("new_trait", {})
	for key in new_trait:
		var current: float = GameManager.player_stats.spliced_traits.get(key, 0.0)
		GameManager.player_stats.spliced_traits[key] = current + new_trait[key]

	# Success VFX
	_flash_timer = 0.4
	_flash_color = Color(0.2, 1.0, 0.4)
	AudioManager.play_splice_success()

	if randf() < 0.10:
		preview_label.text = "Splice applied + WILDCARD MUTATION!"
		preview_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		_flash_color = Color(1.0, 0.8, 0.2)
		GameManager.player_stats.spliced_traits["random_boost"] = GameManager.player_stats.spliced_traits.get("random_boost", 0.0) + 0.05
	else:
		preview_label.text = "Splice applied successfully!"
		preview_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

	splice_applied.emit(new_trait)
	_reset_slots()

func _reset_slots() -> void:
	selected_gene_1 = ""
	selected_gene_2 = ""
	splice_slot_1.text = "[Empty]"
	splice_slot_2.text = "[Empty]"
	splice_slot_1.modulate = Color.WHITE
	splice_slot_2.modulate = Color.WHITE
	inject_button.disabled = true
	inject_button.text = "INJECT SPLICE"
	current_splice_result = {}
	_awaiting_confirm = false
	# Deselect card
	if _selected_card:
		for d in _card_data:
			if d["node"] == _selected_card:
				d["selected"] = false
				_selected_card.queue_redraw()
		_selected_card = null

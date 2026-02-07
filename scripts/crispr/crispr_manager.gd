extends Control
## CRISPR Editor: Visual gene splicing with animated DNA helix background.
## Color-coded viability, splice VFX, and confirmation for risky splices.

signal splice_applied(new_traits: Dictionary)

@onready var gene_list: ItemList = $PanelContainer/VBoxContainer/GeneList
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

func _ready() -> void:
	_populate_gene_list()
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

func _populate_gene_list() -> void:
	gene_list.clear()
	for gene in BiologyLoader.genes:
		gene_list.add_item("%s - %s (%s)" % [gene.id, gene.function, _format_impact(gene.trait_impact)])
	for protein in BiologyLoader.proteins:
		gene_list.add_item("%s - %s (%s)" % [protein.id, protein.function, _format_impact(protein.trait_impact)])

func _format_impact(impact: Dictionary) -> String:
	var parts: Array = []
	for key in impact:
		parts.append("%s: %+.0f%%" % [key, impact[key] * 100])
	return ", ".join(parts)

func _on_gene_list_item_selected(index: int) -> void:
	_awaiting_confirm = false
	var item_text: String = gene_list.get_item_text(index)
	var comp_id: String = item_text.split(" - ")[0]

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

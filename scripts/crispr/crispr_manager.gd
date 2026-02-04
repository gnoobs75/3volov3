extends Control
## CRISPR Editor: Drag-drop gene splicing from biology library.
## From Possible_Features: "Drag genes/proteins from JSON lib; compatibility check; What-If sim; inject with risks"

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

func _ready() -> void:
	_populate_gene_list()
	inject_button.pressed.connect(_on_inject)
	inject_button.disabled = true

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
	var item_text: String = gene_list.get_item_text(index)
	var comp_id: String = item_text.split(" - ")[0]

	if selected_gene_1.is_empty():
		selected_gene_1 = comp_id
		splice_slot_1.text = comp_id
	elif selected_gene_2.is_empty():
		selected_gene_2 = comp_id
		splice_slot_2.text = comp_id
		_check_compatibility()
	else:
		# Reset and start over
		selected_gene_1 = comp_id
		selected_gene_2 = ""
		splice_slot_1.text = comp_id
		splice_slot_2.text = "[Empty]"
		viability_label.text = "Select two genes to splice"
		preview_label.text = ""
		inject_button.disabled = true

func _check_compatibility() -> void:
	## From Possible_Features: compatibility check + viability scoring
	current_splice_result = BiologyLoader.check_splice(selected_gene_1, selected_gene_2)
	var viability: float = current_splice_result.get("viability", 0.0)
	viability_label.text = "Viability: %.0f%%" % (viability * 100)

	# Preview new traits
	var new_trait: Dictionary = current_splice_result.get("new_trait", {})
	preview_label.text = "Preview: " + _format_impact(new_trait)

	# From Possible_Features: "Incompatible splices → sterility/cancer"
	if viability < 0.4:
		viability_label.text += " [WARNING: High risk of sterility!]"

	inject_button.disabled = false

func _on_inject() -> void:
	if current_splice_result.is_empty():
		return

	var viability: float = current_splice_result.get("viability", 0.0)

	# Roll for success based on viability
	if randf() > viability:
		preview_label.text = "SPLICE FAILED! Incompatible genes caused rejection."
		# From Possible_Features: "risks (e.g., sterility)"
		# Penalize player slightly
		return

	# Apply new traits
	var new_trait: Dictionary = current_splice_result.get("new_trait", {})
	for key in new_trait:
		var current: float = GameManager.player_stats.spliced_traits.get(key, 0.0)
		GameManager.player_stats.spliced_traits[key] = current + new_trait[key]

	# From Possible_Features: "10% wildcard mutations"
	if randf() < 0.10:
		preview_label.text = "Splice applied + WILDCARD MUTATION!"
		GameManager.player_stats.spliced_traits["random_boost"] = GameManager.player_stats.spliced_traits.get("random_boost", 0.0) + 0.05
	else:
		preview_label.text = "Splice applied successfully!"

	splice_applied.emit(new_trait)
	_reset_slots()

func _reset_slots() -> void:
	selected_gene_1 = ""
	selected_gene_2 = ""
	splice_slot_1.text = "[Empty]"
	splice_slot_2.text = "[Empty]"
	inject_button.disabled = true
	current_splice_result = {}

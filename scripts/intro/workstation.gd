extends Control
## Workstation intro with procedural microscope view.
## Q/E keys or slider to focus. Microscope shader reveals cell. Transition to cell stage.

@onready var microscope_rect: ColorRect = $MicroscopeView
@onready var focus_label: Label = $FocusLabel
@onready var tooltip: Label = $TooltipLabel
@onready var focus_slider: HSlider = $FocusSlider
@onready var title_label: Label = $TitleLabel

var focus_level: float = 0.0
var transition_triggered: bool = false
const FOCUS_SPEED: float = 0.3

func _ready() -> void:
	focus_level = 0.0
	_update_focus()
	tooltip.text = "Adjust the microscope focus: E = Focus In, Q = Focus Out"

func _process(delta: float) -> void:
	if transition_triggered:
		return

	if Input.is_action_pressed("focus_in"):
		focus_level = minf(focus_level + FOCUS_SPEED * delta, 1.0)
	if Input.is_action_pressed("focus_out"):
		focus_level = maxf(focus_level - FOCUS_SPEED * delta, 0.0)

	focus_slider.value = focus_level
	_update_focus()

	if focus_level >= 0.99 and not transition_triggered:
		_on_focus_complete()

func _update_focus() -> void:
	if microscope_rect.material:
		(microscope_rect.material as ShaderMaterial).set_shader_parameter("focus", focus_level)
	focus_label.text = "Focus: %d%%" % int(focus_level * 100)
	# Tooltip changes as focus increases
	if focus_level > 0.3 and focus_level < 0.7:
		tooltip.text = "Organisms becoming visible... keep focusing"
	elif focus_level >= 0.7 and not transition_triggered:
		tooltip.text = "Target organism locked! Almost there..."

func _on_focus_slider_value_changed(value: float) -> void:
	focus_level = value
	_update_focus()

func _on_focus_complete() -> void:
	transition_triggered = true
	tooltip.text = "Cell detected! Entering microscope view..."
	title_label.visible = false
	await get_tree().create_timer(1.5).timeout
	GameManager.go_to_cell_stage()

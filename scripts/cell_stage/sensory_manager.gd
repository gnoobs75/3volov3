extends ColorRect
## Updates sensory shader uniforms: fog of war radius + grayscale based on sensory level.

var _target_visibility: float = 0.3
var _target_color: float = 0.0
var _current_visibility: float = 0.3
var _current_color: float = 0.0

func _ready() -> void:
	GameManager.evolution_applied.connect(_on_evolution_applied)
	_apply_sensory_tier(true)

func _process(delta: float) -> void:
	_current_visibility = move_toward(_current_visibility, _target_visibility, delta * 0.4)
	_current_color = move_toward(_current_color, _target_color, delta * 0.4)
	var mat: ShaderMaterial = material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("visibility_range", _current_visibility)
		mat.set_shader_parameter("color_perception", _current_color)

func _on_evolution_applied(_mutation: Dictionary) -> void:
	_apply_sensory_tier(false)

func _apply_sensory_tier(instant: bool) -> void:
	var tier: Dictionary = GameManager.get_sensory_tier()
	_target_visibility = tier.get("visibility_range", 0.3)
	_target_color = tier.get("color_perception", 0.0)
	if instant:
		_current_visibility = _target_visibility
		_current_color = _target_color

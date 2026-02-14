extends Area2D
## Beamable eye node for the Oculus Titan boss.
## Acts like a food particle for the organic vacuum system.

var component_data: Dictionary = {"id": "boss_eye", "display_name": "Eye", "short_name": "EYE", "color": [0.9, 0.3, 0.3], "is_organelle": false}
var _pull_progress: float = 0.0

func beam_pull_toward(target_pos: Vector2, delta: float) -> void:
	_pull_progress += delta
	var boss = get_meta("boss", null)
	var idx = get_meta("eye_index", -1)
	if boss and is_instance_valid(boss) and idx >= 0:
		boss._on_eye_being_pulled(idx, _pull_progress)

func beam_release() -> void:
	_pull_progress = 0.0
	var boss = get_meta("boss", null)
	var idx = get_meta("eye_index", -1)
	if boss and is_instance_valid(boss) and idx >= 0:
		boss._on_eye_release(idx)

func get_beam_color() -> Color:
	return Color(0.9, 0.3, 0.3)

func feed(_data: Dictionary) -> void:
	pass

func setup(_data: Dictionary, _is_org: bool) -> void:
	pass

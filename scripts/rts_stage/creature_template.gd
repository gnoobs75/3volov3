class_name CreatureTemplate
## Stores procedural creature appearance data for a faction.
## Generated from faction_data or player customization.

var faction_id: int = 0
var membrane_color: Color = Color.WHITE
var interior_color: Color = Color.GRAY
var glow_color: Color = Color.WHITE
var eye_style: String = "anime"
var body_handles: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var eye_data: Array = []
var decoration_seed: int = 0

func setup_from_faction(fid: int) -> void:
	faction_id = fid
	var fd: Dictionary = FactionData.get_faction(fid)
	membrane_color = fd.get("color", Color.WHITE)
	interior_color = fd.get("color_dark", Color.GRAY)
	glow_color = fd.get("color_glow", Color.WHITE)
	eye_style = fd.get("eye_style", "anime")
	decoration_seed = fid * 1000 + randi() % 1000
	# Generate body handles with slight variation per faction
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration_seed
	body_handles = []
	for i in range(8):
		body_handles.append(clampf(1.0 + rng.randf_range(-0.15, 0.15), 0.7, 1.3))
	# Generate eyes
	eye_data = [
		{"x": -0.15, "y": -0.2, "size": 3.0, "style": eye_style},
		{"x": -0.15, "y": 0.2, "size": 3.0, "style": eye_style},
	]

func setup_from_player() -> void:
	faction_id = 0
	var cc: Dictionary = GameManager.creature_customization
	membrane_color = cc.get("membrane_color", Color(0.3, 0.6, 1.0))
	interior_color = cc.get("interior_color", Color(0.15, 0.25, 0.5))
	glow_color = cc.get("glow_color", Color(0.3, 0.7, 1.0))
	eye_style = cc.get("eye_style", "anime")
	body_handles = cc.get("body_handles", [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]).duplicate()
	eye_data = GameManager.get_eyes().duplicate(true)
	decoration_seed = randi()

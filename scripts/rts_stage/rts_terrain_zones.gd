extends Node2D
## Manages elevated terrain zones that give combat advantage.
## Units on high ground deal +15% damage to units not on high ground.

var _zones: Array = []  # Array of {center: Vector2, radius: float}
var _time: float = 0.0

func setup(map_radius: float) -> void:
	# Place 6 elevation zones at strategic locations
	# Between spawn points, near resource clusters
	var zone_configs: Array = [
		{"center": Vector2(2000, 0), "radius": 200.0},
		{"center": Vector2(-2000, 0), "radius": 200.0},
		{"center": Vector2(0, 2000), "radius": 180.0},
		{"center": Vector2(0, -2000), "radius": 180.0},
		{"center": Vector2(1500, 1500), "radius": 150.0},
		{"center": Vector2(-1500, -1500), "radius": 150.0},
	]
	_zones = zone_configs

func is_on_high_ground(pos: Vector2) -> bool:
	for zone in _zones:
		if pos.distance_to(zone["center"]) <= zone["radius"]:
			return true
	return false

func get_elevation_bonus(attacker_pos: Vector2, target_pos: Vector2) -> float:
	## Returns damage multiplier. 1.15 if attacker on high ground and target not, else 1.0
	var attacker_elevated: bool = is_on_high_ground(attacker_pos)
	var target_elevated: bool = is_on_high_ground(target_pos)
	if attacker_elevated and not target_elevated:
		return 1.15
	return 1.0

func _process(delta: float) -> void:
	_time += delta
	# Only redraw every 5 frames (terrain zones are mostly static)
	if Engine.get_process_frames() % 5 == 0:
		queue_redraw()

func _draw() -> void:
	# Draw elevation zones as subtle raised platforms
	for zone in _zones:
		var center: Vector2 = zone["center"]
		var radius: float = zone["radius"]
		# Check if on screen before drawing
		var camera: Camera2D = get_viewport().get_camera_2d()
		if camera:
			var dist: float = camera.global_position.distance_to(center)
			if dist > 2000:
				continue
		# Outer contour ring (like topographic map)
		draw_arc(center, radius, 0, TAU, 48, Color(0.4, 0.35, 0.25, 0.15), 2.0)
		draw_arc(center, radius * 0.8, 0, TAU, 36, Color(0.4, 0.35, 0.25, 0.08), 1.0)
		# Fill with very subtle tint
		draw_circle(center, radius, Color(0.35, 0.3, 0.2, 0.04))
		# Shimmer effect
		var shimmer: float = 0.02 + 0.01 * sin(_time * 1.5 + center.x * 0.01)
		draw_circle(center, radius * 0.5, Color(0.5, 0.45, 0.3, shimmer))
		# Small "HIGH GROUND" text at center (only when zoomed in)
		if camera and camera.zoom.x > 0.3:
			var font: Font = ThemeDB.fallback_font
			draw_string(font, center + Vector2(-30, 5), "HIGH GROUND", HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(0.6, 0.55, 0.4, 0.3))

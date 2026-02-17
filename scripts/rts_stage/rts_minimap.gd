extends Control
## Circular minimap showing faction-colored dots for units/buildings, resources.
## Click to pan camera. Alt+click to ping (typed). Click-and-drag to scroll.

var _stage: Node = null
var _camera: Camera2D = null
var _time: float = 0.0

# Attack alert pings (red, enemy kills)
var _alert_pings: Array = []  # [{pos, time}]
const ALERT_PING_LIFE: float = 3.0
var _alert_cooldown: float = 0.0

# Player communication pings (typed: 0=danger, 1=assist, 2=omw)
var _player_pings: Array = []  # [{pos, time, type}]
const PLAYER_PING_LIFE: float = 4.0
const PING_COLORS: Array = [
	Color(1.0, 0.3, 0.2),   # Danger - red
	Color(1.0, 0.85, 0.2),  # Assist - yellow
	Color(0.2, 1.0, 0.4),   # On My Way - green
]

# Minimap drag state
var _minimap_dragging: bool = false

const MINIMAP_RADIUS: float = 85.0
const MINIMAP_CENTER: Vector2 = Vector2(95, 0)  # Offset from bottom-left
const MAP_RADIUS: float = 8000.0

# Reference to HUD for forwarding typed pings
var _hud: Control = null

func setup(stage: Node, camera: Camera2D) -> void:
	_stage = stage
	_camera = camera
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_hud(hud: Control) -> void:
	_hud = hud

func add_attack_ping(world_pos: Vector2) -> void:
	_alert_pings.append({"pos": world_pos, "time": 0.0})
	if _alert_pings.size() > 5:
		_alert_pings.pop_front()

func add_player_ping(world_pos: Vector2, ping_type: int = 2) -> void:
	_player_pings.append({"pos": world_pos, "time": 0.0, "type": clampi(ping_type, 0, 2)})
	if _player_pings.size() > 5:
		_player_pings.pop_front()
	# Also forward to HUD for screen-space ping display
	if _hud and _hud.has_method("add_map_ping"):
		_hud.add_map_ping(world_pos, ping_type)
	AudioManager.play_map_ping()

func _process(delta: float) -> void:
	_time += delta
	_alert_cooldown = maxf(_alert_cooldown - delta, 0.0)
	# Update attack pings
	var i: int = _alert_pings.size() - 1
	while i >= 0:
		_alert_pings[i]["time"] += delta
		if _alert_pings[i]["time"] >= ALERT_PING_LIFE:
			_alert_pings.remove_at(i)
		i -= 1
	# Update player pings
	i = _player_pings.size() - 1
	while i >= 0:
		_player_pings[i]["time"] += delta
		if _player_pings[i]["time"] >= PLAYER_PING_LIFE:
			_player_pings.remove_at(i)
		i -= 1
	queue_redraw()

func _get_minimap_center() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	return Vector2(MINIMAP_CENTER.x, vp.y - MINIMAP_RADIUS - 25.0)

func _world_to_minimap(world_pos: Vector2) -> Vector2:
	var center: Vector2 = _get_minimap_center()
	var normalized: Vector2 = world_pos / MAP_RADIUS
	return center + normalized * MINIMAP_RADIUS

func _minimap_to_world(minimap_pos: Vector2) -> Vector2:
	var center: Vector2 = _get_minimap_center()
	var offset: Vector2 = minimap_pos - center
	var normalized: Vector2 = offset / MINIMAP_RADIUS
	return normalized * MAP_RADIUS

func _move_camera_to_minimap_pos(screen_pos: Vector2) -> void:
	var center: Vector2 = _get_minimap_center()
	var dist: float = screen_pos.distance_to(center)
	if dist > MINIMAP_RADIUS:
		# Clamp to minimap circle
		var dir: Vector2 = (screen_pos - center).normalized()
		screen_pos = center + dir * MINIMAP_RADIUS
	var world_pos: Vector2 = _minimap_to_world(screen_pos)
	if _camera and _camera.has_method("focus_position"):
		_camera.focus_position(world_pos)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var center: Vector2 = _get_minimap_center()
		var dist: float = event.position.distance_to(center)
		if event.pressed:
			if dist < MINIMAP_RADIUS:
				var world_pos: Vector2 = _minimap_to_world(event.position)
				if event.alt_pressed:
					# Alt+click: danger ping (type 0)
					var ping_type: int = 0  # danger
					if event.ctrl_pressed:
						ping_type = 1  # assist (Ctrl+Alt)
					elif event.shift_pressed:
						ping_type = 2  # omw (Shift+Alt)
					add_player_ping(world_pos, ping_type)
				else:
					# Normal click: pan camera + start dragging
					_minimap_dragging = true
					_move_camera_to_minimap_pos(event.position)
				get_viewport().set_input_as_handled()
		else:
			# Mouse released
			if _minimap_dragging:
				_minimap_dragging = false
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _minimap_dragging:
		# Drag on minimap: continuously scroll camera
		_move_camera_to_minimap_pos(event.position)
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var center: Vector2 = _get_minimap_center()

	# Background circle
	draw_circle(center, MINIMAP_RADIUS + 2, Color(0.02, 0.03, 0.06, 0.9))
	draw_circle(center, MINIMAP_RADIUS, Color(0.04, 0.06, 0.1, 0.8))
	draw_arc(center, MINIMAP_RADIUS, 0, TAU, 48, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.5), 1.5)

	# Map boundary ring
	draw_arc(center, MINIMAP_RADIUS - 1, 0, TAU, 48, Color(0.3, 0.5, 0.7, 0.2), 1.0)

	# Obstacles (dark grey patches, drawn first as background)
	for obs in get_tree().get_nodes_in_group("rts_obstacles"):
		if not is_instance_valid(obs):
			continue
		var mp: Vector2 = _world_to_minimap(obs.global_position)
		if mp.distance_to(center) > MINIMAP_RADIUS:
			continue
		draw_circle(mp, 2.0, Color(0.2, 0.2, 0.2, 0.5))

	# Resources (yellow dots for resource nodes, colored for titans)
	for res in get_tree().get_nodes_in_group("rts_resources"):
		if not is_instance_valid(res):
			continue
		if res.has_method("is_depleted") and res.is_depleted():
			continue
		var mp: Vector2 = _world_to_minimap(res.global_position)
		if mp.distance_to(center) > MINIMAP_RADIUS:
			continue
		var is_titan: bool = res.is_in_group("titan_corpses")
		var rc: Color = Color(0.5, 0.35, 0.15) if is_titan else Color(0.85, 0.75, 0.2)
		draw_circle(mp, 2.5 if is_titan else 1.5, rc)

	# Buildings
	for building in get_tree().get_nodes_in_group("rts_buildings"):
		if not is_instance_valid(building):
			continue
		var mp: Vector2 = _world_to_minimap(building.global_position)
		if mp.distance_to(center) > MINIMAP_RADIUS:
			continue
		var fid: int = building.faction_id if "faction_id" in building else 0
		var fc: Color = FactionData.get_faction_color(fid)
		draw_rect(Rect2(mp.x - 2, mp.y - 2, 4, 4), fc)

	# Units
	for unit in get_tree().get_nodes_in_group("rts_units"):
		if not is_instance_valid(unit):
			continue
		var mp: Vector2 = _world_to_minimap(unit.global_position)
		if mp.distance_to(center) > MINIMAP_RADIUS:
			continue
		var fid: int = unit.faction_id if "faction_id" in unit else 0
		var fc: Color = FactionData.get_faction_color(fid)
		var is_sel: bool = "is_selected" in unit and unit.is_selected
		if is_sel:
			# Selected units get a brighter, larger dot
			draw_circle(mp, 2.5, Color(1.0, 1.0, 1.0, 0.7))
			draw_circle(mp, 2.0, fc.lightened(0.3))
		else:
			draw_circle(mp, 1.5, fc)

	# Attack alert pings (red)
	for ping in _alert_pings:
		var mp: Vector2 = _world_to_minimap(ping["pos"])
		if mp.distance_to(center) > MINIMAP_RADIUS:
			continue
		var ping_alpha: float = 1.0 - (ping["time"] / ALERT_PING_LIFE)
		var pt: float = ping["time"] / ALERT_PING_LIFE
		var ping_r: float = 3.0 + pt * 8.0
		draw_arc(mp, ping_r, 0, TAU, 12, Color(1.0, 0.3, 0.2, ping_alpha * 0.7), 1.5)
		if pt < 0.5:
			draw_circle(mp, 2.0, Color(1.0, 0.3, 0.2, ping_alpha))

	# Player communication pings (typed colors)
	for ping in _player_pings:
		var mp: Vector2 = _world_to_minimap(ping["pos"])
		if mp.distance_to(center) > MINIMAP_RADIUS:
			continue
		var ping_type: int = ping.get("type", 2)
		var pc: Color = PING_COLORS[clampi(ping_type, 0, 2)]
		var ping_alpha: float = 1.0 - (ping["time"] / PLAYER_PING_LIFE)
		var pt: float = ping["time"] / PLAYER_PING_LIFE
		var ping_r: float = 3.0 + pt * 10.0
		draw_arc(mp, ping_r, 0, TAU, 12, Color(pc.r, pc.g, pc.b, ping_alpha * 0.7), 1.5)
		if pt < 0.5:
			draw_circle(mp, 2.0, Color(pc.r, pc.g, pc.b, ping_alpha))

	# Camera viewport rectangle (drawn last, on top)
	_draw_camera_rect()

func _draw_camera_rect() -> void:
	if not _camera:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: float = _camera.zoom.x if _camera.zoom.x > 0 else 1.0
	var half_w: float = (vp_size.x / zoom) * 0.5
	var half_h: float = (vp_size.y / zoom) * 0.5
	var cam_pos: Vector2 = _camera.global_position
	# Convert 4 corners from world to minimap coords
	var tl: Vector2 = _world_to_minimap(cam_pos + Vector2(-half_w, -half_h))
	var tr: Vector2 = _world_to_minimap(cam_pos + Vector2(half_w, -half_h))
	var br: Vector2 = _world_to_minimap(cam_pos + Vector2(half_w, half_h))
	var bl: Vector2 = _world_to_minimap(cam_pos + Vector2(-half_w, half_h))
	var rect_color: Color = Color(1.0, 1.0, 1.0, 0.6)
	draw_line(tl, tr, rect_color, 1.0)
	draw_line(tr, br, rect_color, 1.0)
	draw_line(br, bl, rect_color, 1.0)
	draw_line(bl, tl, rect_color, 1.0)

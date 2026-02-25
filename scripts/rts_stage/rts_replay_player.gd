extends CanvasLayer
## Plays back a recorded RTS match by re-issuing commands at their timestamps.
## Draws a replay control bar at the bottom of screen and "REPLAY" watermark.

var _events: Array = []
var _event_index: int = 0
var _playback_time: float = 0.0
var _playback_speed: float = 1.0
var _is_playing: bool = false
var _is_paused: bool = false
var _total_time: float = 0.0
var _initial_state: Dictionary = {}
var _stage: Node2D = null
var _time: float = 0.0  # For animations

# Speed options
const SPEED_OPTIONS: Array = [1.0, 2.0, 4.0, 8.0]
var _speed_index: int = 0

# UI
var _draw_control: Control = null

# Hover tracking
var _hover_play_pause: bool = false
var _hover_speed: Array = [false, false, false, false]
var _hover_timeline: bool = false

# Layout constants
const BAR_HEIGHT: float = 48.0
const BAR_MARGIN: float = 160.0  # Left/right margin from viewport edges
const BTN_SIZE: float = 36.0
const SPEED_BTN_W: float = 40.0
const SPEED_BTN_H: float = 28.0
const SPEED_BTN_GAP: float = 6.0
const TIMELINE_H: float = 8.0
const WATERMARK_MARGIN: float = 20.0

func _ready() -> void:
	layer = 25  # Above everything
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_control = Control.new()
	_draw_control.name = "ReplayDrawControl"
	_draw_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_control.draw.connect(_on_draw)
	_draw_control.gui_input.connect(_on_gui_input)
	add_child(_draw_control)

func setup(stage: Node2D) -> void:
	_stage = stage

func load_replay(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return false
	_events = data.get("events", [])
	_initial_state = data.get("initial_state", {})
	_total_time = data.get("total_time", 0.0)
	if _total_time <= 0.0 and not _events.is_empty():
		_total_time = _events.back().get("time", 0.0)
	return true

func get_initial_state() -> Dictionary:
	return _initial_state

func start_playback() -> void:
	_is_playing = true
	_is_paused = false
	_playback_time = 0.0
	_event_index = 0
	_speed_index = 0
	_playback_speed = SPEED_OPTIONS[0]

func is_active() -> bool:
	return _is_playing

func is_paused() -> bool:
	return _is_paused

func get_playback_time() -> float:
	return _playback_time

func get_total_time() -> float:
	return _total_time

func get_playback_speed() -> float:
	return _playback_speed

func _process(delta: float) -> void:
	_time += delta
	if not _is_playing:
		return
	# Update hover state
	if _draw_control:
		var vp: Vector2 = _draw_control.get_viewport_rect().size
		var mouse: Vector2 = _draw_control.get_local_mouse_position()
		_update_hover(vp, mouse)
		_draw_control.queue_redraw()
	if _is_paused:
		return
	_playback_time += delta * _playback_speed
	# Execute events up to current time
	while _event_index < _events.size():
		var event: Dictionary = _events[_event_index]
		var event_time: float = event.get("time", 0.0)
		if event_time > _playback_time:
			break
		_execute_event(event)
		_event_index += 1
	# Check if playback is complete
	if _event_index >= _events.size() and _playback_time >= _total_time:
		_is_paused = true  # Pause at end rather than stopping

func _execute_event(event: Dictionary) -> void:
	if not _stage:
		return
	var event_type: String = event.get("type", "")
	var data: Dictionary = event.get("data", {})
	# In replay mode, we dispatch visual commands to replicate the match.
	# Find units/buildings by name and issue matching commands.
	match event_type:
		"move":
			var target_pos: Vector2 = Vector2(data.get("target_x", 0.0), data.get("target_y", 0.0))
			var units: Array = _find_nodes_by_names(data.get("units", []))
			for unit in units:
				if unit.has_method("command_move"):
					unit.command_move(target_pos)
			# Show VFX
			if _stage._command_vfx and _stage._command_vfx.has_method("add_move_indicator"):
				_stage._command_vfx.add_move_indicator(target_pos)
		"attack":
			var target_id: String = data.get("target_id", "")
			var target: Node2D = _find_node_by_name(target_id)
			if target:
				var units: Array = _find_nodes_by_names(data.get("units", []))
				for unit in units:
					if unit.has_method("command_attack"):
						unit.command_attack(target)
		"attack_move":
			var target_pos: Vector2 = Vector2(data.get("target_x", 0.0), data.get("target_y", 0.0))
			var units: Array = _find_nodes_by_names(data.get("units", []))
			for unit in units:
				if unit.has_method("command_move"):
					unit.command_move(target_pos)
			if _stage._command_vfx and _stage._command_vfx.has_method("add_attack_move_ring"):
				_stage._command_vfx.add_attack_move_ring(target_pos)
		"build":
			var building_type: int = int(data.get("building_type", 0))
			var pos: Vector2 = Vector2(data.get("pos_x", 0.0), data.get("pos_y", 0.0))
			# Determine faction from worker name
			var worker_id: String = data.get("worker_id", "")
			var faction_id: int = _extract_faction_from_name(worker_id)
			if faction_id == 0 and _stage.has_method("place_building"):
				_stage.place_building(building_type, pos)
			elif _stage.has_method("ai_place_building"):
				_stage.ai_place_building(faction_id, building_type)
		"produce":
			var building_id: String = data.get("building_id", "")
			var building: Node2D = _find_node_by_name(building_id)
			if building and building.has_method("queue_unit"):
				var unit_type: int = int(data.get("unit_type", 0))
				building.queue_unit(unit_type)
		"research":
			var building_id: String = data.get("building_id", "")
			var building: Node2D = _find_node_by_name(building_id)
			if building and building.has_method("queue_research"):
				var upgrade_id: String = data.get("upgrade_id", "")
				building.queue_research(upgrade_id)
		"ability":
			var unit_id: String = data.get("unit_id", "")
			var unit: Node2D = _find_node_by_name(unit_id)
			if unit and unit.has_method("use_ability"):
				var target_pos: Vector2 = Vector2(data.get("target_x", 0.0), data.get("target_y", 0.0))
				unit.use_ability(target_pos)
		"rally":
			var building_id: String = data.get("building_id", "")
			var building: Node2D = _find_node_by_name(building_id)
			if building and building.has_method("set_rally_point"):
				var pos: Vector2 = Vector2(data.get("pos_x", 0.0), data.get("pos_y", 0.0))
				building.set_rally_point(pos)
		"patrol":
			var units: Array = _find_nodes_by_names(data.get("units", []))
			var point_a: Vector2 = Vector2(data.get("a_x", 0.0), data.get("a_y", 0.0))
			var point_b: Vector2 = Vector2(data.get("b_x", 0.0), data.get("b_y", 0.0))
			for unit in units:
				if unit.has_method("command_patrol"):
					unit.command_patrol(point_a, point_b)
		"gather":
			var target_id: String = data.get("target_id", "")
			var target: Node2D = _find_node_by_name(target_id)
			if target:
				var units: Array = _find_nodes_by_names(data.get("units", []))
				for unit in units:
					if unit.has_method("command_gather"):
						unit.command_gather(target)
		"repair":
			var building_id: String = data.get("building_id", "")
			var building: Node2D = _find_node_by_name(building_id)
			if building:
				var units: Array = _find_nodes_by_names(data.get("units", []))
				for unit in units:
					if unit.has_method("command_repair"):
						unit.command_repair(building)

# === NODE LOOKUP ===

func _find_node_by_name(node_name: String) -> Node2D:
	if node_name.is_empty() or not _stage:
		return null
	for child in _stage.get_children():
		if child.name == node_name and is_instance_valid(child):
			return child
	return null

func _find_nodes_by_names(names: Array) -> Array:
	var result: Array = []
	if not _stage:
		return result
	for child in _stage.get_children():
		if is_instance_valid(child) and child.name in names:
			result.append(child)
	return result

func _extract_faction_from_name(node_name: String) -> int:
	# Node names follow pattern "Unit_<faction>_<type>_<id>" or "Building_<faction>_..."
	var parts: PackedStringArray = node_name.split("_")
	if parts.size() >= 2:
		if parts[1].is_valid_int():
			return int(parts[1])
	return 0

# === INPUT ===

func _on_gui_input(_event: InputEvent) -> void:
	pass  # Using _input() instead since draw_control is MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if not _is_playing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_is_paused = not _is_paused
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				# Exit replay mode
				get_tree().paused = false
				GameManager.rts_replay_file = ""
				GameManager.go_to_menu()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp: Vector2 = _draw_control.get_viewport_rect().size
		# Play/Pause button
		if _hover_play_pause:
			_is_paused = not _is_paused
			get_viewport().set_input_as_handled()
			return
		# Speed buttons
		for i in range(SPEED_OPTIONS.size()):
			if _hover_speed[i]:
				_speed_index = i
				_playback_speed = SPEED_OPTIONS[i]
				get_viewport().set_input_as_handled()
				return
		# Timeline scrub
		if _hover_timeline:
			var tl_rect: Rect2 = _get_timeline_rect(vp)
			var ratio: float = clampf((event.position.x - tl_rect.position.x) / tl_rect.size.x, 0.0, 1.0)
			_seek_to(ratio * _total_time)
			get_viewport().set_input_as_handled()
			return

func _seek_to(target_time: float) -> void:
	## Seek is approximate - we reset event index to 0 and replay up to target.
	## For simplicity, we just move the time pointer and let events before it be skipped.
	_playback_time = clampf(target_time, 0.0, _total_time)
	# Find the right event index
	_event_index = 0
	for i in range(_events.size()):
		if _events[i].get("time", 0.0) > _playback_time:
			break
		_event_index = i + 1

# === HOVER ===

func _update_hover(vp: Vector2, mouse: Vector2) -> void:
	_hover_play_pause = _get_play_pause_rect(vp).has_point(mouse)
	for i in range(SPEED_OPTIONS.size()):
		_hover_speed[i] = _get_speed_btn_rect(vp, i).has_point(mouse)
	_hover_timeline = _get_timeline_rect(vp).has_point(mouse)

# === RECT HELPERS ===

func _get_bar_rect(vp: Vector2) -> Rect2:
	return Rect2(BAR_MARGIN, vp.y - BAR_HEIGHT - 10.0, vp.x - BAR_MARGIN * 2.0, BAR_HEIGHT)

func _get_play_pause_rect(vp: Vector2) -> Rect2:
	var bar: Rect2 = _get_bar_rect(vp)
	return Rect2(bar.position.x + 8, bar.position.y + (bar.size.y - BTN_SIZE) * 0.5, BTN_SIZE, BTN_SIZE)

func _get_speed_btn_rect(vp: Vector2, index: int) -> Rect2:
	var bar: Rect2 = _get_bar_rect(vp)
	var start_x: float = bar.position.x + BTN_SIZE + 24.0
	return Rect2(start_x + index * (SPEED_BTN_W + SPEED_BTN_GAP), bar.position.y + (bar.size.y - SPEED_BTN_H) * 0.5, SPEED_BTN_W, SPEED_BTN_H)

func _get_timeline_rect(vp: Vector2) -> Rect2:
	var bar: Rect2 = _get_bar_rect(vp)
	var tl_x: float = bar.position.x + BTN_SIZE + 24.0 + (SPEED_BTN_W + SPEED_BTN_GAP) * SPEED_OPTIONS.size() + 20.0
	var time_label_w: float = 120.0
	var tl_w: float = bar.position.x + bar.size.x - tl_x - time_label_w - 10.0
	return Rect2(tl_x, bar.position.y + (bar.size.y - TIMELINE_H) * 0.5, maxf(tl_w, 100.0), TIMELINE_H)

# === DRAWING ===

func _on_draw() -> void:
	if not _is_playing:
		return
	var vp: Vector2 = _draw_control.get_viewport_rect().size
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()

	# Watermark: "REPLAY" in top-right corner
	_draw_watermark(vp, font)

	# Control bar background
	var bar: Rect2 = _get_bar_rect(vp)
	_draw_control.draw_rect(bar, Color(0.02, 0.03, 0.06, 0.85))
	_draw_control.draw_rect(bar, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3), false, 1.0)

	# Play/Pause button
	_draw_play_pause(vp)

	# Speed buttons
	for i in range(SPEED_OPTIONS.size()):
		_draw_speed_btn(vp, i)

	# Timeline bar
	_draw_timeline(vp, mono)

	# Time display
	_draw_time_display(vp, mono)

func _draw_watermark(vp: Vector2, font: Font) -> void:
	var text: String = "REPLAY"
	var text_size: int = UIConstants.FONT_HEADER
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
	var x: float = vp.x - ts.x - WATERMARK_MARGIN
	var y: float = WATERMARK_MARGIN + ts.y
	# Pulsing alpha
	var pulse: float = 0.4 + 0.2 * sin(_time * 2.0)
	# Background glow
	_draw_control.draw_rect(Rect2(x - 8, y - ts.y - 4, ts.x + 16, ts.y + 12), Color(0.0, 0.0, 0.0, 0.3 * pulse))
	# Border
	_draw_control.draw_rect(Rect2(x - 8, y - ts.y - 4, ts.x + 16, ts.y + 12),
		Color(UIConstants.STAT_YELLOW.r, UIConstants.STAT_YELLOW.g, UIConstants.STAT_YELLOW.b, 0.4 * pulse), false, 1.0)
	# Text
	_draw_control.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
		Color(UIConstants.STAT_YELLOW.r, UIConstants.STAT_YELLOW.g, UIConstants.STAT_YELLOW.b, pulse))

func _draw_play_pause(vp: Vector2) -> void:
	var rect: Rect2 = _get_play_pause_rect(vp)
	var bg_col: Color = UIConstants.BTN_BG_HOVER if _hover_play_pause else UIConstants.BTN_BG
	_draw_control.draw_rect(rect, bg_col)
	var border_col: Color = UIConstants.BTN_BORDER_HOVER if _hover_play_pause else UIConstants.BTN_BORDER
	_draw_control.draw_rect(rect, border_col, false, 1.0)
	var center: Vector2 = rect.position + rect.size * 0.5
	var icon_col: Color = UIConstants.TEXT_BRIGHT
	if _is_paused:
		# Play triangle
		var pts: PackedVector2Array = PackedVector2Array([
			center + Vector2(-7, -9),
			center + Vector2(-7, 9),
			center + Vector2(9, 0),
		])
		_draw_control.draw_colored_polygon(pts, icon_col)
	else:
		# Pause bars
		_draw_control.draw_rect(Rect2(center.x - 7, center.y - 8, 5, 16), icon_col)
		_draw_control.draw_rect(Rect2(center.x + 2, center.y - 8, 5, 16), icon_col)

func _draw_speed_btn(vp: Vector2, index: int) -> void:
	var rect: Rect2 = _get_speed_btn_rect(vp, index)
	var is_active: bool = index == _speed_index
	var is_hovered: bool = _hover_speed[index]
	var font: Font = UIConstants.get_mono_font()

	var bg_col: Color
	if is_active:
		bg_col = Color(UIConstants.ACCENT.r * 0.15, UIConstants.ACCENT.g * 0.15, UIConstants.ACCENT.b * 0.1, 0.9)
	elif is_hovered:
		bg_col = UIConstants.BTN_BG_HOVER
	else:
		bg_col = UIConstants.BTN_BG
	_draw_control.draw_rect(rect, bg_col)

	var border_col: Color
	if is_active:
		border_col = Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.8)
	elif is_hovered:
		border_col = UIConstants.BTN_BORDER_HOVER
	else:
		border_col = UIConstants.BTN_BORDER
	_draw_control.draw_rect(rect, border_col, false, 1.0 if not is_active else 1.5)

	var label: String = "%dx" % int(SPEED_OPTIONS[index])
	var ls: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, UIConstants.FONT_CAPTION)
	var text_col: Color
	if is_active:
		text_col = UIConstants.ACCENT
	elif is_hovered:
		text_col = UIConstants.BTN_TEXT_HOVER
	else:
		text_col = UIConstants.BTN_TEXT
	_draw_control.draw_string(font, Vector2(rect.position.x + (rect.size.x - ls.x) * 0.5, rect.position.y + rect.size.y * 0.5 + UIConstants.FONT_CAPTION * 0.35),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, text_col)

func _draw_timeline(vp: Vector2, mono: Font) -> void:
	var tl_rect: Rect2 = _get_timeline_rect(vp)
	# Track background
	_draw_control.draw_rect(tl_rect, Color(0.08, 0.10, 0.16, 0.9))
	# Progress fill
	var progress: float = 0.0
	if _total_time > 0.0:
		progress = clampf(_playback_time / _total_time, 0.0, 1.0)
	var fill_rect: Rect2 = Rect2(tl_rect.position.x, tl_rect.position.y, tl_rect.size.x * progress, tl_rect.size.y)
	_draw_control.draw_rect(fill_rect, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.6))
	# Border
	var border_col: Color = UIConstants.BTN_BORDER_HOVER if _hover_timeline else UIConstants.BTN_BORDER
	_draw_control.draw_rect(tl_rect, border_col, false, 1.0)
	# Playhead marker
	var head_x: float = tl_rect.position.x + tl_rect.size.x * progress
	_draw_control.draw_rect(Rect2(head_x - 2, tl_rect.position.y - 3, 4, tl_rect.size.y + 6),
		UIConstants.TEXT_BRIGHT)

func _draw_time_display(vp: Vector2, mono: Font) -> void:
	var bar: Rect2 = _get_bar_rect(vp)
	var current_mins: int = int(_playback_time) / 60
	var current_secs: int = int(_playback_time) % 60
	var total_mins: int = int(_total_time) / 60
	var total_secs: int = int(_total_time) % 60
	var time_text: String = "%02d:%02d / %02d:%02d" % [current_mins, current_secs, total_mins, total_secs]
	var x: float = bar.position.x + bar.size.x - 110.0
	var y: float = bar.position.y + bar.size.y * 0.5 + UIConstants.FONT_CAPTION * 0.35
	_draw_control.draw_string(mono, Vector2(x, y), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_NORMAL)

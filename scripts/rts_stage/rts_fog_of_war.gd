extends Node2D
## Grid-based fog of war for the player faction.
## 3 states: UNEXPLORED (black), EXPLORED (dim), VISIBLE (clear).

enum FogState { UNEXPLORED, EXPLORED, VISIBLE }

const CELL_SIZE: float = 80.0
const MAP_RADIUS: float = 8000.0
var _grid_size: int = 0
var _grid: Array = []  # 2D array of FogState
var _offset: int = 0  # Grid offset (grid center = _offset, _offset)

var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.3

func _ready() -> void:
	_grid_size = int(MAP_RADIUS * 2.0 / CELL_SIZE) + 2
	_offset = _grid_size / 2
	_grid.resize(_grid_size)
	for x in range(_grid_size):
		_grid[x] = []
		_grid[x].resize(_grid_size)
		for y in range(_grid_size):
			_grid[x][y] = FogState.UNEXPLORED

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_update_visibility()
		queue_redraw()

func _update_visibility() -> void:
	# Fade all VISIBLE to EXPLORED
	for x in range(_grid_size):
		for y in range(_grid_size):
			if _grid[x][y] == FogState.VISIBLE:
				_grid[x][y] = FogState.EXPLORED

	# Reveal around player units and buildings
	for unit in get_tree().get_nodes_in_group("faction_0"):
		if not is_instance_valid(unit):
			continue
		var detect_range: float = 200.0
		if "detection_range" in unit:
			detect_range = unit.detection_range
		elif unit.is_in_group("rts_buildings"):
			detect_range = 250.0
		_reveal_around(unit.global_position, detect_range)

func _reveal_around(world_pos: Vector2, radius: float) -> void:
	var gx: int = int(world_pos.x / CELL_SIZE) + _offset
	var gy: int = int(world_pos.y / CELL_SIZE) + _offset
	var cell_range: int = int(radius / CELL_SIZE) + 1
	for dx in range(-cell_range, cell_range + 1):
		for dy in range(-cell_range, cell_range + 1):
			var cx: int = gx + dx
			var cy: int = gy + dy
			if cx < 0 or cx >= _grid_size or cy < 0 or cy >= _grid_size:
				continue
			var cell_world: Vector2 = Vector2((cx - _offset) * CELL_SIZE, (cy - _offset) * CELL_SIZE)
			if cell_world.distance_to(world_pos) <= radius:
				_grid[cx][cy] = FogState.VISIBLE

func is_pos_visible(world_pos: Vector2) -> bool:
	var gx: int = int(world_pos.x / CELL_SIZE) + _offset
	var gy: int = int(world_pos.y / CELL_SIZE) + _offset
	if gx < 0 or gx >= _grid_size or gy < 0 or gy >= _grid_size:
		return false
	return _grid[gx][gy] == FogState.VISIBLE

func is_explored(world_pos: Vector2) -> bool:
	var gx: int = int(world_pos.x / CELL_SIZE) + _offset
	var gy: int = int(world_pos.y / CELL_SIZE) + _offset
	if gx < 0 or gx >= _grid_size or gy < 0 or gy >= _grid_size:
		return false
	return _grid[gx][gy] != FogState.UNEXPLORED

func get_state(world_pos: Vector2) -> int:
	var gx: int = int(world_pos.x / CELL_SIZE) + _offset
	var gy: int = int(world_pos.y / CELL_SIZE) + _offset
	if gx < 0 or gx >= _grid_size or gy < 0 or gy >= _grid_size:
		return FogState.UNEXPLORED
	return _grid[gx][gy]

func _draw() -> void:
	# Draw fog overlay — only draw non-visible cells near camera for performance
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return
	var cam_pos: Vector2 = camera.global_position
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: float = camera.zoom.x if camera.zoom.x > 0 else 1.0
	var view_half: Vector2 = vp_size / (2.0 * zoom)

	var min_gx: int = int((cam_pos.x - view_half.x) / CELL_SIZE) + _offset - 1
	var max_gx: int = int((cam_pos.x + view_half.x) / CELL_SIZE) + _offset + 1
	var min_gy: int = int((cam_pos.y - view_half.y) / CELL_SIZE) + _offset - 1
	var max_gy: int = int((cam_pos.y + view_half.y) / CELL_SIZE) + _offset + 1

	min_gx = clampi(min_gx, 0, _grid_size - 1)
	max_gx = clampi(max_gx, 0, _grid_size - 1)
	min_gy = clampi(min_gy, 0, _grid_size - 1)
	max_gy = clampi(max_gy, 0, _grid_size - 1)

	for gx in range(min_gx, max_gx + 1):
		for gy in range(min_gy, max_gy + 1):
			var state: int = _grid[gx][gy]
			if state == FogState.VISIBLE:
				continue
			var world_x: float = (gx - _offset) * CELL_SIZE
			var world_y: float = (gy - _offset) * CELL_SIZE
			var alpha: float = 0.85 if state == FogState.UNEXPLORED else 0.4
			draw_rect(Rect2(world_x, world_y, CELL_SIZE, CELL_SIZE), Color(0.0, 0.0, 0.0, alpha))

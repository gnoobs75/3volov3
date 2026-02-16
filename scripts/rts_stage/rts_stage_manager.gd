extends Node2D
## Central orchestrator for the RTS stage. Creates all subsystems, manages game loop.

var _petri_dish: Node2D = null
var _camera: Camera2D = null
var _faction_manager: Node = null
var _resource_manager: Node = null
var _combat_system: Node = null
var _selection_manager: Node = null
var _command_system: Node = null
var _victory_manager: Node = null
var _fog_of_war: Node2D = null
var _ai_directors: Array = []  # One per AI faction

# HUD layer
var _hud_layer: CanvasLayer = null
var _hud: Control = null
var _minimap: Control = null
var _input_handler: Control = null
var _overlay: Control = null
var _intel_overlay: Control = null
var _command_vfx: Node2D = null
var _pause_menu: Control = null

var _time: float = 0.0
var _game_started: bool = false
var _paused: bool = false
var _game_over_shown: bool = false
var _game_over_type: String = ""  # "win" or "lose"

# AI difficulty (0=NOOB, 1=EASY, 2=MEDIUM, 3=HARD, 4=SWEATY)
var ai_difficulty: int = 2

# Navigation
var _nav_region: NavigationRegion2D = null

func _ready() -> void:
	add_to_group("rts_stage")

	# 1. Create map
	_petri_dish = preload("res://scripts/rts_stage/petri_dish_map.gd").new()
	_petri_dish.name = "PetriDishMap"
	_petri_dish.add_to_group("rts_map")
	add_child(_petri_dish)

	# 2. Setup navigation region
	_setup_navigation()

	# 3. Create camera
	_camera = preload("res://scripts/rts_stage/rts_camera.gd").new()
	_camera.name = "RTSCamera"
	add_child(_camera)

	# 4. Create managers
	_faction_manager = preload("res://scripts/rts_stage/faction_manager.gd").new()
	_faction_manager.name = "FactionManager"
	add_child(_faction_manager)

	_resource_manager = preload("res://scripts/rts_stage/resource_manager.gd").new()
	_resource_manager.name = "ResourceManager"
	add_child(_resource_manager)

	_combat_system = preload("res://scripts/rts_stage/combat_system.gd").new()
	_combat_system.name = "CombatSystem"
	add_child(_combat_system)

	_selection_manager = preload("res://scripts/rts_stage/selection_manager.gd").new()
	_selection_manager.name = "SelectionManager"
	add_child(_selection_manager)

	_command_system = preload("res://scripts/rts_stage/command_system.gd").new()
	_command_system.name = "CommandSystem"
	add_child(_command_system)

	_victory_manager = preload("res://scripts/rts_stage/victory_manager.gd").new()
	_victory_manager.name = "VictoryManager"
	add_child(_victory_manager)

	# 5. Create fog of war
	_fog_of_war = preload("res://scripts/rts_stage/rts_fog_of_war.gd").new()
	_fog_of_war.name = "FogOfWar"
	_fog_of_war.z_index = 10  # Above units/buildings
	add_child(_fog_of_war)

	# 6. Create HUD layer
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUD"
	_hud_layer.layer = 5
	add_child(_hud_layer)

	_input_handler = preload("res://scripts/rts_stage/rts_input_handler.gd").new()
	_input_handler.name = "InputHandler"
	_hud_layer.add_child(_input_handler)
	_input_handler.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_hud = preload("res://scripts/rts_stage/rts_hud.gd").new()
	_hud.name = "RtsHUD"
	_hud_layer.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_minimap = preload("res://scripts/rts_stage/rts_minimap.gd").new()
	_minimap.name = "Minimap"
	_hud_layer.add_child(_minimap)
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Intel overlay (TAB toggle)
	_intel_overlay = preload("res://scripts/rts_stage/rts_intel_overlay.gd").new()
	_intel_overlay.name = "IntelOverlay"
	_hud_layer.add_child(_intel_overlay)
	_intel_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intel_overlay.setup(self)

	# Game over overlay
	_overlay = preload("res://scripts/rts_stage/rts_overlay.gd").new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Pause menu
	_pause_menu = preload("res://scripts/rts_stage/rts_pause_menu.gd").new()
	_pause_menu.name = "PauseMenu"
	_hud_layer.add_child(_pause_menu)
	_pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Command VFX layer (world-space)
	_command_vfx = preload("res://scripts/rts_stage/rts_command_vfx.gd").new()
	_command_vfx.name = "CommandVFX"
	_command_vfx.z_index = 5
	add_child(_command_vfx)

	# 7. Initialize systems
	_faction_manager.setup_factions()
	_resource_manager.setup(4)
	_victory_manager.setup(self)
	_input_handler.setup(_selection_manager, _command_system, _camera, self)
	_hud.setup(self, _selection_manager, _command_system)
	_minimap.setup(self, _camera)

	# 8. Connect signals
	_victory_manager.game_won.connect(_on_game_won)
	_victory_manager.game_lost.connect(_on_game_lost)
	_victory_manager.faction_eliminated_announcement.connect(_on_faction_eliminated)
	_combat_system.unit_killed.connect(_on_unit_killed)
	_faction_manager.faction_eliminated.connect(_on_faction_eliminated_check)
	_command_system.command_issued.connect(_on_command_issued)

	# 9. Spawn resources on map (including NPC dangers)
	_petri_dish.spawn_resources()

	# 10b. Connect NPC creature death signals for stats
	for npc in _petri_dish.npc_creatures:
		if is_instance_valid(npc):
			npc.died.connect(_on_unit_died)

	# 10. Setup starting bases for all 4 factions
	_setup_starting_bases()

	# 11. Create AI directors for factions 1-3
	for fid in [1, 2, 3]:
		var ai := preload("res://scripts/rts_stage/ai_director.gd").new()
		ai.name = "AIDirector_%d" % fid
		ai.setup(fid, self, ai_difficulty)
		add_child(ai)
		_ai_directors.append(ai)

	# 12. Focus camera on player spawn
	_camera.focus_position(_petri_dish.spawn_positions[0])

	_game_started = true

func _setup_navigation() -> void:
	_nav_region = NavigationRegion2D.new()
	_nav_region.name = "NavigationRegion"
	# Create a large circular navigation polygon
	var nav_poly := NavigationPolygon.new()
	var outline := PackedVector2Array()
	var num_pts: int = 64
	for i in range(num_pts):
		var angle: float = TAU * float(i) / float(num_pts)
		outline.append(Vector2(cos(angle), sin(angle)) * 7900.0)  # Slightly inside map boundary
	nav_poly.add_outline(outline)
	var source_geo := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(nav_poly, source_geo, self)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geo)
	_nav_region.navigation_polygon = nav_poly
	add_child(_nav_region)

func _setup_starting_bases() -> void:
	for fid in range(4):
		var spawn_pos: Vector2 = _petri_dish.spawn_positions[fid]
		var template: CreatureTemplate = _faction_manager.get_template(fid)

		# Create Spawning Pool (pre-built)
		var pool := _create_building(fid, BuildingStats.BuildingType.SPAWNING_POOL, spawn_pos, template, true)

		# Spawn 3 starting workers
		for i in range(3):
			var offset: Vector2 = Vector2(randf_range(-50, 50), randf_range(-50, 50))
			_spawn_unit(fid, UnitStats.UnitType.WORKER, spawn_pos + offset, template)

func _create_building(fid: int, btype: int, pos: Vector2, template: CreatureTemplate, pre_built: bool = false) -> Node2D:
	var building: StaticBody2D = preload("res://scripts/rts_stage/rts_building.gd").new()
	building.name = "Building_%d_%d_%d" % [fid, btype, randi() % 10000]
	building.global_position = pos
	building.setup(fid, btype, template, pre_built)
	building.destroyed.connect(_on_building_destroyed)
	building.unit_produced.connect(_on_unit_produced)
	add_child(building)
	return building

func _spawn_unit(fid: int, utype: int, pos: Vector2, template: CreatureTemplate) -> Node2D:
	var unit: CharacterBody2D = preload("res://scripts/rts_stage/rts_unit.gd").new()
	unit.name = "Unit_%d_%d_%d" % [fid, utype, randi() % 10000]
	unit.global_position = pos
	add_child(unit)
	unit.setup(fid, utype, template)
	unit.died.connect(_on_unit_died)
	return unit

func _process(delta: float) -> void:
	if not _game_started or _game_over_shown:
		return
	_time += delta
	# Check victory periodically
	if int(_time * 2) % 3 == 0:
		_victory_manager.check_victory()

# === PUBLIC API ===

func get_resource_manager() -> Node:
	return _resource_manager

func get_faction_manager() -> Node:
	return _faction_manager

func get_combat_system() -> Node:
	return _combat_system

func get_input_handler() -> Control:
	return _input_handler

func toggle_intel_overlay() -> void:
	if _intel_overlay and _intel_overlay.has_method("toggle"):
		_intel_overlay.toggle()

func set_ai_difficulty(diff: int) -> void:
	ai_difficulty = diff
	for ai in _ai_directors:
		if is_instance_valid(ai) and ai.has_method("set_difficulty"):
			ai.set_difficulty(diff)

# === BUILDING PLACEMENT ===

func place_building(building_type: int, pos: Vector2) -> void:
	## Place a player building (faction 0)
	var cost: Dictionary = BuildingStats.get_cost(building_type)
	if not _resource_manager.spend(0, cost.get("biomass", 0), cost.get("genes", 0)):
		return
	var template: CreatureTemplate = _faction_manager.get_template(0)
	var building: Node2D = _create_building(0, building_type, pos, template, false)
	# Send nearest selected worker to build
	var workers: Array = _selection_manager.get_selected_workers()
	if not workers.is_empty():
		var nearest_worker: Node2D = workers[0]
		var nearest_dist: float = INF
		for w in workers:
			if is_instance_valid(w):
				var dist: float = w.global_position.distance_to(pos)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_worker = w
		if nearest_worker.has_method("command_build"):
			nearest_worker.command_build(building)
	AudioManager.play_rts_build_place()

func ai_place_building(faction_id: int, building_type: int) -> void:
	## AI building placement — near base with offset
	var cost: Dictionary = BuildingStats.get_cost(building_type)
	if not _resource_manager.spend(faction_id, cost.get("biomass", 0), cost.get("genes", 0)):
		return
	var template: CreatureTemplate = _faction_manager.get_template(faction_id)
	var base_pos: Vector2 = _petri_dish.spawn_positions[faction_id]

	# Find open position near base
	var pos: Vector2 = base_pos + Vector2(randf_range(-150, 150), randf_range(-150, 150))
	# Avoid overlap
	for _attempt in range(10):
		var too_close: bool = false
		for building in get_tree().get_nodes_in_group("rts_buildings"):
			if is_instance_valid(building) and building.global_position.distance_to(pos) < 60.0:
				too_close = true
				break
		if not too_close:
			break
		pos = base_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200))

	var building: Node2D = _create_building(faction_id, building_type, pos, template, false)
	# Find idle worker to build
	for unit in get_tree().get_nodes_in_group("faction_%d" % faction_id):
		if unit.is_in_group("rts_units") and "unit_type" in unit and unit.unit_type == UnitStats.UnitType.WORKER:
			if "state" in unit and unit.state == 0:  # IDLE
				if unit.has_method("command_build"):
					unit.command_build(building)
					break

# === SIGNAL HANDLERS ===

func _on_unit_produced(building: Node2D, unit_type: int) -> void:
	var fid: int = building.faction_id if "faction_id" in building else 0
	if not _faction_manager.can_afford_supply(fid, unit_type):
		return
	var template: CreatureTemplate = _faction_manager.get_template(fid)
	var offset: Vector2 = Vector2(randf_range(-30, 30), randf_range(30, 60))
	var unit: Node2D = _spawn_unit(fid, unit_type, building.global_position + offset, template)
	# Track stats
	if fid == 0:
		_victory_manager.stats_units_produced += 1
	# If building has a rally point set, command the unit to move there
	if "has_rally_point" in building and building.has_rally_point:
		if is_instance_valid(unit) and unit.has_method("command_move"):
			unit.command_move(building.rally_point)

func _on_unit_died(unit: Node2D) -> void:
	_selection_manager.remove_unit(unit)
	var fid: int = unit.faction_id if "faction_id" in unit else 0
	if fid == 0:
		_victory_manager.stats_units_lost += 1
	# Delayed elimination check (only for real factions 0-3)
	if fid >= 0 and fid <= 3:
		call_deferred("_check_faction_elimination", fid)

func _on_unit_killed(unit: Node2D, _killer: Node2D) -> void:
	AudioManager.play_rts_unit_death()
	var fid: int = unit.faction_id if "faction_id" in unit else 0
	# Track enemy kills by player
	if _killer and is_instance_valid(_killer) and "faction_id" in _killer and _killer.faction_id == 0 and fid != 0:
		_victory_manager.stats_enemies_killed += 1
	# Minimap attack ping when player unit is killed
	if fid == 0 and is_instance_valid(unit) and _minimap and _minimap.has_method("add_attack_ping"):
		_minimap.add_attack_ping(unit.global_position)

func _on_building_destroyed(building: Node2D) -> void:
	var fid: int = building.faction_id if "faction_id" in building else 0
	call_deferred("_check_faction_elimination", fid)

func _check_faction_elimination(fid: int) -> void:
	_faction_manager.check_elimination(fid)

func _on_faction_eliminated_check(_fid: int) -> void:
	_victory_manager.check_victory()

func _on_command_issued(command: String, target_pos: Vector2) -> void:
	if not _command_vfx:
		return
	match command:
		"move": _command_vfx.add_move_indicator(target_pos)
		"attack_move": _command_vfx.add_attack_indicator(target_pos)
		"gather": _command_vfx.add_gather_indicator(target_pos)

func _on_faction_eliminated(fid: int, fname: String) -> void:
	if _overlay and _overlay.has_method("show_elimination"):
		_overlay.show_elimination(fname)

func _on_game_won() -> void:
	_game_over_shown = true
	if _overlay and _overlay.has_method("show_victory"):
		_overlay.show_victory(_victory_manager.get_game_time())

func _on_game_lost() -> void:
	_game_over_shown = true
	if _overlay and _overlay.has_method("show_defeat"):
		_overlay.show_defeat(_victory_manager.get_game_time())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _game_over_shown:
			GameManager.go_to_menu()
		elif _pause_menu:
			_pause_menu.toggle()
		get_viewport().set_input_as_handled()

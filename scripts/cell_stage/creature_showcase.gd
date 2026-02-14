extends Node2D
## Creature Showcase Cinematic — Alien observer discovers the ecosystem.
## 8-phase educational experience (~52s) that spawns creatures on-demand,
## pans the camera between vignettes, and hides the player until the finale.
## After completion, emits showcase_finished signal for tutorial to begin.

signal showcase_finished

const DUMMY_SCENE := preload("res://scenes/showcase_dummy.tscn")
const VIRUS_SCENE := preload("res://scenes/virus_organism.tscn")
const PARASITE_SCENE := preload("res://scenes/parasite_organism.tscn")
const DART_SCENE := preload("res://scenes/dart_predator.tscn")
const SNAKE_SCENE := preload("res://scenes/snake_prey.tscn")
const FOOD_SCENE := preload("res://scenes/food_particle.tscn")
const COMPETITOR_SCENE := preload("res://scenes/competitor_cell.tscn")
const REPELLER_SCENE := preload("res://scenes/repeller_organism.tscn")

var _player: CharacterBody2D = null
var _camera: Camera2D = null
var _time: float = 0.0
var _phase: int = -1  # Start at -1 so first _advance_phase sets it to 0
var _phase_timer: float = 0.0
var _camera_offset_target: Vector2 = Vector2.ZERO
var _camera_offset_current: Vector2 = Vector2.ZERO

# Spawned entities for cleanup between phases
var _spawned_entities: Array[Node2D] = []

# Text display
var _title_text: String = ""
var _body_lines: Array = []
var _observer_text: String = ""
var _title_alpha: float = 0.0
var _body_alpha: float = 0.0
var _observer_alpha: float = 0.0

# Overlay for drawing text on screen
var _overlay: Control = null

# Skip mechanic — hold spacebar for 2 seconds
var _skip_hold: float = 0.0
const SKIP_HOLD_REQUIRED: float = 2.0

# HUD integration — science desk comes alive during showcase
var _observer_notes: Control = null
var _creature_viewer: Control = null
var _helix_hud: Control = null
var _helix_flash_index: int = -1  # For staggered helix flash during Phase 1
var _helix_flash_timer: float = 0.0

# Phase definitions
var _phases: Array = [
	# Phase 0: Opening narration
	{
		"dur": 7.0, "offset": Vector2.ZERO,
		"title": "FIELD LOG: Entry 1",
		"body": ["Initiating micro-scale observation...", "A thriving ecosystem detected.", "Recording specimens for analysis."],
		"observer": "",
		"spawns": "none",
	},
	# Phase 1: Biomolecules (food)
	{
		"dur": 10.0, "offset": Vector2(300, 0),
		"title": "BUILDING BLOCKS",
		"body": ["Biomolecules: raw energy and growth fuel.", "Collect with organic vacuum [LMB].", "Organelles grant evolution progress."],
		"observer": "Abundant molecular resources...",
		"spawns": "food",
	},
	# Phase 2: Snake prey
	{
		"dur": 10.0, "offset": Vector2(300, -300),
		"title": "EDIBLE WORMS",
		"body": ["Snake prey: slow, nutritious organisms.", "Use your organic vacuum [LMB] to consume them.", "Great source of health and energy."],
		"observer": "Easy pickings for a hunter...",
		"spawns": "snake_prey",
	},
	# Phase 3: Virus
	{
		"dur": 10.0, "offset": Vector2(0, -300),
		"title": "VIRAL AGENT",
		"body": ["Attaches to host cells and drains vitality.", "Geometric protein shell resists damage.", "Avoid or outrun — don't let them latch."],
		"observer": "Fascinating pathogen...",
		"spawns": "virus",
	},
	# Phase 4: Parasite
	{
		"dur": 10.0, "offset": Vector2(-300, -300),
		"title": "PARASITIC WORM",
		"body": ["Latches on and feeds off the host.", "Five attached means total takeover.", "Outrun them or lure them through a Cleansing Anemone."],
		"observer": "Disturbing symbiosis...",
		"spawns": "parasite",
	},
	# Phase 5: Repeller / Cleanser
	{
		"dur": 11.0, "offset": Vector2(-300, -150),
		"title": "CLEANSING ANEMONE",
		"body": ["This purple organism repels parasites.", "Swim through it to cleanse latched parasites.", "Symbiotic allies can also eat parasites off you."],
		"observer": "A natural remedy...",
		"spawns": "repeller_demo",
	},
	# Phase 6: Dart predator
	{
		"dur": 10.0, "offset": Vector2(-300, 0),
		"title": "APEX HUNTER",
		"body": ["Stalks prey, then lunges at lethal speed.", "Hit-and-run predator — very dangerous.", "Sprint [SHIFT] away if one targets you."],
		"observer": "Remarkable speed!",
		"spawns": "dart_predator",
	},
	# Phase 7: Competitor
	{
		"dur": 11.0, "offset": Vector2(0, 300),
		"title": "RIVAL ORGANISM",
		"body": ["Neutral competitor collecting the same food.", "Won't attack, but steals your resources.", "Soon it will be your turn to compete."],
		"observer": "The struggle for survival...",
		"spawns": "competitor",
	},
	# Phase 8: Final message (player stays hidden — editor will handle reveal)
	{
		"dur": 5.0, "offset": Vector2.ZERO,
		"title": "",
		"body": ["Your specimen awaits configuration.", "Design. Survive. Evolve. Dominate."],
		"observer": "What kind of creature is this...?",
		"spawns": "none",
	},
]

func setup(player: CharacterBody2D) -> void:
	_player = player
	_camera = player.get_node_or_null("Camera2D")
	_hide_player()

func _hide_player() -> void:
	if not _player:
		return
	_player.visible = false
	_player.input_disabled = true
	if _player.is_in_group("player"):
		_player.remove_from_group("player")
	# Disable collision shapes
	var col := _player.get_node_or_null("CollisionShape2D")
	if col:
		col.disabled = true
	# Stop camera shake from overwriting offset
	if _camera:
		_camera.set_process(false)

func _reveal_player() -> void:
	if not _player:
		return
	_player.visible = true
	_player.input_disabled = false
	if not _player.is_in_group("player"):
		_player.add_to_group("player")
	# Re-enable collision shapes
	var col := _player.get_node_or_null("CollisionShape2D")
	if col:
		col.disabled = false
	# Re-enable camera shake processing
	if _camera:
		_camera.set_process(true)

func _find_hud_components() -> void:
	# Observer notes is in a group
	var notes := get_tree().get_nodes_in_group("observer_notes")
	if notes.size() > 0:
		_observer_notes = notes[0]
	# Creature viewer and helix via parent's HUD tree
	var stage := get_parent()
	if stage:
		_creature_viewer = stage.get_node_or_null("HUD/ThreePaneLayout/RightPane/RightVBox/CreatureViewer")
		_helix_hud = stage.get_node_or_null("HUD/ThreePaneLayout/LeftPane/LeftVBox/HelixHUD")

func _trigger_hud_for_phase() -> void:
	match _phase:
		0:  # Opening — observer starts scribing
			_queue_observer_note("Observation")
			_queue_observer_note("Observation")
			AudioManager.play_observer_mutter()
		1:  # Food / Building Blocks — light up the helix
			_queue_observer_note("Collection")
			_helix_flash_index = 0
			_helix_flash_timer = 0.0
			AudioManager.play_observer_chirp()
		2:  # Snake prey
			_show_creature_blueprint("prey")
			_queue_observer_note("Kill")
			AudioManager.play_observer_grunt()
		3:  # Virus
			_show_creature_blueprint("virus")
			_queue_observer_note("Damage")
			AudioManager.play_observer_hmm()
		4:  # Parasite
			_show_creature_blueprint("parasite")
			_queue_observer_note("Damage")
			AudioManager.play_observer_distressed()
		5:  # Repeller / Cleanser
			_queue_observer_note("Observation")
			_queue_observer_note("Collection")
			AudioManager.play_observer_chirp()
		6:  # Dart predator
			_show_creature_blueprint("dart_predator")
			_queue_observer_note("Kill")
			AudioManager.play_observer_gasp()
		7:  # Competitor
			_show_creature_blueprint("competitor")
			_queue_observer_note("Observation")
			AudioManager.play_observer_mutter()
		8:  # Reveal player
			_queue_observer_note("Evolution")
			_queue_observer_note("Evolution")
			AudioManager.play_observer_impressed()

func _queue_observer_note(event_type: String) -> void:
	if _observer_notes and _observer_notes.has_method("_queue_note"):
		_observer_notes._queue_note(event_type)

func _show_creature_blueprint(type: String) -> void:
	if _creature_viewer and _creature_viewer.has_method("_capture_generic_specimen"):
		_creature_viewer._trigger_cooldown = 0.0  # Bypass cooldown for showcase
		_creature_viewer._capture_generic_specimen(type)

func _flash_helix_category(index: int) -> void:
	if not _helix_hud or index < 0:
		return
	var defs: Array = _helix_hud.DEFS
	if index >= defs.size():
		return
	var key: String = defs[index].key
	_helix_hud._flash[key] = 1.0
	_helix_hud._flash_active = true
	_helix_hud.queue_redraw()

func _ready() -> void:
	# Create screen overlay for text
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 9  # Above HUD, below EvolutionUI
	overlay_layer.name = "ShowcaseOverlay"
	add_child(overlay_layer)

	var OverlayScript := preload("res://scripts/cell_stage/screen_overlay.gd")
	_overlay = Control.new()
	_overlay.set_script(OverlayScript)
	_overlay.name = "ShowcaseText"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw_callback = _draw_overlay
	overlay_layer.add_child(_overlay)

	# Find HUD components then start first phase (deferred order matters)
	call_deferred("_find_hud_components")
	call_deferred("_advance_phase")

func _advance_phase() -> void:
	# Clean up previous phase's entities
	for entity in _spawned_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	_spawned_entities.clear()

	_phase += 1
	_phase_timer = 0.0
	_title_alpha = 0.0
	_body_alpha = 0.0
	_observer_alpha = 0.0

	if _phase >= _phases.size():
		_finish_showcase()
		return

	var pd: Dictionary = _phases[_phase]
	_camera_offset_target = pd.offset
	_title_text = pd.title
	_body_lines = pd.body.duplicate() if pd.has("body") else []
	_observer_text = pd.observer

	# Spawn entities for this phase
	_spawn_for_phase(pd.spawns)

	# Trigger HUD science desk for this phase
	_trigger_hud_for_phase()

func _spawn_for_phase(spawn_type: String) -> void:
	if not _player:
		return
	var origin: Vector2 = _player.global_position
	var pd: Dictionary = _phases[_phase]
	var center: Vector2 = origin + pd.offset

	match spawn_type:
		"food":
			for i in range(8):
				var food := FOOD_SCENE.instantiate()
				food.setup(BiologyLoader.get_random_biomolecule(), i == 7)  # Last one is organelle
				food.global_position = center + Vector2(randf_range(-80, 80), randf_range(-60, 60))
				food.add_to_group("food")
				add_child(food)
				_spawned_entities.append(food)

		"snake_prey":
			for i in range(3):
				var prey := SNAKE_SCENE.instantiate()
				prey.global_position = center + Vector2(randf_range(-60, 60), randf_range(-40, 40))
				add_child(prey)
				_spawned_entities.append(prey)

		"virus":
			var dummy := DUMMY_SCENE.instantiate()
			dummy.global_position = center + Vector2(20, 10)
			add_child(dummy)
			_spawned_entities.append(dummy)
			for i in range(2):
				var virus := VIRUS_SCENE.instantiate()
				virus.global_position = center + Vector2(-40 + i * 70, -30 + i * 20)
				add_child(virus)
				_spawned_entities.append(virus)

		"parasite":
			var dummy := DUMMY_SCENE.instantiate()
			dummy.global_position = center + Vector2(10, 0)
			add_child(dummy)
			_spawned_entities.append(dummy)
			for i in range(3):
				var angle: float = TAU * i / 3.0
				var parasite := PARASITE_SCENE.instantiate()
				parasite.global_position = center + Vector2(cos(angle) * 50, sin(angle) * 50)
				add_child(parasite)
				_spawned_entities.append(parasite)

		"repeller_demo":
			# Purple repeller in center with parasites nearby + a dummy victim
			var repeller := REPELLER_SCENE.instantiate()
			repeller.global_position = center
			add_child(repeller)
			_spawned_entities.append(repeller)
			# Dummy cell with parasites approaching it
			var dummy := DUMMY_SCENE.instantiate()
			dummy.global_position = center + Vector2(50, 20)
			add_child(dummy)
			_spawned_entities.append(dummy)
			for i in range(3):
				var parasite := PARASITE_SCENE.instantiate()
				parasite.global_position = center + Vector2(randf_range(-70, 70), randf_range(-50, 50))
				add_child(parasite)
				_spawned_entities.append(parasite)

		"dart_predator":
			var prey := SNAKE_SCENE.instantiate()
			prey.global_position = center + Vector2(50, 20)
			add_child(prey)
			_spawned_entities.append(prey)
			var dart := DART_SCENE.instantiate()
			dart.global_position = center + Vector2(-60, -30)
			add_child(dart)
			_spawned_entities.append(dart)

		"competitor":
			var comp := COMPETITOR_SCENE.instantiate()
			comp.global_position = center + Vector2(-30, 0)
			add_child(comp)
			_spawned_entities.append(comp)
			for i in range(5):
				var food := FOOD_SCENE.instantiate()
				food.setup(BiologyLoader.get_random_biomolecule(), false)
				food.global_position = center + Vector2(randf_range(-70, 70), randf_range(-50, 50))
				food.add_to_group("food")
				add_child(food)
				_spawned_entities.append(food)

		"reveal":
			_reveal_player()

func _process(delta: float) -> void:
	_time += delta
	_phase_timer += delta

	# Skip mechanic: hold spacebar
	if Input.is_key_pressed(KEY_SPACE):
		_skip_hold += delta
		if _skip_hold >= SKIP_HOLD_REQUIRED:
			_phase = _phases.size()
			_finish_showcase()
			return
	else:
		_skip_hold = move_toward(_skip_hold, 0.0, delta * 2.0)

	if _phase < 0 or _phase >= _phases.size():
		return

	var pd: Dictionary = _phases[_phase]
	var dur: float = pd.dur

	# Smooth camera pan
	_camera_offset_current = _camera_offset_current.lerp(_camera_offset_target, delta * 2.5)
	if _camera:
		_camera.offset = _camera_offset_current

	# Title fade in/out
	var title_show: bool = _title_text != "" and _phase_timer > 0.4 and _phase_timer < dur - 0.8
	_title_alpha = move_toward(_title_alpha, 1.0 if title_show else 0.0, delta * 3.0)

	# Body text: staggered fade in, then out near end
	var body_show: bool = _phase_timer > 0.8 and _phase_timer < dur - 0.6
	_body_alpha = move_toward(_body_alpha, 1.0 if body_show else 0.0, delta * 2.5)

	# Observer text (delayed)
	var obs_show: bool = _observer_text != "" and _phase_timer > 1.8 and _phase_timer < dur - 0.5
	_observer_alpha = move_toward(_observer_alpha, 1.0 if obs_show else 0.0, delta * 2.5)

	# Mid-phase observer vocalization (~5s in, after cooldown clears)
	if _phase_timer > 5.0 and _phase_timer < 5.0 + delta * 2.0:
		match _phase:
			1:  AudioManager.play_observer_grunt()
			2:  AudioManager.play_observer_mutter()
			4:  AudioManager.play_observer_grunt()
			5:  AudioManager.play_observer_mutter()
			7:  AudioManager.play_observer_grunt()

	# Staggered helix flash during Phase 1 (Building Blocks)
	if _phase == 1 and _helix_flash_index >= 0 and _helix_flash_index < 8:
		_helix_flash_timer += delta
		if _helix_flash_timer >= 1.0:  # Flash one category per second
			_flash_helix_category(_helix_flash_index)
			_helix_flash_index += 1
			_helix_flash_timer = 0.0

	# Advance phase
	if _phase_timer >= dur:
		_advance_phase()

	# Keep overlay redrawing
	if _overlay:
		_overlay.queue_redraw()

func _finish_showcase() -> void:
	# Clean up any remaining entities
	for entity in _spawned_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	_spawned_entities.clear()

	# Reset camera offset smoothly
	if _camera:
		_camera.offset = Vector2.ZERO

	# Player stays hidden — the creature editor opens next and handles reveal
	showcase_finished.emit()

	# Self-destruct after a short delay for final fade
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _draw_overlay(ctl: Control) -> void:
	var vp := ctl.get_viewport_rect().size
	var font := UIConstants.get_display_font()

	# --- Title: top-center with accent pill ---
	if _title_text != "" and _title_alpha > 0.01:
		var title_fs: int = 26
		var ts := font.get_string_size(_title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, title_fs)
		var tx: float = (vp.x - ts.x) * 0.5
		var ty: float = vp.y * 0.16

		# Background pill
		var pill_w: float = ts.x + 60
		var pill_h: float = 45
		ctl.draw_rect(Rect2(tx - 30, ty - 30, pill_w, pill_h), Color(0.08, 0.10, 0.18, 0.78 * _title_alpha))
		# Accent lines
		ctl.draw_rect(Rect2(tx - 30, ty - 31, pill_w, 1), Color(0.4, 0.7, 1.0, 0.5 * _title_alpha))
		ctl.draw_rect(Rect2(tx - 30, ty + 14, pill_w, 1), Color(0.4, 0.7, 1.0, 0.5 * _title_alpha))
		# Title text
		ctl.draw_string(font, Vector2(tx, ty), _title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_fs, Color(0.5, 0.9, 1.0, _title_alpha))

	# --- Body text: multi-line below title ---
	if _body_lines.size() > 0 and _body_alpha > 0.01:
		var body_fs: int = 14
		var start_y: float = vp.y * 0.22
		for i in range(_body_lines.size()):
			# Stagger each line slightly
			var line_alpha: float = clampf((_body_alpha - i * 0.15) / 0.7, 0.0, 1.0)
			if line_alpha <= 0.01:
				continue
			var line_text: String = _body_lines[i]
			var ls := font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_CENTER, -1, body_fs)
			var lx: float = (vp.x - ls.x) * 0.5
			var ly: float = start_y + i * 22.0
			ctl.draw_string(font, Vector2(lx, ly), line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, body_fs, Color(0.5, 0.7, 0.8, 0.85 * line_alpha * _body_alpha))

	# --- Observer narration: bottom-right italic ---
	if _observer_text != "" and _observer_alpha > 0.01:
		var obs_fs: int = 16
		var full_text: String = "\"" + _observer_text + "\""
		var os := font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, obs_fs)
		var ox: float = vp.x * 0.7 - os.x * 0.5
		var oy: float = vp.y * 0.82

		# Subtle background
		ctl.draw_rect(Rect2(ox - 15, oy - 18, os.x + 30, 28), Color(0.03, 0.05, 0.08, 0.6 * _observer_alpha))
		# Observer text with quote marks
		ctl.draw_string(font, Vector2(ox, oy), full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, obs_fs, Color(0.8, 0.7, 0.4, _observer_alpha))

	# --- Skip indicator: bottom-center ---
	var skip_text := "Hold SPACE to skip"
	var skip_fs: int = 13
	var skip_ts := font.get_string_size(skip_text, HORIZONTAL_ALIGNMENT_CENTER, -1, skip_fs)
	var skip_x: float = (vp.x - skip_ts.x) * 0.5
	var skip_y: float = vp.y * 0.94
	var skip_base_alpha: float = 0.4 + 0.15 * sin(_time * 2.0)  # Gentle pulse
	ctl.draw_string(font, Vector2(skip_x, skip_y), skip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, skip_fs, Color(0.5, 0.6, 0.7, skip_base_alpha))

	# Filling circle when holding spacebar
	if _skip_hold > 0.05:
		var circle_x: float = skip_x - 20.0
		var circle_y: float = skip_y - 5.0
		var circle_r: float = 8.0
		var fill_ratio: float = clampf(_skip_hold / SKIP_HOLD_REQUIRED, 0.0, 1.0)
		# Background ring
		ctl.draw_arc(Vector2(circle_x, circle_y), circle_r, 0, TAU, 32, Color(0.3, 0.4, 0.5, 0.4), 2.0)
		# Filling arc (clockwise from top)
		if fill_ratio > 0.01:
			var fill_angle: float = fill_ratio * TAU
			ctl.draw_arc(Vector2(circle_x, circle_y), circle_r, -PI / 2.0, -PI / 2.0 + fill_angle, 32, Color(0.4, 0.85, 1.0, 0.9), 2.5)

	# --- Cinematic letterbox bars (thin, at absolute edges) ---
	var bar_h: float = vp.y * 0.03
	var bar_alpha: float = 0.8
	# Fade out bars during final phase
	if _phase >= _phases.size() - 1 and _phase >= 0:
		bar_alpha *= clampf(1.0 - _phase_timer / 2.0, 0.0, 1.0)
	elif _phase >= _phases.size():
		bar_alpha = 0.0
	ctl.draw_rect(Rect2(0, 0, vp.x, bar_h), Color(0.0, 0.0, 0.0, bar_alpha))
	ctl.draw_rect(Rect2(0, vp.y - bar_h, vp.x, bar_h), Color(0.0, 0.0, 0.0, bar_alpha))

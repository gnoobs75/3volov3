extends CanvasLayer
## Unified Creature Editor — handles both initial customization and evolution upgrades.
## Modes: CARD_SELECT (pick 1 of 3 cards at bottom), CUSTOMIZE (full editor with preview + color picker).
## Pauses game. Player interacts. Game resumes on save.

signal initial_customization_completed

enum EditorMode { CARD_SELECT, CUSTOMIZE }

const CARD_WIDTH: float = 210.0
const CARD_HEIGHT: float = 280.0
const CARD_SPACING: float = 24.0
const SMALL_CARD_W: float = 170.0
const SMALL_CARD_H: float = 200.0

# Ring handle constants
const RING_RADIUS: float = 34.0  # Ring drawn around selected mutation
const RING_HANDLE_R: float = 6.5  # Handle grab radius
const RING_COLOR: Color = Color(0.3, 0.8, 1.0, 0.6)
const RING_HOVER_COLOR: Color = Color(0.5, 1.0, 1.0, 0.9)
const HANDLE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const HANDLE_HOVER_COLOR: Color = Color(1.0, 1.0, 0.3, 1.0)
const SCALE_HANDLE_COLOR: Color = Color(0.3, 1.0, 0.5, 0.85)
const SCALE_HANDLE_HOVER: Color = Color(0.5, 1.0, 0.3, 1.0)

# Alien glyphs for sci-fi labels (matching organism_card.gd aesthetic)
const ALIEN_GLYPHS: Array = [
	"◊", "∆", "Ω", "Σ", "Φ", "Ψ", "λ", "π", "θ", "ξ",
	"╬", "╫", "╪", "┼", "╋", "╂", "╁", "╀", "┿", "┾",
	"⊕", "⊗", "⊙", "⊚", "⊛", "⊜", "⊝", "⊞", "⊟", "⊠",
]

var _active: bool = false
var _mode: EditorMode = EditorMode.CARD_SELECT
var _choices: Array[Dictionary] = []
var _category: String = ""
var _hover_index: int = -1
var _time: float = 0.0
var _appear_t: float = 0.0
var _card_draw: Control = null
var _bg_particles: Array = []
var _selected_index: int = -1
var _select_anim: float = 0.0
var _flash_alpha: float = 0.0
var _prev_hover: int = -1
var _is_initial_customize: bool = false  # True if opened from tutorial

# Golden card state
var _is_golden_evolution: bool = false
var _golden_card: Dictionary = {}
var _golden_hover: bool = false
var _golden_selected: bool = false
var _golden_sparkles: Array = []  # [{pos, vel, life, angle}]

# Cards pending selection (merged into customize mode)
var _cards_pending: bool = false

# Freeform placement state (Spore-style)
var _sidebar_hover: int = -1
var _sidebar_scroll: int = 0
var _is_dragging: bool = false
var _dragging_mutation: Dictionary = {}
var _drag_source: String = ""  # "palette" or "placed"
var _drag_pos: Vector2 = Vector2.ZERO
var _drag_ghost_angle: float = 0.0

# Selected placed mutation for rotation ring
var _selected_mutation_id: String = ""
var _hover_placed_mutation: String = ""  # mutation_id under cursor
var _hover_angle: float = 0.0
var _hover_mutation_id: String = ""  # for scaling

# Ring handle interaction
var _ring_drag_mode: String = ""  # "", "rotate", "scale"
var _ring_drag_start_angle: float = 0.0
var _ring_drag_start_value: float = 0.0
var _ring_hover_handle: String = ""  # "", "rotate", "scale_0".."scale_3"

# Symmetry toggle
var _symmetry_enabled: bool = true

# Placement particles
var _place_particles: Array = []  # [{pos, vel, life, color}]

# Preview zoom
var _preview_zoom: float = 5.0

# Creature preview + color picker
var _preview: Control = null
var _color_picker: Control = null

# Confirm/Save button
var _confirm_hover: bool = false

# Tooltip state
var _tooltip_alpha: float = 0.0
var _tooltip_target_index: int = -1  # Which card tooltip is showing for
var _tooltip_golden: bool = false  # Is tooltip for golden card

# Eye drag state
var _dragging_eye: bool = false
var _dragging_eye_index: int = -1  # index into eyes array

# Morph handle drag state
var _dragging_morph_handle: int = -1  # -1 = not dragging, 0-7 = handle index
var _eye_selected: bool = false
var _eye_drag_hint_timer: float = 3.0  # Fades "DRAG TO MOVE" hint

# Sci-fi background state
var _glyph_columns: Array = []  # [{x, glyphs, offset, speed, alpha}]
var _scan_line_y: float = 0.0
var _diagram_rot: Array = [0.0, 0.0]
var _helix_phase: float = 0.0
var _scifi_initialized: bool = false

func _ready() -> void:
	visible = false
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.evolution_triggered.connect(_on_evolution_triggered)
	_card_draw = Control.new()
	_card_draw.name = "CardDraw"
	_card_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_draw.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_draw.draw.connect(_draw_ui)
	_card_draw.gui_input.connect(_on_gui_input)
	add_child(_card_draw)

## Open for initial creature customization (after tutorial, no cards)
func open_initial_customization() -> void:
	if _active:
		return
	_active = true
	_is_initial_customize = true
	_mode = EditorMode.CUSTOMIZE
	_choices = []
	_appear_t = 0.0
	_flash_alpha = 0.5
	visible = true
	get_tree().paused = true
	_setup_preview()
	_setup_color_picker()
	AudioManager.play_ui_open()

func _on_evolution_triggered(category_key: String) -> void:
	if _active:
		return
	_category = category_key
	_choices = EvolutionData.generate_choices(category_key, GameManager.evolution_level)
	if _choices.is_empty():
		return
	_active = true
	_is_initial_customize = false
	_mode = EditorMode.CUSTOMIZE
	_cards_pending = true
	_appear_t = 0.0
	_hover_index = -1
	_prev_hover = -1
	_selected_index = -1
	_select_anim = 0.0
	_flash_alpha = 1.0
	# Check if this is a golden evolution (every 3rd level: 2, 5, 8, 11...)
	_is_golden_evolution = (GameManager.evolution_level % 3 == 2)
	_golden_hover = false
	_golden_selected = false
	if _is_golden_evolution:
		_golden_card = GoldenCardData.generate_golden_choice(GameManager.equipped_golden_card)
		_golden_sparkles.clear()
	else:
		_golden_card = {}
	visible = true
	get_tree().paused = true
	_setup_preview()
	_setup_color_picker()
	AudioManager.play_evolution_fanfare()
	AudioManager.play_ui_open()

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_appear_t = minf(_appear_t + delta * 3.0, 1.0)
	_flash_alpha = maxf(_flash_alpha - delta * 3.0, 0.0)

	# Card selection animation (legacy CARD_SELECT path — kept for safety)
	if _mode == EditorMode.CARD_SELECT and _selected_index >= 0:
		_select_anim += delta * 4.0
		if _select_anim >= 1.0:
			_enter_customize_mode()
			return
	if _mode == EditorMode.CARD_SELECT and _golden_selected:
		_select_anim += delta * 4.0
		if _select_anim >= 1.0:
			GameManager.equipped_golden_card = _golden_card.get("id", "")
			_enter_customize_mode()
			return

	# Spawn golden sparkles around golden card
	if _is_golden_evolution and _cards_pending and randf() < 0.4:
		var gr := _get_golden_card_rect()
		_golden_sparkles.append({
			"pos": Vector2(gr.position.x + randf() * gr.size.x, gr.position.y + randf() * gr.size.y),
			"vel": Vector2(randf_range(-20, 20), randf_range(-40, -10)),
			"life": 1.0,
			"angle": randf() * TAU,
		})
	var alive_gs: Array = []
	for gs in _golden_sparkles:
		gs.life -= delta * 0.8
		gs.pos += gs.vel * delta
		gs.angle += delta * 3.0
		if gs.life > 0:
			alive_gs.append(gs)
	_golden_sparkles = alive_gs

	# Tooltip fade
	var want_tooltip: bool = (_hover_index >= 0) or _golden_hover
	if want_tooltip:
		_tooltip_alpha = minf(_tooltip_alpha + delta / 0.15, 1.0)
	else:
		_tooltip_alpha = maxf(_tooltip_alpha - delta / 0.1, 0.0)

	# Eye drag hint fade
	if _mode == EditorMode.CUSTOMIZE and _eye_drag_hint_timer > 0.0:
		_eye_drag_hint_timer -= delta

	# Initialize sci-fi background on first activation
	if not _scifi_initialized:
		_init_glyph_columns()
		_scifi_initialized = true

	# Sci-fi background animation
	var vp := get_viewport().get_visible_rect().size
	_scan_line_y = fmod(_scan_line_y + delta * 50.0, vp.y + 40.0)
	_diagram_rot[0] += delta * 0.4
	_diagram_rot[1] -= delta * 0.25
	_helix_phase += delta * 1.5
	for col in _glyph_columns:
		col.offset += delta * col.speed

	# Background particles
	if _appear_t > 0.3 and randf() < 0.3:
		_bg_particles.append({
			"pos": Vector2(randf() * vp.x, vp.y + 10),
			"vel": Vector2(randf_range(-20, 20), randf_range(-60, -30)),
			"life": 1.0,
			"color": Color(randf_range(0.2, 0.5), randf_range(0.5, 0.9), randf_range(0.7, 1.0), 0.15),
			"size": randf_range(1.0, 3.0),
		})
	var alive: Array = []
	for p in _bg_particles:
		p.life -= delta * 0.4
		p.pos += p.vel * delta
		if p.life > 0:
			alive.append(p)
	_bg_particles = alive

	# Sync preview rotation from color picker, zoom from local state
	if _mode == EditorMode.CUSTOMIZE and _preview and _color_picker:
		_preview.preview_scale = _preview_zoom
		_preview.preview_rotation = _color_picker.preview_rotation
		_color_picker.preview_zoom = _preview_zoom

	# Update placement particles
	var alive_pp: Array = []
	for pp in _place_particles:
		pp.life -= delta * 2.5
		pp.pos += pp.vel * delta
		pp.vel *= 0.92
		if pp.life > 0:
			alive_pp.append(pp)
	_place_particles = alive_pp

	_card_draw.queue_redraw()

func _enter_customize_mode() -> void:
	if _selected_index >= 0 and _selected_index < _choices.size():
		var pending: Dictionary = _choices[_selected_index]
		GameManager.consume_vial_for_evolution(_category)
		var vis: String = pending.get("visual", "")
		var angle: float = SnapPointSystem.get_default_angle_for_visual(vis)
		var distance: float = SnapPointSystem.get_default_distance_for_visual(vis)
		GameManager.apply_mutation_with_angle(pending, angle, distance)

	_mode = EditorMode.CUSTOMIZE
	_selected_index = -1
	_select_anim = 0.0
	_appear_t = 0.8
	_hover_index = -1
	_tooltip_alpha = 0.0
	_eye_drag_hint_timer = 3.0
	_setup_preview()
	_setup_color_picker()

func _setup_preview() -> void:
	if _preview:
		_preview.queue_free()
	var PreviewScript := preload("res://scripts/cell_stage/creature_preview.gd")
	_preview = Control.new()
	_preview.set_script(PreviewScript)
	_preview.name = "CreaturePreview"
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_draw.add_child(_preview)
	var vp := get_viewport().get_visible_rect().size
	_preview.preview_center = Vector2(vp.x * 0.43, vp.y * 0.42)
	_preview.preview_scale = _preview_zoom
	_preview.show_morph_handles = true

func _setup_color_picker() -> void:
	if _color_picker:
		if _color_picker.color_changed.is_connected(_on_color_changed):
			_color_picker.color_changed.disconnect(_on_color_changed)
		if _color_picker.style_changed.is_connected(_on_style_changed):
			_color_picker.style_changed.disconnect(_on_style_changed)
		if _color_picker.eye_size_changed.is_connected(_on_eye_size_changed):
			_color_picker.eye_size_changed.disconnect(_on_eye_size_changed)
		if _color_picker.add_eye_requested.is_connected(_on_add_eye_requested):
			_color_picker.add_eye_requested.disconnect(_on_add_eye_requested)
		_color_picker.queue_free()
	var PickerScript := preload("res://scripts/cell_stage/color_picker_ui.gd")
	_color_picker = Control.new()
	_color_picker.set_script(PickerScript)
	_color_picker.name = "ColorPicker"
	_color_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_draw.add_child(_color_picker)
	var vp := get_viewport().get_visible_rect().size
	_color_picker.position = Vector2(vp.x * 0.68, 0)
	_color_picker.size = Vector2(vp.x * 0.32, vp.y)
	_color_picker.setup(GameManager.creature_customization)
	_color_picker.color_changed.connect(_on_color_changed)
	_color_picker.style_changed.connect(_on_style_changed)
	_color_picker.eye_size_changed.connect(_on_eye_size_changed)
	_color_picker.add_eye_requested.connect(_on_add_eye_requested)

func _on_color_changed(target: String, color: Color) -> void:
	GameManager.update_creature_customization({target: color})

func _on_style_changed(target: String, style: String) -> void:
	GameManager.update_creature_customization({target: style})

func _on_eye_size_changed(new_size: float) -> void:
	GameManager.update_creature_customization({"eye_size": new_size})

func _on_add_eye_requested() -> void:
	var eyes: Array = GameManager.get_eyes()
	if eyes.size() >= 6:
		return
	# Add new eye at a default position
	GameManager.add_eye(0.0, 0.0)
	if _preview and _preview.has_method("refresh_handles"):
		_preview.refresh_handles()

func _close_editor() -> void:
	if _preview:
		_preview.queue_free()
		_preview = null
	if _color_picker:
		if _color_picker.color_changed.is_connected(_on_color_changed):
			_color_picker.color_changed.disconnect(_on_color_changed)
		if _color_picker.style_changed.is_connected(_on_style_changed):
			_color_picker.style_changed.disconnect(_on_style_changed)
		if _color_picker.eye_size_changed.is_connected(_on_eye_size_changed):
			_color_picker.eye_size_changed.disconnect(_on_eye_size_changed)
		if _color_picker.add_eye_requested.is_connected(_on_add_eye_requested):
			_color_picker.add_eye_requested.disconnect(_on_add_eye_requested)
		_color_picker.queue_free()
		_color_picker = null
	_active = false
	_is_initial_customize = false
	_cards_pending = false
	_choices = []
	_dragging_mutation = {}
	_is_dragging = false
	_drag_source = ""
	_bg_particles.clear()
	_place_particles.clear()
	_golden_sparkles.clear()
	_is_golden_evolution = false
	_golden_card = {}
	_golden_hover = false
	_golden_selected = false
	_hover_mutation_id = ""
	_hover_placed_mutation = ""
	_selected_mutation_id = ""
	_ring_drag_mode = ""
	_ring_hover_handle = ""
	_dragging_eye = false
	_dragging_morph_handle = -1
	_eye_selected = false
	_tooltip_alpha = 0.0
	_hover_index = -1
	visible = false
	get_tree().paused = false

# --- Layout helpers ---

func _get_vp() -> Vector2:
	return get_viewport().get_visible_rect().size

func _get_card_rect(index: int) -> Rect2:
	var vp := _get_vp()
	if _mode == EditorMode.CARD_SELECT:
		var card_count: int = _choices.size() + (1 if _is_golden_evolution else 0)
		var total_w: float = card_count * CARD_WIDTH + (card_count - 1) * CARD_SPACING
		var start_x: float = (vp.x - total_w) * 0.5
		var x: float = start_x + index * (CARD_WIDTH + CARD_SPACING)
		var y: float = vp.y * 0.2 + (1.0 - _appear_t) * 80.0
		return Rect2(x, y, CARD_WIDTH, CARD_HEIGHT)
	else:
		# Cards at bottom in customize mode — larger when pending selection
		var cw: float = 190.0 if _cards_pending else SMALL_CARD_W
		var ch: float = 230.0 if _cards_pending else SMALL_CARD_H
		var sp: float = 16.0 if _cards_pending else 12.0
		var card_count: int = _choices.size() + (1 if _cards_pending and _is_golden_evolution else 0)
		var total_w: float = card_count * cw + (card_count - 1) * sp
		var center_x: float = vp.x * 0.43  # Center of preview area
		var start_x: float = center_x - total_w * 0.5
		var x: float = start_x + index * (cw + sp)
		var y: float = vp.y - ch - 16.0
		return Rect2(x, y, cw, ch)

func _get_golden_card_rect() -> Rect2:
	var vp := _get_vp()
	if _mode == EditorMode.CUSTOMIZE and _cards_pending:
		# Position golden card after the regular cards at bottom
		var cw: float = 190.0
		var ch: float = 230.0
		var sp: float = 16.0
		var card_count: int = _choices.size() + 1
		var total_w: float = card_count * cw + (card_count - 1) * sp
		var center_x: float = vp.x * 0.43
		var start_x: float = center_x - total_w * 0.5
		var x: float = start_x + _choices.size() * (cw + sp)
		var y: float = vp.y - ch - 16.0
		return Rect2(x, y, cw, ch)
	else:
		var card_count: int = _choices.size() + 1
		var total_w: float = card_count * CARD_WIDTH + (card_count - 1) * CARD_SPACING
		var start_x: float = (vp.x - total_w) * 0.5
		var x: float = start_x + _choices.size() * (CARD_WIDTH + CARD_SPACING)
		var y: float = vp.y * 0.2 + (1.0 - _appear_t) * 80.0
		return Rect2(x, y, CARD_WIDTH, CARD_HEIGHT)

func _get_preview_center() -> Vector2:
	var vp := _get_vp()
	return Vector2(vp.x * 0.43, vp.y * 0.42)

func _get_preview_cell_radius() -> float:
	return 18.0

func _get_preview_handles() -> Array:
	var handles: Array = GameManager.get_body_handles()
	var evo_scale: float = 1.0 + GameManager.evolution_level * 0.08
	var effective: Array = []
	for h in handles:
		effective.append(h * evo_scale)
	return effective

func _get_preview_scale() -> float:
	return _preview_zoom

func _get_angle_screen_pos(angle: float, distance: float) -> Vector2:
	var center := _get_preview_center()
	var s: float = _get_preview_scale()
	var cr: float = _get_preview_cell_radius()
	var handles: Array = _get_preview_handles()
	return center + SnapPointSystem.angle_to_perimeter_position_morphed(angle, cr, handles, distance) * s

func _screen_pos_to_angle(screen_pos: Vector2) -> float:
	var center := _get_preview_center()
	var delta: Vector2 = screen_pos - center
	return atan2(delta.y, delta.x)

func _screen_pos_to_distance(screen_pos: Vector2) -> float:
	var center := _get_preview_center()
	var s: float = _get_preview_scale()
	var cr: float = _get_preview_cell_radius()
	var handles: Array = _get_preview_handles()
	var delta: Vector2 = screen_pos - center
	var angle: float = atan2(delta.y, delta.x)
	var membrane_r: float = SnapPointSystem.get_radius_at_angle(angle, cr, handles) * s
	if membrane_r < 0.01:
		return 0.0
	return clampf(delta.length() / membrane_r, 0.0, 1.2)

func _get_confirm_rect() -> Rect2:
	var vp := _get_vp()
	var btn_w: float = 240.0
	var btn_h: float = 56.0
	return Rect2(vp.x * 0.43 - btn_w * 0.5, vp.y * 0.78, btn_w, btn_h)

func _get_palette_rect() -> Rect2:
	var vp := _get_vp()
	return Rect2(vp.x * 0.01, 68, vp.x * 0.17, vp.y - 84)

func _get_palette_item_rect(index: int) -> Rect2:
	var vp := _get_vp()
	var pr := _get_palette_rect()
	var row: int = index - _sidebar_scroll
	return Rect2(pr.position.x + 4, pr.position.y + 36 + row * 56.0, pr.size.x - 8, 50.0)

func _get_mutation_at_angle(screen_pos: Vector2) -> String:
	# Find the placed mutation closest to this screen position
	var best_id: String = ""
	var best_dist: float = 22.0  # Hit radius
	for mid in GameManager.mutation_placements:
		var p: Dictionary = GameManager.mutation_placements[mid]
		var angle: float = p.get("angle", 0.0)
		var distance: float = p.get("distance", 1.0)
		var sp: Vector2 = _get_angle_screen_pos(angle, distance)
		var d: float = screen_pos.distance_to(sp)
		if d < best_dist:
			best_dist = d
			best_id = mid
		# Also check mirror
		if p.get("mirrored", false):
			var ma: float = SnapPointSystem.get_mirror_angle(angle)
			var msp: Vector2 = _get_angle_screen_pos(ma, distance)
			if screen_pos.distance_to(msp) < best_dist:
				best_dist = screen_pos.distance_to(msp)
				best_id = mid
	return best_id

# --- Input handling ---

func _on_gui_input(event: InputEvent) -> void:
	if not _active:
		return
	match _mode:
		EditorMode.CARD_SELECT:
			_handle_card_input(event)
		EditorMode.CUSTOMIZE:
			_handle_customize_input(event)

func _handle_card_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_index = -1
		_golden_hover = false
		for i in range(_choices.size()):
			if _get_card_rect(i).has_point(event.position):
				_hover_index = i
				break
		# Check golden card hover
		if _is_golden_evolution and not _golden_card.is_empty():
			if _get_golden_card_rect().has_point(event.position):
				_golden_hover = true
				if _prev_hover != 99:
					AudioManager.play_ui_hover()
					_prev_hover = 99
		if _hover_index != _prev_hover and _hover_index >= 0:
			AudioManager.play_ui_hover()
		if not _golden_hover:
			_prev_hover = _hover_index
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _golden_hover and not _golden_selected and _selected_index < 0:
			AudioManager.play_ui_select()
			_golden_selected = true
			_select_anim = 0.0
		elif _hover_index >= 0 and _hover_index < _choices.size() and _selected_index < 0 and not _golden_selected:
			AudioManager.play_ui_select()
			_selected_index = _hover_index
			_select_anim = 0.0

func _handle_customize_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position

		# Morph handle drag in progress — update handle radius
		if _dragging_morph_handle >= 0:
			_update_morph_handle_drag(pos)
			return

		# Eye drag in progress — update eye placement
		if _dragging_eye:
			_update_eye_drag(pos)
			return

		# Ring handle drag in progress — update it
		if _ring_drag_mode != "":
			_update_ring_drag(pos)
			return

		_sidebar_hover = -1
		_confirm_hover = false
		_hover_placed_mutation = ""
		_hover_mutation_id = ""
		_ring_hover_handle = ""

		# Check ring handles first (when mutation selected)
		if _selected_mutation_id != "":
			var handle: String = _get_ring_handle_at(pos)
			if handle != "":
				_ring_hover_handle = handle
				return  # Skip other hover checks while on handles

		# Check palette items (left panel)
		var palette_rect := _get_palette_rect()
		if palette_rect.has_point(pos):
			var max_visible: int = mini(8, GameManager.active_mutations.size() - _sidebar_scroll)
			for i in range(max_visible):
				var idx: int = i + _sidebar_scroll
				if idx >= GameManager.active_mutations.size():
					break
				if _get_palette_item_rect(idx).has_point(pos):
					_sidebar_hover = idx
					break

		# Check placed mutations on the creature
		var placed_mid: String = _get_mutation_at_angle(pos)
		if placed_mid != "":
			_hover_placed_mutation = placed_mid
			_hover_mutation_id = placed_mid

		# Check confirm button
		if _get_confirm_rect().has_point(pos):
			_confirm_hover = true

		# Check cards at bottom for tooltip hover
		_hover_index = -1
		_golden_hover = false
		for i in range(_choices.size()):
			if _get_card_rect(i).has_point(pos):
				_hover_index = i
				break
		# Golden card hover (when cards pending)
		if _cards_pending and _is_golden_evolution and not _golden_card.is_empty():
			if _get_golden_card_rect().has_point(pos):
				_golden_hover = true

		# Check eye hit-test on creature preview
		if not _is_dragging and not _dragging_eye:
			var eye_hit: int = _get_eye_at_pos(pos)
			if eye_hit >= 0:
				_eye_selected = true

		# Update drag
		if _is_dragging:
			_drag_pos = pos
			_drag_ghost_angle = _screen_pos_to_angle(pos)

	elif event is InputEventMouseButton:
		var pos: Vector2 = event.position
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check morph handle click
			var morph_hit: int = _get_morph_handle_at(pos)
			if morph_hit >= 0:
				_dragging_morph_handle = morph_hit
				_selected_mutation_id = ""
				_eye_selected = false
				if _preview:
					_preview.dragging_morph_handle = morph_hit
				return

			# Check ring handles first (highest priority when mutation is selected)
			if _ring_hover_handle != "":
				_start_ring_drag(_ring_hover_handle, pos)
				return

			# Check eye click (start drag)
			var eye_hit: int = _get_eye_at_pos(pos)
			if eye_hit >= 0 and _mode == EditorMode.CUSTOMIZE:
				_dragging_eye = true
				_dragging_eye_index = eye_hit
				_eye_selected = true
				_selected_mutation_id = ""
				_end_ring_drag()
				AudioManager.play_ui_hover()
				return

			# Click pending card at bottom to apply mutation
			if _cards_pending:
				var card_clicked: bool = false
				for i in range(_choices.size()):
					if _get_card_rect(i).has_point(pos):
						var choice: Dictionary = _choices[i]
						GameManager.consume_vial_for_evolution(_category)
						var vis: String = choice.get("visual", "")
						var angle: float = SnapPointSystem.get_default_angle_for_visual(vis)
						var distance: float = SnapPointSystem.get_default_distance_for_visual(vis)
						GameManager.apply_mutation_with_angle(choice, angle, distance)
						_cards_pending = false
						_selected_index = i
						AudioManager.play_ui_select()
						card_clicked = true
						break
				# Check golden card click
				if not card_clicked and _is_golden_evolution and not _golden_card.is_empty():
					if _get_golden_card_rect().has_point(pos):
						GameManager.equipped_golden_card = _golden_card.get("id", "")
						GameManager.consume_vial_for_evolution(_category)
						_cards_pending = false
						_golden_selected = true
						AudioManager.play_ui_select()
						card_clicked = true
				if card_clicked:
					return

			# Click palette item to start drag
			if _sidebar_hover >= 0 and _sidebar_hover < GameManager.active_mutations.size():
				_dragging_mutation = GameManager.active_mutations[_sidebar_hover]
				_is_dragging = true
				_drag_source = "palette"
				_drag_pos = pos
				_selected_mutation_id = ""
				AudioManager.play_ui_hover()
			# Click placed mutation to select it (for ring handles)
			elif _hover_placed_mutation != "":
				_selected_mutation_id = _hover_placed_mutation
				# Start drag to reposition
				var m_data: Dictionary = {}
				for m in GameManager.active_mutations:
					if m.get("id", "") == _hover_placed_mutation:
						m_data = m
						break
				if not m_data.is_empty():
					_dragging_mutation = m_data
					_is_dragging = true
					_drag_source = "placed"
					_drag_pos = pos
				AudioManager.play_ui_hover()
			# Click confirm/save
			elif _get_confirm_rect().has_point(pos):
				AudioManager.play_ui_select()
				var was_initial := _is_initial_customize
				if _is_initial_customize:
					GameManager.initial_customization_done = true
				_close_editor()
				if was_initial:
					initial_customization_completed.emit()
			# Click symmetry toggle
			elif _get_symmetry_toggle_rect().has_point(pos):
				_symmetry_enabled = not _symmetry_enabled
				AudioManager.play_ui_select()
			# Click empty area — deselect
			else:
				_selected_mutation_id = ""
				_ring_hover_handle = ""
				_eye_selected = false
				_end_ring_drag()

		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# End morph handle drag
			if _dragging_morph_handle >= 0:
				_dragging_morph_handle = -1
				if _preview:
					_preview.dragging_morph_handle = -1
				return

			# End eye drag
			if _dragging_eye:
				_dragging_eye = false
				return

			# End ring handle drag
			if _ring_drag_mode != "":
				_end_ring_drag()
				return

			# Drop mutation
			if _is_dragging:
				var mid: String = _dragging_mutation.get("id", "")
				var preview_area := _get_preview_area_rect()
				if preview_area.has_point(pos) and mid != "":
					var angle: float = _screen_pos_to_angle(pos)
					var distance: float = clampf(_screen_pos_to_distance(pos), 0.0, 1.0)
					var mirrored: bool = _symmetry_enabled and not SnapPointSystem.is_center_angle(angle) and distance >= 0.5
					GameManager.update_mutation_angle(mid, angle, distance, mirrored)
					AudioManager.play_ui_select()
					_spawn_place_particles(pos)
					_selected_mutation_id = mid
			_is_dragging = false
			_dragging_mutation = {}
			_drag_source = ""

		# Right-click: unplace mutation or remove eye
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			# Check eye right-click (remove)
			var eye_rc: int = _get_eye_at_pos(pos)
			if eye_rc >= 0 and GameManager.get_eyes().size() > 1:
				GameManager.remove_eye(eye_rc)
				_eye_selected = false
				_dragging_eye = false
				if _preview and _preview.has_method("refresh_handles"):
					_preview.refresh_handles()
				AudioManager.play_ui_hover()
			elif _hover_placed_mutation != "":
				GameManager.remove_mutation_placement(_hover_placed_mutation)
				if _selected_mutation_id == _hover_placed_mutation:
					_selected_mutation_id = ""
					_end_ring_drag()
				_hover_placed_mutation = ""
				_ring_hover_handle = ""
				AudioManager.play_ui_hover()

		# Mouse wheel over eye: resize
		if event.pressed and _eye_selected and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var eye_hit_scroll: int = _get_eye_at_pos(pos)
			if eye_hit_scroll >= 0:
				var eyes: Array = GameManager.get_eyes()
				if eye_hit_scroll < eyes.size():
					var cur_eye_size: float = eyes[eye_hit_scroll].get("size", 3.5)
					var delta_sz: float = 0.3 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.3
					cur_eye_size = clampf(cur_eye_size + delta_sz, 2.0, 6.0)
					GameManager.update_eye(eye_hit_scroll, {"size": cur_eye_size})

		# Mouse wheel: rotate or scale placed mutations (scroll fallback still works)
		if event.pressed and _hover_mutation_id != "":
			if event.shift_pressed:
				# Shift+scroll = scale
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					var cur_scale: float = GameManager.mutation_placements.get(_hover_mutation_id, {}).get("scale", 1.0)
					GameManager.update_mutation_scale(_hover_mutation_id, cur_scale + 0.15)
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					var cur_scale: float = GameManager.mutation_placements.get(_hover_mutation_id, {}).get("scale", 1.0)
					GameManager.update_mutation_scale(_hover_mutation_id, cur_scale - 0.15)
			else:
				# Normal scroll = rotate
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					var cur_rot: float = GameManager.mutation_placements.get(_hover_mutation_id, {}).get("rotation_offset", 0.0)
					GameManager.update_mutation_rotation(_hover_mutation_id, cur_rot + 0.15)
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					var cur_rot: float = GameManager.mutation_placements.get(_hover_mutation_id, {}).get("rotation_offset", 0.0)
					GameManager.update_mutation_rotation(_hover_mutation_id, cur_rot - 0.15)

		# Scroll-over-preview to zoom (when not hovering a mutation)
		elif event.pressed and _hover_mutation_id == "":
			var preview_rect := _get_preview_area_rect()
			if preview_rect.has_point(pos):
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					_preview_zoom = clampf(_preview_zoom + 0.3, 2.5, 7.0)
					if _preview:
						_preview.preview_scale = _preview_zoom
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_preview_zoom = clampf(_preview_zoom - 0.3, 2.5, 7.0)
					if _preview:
						_preview.preview_scale = _preview_zoom
			elif _get_palette_rect().has_point(pos):
				# Palette scroll
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					_sidebar_scroll = maxi(_sidebar_scroll - 1, 0)
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_sidebar_scroll = mini(_sidebar_scroll + 1, maxi(0, GameManager.active_mutations.size() - 8))

func _get_preview_area_rect() -> Rect2:
	var vp := _get_vp()
	return Rect2(vp.x * 0.18, 68, vp.x * 0.50, vp.y * 0.65)

func _get_symmetry_toggle_rect() -> Rect2:
	var vp := _get_vp()
	return Rect2(vp.x * 0.43 - 80, 68, 160, 34)

func _spawn_place_particles(pos: Vector2) -> void:
	for i in range(12):
		var angle: float = randf() * TAU
		var speed: float = randf_range(30, 80)
		_place_particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed),
			"life": 1.0,
			"color": Color(0.4, 0.9, 1.0, 0.8),
		})

# --- Drawing ---

func _draw_ui() -> void:
	if not _active:
		return
	var vp := _get_vp()
	var font := UIConstants.get_display_font()

	# Sci-fi background with tech blueprints and alien diagrams
	_draw_scifi_bg(vp)

	# Flash
	if _flash_alpha > 0.01:
		_card_draw.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.4, 0.8, 1.0, _flash_alpha * 0.3))

	# Background particles
	for p in _bg_particles:
		_card_draw.draw_circle(p.pos, p.size, Color(p.color.r, p.color.g, p.color.b, p.life * p.color.a))

	match _mode:
		EditorMode.CARD_SELECT:
			_draw_card_select(vp, font)
		EditorMode.CUSTOMIZE:
			_draw_customize_mode(vp, font)

func _init_glyph_columns() -> void:
	_glyph_columns.clear()
	var num_cols := 10
	for i in range(num_cols):
		var col := {
			"x": 30.0 + float(i) * 120.0 + randf_range(-20, 20),
			"offset": randf() * 400.0,
			"speed": randf_range(8.0, 18.0),
			"alpha": randf_range(0.12, 0.22),
			"glyphs": [],
		}
		for j in range(24):
			col.glyphs.append(str(ALIEN_GLYPHS[randi() % ALIEN_GLYPHS.size()]))
		_glyph_columns.append(col)

func _draw_scifi_bg(vp: Vector2) -> void:
	var a := _appear_t

	# 1. Dark base
	_card_draw.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(UIConstants.BG_DARK.r, UIConstants.BG_DARK.g, UIConstants.BG_DARK.b, 0.96 * a))

	# 2. Blueprint grid (bolder)
	var grid_alpha := 0.12 * a
	var grid_spacing := 40.0
	var gx_count := int(vp.x / grid_spacing) + 1
	var gy_count := int(vp.y / grid_spacing) + 1
	for i in range(gx_count):
		var x := float(i) * grid_spacing
		var is_major := (i % 4 == 0)
		var ga := grid_alpha * (1.55 if is_major else 1.0)
		var gw := 1.5 if is_major else 1.0
		_card_draw.draw_line(Vector2(x, 0), Vector2(x, vp.y), Color(UIConstants.GRID_COLOR.r, UIConstants.GRID_COLOR.g, UIConstants.GRID_COLOR.b, ga), gw)
	for i in range(gy_count):
		var y := float(i) * grid_spacing
		var is_major := (i % 4 == 0)
		var ga := grid_alpha * (1.55 if is_major else 1.0)
		var gw := 1.5 if is_major else 1.0
		_card_draw.draw_line(Vector2(0, y), Vector2(vp.x, y), Color(UIConstants.GRID_COLOR.r, UIConstants.GRID_COLOR.g, UIConstants.GRID_COLOR.b, ga), gw)

	# 3. Horizontal scan line with glow band (bolder)
	var scan_alpha := (0.25 + 0.12 * sin(_time * 3.0)) * a
	_card_draw.draw_line(Vector2(0, _scan_line_y), Vector2(vp.x, _scan_line_y), Color(0.3, 0.8, 1.0, scan_alpha), 2.5)
	for i in range(6):
		var off := float(i + 1) * 3.0
		var band_a := scan_alpha * (1.0 - float(i) / 6.0) * 0.3
		_card_draw.draw_line(Vector2(0, _scan_line_y + off), Vector2(vp.x, _scan_line_y + off), Color(0.2, 0.6, 0.8, band_a), 1.5)

	# 4. Scrolling alien glyph columns
	_draw_glyph_columns(vp)

	# 5. Rotating tech diagrams (bolder)
	_draw_tech_diagram(Vector2(vp.x * 0.15, vp.y * 0.28), 110.0, _diagram_rot[0], a * 0.22)
	_draw_tech_diagram(Vector2(vp.x * 0.82, vp.y * 0.72), 90.0, _diagram_rot[1], a * 0.18)

	# 6. DNA helix decoration along left edge
	_draw_dna_helix(vp)

	# 7. Tech readouts along bottom edge
	_draw_edge_readouts(vp)

	# 8. Corner bracket tech frame (bolder)
	_draw_corner_frame(Rect2(6, 6, vp.x - 12, vp.y - 12), Color(0.2, 0.5, 0.7, 0.4 * a))

	# 9. Subtle vignette gradient (darker edges)
	for i in range(4):
		var t := float(i) / 4.0
		var edge_a := 0.06 * (1.0 - t) * a
		_card_draw.draw_rect(Rect2(0, 0, vp.x, 30 - i * 6), Color(0.0, 0.0, 0.0, edge_a))
		_card_draw.draw_rect(Rect2(0, vp.y - 30 + i * 6, vp.x, 30 - i * 6), Color(0.0, 0.0, 0.0, edge_a))

	# 10. Top header bar (styled with scan accent)
	_card_draw.draw_rect(Rect2(0, 0, vp.x, 64), Color(UIConstants.BG_PANEL.r, UIConstants.BG_PANEL.g, UIConstants.BG_PANEL.b, 0.92 * a))
	_card_draw.draw_line(Vector2(0, 63), Vector2(vp.x, 63), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.45 * a), 1.5)
	# Moving accent light on header line
	var header_scan := fmod(_time * 120.0, vp.x + 200.0) - 100.0
	_card_draw.draw_line(Vector2(header_scan, 63), Vector2(header_scan + 120.0, 63), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.7 * a), 3.0)
	# Alien timestamp in header corner
	var mono_font := UIConstants.get_mono_font()
	var alien_ts: String = UIConstants.random_glyphs(8, _time)
	_card_draw.draw_string(mono_font, Vector2(vp.x - 150, 22), alien_ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.5 * a))
	# Status text top-left
	_card_draw.draw_string(mono_font, Vector2(12, 22), "SYS.ACTIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.7, 0.5, 0.5 * a))
	var status_val := "%.2f" % fmod(_time * 7.3, 99.99)
	_card_draw.draw_string(mono_font, Vector2(80, 22), status_val, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.95, 0.6, 0.6 * a))

func _draw_glyph_columns(vp: Vector2) -> void:
	var font := UIConstants.get_mono_font()
	var a := _appear_t
	for col in _glyph_columns:
		var x: float = col.x
		if x > vp.x:
			continue
		for i in range(col.glyphs.size()):
			var y: float = fmod(col.offset + float(i) * 18.0, float(col.glyphs.size()) * 18.0 + vp.y) - 36.0
			if y < -18.0 or y > vp.y + 18.0:
				continue
			# Fade near top/bottom edges
			var edge_fade := 1.0
			if y < 80.0:
				edge_fade = clampf(y / 80.0, 0.0, 1.0)
			elif y > vp.y - 60.0:
				edge_fade = clampf((vp.y - y) / 60.0, 0.0, 1.0)
			_card_draw.draw_string(font, Vector2(x, y), str(col.glyphs[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_GLYPH, Color(0.28, 0.55, 0.68, col.alpha * edge_fade * a))

func _draw_tech_diagram(center: Vector2, radius: float, angle: float, alpha: float) -> void:
	if alpha < 0.005:
		return
	# Outer ring
	_card_draw.draw_arc(center, radius, 0, TAU, 32, Color(0.2, 0.5, 0.7, alpha), 1.0, true)
	# Inner concentric rings
	_card_draw.draw_arc(center, radius * 0.7, 0, TAU, 24, Color(0.15, 0.4, 0.6, alpha * 0.7), 0.8, true)
	_card_draw.draw_arc(center, radius * 0.4, 0, TAU, 16, Color(0.12, 0.3, 0.5, alpha * 0.5), 0.5, true)
	# Tick marks on outer ring (rotating)
	for i in range(12):
		var tick_a := angle + TAU * float(i) / 12.0
		var p1 := center + Vector2(cos(tick_a), sin(tick_a)) * radius
		var p2 := center + Vector2(cos(tick_a), sin(tick_a)) * (radius - 8.0)
		_card_draw.draw_line(p1, p2, Color(0.3, 0.6, 0.8, alpha), 1.0, true)
	# Cross-hairs (slower rotation)
	for i in range(4):
		var ch_a := angle * 0.5 + TAU * float(i) / 4.0
		var p1 := center + Vector2(cos(ch_a), sin(ch_a)) * radius * 0.15
		var p2 := center + Vector2(cos(ch_a), sin(ch_a)) * radius * 0.65
		_card_draw.draw_line(p1, p2, Color(0.2, 0.4, 0.6, alpha * 0.5), 0.5, true)
	# Rotating data arc (partial arc that sweeps)
	var arc_start := fmod(angle * 1.5, TAU)
	_card_draw.draw_arc(center, radius * 0.85, arc_start, arc_start + PI * 0.6, 12, Color(0.3, 0.7, 0.9, alpha * 0.7), 2.0, true)
	# Center dot
	_card_draw.draw_circle(center, 2.5, Color(0.3, 0.7, 0.9, alpha))
	# Small orbiting dot
	var orbit_a := angle * 2.0
	var orbit_pos := center + Vector2(cos(orbit_a), sin(orbit_a)) * radius * 0.55
	_card_draw.draw_circle(orbit_pos, 2.0, Color(0.4, 0.9, 1.0, alpha * 0.8))

func _draw_dna_helix(vp: Vector2) -> void:
	var x_base := vp.x * 0.97
	var helix_width := 12.0
	var a := _appear_t * 0.18
	var strand1 := PackedVector2Array()
	var strand2 := PackedVector2Array()
	var num_pts := 30

	for i in range(num_pts):
		var t := float(i) / float(num_pts - 1)
		var y := t * vp.y
		var phase := _helix_phase + t * 8.0
		var x1 := x_base + sin(phase) * helix_width
		var x2 := x_base + sin(phase + PI) * helix_width
		strand1.append(Vector2(x1, y))
		strand2.append(Vector2(x2, y))
		# Cross rungs
		if i % 3 == 0 and i > 0:
			_card_draw.draw_line(Vector2(x1, y), Vector2(x2, y), Color(0.2, 0.5, 0.7, a * 0.7), 1.0, true)

	if strand1.size() >= 2:
		_card_draw.draw_polyline(strand1, Color(0.3, 0.7, 0.9, a), 2.5, true)
		_card_draw.draw_polyline(strand2, Color(0.2, 0.6, 0.8, a), 2.5, true)

func _draw_edge_readouts(vp: Vector2) -> void:
	var font := UIConstants.get_mono_font()
	var a := _appear_t * 0.7

	# Bottom-right tech readouts
	var rx := vp.x - 165.0
	var ry := vp.y - 38.0
	var val1 := 50.0 + sin(_time * 1.3) * 30.0
	var val2 := 75.0 + cos(_time * 0.9) * 20.0
	var val3 := 30.0 + sin(_time * 2.1) * 25.0

	_card_draw.draw_string(font, Vector2(rx, ry), "BIO.SIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.5, 0.6, a * 0.6))
	_card_draw.draw_string(font, Vector2(rx + 46, ry), "%.1f" % val1, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.9, 0.5, a))
	_card_draw.draw_string(font, Vector2(rx + 86, ry), "MTB.RT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.5, 0.6, a * 0.6))
	_card_draw.draw_string(font, Vector2(rx + 128, ry), "%.1f" % val2, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.9, 0.5, a))
	ry += 14.0
	_card_draw.draw_string(font, Vector2(rx, ry), "STAB.IX", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.5, 0.6, a * 0.6))
	_card_draw.draw_string(font, Vector2(rx + 48, ry), "%.1f%%" % val3, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.9, 0.5, a))
	# Alien label
	var alien_lbl: String = ""
	for i in range(6):
		alien_lbl += str(ALIEN_GLYPHS[int(fmod(_time * 0.5 + float(i), float(ALIEN_GLYPHS.size())))])
	_card_draw.draw_string(font, Vector2(rx + 100, ry), alien_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.2, 0.4, 0.5, a * 0.35))

	# Bottom-left alien readout
	var lx := 12.0
	var ly := vp.y - 26.0
	var alien_bl: String = ""
	for i in range(10):
		alien_bl += str(ALIEN_GLYPHS[int(fmod(_time * 0.2 + float(i) * 2.3, float(ALIEN_GLYPHS.size())))])
	_card_draw.draw_string(font, Vector2(lx, ly), alien_bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.2, 0.4, 0.5, a * 0.3))

func _draw_corner_frame(rect: Rect2, color: Color) -> void:
	var corner_len := 30.0
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	# Top-left
	_card_draw.draw_line(Vector2(x, y), Vector2(x + corner_len, y), color, 2.0)
	_card_draw.draw_line(Vector2(x, y), Vector2(x, y + corner_len), color, 2.0)
	# Top-right
	_card_draw.draw_line(Vector2(x + w, y), Vector2(x + w - corner_len, y), color, 2.0)
	_card_draw.draw_line(Vector2(x + w, y), Vector2(x + w, y + corner_len), color, 2.0)
	# Bottom-left
	_card_draw.draw_line(Vector2(x, y + h), Vector2(x + corner_len, y + h), color, 2.0)
	_card_draw.draw_line(Vector2(x, y + h), Vector2(x, y + h - corner_len), color, 2.0)
	# Bottom-right
	_card_draw.draw_line(Vector2(x + w, y + h), Vector2(x + w - corner_len, y + h), color, 2.0)
	_card_draw.draw_line(Vector2(x + w, y + h), Vector2(x + w, y + h - corner_len), color, 2.0)

func _draw_card_select(vp: Vector2, font: Font) -> void:
	# Main header
	var header := "CHOOSE YOUR MUTATION"
	var hs := font.get_string_size(header, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
	var header_x: float = (vp.x - hs.x) * 0.5
	_card_draw.draw_string(font, Vector2(header_x, 38), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIConstants.TEXT_TITLE.r, UIConstants.TEXT_TITLE.g, UIConstants.TEXT_TITLE.b, _appear_t))
	# Underline
	_card_draw.draw_line(Vector2(header_x, 42), Vector2(header_x + hs.x, 42), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.5 * _appear_t), 1.5)

	# Category subtitle
	var cat_label: String = GameManager.CATEGORY_LABELS.get(_category, _category)
	var sub := "Vial filled: " + cat_label
	var ss := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	_card_draw.draw_string(font, Vector2((vp.x - ss.x) * 0.5, 58), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, _appear_t * 0.85))

	# Evolution level indicator (top-right)
	var evo_str := "EVO LV %d" % GameManager.evolution_level
	_card_draw.draw_string(font, Vector2(vp.x - 120, 38), evo_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.7 * _appear_t))

	# Cards
	for i in range(_choices.size()):
		_draw_single_card(i, true)

	# Golden card (4th slot)
	if _is_golden_evolution and not _golden_card.is_empty():
		_draw_golden_card(vp, font)

	# Tooltip (drawn on top of cards)
	if _tooltip_alpha > 0.01:
		if _golden_hover and not _golden_card.is_empty():
			_draw_card_tooltip(_golden_card, _get_golden_card_rect(), true, true)
		elif _hover_index >= 0 and _hover_index < _choices.size():
			_draw_card_tooltip(_choices[_hover_index], _get_card_rect(_hover_index), true, false)

func _draw_customize_mode(vp: Vector2, font: Font) -> void:
	# Header title with alien glyph accents
	var glyph_l: String = str(ALIEN_GLYPHS[int(fmod(_time * 0.5, ALIEN_GLYPHS.size()))]) + " "
	var glyph_r: String = " " + str(ALIEN_GLYPHS[int(fmod(_time * 0.5 + 7, ALIEN_GLYPHS.size()))])
	var title := glyph_l + "CREATURE EDITOR" + glyph_r
	if _is_initial_customize:
		title = glyph_l + "DESIGN YOUR ORGANISM" + glyph_r
	var title_cx: float = vp.x * 0.43
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 32)
	_card_draw.draw_string(font, Vector2(title_cx - ts.x * 0.5, 44), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(UIConstants.TEXT_TITLE.r, UIConstants.TEXT_TITLE.g, UIConstants.TEXT_TITLE.b, _appear_t))

	# Subtitle/hint
	var hint := "Drag parts onto creature. Click to select, drag handles to rotate/scale, Right-click=remove"
	if _is_initial_customize:
		hint = "Choose your colors and eyes — make it yours!"
	var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	_card_draw.draw_string(font, Vector2(title_cx - hs.x * 0.5, 62), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, _appear_t * 0.8))

	# Symmetry toggle
	_draw_symmetry_toggle(vp, font)

	# Tech frame around preview area
	var preview_frame := Rect2(vp.x * 0.18, 72, vp.x * 0.50, vp.y * 0.63)
	_draw_corner_frame(preview_frame, Color(UIConstants.FRAME_COLOR.r, UIConstants.FRAME_COLOR.g, UIConstants.FRAME_COLOR.b, 0.22 * _appear_t))
	_card_draw.draw_string(font, Vector2(preview_frame.position.x + 8, preview_frame.position.y + 18), "SPECIMEN VIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.6 * _appear_t))
	var spec_glyph: String = ""
	for i in range(5):
		spec_glyph += str(ALIEN_GLYPHS[int(fmod(_time * 0.15 + float(i) * 3.1, float(ALIEN_GLYPHS.size())))])
	_card_draw.draw_string(font, Vector2(preview_frame.position.x + preview_frame.size.x - 80, preview_frame.position.y + 18), spec_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.4 * _appear_t))

	# Draw placement handles on creature
	_draw_placement_handles(vp, font)

	# Draw eye drag handles
	_draw_eye_handles(vp, font)

	# Parts palette (left panel)
	_draw_parts_palette(vp, font)

	# Save/Done button
	_draw_confirm_button(vp, font)

	# Drag ghost + mirror ghost
	if _is_dragging:
		_draw_drag_ghost(vp, font)

	# Placement particles
	_draw_placement_particles()

	# Cards at bottom
	if _choices.size() > 0:
		var card_top: float = vp.y - SMALL_CARD_H - 24.0
		_card_draw.draw_line(Vector2(vp.x * 0.18, card_top), Vector2(vp.x * 0.68 - 8, card_top), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3), 1.0)
		var lbl := "CHOOSE YOUR MUTATION" if _cards_pending else "MUTATIONS AVAILABLE"
		var lbl_fs: int = 20 if _cards_pending else 16
		var lbl_col: Color = Color(UIConstants.TEXT_TITLE.r, UIConstants.TEXT_TITLE.g, UIConstants.TEXT_TITLE.b, 0.95) if _cards_pending else Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.7)
		var ls := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, lbl_fs)
		_card_draw.draw_string(font, Vector2(vp.x * 0.43 - ls.x * 0.5, card_top - 4), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lbl_fs, lbl_col)
		# Pulsing accent line when cards pending
		if _cards_pending:
			var pulse_a: float = 0.4 + 0.3 * sin(_time * 3.0)
			_card_draw.draw_line(Vector2(vp.x * 0.18, card_top), Vector2(vp.x * 0.68 - 8, card_top), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, pulse_a), 2.0)
		for i in range(_choices.size()):
			_draw_single_card(i, _cards_pending)
		# Golden card at bottom when pending
		if _cards_pending and _is_golden_evolution and not _golden_card.is_empty():
			_draw_golden_card(vp, font)
		# Tooltip for hovered card (drawn above)
		if _tooltip_alpha > 0.01 and _hover_index >= 0 and _hover_index < _choices.size():
			_draw_card_tooltip(_choices[_hover_index], _get_card_rect(_hover_index), _cards_pending, false)

func _draw_placement_handles(vp: Vector2, font: Font) -> void:
	# Draw handles on each placed mutation
	for mid in GameManager.mutation_placements:
		var p: Dictionary = GameManager.mutation_placements[mid]
		if not p.has("angle"):
			continue
		var angle: float = p.get("angle", 0.0)
		var distance: float = p.get("distance", 1.0)
		var sp: Vector2 = _get_angle_screen_pos(angle, distance)
		var is_selected: bool = mid == _selected_mutation_id
		var is_hover: bool = mid == _hover_placed_mutation

		var handle_r: float = 12.0
		var base_col: Color = Color(0.4, 0.9, 0.5, 0.5)
		if is_hover:
			base_col = Color(0.5, 1.0, 0.6, 0.7)
		if is_selected:
			base_col = Color(1.0, 0.9, 0.3, 0.8)

		# Handle circle
		_card_draw.draw_arc(sp, handle_r, 0, TAU, 16, base_col, 1.5, true)
		_card_draw.draw_circle(sp, 3.0, base_col)

		# Ring handles on selected mutation
		if is_selected:
			var rot_offset: float = p.get("rotation_offset", 0.0)
			var scale_val: float = p.get("scale", 1.0)

			# Main ring
			_card_draw.draw_arc(sp, RING_RADIUS, 0, TAU, 32, RING_COLOR, 1.5, true)

			# Rotation handle (top of ring, diamond shape)
			var rot_handle_pos: Vector2 = sp + Vector2(cos(angle + rot_offset - PI * 0.5), sin(angle + rot_offset - PI * 0.5)) * RING_RADIUS
			var rot_col: Color = HANDLE_HOVER_COLOR if _ring_hover_handle == "rotate" else HANDLE_COLOR
			_card_draw.draw_circle(rot_handle_pos, RING_HANDLE_R + 1.0, rot_col)
			# Inner arrow indicator
			var arrow_dir: Vector2 = (rot_handle_pos - sp).normalized()
			var arrow_perp: Vector2 = Vector2(-arrow_dir.y, arrow_dir.x)
			_card_draw.draw_line(rot_handle_pos - arrow_perp * 3.0, rot_handle_pos + arrow_perp * 3.0, Color(0.1, 0.1, 0.2, 0.9), 1.5, true)
			# Rotation arc indicator
			var arc_start: float = angle + rot_offset - PI * 0.5 - 0.3
			var arc_end: float = angle + rot_offset - PI * 0.5 + 0.3
			_card_draw.draw_arc(sp, RING_RADIUS + 3.0, arc_start, arc_end, 8, Color(rot_col.r, rot_col.g, rot_col.b, 0.4), 2.0, true)
			# "R" label
			_card_draw.draw_string(font, rot_handle_pos + Vector2(-4, -12), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(rot_col.r, rot_col.g, rot_col.b, 0.7))

			# Scale handles (4 cardinal directions relative to mutation orientation)
			for i in range(4):
				var scale_angle: float = angle + rot_offset + i * PI * 0.5
				var scale_pos: Vector2 = sp + Vector2(cos(scale_angle), sin(scale_angle)) * RING_RADIUS
				var handle_id: String = "scale_%d" % i
				var sc_col: Color = SCALE_HANDLE_HOVER if _ring_hover_handle == handle_id else SCALE_HANDLE_COLOR
				# Square handle
				var sq_size: float = RING_HANDLE_R * 1.6
				_card_draw.draw_rect(Rect2(scale_pos.x - sq_size * 0.5, scale_pos.y - sq_size * 0.5, sq_size, sq_size), sc_col)
				_card_draw.draw_rect(Rect2(scale_pos.x - sq_size * 0.5, scale_pos.y - sq_size * 0.5, sq_size, sq_size), Color(0.1, 0.3, 0.2, 0.6), false, 1.0)

			# Info readout below
			var info_str: String = "%.0f%% | %d°" % [scale_val * 100.0, int(rad_to_deg(rot_offset))]
			var is_sz := font.get_string_size(info_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			_card_draw.draw_string(font, Vector2(sp.x - is_sz.x * 0.5, sp.y + RING_RADIUS + 18), info_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.95, 0.7, 0.8))

			# Hint text for selected mutation
			var hint_str: String = "Drag handles to rotate/scale"
			var hint_sz := font.get_string_size(hint_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
			_card_draw.draw_string(font, Vector2(sp.x - hint_sz.x * 0.5, sp.y + RING_RADIUS + 34), hint_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.6))

		# Hover tooltip
		if is_hover and not is_selected:
			var mname: String = ""
			for m in GameManager.active_mutations:
				if m.get("id", "") == mid:
					mname = m.get("name", mid)
					break
			if mname != "":
				var ns := font.get_string_size(mname, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
				_card_draw.draw_string(font, Vector2(sp.x - ns.x * 0.5, sp.y - handle_r - 8), mname, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.85))

		# Mirror handle
		if p.get("mirrored", false):
			var ma: float = SnapPointSystem.get_mirror_angle(angle)
			var msp: Vector2 = _get_angle_screen_pos(ma, distance)
			_card_draw.draw_arc(msp, handle_r * 0.8, 0, TAU, 12, Color(base_col.r, base_col.g, base_col.b, base_col.a * 0.5), 1.0, true)
			var m_sz := font.get_string_size("M", HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
			_card_draw.draw_string(font, Vector2(msp.x - m_sz.x * 0.5, msp.y + 5), "M", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.3, 0.4))

func _draw_parts_palette(vp: Vector2, font: Font) -> void:
	var pr := _get_palette_rect()

	# Panel background
	_card_draw.draw_rect(pr, Color(UIConstants.BG_PANEL.r, UIConstants.BG_PANEL.g, UIConstants.BG_PANEL.b, 0.92))
	_draw_corner_frame(Rect2(pr.position.x - 2, pr.position.y - 2, pr.size.x + 4, pr.size.y + 4), Color(UIConstants.FRAME_COLOR.r, UIConstants.FRAME_COLOR.g, UIConstants.FRAME_COLOR.b, 0.25))

	# Header
	var side_glyph: String = str(ALIEN_GLYPHS[int(fmod(_time * 0.4 + 3.0, ALIEN_GLYPHS.size()))])
	_card_draw.draw_string(font, Vector2(pr.position.x + 6, pr.position.y + 26), side_glyph + " PARTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.95))
	_card_draw.draw_line(Vector2(pr.position.x + 4, pr.position.y + 34), Vector2(pr.position.x + pr.size.x - 4, pr.position.y + 34), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)

	if GameManager.active_mutations.is_empty():
		_card_draw.draw_string(font, Vector2(pr.position.x + 8, pr.position.y + 60), "No mutations yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.6))
		return

	var max_visible: int = mini(8, GameManager.active_mutations.size() - _sidebar_scroll)
	for i in range(max_visible):
		var idx: int = i + _sidebar_scroll
		if idx >= GameManager.active_mutations.size():
			break
		var m: Dictionary = GameManager.active_mutations[idx]
		var mid: String = m.get("id", "")
		var rect := _get_palette_item_rect(idx)
		var is_hover: bool = idx == _sidebar_hover
		var is_placed: bool = mid in GameManager.mutation_placements

		var bg: Color = Color(0.12, 0.20, 0.32, 0.8) if is_hover else Color(0.07, 0.11, 0.20, 0.6)
		_card_draw.draw_rect(rect, bg)
		if is_hover:
			_card_draw.draw_rect(rect, Color(0.35, 0.75, 1.0, 0.5), false, 1.5)

		# Drag handle indicator
		_card_draw.draw_rect(Rect2(rect.position.x + 3, rect.position.y + 12, 4, 26), Color(0.35, 0.65, 0.85, 0.5))
		_card_draw.draw_rect(Rect2(rect.position.x + 10, rect.position.y + 12, 4, 26), Color(0.35, 0.65, 0.85, 0.5))

		# Mutation name
		var name_str: String = m.get("name", "Unknown")
		var name_col: Color = Color(0.8, 0.95, 1.0, 0.95) if is_hover else Color(0.65, 0.82, 0.90, 0.85)
		if is_placed:
			name_col = Color(0.5, 0.95, 0.6, 0.9) if not is_hover else Color(0.6, 1.0, 0.7, 1.0)
		_card_draw.draw_string(font, Vector2(rect.position.x + 20, rect.position.y + 32), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, name_col)

		# Placed indicator
		if is_placed:
			var placed_label := "PLACED"
			_card_draw.draw_string(font, Vector2(rect.position.x + rect.size.x - 64, rect.position.y + 32), placed_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.4, 0.9, 0.5, 0.75))

	# Scroll indicators
	if _sidebar_scroll > 0:
		_card_draw.draw_string(font, Vector2(pr.position.x + pr.size.x * 0.5 - 6, pr.position.y + 42), "^", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.7))
	if _sidebar_scroll + 8 < GameManager.active_mutations.size():
		_card_draw.draw_string(font, Vector2(pr.position.x + pr.size.x * 0.5 - 6, pr.position.y + pr.size.y - 10), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.7))

func _draw_drag_ghost(vp: Vector2, font: Font) -> void:
	var vis: String = _dragging_mutation.get("visual", "")
	var name_str: String = _dragging_mutation.get("name", "")

	# Ghost at cursor
	_card_draw.draw_circle(_drag_pos, 16.0, Color(0.2, 0.5, 0.8, 0.25))
	_card_draw.draw_arc(_drag_pos, 16.0, 0, TAU, 16, Color(0.4, 0.8, 1.0, 0.5), 1.5, true)
	var ns := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	_card_draw.draw_string(font, Vector2(_drag_pos.x - ns.x * 0.5, _drag_pos.y + 28), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.9, 1.0, 0.7))

	# If over preview area, show snapping ghost on perimeter + mirror
	var preview_area := _get_preview_area_rect()
	if preview_area.has_point(_drag_pos):
		var angle: float = _screen_pos_to_angle(_drag_pos)
		var distance: float = clampf(_screen_pos_to_distance(_drag_pos), 0.0, 1.0)
		var snap_pos: Vector2 = _get_angle_screen_pos(angle, distance)
		# Ghost circle on perimeter
		_card_draw.draw_circle(snap_pos, 10.0, Color(0.4, 0.9, 1.0, 0.3))
		_card_draw.draw_arc(snap_pos, 10.0, 0, TAU, 12, Color(0.4, 0.9, 1.0, 0.6), 2.0, true)
		# Connecting line from cursor to snap point
		_card_draw.draw_line(_drag_pos, snap_pos, Color(0.4, 0.8, 1.0, 0.2), 1.0, true)

		# Mirror ghost
		if _symmetry_enabled and not SnapPointSystem.is_center_angle(angle) and distance >= 0.5:
			var mirror_angle: float = SnapPointSystem.get_mirror_angle(angle)
			var mirror_pos: Vector2 = _get_angle_screen_pos(mirror_angle, distance)
			_card_draw.draw_circle(mirror_pos, 8.0, Color(1.0, 0.9, 0.3, 0.2))
			_card_draw.draw_arc(mirror_pos, 8.0, 0, TAU, 12, Color(1.0, 0.9, 0.3, 0.4), 1.5, true)
			# "Mirror" label
			var ml := "Mirror"
			var mls := font.get_string_size(ml, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
			_card_draw.draw_string(font, Vector2(mirror_pos.x - mls.x * 0.5, mirror_pos.y - 16), ml, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.3, 0.5))

func _draw_symmetry_toggle(vp: Vector2, font: Font) -> void:
	var rect := _get_symmetry_toggle_rect()
	var bg: Color = Color(0.18, 0.34, 0.14, 0.75) if _symmetry_enabled else Color(0.12, 0.12, 0.18, 0.6)
	_card_draw.draw_rect(rect, bg)
	var border_col: Color = Color(1.0, 0.88, 0.35, 0.7) if _symmetry_enabled else Color(0.4, 0.4, 0.5, 0.5)
	_card_draw.draw_rect(rect, border_col, false, 1.5)
	var label: String = "SYMMETRY: ON" if _symmetry_enabled else "SYMMETRY: OFF"
	var label_col: Color = Color(1.0, 0.92, 0.45, 0.95) if _symmetry_enabled else Color(0.6, 0.6, 0.7, 0.7)
	var ls := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	_card_draw.draw_string(font, Vector2(rect.position.x + (rect.size.x - ls.x) * 0.5, rect.position.y + 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, label_col)

func _draw_placement_particles() -> void:
	for pp in _place_particles:
		var alpha: float = pp.life * pp.color.a
		_card_draw.draw_circle(pp.pos, 2.0 * pp.life, Color(pp.color.r, pp.color.g, pp.color.b, alpha))

func _draw_confirm_button(vp: Vector2, font: Font) -> void:
	var rect := _get_confirm_rect()

	# Tech-styled button background
	var bg: Color = Color(UIConstants.BTN_BG_HOVER.r, UIConstants.BTN_BG_HOVER.g, UIConstants.BTN_BG_HOVER.b, 0.95) if _confirm_hover else Color(UIConstants.BTN_BG.r, UIConstants.BTN_BG.g, UIConstants.BTN_BG.b, 0.92)
	_card_draw.draw_rect(rect, bg)

	# Corner bracket frame around button
	_draw_corner_frame(Rect2(rect.position.x - 2, rect.position.y - 2, rect.size.x + 4, rect.size.y + 4), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.75 if _confirm_hover else 0.4))

	# Border
	var border: Color = Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.9) if _confirm_hover else Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.6)
	_card_draw.draw_rect(rect, border, false, 1.5)

	# Hover glow + scan effect
	if _confirm_hover:
		var glow_rect := Rect2(rect.position.x - 4, rect.position.y - 4, rect.size.x + 8, rect.size.y + 8)
		_card_draw.draw_rect(glow_rect, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.08))
		# Scanning bar inside button
		var scan_x := fmod(_time * 80.0, rect.size.x)
		_card_draw.draw_line(Vector2(rect.position.x + scan_x, rect.position.y + 2), Vector2(rect.position.x + scan_x, rect.position.y + rect.size.y - 2), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.18), 2.0)

	var glyph: String = str(ALIEN_GLYPHS[int(fmod(_time * 0.6, ALIEN_GLYPHS.size()))])
	var label := glyph + " SAVE " + glyph if not _is_initial_customize else glyph + " CONFIRM " + glyph
	var text_col: Color = Color(UIConstants.TEXT_BRIGHT.r, UIConstants.TEXT_BRIGHT.g, UIConstants.TEXT_BRIGHT.b, 1.0) if _confirm_hover else Color(UIConstants.BTN_TEXT.r, UIConstants.BTN_TEXT.g, UIConstants.BTN_TEXT.b, 0.95)
	var ls := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
	_card_draw.draw_string(font, Vector2(rect.position.x + (rect.size.x - ls.x) * 0.5, rect.position.y + 36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, text_col)

# --- Card drawing ---

func _draw_golden_card(vp: Vector2, font: Font) -> void:
	var rect := _get_golden_card_rect()
	var card_a: float = clampf(_appear_t * 3.0 - 1.5, 0.0, 1.0)  # Appears slightly after normal cards
	var gold_col := Color(1.0, 0.85, 0.2)
	var is_rejected: bool = _selected_index >= 0  # Normal card was picked
	var is_selected: bool = _golden_selected

	if is_rejected and not is_selected:
		card_a *= (1.0 - _select_anim)
	if is_selected:
		var glow_r: float = 20.0 + _select_anim * 50.0
		_card_draw.draw_rect(Rect2(rect.position.x - glow_r * 0.5, rect.position.y - glow_r * 0.5, rect.size.x + glow_r, rect.size.y + glow_r), Color(1.0, 0.9, 0.3, (1.0 - _select_anim) * 0.2))

	# Golden gradient background
	var bg := Color(0.12, 0.1, 0.03, 0.95 * card_a)
	if _golden_hover and not is_selected and _selected_index < 0:
		bg = Color(0.18, 0.15, 0.05, 0.97 * card_a)
	if is_selected:
		bg = bg.lerp(Color(0.3, 0.25, 0.05, 0.95), _select_anim)
	_card_draw.draw_rect(rect, bg)

	# Triple golden border (premium feel)
	var border_pulse: float = 0.6 + 0.4 * sin(_time * 2.5)
	_card_draw.draw_rect(rect, Color(1.0, 0.85, 0.2, border_pulse * card_a), false, 3.0)
	_card_draw.draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), Color(1.0, 0.95, 0.5, border_pulse * 0.5 * card_a), false, 1.5)
	_card_draw.draw_rect(Rect2(rect.position + Vector2(-1, -1), rect.size + Vector2(2, 2)), Color(0.8, 0.6, 0.1, border_pulse * 0.3 * card_a), false, 1.0)

	# Hover outer glow
	if _golden_hover and not is_selected and _selected_index < 0:
		var hover_glow: float = 6.0 + 3.0 * sin(_time * 4.0)
		_card_draw.draw_rect(Rect2(rect.position - Vector2(hover_glow, hover_glow), rect.size + Vector2(hover_glow * 2, hover_glow * 2)), Color(1.0, 0.9, 0.3, 0.08 * card_a))

	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y

	# "GOLDEN ABILITY" header with star glyphs
	var header := "★ GOLDEN ★"
	var hs := font.get_string_size(header, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	_card_draw.draw_string(font, Vector2(cx - hs.x * 0.5, cy + 14), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.9, 0.4, card_a))

	# Effect type icon (procedural)
	var icon_center := Vector2(cx, cy + 65.0)
	var icon_col: Color = _golden_card.get("color", gold_col)
	_draw_golden_card_icon(_golden_card.get("effect_type", ""), icon_center, card_a, icon_col)

	# Name
	var name_str: String = _golden_card.get("name", "Unknown")
	var ns := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
	_card_draw.draw_string(font, Vector2(cx - ns.x * 0.5, cy + 115.0), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.95, 0.8, card_a))

	# Description
	var desc: String = _golden_card.get("desc", "")
	_draw_wrapped_text(font, desc, cx, cy + 132.0, CARD_WIDTH - 16.0, 9, card_a)

	# Cooldown info
	var cd_str := "Cooldown: %.0fs  |  MMB" % _golden_card.get("cooldown", 15.0)
	var cd_s := font.get_string_size(cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
	_card_draw.draw_string(font, Vector2(cx - cd_s.x * 0.5, cy + 195.0), cd_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.7, 0.4, card_a * 0.7))

	# Currently equipped indicator
	if GameManager.equipped_golden_card != "":
		var prev_card: Dictionary = GoldenCardData.get_card_by_id(GameManager.equipped_golden_card)
		if not prev_card.is_empty():
			var replace_str: String = "Replaces: " + prev_card.get("name", "Unknown")
			var rs := font.get_string_size(replace_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
			_card_draw.draw_string(font, Vector2(cx - rs.x * 0.5, cy + CARD_HEIGHT - 18.0), replace_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.5, 0.3, card_a * 0.6))

	# Sparkle particles
	for gs in _golden_sparkles:
		var sp: Vector2 = gs.pos
		var sa: float = gs.life * 0.8
		var sr: float = 2.0 + sin(gs.angle) * 1.0
		_card_draw.draw_circle(sp, sr, Color(1.0, 0.95, 0.5, sa * card_a))

	# Shimmer line (diagonal sweep)
	if card_a > 0.1:
		var shimmer_x: float = fmod(_time * 80.0, rect.size.x + 40.0) - 20.0
		var shimmer_a: float = 0.15 * card_a
		_card_draw.draw_line(
			Vector2(rect.position.x + shimmer_x, rect.position.y),
			Vector2(rect.position.x + shimmer_x - 20.0, rect.position.y + rect.size.y),
			Color(1.0, 0.95, 0.7, shimmer_a), 3.0
		)

func _draw_golden_card_icon(effect_type: String, center: Vector2, alpha: float, accent: Color) -> void:
	match effect_type:
		"flee":
			# Toxic cloud: green swirling circles
			for i in range(5):
				var a: float = TAU * i / 5.0 + _time * 1.5
				var r: float = 12.0 + sin(_time * 2.0 + i) * 4.0
				var pos := center + Vector2(cos(a), sin(a)) * r
				var cr: float = 8.0 + sin(_time * 3.0 + i * 1.3) * 3.0
				_card_draw.draw_circle(pos, cr, Color(accent.r, accent.g, accent.b, alpha * 0.25))
			_card_draw.draw_circle(center, 10.0, Color(accent.r, accent.g, accent.b, alpha * 0.5))
			# Skull hint
			_card_draw.draw_circle(center + Vector2(0, -3), 4.0, Color(0.1, 0.1, 0.1, alpha * 0.6))
			_card_draw.draw_circle(center + Vector2(-2, -4), 1.5, Color(accent.r, accent.g, accent.b, alpha))
			_card_draw.draw_circle(center + Vector2(2, -4), 1.5, Color(accent.r, accent.g, accent.b, alpha))
		"stun":
			# Lightning bolt: zigzag lines radiating out
			for i in range(8):
				var a: float = TAU * i / 8.0 + _time * 0.5
				var p1 := center + Vector2(cos(a), sin(a)) * 6.0
				var p2 := center + Vector2(cos(a + 0.15), sin(a + 0.15)) * 16.0
				var p3 := center + Vector2(cos(a - 0.1), sin(a - 0.1)) * 24.0
				var bolt_a: float = alpha * (0.5 + 0.5 * sin(_time * 6.0 + i * 1.2))
				_card_draw.draw_line(p1, p2, Color(accent.r, accent.g, accent.b, bolt_a), 2.0, true)
				_card_draw.draw_line(p2, p3, Color(accent.r, accent.g, accent.b, bolt_a * 0.7), 1.5, true)
			_card_draw.draw_circle(center, 5.0, Color(1.0, 1.0, 1.0, alpha * 0.7))
		"heal":
			# Golden cross with pulsing rings
			var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
			_card_draw.draw_circle(center, 20.0 * pulse, Color(accent.r, accent.g, accent.b, alpha * 0.15))
			_card_draw.draw_circle(center, 12.0 * pulse, Color(accent.r, accent.g, accent.b, alpha * 0.25))
			# Cross shape
			var cw: float = 4.0
			var ch: float = 14.0
			_card_draw.draw_rect(Rect2(center.x - cw * 0.5, center.y - ch * 0.5, cw, ch), Color(accent.r, accent.g, accent.b, alpha * 0.8))
			_card_draw.draw_rect(Rect2(center.x - ch * 0.5, center.y - cw * 0.5, ch, cw), Color(accent.r, accent.g, accent.b, alpha * 0.8))
		_:
			_card_draw.draw_circle(center, 14.0, Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, alpha * 0.5))

func _draw_single_card(index: int, large: bool) -> void:
	var m: Dictionary = _choices[index]
	var rect := _get_card_rect(index)
	var hovered: bool = index == _hover_index
	var font := UIConstants.get_display_font()
	var card_a: float = clampf(_appear_t * 3.0 - index * 0.5, 0.0, 1.0)

	var affinities: Array = m.get("affinities", [])
	var border_color := Color(0.3, 0.7, 0.9)
	if affinities.size() > 0:
		border_color = EvolutionData.CATEGORY_COLORS.get(affinities[0], border_color)

	var tier: int = m.get("tier", 1)
	var tier_glow: float = 0.3 + tier * 0.15
	var is_selected: bool = index == _selected_index
	var is_rejected: bool = (_selected_index >= 0 and not is_selected) or _golden_selected

	var bg_color := Color(0.07, 0.11, 0.20, 0.94 * card_a)
	if hovered and _selected_index < 0 and not _golden_selected:
		bg_color = Color(0.10, 0.16, 0.26, 0.96 * card_a)
	if is_selected:
		bg_color = bg_color.lerp(Color(border_color.r * 0.2, border_color.g * 0.2, border_color.b * 0.2, 0.95), _select_anim)
	if is_rejected:
		card_a *= (1.0 - _select_anim)
	_card_draw.draw_rect(rect, bg_color)

	if is_selected:
		var glow_r: float = 20.0 + _select_anim * 40.0
		_card_draw.draw_rect(Rect2(rect.position.x - glow_r * 0.5, rect.position.y - glow_r * 0.5, rect.size.x + glow_r, rect.size.y + glow_r), Color(border_color.r, border_color.g, border_color.b, (1.0 - _select_anim) * 0.15))

	# Border
	var bw: float = 2.0 if not hovered else 3.0
	var bc := Color(border_color.r, border_color.g, border_color.b, (tier_glow + 0.2 * sin(_time * 2.0 + index)) * card_a)
	_card_draw.draw_rect(rect, bc, false, bw)

	if hovered:
		_card_draw.draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, 0.08))

	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y

	if large:
		# Full-size card layout
		# Tier stars
		var star_y: float = cy + 16.0
		for s in range(tier):
			var sx: float = cx - (tier - 1) * 8.0 + s * 16.0
			_draw_star(Vector2(sx, star_y), 4.0, Color(1.0, 0.9, 0.3, card_a))

		# Preview
		var preview_center := Vector2(cx, cy + 65.0)
		_draw_mutation_preview(m.get("visual", ""), preview_center, card_a, border_color)

		# Name
		var name_str: String = m.get("name", "Unknown")
		var ns := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
		_card_draw.draw_string(font, Vector2(cx - ns.x * 0.5, cy + 118.0), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.97, 1.0, card_a))

		# Description (word-wrapped)
		var desc: String = m.get("desc", "")
		_draw_wrapped_text(font, desc, cx, cy + 136.0, CARD_WIDTH - 16.0, 11, card_a)

		# Stats
		var stat: Dictionary = m.get("stat", {})
		var stat_y: float = cy + 176.0
		for key in stat:
			var val: float = stat[key]
			var sign: String = "+" if val > 0 else ""
			var stat_str: String = "%s%s: %s%.0f%%" % [_stat_icon(key), _stat_label(key), sign, val * 100.0]
			var stat_s := font.get_string_size(stat_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
			_card_draw.draw_string(font, Vector2(cx - stat_s.x * 0.5, stat_y), stat_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 1.0, 0.65, card_a))
			stat_y += 16.0

		# Sensory badge
		if m.get("sensory_upgrade", false):
			var badge := "SENSORY+"
			var bs := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
			var badge_y: float = cy + CARD_HEIGHT - 22.0
			_card_draw.draw_rect(Rect2(cx - bs.x * 0.5 - 4, badge_y - 11, bs.x + 8, 16), Color(0.25, 0.14, 0.45, 0.65 * card_a))
			_card_draw.draw_string(font, Vector2(cx - bs.x * 0.5, badge_y), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.55, 1.0, card_a))
	else:
		# Small card layout for bottom strip
		# Name
		var name_str: String = m.get("name", "Unknown")
		var ns := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		_card_draw.draw_string(font, Vector2(cx - ns.x * 0.5, cy + 20), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.97, 1.0, card_a))

		# Mini preview
		var preview_center := Vector2(cx, cy + 52.0)
		_draw_mutation_preview(m.get("visual", ""), preview_center, card_a, border_color)

		# Description
		var desc: String = m.get("desc", "")
		_draw_wrapped_text(font, desc, cx, cy + 84.0, SMALL_CARD_W - 12.0, 10, card_a * 0.85)

		# Stats
		var stat: Dictionary = m.get("stat", {})
		var stat_y: float = cy + 120.0
		for key in stat:
			var val: float = stat[key]
			var sign: String = "+" if val > 0 else ""
			var stat_str: String = "%s: %s%.0f%%" % [_stat_label(key), sign, val * 100.0]
			var stat_s := font.get_string_size(stat_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			_card_draw.draw_string(font, Vector2(cx - stat_s.x * 0.5, stat_y), stat_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 1.0, 0.65, card_a))
			stat_y += 14.0

		# Tier dots
		for s in range(tier):
			_card_draw.draw_circle(Vector2(cx - (tier - 1) * 5.0 + s * 10.0, cy + SMALL_CARD_H - 14.0), 2.5, Color(1.0, 0.9, 0.3, card_a))

func _draw_wrapped_text(font: Font, text: String, cx: float, start_y: float, max_width: float, font_size: int, alpha: float) -> void:
	var desc_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	if desc_size.x > max_width:
		var words: PackedStringArray = text.split(" ")
		var lines: Array[String] = [""]
		for word in words:
			var test: String = lines[-1] + (" " if lines[-1] != "" else "") + word
			if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
				lines.append(word)
			else:
				lines[-1] = test
		for li in range(lines.size()):
			var ls := font.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			_card_draw.draw_string(font, Vector2(cx - ls.x * 0.5, start_y + li * (font_size + 3)), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.6, 0.75, 0.85, alpha * 0.8))
	else:
		_card_draw.draw_string(font, Vector2(cx - desc_size.x * 0.5, start_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.6, 0.75, 0.85, alpha * 0.8))

func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var angle: float = -PI / 2.0 + TAU * i / 10.0
		var r: float = radius if i % 2 == 0 else radius * 0.4
		pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	_card_draw.draw_colored_polygon(pts, color)

func _draw_mutation_preview(visual: String, center: Vector2, alpha: float, accent: Color) -> void:
	var c := Color(accent.r, accent.g, accent.b, alpha)
	var dim := Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, alpha * 0.5)

	match visual:
		"extra_cilia":
			for i in range(8):
				var a: float = TAU * i / 8.0 + sin(_time * 3.0) * 0.2
				var p1 := center + Vector2(cos(a), sin(a)) * 12.0
				var p2 := center + Vector2(cos(a), sin(a)) * 28.0 + Vector2(sin(_time * 4.0 + i) * 3.0, 0)
				_card_draw.draw_line(p1, p2, c, 1.5, true)
			_card_draw.draw_circle(center, 12.0, dim)
		"spikes":
			_card_draw.draw_circle(center, 14.0, dim)
			for i in range(10):
				var a: float = TAU * i / 10.0
				_card_draw.draw_line(center + Vector2(cos(a), sin(a)) * 14.0, center + Vector2(cos(a), sin(a)) * 28.0, c, 2.0, true)
		"flagellum":
			_card_draw.draw_circle(center + Vector2(0, -8), 10.0, dim)
			for i in range(10):
				var t: float = float(i) / 9.0
				var px: float = center.x + sin(_time * 5.0 + t * 4.0) * 7.0 * t
				var py: float = center.y + t * 30.0
				if i > 0:
					var pt: float = float(i - 1) / 9.0
					_card_draw.draw_line(Vector2(center.x + sin(_time * 5.0 + pt * 4.0) * 7.0 * pt, center.y + pt * 30.0), Vector2(px, py), c, 2.0 - t, true)
		"third_eye":
			_card_draw.draw_circle(center, 14.0, dim)
			_card_draw.draw_circle(center, 8.0, Color(1, 1, 1, alpha * 0.9))
			_card_draw.draw_circle(center, 4.0, Color(0.1, 0.1, 0.3, alpha))
			_card_draw.draw_circle(center + Vector2(1.5, -1), 1.5, Color(1, 1, 1, alpha))
		"bioluminescence":
			var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
			_card_draw.draw_circle(center, 20.0 * pulse, Color(c.r, c.g, c.b, alpha * 0.2))
			_card_draw.draw_circle(center, 12.0 * pulse, Color(c.r, c.g, c.b, alpha * 0.4))
			_card_draw.draw_circle(center, 5.0, Color(1, 1, 0.8, alpha))
		"color_shift":
			for i in range(3):
				var hue: float = fmod(_time * 0.3 + i * 0.33, 1.0)
				_card_draw.draw_circle(center + Vector2(cos(_time + i) * 5, sin(_time + i) * 5), 14.0 - i * 3, Color.from_hsv(hue, 0.7, 0.9, alpha * 0.6))
		"compound_eye":
			for row in range(3):
				for col in range(3):
					var ep := center + Vector2((col - 1) * 9.0, (row - 1) * 9.0)
					_card_draw.draw_circle(ep, 4.5, Color(0.9, 0.9, 1.0, alpha * 0.7))
					_card_draw.draw_circle(ep, 2.0, Color(0.1, 0.1, 0.3, alpha))
		_:
			_card_draw.draw_circle(center, 14.0, dim)
			_card_draw.draw_arc(center, 14.0, 0, TAU, 16, c, 1.5, true)

func _default_slot_for(visual: String) -> int:
	# Legacy helper, kept for backward compat in card drawing
	match visual:
		"flagellum", "rear_stinger", "tail_club": return 9
		"front_spike", "mandibles", "ramming_crest", "proboscis", "beak", "antenna": return 8
		"spikes", "armor_plates", "thick_membrane", "absorption_villi", "pili_network": return 0
		"tentacles": return 4
		"third_eye", "eye_stalks", "compound_eye", "photoreceptor": return 8
		"side_barbs": return 2
		"dorsal_fin": return 0
		"electroreceptors", "lateral_line": return 2
	return 10

func _stat_icon(key: String) -> String:
	match key:
		"speed": return ">"
		"attack": return "X"
		"max_health": return "+"
		"armor": return "#"
		"stealth": return "~"
		"detection": return "?"
		"beam_range": return "O"
		"energy_efficiency": return "*"
		"health_regen": return "+"
	return ""

func _stat_label(key: String) -> String:
	match key:
		"speed": return "Speed"
		"attack": return "Attack"
		"max_health": return "Health"
		"armor": return "Armor"
		"stealth": return "Stealth"
		"detection": return "Detection"
		"beam_range": return "Beam Range"
		"energy_efficiency": return "Efficiency"
		"health_regen": return "Regen"
	return key.capitalize()

# --- Ring handle system ---

func _get_ring_handle_at(pos: Vector2) -> String:
	if _selected_mutation_id == "" or _selected_mutation_id not in GameManager.mutation_placements:
		return ""
	var p: Dictionary = GameManager.mutation_placements[_selected_mutation_id]
	var angle: float = p.get("angle", 0.0)
	var distance: float = p.get("distance", 1.0)
	var rot_offset: float = p.get("rotation_offset", 0.0)
	var sp: Vector2 = _get_angle_screen_pos(angle, distance)
	var hit_r: float = RING_HANDLE_R + 6.0

	# Check rotation handle first (most common)
	var rot_handle_pos: Vector2 = sp + Vector2(cos(angle + rot_offset - PI * 0.5), sin(angle + rot_offset - PI * 0.5)) * RING_RADIUS
	if pos.distance_to(rot_handle_pos) < hit_r:
		return "rotate"

	# Check 4 scale handles
	for i in range(4):
		var scale_angle: float = angle + rot_offset + i * PI * 0.5
		var scale_pos: Vector2 = sp + Vector2(cos(scale_angle), sin(scale_angle)) * RING_RADIUS
		if pos.distance_to(scale_pos) < hit_r:
			return "scale_%d" % i

	return ""

func _start_ring_drag(handle: String, pos: Vector2) -> void:
	_ring_drag_mode = handle
	var p: Dictionary = GameManager.mutation_placements.get(_selected_mutation_id, {})
	var sp: Vector2 = _get_angle_screen_pos(p.get("angle", 0.0), p.get("distance", 1.0))
	_ring_drag_start_angle = atan2(pos.y - sp.y, pos.x - sp.x)
	if handle == "rotate":
		_ring_drag_start_value = p.get("rotation_offset", 0.0)
	else:
		_ring_drag_start_value = p.get("scale", 1.0)

func _update_ring_drag(pos: Vector2) -> void:
	if _ring_drag_mode == "" or _selected_mutation_id == "":
		return
	var p: Dictionary = GameManager.mutation_placements.get(_selected_mutation_id, {})
	var sp: Vector2 = _get_angle_screen_pos(p.get("angle", 0.0), p.get("distance", 1.0))
	var current_angle: float = atan2(pos.y - sp.y, pos.x - sp.x)
	var delta_angle: float = current_angle - _ring_drag_start_angle

	if _ring_drag_mode == "rotate":
		var new_rot: float = _ring_drag_start_value + delta_angle
		GameManager.update_mutation_rotation(_selected_mutation_id, new_rot)
	elif _ring_drag_mode.begins_with("scale"):
		# Scale based on distance from center
		var dist: float = pos.distance_to(sp)
		var new_scale: float = clampf(dist / RING_RADIUS, 0.4, 2.5)
		GameManager.update_mutation_scale(_selected_mutation_id, new_scale)

func _end_ring_drag() -> void:
	_ring_drag_mode = ""
	_ring_drag_start_angle = 0.0
	_ring_drag_start_value = 0.0

# --- Tooltip system ---

func _draw_card_tooltip(card: Dictionary, card_rect: Rect2, below: bool, is_golden: bool) -> void:
	var font := UIConstants.get_display_font()
	var vp := _get_vp()
	var alpha: float = _tooltip_alpha

	var tooltip_w: float = 280.0
	var name_str: String = card.get("name", "Unknown")
	var gameplay_desc: String = card.get("gameplay_desc", "")
	var tier: int = card.get("tier", 0)
	var stat: Dictionary = card.get("stat", {})
	var affinities: Array = card.get("affinities", [])

	if gameplay_desc == "":
		return  # No tooltip if no gameplay desc

	# Word-wrap gameplay_desc to estimate height
	var desc_lines: Array[String] = _wrap_text(font, gameplay_desc, tooltip_w - 20.0, 13)
	var stat_count: int = stat.size()
	var affinity_line: bool = affinities.size() > 0

	var tooltip_h: float = 20.0  # top padding + name
	tooltip_h += 8.0  # separator
	tooltip_h += desc_lines.size() * 18.0  # gameplay desc lines
	tooltip_h += 8.0  # gap
	if stat_count > 0:
		tooltip_h += stat_count * 16.0 + 4.0  # stats
	if affinity_line:
		tooltip_h += 18.0  # affinity line
	tooltip_h += 10.0  # bottom padding

	# Position: centered below card, or above if it would go off-screen
	var tx: float = card_rect.position.x + card_rect.size.x * 0.5 - tooltip_w * 0.5
	tx = clampf(tx, 8.0, vp.x - tooltip_w - 8.0)
	var ty: float
	if below:
		ty = card_rect.position.y + card_rect.size.y + 8.0
		if ty + tooltip_h > vp.y - 8.0:
			ty = card_rect.position.y - tooltip_h - 8.0  # Flip above
	else:
		ty = card_rect.position.y - tooltip_h - 8.0  # Above for small cards
		if ty < 8.0:
			ty = card_rect.position.y + card_rect.size.y + 8.0  # Flip below

	var tooltip_rect := Rect2(tx, ty, tooltip_w, tooltip_h)

	# Background
	var bg_col := Color(0.06, 0.09, 0.16, 0.95 * alpha)
	_card_draw.draw_rect(tooltip_rect, bg_col)

	# Border — affinity colored or golden
	var border_col: Color
	if is_golden:
		border_col = Color(1.0, 0.85, 0.2, 0.8 * alpha)
	elif affinities.size() > 0:
		border_col = EvolutionData.CATEGORY_COLORS.get(affinities[0], Color(0.3, 0.7, 0.9))
		border_col = Color(border_col.r, border_col.g, border_col.b, 0.7 * alpha)
	else:
		border_col = Color(0.3, 0.7, 0.9, 0.6 * alpha)
	_card_draw.draw_rect(tooltip_rect, border_col, false, 1.5)

	var cy: float = ty + 18.0
	var cx: float = tx + 10.0

	# Name + tier stars
	_card_draw.draw_string(font, Vector2(cx, cy), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.98, 1.0, alpha))
	if tier > 0:
		var star_x: float = tx + tooltip_w - 10.0 - tier * 14.0
		for s in range(tier):
			_draw_star(Vector2(star_x + s * 14.0 + 5.0, cy - 4.0), 4.0, Color(1.0, 0.9, 0.3, alpha))

	cy += 6.0
	# Separator line
	_card_draw.draw_line(Vector2(cx, cy), Vector2(tx + tooltip_w - 10.0, cy), Color(border_col.r, border_col.g, border_col.b, 0.3 * alpha), 1.0)
	cy += 10.0

	# Gameplay description
	for line in desc_lines:
		_card_draw.draw_string(font, Vector2(cx, cy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.88, 0.95, 0.9 * alpha))
		cy += 18.0

	cy += 4.0

	# Stats
	if stat_count > 0:
		for key in stat:
			var val: float = stat[key]
			var sign: String = "+" if val > 0 else ""
			var stat_str: String = "> %s: %s%.0f%%" % [_stat_label(key), sign, val * 100.0]
			_card_draw.draw_string(font, Vector2(cx, cy), stat_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 1.0, 0.6, 0.85 * alpha))
			cy += 16.0
		cy += 2.0

	# Affinities
	if affinity_line:
		var aff_names: PackedStringArray = PackedStringArray()
		for a in affinities:
			aff_names.append(a.capitalize().replace("_", " "))
		var aff_str: String = "Affinity: " + ", ".join(aff_names)
		_card_draw.draw_string(font, Vector2(cx, cy), aff_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.7, 0.8, 0.7 * alpha))

func _wrap_text(font: Font, text: String, max_width: float, font_size: int) -> Array[String]:
	var desc_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	if desc_size.x <= max_width:
		return [text]
	var words: PackedStringArray = text.split(" ")
	var lines: Array[String] = [""]
	for word in words:
		var test: String = lines[-1] + (" " if lines[-1] != "" else "") + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
			lines.append(word)
		else:
			lines[-1] = test
	return lines

# --- Morph handle system ---

func _get_morph_handle_at(pos: Vector2) -> int:
	## Returns handle index (0-7) if pos is near a morph handle, -1 otherwise
	var center := _get_preview_center()
	var s: float = _get_preview_scale()
	var cr: float = _get_preview_cell_radius()
	var handles: Array = _get_preview_handles()
	var hit_dist: float = 15.0
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		var r: float = SnapPointSystem.get_radius_at_angle(angle, cr, handles)
		var handle_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * r * s
		if pos.distance_to(handle_pos) < hit_dist:
			return i
	return -1

func _update_morph_handle_drag(pos: Vector2) -> void:
	## Update handle radius based on drag position
	if _dragging_morph_handle < 0 or _dragging_morph_handle >= 8:
		return
	var center := _get_preview_center()
	var s: float = _get_preview_scale()
	var cr: float = _get_preview_cell_radius()
	var evo_scale: float = 1.0 + GameManager.evolution_level * 0.08
	var dist_from_center: float = (pos - center).length() / (cr * s)
	# Convert screen distance to raw handle value (divide out evo_scale)
	var raw_value: float = clampf(dist_from_center / evo_scale, 0.5, 2.0)
	GameManager.update_body_handle(_dragging_morph_handle, raw_value)
	if _preview and _preview.has_method("refresh_handles"):
		_preview.refresh_handles()

# --- Eye drag system ---

func _get_eye_screen_positions() -> Array:
	## Returns [{pos, size}] for each eye in screen coords
	var center := _get_preview_center()
	var s: float = _get_preview_scale()
	var cr: float = _get_preview_cell_radius()
	var eyes: Array = GameManager.get_eyes()
	var result: Array = []
	for eye in eyes:
		var ep: Vector2 = center + Vector2(eye.get("x", 0.0), eye.get("y", 0.0)) * cr * s
		var er: float = eye.get("size", 3.5) * s * 0.3
		result.append({"pos": ep, "size": er})
	return result

func _get_eye_at_pos(pos: Vector2) -> int:
	## Returns eye index or -1 for none
	var eye_data: Array = _get_eye_screen_positions()
	for i in range(eye_data.size()):
		var ep: Vector2 = eye_data[i].pos
		var er: float = eye_data[i].size
		if pos.distance_to(ep) < er * 2.0:
			return i
	return -1

func _update_eye_drag(pos: Vector2) -> void:
	## Convert screen position to normalized eye coords and update
	var center := _get_preview_center()
	var s: float = _get_preview_scale()
	var cr: float = _get_preview_cell_radius()
	var offset: Vector2 = pos - center
	var new_x: float = clampf(offset.x / (cr * s), -1.0, 1.0)
	var new_y: float = clampf(offset.y / (cr * s), -1.0, 1.0)
	# Clamp to unit circle
	var dist: float = sqrt(new_x * new_x + new_y * new_y)
	if dist > 1.0:
		new_x /= dist
		new_y /= dist
	if _dragging_eye_index >= 0:
		GameManager.update_eye(_dragging_eye_index, {"x": new_x, "y": new_y})

func _draw_eye_handles(vp: Vector2, font: Font) -> void:
	var eye_data: Array = _get_eye_screen_positions()
	if eye_data.is_empty():
		return
	var handle_col: Color = Color(0.3, 0.9, 1.0, 0.5)
	var active_col: Color = Color(0.5, 1.0, 1.0, 0.8)

	var show_handles: bool = _eye_selected or _dragging_eye
	if show_handles:
		for i in range(eye_data.size()):
			var ep: Vector2 = eye_data[i].pos
			var er: float = eye_data[i].size
			var ring_r: float = er + 6.0
			var is_dragged: bool = _dragging_eye and _dragging_eye_index == i
			var col: Color = active_col if is_dragged else handle_col
			_card_draw.draw_arc(ep, ring_r, 0, TAU, 16, col, 1.5, true)
			# Small resize squares at corners
			for j in range(4):
				var sq_angle: float = PI * 0.25 + j * PI * 0.5
				var sq_pos: Vector2 = ep + Vector2(cos(sq_angle), sin(sq_angle)) * ring_r
				var sq_sz: float = 4.0
				_card_draw.draw_rect(Rect2(sq_pos.x - sq_sz * 0.5, sq_pos.y - sq_sz * 0.5, sq_sz, sq_sz), col)

	# "DRAG TO MOVE" hint (fades after 3s on first open)
	if _eye_drag_hint_timer > 0.0 and _eye_drag_hint_timer < 3.0 and eye_data.size() >= 1:
		var hint_alpha: float = clampf(_eye_drag_hint_timer / 1.0, 0.0, 1.0) * 0.7
		var hint_pos: Vector2 = eye_data[0].pos + Vector2(0, eye_data[0].size + 22.0)
		var hint_str := "Click eye to drag, scroll to resize, right-click to remove"
		var hs := font.get_string_size(hint_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		_card_draw.draw_string(font, Vector2(hint_pos.x - hs.x * 0.5, hint_pos.y), hint_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.9, 1.0, hint_alpha))

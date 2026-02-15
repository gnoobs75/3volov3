class_name SnapPointSystem
## Static utility: 12 snap slots around the creature body.
## Handles positions, symmetry detection, and mirroring.

# Snap positions as normalized offsets from cell center.
# Multiply by cell_radius to get world positions.
# In the cell's local space: +X = front, -X = back, +Y = right (bottom in screen), -Y = left (top in screen).
const SNAP_POSITIONS: Array = [
	Vector2(0, -1.15),      # 0: Top (center — no mirror)
	Vector2(0.82, -0.82),   # 1: TopRight
	Vector2(1.15, 0),       # 2: Right
	Vector2(0.82, 0.82),    # 3: BottomRight
	Vector2(0, 1.15),       # 4: Bottom (center — no mirror)
	Vector2(-0.82, 0.82),   # 5: BottomLeft
	Vector2(-1.15, 0),      # 6: Left
	Vector2(-0.82, -0.82),  # 7: TopLeft
	Vector2(0.6, 0),        # 8: Front (center — no mirror)
	Vector2(-0.6, 0),       # 9: Back (center — no mirror)
	Vector2(0, 0),          # 10: Core (center — no mirror)
	Vector2(0.35, 0),       # 11: InsideFront (center — no mirror)
]

const SLOT_NAMES: Array = [
	"Top", "Top-Right", "Right", "Bottom-Right",
	"Bottom", "Bottom-Left", "Left", "Top-Left",
	"Front", "Back", "Core", "Inside-Front",
]

# Center slots don't get mirrored
const CENTER_SLOTS: Array = [0, 4, 8, 9, 10, 11]

# Mirror pairs: slot -> its mirrored counterpart
const MIRROR_MAP: Dictionary = {
	1: 7,   # TopRight <-> TopLeft
	2: 6,   # Right <-> Left
	3: 5,   # BottomRight <-> BottomLeft
	5: 3,   # BottomLeft <-> BottomRight
	6: 2,   # Left <-> Right
	7: 1,   # TopLeft <-> TopRight
}

static func get_snap_position(slot: int, cell_radius: float, elongation: float = 1.0) -> Vector2:
	if slot < 0 or slot >= SNAP_POSITIONS.size():
		return Vector2.ZERO
	var base: Vector2 = SNAP_POSITIONS[slot]
	return Vector2(base.x * cell_radius * elongation, base.y * cell_radius)

static func is_center_slot(slot: int) -> bool:
	return slot in CENTER_SLOTS

static func get_mirrored_slot(slot: int) -> int:
	return MIRROR_MAP.get(slot, -1)

static func find_closest_snap(local_pos: Vector2, cell_radius: float, elongation: float = 1.0, snap_range: float = 30.0) -> int:
	var best_dist: float = snap_range
	var best_slot: int = -1
	for i in range(SNAP_POSITIONS.size()):
		var sp: Vector2 = get_snap_position(i, cell_radius, elongation)
		var dist: float = local_pos.distance_to(sp)
		if dist < best_dist:
			best_dist = dist
			best_slot = i
	return best_slot

static func get_slot_count() -> int:
	return SNAP_POSITIONS.size()

# --- Angular placement system (freeform Spore-style) ---

const CENTER_ANGLE_THRESHOLD: float = 0.15  # Radians near 0 or PI = center (no mirror)

## Convert an angle (radians, 0=front/+X, PI=back) to a perimeter position on an ellipse.
static func angle_to_perimeter_position(angle: float, cell_radius: float, elongation: float = 1.0, distance: float = 1.0) -> Vector2:
	var rx: float = cell_radius * elongation * distance
	var ry: float = cell_radius * distance
	return Vector2(cos(angle) * rx, sin(angle) * ry)

## True if angle is within threshold of 0 (front) or PI (back) — center parts don't mirror.
static func is_center_angle(angle: float) -> bool:
	var normalized: float = fmod(angle + TAU, TAU)
	# Near 0 / TAU
	if normalized < CENTER_ANGLE_THRESHOLD or normalized > TAU - CENTER_ANGLE_THRESHOLD:
		return true
	# Near PI
	if absf(normalized - PI) < CENTER_ANGLE_THRESHOLD:
		return true
	return false

## Mirror an angle across the horizontal axis (front-to-back). Flips sign of angle.
static func get_mirror_angle(angle: float) -> float:
	return fmod(-angle + TAU, TAU)

## Default angle for a mutation visual type (replaces _default_slot_for).
static func get_default_angle_for_visual(visual: String) -> float:
	match visual:
		"flagellum", "rear_stinger", "tail_club":
			return PI  # Back
		"front_spike", "mandibles", "ramming_crest", "proboscis", "beak", "antenna":
			return 0.0  # Front
		"third_eye", "eye_stalks", "compound_eye", "photoreceptor":
			return 0.0  # Front
		"tentacles":
			return PI * 0.5  # Bottom
		"spikes", "armor_plates", "thick_membrane", "absorption_villi", "pili_network":
			return -PI * 0.5  # Top
		"dorsal_fin":
			return -PI * 0.5  # Top
		"side_barbs", "electroreceptors", "lateral_line":
			return PI * 0.25  # Side (bottom-right quadrant)
	return 0.0  # Default: front

## Default distance for a mutation visual (0.0=core, 1.0=membrane perimeter).
static func get_default_distance_for_visual(visual: String) -> float:
	match visual:
		"bioluminescence", "color_shift", "regeneration", "enzyme_boost", "sprint_boost":
			return 0.0  # Core/global
		"hardened_nucleus", "symbiont_pouch", "chrono_enzyme":
			return 0.3  # Inner
		"toxin_glands", "ink_sac", "gas_vacuole", "thermal_vent_organ":
			return 0.5  # Mid
	return 1.0  # Membrane perimeter (default)

## Migration: convert old snap_slot index to an angle.
static func snap_slot_to_angle(slot: int) -> float:
	match slot:
		0: return -PI * 0.5     # Top
		1: return -PI * 0.25    # TopRight
		2: return 0.0 + PI * 0.01  # Right (slight offset to avoid exact center)
		3: return PI * 0.25     # BottomRight
		4: return PI * 0.5      # Bottom
		5: return PI * 0.75     # BottomLeft
		6: return PI - 0.01     # Left (slight offset)
		7: return -PI * 0.75    # TopLeft
		8: return 0.0           # Front (center)
		9: return PI            # Back (center)
		10: return 0.0          # Core (center)
		11: return 0.0          # InsideFront (center)
	return 0.0

## Migration: convert old snap_slot index to a distance.
static func snap_slot_to_distance(slot: int) -> float:
	match slot:
		10: return 0.0  # Core
		11: return 0.3  # InsideFront
		8: return 0.6   # Front (slightly inside)
		9: return 0.6   # Back (slightly inside)
	return 1.0  # All perimeter slots

## Get the outward rotation angle at a given perimeter angle (for orienting mutations).
static func get_outward_rotation(angle: float) -> float:
	return angle

# --- Morph Handle System (8 handles at 45-degree intervals) ---

## Interpolate radius multiplier from 8 morph handles at a given angle.
## Uses cosine interpolation for smooth curves between handles.
static func get_radius_at_angle(angle: float, cell_radius: float, handles: Array) -> float:
	if handles.size() != 8:
		return cell_radius
	var sector: float = fmod(angle + TAU, TAU) / TAU * 8.0
	var i0: int = int(sector) % 8
	var i1: int = (i0 + 1) % 8
	var t: float = sector - floorf(sector)
	var smooth_t: float = (1.0 - cos(t * PI)) * 0.5
	return lerpf(handles[i0], handles[i1], smooth_t) * cell_radius

## Get perimeter position using morph handles instead of elongation/bulge.
static func angle_to_perimeter_position_morphed(angle: float, cell_radius: float, handles: Array, distance: float = 1.0) -> Vector2:
	var r: float = get_radius_at_angle(angle, cell_radius, handles) * distance
	return Vector2(cos(angle) * r, sin(angle) * r)

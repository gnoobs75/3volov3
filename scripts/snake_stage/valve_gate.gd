extends Node3D
## Fleshy iris gate that opens when player approaches.
## 6 petal segments that rotate outward to reveal passage.
## Placed at tunnel midpoints by cave_generator.

var _petals: Array[MeshInstance3D] = []
var _open_amount: float = 0.0  # 0 = closed, 1 = fully open
var _target_open: float = 0.0
var _gate_color: Color = Color(0.08, 0.04, 0.04)
var _emission_color: Color = Color(0.5, 0.1, 0.08)
var _gate_radius: float = 5.0
const PETAL_COUNT: int = 6
const OPEN_DISTANCE: float = 30.0  # Player proximity to trigger open
const OPEN_SPEED: float = 2.0

func setup(radius: float, gate_col: Color, emission_col: Color) -> void:
	_gate_radius = radius
	_gate_color = gate_col
	_emission_color = emission_col

func _ready() -> void:
	_build_iris()

func _build_iris() -> void:
	for i in range(PETAL_COUNT):
		var angle_offset: float = TAU / PETAL_COUNT * i

		# Pivot at gate rim
		var pivot: Node3D = Node3D.new()
		pivot.name = "PetalPivot_%d" % i
		pivot.rotation.z = angle_offset
		add_child(pivot)

		# Petal mesh: flattened wedge shape (use CylinderMesh sector)
		var petal: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.1
		mesh.bottom_radius = _gate_radius * 0.6
		mesh.height = 0.15
		mesh.radial_segments = 6
		petal.mesh = mesh
		petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = _gate_color
		mat.roughness = 0.7
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.emission_enabled = true
		mat.emission = _emission_color
		mat.emission_energy_multiplier = 0.3
		petal.material_override = mat

		# Position petal extending inward from rim
		petal.position = Vector3(0, _gate_radius * 0.3, 0)
		petal.rotation.x = PI * 0.5  # Flat disc orientation
		pivot.add_child(petal)
		_petals.append(petal)

	# Center sphincter light
	var center_light: OmniLight3D = OmniLight3D.new()
	center_light.name = "GateLight"
	center_light.light_color = _emission_color.lightened(0.3)
	center_light.light_energy = 0.3
	center_light.omni_range = _gate_radius * 1.5
	center_light.omni_attenuation = 1.5
	center_light.shadow_enabled = false
	add_child(center_light)

func _process(delta: float) -> void:
	# Check player proximity
	var player_nodes: Array = get_tree().get_nodes_in_group("player_worm")
	if player_nodes.size() > 0:
		var player: Node3D = player_nodes[0]
		var dist: float = global_position.distance_to(player.global_position)
		_target_open = 1.0 if dist < OPEN_DISTANCE else 0.0
	else:
		_target_open = 0.0

	# Smoothly interpolate open amount
	_open_amount = lerpf(_open_amount, _target_open, delta * OPEN_SPEED)

	# Apply to petal pivots (rotate outward to open)
	for i in range(get_child_count()):
		var child: Node = get_child(i)
		if child.name.begins_with("PetalPivot"):
			# When open: rotate petal outward 85 degrees
			child.rotation.x = _open_amount * deg_to_rad(85.0)

static func create_gate(tunnel_data, cave_gen) -> Node3D:
	## Factory: creates a valve gate at the midpoint of a tunnel.
	if tunnel_data.path.size() < 4:
		return null

	var gate_script = load("res://scripts/snake_stage/valve_gate.gd")
	var gate: Node3D = Node3D.new()
	gate.set_script(gate_script)
	gate.name = "ValveGate_%d" % tunnel_data.id

	# Position at tunnel midpoint, centered vertically in hallway
	var mid_idx: int = tunnel_data.path.size() / 2
	var hall_h: float = tunnel_data.width * 0.6 * 0.5  # Half hallway height
	gate.global_position = tunnel_data.path[mid_idx] + Vector3(0, hall_h, 0)

	# Orient gate perpendicular to tunnel direction
	var fwd: Vector3 = Vector3.ZERO
	if mid_idx + 1 < tunnel_data.path.size() and mid_idx > 0:
		fwd = (tunnel_data.path[mid_idx + 1] - tunnel_data.path[mid_idx - 1]).normalized()
	if fwd.length() < 0.1:
		fwd = Vector3.FORWARD
	var up: Vector3 = Vector3.UP
	if absf(fwd.dot(up)) > 0.95:
		up = Vector3.RIGHT
	gate.look_at(gate.global_position + fwd, up)

	# Colors from biome blend
	var col_a: Dictionary = cave_gen.get_biome_colors(tunnel_data.biome_a)
	var col_b: Dictionary = cave_gen.get_biome_colors(tunnel_data.biome_b)
	var gate_col: Color = col_a.wall.lerp(col_b.wall, 0.5).lightened(0.1)
	var emission_col: Color = col_a.emission.lerp(col_b.emission, 0.5)

	gate.setup(tunnel_data.width * 0.5, gate_col, emission_col)
	return gate

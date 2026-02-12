extends Node3D
class_name AmbientLife
## Static factory: spawns non-aggressive ambient creatures in cave hubs.
## 4 types: Red Blood Cells, Platelets, Microbiome Bacteria, Cilia Plankton.

static func spawn_ambient_creatures(hub: Node3D, biome: int, count: int) -> void:
	var hub_data = hub._hub_data
	if not hub_data:
		return
	var radius: float = hub_data.radius * 0.7

	for i in range(count):
		var creature: Node3D = _create_ambient(biome, i)
		if not creature:
			continue
		var angle: float = randf() * TAU
		var r: float = radius * sqrt(randf())
		var y_offset: float = randf_range(1.0, 8.0)
		creature.position = Vector3(cos(angle) * r, y_offset, sin(angle) * r)
		hub.add_child(creature)

static func _create_ambient(biome: int, index: int) -> Node3D:
	# Pick type based on biome affinity
	var types: Array = _get_types_for_biome(biome)
	if types.is_empty():
		types = ["platelet"]
	var creature_type: String = types[index % types.size()]

	match creature_type:
		"red_blood_cell":
			return _create_red_blood_cell()
		"platelet":
			return _create_platelet()
		"bacteria":
			return _create_bacteria()
		"cilia_plankton":
			return _create_cilia_plankton()
	return _create_platelet()

static func _get_types_for_biome(biome: int) -> Array:
	match biome:
		0: return ["red_blood_cell", "platelet", "bacteria"]  # STOMACH
		1: return ["red_blood_cell", "red_blood_cell", "platelet"]  # HEART
		2: return ["bacteria", "bacteria", "platelet"]  # INTESTINE
		3: return ["cilia_plankton", "cilia_plankton", "platelet"]  # LUNG
		4: return ["platelet", "red_blood_cell", "platelet"]  # BONE_MARROW
		5: return ["bacteria", "platelet", "red_blood_cell"]  # LIVER
		6: return ["platelet", "cilia_plankton", "platelet"]  # BRAIN
	return ["platelet"]

static func _create_red_blood_cell() -> Node3D:
	var rbc: Node3D = Node3D.new()
	rbc.name = "RedBloodCell"
	rbc.add_to_group("ambient_life")
	rbc.set_meta("creature_id", "red_blood_cell")

	# Disc-shaped body (flattened torus-like)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.4
	disc.bottom_radius = 0.4
	disc.height = 0.12
	disc.radial_segments = 16
	mesh.mesh = disc

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.15, 0.1, 0.7)
	mat.roughness = 0.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.1, 0.05)
	mat.emission_energy_multiplier = 1.0
	mesh.material_override = mat
	rbc.add_child(mesh)

	# Soft glow
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.8, 0.15, 0.1)
	light.light_energy = 0.2
	light.omni_range = 2.0
	light.shadow_enabled = false
	rbc.add_child(light)

	# Drift behavior script
	var script = _get_drift_script()
	rbc.set_script(script)

	return rbc

static func _create_platelet() -> Node3D:
	var plt: Node3D = Node3D.new()
	plt.name = "Platelet"
	plt.add_to_group("ambient_life")
	plt.set_meta("creature_id", "platelet")

	# Tiny irregular cluster (small spheres)
	for j in range(randi_range(2, 4)):
		var bit: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = randf_range(0.08, 0.15)
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		bit.mesh = sphere

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.85, 0.7, 0.6)
		mat.roughness = 0.4
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.75, 0.5)
		mat.emission_energy_multiplier = 0.5
		bit.material_override = mat
		bit.position = Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.05), randf_range(-0.1, 0.1))
		plt.add_child(bit)

	var script = _get_drift_script()
	plt.set_script(script)
	return plt

static func _create_bacteria() -> Node3D:
	var bac: Node3D = Node3D.new()
	bac.name = "Bacteria"
	bac.add_to_group("ambient_life")
	bac.set_meta("creature_id", "bacteria")

	# Rod shape
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var rod: CapsuleMesh = CapsuleMesh.new()
	rod.radius = 0.1
	rod.height = 0.5
	rod.radial_segments = 8
	rod.rings = 4
	mesh.mesh = rod

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.7, 0.3, 0.65)
	mat.roughness = 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 0.2)
	mat.emission_energy_multiplier = 0.8
	mesh.material_override = mat
	bac.add_child(mesh)

	var script = _get_drift_script()
	bac.set_script(script)
	return bac

static func _create_cilia_plankton() -> Node3D:
	var cp: Node3D = Node3D.new()
	cp.name = "CiliaPlankton"
	cp.add_to_group("ambient_life")
	cp.set_meta("creature_id", "cilia_plankton")

	# Central body
	var body: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	sphere.radial_segments = 10
	sphere.rings = 5
	body.mesh = sphere

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.8, 0.9, 0.5)
	mat.roughness = 0.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.7, 0.9)
	mat.emission_energy_multiplier = 1.2
	body.material_override = mat
	cp.add_child(body)

	# Feathery tendrils (thin cylinders)
	for j in range(5):
		var tendril: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.005
		cyl.bottom_radius = 0.02
		cyl.height = 0.3
		cyl.radial_segments = 4
		tendril.mesh = cyl
		var t_mat: StandardMaterial3D = StandardMaterial3D.new()
		t_mat.albedo_color = Color(0.5, 0.7, 0.85, 0.4)
		t_mat.roughness = 0.4
		t_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		t_mat.emission_enabled = true
		t_mat.emission = Color(0.4, 0.6, 0.8)
		t_mat.emission_energy_multiplier = 0.6
		tendril.material_override = t_mat
		var a: float = TAU * j / 5.0
		tendril.position = Vector3(cos(a) * 0.12, -0.15, sin(a) * 0.12)
		tendril.rotation.z = cos(a) * 0.5
		tendril.rotation.x = sin(a) * 0.5
		cp.add_child(tendril)

	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.5, 0.7, 0.9)
	light.light_energy = 0.15
	light.omni_range = 1.5
	light.shadow_enabled = false
	cp.add_child(light)

	var script = _get_drift_script()
	cp.set_script(script)
	return cp

static func _get_drift_script() -> GDScript:
	# Returns a shared drift behavior script (compiled once, cached)
	if _drift_script_cache:
		return _drift_script_cache
	_drift_script_cache = GDScript.new()
	_drift_script_cache.source_code = DRIFT_SCRIPT_CODE
	_drift_script_cache.reload()
	return _drift_script_cache

static var _drift_script_cache: GDScript = null

const DRIFT_SCRIPT_CODE: String = """
extends Node3D
## Simple ambient drift AI: float around lazily, scatter on player proximity.

var _time: float = 0.0
var _drift_dir: Vector3 = Vector3.ZERO
var _drift_speed: float = 0.0
var _base_y: float = 0.0
var _scatter_timer: float = 0.0

func _ready() -> void:
	_time = randf() * 10.0
	_drift_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_drift_speed = randf_range(0.3, 0.8)
	_base_y = position.y

func _process(delta: float) -> void:
	_time += delta
	_scatter_timer = maxf(_scatter_timer - delta, 0.0)

	# Check player proximity for scatter
	var players: Array = get_tree().get_nodes_in_group(\"player_worm\")
	if players.size() > 0:
		var player: Node3D = players[0]
		var dist: float = global_position.distance_to(player.global_position)
		if dist < 5.0 and _scatter_timer <= 0:
			# Scatter away from player
			var away: Vector3 = (global_position - player.global_position).normalized()
			_drift_dir = Vector3(away.x, 0, away.z).normalized()
			_drift_speed = 2.5
			_scatter_timer = 3.0

	# Slow down after scatter
	if _scatter_timer <= 0:
		_drift_speed = lerpf(_drift_speed, randf_range(0.3, 0.8), delta * 2.0)
		# Gentle random direction changes
		if fmod(_time, 4.0) < delta:
			_drift_dir = _drift_dir.rotated(Vector3.UP, randf_range(-0.5, 0.5)).normalized()

	# Move
	position += _drift_dir * _drift_speed * delta

	# Gentle vertical bob
	position.y = _base_y + sin(_time * 1.5) * 0.3

	# Slow rotation for visual interest
	rotation.y += delta * 0.5
"""

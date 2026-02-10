extends Node2D
## Bioluminescent ambient particles using GPUParticles2D for massive performance gain.
## Multiple particle systems for different visual types, all GPU-driven.
## Follows the player to create an infinite ocean feel.

var _player: Node2D = null
var _time: float = 0.0
var _systems: Array[GPUParticles2D] = []

func _ready() -> void:
	call_deferred("_find_player")
	_build_particle_systems()

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _build_particle_systems() -> void:
	# System 1: Cyan micro-plankton (most common, tiny dots)
	_add_system(
		150, 4.0,
		Color(0.3, 0.7, 1.0, 0.15),
		Vector2(600, 600),  # emission area
		Vector2(0.8, 0.8),  # particle size
		Vector2(-6.0, -10.0),  # drift direction
		5.0  # drift speed variation
	)

	# System 2: Green bioluminescent specks
	_add_system(
		100, 5.0,
		Color(0.2, 1.0, 0.5, 0.12),
		Vector2(500, 500),
		Vector2(1.0, 1.0),
		Vector2(4.0, -8.0),
		6.0
	)

	# System 3: Pink/warm glow dots
	_add_system(
		60, 6.0,
		Color(1.0, 0.5, 0.7, 0.1),
		Vector2(550, 550),
		Vector2(1.2, 1.2),
		Vector2(-3.0, -5.0),
		4.0
	)

	# System 4: Purple drifters
	_add_system(
		50, 5.5,
		Color(0.6, 0.4, 1.0, 0.13),
		Vector2(480, 480),
		Vector2(0.9, 0.9),
		Vector2(5.0, -7.0),
		5.0
	)

	# System 5: Teal jellyfish plankton (larger, fewer, brighter)
	_add_system(
		20, 8.0,
		Color(0.4, 0.9, 0.9, 0.2),
		Vector2(600, 600),
		Vector2(3.0, 3.0),
		Vector2(-2.0, -4.0),
		3.0
	)

func _add_system(
	count: int, lifetime: float,
	color: Color, emission_area: Vector2,
	particle_size: Vector2, drift: Vector2, speed_variation: float
) -> void:
	var gpu: GPUParticles2D = GPUParticles2D.new()
	gpu.amount = count
	gpu.lifetime = lifetime
	gpu.preprocess = lifetime  # Pre-fill so particles exist immediately

	var proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(emission_area.x, emission_area.y, 0)

	# Drift direction
	proc.direction = Vector3(drift.x, drift.y, 0).normalized()
	proc.spread = 30.0
	proc.initial_velocity_min = maxf(drift.length() - speed_variation, 0.5)
	proc.initial_velocity_max = drift.length() + speed_variation

	# No gravity — floating particles
	proc.gravity = Vector3(0, 0, 0)

	# Scale
	proc.scale_min = particle_size.x * 0.5
	proc.scale_max = particle_size.x * 1.5

	# Color with fade in/out
	proc.color = color

	# Alpha curve: fade in, hold, fade out
	var alpha_curve: CurveTexture = CurveTexture.new()
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(0.85, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	proc.alpha_curve = alpha_curve

	# Scale curve: gentle pulse
	var scale_curve: CurveTexture = CurveTexture.new()
	var s_curve: Curve = Curve.new()
	s_curve.add_point(Vector2(0.0, 0.6))
	s_curve.add_point(Vector2(0.3, 1.0))
	s_curve.add_point(Vector2(0.7, 1.2))
	s_curve.add_point(Vector2(1.0, 0.4))
	scale_curve.curve = s_curve
	proc.scale_curve = scale_curve

	gpu.process_material = proc

	# Use a simple circle texture rendered as a CanvasItemMaterial
	# with additive blend for glow effect
	var canvas_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gpu.material = canvas_mat

	add_child(gpu)
	_systems.append(gpu)

func _process(delta: float) -> void:
	_time += delta

	if not _player:
		_find_player()
		return

	# Keep particle systems centered on player for infinite effect
	global_position = _player.global_position

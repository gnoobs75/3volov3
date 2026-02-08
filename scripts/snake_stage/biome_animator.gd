extends Node3D
## Animates biome-specific effects on cave hub decorations and lights.
## Added as child of cave hub; automatically pauses when hub is deactivated.

var _biome: int = 0
var _colors: Dictionary = {}
var _time: float = 0.0
var _lights: Array = []  # OmniLight3D references from BiolumLights
var _pulse_timer: float = 0.0

func setup(biome: int, colors: Dictionary) -> void:
	_biome = biome
	_colors = colors

func _ready() -> void:
	# Collect light references from sibling BiolumLights container
	var lights_node: Node = get_parent().get_node_or_null("BiolumLights")
	if lights_node:
		for child in lights_node.get_children():
			if child is OmniLight3D:
				_lights.append(child)

func _process(delta: float) -> void:
	_time += delta
	match _biome:
		1: _heartbeat(delta)
		3: _breathing(delta)
		6: _brain_sparks(delta)
		0: _acid_glow(delta)
		_: _generic_pulse(delta)

# --- Heart Chamber: double-pulse heartbeat ---
func _heartbeat(_delta: float) -> void:
	# Realistic double-beat pattern (lub-dub) at ~72 BPM
	var cycle: float = fmod(_time * 1.2, 1.0)
	var pulse: float = 0.0
	if cycle < 0.1:
		pulse = sin(cycle / 0.1 * PI)
	elif cycle > 0.15 and cycle < 0.25:
		pulse = sin((cycle - 0.15) / 0.1 * PI) * 0.6

	for light in _lights:
		if is_instance_valid(light):
			light.light_energy = 0.15 + pulse * 0.6

	# Pulse the decoration container scale for a subtle throb
	var deco: Node3D = get_parent().get_node_or_null("Decorations")
	if deco:
		var throb: float = 1.0 + pulse * 0.02
		deco.scale = Vector3(throb, throb, throb)

# --- Lung Tissue: slow breathing cycle ---
func _breathing(_delta: float) -> void:
	var breath: float = sin(_time * 0.8) * 0.5 + 0.5  # 0-1 smooth
	for light in _lights:
		if is_instance_valid(light):
			light.light_energy = 0.1 + breath * 0.25

	# Subtle vertical scale on decorations (expanding/contracting)
	var deco: Node3D = get_parent().get_node_or_null("Decorations")
	if deco:
		var expand: float = 1.0 + sin(_time * 0.8) * 0.015
		deco.scale = Vector3(expand, 1.0 + sin(_time * 0.8) * 0.025, expand)

# --- Brain: random synaptic flashes ---
func _brain_sparks(_delta: float) -> void:
	for light in _lights:
		if not is_instance_valid(light):
			continue
		if randf() < 0.02:  # 2% chance per frame per light = random sparks
			light.light_energy = randf_range(0.8, 1.5)
			light.light_color = Color(
				_colors.emission.r + randf_range(-0.1, 0.2),
				_colors.emission.g + randf_range(-0.1, 0.1),
				_colors.emission.b + randf_range(0.0, 0.3)
			)
		else:
			light.light_energy = lerpf(light.light_energy, 0.15, _delta * 3.0)

# --- Stomach: acid glow cycle ---
func _acid_glow(_delta: float) -> void:
	var glow: float = sin(_time * 2.0) * 0.3 + 0.7  # Subtle pulsing
	for light in _lights:
		if is_instance_valid(light):
			light.light_energy = 0.15 * glow + 0.1

# --- Generic: gentle ambient pulse ---
func _generic_pulse(_delta: float) -> void:
	var pulse: float = sin(_time * 1.5) * 0.5 + 0.5
	for light in _lights:
		if is_instance_valid(light):
			light.light_energy = 0.12 + pulse * 0.18

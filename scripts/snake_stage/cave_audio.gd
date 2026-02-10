class_name CaveAudio
extends RefCounted
## Procedural audio/soundscape system for the cave stage.
## Creates ambient heartbeat, drips, rumbles, and biome-specific sounds
## using AudioStreamPlayer3D and procedural AudioStreamGenerator.

const STOMACH = 0
const HEART_CHAMBER = 1
const INTESTINAL_TRACT = 2
const LUNG_TISSUE = 3
const BONE_MARROW = 4
const LIVER = 5
const BRAIN = 6

# --- Heartbeat generator ---
static func add_heartbeat(parent: Node3D, biome: int) -> void:
	## Adds an ambient heartbeat that's louder in the Heart Chamber biome.
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "Heartbeat"

	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	player.stream = gen

	# Volume based on biome proximity to heart
	match biome:
		HEART_CHAMBER:
			player.volume_db = -6.0
		STOMACH:
			player.volume_db = -18.0
		_:
			player.volume_db = -22.0

	player.max_distance = 200.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	player.position = Vector3(0, 5.0, 0)
	parent.add_child(player)

	# Attach script to generate heartbeat audio
	var script = load("res://scripts/snake_stage/heartbeat_generator.gd")
	if script:
		var gen_node: Node = Node.new()
		gen_node.name = "HeartbeatDriver"
		gen_node.set_script(script)
		gen_node.set("audio_player", player)
		gen_node.set("biome", biome)
		parent.add_child(gen_node)

# --- Ambient drip sounds ---
static func add_drips(parent: Node3D, hub_data, biome_colors: Dictionary) -> void:
	## Places 2-4 drip sound emitters on the ceiling.
	var drip_count: int = randi_range(2, 4)
	var r: float = hub_data.radius
	var h: float = hub_data.height

	for i in range(drip_count):
		var angle: float = randf() * TAU
		var dist: float = r * sqrt(randf()) * 0.6
		var pos: Vector3 = Vector3(cos(angle) * dist, h * 0.9, sin(angle) * dist)

		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.name = "Drip_%d" % i
		player.position = pos
		player.volume_db = -14.0
		player.max_distance = 40.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC

		var gen: AudioStreamGenerator = AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.25
		player.stream = gen
		parent.add_child(player)

		# Drip driver node
		var script = load("res://scripts/snake_stage/drip_generator.gd")
		if script:
			var drip_node: Node = Node.new()
			drip_node.name = "DripDriver_%d" % i
			drip_node.set_script(script)
			drip_node.set("audio_player", player)
			drip_node.set("drip_interval", randf_range(3.0, 8.0))
			parent.add_child(drip_node)

# --- Biome ambient drone ---
static func add_ambient_drone(parent: Node3D, hub_data, biome_colors: Dictionary) -> void:
	## Low continuous drone specific to each biome.
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "AmbientDrone"

	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.0
	player.stream = gen
	player.volume_db = -20.0
	player.max_distance = 250.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	player.position = Vector3(0, hub_data.height * 0.5, 0)
	parent.add_child(player)

	var script = load("res://scripts/snake_stage/drone_generator.gd")
	if script:
		var drone_node: Node = Node.new()
		drone_node.name = "DroneDriver"
		drone_node.set_script(script)
		drone_node.set("audio_player", player)
		drone_node.set("biome", hub_data.biome)
		parent.add_child(drone_node)

# --- Convenience: add all audio to a hub ---
static func add_audio(parent: Node3D, hub_data, biome_colors: Dictionary) -> void:
	add_heartbeat(parent, hub_data.biome)
	add_drips(parent, hub_data, biome_colors)
	add_ambient_drone(parent, hub_data, biome_colors)

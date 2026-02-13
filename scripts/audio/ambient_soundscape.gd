class_name AmbientSoundscape
## Static factory for cell stage underwater ambient soundscape.
## Creates AudioStreamPlayer with procedural generator (mirrors CaveAudio pattern).

static func create_cell_ambient(parent: Node) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "CellAmbient"
	player.bus = "Master"
	player.volume_db = -16.0

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.0
	player.stream = gen
	parent.add_child(player)

	# Attach driver script
	var script = load("res://scripts/audio/cell_ambient_generator.gd")
	if script:
		var driver := Node.new()
		driver.name = "CellAmbientDriver"
		driver.set_script(script)
		driver.set("audio_player", player)
		parent.add_child(driver)

	return player

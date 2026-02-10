extends Node
## Generates a continuous low ambient drone specific to each biome.
## Uses layered sine waves with slow modulation for organic feel.

var audio_player: AudioStreamPlayer3D = null
var biome: int = 0
var _playback: AudioStreamGeneratorPlayback = null
var _time: float = 0.0
var _started: bool = false
var _mix_rate: float = 22050.0

# Per-biome drone parameters
var _base_freq: float = 40.0
var _mod_freq: float = 0.3
var _mod_depth: float = 0.3
var _harmonics: Array[float] = [1.0, 2.0, 3.0]
var _harmonic_weights: Array[float] = [1.0, 0.3, 0.1]

func _ready() -> void:
	_configure_biome()
	call_deferred("_start_audio")

func _configure_biome() -> void:
	match biome:
		0:  # STOMACH - acid gurgle
			_base_freq = 35.0
			_mod_freq = 0.5
			_mod_depth = 0.5
			_harmonics = [1.0, 1.5, 2.0, 3.0]
			_harmonic_weights = [1.0, 0.4, 0.2, 0.08]
		1:  # HEART - steady throb
			_base_freq = 30.0
			_mod_freq = 1.2
			_mod_depth = 0.4
			_harmonics = [1.0, 2.0]
			_harmonic_weights = [1.0, 0.3]
		2:  # INTESTINE - slow squelch
			_base_freq = 45.0
			_mod_freq = 0.2
			_mod_depth = 0.6
			_harmonics = [1.0, 1.3, 2.5]
			_harmonic_weights = [1.0, 0.5, 0.15]
		3:  # LUNG - breathy whoosh
			_base_freq = 55.0
			_mod_freq = 0.8
			_mod_depth = 0.7
			_harmonics = [1.0, 2.0, 4.0, 6.0]
			_harmonic_weights = [0.5, 0.3, 0.15, 0.05]
		4:  # BONE MARROW - hollow resonance
			_base_freq = 50.0
			_mod_freq = 0.15
			_mod_depth = 0.2
			_harmonics = [1.0, 3.0, 5.0]
			_harmonic_weights = [1.0, 0.2, 0.05]
		5:  # LIVER - thick wet
			_base_freq = 38.0
			_mod_freq = 0.35
			_mod_depth = 0.45
			_harmonics = [1.0, 1.5, 2.0]
			_harmonic_weights = [1.0, 0.35, 0.15]
		6:  # BRAIN - eerie electrical
			_base_freq = 60.0
			_mod_freq = 2.5
			_mod_depth = 0.3
			_harmonics = [1.0, 1.618, 2.618, 4.236]  # Golden ratio harmonics
			_harmonic_weights = [0.6, 0.4, 0.2, 0.1]

func _start_audio() -> void:
	if audio_player and audio_player.stream is AudioStreamGenerator:
		_mix_rate = audio_player.stream.mix_rate
		audio_player.play()
		_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
		_started = true

func _process(delta: float) -> void:
	if not _started or not _playback:
		return

	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var frames_to_fill: int = mini(frames_available, 512)

	for i in range(frames_to_fill):
		var t: float = _time + float(i) / _mix_rate
		var sample: float = 0.0

		# Frequency modulation for organic movement
		var mod: float = sin(t * TAU * _mod_freq) * _mod_depth
		var freq: float = _base_freq * (1.0 + mod * 0.1)

		# Layer harmonics
		for h_idx in range(_harmonics.size()):
			var h: float = _harmonics[h_idx]
			var w: float = _harmonic_weights[h_idx]
			sample += sin(t * TAU * freq * h) * w

		# Slow amplitude envelope for breathing feel
		var env: float = 0.08 + sin(t * _mod_freq * TAU) * 0.03
		sample *= env

		# Soft clip
		sample = clampf(sample, -0.5, 0.5)
		_playback.push_frame(Vector2(sample, sample))

	_time += float(frames_to_fill) / _mix_rate

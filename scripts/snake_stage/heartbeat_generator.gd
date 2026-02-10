extends Node
## Generates a procedural heartbeat sound using AudioStreamGenerator.
## Produces a realistic lub-dub pattern at ~72 BPM.

var audio_player: AudioStreamPlayer3D = null
var biome: int = 0
var _playback: AudioStreamGeneratorPlayback = null
var _time: float = 0.0
var _started: bool = false
var _mix_rate: float = 22050.0

func _ready() -> void:
	# Start audio after a short delay to ensure stream is ready
	call_deferred("_start_audio")

func _start_audio() -> void:
	if audio_player and audio_player.stream is AudioStreamGenerator:
		_mix_rate = audio_player.stream.mix_rate
		audio_player.play()
		_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
		_started = true

func _process(delta: float) -> void:
	if not _started or not _playback:
		return

	_time += delta

	# Fill audio buffer
	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var bpm: float = 72.0
	if biome == 1:  # Heart chamber: faster, louder
		bpm = 80.0

	var beat_period: float = 60.0 / bpm
	var frames_to_fill: int = mini(frames_available, 512)

	for i in range(frames_to_fill):
		var t: float = _time + float(i) / _mix_rate
		var cycle: float = fmod(t / beat_period, 1.0)

		var sample: float = 0.0

		# Lub (first beat) - deeper, stronger
		if cycle < 0.08:
			var env: float = sin(cycle / 0.08 * PI)
			sample += sin(cycle * TAU * 45.0) * env * 0.6  # ~45 Hz thump
			sample += sin(cycle * TAU * 90.0) * env * 0.2   # Harmonic

		# Dub (second beat) - slightly higher, softer
		elif cycle > 0.18 and cycle < 0.26:
			var phase: float = (cycle - 0.18) / 0.08
			var env: float = sin(phase * PI) * 0.5
			sample += sin(phase * TAU * 55.0) * env * 0.4
			sample += sin(phase * TAU * 110.0) * env * 0.15

		# Very subtle rumble between beats
		sample += sin(t * TAU * 25.0) * 0.02

		# Soft clip
		sample = clampf(sample, -0.8, 0.8)
		_playback.push_frame(Vector2(sample, sample))

	_time += float(frames_to_fill) / _mix_rate

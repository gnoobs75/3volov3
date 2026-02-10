extends Node
## Generates procedural water drip sounds at random intervals.
## Creates a short sine-decay "plink" when triggered.

var audio_player: AudioStreamPlayer3D = null
var drip_interval: float = 5.0
var _playback: AudioStreamGeneratorPlayback = null
var _timer: float = 0.0
var _drip_time: float = -1.0  # <0 means no active drip
var _started: bool = false
var _mix_rate: float = 22050.0

func _ready() -> void:
	_timer = randf_range(0.5, drip_interval)  # Random initial delay
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

	_timer -= delta
	if _timer <= 0.0:
		_drip_time = 0.0
		_timer = drip_interval + randf_range(-1.5, 2.0)

	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var frames_to_fill: int = mini(frames_available, 256)

	for i in range(frames_to_fill):
		var sample: float = 0.0

		if _drip_time >= 0.0:
			var t: float = _drip_time
			_drip_time += 1.0 / _mix_rate

			if t < 0.15:
				# Primary drip: high frequency sine with fast decay
				var env: float = exp(-t * 30.0)
				var freq: float = 800.0 + randf_range(-100.0, 200.0) * (1.0 - t * 5.0)
				sample += sin(t * TAU * freq) * env * 0.5

				# Lower resonance (water body)
				sample += sin(t * TAU * 200.0) * env * 0.15

				# Tiny splash noise
				if t < 0.01:
					sample += (randf() - 0.5) * 0.3 * (1.0 - t * 100.0)
			else:
				# Drip finished
				_drip_time = -1.0

		_playback.push_frame(Vector2(sample, sample))

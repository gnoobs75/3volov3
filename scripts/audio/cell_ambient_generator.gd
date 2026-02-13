extends Node
## Continuous underwater ambient soundscape for the cell stage.
## Synthesizes 5 mixed layers: deep drone, water flow, distant bio, bubbles, biome tone.

var audio_player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _time: float = 0.0
var _started: bool = false
var _mix_rate: float = 22050.0

# Layer state
var _drone_phase: float = 0.0
var _drone_phase2: float = 0.0
var _flow_prev: float = 0.0
var _flow_burst_timer: float = 0.0
var _flow_burst_active: bool = false
var _flow_burst_dur: float = 0.0
var _bio_timer: float = 0.0
var _bio_freq: float = 0.0
var _bio_phase: float = 0.0
var _bio_env: float = 0.0
var _bubble_timer: float = 0.0
var _bubble_phase: float = 0.0
var _bubble_env: float = 0.0
var _bubble_freq: float = 800.0

func _ready() -> void:
	call_deferred("_start_audio")

func _start_audio() -> void:
	if audio_player and audio_player.stream is AudioStreamGenerator:
		_mix_rate = audio_player.stream.mix_rate
		audio_player.play()
		_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
		_started = true
		_bio_timer = randf_range(2.0, 5.0)
		_bubble_timer = randf_range(1.0, 3.0)
		_flow_burst_timer = randf_range(3.0, 7.0)

func _process(_delta: float) -> void:
	if not _started or not _playback:
		return

	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var frames_to_fill: int = mini(frames_available, 512)

	for i in range(frames_to_fill):
		var t: float = _time + float(i) / _mix_rate
		var sample: float = 0.0

		# === Layer 1: Deep Drone (30-50 Hz, slow LFO) ===
		var drone_freq: float = 38.0 + sin(t * 0.15 * TAU) * 8.0
		_drone_phase += drone_freq / _mix_rate
		_drone_phase2 += (drone_freq * 1.498) / _mix_rate  # Detuned fifth
		var drone: float = sin(_drone_phase * TAU) * 0.35 + sin(_drone_phase2 * TAU) * 0.2
		# Slow breathing envelope
		drone *= 0.06 + sin(t * 0.1 * TAU) * 0.02
		sample += drone

		# === Layer 2: Water Flow (filtered noise bursts) ===
		var flow: float = 0.0
		_flow_burst_timer -= 1.0 / _mix_rate
		if _flow_burst_timer <= 0.0:
			if not _flow_burst_active:
				_flow_burst_active = true
				_flow_burst_dur = randf_range(0.5, 1.5)
				_flow_burst_timer = _flow_burst_dur
			else:
				_flow_burst_active = false
				_flow_burst_timer = randf_range(3.0, 7.0)

		if _flow_burst_active:
			var burst_t: float = 1.0 - _flow_burst_timer / _flow_burst_dur
			var burst_env: float = sin(burst_t * PI) * 0.04  # Swell in and out
			var raw: float = (randf() - 0.5)
			# Simple lowpass: blend with previous sample
			flow = raw * 0.3 + _flow_prev * 0.7
			_flow_prev = flow
			flow *= burst_env
		else:
			# Very quiet background trickle
			var raw: float = (randf() - 0.5)
			flow = raw * 0.2 + _flow_prev * 0.8
			_flow_prev = flow
			flow *= 0.008
		sample += flow

		# === Layer 3: Distant Biology (sparse chirps) ===
		_bio_timer -= 1.0 / _mix_rate
		if _bio_timer <= 0.0 and _bio_env <= 0.0:
			# Start a new chirp
			_bio_freq = randf_range(1800.0, 4000.0)
			_bio_env = 1.0
			_bio_phase = 0.0
			_bio_timer = randf_range(3.0, 8.0)

		if _bio_env > 0.0:
			_bio_phase += _bio_freq / _mix_rate
			# AM modulation for chirp texture
			var am: float = 0.5 + 0.5 * sin(_bio_phase * 30.0)
			var bio: float = sin(_bio_phase * TAU) * _bio_env * am * 0.015
			sample += bio
			_bio_env -= 8.0 / _mix_rate  # ~0.12 sec decay
			if _bio_env < 0.0:
				_bio_env = 0.0

		# === Layer 4: Bubble Clusters (random pops) ===
		_bubble_timer -= 1.0 / _mix_rate
		if _bubble_timer <= 0.0 and _bubble_env <= 0.0:
			_bubble_freq = randf_range(600.0, 1200.0)
			_bubble_env = 1.0
			_bubble_phase = 0.0
			_bubble_timer = randf_range(0.8, 3.0)

		if _bubble_env > 0.0:
			_bubble_phase += _bubble_freq / _mix_rate
			var bub: float = sin(_bubble_phase * TAU) * _bubble_env * 0.02
			sample += bub
			_bubble_env *= 0.992  # Exponential decay
			if _bubble_env < 0.005:
				_bubble_env = 0.0

		# === Layer 5: Biome Signature (tonal color) ===
		# Eerie mid-frequency hum with slow wobble
		var sig_freq: float = 120.0 + sin(t * 0.08 * TAU) * 15.0
		var sig: float = sin(t * sig_freq * TAU) * 0.02
		sig += sin(t * sig_freq * 1.618 * TAU) * 0.008  # Golden ratio harmonic
		sig *= 0.5 + 0.5 * sin(t * 0.05 * TAU)  # Very slow swell
		sample += sig

		# Soft clip
		sample = clampf(sample, -0.5, 0.5)
		_playback.push_frame(Vector2(sample, sample))

	_time += float(frames_to_fill) / _mix_rate

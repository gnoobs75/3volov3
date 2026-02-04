extends Node
## Autoload: Procedural audio manager for all game sounds.
## Generates sounds from waveforms — no external audio files needed.

const SAMPLE_RATE: int = 22050
const BGM_SAMPLE_RATE: int = 22050

# SFX players pool
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

# BGM
var _bgm_player: AudioStreamPlayer
var _bgm_generator: AudioStreamGenerator
var _bgm_playback: AudioStreamGeneratorPlayback
var _bgm_time: float = 0.0

# Pre-generated sound buffers
var _buf_collect: PackedFloat32Array
var _buf_collect_rare: PackedFloat32Array
var _buf_eat: PackedFloat32Array
var _buf_hurt: PackedFloat32Array
var _buf_toxin: PackedFloat32Array
var _buf_death: PackedFloat32Array
var _buf_confused: PackedFloat32Array
var _buf_beam: PackedFloat32Array
var _buf_jet: PackedFloat32Array
var _buf_bubble: PackedFloat32Array
var _buf_sprint: PackedFloat32Array

# Beam looping state
var _beam_playing: bool = false
var _beam_player: AudioStreamPlayer

# BGM chord progression
var _bgm_chord_index: int = 0
var _bgm_chord_timer: float = 0.0
const BGM_CHORDS: Array = [
	[130.81, 164.81, 196.0],     # C major
	[146.83, 174.61, 220.0],     # D minor-ish
	[164.81, 196.0, 246.94],     # E minor
	[174.61, 220.0, 261.63],     # F major
]

func _ready() -> void:
	# Create SFX player pool
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

	# Create beam looping player
	_beam_player = AudioStreamPlayer.new()
	_beam_player.bus = "Master"
	add_child(_beam_player)

	# Pre-generate all sound buffers
	_buf_collect = SynthSounds.gen_collect(1.0)
	_buf_collect_rare = SynthSounds.gen_collect(1.4)
	_buf_eat = SynthSounds.gen_eat()
	_buf_hurt = SynthSounds.gen_hurt()
	_buf_toxin = SynthSounds.gen_toxin()
	_buf_death = SynthSounds.gen_death()
	_buf_confused = SynthSounds.gen_confused()
	_buf_beam = SynthSounds.gen_beam_hum()
	_buf_jet = SynthSounds.gen_jet()
	_buf_bubble = SynthSounds.gen_bubble()
	_buf_sprint = SynthSounds.gen_sprint()

	# Setup BGM
	_setup_bgm()

func _setup_bgm() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -12.0
	add_child(_bgm_player)

	_bgm_generator = AudioStreamGenerator.new()
	_bgm_generator.mix_rate = BGM_SAMPLE_RATE
	_bgm_generator.buffer_length = 0.5
	_bgm_player.stream = _bgm_generator
	_bgm_player.play()
	_bgm_playback = _bgm_player.get_stream_playback()

func _process(delta: float) -> void:
	_fill_bgm_buffer(delta)
	# Random ambient bubbles
	if randf() < delta * 0.3:  # ~0.3 bubbles per second
		play_bubble()

func _fill_bgm_buffer(_delta: float) -> void:
	if not _bgm_playback:
		return
	var frames_available: int = _bgm_playback.get_frames_available()
	if frames_available <= 0:
		return

	# Chord timing
	_bgm_chord_timer += float(frames_available) / BGM_SAMPLE_RATE
	if _bgm_chord_timer > 4.0:
		_bgm_chord_timer = 0.0
		_bgm_chord_index = (_bgm_chord_index + 1) % BGM_CHORDS.size()

	var chord: Array = BGM_CHORDS[_bgm_chord_index]
	var next_chord: Array = BGM_CHORDS[(_bgm_chord_index + 1) % BGM_CHORDS.size()]
	var blend: float = smoothstep(3.5, 4.0, _bgm_chord_timer)

	for i in range(frames_available):
		_bgm_time += 1.0 / BGM_SAMPLE_RATE
		var sample: float = 0.0

		# Pad: 3 sine tones per chord, crossfading
		for n in range(3):
			var freq_a: float = chord[n] * 0.5  # One octave lower for warmth
			var freq_b: float = next_chord[n] * 0.5
			var freq: float = lerpf(freq_a, freq_b, blend)
			sample += sin(_bgm_time * freq * TAU) * 0.06

		# Sub bass drone
		sample += sin(_bgm_time * 65.0 * TAU) * 0.04
		# Gentle high shimmer
		var shimmer_freq: float = 2200.0 + sin(_bgm_time * 0.3) * 400.0
		sample += sin(_bgm_time * shimmer_freq * TAU) * 0.008 * (0.5 + 0.5 * sin(_bgm_time * 0.7))

		# Slow LFO volume swell
		var lfo: float = 0.7 + 0.3 * sin(_bgm_time * 0.15 * TAU)
		sample *= lfo

		_bgm_playback.push_frame(Vector2(sample, sample))

## --- SFX play functions ---

func _play_buffer(buf: PackedFloat32Array, volume_db: float = 0.0) -> void:
	# Find free player
	for p in _sfx_players:
		if not p.playing:
			var stream := _buffer_to_stream(buf)
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return
	# All busy - steal oldest
	var p: AudioStreamPlayer = _sfx_players[0]
	p.stream = _buffer_to_stream(buf)
	p.volume_db = volume_db
	p.play()

func _buffer_to_stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SynthSounds.SAMPLE_RATE)
	stream.stereo = false
	# Convert float32 to 16-bit PCM bytes
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in range(buf.size()):
		var s: int = clampi(int(buf[i] * 32767.0), -32768, 32767)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	stream.data = data
	return stream

func play_collect(is_rare: bool = false) -> void:
	_play_buffer(_buf_collect_rare if is_rare else _buf_collect, -3.0)

func play_eat() -> void:
	_play_buffer(_buf_eat, -2.0)

func play_hurt() -> void:
	_play_buffer(_buf_hurt, -1.0)

func play_toxin() -> void:
	_play_buffer(_buf_toxin, -2.0)

func play_death() -> void:
	_play_buffer(_buf_death, 0.0)

func play_confused() -> void:
	_play_buffer(_buf_confused, -4.0)

func play_jet() -> void:
	_play_buffer(_buf_jet, -3.0)

func play_bubble() -> void:
	# Regenerate each time for variety
	var buf := SynthSounds.gen_bubble()
	_play_buffer(buf, -10.0)

func play_sprint() -> void:
	_play_buffer(_buf_sprint, -6.0)

## Beam sound (looping while active)
func start_beam() -> void:
	if _beam_playing:
		return
	_beam_playing = true
	var stream := _buffer_to_stream(_buf_beam)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2  # 16-bit mono
	_beam_player.stream = stream
	_beam_player.volume_db = -6.0
	_beam_player.play()

func stop_beam() -> void:
	if not _beam_playing:
		return
	_beam_playing = false
	_beam_player.stop()

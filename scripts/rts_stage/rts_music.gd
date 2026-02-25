extends Node
## Procedural dynamic music engine for the RTS colony stage.
## Uses AudioStreamGenerator with three layered states: CALM, TENSION, COMBAT.
## State transitions crossfade over 3 seconds. Overall volume is kept low (~0.15).

enum MusicState { CALM, TENSION, COMBAT }

var _stage_ref: Node2D = null
var _map_flavor: String = "petri_dish"

# Audio
var _audio_player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _mix_rate: float = 22050.0
var _time: float = 0.0
var _started: bool = false

# State machine
var _music_state: int = MusicState.CALM
var _target_state: int = MusicState.CALM
var _crossfade: float = 0.0  # 0.0 = fully in current, 1.0 = fully in target
var _state_check_timer: float = 0.0
const STATE_CHECK_INTERVAL: float = 1.0
const CROSSFADE_DURATION: float = 3.0

# Combat tracking (updated externally)
var _units_in_combat: int = 0
var _threat_active: bool = false
var _enemy_visible: bool = false
var _no_combat_timer: float = 0.0

# Layer state: CALM
var _drone_phase: float = 0.0
var _drone_lfo_phase: float = 0.0
var _bubble_timer: float = 0.0
var _bubble_freq: float = 600.0
var _bubble_phase: float = 0.0
var _bubble_env: float = 0.0
var _bubble_dur: float = 0.08
var _pad_phase: float = 0.0
var _pad_filter: float = 0.0

# Layer state: TENSION
var _kick_timer: float = 0.0
var _kick_phase: float = 0.0
var _kick_env: float = 0.0
var _sweep_time: float = 0.0
var _sweep_phase: float = 0.0
var _staccato_timer: float = 0.0
var _staccato_phase: float = 0.0
var _staccato_env: float = 0.0

# Layer state: COMBAT
var _beat_timer: float = 0.0
var _beat_phase: float = 0.0
var _beat_kick_env: float = 0.0
var _beat_snare_env: float = 0.0
var _beat_count: int = 0
var _bass_phase: float = 0.0
var _lead_phase: float = 0.0
var _lead_note_idx: int = 0
var _lead_timer: float = 0.0

# Map flavor multipliers
var _freq_mult: float = 1.0
var _vibrato_width: float = 1.0
var _detune: float = 0.0

# Master volume
const MASTER_AMP: float = 0.15

func setup(stage_ref: Node2D, map_id: String) -> void:
	_stage_ref = stage_ref
	_map_flavor = map_id
	_apply_map_flavor()

func _apply_map_flavor() -> void:
	match _map_flavor:
		"petri_dish":
			_freq_mult = 1.0
			_vibrato_width = 1.0
			_detune = 0.0
		"blood_vessel":
			_freq_mult = 1.1  # 10% up
			_vibrato_width = 0.8
			_detune = 0.0
		"brain_cortex":
			_freq_mult = 0.95  # 5% down
			_vibrato_width = 1.8  # Wider vibrato
			_detune = 0.03  # Eerie detuning
		_:
			_freq_mult = 1.0
			_vibrato_width = 1.0
			_detune = 0.0

func _ready() -> void:
	# Create AudioStreamPlayer with generator
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	_audio_player.volume_db = -6.0
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	_audio_player.stream = gen
	add_child(_audio_player)

	# Initialize random timers
	_bubble_timer = randf_range(0.5, 2.0)
	_kick_timer = 0.8
	_staccato_timer = 0.4

	call_deferred("_start_audio")

func _start_audio() -> void:
	if _audio_player and _audio_player.stream is AudioStreamGenerator:
		_mix_rate = _audio_player.stream.mix_rate
		_audio_player.play()
		_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
		_started = true

func update_combat_state(units_in_combat: int, threat_active: bool, enemy_visible: bool) -> void:
	_units_in_combat = units_in_combat
	_threat_active = threat_active
	_enemy_visible = enemy_visible

func _process(delta: float) -> void:
	if not _started or not _playback:
		return

	# State check timer
	_state_check_timer -= delta
	if _state_check_timer <= 0.0:
		_state_check_timer = STATE_CHECK_INTERVAL
		_evaluate_state(delta)

	# Track no-combat time
	if _units_in_combat > 0:
		_no_combat_timer = 0.0
	else:
		_no_combat_timer += delta

	# Crossfade progression
	if _music_state != _target_state:
		_crossfade += delta / CROSSFADE_DURATION
		if _crossfade >= 1.0:
			_crossfade = 0.0
			_music_state = _target_state

	# Fill audio buffer
	_fill_buffer()

func _evaluate_state(_delta: float) -> void:
	var new_state: int = _music_state

	if _units_in_combat >= 3:
		new_state = MusicState.COMBAT
	elif _enemy_visible or _threat_active:
		new_state = MusicState.TENSION
	elif _no_combat_timer >= 30.0 and not _threat_active:
		new_state = MusicState.CALM

	if new_state != _target_state:
		_target_state = new_state
		_crossfade = 0.0

func _fill_buffer() -> void:
	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var frames_to_fill: int = mini(frames_available, 512)
	var dt: float = 1.0 / _mix_rate

	for i in range(frames_to_fill):
		var t: float = _time + float(i) * dt
		var sample: float = 0.0

		# Calculate blend weights for current and target states
		var weights: Array = [0.0, 0.0, 0.0]  # CALM, TENSION, COMBAT
		if _music_state == _target_state:
			weights[_music_state] = 1.0
		else:
			weights[_music_state] = 1.0 - _crossfade
			weights[_target_state] = _crossfade

		# Generate each layer with its weight
		if weights[MusicState.CALM] > 0.01:
			sample += _gen_calm_sample(t, dt) * weights[MusicState.CALM]
		if weights[MusicState.TENSION] > 0.01:
			sample += _gen_tension_sample(t, dt) * weights[MusicState.TENSION]
		if weights[MusicState.COMBAT] > 0.01:
			sample += _gen_combat_sample(t, dt) * weights[MusicState.COMBAT]

		# Master amplitude and soft clip
		sample *= MASTER_AMP
		sample = clampf(sample, -0.5, 0.5)
		_playback.push_frame(Vector2(sample, sample))

	_time += float(frames_to_fill) * dt

# === CALM LAYER ===
func _gen_calm_sample(t: float, dt: float) -> float:
	var sample: float = 0.0

	# Deep drone: sine at 45Hz with slow LFO (0.1Hz) on amplitude
	var drone_freq: float = 45.0 * _freq_mult
	_drone_phase += drone_freq * dt
	var drone_lfo: float = 0.6 + 0.4 * sin(t * 0.1 * TAU)
	var drone: float = sin(_drone_phase * TAU) * 0.5 * drone_lfo
	# Add detuned layer for brain_cortex flavor
	if _detune > 0.0:
		drone += sin(_drone_phase * (1.0 + _detune) * TAU) * 0.15
	sample += drone

	# Ambient bubble pings: random sine at 400-800Hz, short duration
	_bubble_timer -= dt
	if _bubble_timer <= 0.0 and _bubble_env <= 0.0:
		_bubble_freq = randf_range(400.0, 800.0) * _freq_mult
		_bubble_env = 1.0
		_bubble_phase = 0.0
		_bubble_dur = randf_range(0.05, 0.1)
		_bubble_timer = randf_range(0.5, 2.0)

	if _bubble_env > 0.0:
		_bubble_phase += _bubble_freq * dt
		var bub: float = sin(_bubble_phase * TAU) * _bubble_env * 0.2
		sample += bub
		_bubble_env -= dt / _bubble_dur
		if _bubble_env < 0.0:
			_bubble_env = 0.0

	# Pad: filtered sawtooth at 90Hz, very low amplitude, slow filter sweep
	var pad_freq: float = 90.0 * _freq_mult
	_pad_phase += pad_freq * dt
	var raw_saw: float = 2.0 * fmod(_pad_phase, 1.0) - 1.0
	# Simple lowpass via lerp with previous value
	_pad_filter = _pad_filter * 0.95 + raw_saw * 0.05
	var pad_amp: float = 0.08 + 0.04 * sin(t * 0.07 * TAU)
	sample += _pad_filter * pad_amp

	return sample

# === TENSION LAYER ===
func _gen_tension_sample(t: float, dt: float) -> float:
	var sample: float = 0.0

	# Pulsing kick: sine at 60Hz, 0.1s duration, every 0.8s
	_kick_timer -= dt
	if _kick_timer <= 0.0:
		_kick_env = 1.0
		_kick_phase = 0.0
		_kick_timer = 0.8

	if _kick_env > 0.0:
		var kick_freq: float = 60.0 * _freq_mult
		_kick_phase += kick_freq * dt
		var kick: float = sin(_kick_phase * TAU) * _kick_env * 0.6
		sample += kick
		_kick_env -= dt / 0.1  # 0.1s decay
		if _kick_env < 0.0:
			_kick_env = 0.0

	# Rising harmonics: sawtooth sweep 200->800Hz over 4s, repeating
	_sweep_time = fmod(t, 4.0)
	var sweep_freq: float = lerpf(200.0, 800.0, _sweep_time / 4.0) * _freq_mult
	_sweep_phase += sweep_freq * dt
	var sweep_saw: float = 2.0 * fmod(_sweep_phase, 1.0) - 1.0
	# Vibrato
	var vib: float = sin(t * 5.0 * TAU) * 0.02 * _vibrato_width
	sweep_saw *= 0.25 * (1.0 + vib)
	# Envelope: fade in and out within 4s cycle
	var sweep_env: float = sin(_sweep_time / 4.0 * PI) * 0.8
	sample += sweep_saw * sweep_env

	# Staccato notes: short triangle pings on beat subdivisions
	_staccato_timer -= dt
	if _staccato_timer <= 0.0:
		_staccato_env = 1.0
		_staccato_phase = 0.0
		_staccato_timer = 0.2  # eighth-note subdivision of 0.8s beat
		# Vary staccato note (different notes in sequence)
		# No need for random: the sweep already provides pitch variation

	if _staccato_env > 0.0:
		var stacc_freq: float = 330.0 * _freq_mult
		_staccato_phase += stacc_freq * dt
		# Triangle wave
		var p: float = fmod(_staccato_phase, 1.0)
		var tri: float = 4.0 * absf(p - 0.5) - 1.0
		sample += tri * _staccato_env * 0.15
		_staccato_env -= dt / 0.05  # Very short, 50ms
		if _staccato_env < 0.0:
			_staccato_env = 0.0

	return sample

# === COMBAT LAYER ===
func _gen_combat_sample(t: float, dt: float) -> float:
	var sample: float = 0.0

	# 140 BPM = beat every 60/140 = ~0.4286s
	var beat_interval: float = 60.0 / 140.0

	_beat_timer -= dt
	if _beat_timer <= 0.0:
		_beat_count += 1
		_beat_timer = beat_interval
		_beat_phase = 0.0

		# Alternate kick and snare
		if _beat_count % 2 == 0:
			_beat_kick_env = 1.0
		else:
			_beat_snare_env = 1.0

	# Kick: 60Hz sine, 0.05s
	if _beat_kick_env > 0.0:
		var kick_freq: float = 60.0 * _freq_mult
		_beat_phase += kick_freq * dt
		sample += sin(_beat_phase * TAU) * _beat_kick_env * 0.7
		_beat_kick_env -= dt / 0.05
		if _beat_kick_env < 0.0:
			_beat_kick_env = 0.0

	# Snare: noise burst, 0.03s
	if _beat_snare_env > 0.0:
		sample += randf_range(-1.0, 1.0) * _beat_snare_env * 0.35
		_beat_snare_env -= dt / 0.03
		if _beat_snare_env < 0.0:
			_beat_snare_env = 0.0

	# Aggressive bass: square wave at 55Hz with fast LFO on pitch
	var bass_freq: float = 55.0 * _freq_mult
	var bass_lfo: float = 1.0 + sin(t * 8.0 * TAU) * 0.05  # Fast pitch wobble
	_bass_phase += bass_freq * bass_lfo * dt
	var bass_p: float = fmod(_bass_phase, 1.0)
	var bass: float = 1.0 if bass_p < 0.5 else -1.0
	sample += bass * 0.2

	# Lead melody: saw wave, 4-note pattern cycling
	# Notes: C4(262), Eb4(311), G4(392), Bb4(466) -- minor feel
	var lead_notes: Array = [262.0, 311.0, 392.0, 466.0]
	_lead_timer -= dt
	if _lead_timer <= 0.0:
		_lead_note_idx = (_lead_note_idx + 1) % 4
		_lead_timer = beat_interval  # One note per beat

	var lead_freq: float = lead_notes[_lead_note_idx] * _freq_mult
	# Add vibrato
	lead_freq *= 1.0 + sin(t * 6.0 * TAU) * 0.01 * _vibrato_width
	_lead_phase += lead_freq * dt
	var lead_saw: float = 2.0 * fmod(_lead_phase, 1.0) - 1.0
	# Envelope per note: sharp attack, quick decay
	var lead_env: float = clampf(1.0 - (_lead_timer / beat_interval - 0.7) * 3.33, 0.0, 1.0)
	lead_env *= clampf(_lead_timer / (beat_interval * 0.1), 0.0, 1.0)
	# Alternate approach: simple sustain with slight fade
	var note_progress: float = 1.0 - _lead_timer / beat_interval
	lead_env = clampf(1.0 - note_progress * 0.3, 0.0, 1.0) * clampf(note_progress * 20.0, 0.0, 1.0)
	sample += lead_saw * lead_env * 0.15

	return sample

extends Node
## Autoload: Audio manager for all game sounds.
## Supports both procedural synthesis and music file playback.

const SAMPLE_RATE: int = 22050
const BGM_SAMPLE_RATE: int = 22050

# SFX players pool
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

# Procedural BGM
var _bgm_player: AudioStreamPlayer
var _bgm_generator: AudioStreamGenerator
var _bgm_playback: AudioStreamGeneratorPlayback
var _bgm_time: float = 0.0

# === MUSIC FILE SYSTEM ===
# Music mode: true = file-based, false = procedural
var use_music_files: bool = false

# Music players (two for crossfading)
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _crossfade_time: float = 0.0
var _crossfade_duration: float = 2.0
var _is_crossfading: bool = false

# Music tracks by category
var _music_tracks: Dictionary = {
	"menu": "res://audio/music/menu.ogg",
	"cell_stage": "res://audio/music/cell_stage.ogg",
	"evolution": "res://audio/music/evolution.ogg",
	"death": "res://audio/music/death.ogg",
	"victory": "res://audio/music/victory.ogg",
}

# Current music state
var _current_music_key: String = ""
const MUSIC_VOLUME_DB: float = -8.0

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

# Phase 1 polish sound buffers
var _buf_evolution_fanfare: PackedFloat32Array
var _buf_sensory_upgrade: PackedFloat32Array
var _buf_heartbeat: PackedFloat32Array
var _buf_ui_hover: PackedFloat32Array
var _buf_ui_select: PackedFloat32Array
var _buf_ui_open: PackedFloat32Array
var _buf_energy_warning: PackedFloat32Array

# CRISPR splice sound buffers
var _buf_splice_success: PackedFloat32Array
var _buf_splice_fail: PackedFloat32Array

# Observer vocalization buffers
var _buf_observer_gasp: PackedFloat32Array
var _buf_observer_hmm: PackedFloat32Array
var _buf_observer_laugh: PackedFloat32Array
var _buf_observer_impressed: PackedFloat32Array
var _buf_observer_distressed: PackedFloat32Array
var _buf_observer_grunt: PackedFloat32Array
var _buf_observer_chirp: PackedFloat32Array
var _buf_observer_mutter: PackedFloat32Array

# Observer sound cooldown
var _observer_cooldown: float = 0.0
const OBSERVER_COOLDOWN_TIME: float = 4.0

# Snake stage environment sound buffers
var _buf_grass_rustle: PackedFloat32Array
var _buf_bush_push: PackedFloat32Array
var _buf_insect_chirp: PackedFloat32Array
var _buf_tunnel_echo: PackedFloat32Array
var _buf_land_collect: PackedFloat32Array
var _buf_ambient_hum: PackedFloat32Array

# Parasite mode combat sound buffers
var _buf_bite_snap: PackedFloat32Array
var _buf_stun_burst: PackedFloat32Array
var _buf_wbc_alert: PackedFloat32Array

# Cave stage sound buffers
var _buf_sonar_ping: PackedFloat32Array
var _buf_sonar_return: PackedFloat32Array
var _buf_cave_drip: PackedFloat32Array
var _buf_crystal_resonance: PackedFloat32Array
var _buf_lava_bubble: PackedFloat32Array
var _buf_deep_cave_drone: PackedFloat32Array
var _buf_cave_footstep: PackedFloat32Array
var _buf_mode_switch: PackedFloat32Array
var _buf_spore_release: PackedFloat32Array
var _buf_creature_echolocation: PackedFloat32Array

# Combat audio
var _buf_victory_sting: PackedFloat32Array
var _buf_combat_percussion: PackedFloat32Array
var _buf_boss_intro_sting: PackedFloat32Array
var _combat_intensity: float = 0.0

# Snake stage combat SFX
var _buf_venom_spit: PackedFloat32Array
var _buf_tail_whip: PackedFloat32Array
var _buf_segment_grow: PackedFloat32Array

# Golden card ability SFX
var _buf_toxic_miasma: PackedFloat32Array
var _buf_chain_lightning: PackedFloat32Array
var _buf_regenerative_burst: PackedFloat32Array

# Boss trait attack SFX
var _buf_pulse_wave: PackedFloat32Array
var _buf_acid_spit_muzzle: PackedFloat32Array
var _buf_wind_gust: PackedFloat32Array
var _buf_bone_shield: PackedFloat32Array
var _buf_summon_minions: PackedFloat32Array
var _buf_flashlight_click: PackedFloat32Array

# RTS stage sound buffers
var _buf_rts_select: PackedFloat32Array
var _buf_rts_command: PackedFloat32Array
var _buf_rts_build_place: PackedFloat32Array
var _buf_rts_build_complete: PackedFloat32Array
var _buf_rts_attack: PackedFloat32Array
var _buf_rts_unit_death: PackedFloat32Array
var _buf_rts_gather: PackedFloat32Array

# Cell stage ambient
var _cell_ambient_player: AudioStreamPlayer = null

# Creature vocalization cooldowns
var _player_voice_cooldown: float = 0.0
const PLAYER_VOICE_COOLDOWN_TIME: float = 3.0
var _creature_voice_cooldown: float = 0.0
const CREATURE_VOICE_COOLDOWN_TIME: float = 0.4  # Global throttle: max ~2.5 creature voices/sec

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

	# Pre-generate Phase 1 polish sounds
	_buf_evolution_fanfare = SynthSounds.gen_evolution_fanfare()
	_buf_sensory_upgrade = SynthSounds.gen_sensory_upgrade()
	_buf_heartbeat = SynthSounds.gen_heartbeat()
	_buf_ui_hover = SynthSounds.gen_ui_hover()
	_buf_ui_select = SynthSounds.gen_ui_select()
	_buf_ui_open = SynthSounds.gen_ui_open()
	_buf_energy_warning = SynthSounds.gen_energy_warning()

	# Pre-generate CRISPR splice sounds
	_buf_splice_success = SynthSounds.gen_splice_success()
	_buf_splice_fail = SynthSounds.gen_splice_fail()

	# Pre-generate observer vocalization buffers
	_buf_observer_gasp = SynthSounds.gen_observer_gasp()
	_buf_observer_hmm = SynthSounds.gen_observer_hmm()
	_buf_observer_laugh = SynthSounds.gen_observer_laugh()
	_buf_observer_impressed = SynthSounds.gen_observer_impressed()
	_buf_observer_distressed = SynthSounds.gen_observer_distressed()
	_buf_observer_grunt = SynthSounds.gen_observer_grunt()
	_buf_observer_chirp = SynthSounds.gen_observer_chirp()
	_buf_observer_mutter = SynthSounds.gen_observer_mutter()

	# Pre-generate snake stage environment sounds
	_buf_grass_rustle = SynthSounds.gen_grass_rustle()
	_buf_bush_push = SynthSounds.gen_bush_push()
	_buf_insect_chirp = SynthSounds.gen_insect_chirp()
	_buf_tunnel_echo = SynthSounds.gen_tunnel_echo()
	_buf_land_collect = SynthSounds.gen_land_collect()
	_buf_ambient_hum = SynthSounds.gen_ambient_hum()

	# Pre-generate parasite mode combat sounds
	_buf_bite_snap = SynthSounds.gen_bite_snap()
	_buf_stun_burst = SynthSounds.gen_stun_burst()
	_buf_wbc_alert = SynthSounds.gen_wbc_alert()

	# Pre-generate cave stage sounds
	_buf_sonar_ping = SynthSounds.gen_sonar_ping()
	_buf_sonar_return = SynthSounds.gen_sonar_return()
	_buf_cave_drip = SynthSounds.gen_cave_drip()
	_buf_crystal_resonance = SynthSounds.gen_crystal_resonance()
	_buf_lava_bubble = SynthSounds.gen_lava_bubble()
	_buf_deep_cave_drone = SynthSounds.gen_deep_cave_drone()
	_buf_cave_footstep = SynthSounds.gen_cave_footstep()
	_buf_mode_switch = SynthSounds.gen_mode_switch()
	_buf_spore_release = SynthSounds.gen_spore_release()
	_buf_creature_echolocation = SynthSounds.gen_creature_echolocation()

	# Pre-generate combat audio
	_buf_victory_sting = SynthSounds.gen_victory_sting()
	_buf_combat_percussion = SynthSounds.gen_combat_percussion()
	_buf_boss_intro_sting = SynthSounds.gen_boss_intro_sting()

	# Pre-generate snake stage combat SFX
	_buf_venom_spit = SynthSounds.gen_venom_spit()
	_buf_tail_whip = SynthSounds.gen_tail_whip()
	_buf_segment_grow = SynthSounds.gen_segment_grow()

	# Pre-generate golden card SFX
	_buf_toxic_miasma = SynthSounds.gen_toxic_miasma()
	_buf_chain_lightning = SynthSounds.gen_chain_lightning()
	_buf_regenerative_burst = SynthSounds.gen_regenerative_burst()

	# Pre-generate boss trait attack SFX
	_buf_pulse_wave = SynthSounds.gen_pulse_wave()
	_buf_acid_spit_muzzle = SynthSounds.gen_acid_spit_muzzle()
	_buf_wind_gust = SynthSounds.gen_wind_gust()
	_buf_bone_shield = SynthSounds.gen_bone_shield()
	_buf_summon_minions = SynthSounds.gen_summon_minions()
	_buf_flashlight_click = SynthSounds.gen_flashlight_click()

	# Pre-generate RTS stage sounds
	_buf_rts_select = _gen_rts_select()
	_buf_rts_command = _gen_rts_command()
	_buf_rts_build_place = _gen_rts_build_place()
	_buf_rts_build_complete = _gen_rts_build_complete()
	_buf_rts_attack = _gen_rts_attack()
	_buf_rts_unit_death = _gen_rts_unit_death()
	_buf_rts_gather = _gen_rts_gather()

	# Setup music players for file-based music
	_setup_music_players()

	# Setup procedural BGM
	_setup_bgm()

	# Connect to GameManager for stage changes
	if GameManager:
		GameManager.stage_changed.connect(_on_stage_changed)

func _setup_music_players() -> void:
	# Create two music players for crossfading
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Master"
	_music_player_a.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Master"
	_music_player_b.volume_db = -80.0  # Start silent
	add_child(_music_player_b)

	_active_music_player = _music_player_a

func _setup_bgm() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -12.0
	add_child(_bgm_player)

	_bgm_generator = AudioStreamGenerator.new()
	_bgm_generator.mix_rate = BGM_SAMPLE_RATE
	_bgm_generator.buffer_length = 0.5
	_bgm_player.stream = _bgm_generator

	# Only play procedural BGM if not using music files
	if not use_music_files:
		_bgm_player.play()
		_bgm_playback = _bgm_player.get_stream_playback()

func _process(delta: float) -> void:
	# Handle procedural BGM or crossfade
	if use_music_files:
		_update_crossfade(delta)
	else:
		_fill_bgm_buffer(delta)

	# Random ambient bubbles
	if randf() < delta * 0.3:  # ~0.3 bubbles per second
		play_bubble()
	# Update observer cooldown
	if _observer_cooldown > 0:
		_observer_cooldown -= delta
	# Update voice cooldowns
	if _player_voice_cooldown > 0:
		_player_voice_cooldown -= delta
	if _creature_voice_cooldown > 0:
		_creature_voice_cooldown -= delta

func _update_crossfade(delta: float) -> void:
	if not _is_crossfading:
		return

	_crossfade_time += delta
	var t: float = clampf(_crossfade_time / _crossfade_duration, 0.0, 1.0)

	# Crossfade volumes
	var fade_out_player: AudioStreamPlayer = _music_player_b if _active_music_player == _music_player_a else _music_player_a
	_active_music_player.volume_db = lerpf(-80.0, MUSIC_VOLUME_DB, t)
	fade_out_player.volume_db = lerpf(MUSIC_VOLUME_DB, -80.0, t)

	if t >= 1.0:
		_is_crossfading = false
		fade_out_player.stop()

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

		# Combat tension layer
		if _combat_intensity > 0.0:
			# Tense low pulse
			sample += sin(_bgm_time * 55.0 * TAU) * 0.08 * _combat_intensity
			# Dissonant overtone
			sample += sin(_bgm_time * 233.0 * TAU) * 0.03 * _combat_intensity
			# Rhythmic pulse (heartbeat-like)
			var pulse_rate: float = 2.0 + _combat_intensity * 3.0
			var pulse: float = exp(-fmod(_bgm_time * pulse_rate, 1.0) * 8.0)
			sample += pulse * 0.06 * _combat_intensity

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

## --- Phase 1 Polish sounds ---

func play_evolution_fanfare() -> void:
	_play_buffer(_buf_evolution_fanfare, -1.0)

func play_sensory_upgrade() -> void:
	_play_buffer(_buf_sensory_upgrade, -2.0)

func play_heartbeat() -> void:
	_play_buffer(_buf_heartbeat, -2.0)

func play_ui_hover() -> void:
	_play_buffer(_buf_ui_hover, -8.0)

func play_ui_select() -> void:
	_play_buffer(_buf_ui_select, -4.0)

func play_ui_open() -> void:
	_play_buffer(_buf_ui_open, -4.0)

func play_energy_warning() -> void:
	_play_buffer(_buf_energy_warning, -3.0)

func play_splice_success() -> void:
	_play_buffer(_buf_splice_success, -2.0)

func play_splice_fail() -> void:
	_play_buffer(_buf_splice_fail, -2.0)

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

## === OBSERVER VOCALIZATION FUNCTIONS ===

func _can_play_observer() -> bool:
	return _observer_cooldown <= 0

func _play_observer_sound(buf: PackedFloat32Array, volume_db: float = -4.0) -> void:
	if not _can_play_observer():
		return
	_observer_cooldown = OBSERVER_COOLDOWN_TIME
	_play_buffer(buf, volume_db)

func play_observer_gasp() -> void:
	_play_observer_sound(_buf_observer_gasp, -3.0)

func play_observer_hmm() -> void:
	_play_observer_sound(_buf_observer_hmm, -5.0)

func play_observer_laugh() -> void:
	_play_observer_sound(_buf_observer_laugh, -4.0)

func play_observer_impressed() -> void:
	_play_observer_sound(_buf_observer_impressed, -4.0)

func play_observer_distressed() -> void:
	_play_observer_sound(_buf_observer_distressed, -3.0)

func play_observer_grunt() -> void:
	_play_observer_sound(_buf_observer_grunt, -4.0)

func play_observer_chirp() -> void:
	_play_observer_sound(_buf_observer_chirp, -5.0)

func play_observer_mutter() -> void:
	_play_observer_sound(_buf_observer_mutter, -5.0)

## === SNAKE STAGE ENVIRONMENT SOUNDS ===

func play_grass_rustle() -> void:
	_play_buffer(_buf_grass_rustle, -12.0)

func play_bush_push() -> void:
	_play_buffer(_buf_bush_push, -8.0)

func play_insect_chirp() -> void:
	_play_buffer(_buf_insect_chirp, -14.0)

func play_tunnel_echo() -> void:
	_play_buffer(_buf_tunnel_echo, -6.0)

func play_land_collect() -> void:
	_play_buffer(_buf_land_collect, -4.0)

func play_ambient_hum() -> void:
	_play_buffer(_buf_ambient_hum, -16.0)

## === PARASITE MODE COMBAT SOUNDS ===

func play_bite_snap() -> void:
	_play_buffer(_buf_bite_snap, -2.0)

func play_stun_burst() -> void:
	_play_buffer(_buf_stun_burst, -1.0)

func play_wbc_alert() -> void:
	_play_buffer(_buf_wbc_alert, -4.0)

## === CAVE STAGE SOUNDS ===

func play_sonar_ping() -> void:
	_play_buffer(_buf_sonar_ping, -10.0)

func play_sonar_return() -> void:
	_play_buffer(_buf_sonar_return, -12.0)

func play_cave_drip() -> void:
	# Regenerate each time for variety in pitch
	var buf := SynthSounds.gen_cave_drip()
	_play_buffer(buf, -10.0)

func play_crystal_resonance() -> void:
	_play_buffer(_buf_crystal_resonance, -8.0)

func play_lava_bubble() -> void:
	_play_buffer(_buf_lava_bubble, -6.0)

func play_deep_cave_drone() -> void:
	_play_buffer(_buf_deep_cave_drone, -14.0)

func play_cave_footstep() -> void:
	_play_buffer(_buf_cave_footstep, -10.0)

func play_mode_switch() -> void:
	_play_buffer(_buf_mode_switch, -4.0)

func play_spore_release() -> void:
	_play_buffer(_buf_spore_release, -8.0)

func play_creature_echolocation() -> void:
	_play_buffer(_buf_creature_echolocation, -6.0)

## === COMBAT AUDIO ===

## Set combat music intensity (0.0 = calm, 0.3 = alert, 1.0 = full combat)
func set_combat_intensity(intensity: float) -> void:
	_combat_intensity = clampf(intensity, 0.0, 1.0)
	if intensity > 0.5:
		_play_buffer(_buf_combat_percussion, -6.0)

## Play ominous boss intro sting for title cards
func play_boss_intro_sting() -> void:
	_play_buffer(_buf_boss_intro_sting, -1.0)

## Play victory fanfare sting
func play_victory_sting() -> void:
	_combat_intensity = 0.0
	_play_buffer(_buf_victory_sting, -2.0)

## === MUSIC FILE PLAYBACK ===

## Play a music track by key (crossfades from current track)
func play_music(key: String) -> void:
	if not use_music_files:
		return
	if key == _current_music_key:
		return
	if key not in _music_tracks:
		push_warning("AudioManager: Unknown music key: " + key)
		return

	var path: String = _music_tracks[key]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: Music file not found: " + path)
		return

	_current_music_key = key
	var stream: AudioStream = load(path)

	# Swap active player and start crossfade
	var next_player: AudioStreamPlayer = _music_player_b if _active_music_player == _music_player_a else _music_player_a
	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()

	_active_music_player = next_player
	_crossfade_time = 0.0
	_is_crossfading = true

## Stop all music with fade out
func stop_music() -> void:
	_current_music_key = ""
	_is_crossfading = false
	# Quick fade out
	var tween := create_tween()
	tween.tween_property(_music_player_a, "volume_db", -80.0, 0.5)
	tween.parallel().tween_property(_music_player_b, "volume_db", -80.0, 0.5)
	tween.tween_callback(func():
		_music_player_a.stop()
		_music_player_b.stop()
	)

## Play a one-shot event music (like death or victory jingle)
func play_event_music(key: String) -> void:
	if not use_music_files:
		return
	if key not in _music_tracks:
		return

	var path: String = _music_tracks[key]
	if not ResourceLoader.exists(path):
		return

	# Use an SFX player for one-shot event music
	var stream: AudioStream = load(path)
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = MUSIC_VOLUME_DB
			p.play()
			return

## === MUSIC/PROCEDURAL TOGGLE ===

## Toggle between procedural and file-based music
func set_use_music_files(enabled: bool) -> void:
	if use_music_files == enabled:
		return

	use_music_files = enabled

	if enabled:
		# Stop procedural BGM
		_bgm_player.stop()
		_bgm_playback = null
		# Start file-based music for current stage
		_start_music_for_current_stage()
	else:
		# Stop file music
		stop_music()
		# Restart procedural BGM
		_bgm_player.stream = _bgm_generator
		_bgm_player.play()
		_bgm_playback = _bgm_player.get_stream_playback()

func toggle_music_mode() -> void:
	set_use_music_files(not use_music_files)

func is_using_music_files() -> bool:
	return use_music_files

## === VOLUME CONTROL ===
## Uses Godot's Master audio bus. Values are 0.0 to 1.0 (linear).

var _master_volume: float = 1.0
var _sfx_volume: float = 1.0
var _music_volume: float = 1.0

func set_master_volume(vol: float) -> void:
	_master_volume = clampf(vol, 0.0, 1.0)
	var db: float = linear_to_db(_master_volume) if _master_volume > 0.001 else -80.0
	AudioServer.set_bus_volume_db(0, db)

func get_master_volume() -> float:
	return _master_volume

func set_sfx_volume(vol: float) -> void:
	_sfx_volume = clampf(vol, 0.0, 1.0)
	for player in _sfx_players:
		player.volume_db = linear_to_db(_sfx_volume) if _sfx_volume > 0.001 else -80.0

func get_sfx_volume() -> float:
	return _sfx_volume

func set_music_volume(vol: float) -> void:
	_music_volume = clampf(vol, 0.0, 1.0)
	var db: float = linear_to_db(_music_volume) if _music_volume > 0.001 else -80.0
	_bgm_player.volume_db = db
	if _music_player_a:
		_music_player_a.volume_db = db
	if _music_player_b:
		_music_player_b.volume_db = db

func get_music_volume() -> float:
	return _music_volume

## === STAGE-BASED MUSIC ===

func _on_stage_changed(new_stage: String) -> void:
	if not use_music_files:
		return
	match new_stage:
		"menu":
			play_music("menu")
		"intro":
			play_music("menu")  # Use menu music for intro too
		"cell":
			play_music("cell_stage")
		"rts":
			play_music("cell_stage")  # Reuse cell stage music for RTS
		"ocean_stub":
			play_music("victory")

func _start_music_for_current_stage() -> void:
	if not GameManager:
		return
	match GameManager.current_stage:
		GameManager.Stage.MENU:
			play_music("menu")
		GameManager.Stage.INTRO:
			play_music("menu")
		GameManager.Stage.CELL:
			play_music("cell_stage")
		GameManager.Stage.RTS:
			play_music("cell_stage")
		GameManager.Stage.OCEAN_STUB:
			play_music("victory")

## Register a custom music track
func register_music_track(key: String, path: String) -> void:
	_music_tracks[key] = path

## Get list of registered music keys
func get_music_keys() -> Array:
	return _music_tracks.keys()

## === CREATURE VOCALIZATIONS ===

## Play player organism voice (evolves with evolution level)
func play_player_voice(type: String) -> void:
	if _player_voice_cooldown > 0:
		return
	_player_voice_cooldown = PLAYER_VOICE_COOLDOWN_TIME
	var evo: int = GameManager.evolution_level if GameManager else 0
	var params: Dictionary = VoiceGenerator.get_player_voice_params(evo, type)
	var buf := VoiceGenerator.gen_voice(params)
	_play_buffer(buf, -4.0)

## Play enemy creature voice (parameterized by species + runtime traits)
func play_creature_voice(species_id: String, type: String, size: float = 1.0, aggro: float = 0.5, speed: float = 1.0) -> void:
	if _creature_voice_cooldown > 0 and type != "death":
		return  # Global throttle prevents audio pool saturation (death always plays)
	_creature_voice_cooldown = CREATURE_VOICE_COOLDOWN_TIME
	var params: Dictionary = VoiceGenerator.get_species_voice_params(species_id, type, size, aggro, speed)
	var buf := VoiceGenerator.gen_voice(params)
	_play_buffer(buf, -5.0)

## Play voice preview for codex UI (bypasses cooldown)
func play_voice_preview(species_id: String, voice_type: String) -> void:
	var params: Dictionary = VoiceGenerator.get_species_voice_params(species_id, voice_type, 1.0, 0.5, 1.0)
	var buf := VoiceGenerator.gen_voice(params)
	_play_buffer(buf, -3.0)

## === SNAKE STAGE COMBAT SFX ===

func play_venom_spit() -> void:
	_play_buffer(_buf_venom_spit, -3.0)

func play_tail_whip() -> void:
	_play_buffer(_buf_tail_whip, -2.0)

func play_segment_grow() -> void:
	_play_buffer(_buf_segment_grow, -4.0)

## === GOLDEN CARD ABILITIES ===

func play_toxic_miasma() -> void:
	_play_buffer(_buf_toxic_miasma, -1.0)

func play_chain_lightning() -> void:
	_play_buffer(_buf_chain_lightning, 0.0)

func play_regenerative_burst() -> void:
	_play_buffer(_buf_regenerative_burst, -2.0)

## === BOSS TRAIT ATTACKS ===

func play_pulse_wave() -> void:
	_play_buffer(_buf_pulse_wave, -1.0)

func play_acid_spit_muzzle() -> void:
	_play_buffer(_buf_acid_spit_muzzle, -2.0)

func play_wind_gust() -> void:
	_play_buffer(_buf_wind_gust, -3.0)

func play_bone_shield() -> void:
	_play_buffer(_buf_bone_shield, -2.0)

func play_summon_minions() -> void:
	_play_buffer(_buf_summon_minions, -3.0)

func play_flashlight_click() -> void:
	_play_buffer(_buf_flashlight_click, -4.0)

## === RTS STAGE SOUNDS ===

func play_rts_select() -> void:
	_play_buffer(_buf_rts_select, -6.0)

func play_rts_command() -> void:
	_play_buffer(_buf_rts_command, -5.0)

func play_rts_build_place() -> void:
	_play_buffer(_buf_rts_build_place, -4.0)

func play_rts_build_complete() -> void:
	_play_buffer(_buf_rts_build_complete, -2.0)

func play_rts_attack() -> void:
	_play_buffer(_buf_rts_attack, -3.0)

func play_rts_unit_death() -> void:
	_play_buffer(_buf_rts_unit_death, -3.0)

func play_rts_gather() -> void:
	_play_buffer(_buf_rts_gather, -8.0)

# RTS sound generators (simple procedural)
func _gen_rts_select() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	var len: int = int(SAMPLE_RATE * 0.12)
	buf.resize(len)
	for i in range(len):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = (1.0 - t / 0.12) * 0.4
		buf[i] = sin(t * 880.0 * TAU) * env + sin(t * 1320.0 * TAU) * env * 0.3
	return buf

func _gen_rts_command() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	var len: int = int(SAMPLE_RATE * 0.15)
	buf.resize(len)
	for i in range(len):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = (1.0 - t / 0.15) * 0.35
		var freq: float = 660.0 + t * 200.0
		buf[i] = sin(t * freq * TAU) * env
	return buf

func _gen_rts_build_place() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	var len: int = int(SAMPLE_RATE * 0.2)
	buf.resize(len)
	for i in range(len):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = (1.0 - t / 0.2) * 0.3
		buf[i] = sin(t * 440.0 * TAU) * env + sin(t * 550.0 * TAU) * env * 0.5
	return buf

func _gen_rts_build_complete() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	var len: int = int(SAMPLE_RATE * 0.4)
	buf.resize(len)
	for i in range(len):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = (1.0 - t / 0.4) * 0.35
		var freq: float = 440.0 if t < 0.15 else 660.0 if t < 0.3 else 880.0
		buf[i] = sin(t * freq * TAU) * env
	return buf

func _gen_rts_attack() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	var len: int = int(SAMPLE_RATE * 0.1)
	buf.resize(len)
	for i in range(len):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = (1.0 - t / 0.1) * 0.5
		buf[i] = sin(t * 220.0 * TAU) * env + sin(t * 330.0 * TAU) * env * 0.3
	return buf

func _gen_rts_unit_death() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	var len: int = int(SAMPLE_RATE * 0.3)
	buf.resize(len)
	for i in range(len):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = (1.0 - t / 0.3) * 0.4
		var freq: float = 300.0 - t * 200.0
		buf[i] = sin(t * freq * TAU) * env
	return buf

func _gen_rts_gather() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	var len: int = int(SAMPLE_RATE * 0.08)
	buf.resize(len)
	for i in range(len):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = (1.0 - t / 0.08) * 0.2
		buf[i] = sin(t * 1200.0 * TAU) * env
	return buf

## === CELL STAGE AMBIENT ===

func start_cell_ambient() -> void:
	if _cell_ambient_player:
		return
	_cell_ambient_player = AmbientSoundscape.create_cell_ambient(self)

func stop_cell_ambient() -> void:
	if _cell_ambient_player:
		_cell_ambient_player.stop()
		_cell_ambient_player.queue_free()
		_cell_ambient_player = null
	# Also clean up the driver node
	var driver = get_node_or_null("CellAmbientDriver")
	if driver:
		driver.queue_free()

class_name VoiceGenerator
## Parameterized creature vocalization engine.
## Generates organic sounds from trait parameters (size, aggression, speed).
## Player voice evolves gradually with evolution_level (0-10).

const SAMPLE_RATE: float = 22050.0

## Voice types and their base envelopes
const VOICE_ENVELOPES: Dictionary = {
	"idle": {"dur": 0.5, "attack": 0.08, "decay": 0.1, "sustain": 0.4, "release": 0.2},
	"alert": {"dur": 0.4, "attack": 0.02, "decay": 0.05, "sustain": 0.6, "release": 0.15},
	"attack": {"dur": 0.3, "attack": 0.01, "decay": 0.04, "sustain": 0.7, "release": 0.1},
	"hurt": {"dur": 0.25, "attack": 0.005, "decay": 0.03, "sustain": 0.5, "release": 0.12},
	"death": {"dur": 0.7, "attack": 0.02, "decay": 0.1, "sustain": 0.3, "release": 0.4},
}

## Species preset library — base voice parameters per creature type
## Keys: base_freq, harmonics, breathiness, metallic, aggro_base, voice_character
const SPECIES_PRESETS: Dictionary = {
	# --- Cell Stage ---
	"player_cell":      {"base_freq": 280.0, "harmonics": 2, "breathiness": 0.15, "metallic": 0.0, "aggro_base": 0.2, "voice_character": "chirp"},
	"enemy_cell":       {"base_freq": 200.0, "harmonics": 2, "breathiness": 0.2, "metallic": 0.0, "aggro_base": 0.4, "voice_character": "warble"},
	"competitor_cell":  {"base_freq": 180.0, "harmonics": 2, "breathiness": 0.15, "metallic": 0.05, "aggro_base": 0.5, "voice_character": "warble"},
	"basilisk":         {"base_freq": 120.0, "harmonics": 3, "breathiness": 0.1, "metallic": 0.15, "aggro_base": 0.7, "voice_character": "hiss"},
	"dart_predator":    {"base_freq": 250.0, "harmonics": 2, "breathiness": 0.25, "metallic": 0.0, "aggro_base": 0.6, "voice_character": "screech"},
	"electric_eel":     {"base_freq": 160.0, "harmonics": 4, "breathiness": 0.05, "metallic": 0.4, "aggro_base": 0.5, "voice_character": "buzz"},
	"ink_bomber":       {"base_freq": 140.0, "harmonics": 2, "breathiness": 0.3, "metallic": 0.0, "aggro_base": 0.4, "voice_character": "gurgle"},
	"juggernaut":       {"base_freq": 80.0, "harmonics": 3, "breathiness": 0.1, "metallic": 0.2, "aggro_base": 0.8, "voice_character": "growl"},
	"siren_cell":       {"base_freq": 300.0, "harmonics": 3, "breathiness": 0.1, "metallic": 0.0, "aggro_base": 0.3, "voice_character": "sing"},
	"splitter_cell":    {"base_freq": 220.0, "harmonics": 2, "breathiness": 0.2, "metallic": 0.0, "aggro_base": 0.4, "voice_character": "squelch"},
	"snake_prey":       {"base_freq": 320.0, "harmonics": 1, "breathiness": 0.3, "metallic": 0.0, "aggro_base": 0.1, "voice_character": "chirp"},
	"schooling_prey":   {"base_freq": 350.0, "harmonics": 1, "breathiness": 0.25, "metallic": 0.0, "aggro_base": 0.05, "voice_character": "chirp"},
	"hazard_organism":  {"base_freq": 100.0, "harmonics": 3, "breathiness": 0.15, "metallic": 0.1, "aggro_base": 0.3, "voice_character": "gurgle"},
	"leviathan":        {"base_freq": 65.0, "harmonics": 4, "breathiness": 0.08, "metallic": 0.3, "aggro_base": 0.9, "voice_character": "roar"},
	"oculus_titan":     {"base_freq": 75.0, "harmonics": 4, "breathiness": 0.05, "metallic": 0.35, "aggro_base": 0.85, "voice_character": "drone"},
	"virus_organism":   {"base_freq": 400.0, "harmonics": 2, "breathiness": 0.35, "metallic": 0.0, "aggro_base": 0.3, "voice_character": "buzz"},
	# --- Snake Stage ---
	"white_blood_cell": {"base_freq": 220.0, "harmonics": 2, "breathiness": 0.2, "metallic": 0.0, "aggro_base": 0.6, "voice_character": "squelch"},
	"phagocyte":        {"base_freq": 90.0, "harmonics": 3, "breathiness": 0.15, "metallic": 0.15, "aggro_base": 0.7, "voice_character": "growl"},
	"killer_t_cell":    {"base_freq": 200.0, "harmonics": 3, "breathiness": 0.1, "metallic": 0.2, "aggro_base": 0.8, "voice_character": "hiss"},
	"mast_cell":        {"base_freq": 260.0, "harmonics": 2, "breathiness": 0.3, "metallic": 0.1, "aggro_base": 0.5, "voice_character": "screech"},
	"antibody_flyer":   {"base_freq": 340.0, "harmonics": 2, "breathiness": 0.2, "metallic": 0.0, "aggro_base": 0.4, "voice_character": "screech"},
	"prey_bug":         {"base_freq": 380.0, "harmonics": 1, "breathiness": 0.3, "metallic": 0.0, "aggro_base": 0.1, "voice_character": "chirp"},
	# --- Bosses ---
	"macrophage_queen": {"base_freq": 70.0, "harmonics": 5, "breathiness": 0.05, "metallic": 0.5, "aggro_base": 0.9, "voice_character": "roar"},
	"cardiac_colossus": {"base_freq": 55.0, "harmonics": 4, "breathiness": 0.1, "metallic": 0.4, "aggro_base": 0.85, "voice_character": "drone"},
	"gut_warden":       {"base_freq": 60.0, "harmonics": 4, "breathiness": 0.2, "metallic": 0.3, "aggro_base": 0.8, "voice_character": "gurgle"},
	"alveolar_titan":   {"base_freq": 75.0, "harmonics": 4, "breathiness": 0.3, "metallic": 0.25, "aggro_base": 0.8, "voice_character": "growl"},
	"marrow_sentinel":  {"base_freq": 65.0, "harmonics": 5, "breathiness": 0.05, "metallic": 0.6, "aggro_base": 0.9, "voice_character": "drone"},
	"mirror_parasite":  {"base_freq": 85.0, "harmonics": 5, "breathiness": 0.1, "metallic": 0.45, "aggro_base": 1.0, "voice_character": "roar"},
}

## Player voice evolution: smoothly interpolated from tier 0 (squeaky) to tier 10 (deep growl)
## Returns voice params for the given evolution level
static func get_player_voice_params(evo_level: int, voice_type: String) -> Dictionary:
	var t: float = clampf(float(evo_level) / 10.0, 0.0, 1.0)  # 0.0-1.0 across 10 levels
	var base_freq: float = lerpf(280.0, 85.0, t)     # High chirp → deep growl
	var harmonics: int = int(lerpf(1.0, 5.0, t))      # Simple → complex
	var breathiness: float = lerpf(0.2, 0.05, t)      # Breathy → clean
	var metallic: float = lerpf(0.0, 0.35, t)         # Organic → metallic edge
	var aggro: float = lerpf(0.1, 0.6, t)             # Timid → aggressive base
	var size_mult: float = lerpf(0.8, 1.6, t)         # Small → large

	# Voice type modifies aggro
	match voice_type:
		"alert": aggro = minf(aggro + 0.2, 1.0)
		"attack": aggro = minf(aggro + 0.4, 1.0)
		"hurt": aggro = minf(aggro + 0.1, 1.0)
		"death": aggro = maxf(aggro - 0.1, 0.0)

	return {
		"base_freq": base_freq,
		"size_mult": size_mult,
		"aggro_level": aggro,
		"speed_mult": 1.0,
		"voice_type": voice_type,
		"harmonics": harmonics,
		"breathiness": breathiness,
		"metallic": metallic,
	}

## Returns voice params for a specific creature species, modulated by runtime traits
static func get_species_voice_params(species_id: String, voice_type: String, size: float, aggro: float, speed: float) -> Dictionary:
	var preset: Dictionary = SPECIES_PRESETS.get(species_id, SPECIES_PRESETS["enemy_cell"])
	var base_aggro: float = preset.aggro_base

	# Voice type modifies aggro
	match voice_type:
		"alert": base_aggro = minf(base_aggro + 0.15, 1.0)
		"attack": base_aggro = minf(base_aggro + 0.3, 1.0)
		"hurt": base_aggro = minf(base_aggro + 0.1, 1.0)
		"death": base_aggro = maxf(base_aggro - 0.2, 0.0)

	return {
		"base_freq": preset.base_freq,
		"size_mult": clampf(size, 0.5, 2.0),
		"aggro_level": clampf(base_aggro * aggro, 0.0, 1.0),
		"speed_mult": clampf(speed, 0.5, 2.0),
		"voice_type": voice_type,
		"harmonics": preset.harmonics,
		"breathiness": preset.breathiness,
		"metallic": preset.metallic,
	}

## Core voice synthesis — generates a creature vocalization from params
static func gen_voice(params: Dictionary) -> PackedFloat32Array:
	var voice_type: String = params.get("voice_type", "idle")
	var env_data: Dictionary = VOICE_ENVELOPES.get(voice_type, VOICE_ENVELOPES["idle"])

	var dur: float = env_data.dur
	var base_freq: float = clampf(params.get("base_freq", 200.0), 40.0, 800.0)
	var size_mult: float = clampf(params.get("size_mult", 1.0), 0.5, 2.0)
	var aggro: float = clampf(params.get("aggro_level", 0.3), 0.0, 1.0)
	var speed_mult: float = clampf(params.get("speed_mult", 1.0), 0.5, 2.0)
	var n_harmonics: int = clampi(params.get("harmonics", 2), 1, 6)
	var breathiness: float = clampf(params.get("breathiness", 0.15), 0.0, 0.5)
	var metallic: float = clampf(params.get("metallic", 0.0), 0.0, 1.0)

	# Size affects pitch inversely (bigger = lower)
	var freq: float = base_freq / size_mult
	freq = clampf(freq, 40.0, 800.0)

	# Duration scales slightly with voice type
	if voice_type == "death":
		dur *= lerpf(1.0, 1.3, size_mult - 0.5)  # Bigger creatures die slower

	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)

	var phase: float = 0.0
	var phases: Array[float] = []
	phases.resize(n_harmonics)
	for h in range(n_harmonics):
		phases[h] = 0.0

	# Harmonic ratios - slightly inharmonic for organic feel
	var h_ratios: Array[float] = [1.0, 2.02, 3.01, 4.05, 5.03, 6.07]
	# Metallic detuning: spread harmonics further from integer ratios
	if metallic > 0.0:
		h_ratios = [1.0, 2.02 + metallic * 0.15, 3.01 + metallic * 0.2, 4.05 + metallic * 0.3, 5.03 + metallic * 0.4, 6.07 + metallic * 0.5]

	# Harmonic amplitude weights (fundamental loudest, higher = quieter)
	var h_weights: Array[float] = [1.0, 0.35, 0.15, 0.08, 0.04, 0.02]
	# Aggression boosts upper harmonics (rougher sound)
	for h in range(1, h_weights.size()):
		h_weights[h] *= (1.0 + aggro * 2.0)

	# Vibrato rate from speed
	var vibrato_rate: float = 5.0 + speed_mult * 4.0
	var vibrato_depth: float = freq * 0.04 * (1.0 + aggro * 0.5)

	# Pitch contour based on voice type
	var pitch_start_mult: float = 1.0
	var pitch_end_mult: float = 1.0
	match voice_type:
		"idle":
			pitch_start_mult = 1.0
			pitch_end_mult = 0.97  # Slight droop
		"alert":
			pitch_start_mult = 0.9
			pitch_end_mult = 1.15  # Rising alarm
		"attack":
			pitch_start_mult = 1.2
			pitch_end_mult = 0.8  # Sharp descending bark
		"hurt":
			pitch_start_mult = 1.3
			pitch_end_mult = 0.7  # Yelp descending
		"death":
			pitch_start_mult = 1.0
			pitch_end_mult = 0.4  # Long descending moan

	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var t_norm: float = t / dur

		# ADSR envelope
		var env: float = SynthSounds.adsr(t, env_data.attack, env_data.decay, env_data.sustain, env_data.release, dur)

		# Pitch contour
		var pitch_mult: float = lerpf(pitch_start_mult, pitch_end_mult, t_norm)
		var current_freq: float = freq * pitch_mult

		# Vibrato
		current_freq += sin(t * vibrato_rate * TAU) * vibrato_depth

		# Aggro growl: low-frequency amplitude modulation
		var growl_mod: float = 1.0
		if aggro > 0.3:
			var growl_rate: float = 20.0 + aggro * 40.0
			growl_mod = 1.0 - (aggro - 0.3) * 0.4 * (0.5 + 0.5 * sin(t * growl_rate * TAU))

		# Sum harmonics
		var sample: float = 0.0
		for h in range(n_harmonics):
			var h_freq: float = current_freq * h_ratios[h]
			phases[h] += h_freq / SAMPLE_RATE
			sample += SynthSounds.sine(phases[h]) * h_weights[h]

		# Normalize harmonic sum
		var total_weight: float = 0.0
		for h in range(n_harmonics):
			total_weight += h_weights[h]
		if total_weight > 0.0:
			sample /= total_weight

		# Add breathiness (filtered noise)
		if breathiness > 0.0:
			sample += SynthSounds.noise() * breathiness * env

		# Apply growl modulation + envelope
		sample *= env * growl_mod * 0.5

		# Soft clip
		sample = clampf(sample, -0.8, 0.8)
		buf[i] = sample

	return buf

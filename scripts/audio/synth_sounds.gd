class_name SynthSounds
## Procedural waveform generation for sound effects.
## Generates PackedFloat32Array PCM buffers at given sample rate.

const SAMPLE_RATE: float = 22050.0

## Basic waveforms
static func sine(phase: float) -> float:
	return sin(phase * TAU)

static func triangle(phase: float) -> float:
	var p: float = fmod(phase, 1.0)
	return 4.0 * absf(p - 0.5) - 1.0

static func sawtooth(phase: float) -> float:
	return 2.0 * fmod(phase, 1.0) - 1.0

static func square(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0

static func noise() -> float:
	return randf_range(-1.0, 1.0)

## ADSR envelope (all times in seconds)
static func adsr(t: float, attack: float, decay: float, sustain_level: float, release: float, total_dur: float) -> float:
	if t < attack:
		return t / attack
	elif t < attack + decay:
		return lerpf(1.0, sustain_level, (t - attack) / decay)
	elif t < total_dur - release:
		return sustain_level
	elif t < total_dur:
		return lerpf(sustain_level, 0.0, (t - (total_dur - release)) / release)
	return 0.0

## Generate a bright ascending chime for collection
static func gen_collect(pitch_mult: float = 1.0) -> PackedFloat32Array:
	var dur: float = 0.25
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.05, 0.3, 0.1, dur)
		var freq: float = lerpf(400.0, 900.0, t / dur) * pitch_mult
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.5 + triangle(phase * 2.0) * 0.15 + sine(phase * 3.0) * 0.1
		buf[i] = s * env * 0.6
	return buf

## Bubbly gulp for eating
static func gen_eat() -> PackedFloat32Array:
	var dur: float = 0.3
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.08, 0.2, 0.12, dur)
		var freq: float = lerpf(180.0, 100.0, t / dur) + sin(t * 30.0) * 20.0
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.6 + noise() * 0.08 * env
		buf[i] = s * env * 0.5
	return buf

## Soft hurt thud
static func gen_hurt() -> PackedFloat32Array:
	var dur: float = 0.2
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 15.0)
		var freq: float = lerpf(120.0, 60.0, t / dur)
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.7 + noise() * 0.15 * exp(-t * 8.0)
		buf[i] = s * env * 0.5
	return buf

## Toxin splash
static func gen_toxin() -> PackedFloat32Array:
	var dur: float = 0.3
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.005, 0.05, 0.3, 0.15, dur)
		var freq: float = lerpf(200.0, 600.0, t / dur) + sin(t * 50.0) * 40.0
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.4 + noise() * 0.2 * env
		buf[i] = s * env * 0.5
	return buf

## Sad descending death tone
static func gen_death() -> PackedFloat32Array:
	var dur: float = 0.6
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.1, 0.5, 0.3, dur)
		var freq: float = lerpf(440.0, 110.0, t / dur)
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.5) / SAMPLE_RATE  # Minor third
		var s: float = sine(phase) * 0.4 + sine(phase2) * 0.15 + triangle(phase * 0.5) * 0.1
		buf[i] = s * env * 0.5
	return buf

## Silly confused warble
static func gen_confused() -> PackedFloat32Array:
	var dur: float = 0.4
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.05, 0.5, 0.15, dur)
		var freq: float = 300.0 + sin(t * 25.0) * 120.0 + sin(t * 8.0) * 50.0
		phase += freq / SAMPLE_RATE
		var s: float = triangle(phase) * 0.5 + sine(phase * 1.5) * 0.15
		buf[i] = s * env * 0.4
	return buf

## Beam suction hum (longer, loopable)
static func gen_beam_hum() -> PackedFloat32Array:
	var dur: float = 0.5
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Fade in/out for seamless loop
		var env: float = minf(t * 10.0, 1.0) * minf((dur - t) * 10.0, 1.0) * 0.4
		var freq: float = 140.0 + sin(t * 6.0) * 20.0
		phase += freq / SAMPLE_RATE
		var s: float = sawtooth(phase) * 0.3 + sine(phase * 2.0) * 0.2 + sine(phase * 0.5) * 0.15
		buf[i] = s * env
	return buf

## Jet spray whoosh
static func gen_jet() -> PackedFloat32Array:
	var dur: float = 0.3
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.05, 0.4, 0.15, dur)
		var freq_mod: float = lerpf(800.0, 200.0, t / dur)
		var s: float = noise() * 0.5
		# Simple lowpass approximation via averaging with sine
		s = s * 0.4 + sin(t * freq_mod * TAU) * 0.2
		buf[i] = s * env * 0.4
	return buf

## Soft bubble pop
static func gen_bubble() -> PackedFloat32Array:
	var dur: float = 0.12
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 25.0)
		var freq: float = randf_range(600.0, 1200.0) * exp(-t * 5.0)
		phase += freq / SAMPLE_RATE
		buf[i] = sine(phase) * env * 0.2
	return buf

## Sprint whoosh (continuous-ish)
static func gen_sprint() -> PackedFloat32Array:
	var dur: float = 0.4
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = minf(t * 8.0, 1.0) * minf((dur - t) * 8.0, 1.0) * 0.25
		var s: float = noise() * 0.3 + sin(t * 400.0 * TAU) * 0.1
		buf[i] = s * env
	return buf

## === ALIEN OBSERVER VOCALIZATIONS ===

## Observer gasp - sharp intake of breath (concern/surprise)
static func gen_observer_gasp() -> PackedFloat32Array:
	var dur: float = 0.35
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Quick attack, sustained breath sound
		var env: float = adsr(t, 0.02, 0.08, 0.6, 0.15, dur)
		# Rising pitch for intake effect
		var freq: float = lerpf(180.0, 320.0, t / dur) + sin(t * 15.0) * 30.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.5) / SAMPLE_RATE
		# Breathy noise + harmonic
		var s: float = sine(phase) * 0.25 + sine(phase2) * 0.1 + noise() * 0.15 * env
		buf[i] = s * env * 0.5
	return buf

## Observer hmm - curious/interested thinking sound
static func gen_observer_hmm() -> PackedFloat32Array:
	var dur: float = 0.5
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.05, 0.1, 0.7, 0.2, dur)
		# Slight pitch rise then fall (questioning inflection)
		var pitch_curve: float = sin(t / dur * PI) * 0.3
		var freq: float = 140.0 * (1.0 + pitch_curve) + sin(t * 8.0) * 10.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 2.0) / SAMPLE_RATE  # Overtone
		# Nasal resonance
		var s: float = sine(phase) * 0.4 + sine(phase2) * 0.15 + triangle(phase * 0.5) * 0.1
		buf[i] = s * env * 0.4
	return buf

## Observer laugh - alien chuckle (amusement)
static func gen_observer_laugh() -> PackedFloat32Array:
	var dur: float = 0.6
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.05, 0.5, 0.25, dur)
		# Pulsing envelope for "ha ha" effect
		var pulse: float = 0.5 + 0.5 * sin(t * 25.0)
		# Descending pitch with wobble
		var freq: float = lerpf(280.0, 180.0, t / dur) + sin(t * 12.0) * 25.0
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.35 + triangle(phase * 1.5) * 0.15
		buf[i] = s * env * pulse * 0.5
	return buf

## Observer impressed - "ooh" sound (wonder/amazement)
static func gen_observer_impressed() -> PackedFloat32Array:
	var dur: float = 0.55
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.08, 0.1, 0.6, 0.2, dur)
		# Rising then sustained pitch
		var pitch_t: float = minf(t / 0.15, 1.0)
		var freq: float = lerpf(160.0, 240.0, pitch_t) + sin(t * 5.0) * 15.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.5) / SAMPLE_RATE
		# Warm, rounded sound
		var s: float = sine(phase) * 0.4 + sine(phase2) * 0.12 + sine(phase * 0.5) * 0.1
		buf[i] = s * env * 0.45
	return buf

## === PHASE 1 POLISH: NEW SOUNDS ===

## Evolution fanfare - triumphant ascending arpeggio
static func gen_evolution_fanfare() -> PackedFloat32Array:
	var dur: float = 0.8
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	var phase3: float = 0.0
	# Three-note ascending arpeggio: C5, E5, G5 then shimmer
	var notes: Array = [523.25, 659.25, 783.99]
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.1, 0.6, 0.3, dur)
		# Sweep through the arpeggio
		var note_t: float = clampf(t / 0.5, 0.0, 1.0)  # First 0.5s for notes
		var note_idx: int = mini(int(note_t * 3.0), 2)
		var freq: float = notes[note_idx]
		# Add shimmer in the tail
		if t > 0.4:
			freq += sin(t * 20.0) * 30.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.5) / SAMPLE_RATE  # Fifth
		phase3 += (freq * 2.0) / SAMPLE_RATE  # Octave
		var s: float = sine(phase) * 0.3 + sine(phase2) * 0.15 + sine(phase3) * 0.08 + triangle(phase * 0.5) * 0.05
		buf[i] = s * env * 0.6
	return buf

## Sensory upgrade - ethereal ascending tone with sparkle
static func gen_sensory_upgrade() -> PackedFloat32Array:
	var dur: float = 0.6
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.05, 0.15, 0.5, 0.2, dur)
		# Slow rising ethereal tone
		var freq: float = lerpf(300.0, 600.0, t / dur)
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.498) / SAMPLE_RATE  # Slightly detuned fifth = shimmer
		# High sparkle overlay
		var sparkle: float = sin(t * 3000.0 * TAU) * 0.03 * maxf(0.0, (t - 0.3) / 0.3)
		var s: float = sine(phase) * 0.3 + sine(phase2) * 0.2 + sparkle
		buf[i] = s * env * 0.5
	return buf

## Heartbeat - low thump for health warning
static func gen_heartbeat() -> PackedFloat32Array:
	var dur: float = 0.35
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Double thump: two short pulses
		var env1: float = exp(-t * 20.0) * 0.8
		var env2: float = exp(-(t - 0.15) * 20.0) * 0.5 if t > 0.15 else 0.0
		var env: float = env1 + env2
		var freq: float = 50.0 + exp(-t * 10.0) * 30.0
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.7 + noise() * 0.05 * env
		buf[i] = s * env * 0.6
	return buf

## UI hover - tiny bright tick
static func gen_ui_hover() -> PackedFloat32Array:
	var dur: float = 0.06
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 40.0)
		phase += 1200.0 / SAMPLE_RATE
		buf[i] = sine(phase) * env * 0.3
	return buf

## UI select - confirming click
static func gen_ui_select() -> PackedFloat32Array:
	var dur: float = 0.15
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.005, 0.03, 0.3, 0.06, dur)
		var freq: float = lerpf(600.0, 900.0, t / dur)
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.5 + sine(phase * 2.0) * 0.15
		buf[i] = s * env * 0.5
	return buf

## UI open - soft whoosh-chime for panel opening
static func gen_ui_open() -> PackedFloat32Array:
	var dur: float = 0.25
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.05, 0.4, 0.1, dur)
		var freq: float = lerpf(400.0, 700.0, t / dur)
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.3 + noise() * 0.06 * exp(-t * 12.0)
		buf[i] = s * env * 0.4
	return buf

## Energy warning - urgent low beep
static func gen_energy_warning() -> PackedFloat32Array:
	var dur: float = 0.2
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.03, 0.5, 0.08, dur)
		# Two-tone alert
		var freq: float = 220.0 if fmod(t, 0.1) < 0.05 else 180.0
		phase += freq / SAMPLE_RATE
		var s: float = triangle(phase) * 0.4 + sine(phase * 2.0) * 0.15
		buf[i] = s * env * 0.4
	return buf

## Observer distressed - worried warble (concern for specimen)
static func gen_observer_distressed() -> PackedFloat32Array:
	var dur: float = 0.7
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.03, 0.1, 0.5, 0.3, dur)
		# Wavering, uncertain pitch
		var vibrato: float = sin(t * 18.0) * 40.0
		var freq: float = lerpf(220.0, 160.0, t / dur) + vibrato
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.33) / SAMPLE_RATE  # Minor third for sad feeling
		var s: float = sine(phase) * 0.35 + sine(phase2) * 0.2 + noise() * 0.05 * env
		buf[i] = s * env * 0.45
	return buf

## Observer grunt - deep villager "hrmm" sound
static func gen_observer_grunt() -> PackedFloat32Array:
	var dur: float = 0.45
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	var phase3: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.04, 0.08, 0.65, 0.2, dur)
		# Low rumbling pitch with slight drop — classic villager grunt
		var freq: float = 95.0 + sin(t * 6.0) * 8.0 - t / dur * 15.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 2.02) / SAMPLE_RATE  # Slightly detuned overtone
		phase3 += (freq * 3.0) / SAMPLE_RATE
		# Thick nasal resonance
		var s: float = sine(phase) * 0.35 + sine(phase2) * 0.2 + triangle(phase3) * 0.08
		# Add chest rumble
		s += sine(phase * 0.5) * 0.12
		buf[i] = s * env * 0.5
	return buf

## Observer chirp - short rising "hmm?" inquisitive sound
static func gen_observer_chirp() -> PackedFloat32Array:
	var dur: float = 0.3
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.05, 0.7, 0.12, dur)
		# Sharp rising pitch at the end — questioning inflection
		var rise: float = 0.0
		if t > dur * 0.6:
			rise = (t - dur * 0.6) / (dur * 0.4)
		var freq: float = 150.0 + rise * 80.0 + sin(t * 12.0) * 10.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.5) / SAMPLE_RATE
		var s: float = sine(phase) * 0.3 + triangle(phase2) * 0.15 + noise() * 0.03 * env
		buf[i] = s * env * 0.45
	return buf

## Observer mutter - low mumbled thought, like writing notes
static func gen_observer_mutter() -> PackedFloat32Array:
	var dur: float = 0.65
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.03, 0.1, 0.4, 0.3, dur)
		# Mumbling: pitch wobbles around low frequency
		var wobble: float = sin(t * 20.0) * 15.0 + sin(t * 7.0) * 8.0
		var freq: float = 110.0 + wobble
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 2.0) / SAMPLE_RATE
		# Mix of nasal tone and slight breathiness
		var s: float = sine(phase) * 0.25 + sine(phase2) * 0.1 + noise() * 0.04 * env
		# Pulsing syllables — creates "mm-mm-mm" feel
		var syllable: float = 0.6 + 0.4 * sin(t * 14.0)
		buf[i] = s * env * syllable * 0.4
	return buf

static func gen_splice_success() -> PackedFloat32Array:
	var dur: float = 0.6
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.05, 0.6, 0.4, dur)
		# Rising arpeggio: C5 → E5 → G5
		var freq: float = 523.0
		if t > 0.15:
			freq = 659.0
		if t > 0.3:
			freq = 784.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 2.0) / SAMPLE_RATE  # Octave sparkle
		var s: float = sine(phase) * 0.4 + sine(phase2) * 0.15 + triangle(phase * 0.5) * 0.1
		buf[i] = s * env * 0.5
	return buf

static func gen_splice_fail() -> PackedFloat32Array:
	var dur: float = 0.5
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.05, 0.5, 0.3, dur)
		# Descending dissonant buzz
		var freq: float = lerpf(300.0, 120.0, t / dur)
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.06) / SAMPLE_RATE  # Minor second for dissonance
		var s: float = square(phase) * 0.25 + sine(phase2) * 0.2 + noise() * 0.1 * env
		buf[i] = s * env * 0.4
	return buf

## --- SNAKE STAGE ENVIRONMENT SOUNDS ---

## Grass rustle: filtered noise with gentle high-pass character
static func gen_grass_rustle() -> PackedFloat32Array:
	var dur: float = 0.3
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var prev: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.08, 0.3, 0.15, dur)
		# Filtered noise (high-pass via differencing)
		var raw: float = noise() * 0.5
		var filtered: float = raw - prev * 0.7
		prev = raw
		buf[i] = filtered * env * 0.25
	return buf

## Bush push: deeper rustling swoosh
static func gen_bush_push() -> PackedFloat32Array:
	var dur: float = 0.4
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.1, 0.4, 0.2, dur)
		var freq: float = lerpf(120.0, 60.0, t / dur)
		phase += freq / SAMPLE_RATE
		var s: float = noise() * 0.4 + sine(phase) * 0.15
		buf[i] = s * env * 0.3
	return buf

## Ambient insect chirp: short high-pitched trill
static func gen_insect_chirp() -> PackedFloat32Array:
	var dur: float = 0.15
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.005, 0.02, 0.6, 0.05, dur)
		# Rapid chirp: high freq with AM modulation
		var freq: float = randf_range(2800.0, 4200.0)
		phase += freq / SAMPLE_RATE
		var am: float = 0.5 + 0.5 * sine(t * 45.0)  # Amplitude modulation for chirp
		var s: float = sine(phase) * am
		buf[i] = s * env * 0.15
	return buf

## Tunnel echo: reverb-like descending tone
static func gen_tunnel_echo() -> PackedFloat32Array:
	var dur: float = 1.2
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.05, 0.2, 0.3, 0.6, dur)
		var freq: float = lerpf(200.0, 80.0, t / dur)
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.5) / SAMPLE_RATE  # Fifth harmony
		var s: float = sine(phase) * 0.4 + sine(phase2) * 0.2 + noise() * 0.05
		buf[i] = s * env * 0.3
	return buf

## Nutrient land collect: bright sparkly chime (different from cell stage)
static func gen_land_collect() -> PackedFloat32Array:
	var dur: float = 0.35
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.08, 0.4, 0.15, dur)
		# Two-tone ascending sparkle
		var freq: float = lerpf(600.0, 1200.0, t / dur)
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.5) / SAMPLE_RATE
		var s: float = sine(phase) * 0.35 + triangle(phase2) * 0.15 + sine(phase * 3.0) * 0.08
		buf[i] = s * env * 0.5
	return buf

## Ambient hum: low organic drone for background
static func gen_ambient_hum() -> PackedFloat32Array:
	var dur: float = 3.0
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.5, 0.3, 0.5, 1.0, dur)
		# Slow, low organic drone
		var freq: float = 55.0 + sin(t * 0.3) * 5.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.498) / SAMPLE_RATE  # Slightly detuned fifth
		var s: float = sine(phase) * 0.3 + sine(phase2) * 0.2 + triangle(phase * 0.5) * 0.1
		buf[i] = s * env * 0.15
	return buf

## --- CAVE STAGE SOUNDS ---

## Sonar ping: deep bassy submarine pulse with cave reverb
static func gen_sonar_ping() -> PackedFloat32Array:
	var dur: float = 3.0
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	var phase3: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Slow exponential decay over 3 seconds
		var env: float = exp(-t * 1.2) * 0.6
		# Deep bass sweep: 65Hz down to 30Hz
		var freq: float = lerpf(65.0, 30.0, t / dur)
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 0.5) / SAMPLE_RATE  # Sub-bass octave below
		phase3 += (freq * 1.5) / SAMPLE_RATE  # Fifth harmonic for warmth
		# Rich bass tone
		var s: float = sine(phase) * 0.45 + sine(phase2) * 0.3 + sine(phase3) * 0.06
		# Subtle organic texture
		s += noise() * 0.015 * env
		# Cave reverb: multiple reflections
		var reverb: float = 0.0
		if i > int(0.09 * SAMPLE_RATE):
			reverb += buf[i - int(0.09 * SAMPLE_RATE)] * 0.18
		if i > int(0.2 * SAMPLE_RATE):
			reverb += buf[i - int(0.2 * SAMPLE_RATE)] * 0.1
		if i > int(0.4 * SAMPLE_RATE):
			reverb += buf[i - int(0.4 * SAMPLE_RATE)] * 0.05
		buf[i] = (s + reverb) * env
	return buf

## Sonar return: soft tink when contour points appear
static func gen_sonar_return() -> PackedFloat32Array:
	var dur: float = 0.1
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = exp(-t * 35.0)
		phase += 3200.0 / SAMPLE_RATE
		buf[i] = sine(phase) * env * 0.15
	return buf

## Cave drip: single water drip with cave reverb
static func gen_cave_drip() -> PackedFloat32Array:
	var dur: float = 0.6
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Sharp initial drip
		var drip_env: float = exp(-t * 40.0) * 0.7
		var drip_freq: float = lerpf(3500.0, 1800.0, minf(t * 20.0, 1.0))
		phase += drip_freq / SAMPLE_RATE
		var drip: float = sine(phase) * drip_env
		# Reverb tail
		var reverb: float = 0.0
		if i > int(0.08 * SAMPLE_RATE):
			reverb = buf[i - int(0.08 * SAMPLE_RATE)] * 0.25
		if i > int(0.18 * SAMPLE_RATE):
			reverb += buf[i - int(0.18 * SAMPLE_RATE)] * 0.15
		if i > int(0.32 * SAMPLE_RATE):
			reverb += buf[i - int(0.32 * SAMPLE_RATE)] * 0.08
		buf[i] = drip + reverb
	return buf

## Crystal resonance: sustained harmonic drone near crystals
static func gen_crystal_resonance() -> PackedFloat32Array:
	var dur: float = 1.5
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	var phase3: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.2, 0.3, 0.6, 0.5, dur)
		# Pure harmonics for crystal-like tone
		var freq: float = 440.0 + sin(t * 2.0) * 10.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 2.0) / SAMPLE_RATE  # Octave
		phase3 += (freq * 3.0) / SAMPLE_RATE  # Fifth above octave
		var s: float = sine(phase) * 0.25 + sine(phase2) * 0.15 + sine(phase3) * 0.08
		buf[i] = s * env * 0.3
	return buf

## Lava bubble: deep gurgling pop
static func gen_lava_bubble() -> PackedFloat32Array:
	var dur: float = 0.4
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.08, 0.3, 0.2, dur)
		# Low frequency bubble with noise
		var freq: float = lerpf(100.0, 50.0, t / dur) + sin(t * 20.0) * 15.0
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.5 + noise() * 0.15 * env
		buf[i] = s * env * 0.4
	return buf

## Deep cave drone: sub-bass rumble for deep caves
static func gen_deep_cave_drone() -> PackedFloat32Array:
	var dur: float = 4.0
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 1.0, 0.5, 0.6, 1.5, dur)
		# Sub-bass with slow modulation
		var freq: float = 35.0 + sin(t * 0.2) * 5.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.5) / SAMPLE_RATE
		var s: float = sine(phase) * 0.4 + sine(phase2) * 0.15 + noise() * 0.02
		buf[i] = s * env * 0.12
	return buf

## Cave footstep: impact + echo, pitch varies with cave size
static func gen_cave_footstep() -> PackedFloat32Array:
	var dur: float = 0.35
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Sharp impact
		var impact: float = exp(-t * 30.0) * 0.5
		var freq: float = lerpf(200.0, 80.0, minf(t * 10.0, 1.0))
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * impact + noise() * impact * 0.3
		# Echo
		if i > int(0.1 * SAMPLE_RATE):
			s += buf[i - int(0.1 * SAMPLE_RATE)] * 0.2
		buf[i] = s * 0.4
	return buf

## Mode switch: whoosh with rising pitch per mode
static func gen_mode_switch() -> PackedFloat32Array:
	var dur: float = 0.3
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.05, 0.5, 0.15, dur)
		var freq: float = lerpf(200.0, 800.0, t / dur)
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.3 + noise() * 0.15 * exp(-t * 8.0)
		buf[i] = s * env * 0.4
	return buf

## Spore release: soft breath-like puff
static func gen_spore_release() -> PackedFloat32Array:
	var dur: float = 0.5
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.05, 0.1, 0.4, 0.25, dur)
		# Breathy noise
		var s: float = noise() * 0.3 + sin(t * 300.0 * TAU) * 0.05
		buf[i] = s * env * 0.2
	return buf

## --- PARASITE MODE COMBAT SOUNDS ---

## Bite snap: sharp attack transient + bone crunch
static func gen_bite_snap() -> PackedFloat32Array:
	var dur: float = 0.3
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Sharp transient attack
		var attack: float = exp(-t * 40.0) * 0.8
		# Crunch noise burst
		var crunch_env: float = exp(-t * 12.0) * 0.5
		var crunch: float = noise() * crunch_env
		# Low thud
		var freq: float = lerpf(200.0, 60.0, minf(t * 8.0, 1.0))
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 3.0) / SAMPLE_RATE  # Bright harmonic
		var tone: float = sine(phase) * attack + sine(phase2) * attack * 0.15
		var s: float = tone + crunch
		# Quick reverb
		if i > int(0.05 * SAMPLE_RATE):
			s += buf[i - int(0.05 * SAMPLE_RATE)] * 0.15
		buf[i] = s * 0.6
	return buf

## Stun burst: electrical zap + bass thud
static func gen_stun_burst() -> PackedFloat32Array:
	var dur: float = 0.5
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Electrical zap: high freq sweep down
		var zap_env: float = exp(-t * 8.0) * 0.5
		var zap_freq: float = lerpf(4000.0, 200.0, minf(t * 4.0, 1.0))
		phase += zap_freq / SAMPLE_RATE
		var zap: float = sine(phase) * zap_env * 0.3 + noise() * zap_env * 0.2
		# Bass thud
		var thud_env: float = exp(-t * 6.0) * 0.7
		phase2 += 50.0 / SAMPLE_RATE
		var thud: float = sine(phase2) * thud_env
		# Combine
		var s: float = zap + thud
		# Reverb
		if i > int(0.07 * SAMPLE_RATE):
			s += buf[i - int(0.07 * SAMPLE_RATE)] * 0.2
		if i > int(0.15 * SAMPLE_RATE):
			s += buf[i - int(0.15 * SAMPLE_RATE)] * 0.1
		buf[i] = s * 0.5
	return buf

## WBC alert: wet squelch alarm
static func gen_wbc_alert() -> PackedFloat32Array:
	var dur: float = 0.4
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.05, 0.5, 0.2, dur)
		# Wet squelch: low freq with noise modulation
		var freq: float = lerpf(300.0, 150.0, t / dur) + sin(t * 30.0) * 40.0
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.4 + noise() * 0.2 * env
		# Gurgle effect
		s *= 0.5 + 0.5 * sin(t * 20.0)
		buf[i] = s * env * 0.5
	return buf

## Boss intro sting: ominous descending brass hit for boss title cards
static func gen_boss_intro_sting() -> PackedFloat32Array:
	var dur: float = 1.5
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.2, 0.6, 0.8, dur)
		# Descending low brass tone
		var freq: float = lerpf(220.0, 110.0, minf(t / 0.8, 1.0))
		phase += freq / SAMPLE_RATE
		var s: float = 0.0
		# Main tone with harmonics for brass character
		s += sawtooth(phase) * 0.3
		s += sine(phase * 0.5) * 0.3  # Sub octave
		s += sine(phase * 3.0) * 0.08  # 3rd harmonic
		# Impact transient
		s += noise() * 0.5 * exp(-t * 15.0)
		# Reverb-like tail
		s += sine(t * 82.0) * 0.1 * exp(-t * 2.0)
		buf[i] = s * env * 0.5
	return buf

## Victory sting: short triumphant fanfare (major chord arpeggio)
static func gen_victory_sting() -> PackedFloat32Array:
	var dur: float = 1.2
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	# Major chord arpeggio: C5, E5, G5, C6
	var notes: Array = [523.25, 659.25, 783.99, 1046.5]
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.1, 0.7, dur - 0.3, dur)
		var s: float = 0.0
		for n_idx in range(notes.size()):
			var note_start: float = n_idx * 0.12
			if t >= note_start:
				var nt: float = t - note_start
				var note_env: float = adsr(nt, 0.01, 0.05, 0.8, dur - note_start - 0.3, dur - note_start)
				s += sine(notes[n_idx] * nt) * note_env * 0.25
		# Shimmer overtone
		s += sine(1046.5 * t * 2.0) * 0.05 * env * (0.5 + 0.5 * sine(t * 6.0))
		buf[i] = s * env * 0.6
	return buf

## Combat percussion: tense rhythmic hit for combat state transitions
static func gen_combat_percussion() -> PackedFloat32Array:
	var dur: float = 0.6
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.005, 0.05, 0.3, 0.2, dur)
		# Deep impact drum
		var drum_freq: float = lerpf(120.0, 50.0, minf(t * 4.0, 1.0))
		phase += drum_freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.5 * exp(-t * 8.0)
		# Noise layer for attack transient
		s += noise() * 0.4 * exp(-t * 25.0)
		# Sub-bass rumble
		s += sine(t * 40.0) * 0.15 * exp(-t * 3.0)
		buf[i] = s * env * 0.7
	return buf

## Creature echolocation: rapid clicks for Abyss Lurker
static func gen_creature_echolocation() -> PackedFloat32Array:
	var dur: float = 0.4
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Rapid clicks
		var click_rate: float = 40.0
		var click_phase: float = fmod(t * click_rate, 1.0)
		var click: float = exp(-click_phase * 50.0) * 0.6
		var freq: float = 4000.0 + sin(t * 8.0) * 500.0
		var s: float = sin(t * freq * TAU) * click
		buf[i] = s * 0.3
	return buf

## === SNAKE STAGE COMBAT SFX ===

## Venom spit: wet toxic spray with rising hiss
static func gen_venom_spit() -> PackedFloat32Array:
	var dur: float = 0.4
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.01, 0.06, 0.4, 0.2, dur)
		# Rising hiss
		var freq: float = lerpf(150.0, 500.0, t / dur) + sin(t * 40.0) * 30.0
		phase += freq / SAMPLE_RATE
		# Wet sizzle: noise + tone
		var s: float = sine(phase) * 0.3 + noise() * 0.25 * env
		# Liquid modulation
		s *= 0.7 + 0.3 * sin(t * 25.0)
		buf[i] = s * env * 0.5
	return buf

## Tail whip: whooshing arc sweep with Doppler-like pitch shift
static func gen_tail_whip() -> PackedFloat32Array:
	var dur: float = 0.5
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Build-up then peak then decay (arc shape)
		var arc: float = sin(t / dur * PI)
		var env: float = arc * arc * 0.6
		# Doppler: freq rises then falls
		var freq: float = 200.0 + arc * 400.0
		phase += freq / SAMPLE_RATE
		# Whoosh: filtered noise + low tone
		var s: float = noise() * 0.4 * env + sine(phase) * 0.15 * env
		# Impact transient at peak
		if t > dur * 0.35 and t < dur * 0.5:
			var impact_t: float = (t - dur * 0.35) / (dur * 0.15)
			s += noise() * 0.3 * exp(-impact_t * 8.0)
		buf[i] = s * 0.5
	return buf

## Segment grow: organic stretching rumble with wet crackle
static func gen_segment_grow() -> PackedFloat32Array:
	var dur: float = 0.6
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.05, 0.1, 0.5, 0.3, dur)
		# Low stretching rumble
		var freq: float = 70.0 + sin(t * 8.0) * 15.0
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.4 + triangle(phase * 2.0) * 0.1
		# Crackle overlay (sparse noise pops)
		if randf() < 0.15:
			s += noise() * 0.2 * env
		# Rising tone for "growth" feel
		s += sine(t * lerpf(200.0, 400.0, t / dur)) * 0.06 * env
		buf[i] = s * env * 0.5
	return buf

## === GOLDEN CARD ABILITIES ===

## Toxic miasma: expanding poison cloud — bubbling hiss + menacing drone
static func gen_toxic_miasma() -> PackedFloat32Array:
	var dur: float = 1.0
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.05, 0.15, 0.5, 0.4, dur)
		# Menacing low drone
		var freq: float = 80.0 + sin(t * 3.0) * 10.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.33) / SAMPLE_RATE  # Minor third
		var s: float = sine(phase) * 0.3 + sine(phase2) * 0.15
		# Bubbling hiss
		var bubble_rate: float = 15.0 + t / dur * 10.0
		s += noise() * 0.2 * env * (0.5 + 0.5 * sin(t * bubble_rate))
		# Sizzle
		s += noise() * 0.08 * env
		buf[i] = s * env * 0.5
	return buf

## Chain lightning: crackling electrical arc with decay
static func gen_chain_lightning() -> PackedFloat32Array:
	var dur: float = 0.7
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Sharp initial crack then sizzling decay
		var env: float = exp(-t * 4.0) * 0.7
		# Multiple arcs: 3 bursts
		var burst1: float = exp(-t * 20.0)
		var burst2: float = exp(-(t - 0.15) * 20.0) * 0.6 if t > 0.15 else 0.0
		var burst3: float = exp(-(t - 0.35) * 15.0) * 0.4 if t > 0.35 else 0.0
		var bursts: float = burst1 + burst2 + burst3
		# High frequency zap
		var zap_freq: float = lerpf(6000.0, 1000.0, t / dur)
		phase += zap_freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.2 * bursts
		# Crackling noise
		s += noise() * 0.4 * bursts
		# Low bass thud on initial
		s += sine(t * 60.0) * 0.3 * exp(-t * 10.0)
		# Sizzle tail
		s += noise() * 0.06 * env
		buf[i] = s * 0.6
	return buf

## Regenerative burst: healing chime — ascending shimmer with warmth
static func gen_regenerative_burst() -> PackedFloat32Array:
	var dur: float = 0.8
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	var phase3: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.05, 0.1, 0.6, 0.3, dur)
		# Warm ascending tone
		var freq: float = lerpf(300.0, 600.0, t / dur)
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.5) / SAMPLE_RATE  # Perfect fifth
		phase3 += (freq * 2.0) / SAMPLE_RATE  # Octave
		var s: float = sine(phase) * 0.3 + sine(phase2) * 0.15 + sine(phase3) * 0.08
		# Sparkle overlay in upper register
		if t > 0.2:
			var sparkle_env: float = (t - 0.2) / (dur - 0.2) * env
			s += sine(t * 2400.0) * 0.04 * sparkle_env * (0.5 + 0.5 * sin(t * 8.0))
		buf[i] = s * env * 0.5
	return buf

## === BOSS TRAIT ATTACK SFX ===

## Pulse wave: expanding torus ring — deep bass thump with overtone ring
static func gen_pulse_wave() -> PackedFloat32Array:
	var dur: float = 0.8
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Massive bass impact
		var impact: float = exp(-t * 8.0) * 0.7
		var freq: float = lerpf(80.0, 35.0, minf(t * 3.0, 1.0))
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * impact
		# Sub-bass
		s += sine(t * 25.0) * 0.3 * impact
		# Overtone ring (sustained after impact)
		var ring_env: float = adsr(t, 0.01, 0.1, 0.3, 0.4, dur)
		s += sine(t * 220.0) * 0.1 * ring_env
		s += sine(t * 330.0) * 0.05 * ring_env
		# Noise burst on attack
		s += noise() * 0.4 * exp(-t * 15.0)
		buf[i] = s * 0.6
	return buf

## Acid spit: charge-up whine then sizzle release
static func gen_acid_spit_muzzle() -> PackedFloat32Array:
	var dur: float = 0.5
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.02, 0.05, 0.5, 0.2, dur)
		# Rising whine then descend
		var freq: float
		if t < dur * 0.4:
			freq = lerpf(200.0, 800.0, t / (dur * 0.4))
		else:
			freq = lerpf(800.0, 300.0, (t - dur * 0.4) / (dur * 0.6))
		phase += freq / SAMPLE_RATE
		var s: float = sine(phase) * 0.3 + sawtooth(phase * 0.5) * 0.1
		# Sizzle noise after peak
		if t > dur * 0.3:
			s += noise() * 0.2 * env
		buf[i] = s * env * 0.5
	return buf

## Wind gust: powerful exhale — broad noise sweep
static func gen_wind_gust() -> PackedFloat32Array:
	var dur: float = 0.6
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var prev: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.03, 0.1, 0.5, 0.3, dur)
		# Wind: filtered noise with sweeping cutoff
		var raw: float = noise()
		# Lowpass blend changes over time (opens up then closes)
		var cutoff: float = 0.3 + sin(t / dur * PI) * 0.5
		var filtered: float = raw * (1.0 - cutoff) + prev * cutoff
		prev = filtered
		var s: float = filtered * 0.5 * env
		# Low whoosh tone
		s += sine(t * lerpf(100.0, 60.0, t / dur)) * 0.12 * env
		buf[i] = s * 0.5
	return buf

## Bone shield: crystalline barrier clang with shimmer
static func gen_bone_shield() -> PackedFloat32Array:
	var dur: float = 0.5
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	var phase3: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		# Sharp metallic clang
		var clang: float = exp(-t * 10.0) * 0.5
		phase += 880.0 / SAMPLE_RATE
		phase2 += 1320.0 / SAMPLE_RATE  # Fifth above
		phase3 += 2200.0 / SAMPLE_RATE  # High partial
		var s: float = sine(phase) * clang + sine(phase2) * clang * 0.4 + sine(phase3) * clang * 0.15
		# Shimmer after clang
		var shimmer_env: float = adsr(t, 0.1, 0.1, 0.4, 0.2, dur)
		s += sine(t * 1760.0) * 0.06 * shimmer_env * (0.5 + 0.5 * sin(t * 6.0))
		# Impact thud
		s += sine(t * 80.0) * 0.2 * exp(-t * 20.0)
		buf[i] = s * 0.6
	return buf

## Summon minions: dark warble with rising portal energy
static func gen_summon_minions() -> PackedFloat32Array:
	var dur: float = 0.9
	var samples: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(samples)
	var phase: float = 0.0
	var phase2: float = 0.0
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var env: float = adsr(t, 0.1, 0.15, 0.5, 0.3, dur)
		# Dark warbling base
		var freq: float = 100.0 + sin(t * 8.0) * 30.0
		phase += freq / SAMPLE_RATE
		phase2 += (freq * 1.06) / SAMPLE_RATE  # Minor second = dissonance
		var s: float = sine(phase) * 0.3 + sine(phase2) * 0.2
		# Rising portal energy
		var rise_freq: float = lerpf(200.0, 800.0, t / dur)
		s += sine(t * rise_freq) * 0.1 * env * (t / dur)
		# Swirling texture
		s += triangle(t * 150.0 + sin(t * 5.0) * 3.0) * 0.06 * env
		# Dark burst at midpoint
		if t > dur * 0.4 and t < dur * 0.6:
			s += noise() * 0.15 * env
		buf[i] = s * env * 0.5
	return buf

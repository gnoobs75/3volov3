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

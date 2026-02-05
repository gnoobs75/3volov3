shader_type canvas_item;
// Vibrant bioluminescent deep-ocean background.
// Rich colors, chromatic shimmer, underwater distortion, glowing vents.

uniform float time_scale : hint_range(0.0, 2.0) = 1.0;
uniform vec4 deep_color : source_color = vec4(0.02, 0.05, 0.12, 1.0);
uniform vec4 vent_color : source_color = vec4(0.25, 0.08, 0.03, 1.0);
uniform vec4 particle_color : source_color = vec4(0.3, 0.6, 1.0, 0.5);
uniform vec2 player_uv = vec2(0.5, 0.5);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Optimized FBM - reduced iterations for performance
float fbm(vec2 p) {
	float val = 0.0;
	val += 0.5 * noise(p);
	val += 0.25 * noise(p * 2.0);
	val += 0.125 * noise(p * 4.0);
	return val;
}

void fragment() {
	float t = TIME * time_scale;
	vec2 uv = UV;

	// Subtle underwater wobble distortion
	vec2 wobble = vec2(
		sin(uv.y * 12.0 + t * 0.8) * 0.003,
		cos(uv.x * 10.0 + t * 0.6) * 0.002
	);
	vec2 uv_d = uv + wobble;

	// Richer base with blue-purple gradient
	float depth_noise = fbm(uv_d * 3.0 + vec2(t * 0.02, t * 0.015));
	vec4 base = mix(deep_color, deep_color * 1.6, depth_noise * 0.6);
	// Add purple-blue depth variation
	float depth_grad = smoothstep(0.0, 1.0, uv.y);
	base.rgb += vec3(0.03, 0.01, 0.06) * depth_grad;

	// Chromatic bioluminescent shimmer bands (softened to avoid visible lines)
	float shimmer1 = sin(uv_d.x * 12.0 + uv_d.y * 6.0 + t * 0.5) * 0.5 + 0.5;
	float shimmer2 = sin(uv_d.x * 7.0 - uv_d.y * 9.0 + t * 0.7) * 0.5 + 0.5;
	// Use smoothstep instead of pow for softer transitions
	shimmer1 = smoothstep(0.6, 1.0, shimmer1) * 0.06;
	shimmer2 = smoothstep(0.6, 1.0, shimmer2) * 0.05;
	base.rgb += vec3(0.1, 0.3, 0.7) * shimmer1;  // Blue shimmer
	base.rgb += vec3(0.5, 0.1, 0.6) * shimmer2;  // Purple shimmer

	// Volcanic vent glow (brighter, warmer)
	float vent_dist = length(vec2(uv.x - 0.5, uv.y - 0.85));
	float vent_noise = fbm(vec2(uv.x * 5.0 + t * 0.1, uv.y * 8.0 - t * 0.3));
	float vent_glow = smoothstep(0.45, 0.0, vent_dist) * (0.5 + vent_noise * 0.5);
	base = mix(base, vent_color * 1.5, vent_glow);

	// Secondary vent (teal-green)
	float vent2_dist = length(vec2(uv.x - 0.25, uv.y - 0.9));
	float vent2_glow = smoothstep(0.35, 0.0, vent2_dist) * 0.3;
	base = mix(base, vec4(0.05, 0.2, 0.15, 1.0), vent2_glow);

	// Third vent (pink-magenta, top area)
	float vent3_dist = length(vec2(uv.x - 0.75, uv.y - 0.15));
	float vent3_noise = fbm(vec2(uv.x * 6.0 - t * 0.08, uv.y * 4.0 + t * 0.2));
	float vent3_glow = smoothstep(0.3, 0.0, vent3_dist) * (0.15 + vent3_noise * 0.15);
	base.rgb += vec3(0.3, 0.05, 0.2) * vent3_glow;

	// Simplified floating particles (reduced from 14 to 5 for performance)
	float particles = 0.0;
	vec3 particle_tint = vec3(0.0);
	for (int i = 0; i < 5; i++) {
		vec2 p_offset = vec2(hash(vec2(float(i), 0.0)), hash(vec2(0.0, float(i))));
		vec2 p_pos = fract(uv_d * (2.0 + float(i) * 0.8) + p_offset + vec2(t * 0.02 * (float(i) - 2.0), -t * 0.03));
		float p_bright = smoothstep(0.008, 0.0, length(p_pos - vec2(0.5, 0.5)));
		particles += p_bright * 0.25;
		vec3 p_col = mix(vec3(0.2, 0.8, 1.0), vec3(0.3, 1.0, 0.5), float(i) * 0.2);
		particle_tint += p_col * p_bright * 0.15;
	}
	base.rgb += particle_color.rgb * particles + particle_tint;

	// Simplified caustics (single layer for performance)
	float caustics = fbm(uv_d * 7.0 + vec2(t * 0.05, -t * 0.03));
	caustics = smoothstep(0.35, 0.7, caustics) * 0.12;
	base.rgb += vec3(0.12, 0.28, 0.45) * caustics;

	// Vignette (extra soft edges to avoid visible boundaries)
	float vignette_dist = length(uv - vec2(0.5));
	float vignette = smoothstep(0.9, 0.15, vignette_dist);
	// Secondary softer vignette layer for smoother falloff
	float vignette2 = smoothstep(1.0, 0.3, vignette_dist);
	float combined_vignette = vignette * 0.7 + vignette2 * 0.3;
	base.rgb *= 0.5 + combined_vignette * 0.6;

	COLOR = base;
}

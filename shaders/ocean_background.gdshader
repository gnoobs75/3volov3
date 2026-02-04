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

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		val += amp * noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
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

	// Chromatic bioluminescent shimmer bands
	float shimmer1 = sin(uv_d.x * 15.0 + uv_d.y * 8.0 + t * 0.5) * 0.5 + 0.5;
	float shimmer2 = sin(uv_d.x * 8.0 - uv_d.y * 12.0 + t * 0.7) * 0.5 + 0.5;
	shimmer1 = pow(shimmer1, 8.0) * 0.08;
	shimmer2 = pow(shimmer2, 8.0) * 0.06;
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

	// Floating bioluminescent particles (more, brighter, colorful)
	float particles = 0.0;
	vec3 particle_tint = vec3(0.0);
	for (int i = 0; i < 14; i++) {
		vec2 p_offset = vec2(hash(vec2(float(i), 0.0)), hash(vec2(0.0, float(i))));
		vec2 p_pos = fract(uv_d * (2.0 + float(i) * 0.4) + p_offset + vec2(t * 0.012 * (float(i) - 7.0), -t * 0.025));
		float p_size = 0.006 + 0.004 * hash(vec2(float(i), 1.0));
		float p_bright = smoothstep(p_size, 0.0, length(p_pos - vec2(0.5, 0.5)));
		particles += p_bright * 0.2;
		// Vary color: cyan, green, pink
		float hue = hash(vec2(float(i), 2.0));
		vec3 p_col = mix(vec3(0.2, 0.8, 1.0), mix(vec3(0.3, 1.0, 0.5), vec3(1.0, 0.4, 0.7), step(0.5, hue)), step(0.33, hue));
		particle_tint += p_col * p_bright * 0.12;
	}
	base.rgb += particle_color.rgb * particles + particle_tint;

	// Vibrant caustics (colored, brighter)
	float caustics = fbm(uv_d * 8.0 + vec2(t * 0.06, -t * 0.04));
	float caustics2 = fbm(uv_d * 12.0 + vec2(-t * 0.04, t * 0.05));
	caustics = pow(caustics, 2.5) * 0.2;
	caustics2 = pow(caustics2, 3.0) * 0.1;
	base.rgb += vec3(0.15, 0.3, 0.5) * caustics;
	base.rgb += vec3(0.1, 0.4, 0.3) * caustics2;

	// Vignette (softer, brighter center)
	float vignette = smoothstep(0.8, 0.25, length(uv - vec2(0.5)));
	base.rgb *= 0.45 + vignette * 0.65;

	COLOR = base;
}

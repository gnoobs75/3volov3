shader_type canvas_item;
// Microscope/petri dish view for the workstation intro.
// Shows a circular lens with grid overlay, floating microorganisms, and focus blur.

uniform float focus : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset : hint_range(0.0, 100.0) = 0.0;

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

void fragment() {
	float t = TIME + time_offset;
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	float dist_from_center = length(uv - center);

	// Circular lens mask
	float lens_radius = 0.42;
	float lens_edge = smoothstep(lens_radius, lens_radius - 0.02, dist_from_center);

	// Petri dish background (warm amber fluid)
	vec3 fluid = vec3(0.08, 0.06, 0.03);
	float fluid_noise = noise(uv * 6.0 + vec2(t * 0.02, t * 0.01));
	fluid += vec3(0.04, 0.03, 0.01) * fluid_noise;

	// Floating micro-organisms (procedural blobs)
	float organisms = 0.0;
	for (int i = 0; i < 12; i++) {
		float fi = float(i);
		vec2 org_center = vec2(
			0.5 + 0.3 * sin(t * 0.1 * (fi * 0.3 + 1.0) + fi * 2.1),
			0.5 + 0.3 * cos(t * 0.08 * (fi * 0.4 + 1.0) + fi * 1.7)
		);
		float org_size = 0.01 + 0.008 * hash(vec2(fi, 0.0));
		float org_dist = length(uv - org_center);
		float org_shape = smoothstep(org_size, org_size * 0.3, org_dist);
		organisms += org_shape * (0.5 + 0.5 * hash(vec2(fi, 1.0)));
	}
	// Organisms are greenish, visibility scales with focus
	vec3 org_color = vec3(0.15, 0.6, 0.25) * organisms * mix(0.15, 1.0, focus);
	fluid += org_color;

	// Central featured cell (larger, more visible)
	vec2 main_cell = center + vec2(sin(t * 0.05) * 0.02, cos(t * 0.04) * 0.015);
	float main_dist = length(uv - main_cell);
	float cell_body = smoothstep(0.035, 0.01, main_dist);
	float cell_membrane = smoothstep(0.04, 0.035, main_dist) - smoothstep(0.035, 0.03, main_dist);
	vec3 cell_col = vec3(0.1, 0.8, 0.35) * cell_body * mix(0.2, 1.2, focus);
	cell_col += vec3(0.2, 0.9, 0.4) * cell_membrane * mix(0.1, 0.8, focus);
	fluid += cell_col;

	// Grid overlay (microscope reticle)
	float grid_spacing = 0.1;
	vec2 grid_uv = fract(uv / grid_spacing);
	float grid_line = step(0.98, grid_uv.x) + step(0.98, grid_uv.y);
	grid_line = min(grid_line, 1.0);
	fluid += vec3(0.15, 0.2, 0.15) * grid_line * 0.15 * focus;

	// Cross-hair at center
	float ch_h = step(abs(uv.y - 0.5), 0.001) * step(abs(uv.x - 0.5), 0.05);
	float ch_v = step(abs(uv.x - 0.5), 0.001) * step(abs(uv.y - 0.5), 0.05);
	fluid += vec3(0.2, 0.4, 0.2) * (ch_h + ch_v) * 0.3 * focus;

	// Lens chromatic aberration at edges
	float aberration = dist_from_center * 0.02 * (1.0 - focus * 0.5);
	vec3 final_col = fluid;
	final_col.r = fluid.r + aberration * 0.5;
	final_col.b = fluid.b - aberration * 0.3;

	// Dark ring around lens edge
	float ring = smoothstep(lens_radius - 0.01, lens_radius - 0.03, dist_from_center)
				- smoothstep(lens_radius, lens_radius - 0.01, dist_from_center);
	final_col += vec3(0.05, 0.08, 0.05) * ring;

	// Outside lens is dark (microscope body)
	vec3 outside = vec3(0.02, 0.02, 0.03);
	final_col = mix(outside, final_col, lens_edge);

	// Blur effect (reduced sharpness when unfocused) -- simple box blur approximation
	float blur = (1.0 - focus) * 0.008;
	if (blur > 0.001) {
		vec3 blurred = vec3(0.0);
		float total = 0.0;
		for (int x = -2; x <= 2; x++) {
			for (int y = -2; y <= 2; y++) {
				vec2 offset = vec2(float(x), float(y)) * blur;
				float w = 1.0 / (1.0 + float(x*x + y*y));
				// We approximate -- just darken/brighten based on noise at offset
				float n = noise((uv + offset) * 10.0);
				blurred += final_col * (0.8 + 0.4 * n) * w;
				total += w;
			}
		}
		final_col = blurred / total;
	}

	COLOR = vec4(final_col, 1.0);
}

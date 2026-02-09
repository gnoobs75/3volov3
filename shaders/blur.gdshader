shader_type canvas_item;
// Separable Gaussian blur for microscope focus effect.
// Uses two 1D passes (horizontal + vertical) in a single shader invocation.
// Worst case: 2*radius*2+1 = 17 samples vs 81 for the old nested 2D kernel.

uniform float blur_amount : hint_range(0.0, 10.0) = 5.0;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	int radius = min(int(blur_amount), 4);
	float sigma = max(blur_amount * 0.5, 0.5);
	float inv2s2 = 1.0 / (2.0 * sigma * sigma);
	float step_scale = max(blur_amount / max(float(radius), 1.0), 1.0);

	// Horizontal pass
	vec4 h_color = vec4(0.0);
	float h_weight = 0.0;
	for (int x = -radius; x <= radius; x++) {
		float fx = float(x) * step_scale;
		float w = exp(-(fx * fx) * inv2s2);
		h_color += texture(TEXTURE, UV + vec2(fx, 0.0) * ps) * w;
		h_weight += w;
	}
	h_color /= h_weight;

	// Vertical pass
	vec4 v_color = vec4(0.0);
	float v_weight = 0.0;
	for (int y = -radius; y <= radius; y++) {
		float fy = float(y) * step_scale;
		float w = exp(-(fy * fy) * inv2s2);
		v_color += texture(TEXTURE, UV + vec2(0.0, fy) * ps) * w;
		v_weight += w;
	}
	v_color /= v_weight;

	// Average both passes (approximation of true separable blur)
	COLOR = (h_color + v_color) * 0.5;
}

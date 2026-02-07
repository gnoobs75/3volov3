shader_type canvas_item;
// Gaussian blur for microscope focus effect.
// Controlled by 'blur_amount' uniform (0.0 = sharp, 10.0 = very blurry).
// Capped at 9x9=81 samples with scaled step size for consistent coverage.

uniform float blur_amount : hint_range(0.0, 10.0) = 5.0;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec4 color = vec4(0.0);
	float tw = 0.0;
	int radius = min(int(blur_amount), 4);
	float sigma = max(blur_amount * 0.5, 0.5);
	float inv2s2 = 1.0 / (2.0 * sigma * sigma);
	float step_scale = max(blur_amount / max(float(radius), 1.0), 1.0);

	for (int x = -radius; x <= radius; x++) {
		for (int y = -radius; y <= radius; y++) {
			float fx = float(x) * step_scale;
			float fy = float(y) * step_scale;
			float w = exp(-(fx * fx + fy * fy) * inv2s2);
			color += texture(TEXTURE, UV + vec2(fx, fy) * ps) * w;
			tw += w;
		}
	}
	COLOR = color / tw;
}

shader_type canvas_item;
// Gaussian blur for microscope focus effect.
// Controlled by 'blur_amount' uniform (0.0 = sharp, 10.0 = very blurry).

uniform float blur_amount : hint_range(0.0, 10.0) = 5.0;

void fragment() {
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;
	vec4 color = vec4(0.0);
	float total_weight = 0.0;
	int samples = int(blur_amount * 2.0) + 1;

	for (int x = -samples; x <= samples; x++) {
		for (int y = -samples; y <= samples; y++) {
			float weight = exp(-float(x * x + y * y) / (2.0 * blur_amount * blur_amount + 0.001));
			color += texture(TEXTURE, UV + vec2(float(x), float(y)) * pixel_size * blur_amount) * weight;
			total_weight += weight;
		}
	}
	COLOR = color / total_weight;
}

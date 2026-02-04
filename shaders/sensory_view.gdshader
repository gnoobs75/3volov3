shader_type canvas_item;

// Simple sensory shader: grayscale→color + fog of war radius
uniform float visibility_range : hint_range(0.1, 1.0) = 0.3;
uniform float color_perception : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 scene_color = texture(SCREEN_TEXTURE, SCREEN_UV);

	// Distance from center (player is always screen center)
	vec2 diff = SCREEN_UV - vec2(0.5);
	float aspect = SCREEN_SIZE.x / SCREEN_SIZE.y;
	diff.x *= aspect;
	float dist = length(diff);

	// Fog of war: visible inside radius, dark outside, soft edge
	float vis_radius = visibility_range * 0.55;
	float edge_width = vis_radius * 0.4;
	float fog = smoothstep(vis_radius + edge_width, vis_radius - edge_width * 0.2, dist);

	// Grayscale
	float luma = dot(scene_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 final_color = mix(vec3(luma), scene_color.rgb, color_perception);

	// Apply fog
	vec3 fog_color = vec3(0.01, 0.02, 0.04);
	final_color = mix(fog_color, final_color, fog);

	COLOR = vec4(final_color, 1.0);
}

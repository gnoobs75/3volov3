shader_type canvas_item;
// Holographic HUD panel shader -- scanlines, edge glow, slight transparency.

uniform vec4 holo_color : source_color = vec4(0.1, 0.7, 0.9, 0.85);
uniform float scanline_density : hint_range(0.0, 500.0) = 200.0;
uniform float edge_glow : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;

	// Scanline effect
	float scanline = sin(UV.y * scanline_density + TIME * 2.0) * 0.5 + 0.5;
	scanline = 0.85 + scanline * 0.15;
	base.rgb *= scanline;

	// Holographic tint
	base.rgb = mix(base.rgb, holo_color.rgb, 0.15);

	// Edge glow: brighter at edges of UV
	float edge_x = min(UV.x, 1.0 - UV.x);
	float edge_y = min(UV.y, 1.0 - UV.y);
	float edge = smoothstep(0.0, 0.05, min(edge_x, edge_y));
	base.rgb += holo_color.rgb * (1.0 - edge) * edge_glow;

	// Subtle flicker
	float flicker = 0.97 + 0.03 * sin(TIME * 15.0);
	base.rgb *= flicker;

	base.a *= holo_color.a;
	COLOR = base;
}

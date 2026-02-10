shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Cave floor organic tissue shader — same as wall shader but with cull_back
// for upward-facing floor geometry.

uniform vec4 base_color : source_color = vec4(0.05, 0.07, 0.02, 1.0);
uniform vec4 vein_color : source_color = vec4(0.3, 0.08, 0.12, 1.0);
uniform vec4 emission_color : source_color = vec4(0.3, 0.5, 0.1, 1.0);
uniform float emission_strength : hint_range(0.0, 2.0) = 0.25;
uniform float vein_scale : hint_range(1.0, 20.0) = 8.0;
uniform float vein_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.2;
uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.3;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.85;
uniform float moisture : hint_range(0.0, 1.0) = 0.3;
uniform float texture_blend : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float texture_scale : hint_range(0.01, 1.0) = 0.1;

vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

float voronoi_veins(vec2 uv) {
    vec2 g = floor(uv);
    vec2 f = fract(uv);
    float d1 = 1.0;
    float d2 = 1.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash22(g + neighbor);
            vec2 diff = neighbor + point - f;
            float d = length(diff);
            if (d < d1) {
                d2 = d1;
                d1 = d;
            } else if (d < d2) {
                d2 = d;
            }
        }
    }
    return d2 - d1;
}

float simplex_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = dot(hash22(i), vec2(1.0));
    float b = dot(hash22(i + vec2(1.0, 0.0)), vec2(1.0));
    float c = dot(hash22(i + vec2(0.0, 1.0)), vec2(1.0));
    float d = dot(hash22(i + vec2(1.0, 1.0)), vec2(1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = VERTEX.xz * 0.1;

    float veins_large = voronoi_veins(uv * vein_scale * 0.5);
    float veins_small = voronoi_veins(uv * vein_scale);
    float veins_detail = voronoi_veins(uv * vein_scale * 2.0);

    float vein_pattern = smoothstep(0.0, 0.12, veins_large) * 0.5;
    vein_pattern += smoothstep(0.0, 0.08, veins_small) * 0.35;
    vein_pattern += smoothstep(0.0, 0.05, veins_detail) * 0.15;
    vein_pattern = 1.0 - vein_pattern;

    float pulse_phase = TIME * pulse_speed;
    float pulse_wave = sin(pulse_phase + uv.x * 3.0 + uv.y * 2.0) * 0.5 + 0.5;
    float pulse_secondary = sin(pulse_phase * 0.7 + uv.y * 5.0) * 0.5 + 0.5;
    float pulse = mix(pulse_wave, pulse_secondary, 0.3);

    float vein_glow = (1.0 - vein_pattern) * vein_intensity * pulse;

    float surface_noise = simplex_noise(uv * 15.0) * 0.3
                        + simplex_noise(uv * 30.0) * 0.15;

    vec3 albedo = base_color.rgb;
    albedo += surface_noise * 0.05;

    if (texture_blend > 0.001) {
        vec2 tex_uv = uv / texture_scale;
        vec3 tex_color = texture(surface_texture, tex_uv).rgb;
        tex_color = mix(tex_color, base_color.rgb, 0.5);
        albedo = mix(albedo, tex_color, texture_blend);
    }

    albedo = mix(albedo, vein_color.rgb, vein_glow * 0.6);
    ALBEDO = albedo;

    float wet_veins = (1.0 - vein_pattern) * moisture;
    ROUGHNESS = roughness_base - wet_veins * 0.3;

    vec3 emit = emission_color.rgb * vein_glow * emission_strength;
    emit += emission_color.rgb * subsurface_strength * 0.1 * (0.8 + pulse * 0.2);
    EMISSION = emit;

    BACKLIGHT = emission_color.rgb * subsurface_strength * (0.5 + pulse * 0.5);

    float vein_normal_strength = (1.0 - vein_pattern) * 0.15;
    float dx = voronoi_veins((uv + vec2(0.001, 0.0)) * vein_scale) - veins_small;
    float dy = voronoi_veins((uv + vec2(0.0, 0.001)) * vein_scale) - veins_small;
    vec3 perturbed_normal = normalize(vec3(dx * vein_normal_strength * 50.0, dy * vein_normal_strength * 50.0, 1.0));
    NORMAL_MAP = perturbed_normal * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 1.0;
}

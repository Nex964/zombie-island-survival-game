shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, specular_schlick_ggx;

/* ---------- Colors ---------- */
uniform vec4 deep_color    : source_color = vec4(0.02, 0.20, 0.30, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.10, 0.65, 0.75, 1.0);
uniform float shallow_bias : hint_range(0.0, 2.0) = 0.55;
uniform float alpha        : hint_range(0.0, 1.0) = 0.85;

/* ---------- Normal Maps ---------- */
uniform sampler2D normal_map_1 : source_color, hint_normal;
uniform sampler2D normal_map_2 : source_color, hint_normal;
uniform float normal_strength : hint_range(0.0, 4.0) = 1.25;
uniform float normal_scale    : hint_range(0.05, 8.0) = 1.6;
uniform vec2  flow1 = vec2( 0.03,  0.02);
uniform vec2  flow2 = vec2(-0.02,  0.015);

/* ---------- Foam ---------- */
uniform sampler2D foam_tex : source_color;
uniform float foam_intensity : hint_range(0.0, 3.0) = 1.15;
uniform float foam_scale     : hint_range(0.5, 20.0) = 6.0;
uniform float foam_speed     : hint_range(0.0, 2.0) = 0.25;
uniform float foam_crest_threshold : hint_range(0.0, 2.0) = 0.55;

/* ---------- Caustics ---------- */
uniform sampler2D caustics_tex : source_color;
uniform float caustics_scale    : hint_range(0.5, 20.0) = 8.0;
uniform float caustics_speed    : hint_range(0.0, 4.0) = 1.2;
uniform float caustics_strength : hint_range(0.0, 2.0) = 0.3;

/* ---------- Fresnel ---------- */
uniform float fresnel_power : hint_range(1.0, 8.0) = 4.5;
uniform float fresnel_boost : hint_range(0.0, 1.0) = 0.18;


uniform float roughness : hint_range(0.0, 1.0) = 0.4;
uniform float specular : hint_range(0.0, 1.0) = 0.2;

/* ---------- Waves ---------- */
uniform float wave_amp  : hint_range(0.0, 2.0) = 0.35;
uniform float wave_len  : hint_range(0.5, 32.0) = 7.5;
uniform float wave_speed: hint_range(0.1, 4.0) = 1.2;
uniform vec2 wave_dir0 = vec2(1.0, 0.2);
uniform vec2 wave_dir1 = vec2(-0.3, 1.0);
uniform vec2 wave_dir2 = vec2(0.7, 0.7);

/* ---------- Underwater ---------- */
uniform float water_level = 0.0;
uniform vec4 underwater_tint : source_color = vec4(0.02, 0.08, 0.10, 1.0);
uniform float underwater_strength : hint_range(0.0, 1.0) = 0.35;

//const float PI = 3.14159265;

/* ========== WAVE / GERSTNER HELPERS ========== */

void apply_wave(inout vec3 p, vec2 dir, float amp, float k, float w, float t, vec2 world, out float crest) {
    dir = normalize(dir);
    float phase = k * dot(dir, world) + w * t;
    float s = sin(phase);
    float c = cos(phase);

    p.x += amp * dir.x * c;
    p.z += amp * dir.y * c;
    p.y += amp * s;

    crest += abs(c);
}

/* ========== VERTEX ========== */
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec2 xz = world.xz;

    float k = 2.0 * PI / max(wave_len, 0.01);
    float w = sqrt(9.8 * k) * wave_speed;

    vec3 p = VERTEX;
    float crest = 0.0;

    float a = wave_amp / 3.0;

    apply_wave(p, wave_dir0, a, k, w, TIME, xz, crest);
    apply_wave(p, wave_dir1, a, k, w * 1.1, TIME, xz, crest);
    apply_wave(p, wave_dir2, a, k * 1.2, w * 0.9, TIME, xz, crest);

    VERTEX = p;
    COLOR.a = clamp(crest / 3.0, 0.0, 1.0);
}

/* ========== FRAGMENT ========== */
void fragment() {

    /* Normal */
    vec2 uv1 = UV * normal_scale + flow1 * TIME;
    vec2 uv2 = UV * normal_scale * 1.3 + flow2 * TIME;

    vec3 n1 = texture(normal_map_1, uv1).xyz * 2.0 - 1.0;
    vec3 n2 = texture(normal_map_2, uv2).xyz * 2.0 - 1.0;

    vec3 n = normalize(n1 + n2);
    n.xy *= normal_strength;
    NORMAL_MAP = normalize(n);


    /* Fake depth fade using NORMAL.y */
    float up = clamp(NORMAL.y, 0.0, 1.0);
    float shallow = pow(up, 1.6) * shallow_bias;

    /* Base color */
    vec3 col = mix(deep_color.rgb, shallow_color.rgb, shallow);

    /* Fresnel */
    float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power) + fresnel_boost;
    fres = clamp(fres, 0.0, 1.0);


    /* Foam */
    float crest = COLOR.a;
    float crest_mask = smoothstep(foam_crest_threshold, 1.0, crest);

    float foam_val = texture(foam_tex, UV * foam_scale + foam_speed * TIME).r;
    float foam_mask = max(crest_mask, foam_val * 0.3);

    col = mix(col, vec3(1.0), foam_mask * foam_intensity * 0.5);


    /* Caustics */
    float c = texture(caustics_tex, UV * caustics_scale + TIME * caustics_speed).r;
    c = pow(c, 2.0);
    col += c * caustics_strength * (1.0 - fres);


    /* Fake refraction → color shift based on normal */
    float refract_shift = 1.0 + clamp(n.x + n.y, -1.0, 1.0) * 0.05;
	col *= refract_shift;

    /* Underwater */
    vec3 camera_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

	if (camera_pos.y < water_level) {
	    col = mix(col, underwater_tint.rgb, underwater_strength);
	}



    ALBEDO = col;
    ALPHA = alpha;

    ROUGHNESS = mix(roughness, 0.1, fres);
    SPECULAR = specular;
}

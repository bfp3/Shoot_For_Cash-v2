// Lightweight wavy water — vertex displacement only.
// No Gerstner arrays, refraction, foam, depth fog, or multi-LOD ocean rings.

shader_type spatial;

render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

group_uniforms Surface;
uniform vec4 albedo : source_color = vec4(0.02, 0.35, 0.72, 0.72);
uniform vec4 albedo_highlight : source_color = vec4(0.45, 0.75, 0.95, 0.85);
uniform float roughness : hint_range(0.0, 1.0) = 0.18;
uniform float specular : hint_range(0.0, 1.0) = 0.55;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.8;
group_uniforms;

group_uniforms Waves;
uniform float wave_height : hint_range(0.0, 4.0) = 0.45;
uniform float wave_speed : hint_range(0.0, 4.0) = 1.0;
// World-space tiling of the main ripple. Lower = longer waves.
uniform float wave_scale : hint_range(0.005, 0.5) = 0.045;
uniform float wave_secondary : hint_range(0.0, 1.0) = 0.55;
uniform float wave_tertiary : hint_range(0.0, 1.0) = 0.28;
uniform bool freeze_time = false;
group_uniforms;


float _wave(vec2 p, float t, vec2 dir, float freq, float speed, float phase) {
	return sin(dot(p, normalize(dir)) * freq + t * speed + phase);
}


void vertex() {
	float t = TIME * wave_speed * float(!freeze_time);
	vec2 p = VERTEX.xz;

	float f1 = TAU * wave_scale;
	float f2 = TAU * wave_scale * 1.7;
	float f3 = TAU * wave_scale * 3.1;

	float w1 = _wave(p, t, vec2(1.0, 0.25), f1, 1.0, 0.0);
	float w2 = _wave(p, t, vec2(-0.35, 1.0), f2, 1.35, 1.7);
	float w3 = _wave(p, t, vec2(0.8, 0.7), f3, 0.75, 4.2);

	float h = (w1 + w2 * wave_secondary + w3 * wave_tertiary) * wave_height;
	VERTEX.y += h;

	// Cheap normal from neighbouring samples (keeps lighting waving).
	float e = 0.35;
	float hx = (
		_wave(p + vec2(e, 0.0), t, vec2(1.0, 0.25), f1, 1.0, 0.0)
		+ _wave(p + vec2(e, 0.0), t, vec2(-0.35, 1.0), f2, 1.35, 1.7) * wave_secondary
		+ _wave(p + vec2(e, 0.0), t, vec2(0.8, 0.7), f3, 0.75, 4.2) * wave_tertiary
		- (
			_wave(p - vec2(e, 0.0), t, vec2(1.0, 0.25), f1, 1.0, 0.0)
			+ _wave(p - vec2(e, 0.0), t, vec2(-0.35, 1.0), f2, 1.35, 1.7) * wave_secondary
			+ _wave(p - vec2(e, 0.0), t, vec2(0.8, 0.7), f3, 0.75, 4.2) * wave_tertiary
		)
	) * wave_height;
	float hz = (
		_wave(p + vec2(0.0, e), t, vec2(1.0, 0.25), f1, 1.0, 0.0)
		+ _wave(p + vec2(0.0, e), t, vec2(-0.35, 1.0), f2, 1.35, 1.7) * wave_secondary
		+ _wave(p + vec2(0.0, e), t, vec2(0.8, 0.7), f3, 0.75, 4.2) * wave_tertiary
		- (
			_wave(p - vec2(0.0, e), t, vec2(1.0, 0.25), f1, 1.0, 0.0)
			+ _wave(p - vec2(0.0, e), t, vec2(-0.35, 1.0), f2, 1.35, 1.7) * wave_secondary
			+ _wave(p - vec2(0.0, e), t, vec2(0.8, 0.7), f3, 0.75, 4.2) * wave_tertiary
		)
	) * wave_height;

	NORMAL = normalize(vec3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)));
}


void fragment() {
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndotv, fresnel_power);

	ALBEDO = mix(albedo.rgb, albedo_highlight.rgb, fres);
	ALPHA = mix(albedo.a, albedo_highlight.a, fres * 0.35 + 0.65);
	ROUGHNESS = roughness;
	SPECULAR = specular;
	METALLIC = metallic;
}

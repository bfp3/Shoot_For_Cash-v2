shader_type spatial;

// Stylized water for illustrated layouts. Vertex waves from simple_water,
// lighting from the shared illustrated ramp (cool shadows, hard bands).

render_mode depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled, ambient_light_disabled, world_vertex_coords;

#include "res://res/Shaders/stylized_illustrated.gdshaderinc"

group_uniforms Look;
uniform vec4 sty_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float sty_shadow_strength : hint_range(0.0, 1.0) = 1.0;
uniform float sty_shadow_threshold : hint_range(0.0, 1.0) = 0.22;
uniform vec4 sty_mid_color : source_color = vec4(0.42, 0.4, 0.4, 1.0);
uniform float sty_mid_threshold : hint_range(0.0, 1.0) = 0.4;
uniform vec4 sty_light_color : source_color = vec4(1.0, 0.94, 0.82, 1.0);
uniform float sty_light_strength : hint_range(0.0, 1.0) = 1.0;
uniform float sty_light_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float sty_band_softness : hint_range(0.0, 0.2) = 0.01;
uniform float sty_saturation : hint_range(0.0, 1.5) = 0.92;
uniform float sty_contrast : hint_range(0.5, 1.8) = 1.08;
uniform vec4 sty_fog_color : source_color = vec4(0.45, 0.62, 0.78, 1.0);
uniform float sty_fog_strength : hint_range(0.0, 1.5) = 0.55;
uniform float sty_fog_start = 28.0;
uniform float sty_fog_end = 260.0;
group_uniforms;

group_uniforms Surface;
uniform vec4 albedo : source_color = vec4(0.12, 0.31, 0.48, 1.0);
uniform vec4 albedo_highlight : source_color = vec4(0.42, 0.62, 0.78, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.92;
uniform float specular : hint_range(0.0, 1.0) = 0.04;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.2;
group_uniforms;

group_uniforms Waves;
uniform float wave_height : hint_range(0.0, 4.0) = 0.18;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.22;
uniform float wave_scale : hint_range(0.005, 0.5) = 0.04;
uniform float wave_secondary : hint_range(0.0, 1.0) = 0.45;
uniform float wave_tertiary : hint_range(0.0, 1.0) = 0.22;
uniform bool freeze_time = false;
group_uniforms;

varying vec3 v_world_pos;


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
	VERTEX.y += (w1 + w2 * wave_secondary + w3 * wave_tertiary) * wave_height;
	v_world_pos = VERTEX;
}


void fragment() {
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndotv, fresnel_power);
	vec3 base = mix(albedo.rgb, albedo_highlight.rgb, fres * 0.45);
	base = sty_apply_sat_contrast(base, sty_saturation, sty_contrast);
	base = sty_air_perspective(
			base,
			v_world_pos,
			INV_VIEW_MATRIX[3].xyz,
			sty_fog_color.rgb,
			sty_fog_strength,
			sty_fog_start,
			sty_fog_end
	);
	ALBEDO = base;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	METALLIC = 0.0;
}


void light() {
	float ndotl = dot(normalize(NORMAL), normalize(LIGHT));
	float shade = max(ndotl, 0.0);
	if (ATTENUATION < 0.35) {
		shade = 0.0;
	}
	vec3 remapped;
	if (LIGHT_IS_DIRECTIONAL) {
		remapped = sty_remap_lit(
				ALBEDO,
				sty_band(shade, sty_shadow_threshold, sty_light_threshold, sty_band_softness),
				sty_shadow_color.rgb,
				sty_shadow_strength,
				sty_mid_color.rgb,
				sty_light_color.rgb,
				sty_light_strength
		);
	} else {
		remapped = ALBEDO * LIGHT_COLOR * ATTENUATION * max(ndotl, 0.0) * 0.1;
	}
	DIFFUSE_LIGHT += remapped / max(ALBEDO, vec3(0.04));
	SPECULAR_LIGHT = vec3(0.0);
}

shader_type spatial;

// Illustrated low-poly lighting: three hard bands (shadow / mid / light).
// Tune from the StylizedLook node. Per-material: albedo, texture, flat shading.

render_mode cull_back, diffuse_lambert, specular_disabled, ambient_light_disabled;

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
uniform vec4 albedo_color : source_color = vec4(0.91, 0.84, 0.72, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_albedo_texture = false;
uniform float texture_blend : hint_range(0.0, 1.0) = 0.25;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;
uniform float specular_value : hint_range(0.0, 1.0) = 0.0;
uniform bool use_flat_shading = true;
group_uniforms;

varying vec3 v_world_pos;


void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	if (use_flat_shading) {
		vec3 flat_n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		if (dot(flat_n, NORMAL) < 0.0) {
			flat_n = -flat_n;
		}
		NORMAL = flat_n;
	}

	vec3 base = albedo_color.rgb;
	if (use_albedo_texture) {
		vec3 tex = texture(albedo_texture, UV).rgb;
		base = mix(base, base * tex, texture_blend);
	}
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
	ROUGHNESS = clamp(roughness_value, 0.6, 1.0);
	SPECULAR = specular_value;
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
		remapped = ALBEDO * LIGHT_COLOR * ATTENUATION * max(ndotl, 0.0) * 0.12;
	}
	DIFFUSE_LIGHT += remapped / max(ALBEDO, vec3(0.04));
	SPECULAR_LIGHT = vec3(0.0);
}

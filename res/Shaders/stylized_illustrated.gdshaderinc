// Shared illustrated lighting helpers.
// Look uniforms are declared on each .gdshader that includes this file.

float sty_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}


vec3 sty_apply_sat_contrast(vec3 c, float saturation, float contrast) {
	float l = sty_luma(c);
	vec3 sat = mix(vec3(l), c, saturation);
	return clamp(mix(vec3(0.5), sat, contrast), 0.0, 1.5);
}


// shade is NdotL * shadow attenuation (0 = no light, 1 = facing the sun).
// Returns 0 = shadow, 0.5 = mid, 1 = light.
// Only two cuts matter: shadow_th (leave black) and light_th (enter light colour).
float sty_band(float shade, float shadow_th, float light_th, float softness) {
	float s = clamp(shade, 0.0, 1.0);
	float lo = min(shadow_th, light_th);
	float hi = max(shadow_th, light_th);
	if (hi - lo < 0.02) {
		hi = clamp(lo + 0.02, 0.0, 1.0);
	}
	float soft = max(softness, 0.0008);
	float to_mid = smoothstep(lo - soft, lo + soft, s);
	float to_light = smoothstep(hi - soft, hi + soft, s);
	return to_mid * 0.5 + to_light * 0.5;
}


vec3 sty_air_perspective(
		vec3 base,
		vec3 world_pos,
		vec3 camera_pos,
		vec3 fog_rgb,
		float fog_strength,
		float fog_start,
		float fog_end
) {
	float dist = distance(world_pos, camera_pos);
	float span = max(fog_end - fog_start, 1.0);
	float t = clamp((dist - fog_start) / span, 0.0, 1.0);
	t = pow(t, 0.82) * clamp(fog_strength, 0.0, 1.5);
	vec3 aerial = mix(base, fog_rgb, t);
	float desat = mix(1.0, 0.35, t);
	float l = sty_luma(aerial);
	return mix(vec3(l), aerial, desat);
}


vec3 sty_remap_lit(
		vec3 base,
		float band,
		vec3 shadow_rgb,
		float shadow_str,
		vec3 mid_rgb,
		vec3 light_rgb,
		float light_str
) {
	vec3 c_shadow = mix(base * vec3(0.04), shadow_rgb, clamp(shadow_str, 0.0, 1.0));
	vec3 c_mid = mix(base, mid_rgb, 0.85);
	vec3 c_light = mix(base, light_rgb, clamp(light_str, 0.0, 1.0));
	float b = clamp(band, 0.0, 1.0);
	vec3 low = mix(c_shadow, c_mid, smoothstep(0.0, 0.5, b));
	return mix(low, c_light, smoothstep(0.5, 1.0, b));
}

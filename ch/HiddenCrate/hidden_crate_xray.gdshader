shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(0.7, 0.5105334, 0.294, 1.0);
uniform vec2 xray_center_px = vec2(0.0);
uniform float xray_radius_px = 0.0;
uniform float xray_softness_px = 12.0;
uniform float emission_mul : hint_range(0.0, 4.0) = 0.45;
uniform vec4 emission_color : source_color = vec4(1.0, 0.6166667, 0.0, 1.0);

void fragment() {
	float dist = distance(SCREEN_UV * VIEWPORT_SIZE, xray_center_px);
	float inner = max(xray_radius_px - xray_softness_px, 0.0);
	float mask = 1.0 - smoothstep(inner, max(xray_radius_px, 0.001), dist);
	if (mask < 0.01) {
		discard;
	}

	vec4 col = texture(albedo_tex, UV) * albedo_tint;
	ALBEDO = col.rgb;
	ROUGHNESS = 0.78;
	ALPHA = mask;
	EMISSION = emission_color.rgb * emission_mul * mask;
}

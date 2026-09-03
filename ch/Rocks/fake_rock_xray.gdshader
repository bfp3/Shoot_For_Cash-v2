shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform float use_albedo_tex : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(0.52, 0.54, 0.58, 1.0);
uniform vec2 xray_center_px = vec2(0.0);
uniform float xray_radius_px = 0.0;
uniform float xray_softness_px = 12.0;
uniform float emission_mul : hint_range(0.0, 4.0) = 0.2;
uniform vec4 emission_color : source_color = vec4(0.52, 0.54, 0.58, 1.0);

void fragment() {
	float dist = distance(SCREEN_UV * VIEWPORT_SIZE, xray_center_px);
	float inner = max(xray_radius_px - xray_softness_px, 0.0);
	float mask = 1.0 - smoothstep(inner, max(xray_radius_px, 0.001), dist);
	if (mask < 0.01) {
		discard;
	}

	vec4 col = albedo_tint;
	if (use_albedo_tex > 0.5) {
		col *= texture(albedo_tex, UV);
	}
	ALBEDO = col.rgb;
	ROUGHNESS = 0.78;
	ALPHA = mask;
	EMISSION = emission_color.rgb * emission_mul * mask;
}

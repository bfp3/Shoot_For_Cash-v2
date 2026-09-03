shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

uniform float use_albedo_tex : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(0.7, 0.5105334, 0.294, 1.0);
uniform float use_triplanar : hint_range(0.0, 1.0) = 0.0;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.78;
uniform vec2 xray_center_px = vec2(0.0);
uniform float xray_radius_px = 0.0;
uniform float xray_softness_px = 12.0;
uniform float emission_mul : hint_range(0.0, 4.0) = 0.45;
uniform vec4 emission_color : source_color = vec4(1.0, 0.6166667, 0.0, 1.0);

vec4 triplanar_albedo(vec3 world_pos, vec3 world_n) {
	vec3 p = world_pos * uv1_scale + uv1_offset;
	vec3 b = abs(normalize(world_n));
	b /= max(b.x + b.y + b.z, 0.001);
	vec4 x = texture(albedo_tex, p.yz);
	vec4 y = texture(albedo_tex, p.xz);
	vec4 z = texture(albedo_tex, p.xy);
	return x * b.x + y * b.y + z * b.z;
}

void fragment() {
	float dist = distance(SCREEN_UV * VIEWPORT_SIZE, xray_center_px);
	float inner = max(xray_radius_px - xray_softness_px, 0.0);
	float mask = 1.0 - smoothstep(inner, max(xray_radius_px, 0.001), dist);
	if (mask < 0.01) {
		discard;
	}

	vec4 col = albedo_tint;
	if (use_albedo_tex > 0.5) {
		if (use_triplanar > 0.5) {
			vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
			vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
			col *= triplanar_albedo(world_pos, world_n);
		} else {
			col *= texture(albedo_tex, UV);
		}
	}
	ALBEDO = col.rgb;
	ROUGHNESS = surface_roughness;
	ALPHA = mask;
	EMISSION = emission_color.rgb * emission_mul * mask;
}

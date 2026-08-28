shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D tex_top : source_color, filter_nearest, repeat_enable;
uniform sampler2D tex_side : source_color, filter_nearest, repeat_enable;
uniform sampler2D tex_bottom : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 1.0;
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec3 v_n;

void vertex() {
	v_n = NORMAL;
}

void fragment() {
	vec3 n = abs(v_n);
	vec4 col;
	if (n.y >= n.x && n.y >= n.z) {
		col = v_n.y >= 0.0 ? texture(tex_top, UV) : texture(tex_bottom, UV);
	} else {
		col = texture(tex_side, UV);
	}
	if (col.a < 0.04) {
		discard;
	}
	ALBEDO = col.rgb * albedo_tint.rgb;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.0;
	EMISSION = emission_color.rgb * emission_energy;
	ALPHA = col.a;
}

shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D tex_leaves : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(0.55, 0.85, 0.4, 1.0);
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 col = texture(tex_leaves, UV);
	if (col.a < alpha_scissor) {
		discard;
	}
	ALBEDO = col.rgb * albedo_tint.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = 1.0;
}

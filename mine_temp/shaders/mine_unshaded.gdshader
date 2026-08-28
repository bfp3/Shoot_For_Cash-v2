shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.4;

uniform float emission_mul : hint_range(0.0, 8.0) = 0.0;

void fragment() {
	vec4 col = texture(albedo_tex, UV) * albedo_tint;
	if (col.a < alpha_scissor) {
		discard;
	}
	ALBEDO = col.rgb;
	ALPHA = col.a;
	EMISSION = col.rgb * emission_mul;
}

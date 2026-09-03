shader_type spatial;
render_mode unshaded, blend_mix, cull_back, shadows_disabled, specular_disabled, ambient_light_disabled, fog_disabled;

uniform vec4 face_color : source_color = vec4(0.03, 0.08, 0.16, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.72, 0.28, 1.0);
uniform float edge_thickness : hint_range(0.01, 12.0) = 1.8;
uniform float glow_amount : hint_range(0.0, 12.0) = 2.5;
uniform float edge_softness : hint_range(0.4, 4.0) = 1.2;

varying vec3 v_bary;

void vertex() {
	v_bary = COLOR.rgb;
}

float edge_mask(vec3 bary, float width_px) {
	vec3 fw = max(fwidth(bary), vec3(1.0e-5));
	vec3 start = fw * width_px;
	vec3 end = fw * (width_px + edge_softness);
	vec3 s = smoothstep(start, end, bary);
	return 1.0 - min(s.x, min(s.y, s.z));
}

void fragment() {
	float core = edge_mask(v_bary, edge_thickness);
	float halo = edge_mask(v_bary, edge_thickness * (2.4 + glow_amount * 0.35));
	halo = max(halo - core, 0.0);

	vec3 face = face_color.rgb;
	vec3 edge = edge_color.rgb;
	vec3 col = mix(face, edge, core);
	col += edge * halo * (0.18 + glow_amount * 0.08);

	ALBEDO = col;
	ALPHA = mix(face_color.a, 1.0, core);
	EMISSION = edge * glow_amount * (core + halo * 0.45);
}

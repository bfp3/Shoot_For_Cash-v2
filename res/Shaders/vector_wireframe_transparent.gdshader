shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled, specular_disabled, ambient_light_disabled, fog_disabled;

uniform vec4 face_color : source_color = vec4(0.03, 0.08, 0.16, 0.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.72, 0.28, 1.0);
uniform float edge_thickness : hint_range(0.01, 12.0) = 1.8;
uniform float glow_amount : hint_range(0.0, 60.0) = 2.5;
uniform float edge_softness : hint_range(0.4, 4.0) = 1.2;
uniform float line_gap_amount : hint_range(0.0, 1.0) = 0.85;
uniform float line_gap_spacing : hint_range(1.0, 24.0) = 4.0;
uniform float line_gap_size : hint_range(0.0, 12.0) = 1.4;
uniform float line_gap_softness : hint_range(0.0, 4.0) = 0.55;
uniform float line_gap_angle : hint_range(0.0, 180.0) = 0.0;
uniform float line_gap_offset : hint_range(0.0, 1.0) = 0.0;

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

float line_gap_mask(vec2 screen_uv, vec2 viewport_size) {
	if (line_gap_amount <= 0.001 || line_gap_size <= 0.001) {
		return 1.0;
	}
	float rad = radians(line_gap_angle);
	vec2 px = screen_uv * viewport_size;
	float axis = px.x * sin(rad) + px.y * cos(rad);
	float spacing = max(line_gap_spacing, 1.0);
	float t = mod(axis + line_gap_offset * spacing, spacing);
	float dist = min(t, spacing - t);
	float half_gap = line_gap_size * 0.5;
	float lit = smoothstep(half_gap, half_gap + max(line_gap_softness, 0.001), dist);
	return mix(1.0, lit, line_gap_amount);
}

void fragment() {
	float gaps = line_gap_mask(SCREEN_UV, VIEWPORT_SIZE);
	float core = edge_mask(v_bary, edge_thickness) * gaps;
	float halo = edge_mask(v_bary, edge_thickness * (2.4 + glow_amount * 0.35));
	halo = max(halo - core, 0.0) * gaps;

	float edge_a = clamp(core, 0.0, 1.0);
	float alpha = mix(face_color.a, 1.0, edge_a);
	if (alpha < 0.004) {
		discard;
	}

	vec3 face = face_color.rgb;
	vec3 edge = edge_color.rgb;
	vec3 col = mix(face, edge, core);
	col += edge * halo * 0.16;
	ALBEDO = col;
	ALPHA = alpha;
	float line = max(core, halo * 0.3);
	EMISSION = edge * line * (1.8 + glow_amount);
}

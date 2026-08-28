shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_lambert, specular_schlick_ggx, world_vertex_coords;

uniform sampler2D tex_water : source_color, filter_nearest, repeat_enable;
uniform vec4 shallow : source_color = vec4(0.18, 0.48, 0.92, 0.62);
uniform vec4 deep : source_color = vec4(0.05, 0.22, 0.55, 0.82);
uniform float wave_height : hint_range(0.0, 0.4) = 0.06;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.7;
uniform float pixel_scale : hint_range(1.0, 32.0) = 8.0;

varying vec3 v_world;

void vertex() {
	float t = TIME * wave_speed;
	float h = sin(VERTEX.x * 1.7 + t) * 0.45 + sin(VERTEX.z * 1.3 - t * 0.8) * 0.55;
	VERTEX.y += h * wave_height;
	v_world = VERTEX;
}

void fragment() {
	vec2 uv = floor(v_world.xz * pixel_scale) / pixel_scale;
	uv += vec2(TIME * 0.015, TIME * 0.01);
	vec4 tex = texture(tex_water, uv);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	vec3 col = mix(deep.rgb, shallow.rgb, tex.r * 0.55 + 0.25);
	col = mix(col, vec3(0.75, 0.9, 1.0), fres * 0.45);
	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.05;
	SPECULAR = 0.7;
	ALPHA = mix(deep.a, shallow.a, fres);
	EMISSION = col * 0.08;
}

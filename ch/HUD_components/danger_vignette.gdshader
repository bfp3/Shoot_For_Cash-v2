shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform vec4 vignette_color : source_color = vec4(0.72, 0.03, 0.02, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.85;
uniform float size : hint_range(0.05, 1.5) = 0.58;
uniform float softness : hint_range(0.01, 1.5) = 0.48;
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
uniform vec2 center_offset = vec2(0.0);
uniform float aberration : hint_range(0.0, 0.03) = 0.0024;
uniform float danger : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.00001);
	vec2 centered = uv - (vec2(0.5) + center_offset);
	centered.x *= aspect;
	float dist = length(centered) * 2.0;
	float vig = smoothstep(size, size + softness, dist) * intensity * danger;

	vec2 dir = centered;
	float dir_len = length(dir);
	if (dir_len > 0.0001) {
		dir /= dir_len;
	} else {
		dir = vec2(1.0, 0.0);
	}
	float ab = aberration * danger;
	vec3 screen;
	screen.r = texture(screen_texture, uv + dir * ab).r;
	screen.g = texture(screen_texture, uv).g;
	screen.b = texture(screen_texture, uv - dir * ab).b;

	vec3 edge = mix(screen, screen * vignette_color.rgb, vig * 0.72);
	edge = mix(edge, vignette_color.rgb, vig * 0.38);
	COLOR = vec4(mix(screen, edge, opacity), 1.0);
}

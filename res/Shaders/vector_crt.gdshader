shader_type canvas_item;
render_mode unshaded, blend_mix;

// Fullscreen overlay CRT for vector / polygon drawings.
// Put this on a ColorRect that covers the viewport (CanvasLayer), drawn after the shapes.

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform float warp_amount : hint_range(0.0, 2.0) = 0.42;
uniform float aberration : hint_range(0.0, 0.08) = 0.014;
uniform float scanline_count : hint_range(80.0, 1080.0) = 480.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.55;
uniform float grille_opacity : hint_range(0.0, 1.0) = 0.22;
uniform float bloom_amount : hint_range(0.0, 4.0) = 1.65;
uniform float bloom_spread : hint_range(0.001, 0.03) = 0.0075;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.12;
uniform float brightness : hint_range(0.5, 3.0) = 1.45;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.9;
uniform float corner_radius : hint_range(0.0, 0.25) = 0.07;
uniform float grain_amount : hint_range(0.0, 0.2) = 0.035;
uniform float flicker_amount : hint_range(0.0, 0.1) = 0.018;
uniform vec3 phosphor_tint : source_color = vec3(1.0, 0.96, 0.88);

vec2 warp(vec2 uv) {
	vec2 delta = uv - 0.5;
	float r2 = dot(delta, delta);
	return uv + delta * r2 * warp_amount;
}

float rounded_bezel(vec2 uv) {
	float r = max(corner_radius, 1e-4);
	vec2 p = abs(uv * 2.0 - 1.0);
	vec2 q = p - vec2(1.0) + r;
	float dist = length(max(q, vec2(0.0))) / r;
	return 1.0 - smoothstep(0.82, 1.02, dist);
}

float vignette(vec2 uv) {
	vec2 v = uv * (1.0 - uv);
	float vig = v.x * v.y * 18.0;
	return pow(clamp(vig, 0.0, 1.0), vignette_intensity * 0.55);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 sample_ca(vec2 uv, float ca) {
	vec3 c;
	c.r = texture(SCREEN_TEXTURE, uv + vec2(ca, 0.0)).r;
	c.g = texture(SCREEN_TEXTURE, uv).g;
	c.b = texture(SCREEN_TEXTURE, uv - vec2(ca, 0.0)).b;
	return c;
}

vec3 bloom_tap(vec2 uv, vec2 dir, float spread, float weight) {
	vec3 s = texture(SCREEN_TEXTURE, uv + dir * spread).rgb;
	float lum = max(dot(s, vec3(0.299, 0.587, 0.114)) - bloom_threshold, 0.0);
	return s * lum * weight;
}

vec3 bloom(vec2 uv) {
	vec3 acc = vec3(0.0);
	acc += bloom_tap(uv, vec2(1.0, 0.0), bloom_spread, 1.0);
	acc += bloom_tap(uv, vec2(-1.0, 0.0), bloom_spread, 1.0);
	acc += bloom_tap(uv, vec2(0.0, 1.0), bloom_spread, 1.0);
	acc += bloom_tap(uv, vec2(0.0, -1.0), bloom_spread, 1.0);
	acc += bloom_tap(uv, vec2(1.0, 1.0), bloom_spread, 0.85);
	acc += bloom_tap(uv, vec2(-1.0, 1.0), bloom_spread, 0.85);
	acc += bloom_tap(uv, vec2(1.0, -1.0), bloom_spread, 0.85);
	acc += bloom_tap(uv, vec2(-1.0, -1.0), bloom_spread, 0.85);
	acc += bloom_tap(uv, vec2(1.0, 0.0), bloom_spread * 2.35, 0.4);
	acc += bloom_tap(uv, vec2(-1.0, 0.0), bloom_spread * 2.35, 0.4);
	acc += bloom_tap(uv, vec2(0.0, 1.0), bloom_spread * 2.35, 0.4);
	acc += bloom_tap(uv, vec2(0.0, -1.0), bloom_spread * 2.35, 0.4);
	return acc / 8.6;
}

void fragment() {
	vec2 uv = warp(SCREEN_UV);
	float outside = step(uv.x, 0.0) + step(1.0, uv.x) + step(uv.y, 0.0) + step(1.0, uv.y);
	if (outside > 0.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		
	}

	float edge = length(uv - 0.5);
	float ca = aberration * (0.25 + 2.2 * edge);

	vec3 col = sample_ca(uv, ca);
	col += bloom(uv) * bloom_amount;
	col *= brightness;

	float scan = sin(uv.y * scanline_count * 3.14159265);
	scan = mix(1.0, scan * 0.5 + 0.5, scanline_opacity);
	col *= scan;

	if (grille_opacity > 0.0) {
		float gx = uv.x * scanline_count * 1.6;
		float triad = mod(floor(gx), 3.0);
		vec3 mask = vec3(1.0);
		if (triad < 1.0) {
			mask = vec3(1.0, 0.72, 0.72);
		} else if (triad < 2.0) {
			mask = vec3(0.72, 1.0, 0.72);
		} else {
			mask = vec3(0.72, 0.72, 1.0);
		}
		col *= mix(vec3(1.0), mask, grille_opacity);
	}

	col *= phosphor_tint;
	col *= vignette(uv);
	col *= rounded_bezel(uv);

	float grain = hash(uv * vec2(1920.0, 1080.0) + vec2(TIME * 12.7, TIME * 7.3));
	col += (grain - 0.5) * grain_amount;

	float flicker = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * 55.0) * hash(vec2(TIME, 0.17)));
	col *= flicker;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}

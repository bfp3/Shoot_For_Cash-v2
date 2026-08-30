shader_type spatial;
## Soft procedural cloud puff. Morphs via scrolling FBM. Fog disabled so they stay
## visible past moss depth fog (fog_depth_end ~31).
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque, specular_disabled, fog_disabled;

uniform vec4 cloud_color : source_color = vec4(0.98, 0.99, 1.0, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.78, 0.84, 0.94, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.92;
uniform float density : hint_range(0.0, 1.0) = 0.28;
uniform float softness : hint_range(0.02, 0.8) = 0.35;
uniform float noise_scale : hint_range(0.5, 8.0) = 2.0;
uniform float morph_speed : hint_range(0.0, 1.0) = 0.07;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.45;
uniform float edge_falloff : hint_range(0.1, 1.5) = 1.05;
uniform float brightness : hint_range(0.5, 1.5) = 1.08;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int i = 0; i < 5; i++) {
		v += amp * value_noise(p);
		p = m * p;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	float radial = 1.0 - length(centered) * (2.0 / max(edge_falloff, 0.05));
	radial = clamp(radial, 0.0, 1.0);
	radial = smoothstep(0.0, 1.0, radial);

	vec2 drift = vec2(TIME * morph_speed * 0.65, TIME * morph_speed * 0.4);
	vec2 n_uv = uv * noise_scale + drift;
	float n = fbm(n_uv);
	float detail = fbm(n_uv * 2.3 + vec2(17.0, 9.0) + drift * 1.4);
	n = mix(n, detail, detail_strength);

	## Lower density = fuller cloud (noise must clear this threshold).
	float shape = smoothstep(density - softness, density + softness * 0.5, n);
	float alpha = shape * radial * opacity;
	if (alpha < 0.02) {
		discard;
	}

	float shade = smoothstep(0.15, 0.8, n);
	vec3 col = mix(cloud_shadow.rgb, cloud_color.rgb, shade) * brightness;
	ALBEDO = col;
	ALPHA = alpha;
}

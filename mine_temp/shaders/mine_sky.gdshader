shader_type sky;

uniform vec3 top_color : source_color = vec3(0.38, 0.28, 0.58);
uniform vec3 mid_color : source_color = vec3(0.92, 0.48, 0.38);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.62, 0.28);
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.78);
uniform vec3 sun_dir = vec3(-0.82, 0.18, 0.28);
uniform float sun_size : hint_range(0.01, 0.2) = 0.055;
uniform float glow_size : hint_range(0.05, 1.5) = 0.45;

void sky() {
	float h = clamp(EYEDIR.y * 1.15 + 0.08, 0.0, 1.0);
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.28, h));
	col = mix(col, top_color, smoothstep(0.22, 0.85, h));

	vec3 d = normalize(sun_dir);
	float along = dot(normalize(EYEDIR), d);
	float glow = pow(clamp(along, 0.0, 1.0), 8.0);
	col += sun_color * glow * glow_size * 0.35;

	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, d));
	up = normalize(cross(d, right));
	vec3 local = vec3(dot(EYEDIR, right), dot(EYEDIR, up), dot(EYEDIR, d));
	if (local.z > 0.02) {
		vec2 p = local.xy / local.z;
		if (abs(p.x) < sun_size && abs(p.y) < sun_size) {
			col = sun_color;
		}
	}
	COLOR = col;
}

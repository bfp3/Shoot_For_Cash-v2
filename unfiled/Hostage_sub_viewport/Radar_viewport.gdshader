shader_type canvas_item;

// === Radar Shape ===
uniform float ellipse_a : hint_range(0.1, 2.0) = 1.0; // Horizontal radius
uniform float ellipse_b : hint_range(0.1, 2.0) = 1.035; // Vertical radius

// === Radar Sweep Settings ===
uniform float sweep_thickness : hint_range(0.001, 0.2) = 0.005;
uniform float sweep_angle_range : hint_range(0.001, 0.5) = 0.195;
uniform float sweep_speed : hint_range(0.1, 10.0) = 0.5;

// === Trail Fade Settings ===
uniform float trail_fade_speed : hint_range(0.1, 10.0) = 10.0;

// === Pulse Settings ===
uniform float pulse_speed : hint_range(0.1, 10.0) = 0.1;
uniform float pulse_thickness : hint_range(0.001, 0.5) = 0.23;
uniform vec4 pulse_color : source_color = vec4(0.0, 0.7, 0.0, 0.5);

// === Colors ===
uniform vec4 bg_color : source_color = vec4(0.0, 0.2, 0.0, 1.0);
uniform vec4 arm_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);

// === Jam / Malfunction Parameters ===
uniform float jam_chance_speed : hint_range(0.1, 10.0) = 1.5;     // Controls "randomness" of jams
uniform float jam_duration : hint_range(0.1, 3.0) = 0.7;          // How long the jam lasts
uniform float min_time_between_jams : hint_range(0.5, 10.0) = 3.0; // Minimum time between jams
uniform float jam_oscillation_amplitude : hint_range(0.01, 1.0) = 0.3; // Radians to wiggle left/right
uniform float jam_oscillation_speed : hint_range(1.0, 20.0) = 10.0;    // Wiggle speed


void fragment() {
	vec2 uv = (UV - vec2(0.5)) * 2.0;

	// Clip outside ellipse
	float ellipse = (uv.x * uv.x) / (ellipse_a * ellipse_a) + (uv.y * uv.y) / (ellipse_b * ellipse_b);
	if (ellipse > 1.0) {
		discard;
	}

	// Normalize position to ellipse shape
	vec2 ellipse_uv = vec2(uv.x / ellipse_a, uv.y / ellipse_b);
	float distance = length(ellipse_uv);
	float pixel_angle = atan(ellipse_uv.y, ellipse_uv.x);

	// === Radar Sweep ===
	// === JAM / MALFUNCTION LOGIC ===

// Create a pseudo-random pattern based on time chunk
// === JAM / MALFUNCTION LOGIC ===

// Divide time into intervals
	float jam_interval = min_time_between_jams;
	float time_mod = mod(TIME, jam_interval);
	float jam_timer = floor(TIME / jam_interval);

	// Pseudo-random per interval
	float pseudo_random = fract(sin(jam_timer * jam_chance_speed) * 43758.5453);

	// Is this interval a jam?
	bool is_jamming = (pseudo_random < 0.3);
	bool is_in_jam_window = (time_mod < jam_duration);
	float jam_active = float(is_jamming && is_in_jam_window);

	// Calculate what the sweep angle was at the start of the jam
	float stuck_time = jam_timer * jam_interval;
	float stuck_angle = stuck_time * sweep_speed;

	// Oscillate around that stuck angle
	float wiggle = sin(TIME * jam_oscillation_speed) * jam_oscillation_amplitude;

	// Final sweep angle
	float sweep_angle = mix(TIME * sweep_speed, stuck_angle + wiggle, jam_active);

	float angle_diff = mod(pixel_angle - sweep_angle + 3.14159, 6.28318) - 3.14159;

	// Projected vector for arm center direction
	vec2 sweep_dir = vec2(cos(sweep_angle), sin(sweep_angle));
	float proj = dot(ellipse_uv, sweep_dir);
	vec2 closest_point = proj * sweep_dir;
	float perpendicular_dist = length(ellipse_uv - closest_point);

	// Arm mask (constant thickness)
	float arm_mask = smoothstep(sweep_thickness, 0.0, perpendicular_dist) * step(0.1, proj);

	// Trail mask (fades behind arm)
	float trail_mask = exp(-abs(angle_diff) * trail_fade_speed) * step(0.1, distance);

	// Combine radar sweep
	vec4 sweep_color = arm_color * arm_mask + arm_color * 0.3 * trail_mask;

	// === Expanding Pulse Ring ===
	float pulse_radius = mod(TIME * pulse_speed, 1.0);
	float pulse_edge = smoothstep(pulse_radius + pulse_thickness, pulse_radius, distance) *
	                   smoothstep(pulse_radius - pulse_thickness, pulse_radius, distance);
	vec4 pulse = pulse_color * pulse_edge;

	// Final composite
	COLOR = mix(bg_color, sweep_color + pulse, clamp(arm_mask + trail_mask + pulse_edge, 0.0, 1.0));
}

shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// --- Controls ---
uniform vec4 band_color : source_color = vec4(1.0, 0.9, 0.0, 1.0); // yellow, RGBA
uniform float band_thickness : hint_range(0.01, 1.0) = 0.15;       // width of the band (0-1, in diagonal-space)
uniform float skew : hint_range(-2.0, 2.0) = 0.4;                  // diagonal tilt (0 = vertical band, higher = steeper diagonal)

// Driven by a Tween in script, from 0.0 (band not yet entered) to 1.0 (band fully exited).
// Speed is controlled entirely by how long the script's tween takes to go 0 -> 1.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// no vertex changes needed
}

void fragment() {
	// Diagonal coordinate: combines left->right travel with a vertical tilt.
	float diag = UV.x + (UV.y - 0.5) * skew;

	// Band travels from just off the left edge to just off the right edge as progress goes 0 -> 1.
	float band_pos = mix(-band_thickness, 1.0 + band_thickness, progress);

	// Soft-edged band centered on band_pos with total width = 2 * band_thickness.
	float left_edge = smoothstep(band_pos - band_thickness, band_pos, diag);
	float right_edge = 1.0 - smoothstep(band_pos, band_pos + band_thickness, diag);
	float band_mask = left_edge * right_edge;

	ALBEDO = band_color.rgb;
	ALPHA = band_mask * band_color.a;
}

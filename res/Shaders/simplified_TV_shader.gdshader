shader_type canvas_item;
// Core CRT Effects + Custom Crack Overlay
uniform bool overlay = false;
uniform float aberration : hint_range(-1.0, 1.0) = 0.005;
uniform float brightness = 0.0;
uniform bool discolor = false;
uniform float warp_amount :hint_range(0.0, 50.0) = 0.2;
uniform bool clip_warp = false;
uniform float vignette_intensity = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;

// --- CRT scanline / mask settings ---
uniform bool scanlines_enabled = true;
uniform float scanline_count = 240.0;      // roughly your target vertical resolution
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.35;
uniform float scanline_speed = 0.0;        // set >0 for a slow rolling scanline
uniform bool mask_enabled = true;          // faux RGB subpixel mask
uniform float mask_opacity : hint_range(0.0, 1.0) = 0.15;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.03;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

vec2 warp(vec2 uv){
	vec2 delta = uv - 0.5;
	float delta2 = dot(delta.xy, delta.xy);
	float delta4 = delta2 * delta2;
	float delta_offset = delta4 * warp_amount;
	return uv + delta * delta_offset;
}
float border(vec2 uv){
	float radius = min(warp_amount, 0.08);
	radius = max(min(min(abs(radius * 2.0), abs(1.0)), abs(1.0)), 1e-5);
	vec2 abs_uv = abs(uv * 2.0 - 1.0) - vec2(1.0, 1.0) + radius;
	float dist = length(max(vec2(0.0), abs_uv)) / radius;
	float square = smoothstep(0.96, 1.0, dist);
	return clamp(1.0 - square, 0.0, 1.0);
}
float vignette(vec2 uv){
	uv *= 1.0 - uv.xy;
	float vig = uv.x * uv.y * 15.0;
	return pow(vig, vignette_intensity * vignette_opacity);
}
// Simple radial crack function
float crack(vec2 uv, vec2 origin, float size, float thickness, int prongs) {
	vec2 delta = uv - origin;
	float dist = length(delta);
	float angle = atan(delta.y, delta.x);
	float spacing = 3.14159 / float(prongs);
	float radial = abs(mod(angle, spacing));
	float line = smoothstep(thickness, 0.0, radial);
	float reach = smoothstep(size, 0.0, dist);
	return line * reach;
}

// Cheap pseudo-random for flicker
float rand(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 uv = overlay ? warp(SCREEN_UV) : warp(UV);
	vec2 text_uv = uv;
	// Aberration + texture sampling
	vec4 text;
	text.r = texture(SCREEN_TEXTURE, text_uv + vec2(aberration, 0.0) * 0.1).r;
	text.g = texture(SCREEN_TEXTURE, text_uv - vec2(aberration, 0.0) * 0.1).g;
	text.b = texture(SCREEN_TEXTURE, text_uv).b;
	text.a = 1.0;
	// Apply brightness
	text.rgb = clamp(text.rgb * brightness, 0.0, 1.0);
	// Discoloration
	if (discolor) {
		vec3 greyscale = vec3(text.r + text.g + text.b) / 3.0;
		text.rgb = mix(text.rgb, greyscale, 0.5);
		float midpoint = pow(0.5, 2.2);
		text.rgb = (text.rgb - vec3(midpoint)) * 1.2 + midpoint;
	}

	// --- Scanlines ---
	if (scanlines_enabled) {
		float scan_uv = uv.y * scanline_count - TIME * scanline_speed;
		float scanline = sin(scan_uv * 3.14159 * 2.0) * 0.5 + 0.5;
		scanline = mix(1.0, scanline, scanline_opacity);
		text.rgb *= scanline;
	}

	// --- Faux RGB subpixel mask ---
	if (mask_enabled) {
		float mask_x = mod(floor(uv.x * scanline_count * 1.5), 3.0);
		vec3 mask_color = vec3(0.0);
		if (mask_x < 1.0) mask_color = vec3(1.0, mask_opacity * 2.0, mask_opacity * 2.0);
		else if (mask_x < 2.0) mask_color = vec3(mask_opacity * 2.0, 1.0, mask_opacity * 2.0);
		else mask_color = vec3(mask_opacity * 2.0, mask_opacity * 2.0, 1.0);
		text.rgb *= mix(vec3(1.0), mask_color, mask_opacity);
	}

	// --- Subtle random flicker ---
	if (flicker_amount > 0.0) {
		float flicker = 1.0 - flicker_amount * rand(TIME);
		text.rgb *= flicker;
	}

	// Border + vignette
	text.rgb *= border(uv);
	text.rgb *= vignette(uv);
	if (clip_warp)
		text.a = border(uv);
	COLOR = text;
}
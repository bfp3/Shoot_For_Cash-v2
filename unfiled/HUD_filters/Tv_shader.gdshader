/*
Shader from Godot Shaders - the free shader library.
godotshaders.com/shader/VHS-and-CRT-monitor-effect

This shader is under CC0 license. Feel free to use, improve and
change this shader according to your needs and consider sharing
the modified result to godotshaders.com.
*/

shader_type canvas_item;

//*** IMPORTANT! ***/
// - If you are using this shader to affect the node it is applied to set 'overlay' to false (unchecked in the instepctor).
// - If you are using this shader as an overlay, and want the shader to affect the nodes below in the Scene hierarchy,
//   set 'overlay' to true (checked in the inspector).
// On Mac there is potentially a bug causing this to not work properly. If that is the case and you want to use the shader as an overlay
// change all "overlay ? SCREEN_TEXTURE : TEXTURE" to only "SCREEN_TEXTURE" on lines 129-140, and "vec2 uv = overlay ? warp(SCREEN_UV) : warp(UV);"
// to "vec2 uv = warp(SCREEN_UV);" on line 98.
uniform bool overlay = false;

uniform float scanlines_opacity : hint_range(0.0, 1.0) = 0.4;
uniform float scanlines_width : hint_range(0.0, 0.5) = 0.25;
uniform float grille_opacity : hint_range(0.0, 1.0) = 0.3;
uniform vec2 resolution = vec2(640.0, 480.0); // Set the number of rows and columns the texture will be divided in. Scanlines and grille will make a square based on these values

uniform bool pixelate = true; // Fill each square ("pixel") with a sampled color, creating a pixel look and a more accurate representation of how a CRT monitor would work.

uniform bool roll = true;
uniform float roll_speed = 8.0; // Positive values are down, negative are up
uniform float roll_size : hint_range(0.0, 100.0) = 15.0;
uniform float roll_variation : hint_range(0.1, 5.0) = 1.8; // This valie is not an exact science. You have to play around with the value to find a look you like. How this works is explained in the code below.
uniform float distort_intensity : hint_range(0.0, 0.2) = 0.05; // The distortion created by the rolling effect.

uniform float noise_opacity : hint_range(0.0, 1.0) = 0.4;
uniform float noise_speed = 5.0; // There is a movement in the noise pattern that can be hard to see first. This sets the speed of that movement.

uniform float static_noise_intensity : hint_range(0.0, 1.0) = 0.06;

uniform float aberration : hint_range(-1.0, 1.0) = 0.03; // Chromatic aberration, a distortion on each color channel.
uniform float brightness = 1.4; // When adding scanline gaps and grille the image can get very dark. Brightness tries to compensate for that.
uniform bool discolor = true; // Add a discolor effect simulating a VHS

uniform float warp_amount :hint_range(0.0, 5.0) = 1.0; // Warp the texture edges simulating the curved glass of a CRT monitor or old TV.
uniform bool clip_warp = false;

uniform float vignette_intensity = 0.4; // Size of the vignette, how far towards the middle it should go.
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;

uniform int crack_count : hint_range(0, 20) = 3;
uniform float crack_size : hint_range(0.01, 1.0) = 0.3;
uniform float crack_thickness : hint_range(0.001, 0.05) = 0.01;
uniform float crack_opacity : hint_range(0.0, 1.0) = 0.4;

uniform vec3 crack_color : source_color = vec3(1.0, 1.0, 1.0); // default white
uniform int crack_prongs : hint_range(1, 32) = 8;


uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Random hash
vec2 random(vec2 uv){
	uv = vec2( dot(uv, vec2(127.1,311.7) ),
	           dot(uv, vec2(269.5,183.3) ) );
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

// Perlin noise
float noise(vec2 uv) {
	vec2 uv_index = floor(uv);
	vec2 uv_fract = fract(uv);
	vec2 blur = smoothstep(0.0, 1.0, uv_fract);

	return mix( mix( dot( random(uv_index + vec2(0.0,0.0) ), uv_fract - vec2(0.0,0.0) ),
	                 dot( random(uv_index + vec2(1.0,0.0) ), uv_fract - vec2(1.0,0.0) ), blur.x),
	            mix( dot( random(uv_index + vec2(0.0,1.0) ), uv_fract - vec2(0.0,1.0) ),
	                 dot( random(uv_index + vec2(1.0,1.0) ), uv_fract - vec2(1.0,1.0) ), blur.x), blur.y) * 0.5 + 0.5;
}

// Warp edges
vec2 warp(vec2 uv){
	vec2 delta = uv - 0.5;
	float delta2 = dot(delta.xy, delta.xy);
	float delta4 = delta2 * delta2;
	float delta_offset = delta4 * warp_amount;
	return uv + delta * delta_offset;
}

// Black border mask
float border (vec2 uv){
	float radius = min(warp_amount, 0.08);
	radius = max(min(min(abs(radius * 2.0), abs(1.0)), abs(1.0)), 1e-5);
	vec2 abs_uv = abs(uv * 2.0 - 1.0) - vec2(1.0, 1.0) + radius;
	float dist = length(max(vec2(0.0), abs_uv)) / radius;
	float square = smoothstep(0.96, 1.0, dist);
	return clamp(1.0 - square, 0.0, 1.0);
}

// Vignette
float vignette(vec2 uv){
	uv *= 1.0 - uv.xy;
	float vignette = uv.x * uv.y * 15.0;
	return pow(vignette, vignette_intensity * vignette_opacity);
}

float crack(vec2 uv, vec2 origin, float size, float thickness, int prongs) {
	vec2 delta = uv - origin;
	float dist = length(delta);
	float angle = atan(delta.y, delta.x);

	// Adjust how many radial prongs
	float spacing = 3.14159 / float(prongs);
	float radial = abs(mod(angle, spacing));
	float line = smoothstep(thickness, 0.0, radial);
	float reach = smoothstep(size, 0.0, dist);

	return line * reach;
}



void fragment() {
	vec2 uv = overlay ? warp(SCREEN_UV) : warp(UV);
	vec2 text_uv = uv;
	vec2 roll_uv = vec2(0.0);
	float time = roll ? TIME : 0.0;

	if (pixelate)
		text_uv = ceil(uv * resolution) / resolution;

	float roll_line = 0.0;
	if (roll || noise_opacity > 0.0) {
		roll_line = smoothstep(0.3, 0.9, sin(uv.y * roll_size - (time * roll_speed)));
		roll_line *= roll_line * smoothstep(0.3, 0.9, sin(uv.y * roll_size * roll_variation - (time * roll_speed * roll_variation)));
		roll_uv = vec2((roll_line * distort_intensity * (1.0 - UV.x)), 0.0);
	}

	vec4 text;
	if (roll) {
		text.r = texture(SCREEN_TEXTURE, text_uv + roll_uv * 0.8 + vec2(aberration, 0.0) * 0.1).r;
		text.g = texture(SCREEN_TEXTURE, text_uv + roll_uv * 1.2 - vec2(aberration, 0.0) * 0.1).g;
		text.b = texture(SCREEN_TEXTURE, text_uv + roll_uv).b;
		text.a = 1.0;
	} else {
		text.r = texture(SCREEN_TEXTURE, text_uv + vec2(aberration, 0.0) * 0.1).r;
		text.g = texture(SCREEN_TEXTURE, text_uv - vec2(aberration, 0.0) * 0.1).g;
		text.b = texture(SCREEN_TEXTURE, text_uv).b;
		text.a = 1.0;
	}

	float r = text.r;
	float g = text.g;
	float b = text.b;

	uv = warp(UV);

	if (grille_opacity > 0.0) {
		float g_r = smoothstep(0.85, 0.95, abs(sin(uv.x * resolution.x * 3.14159)));
		float g_g = smoothstep(0.85, 0.95, abs(sin(uv.x * resolution.x * 3.14159 + 1.05)));
		float b_b = smoothstep(0.85, 0.95, abs(sin(uv.x * resolution.x * 3.14159 + 2.1)));

		r = mix(r, r * g_r, grille_opacity);
		g = mix(g, g * g_g, grille_opacity);
		b = mix(b, b * b_b, grille_opacity);
	}

	text.r = clamp(r * brightness, 0.0, 1.0);
	text.g = clamp(g * brightness, 0.0, 1.0);
	text.b = clamp(b * brightness, 0.0, 1.0);

	if (scanlines_opacity > 0.0) {
		float scan = smoothstep(scanlines_width, scanlines_width + 0.5, abs(sin(uv.y * resolution.y * 3.14159)));
		text.rgb = mix(text.rgb, text.rgb * vec3(scan), scanlines_opacity);
	}

	if (noise_opacity > 0.0) {
		float noise_val = smoothstep(0.4, 0.5, noise(uv * vec2(2.0, 200.0) + vec2(10.0, time * noise_speed)));
		roll_line *= noise_val * clamp(random((ceil(uv * resolution) / resolution) + vec2(time * 0.8, 0.0)).x + 0.8, 0.0, 1.0);
		text.rgb = clamp(mix(text.rgb, text.rgb + roll_line, noise_opacity), vec3(0.0), vec3(1.0));
	}

	if (static_noise_intensity > 0.0) {
		text.rgb += clamp(random((ceil(uv * resolution) / resolution) + fract(time)).x, 0.0, 1.0) * static_noise_intensity;
	}

	text.rgb *= border(uv);
	text.rgb *= vignette(uv);

	if (clip_warp)
		text.a = border(uv);

	if (discolor) {
		vec3 greyscale = vec3(text.r + text.g + text.b) / 3.0;
		text.rgb = mix(text.rgb, greyscale, 0.5);
		float midpoint = pow(0.5, 2.2);
		text.rgb = (text.rgb - vec3(midpoint)) * 1.2 + midpoint;
	}

	float crack_mask = 0.0;
	for (int i = 0; i < crack_count; i++) {
		float fi = float(i);
		vec2 crack_origin = vec2(
			fract(sin(fi * 42.54) * 43758.23),
			fract(sin(fi * 57.31) * 12345.67)
		);
		crack_mask += crack(UV, crack_origin, crack_size, crack_thickness, crack_prongs);
	}
	crack_mask = clamp(crack_mask, 0.0, 1.0);

	// Blend crack color with CRT final color
	text.rgb = mix(text.rgb, crack_color, crack_mask * crack_opacity);

	COLOR = text;
}
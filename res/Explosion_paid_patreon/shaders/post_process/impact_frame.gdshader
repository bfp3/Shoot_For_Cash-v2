shader_type spatial;
render_mode unshaded, depth_test_disabled;

uniform sampler2D depth_tex : source_color, hint_depth_texture;
uniform sampler2D screen_tex : source_color, hint_screen_texture;

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	vec4 screen = texture(screen_tex, SCREEN_UV);
	
	float grayscale = (screen.r + screen.g + screen.b) / 3.0;
	float stepped = step(0.99, 1.0 - grayscale);
	float smoothstepped = smoothstep(0.0, 1.0, grayscale);
	
	ALBEDO = screen.rgb;
	//ALBEDO = vec3(stepped);
	//ALBEDO = vec3(smoothstepped);
}
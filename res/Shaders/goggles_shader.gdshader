shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float time_fluc : hint_range(0.0, 100.0) = 10.4;

void fragment() {
    COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);

    // Pulsating effect using sine function
    float pulsate = sin(TIME * time_fluc) * 0.04; // Adjust the frequency and amplitude as needed
    COLOR.rgb += vec3(pulsate);

    // Convert to greyscale
    float grey = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
    COLOR.rgb = vec3(grey);

    // Optionally, you can adjust the greyscale intensity
    COLOR.rgb *= 1.5;

    // Optionally, you can desaturate the greyscale a bit
    COLOR = vec4(COLOR.r, (COLOR.g + COLOR.r + COLOR.b) / 3.0, COLOR.b, COLOR.a);
}


//shader_type canvas_item;
//
//uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
//
//void fragment() {
//    COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);
//
//    // Introduce noise
//    float noise = (texture(SCREEN_TEXTURE, SCREEN_UV * vec2(10.0, 10.0)).r - 0.5) * 0.1;
//    COLOR.rgb += noise;
//
//    // Pulsating effect using sine function
//    float pulsate = sin(TIME * 2.0) * 0.02; // Adjust the frequency and amplitude as needed
//    COLOR.rgb += vec3(pulsate);
//
//    // Set red and blue channels to zero, and boost the green channel
//    COLOR.r = COLOR.r * 1.9;
//    COLOR.b = 0.1;
//    COLOR.g = 0.1;
//
//    // Optionally, you can desaturate the green channel a bit
//    COLOR = vec4(COLOR.r, (COLOR.g + COLOR.r + COLOR.b) / 3.0, COLOR.b, COLOR.a);
//}




//
//shader_type canvas_item;
//
//uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
//
//void fragment() {
//	COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);
//	COLOR.rgb = vec3(COLOR.r + COLOR.g + COLOR.b) / 1.5;
//
//}
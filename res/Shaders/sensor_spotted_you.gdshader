

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);

    // Introduce noise
    float noise = (texture(SCREEN_TEXTURE, SCREEN_UV * vec2(10.0, 10.0)).r - 0.5) * 0.1;
    COLOR.rgb += noise;

    // Pulsating effect using sine function
    float pulsate = sin(TIME * 40.0) * 0.18; // Adjust the frequency and amplitude as needed
    COLOR.rgb += vec3(pulsate);

    // Set red and blue channels to zero, and boost the green channel
    COLOR.r = COLOR.r * 1.5;
    COLOR.b = 0.0;
    COLOR.g = 0.0;

    // Optionally, you can desaturate the green channel a bit
    COLOR = vec4(COLOR.r, (COLOR.g + COLOR.r + COLOR.b) / 10.0, COLOR.b, COLOR.a);
}




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
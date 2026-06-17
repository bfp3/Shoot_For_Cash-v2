shader_type spatial;
//render_mode unshaded;

uniform sampler2D texture_albedo : source_color;

uniform float wave_speed = 1.0;
uniform float wave_height = 0.3;
uniform float wave_frequency = 2.0;

void vertex() {
    float wave = sin(VERTEX.x * wave_frequency + TIME * wave_speed) * wave_height;
    VERTEX.y += wave;
    VERTEX.x += wave * 0.3;
}

void fragment() {
    vec4 tex_color = texture(texture_albedo, UV);
    ALBEDO = tex_color.rgb;
    //ALPHA = tex_color.a;
}

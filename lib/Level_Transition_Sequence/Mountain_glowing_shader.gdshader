shader_type canvas_item;

uniform float glow_strength = 1.5;
uniform vec4 glow_color : source_color = vec4(1.0, 0.7, 0.2, 1.0);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float intensity = length(tex_color.rgb);
    COLOR = tex_color + glow_color * intensity * glow_strength;
}

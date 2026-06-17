shader_type spatial;

uniform sampler2D albedo_texture : source_color;
uniform float egg_shape : hint_range(-1.5, 1.5, 0.1);

void vertex() {
    float y = VERTEX.y;
    float deform = 1.0 + (y * egg_shape); // egg taper
    VERTEX.xz *= deform;
}

void fragment() {
    vec2 uv = UV;
    vec4 albedo = texture(albedo_texture, uv);
    ALBEDO = albedo.rgb;
    ALPHA = albedo.a;
}

shader_type canvas_item;

uniform float shine_progress : hint_range(0.0, 2.0) = -0.2;
uniform float shine_width : hint_range(0.01, 1.0) = 0.15;
uniform float shine_strength : hint_range(0.0, 2.0) = 1.0;

uniform vec4 base_color : source_color = vec4(1.0, 0.65, 0.15, 1.0);
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Diagonal from bottom-left to top-right
    float axis = UV.x + UV.y;

    // Distance from the moving shine
    float distance_to_shine = abs(axis - shine_progress);

    // Soft shine band
    float shine = 1.0 - smoothstep(
        0.0,
        shine_width,
        distance_to_shine
    );

    // Tint the original white star
    vec3 color = tex.rgb * base_color.rgb;

    // Add the white shine
    color += shine_color.rgb * shine * shine_strength * tex.a;

    COLOR = vec4(color, tex.a);
}
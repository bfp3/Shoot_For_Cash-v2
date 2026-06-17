shader_type canvas_item;
render_mode blend_add;


uniform float glow_intensity = 1.0;
uniform float blur_radius = 4.0;
uniform int blur_steps = 6;

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    vec4 glow = vec4(0.0);

    // Replace with your actual texture size if different
    vec2 pixel_size = vec2(1.0 / 512.0, 1.0 / 512.0);

    for (int x = -blur_steps; x <= blur_steps; x++) {
        for (int y = -blur_steps; y <= blur_steps; y++) {
            vec2 offset = vec2(float(x), float(y)) * pixel_size * blur_radius;
            glow += texture(TEXTURE, UV + offset);
        }
    }

    int total_samples = (2 * blur_steps + 1) * (2 * blur_steps + 1);
    glow /= float(total_samples);

    vec4 result = base_color + glow * glow_intensity;

    // Respect modulate tint from node
    COLOR = result * COLOR;
}

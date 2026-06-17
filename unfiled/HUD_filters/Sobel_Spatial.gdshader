shader_type spatial;

uniform float edge_intensity : hint_range(0.0, 10.0) = 1.0;
uniform vec3 edge_color = vec3(0.0, 0.0, 0.0); // Black edges
uniform vec3 grayscale_weights = vec3(0.299, 0.587, 0.114);

void fragment() {
    vec2 texel_size = vec2(1.0) / vec2(textureSize(TEXTURE, 0));
    vec2 uv = FRAGCOORD.xy / vec2(SCREEN_PIXEL_SIZE.xy);

    float kernelX[9] = float[](-1.0, 0.0, 1.0, -2.0, 0.0, 2.0, -1.0, 0.0, 1.0);
    float kernelY[9] = float[](1.0, 2.0, 1.0, 0.0, 0.0, 0.0, -1.0, -2.0, -1.0);

    float sumX = 0.0;
    float sumY = 0.0;

    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            vec2 offset = vec2(float(i - 1), float(j - 1)) * texel_size;
            vec4 color = texture(TEXTURE, uv + offset);
            float intensity = dot(color.rgb, grayscale_weights); // Convert to grayscale
            sumX += intensity * kernelX[i * 3 + j];
            sumY += intensity * kernelY[i * 3 + j];
        }
    }

    float edge_strength = sqrt(sumX * sumX + sumY * sumY) * edge_intensity;
    vec3 edge_output_color = mix(vec3(1.0), edge_color, edge_strength);

    ALBEDO = edge_output_color;
}

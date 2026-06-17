
shader_type canvas_item;

// Sobel filter parameters
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float edge_intensity = 1.0;
uniform vec3 edge_color = vec3(0.0, 0.0, 0.0); // Black edges

// Crosshatch shading parameters
uniform vec3 light_color = vec3(1.0, 0.8, 0.6);
uniform vec3 mid_color = vec3(0.6, 0.4, 0.2);
uniform vec3 dark_color = vec3(0.2, 0.1, 0.1);

void fragment() {
    vec2 texel_size = vec2(1.0) / vec2(textureSize(SCREEN_TEXTURE, 0));
    vec2 uv = FRAGCOORD.xy / vec2(textureSize(SCREEN_TEXTURE, 0));

    float kernelX[9] = float[](-1.0, 0.0, 1.0, -2.0, 0.0, 2.0, -1.0, 0.0, 1.0);
    float kernelY[9] = float[]( 1.0, 2.0, 1.0,  0.0, 0.0, 0.0, -1.0, -2.0, -1.0);

    float sumX = 0.0;
    float sumY = 0.0;
    vec3 original_color = texture(SCREEN_TEXTURE, uv).rgb;

    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            vec2 offset = vec2(float(i - 1), float(j - 1)) * texel_size;
            vec4 color = texture(SCREEN_TEXTURE, uv + offset);
            float intensity = dot(color.rgb, vec3(0.299, 0.587, 0.114)); // Convert to grayscale
            sumX += intensity * kernelX[i * 3 + j];
            sumY += intensity * kernelY[i * 3 + j];
        }
    }

    float edge_strength = sqrt(sumX * sumX + sumY * sumY) * edge_intensity;
    vec3 edge_detected = mix(original_color, edge_color, edge_strength);

    // Apply crosshatch shading
    vec3 normal = normalize(NORMAL);
    vec3 light_dir = vec3(0.0, 1.0, 0.0); // Assuming light comes from above
    float intensity = max(dot(normal, light_dir), 0.0); // Ensure intensity is non-negative

    vec3 crosshatch_color;
    if (intensity > 0.66) {
        crosshatch_color = mix(mid_color, light_color, (intensity - 0.66) / 0.34);
    } else if (intensity > 0.33) {
        crosshatch_color = mix(dark_color, mid_color, (intensity - 0.33) / 0.33);
    } else {
        crosshatch_color = dark_color;
    }

    vec3 final_color = mix(edge_detected, crosshatch_color, 1.0 - edge_strength);
    COLOR = vec4(final_color, 1.0);
}

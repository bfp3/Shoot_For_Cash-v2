shader_type canvas_item;

// 0 = full colour, 1 = full grayscale.
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 col = tex * COLOR;
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(gray), amount);
	COLOR = col;
}

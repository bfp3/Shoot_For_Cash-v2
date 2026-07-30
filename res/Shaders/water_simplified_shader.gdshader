// Simplified water shader — basic color/texture + physical Gerstner wave displacement.
// Stripped from the original: no foam, refraction, Snell's window, depth fog,
// distance fade, or triplanar/multi-UV systems.

shader_type spatial;

render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

uniform bool freeze_time = false;

group_uniforms Surface;
uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

group_uniforms UV;
uniform vec2 uv_scale = vec2(0.05, 0.05); // how large the texture tiles across the water
uniform vec2 uv_scroll_speed = vec2(0.02, 0.015); // slow constant drift, independent of the waves
group_uniforms;

group_uniforms WaveParameters;
uniform int WaveCount : hint_range(0, 8) = 0;
uniform float WaveSteepnesses[8];
uniform float WaveAmplitudes[8];
uniform float WaveDirectionsDegrees[8];
uniform float WaveFrequencies[8];
uniform float WaveSpeeds[8];
uniform float WavePhases[8];
group_uniforms;

varying vec3 world_coordinates;

// Gerstner wave vertex offset
vec3 P_DEG(float x, float z, float t, float Steepness, float Amplitude, float DirectionDegrees, float Frequency, float Speed, float PhaseDegrees) {
	vec2 Direction = vec2(sin(DirectionDegrees * TAU / 360.0), cos(DirectionDegrees * TAU / 360.0));
	float p = PhaseDegrees * TAU / 360.0;
	vec3 result;
	result.x = ((Steepness * Amplitude) * Direction.x * cos(TAU * dot(Frequency * Direction, vec2(x, z)) + (Speed * (t + p))));
	result.y = Steepness * sin(TAU * dot(Frequency * Direction, vec2(x, z)) + (Speed * (t + p)));
	result.z = ((Steepness * Amplitude) * Direction.y * cos(TAU * dot(Frequency * Direction, vec2(x, z)) + (Speed * (t + p))));
	return result;
}

// Gerstner wave normal
vec3 N_DEG(float x, float z, float t, float Steepness, float Amplitude, float DirectionDegrees, float Frequency, float Speed, float PhaseDegrees) {
	vec2 Direction = vec2(sin(DirectionDegrees * TAU / 360.0), cos(DirectionDegrees * TAU / 360.0));
	float p = PhaseDegrees * TAU / 360.0;
	vec3 result;
	result.x = (-1.0) * (Direction.x * Frequency * Amplitude * (cos((Frequency * TAU * dot(Direction, vec2(x, z))) + Speed * (t + p))));
	result.y = 1.0 - (Steepness * Frequency * Amplitude * sin((Frequency * TAU * dot(Direction, vec2(x, z))) + Speed * (t + p)));
	result.z = (-1.0) * (Direction.y * Frequency * Amplitude * (cos((Frequency * TAU * dot(Direction, vec2(x, z))) + Speed * (t + p))));
	return result;
}

void vertex() {
	float time = TIME * float(!freeze_time);

	// world_vertex_coords is on, so VERTEX is already in world space.
	world_coordinates = VERTEX;
	vec2 wave_coords = world_coordinates.xz;

	// Simple planar UV, just tiled and slowly scrolled — gives the texture its own drift
	// independent of the physical wave motion.
	UV = wave_coords * uv_scale + uv_scroll_speed * time;

	if (WaveCount > 0) {
		vec3 vertexWave = vec3(0.0);
		vec3 normalWave = vec3(0.0);
		for (int i = 0; i < WaveCount; i++) {
			vertexWave += P_DEG(wave_coords.x, wave_coords.y, time, WaveSteepnesses[i], WaveAmplitudes[i], WaveDirectionsDegrees[i], WaveFrequencies[i], WaveSpeeds[i], WavePhases[i]);
			normalWave += N_DEG(wave_coords.x, wave_coords.y, time, WaveSteepnesses[i], WaveAmplitudes[i], WaveDirectionsDegrees[i], WaveFrequencies[i], WaveSpeeds[i], WavePhases[i]);
		}
		vertexWave /= float(WaveCount);
		normalWave = normalize(normalWave / float(WaveCount));

		VERTEX += vertexWave;
		NORMAL = normalWave;
	}

	world_coordinates = VERTEX;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);

	ALBEDO = albedo.rgb * albedo_tex.rgb;
	ALPHA = albedo.a * albedo_tex.a;
	METALLIC = metallic;
	SPECULAR = specular;
	ROUGHNESS = roughness;
}

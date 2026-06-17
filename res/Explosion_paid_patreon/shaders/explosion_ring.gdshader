shader_type spatial;
render_mode blend_mix,depth_draw_always,cull_disabled,diffuse_burley,specular_disabled,unshaded,alpha_to_coverage;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float proximity_fade_distance;
uniform float alpha_scissor_threshold;
uniform float alpha_antialiasing_edge;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0,128);
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform float specular;
uniform float metallic;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

uniform sampler2D erosion_tex;
uniform sampler2D base_erosion_curve;
uniform float erosion_offset_a;
uniform float erosion_offset_b;

uniform sampler2D mask;

uniform sampler2D color_ramp;

varying float lifetime;

void vertex() {
	lifetime = INSTANCE_CUSTOM.y;
	UV=UV*uv1_scale.xy+uv1_offset.xy;
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	albedo_tex *= COLOR;
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	
	ALPHA *= albedo.a * albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ALPHA_ANTIALIASING_EDGE = alpha_antialiasing_edge;
	//ALPHA_TEXTURE_COORDINATE = UV * vec2(albedo_texture_size);
	
	float erosion = texture(base_erosion_curve, vec2(lifetime)).r;
	float erosion_max_a = erosion + erosion_offset_a;
	float erosion_max_b = erosion + erosion_offset_b;
	
	float erosion_tex_value = texture(erosion_tex, UV).r;
	
	ALPHA *= smoothstep(erosion, erosion_max_a, erosion_tex_value);
	ALPHA *= texture(mask, UV).r;
	
	/*
	ALBEDO *= mix(
		texture(color_ramp, vec2(0.0)).rgb,
		texture(color_ramp, vec2(1.0)).rgb,
		ALBEDO.r
	);
	*/
	
	float depth_tex = textureLod(depth_texture,SCREEN_UV,0.0).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,depth_tex,1.0);
	world_pos.xyz/=world_pos.w;
	
	ALPHA*=clamp(1.0-smoothstep(world_pos.z+proximity_fade_distance,world_pos.z,VERTEX.z),0.0,1.0);
}
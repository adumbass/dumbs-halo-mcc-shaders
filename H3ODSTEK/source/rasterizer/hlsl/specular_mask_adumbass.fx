float calc_specular_mask_no_specular_mask_ps(
	in s_shader_data SHADER_DATA)
{
	return 1.0;
}

float calc_specular_mask_from_diffuse_ps(
	in s_shader_data SHADER_DATA)
{
	return SHADER_DATA.albedo.a;
}

PARAM_SAMPLER_2D(specular_mask_texture);
PARAM(float4, specular_mask_texture_xform);

PARAM_SAMPLER_2D(top_specular_mask_texture);
PARAM(float4, top_specular_mask_texture_xform);

PARAM(float, top_specular_mask_power);
PARAM(float, top_specular_mask_width);
PARAM(float, top_specular_blend_offset);
PARAM(float, top_specular_blend_sharpness);

float calc_specular_mask_texture_ps(
	in s_shader_data SHADER_DATA)
{
	float4 material= sample2D(specular_mask_texture, SHADER_DATA.common.texcoord * specular_mask_texture_xform.xy + specular_mask_texture_xform.zw);	//!adumbass Amit: why didn't they use transform_texcoord() function here
	return material.a;
}

float calc_specular_mask_texture_top_mask_ps(
	in s_shader_data SHADER_DATA)
{
	float4 material= sample2D(specular_mask_texture, SHADER_DATA.common.texcoord * specular_mask_texture_xform.xy + specular_mask_texture_xform.zw);

	float top_mask = calc_top_mask_vertex_ps(SHADER_DATA,
											top_specular_mask_power,
											top_specular_mask_width,
											top_specular_blend_offset,
											top_specular_blend_sharpness);
	float3 top_specular= sample_base_maps_ps(top_specular_mask_texture, top_specular_mask_texture_xform, SHADER_DATA);		// in tangent space

	material.a= lerp(material.a, top_specular, top_mask);
	return material.a;
}

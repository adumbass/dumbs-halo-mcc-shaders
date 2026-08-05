#include "parallax_occlusion.fx"
PARAM(float, height_scale);
PARAM_SAMPLER_2D(height_map);
PARAM(float4, height_map_xform);


float2 calc_parallax_off_ps(
	in s_shader_data SHADER_DATA)
{
	float2 parallax_texcoord= SHADER_DATA.common.texcoord;
	return parallax_texcoord;
}

float2 calc_parallax_simple_ps(
	in s_shader_data SHADER_DATA)
{
	float2 parallax_texcoord= transform_texcoord(SHADER_DATA.common.texcoord, height_map_xform);
	float height= (sample2D(height_map, parallax_texcoord).g - 0.5f) * height_scale;		// ###ctchou $PERF can switch height maps to be signed and get rid of this -0.5 bias
	parallax_texcoord= parallax_texcoord + height * SHADER_DATA.common.view_dir_in_tangent_space.xy;

	parallax_texcoord = (parallax_texcoord - height_map_xform.zw) / height_map_xform.xy;
	return parallax_texcoord;
}

float2 calc_parallax_two_sample_ps(
	in s_shader_data SHADER_DATA)
{
	float height= 0.0f;
	
	float2 parallax_texcoord= transform_texcoord(SHADER_DATA.common.texcoord, height_map_xform);
	float height_difference= (sample2D(height_map, parallax_texcoord).g - 0.5f) * height_scale - height;
	parallax_texcoord= parallax_texcoord + height_difference * SHADER_DATA.common.view_dir_in_tangent_space.xy;
	height= height + height_difference * SHADER_DATA.common.view_dir_in_tangent_space.z;
	
	height_difference= (sample2D(height_map, parallax_texcoord).g - 0.5f) * height_scale - height;
	parallax_texcoord= parallax_texcoord + height_difference * SHADER_DATA.common.view_dir_in_tangent_space.xy;
	
	/// height= height + height_difference * view_dir.z;
	parallax_texcoord= (parallax_texcoord - height_map_xform.zw) / height_map_xform.xy;
	return parallax_texcoord;

}

float2 calc_parallax_interpolated_ps(
	in s_shader_data SHADER_DATA)
{
	float2 temp_texcoord= transform_texcoord(SHADER_DATA.common.texcoord, height_map_xform);
	float cur_height= 0.0f;

	float height_1= (sample2D(height_map, temp_texcoord).g - 0.5f) * height_scale;	
	float height_difference= height_1 - cur_height;
	float2 step_offset= height_difference * SHADER_DATA.common.view_dir_in_tangent_space.xy;
	
	float2 parallax_texcoord= temp_texcoord + step_offset;
	cur_height= height_difference * SHADER_DATA.common.view_dir_in_tangent_space.z;
	
	float height_2= (sample2D(height_map, parallax_texcoord).g - 0.5f) * height_scale;
	
	height_difference= height_2 - cur_height;
	if (sign(height_difference) != sign(height_1 - cur_height))
	{
		float pct= height_1 / (cur_height - height_2 + height_1);
		parallax_texcoord= temp_texcoord + pct * step_offset;
	}
	else
	{
		parallax_texcoord= parallax_texcoord + height_difference * SHADER_DATA.common.view_dir_in_tangent_space.xy;		// view_dir.xy
//		float height_2= height_1 + height_difference * view_dir.z;
	}

	parallax_texcoord= (parallax_texcoord - height_map_xform.zw) / height_map_xform.xy;
	return parallax_texcoord;
}

//float2 calc_parallax_three_sample_ps()
//{
/*	
	parallax_texcoord= texcoord * height_map_xform.xy + height_map_xform.zw;

	float height= 0.0f;
	float height_difference= (sample2D(height_map, parallax_texcoord).g - 0.5f) * height_scale - height;
	parallax_texcoord= texcoord + height_difference * view_dir.xy;

	height= height + height_difference * view_dir.z;
	height_difference= (sample2D(height_map, parallax_texcoord).g - 0.5f) * height_scale - height;
	parallax_texcoord= parallax_texcoord + height_difference * view_dir.xy;

	height= height + height_difference * view_dir.z;
	height_difference= (sample2D(height_map, parallax_texcoord).g - 0.5f) * height_scale - height;
	parallax_texcoord= parallax_texcoord + height_difference * view_dir.xy;
*/
//}

PARAM_SAMPLER_2D(height_scale_map);
PARAM(float4, height_scale_map_xform);

float2 calc_parallax_simple_detail_ps(
	in s_shader_data SHADER_DATA)
{
	float2 parallax_texcoord= transform_texcoord(SHADER_DATA.common.texcoord, height_map_xform);
	float height= (sample2D(height_map, parallax_texcoord).g - 0.5f) * sample2D(height_scale_map, transform_texcoord(SHADER_DATA.common.texcoord, height_scale_map_xform)).g * height_scale;
	parallax_texcoord= parallax_texcoord + height * SHADER_DATA.common.view_dir_in_tangent_space.xy;

	parallax_texcoord= (parallax_texcoord - height_map_xform.zw) / height_map_xform.xy;
}


PARAM(float, parallax_sample_rate_scale);
/*
float2 calc_parallax_occlusion_ps(
	in s_shader_data SHADER_DATA)
{
	//texcoord = transform_texcoord(texcoord, height_map_xform);
	float2 parallax_texcoord= get_parallax_offset_uv(SHADER_DATA);
	return parallax_texcoord;
}
*/
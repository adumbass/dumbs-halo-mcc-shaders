#ifndef _glass_FX_
#define _glass_FX_

/*
glass_material.fx
Mon, Feb 19, 2007 5:41pm (haochen)
*/


//*****************************************************************************
// Analytical Diffuse-Only for point light source only
//*****************************************************************************


float get_material_glass_specular_power(float power_or_roughness)
{
	return 1.0f;
}

float3 get_analytical_specular_multiplier_glass_ps(float specular_mask)
{
	return 0.0f;
}

float3 get_diffuse_multiplier_glass_ps()
{
	return 1.0f;
}

void calc_material_analytic_specular_glass_ps(
	inout s_shader_data SHADER_DATA)
/*
	in float3 SHADER_DATA.common.view_dir,										// fragment to camera, in world space
	in float3 normal_dir,									// bumped fragment surface normal, in world space
	in float3 SHADER_DATA.common.view_reflect_dir,								// SHADER_DATA.common.view_dir reflected about surface normal, in world space
	in float3 light_dir,									// fragment to light, in world space
	in float3 light_irradiance,								// light intensity at fragment; i.e. light_color
	in float3 diffuse_albedo_color,							// diffuse reflectance (ignored for cook-torrance)
	in float2 SHADER_DATA.common.texcoord,
	in float vert_n_dot_l,
	in float3x3 SHADER_DATA.common.tangent_frame,
	out float4 SHADER_DATA.spatially_varying_material_parameters,							// only when use_material_texture is defined
	out float3 specular_fresnel_color,						// fresnel(SHADER_DATA.specular_albedo_color)
	out float3 SHADER_DATA.specular_albedo_color,						// specular reflectance at normal incidence
	out float3 SHADER_DATA.analytic_specular_radiance)					// return specular radiance from this light				<--- ONLY REQUIRED OUTPUT FOR DYNAMIC LIGHTS
	*/
{
	SHADER_DATA.specular_fresnel_color= 0.0f;
	SHADER_DATA.analytic_specular_radiance= 0.0f;
	SHADER_DATA.specular_albedo_color= 0.0f;
	SHADER_DATA.spatially_varying_material_parameters= 1.0f;
}

PARAM(float, fresnel_coefficient);
PARAM(float, fresnel_curve_steepness);
PARAM(float, fresnel_curve_bias);
PARAM(float, roughness);

void calc_material_glass_ps(
	in float4 sh_lighting_coefficients[10],
	inout s_shader_data SHADER_DATA)
	/*
	in float3 SHADER_DATA.common.view_dir,
	in float3 SHADER_DATA.common.fragment_to_camera_world,
	in float3 SHADER_DATA.bump_normal,
	in float3 SHADER_DATA.common.view_reflect_dir,
	in float4 sh_lighting_coefficients[10],
	in float3 SHADER_DATA.dominant_light_direction,
	in float3 SHADER_DATA.dominant_light_intensity,
	in float3 SHADER_DATA.albedo.rgb,
	in float  SHADER_DATA.specular_mask,
	in float2 SHADER_DATA.common.texcoord,
	in float4 SHADER_DATA.prt_ravi_diff,
	in float3x3 SHADER_DATA.common.tangent_frame,				// = {tangent, binormal, normal};
	out float4 SHADER_DATA.envmap_specular_reflectance_and_roughness,
	out float3 SHADER_DATA.envmap_area_specular_only,
	out float4 SHADER_DATA.specular_radiance,
	inout float3 SHADER_DATA.diffuse_radiance)*/
{

	//float3 SHADER_DATA.common.fragment_position_world= Camera_Position_PS - SHADER_DATA.common.fragment_to_camera_world;
	
	float3 area_specular= 0.0f;
	if (area_specular_contribution > 0.0f)
	{
		calculate_area_specular_new_phong_3(
			SHADER_DATA.common.view_reflect_dir,
			sh_lighting_coefficients,
			roughness,
			false,
			area_specular);
	}
		
	float3 analytical_specular= 0.0f;
	if (analytical_specular_contribution > 0.0f)
	{
		calculate_analytical_specular_new_phong_3(
			SHADER_DATA.dominant_light_direction,
			SHADER_DATA.dominant_light_intensity,
			SHADER_DATA.common.view_reflect_dir,
			roughness,
			analytical_specular);
	}
		
	//float3 SHADER_DATA.simple_light_diffuse_light;
	//float3 SHADER_DATA.simple_light_diffuse_light;
	
	if (!no_dynamic_lights)
	{
		calc_simple_lights_analytical(
			SHADER_DATA.common.fragment_position_world,
			SHADER_DATA.bump_normal,
			SHADER_DATA.common.view_reflect_dir,											// view direction = fragment to camera,   reflected around fragment normal
			0.27291 * pow(roughness, -2.1973),
			SHADER_DATA.simple_light_diffuse_light,
			SHADER_DATA.simple_light_diffuse_light);
	}
	else
	{
		SHADER_DATA.simple_light_diffuse_light= 0.0f;
		SHADER_DATA.simple_light_diffuse_light= 0.0f;
	}
		
	float fresnel= fresnel_coefficient+(1.0f - fresnel_coefficient) * pow(1.0 - max(dot(SHADER_DATA.bump_normal, SHADER_DATA.common.view_dir), 0.0f), fresnel_curve_steepness) + fresnel_curve_bias;
	SHADER_DATA.specular_radiance.xyz= (area_specular * area_specular_contribution + analytical_specular * analytical_specular_contribution + SHADER_DATA.simple_light_diffuse_light) * specular_coefficient * SHADER_DATA.specular_mask;
	SHADER_DATA.specular_radiance.w= fresnel;
	SHADER_DATA.diffuse_radiance= (SHADER_DATA.diffuse_radiance + SHADER_DATA.simple_light_diffuse_light) * diffuse_coefficient;
	float env_multiplyer= specular_coefficient * fresnel * SHADER_DATA.specular_mask;
	SHADER_DATA.envmap_specular_reflectance_and_roughness= float4(env_multiplyer, env_multiplyer, env_multiplyer, roughness);
	SHADER_DATA.envmap_area_specular_only= sh_lighting_coefficients[0].xyz;
}


#endif // _glass_FX_
float get_material_none_specular_power(float power_or_roughness)
{
	return 1.0f;
}

float3 get_analytical_specular_multiplier_none_ps(float specular_mask)
{
	return 0.0f;
}

float3 get_diffuse_multiplier_none_ps()
{
	return 1.0f;
}

void calc_material_analytic_specular_none_ps(
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
	out float4 SHADER_DATA.spatially_varying_material_parameters,
	out float3 specular_fresnel_color,						// fresnel(SHADER_DATA.specular_albedo_color)
	out float3 SHADER_DATA.specular_albedo_color,						// specular reflectance at normal incidence
	out float3 SHADER_DATA.analytic_specular_radiance)					// return specular radiance from this light				<--- ONLY REQUIRED OUTPUT FOR DYNAMIC LIGHTS
	*/
{
	SHADER_DATA.specular_fresnel_color= 0.0f;
	SHADER_DATA.analytic_specular_radiance= 0.0f;
	SHADER_DATA.specular_albedo_color= 0.0f;
	SHADER_DATA.spatially_varying_material_parameters= 0.0f;
}

void calc_material_none_ps(
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
	SHADER_DATA.diffuse_radiance= 0.0f;
	SHADER_DATA.specular_radiance= 0.0f;
	
	SHADER_DATA.envmap_specular_reflectance_and_roughness= float4(1.0f, 1.0f, 1.0f, 0.0f);
	SHADER_DATA.envmap_area_specular_only= 0.0f;	
}



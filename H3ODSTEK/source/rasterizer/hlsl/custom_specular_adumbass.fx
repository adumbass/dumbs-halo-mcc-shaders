#ifndef _CUSTOM_SPECULAR_FX_
#define _CUSTOM_SPECULAR_FX_


//****************************************************************************
// custom specular
//****************************************************************************

PARAM_SAMPLER_2D(specular_lobe);						// specular power, tint	(indexed by direction towards sun, and material map)
PARAM_SAMPLER_2D(glancing_falloff);						// fresnel curve
PARAM_SAMPLER_2D(material_map);							// material map -- 
PARAM(float4, material_map_xform);						// 

// float analytical_anti_shadow_control;				// do we need?


//*****************************************************************************
// Analytical model for point light source only
//*****************************************************************************
float get_material_custom_specular_specular_power(float power_or_roughness)
{
	return power_or_roughness;
}

float3 get_analytical_specular_multiplier_custom_specular_ps(float SHADER_DATA.specular_mask)
{
	return SHADER_DATA.specular_mask * specular_coefficient * analytical_specular_contribution;
}

float3 get_diffuse_multiplier_custom_specular_ps()
{
	return diffuse_coefficient;
}

void calc_material_analytic_specular_custom_specular_ps(
	inout s_shader_data SHADER_DATA)
/*
	in float3 SHADER_DATA.common.view_dir,										// fragment to camera, in world space
	in float3 normal_dir,									// bumped fragment surface normal, in world space
	in float3 SHADER_DATA.common.view_reflect_dir,								// SHADER_DATA.common.view_dir reflected about surface normal, in world space
	in float3 light_dir,									// fragment to light, in world space
	in float3 light_irradiance,								// light intensity at fragment; i.e. light_color
	in float3 diffuse_albedo_color,							// diffuse reflectance (ignored for cook-torrance)
	in float2 SHADER_DATA.common.texcoord,
	in float vertex_n_dot_l,
	in float3x3 SHADER_DATA.common.tangent_frame,
	out float4 SHADER_DATA.spatially_varying_material_parameters,							// only when use_material_texture is defined
	out float3 specular_fresnel_color,						// fresnel(SHADER_DATA.specular_albedo_color)
	out float3 SHADER_DATA.specular_albedo_color,						// specular reflectance at normal incidence
	out float3 SHADER_DATA.analytic_specular_radiance)					// return specular radiance from this light				<--- ONLY REQUIRED OUTPUT FOR DYNAMIC LIGHTS
	*/
{
	float3 SHADER_DATA.bump_normal= SHADER_DATA.common.tangent_frame[2];

	SHADER_DATA.spatially_varying_material_parameters.rgb= float3(specular_coefficient, 0.0f /* albedo_specular_tint_blend */, environment_map_specular_contribution);
	SHADER_DATA.spatially_varying_material_parameters.a= 50.0f;	// power_or_roughness;

    float n_dot_v = dot(normal_dir, SHADER_DATA.common.view_dir);
#ifdef _xenon	
    specular_fresnel_color=	tex1D(glancing_falloff, n_dot_v).rgb;
#else
	specular_fresnel_color=	sample2D(glancing_falloff, float2(n_dot_v, 0)).rgb;
#endif

	// half-angle formula
	float3 half_dir=	normalize(SHADER_DATA.common.view_dir + light_dir);
	float h_dot_n=		saturate(dot(half_dir, normal_dir));

	//float material_sample=		sample2D(material_map, transform_texcoord(SHADER_DATA.common.texcoord, material_map_xform)).g;
	float material_sample=		sample_base_maps_ps(material_map, material_map_xform, SHADER_DATA).g;

	float4 lobe_sample=	sample2D(specular_lobe, float2(h_dot_n, material_sample));

	SHADER_DATA.analytic_specular_radiance= light_irradiance * specular_fresnel_color * lobe_sample.rgb * lobe_sample.rgb;
	SHADER_DATA.specular_albedo_color= float3(1.0f, 1.0f, 1.0f);		// specular_tint
}


//*****************************************************************************
// the material model
//*****************************************************************************
	
void calc_material_custom_specular_ps(
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
	inout float3 SHADER_DATA.diffuse_radiance)
{
	float3 SHADER_DATA.analytic_specular_radiance;
	float3 specular_fresnel_color;
	float3 SHADER_DATA.specular_albedo_color;
	float4 SHADER_DATA.spatially_varying_material_parameters;
	
	calc_material_analytic_specular_custom_specular_ps(
		SHADER_DATA);
		/*
		SHADER_DATA.common.view_dir,
		SHADER_DATA.bump_normal,
		SHADER_DATA.common.view_reflect_dir,
		SHADER_DATA.dominant_light_direction,
		SHADER_DATA.dominant_light_intensity,
		SHADER_DATA.albedo.rgb,
		SHADER_DATA.common.texcoord,
		SHADER_DATA.prt_ravi_diff.w,
		SHADER_DATA.common.tangent_frame,
		SHADER_DATA.spatially_varying_material_parameters,
		specular_fresnel_color,
		SHADER_DATA.specular_albedo_color,
		SHADER_DATA.analytic_specular_radiance);
		*/

/*		
	// apply anti-shadow
	if (analytical_anti_shadow_control > 0.0f)
	{
		float4 temp[4]= {sh_lighting_coefficients[0], sh_lighting_coefficients[1], sh_lighting_coefficients[2], sh_lighting_coefficients[3]};
		float ambientness= calculate_ambientness(temp, SHADER_DATA.dominant_light_intensity, SHADER_DATA.dominant_light_direction);
		float ambient_multiplier= pow((1-ambientness), analytical_anti_shadow_control * 100.0f);
		SHADER_DATA.analytic_specular_radiance*= ambient_multiplier;
	}
*/
/*
	// calculate simple dynamic lights	
	float3 SHADER_DATA.simple_light_diffuse_light;//= 0.0f;
	float3 SHADER_DATA.simple_light_diffuse_light;//= 0.0f;	
	
	if (!no_dynamic_lights)
	{
		float3 SHADER_DATA.common.fragment_position_world= Camera_Position_PS - SHADER_DATA.common.fragment_to_camera_world;
		calc_simple_lights_analytical(
			SHADER_DATA.common.fragment_position_world,
			SHADER_DATA.bump_normal,
	//		SHADER_DATA.common.fragment_to_camera_world,
			SHADER_DATA.common.view_reflect_dir,												// view direction = fragment to camera,   reflected around fragment normal
			SHADER_DATA.spatially_varying_material_parameters.a,
			SHADER_DATA.simple_light_diffuse_light,
			SHADER_DATA.simple_light_diffuse_light);
	}
	else
	{
		SHADER_DATA.simple_light_diffuse_light= 0.0f;
		SHADER_DATA.simple_light_diffuse_light= 0.0f;
	}
*/

/*	
	float3 area_specular_radiance;
	if (order3_area_specular)
	{
		calculate_area_specular_phong_order_3(
			SHADER_DATA.common.view_reflect_dir,
			sh_lighting_coefficients,
			SHADER_DATA.spatially_varying_material_parameters.a,
			specular_fresnel_color,
			area_specular_radiance);
	}
	else
	{
		float4 temp[4]= {sh_lighting_coefficients[0], sh_lighting_coefficients[1], sh_lighting_coefficients[2], sh_lighting_coefficients[3]};

		calculate_area_specular_phong_order_2(
			SHADER_DATA.common.view_reflect_dir,
			temp,
			SHADER_DATA.spatially_varying_material_parameters.a,
			specular_fresnel_color,
			area_specular_radiance);
	}
*/
	
	//scaling and masking
//	SHADER_DATA.specular_radiance.xyz= SHADER_DATA.specular_mask * SHADER_DATA.spatially_varying_material_parameters.r * (
//		(SHADER_DATA.simple_light_diffuse_light + max(SHADER_DATA.analytic_specular_radiance, 0.0f)) * analytical_specular_contribution +
//		max(area_specular_radiance * area_specular_contribution, 0.0f));

	SHADER_DATA.specular_radiance.xyz=	SHADER_DATA.specular_mask * (SHADER_DATA.analytic_specular_radiance * SHADER_DATA.spatially_varying_material_parameters.r);	
	SHADER_DATA.specular_radiance.w= 0.0f;

	//modulate with prt	
	SHADER_DATA.specular_radiance*= SHADER_DATA.prt_ravi_diff.z;

	//output for environment stuff
	SHADER_DATA.envmap_area_specular_only= SHADER_DATA.prt_ravi_diff.z;		// area_specular_radiance * 
	SHADER_DATA.envmap_specular_reflectance_and_roughness.xyz=	specular_fresnel_color * SHADER_DATA.specular_mask * SHADER_DATA.spatially_varying_material_parameters.b * SHADER_DATA.spatially_varying_material_parameters.r;
	SHADER_DATA.envmap_specular_reflectance_and_roughness.w=	0.0f;					// max(0.01f, 1.01 - SHADER_DATA.spatially_varying_material_parameters.a / 200.0f);		// convert specular power to roughness (cheap and bad approximation);

	//do diffuse
	//float3 diffuse_part= ravi_order_3(SHADER_DATA.bump_normal, sh_lighting_coefficients);
	SHADER_DATA.diffuse_radiance= SHADER_DATA.prt_ravi_diff.x * SHADER_DATA.diffuse_radiance;
//	SHADER_DATA.diffuse_radiance= (SHADER_DATA.simple_light_diffuse_light + SHADER_DATA.diffuse_radiance) * diffuse_coefficient;
	SHADER_DATA.diffuse_radiance= SHADER_DATA.diffuse_radiance * diffuse_coefficient;
}


#endif 
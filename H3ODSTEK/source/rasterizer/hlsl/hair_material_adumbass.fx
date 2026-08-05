#ifndef _HAIR_MATERIAL_FX_
#define _HAIR_MATERIAL_FX_

/*
hair_material.fx
Mon, Feb 4, 2008 2:01pm (xwan)
*/

//****************************************************************************
// Organism material model parameters
//****************************************************************************

// diffuse
PARAM(float3, diffuse_tint);

// specular from lighting
PARAM(float, area_specular_coefficient);
PARAM(float, analytical_specular_coefficient);
PARAM(float3, specular_tint);
PARAM(float, specular_power);
PARAM_SAMPLER_2D(specular_map);
PARAM_SAMPLER_2D(specular_shift_map);
PARAM_SAMPLER_2D(specular_noise_map);

// specular from environment map
PARAM(float, environment_map_coefficient);
PARAM(float3, environment_map_tint);

// final tint
PARAM(float3, final_tint);

PARAM(float, analytical_anti_shadow_control);

#ifdef pc
	#define FORCE_BRANCH
#else
	#define FORCE_BRANCH	[branch]
#endif

void calc_material_analytic_specular_hair(	
	in float3 tangent_dir,									// tangent direction in world space
	in float3 reflect_half,								// SHADER_DATA.common.view_dir reflected about surface normal, in world space
	in float3 light_dir,									// fragment to light, in world space
	in float3 light_irradiance,								// light intensity at fragment; i.e. light_color	
	float power_or_roughness,
	out float3 analytic_specular_radiance)	
{   	
	const float t_dot_h = dot(tangent_dir, reflect_half); 	
	//if ( t_dot_h > 0 )
	{
		const float sin_t_h= sqrt( 1.0f - t_dot_h*t_dot_h);        
		analytic_specular_radiance= pow(sin_t_h, power_or_roughness) * light_irradiance;
	}
	//else
	//{
	//	analytic_specular_radiance= 0.0f;
	//}
}


void calculate_area_specular_phong_order_2(
	in float3 reflection_dir,
	in float4 sh_lighting_coefficients[10],		
	out float3 s0)
{
															//float power_invert= 0.5f;
	float p_0= 0.4231425f;									// 0.886227f			0.282095f * 1.5f;
	float p_1= -0.3805236f;									// 0.511664f * -2		exp(-0.5f * power_invert) * (-0.488602f);
	float p_2= -0.4018891f;									// 0.429043f * -2		exp(-2.0f * power_invert) * (-1.092448f);
	float p_3= -0.2009446f;									// 0.429043f * -1

	float3 x0, x1, x2, x3;
	
	//constant
	x0= sh_lighting_coefficients[0].r * p_0;
	
	// linear
	x1.r=  dot(reflection_dir, sh_lighting_coefficients[1]);
	x1.g=  dot(reflection_dir, sh_lighting_coefficients[2]);
	x1.b=  dot(reflection_dir, sh_lighting_coefficients[3]);
	x1 *= p_1;
	
	//s0= x0 + x1;		
	s0= x1;
}

//*****************************************************************************
// the material model
//*****************************************************************************
	
void calc_material_hair_ps(	
	in float4 sh_lighting_coefficients[10],
	inout s_shader_data SHADER_DATA)
/*
	in float3 SHADER_DATA.common.view_dir,
	in float3 SHADER_DATA.common.fragment_to_camera_world,
	in float3 bump_normal,
	in float3 view_reflect_by_bump_dir,
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
	const float3 surface_tangent= SHADER_DATA.common.tangent_frame[1];
	const float3 surface_normal= SHADER_DATA.common.tangent_frame[2];

	//const float3 SHADER_DATA.bump_normal= SHADER_DATA.common.tangent_frame[2];
	
	float specular_shift= sample2D(specular_shift_map, SHADER_DATA.common.texcoord).x;
	specular_shift-= 0.5f;
	float specular_noise= sample2D(specular_noise_map, SHADER_DATA.common.texcoord).x;

	float3 tangent_0= surface_tangent + surface_normal*specular_shift;
	float3 tangent_1= surface_tangent - surface_normal*specular_shift*specular_noise;
	normalize(tangent_0);
	normalize(tangent_1);


	float3 bi_view_dir= cross(SHADER_DATA.common.view_dir, surface_tangent);		

	
	float3 area_specular_normal_0= cross(tangent_0, bi_view_dir);
	normalize(area_specular_normal_0);		
	float3 view_reflect_by_hair_0= reflect(-SHADER_DATA.common.view_dir, area_specular_normal_0);	

	float3 area_specular_normal_1= cross(tangent_1, bi_view_dir);
	normalize(area_specular_normal_1);		
	float3 view_reflect_by_hair_1= reflect(-SHADER_DATA.common.view_dir, area_specular_normal_1);	
	

	// sample specular map
	float4 specular_map_color= sample2D(specular_map, SHADER_DATA.common.texcoord);
	float power_or_roughness= specular_map_color.a * specular_power;	

	// calculate simple dynamic lights	
	//float3 SHADER_DATA.common.fragment_position_world= Camera_Position_PS - SHADER_DATA.common.fragment_to_camera_world;
	float3 simple_lights_bump_diffuse= 0.0f;
	float3 simple_lights_bump_specular_0= 0.0f;
	float3 simple_lights_bump_specular_1= 0.0f;
	
	if (!no_dynamic_lights)
	{			
		calc_simple_lights_analytical(
			SHADER_DATA.common.fragment_position_world,
			area_specular_normal_0,
			view_reflect_by_hair_0,	
			sqrt(power_or_roughness), // dim the power as a hack
			simple_lights_bump_diffuse,
			simple_lights_bump_specular_0);

		calc_simple_lights_analytical(
			SHADER_DATA.common.fragment_position_world,
			area_specular_normal_1,
			view_reflect_by_hair_1,	
			sqrt(power_or_roughness), // dim the power as a hack
			simple_lights_bump_diffuse,
			simple_lights_bump_specular_1);
	}

	// calculate diffuse color
	float3 diffuse_color;
	{
		diffuse_color= 
			(simple_lights_bump_diffuse + SHADER_DATA.diffuse_radiance) * 
			diffuse_coefficient * diffuse_tint; // * albedo.xyz * albedo.w
	}

	// calculate specular from analytic and area
	//float3 SHADER_DATA.analytic_specular_radiance;
	{
		float3 reflect_half= SHADER_DATA.common.view_dir + SHADER_DATA.dominant_light_direction;
		reflect_half= normalize(reflect_half);

		float3 specular_0, specular_1;
		calc_material_analytic_specular_hair(	
			tangent_0,
			reflect_half,
			SHADER_DATA.dominant_light_direction,
			SHADER_DATA.dominant_light_intensity,		
			power_or_roughness,
			specular_0);

		calc_material_analytic_specular_hair(	
			tangent_1,
			reflect_half,
			SHADER_DATA.dominant_light_direction,
			SHADER_DATA.dominant_light_intensity,		
			power_or_roughness*specular_noise,
			specular_1);

		SHADER_DATA.analytic_specular_radiance= 
			specular_0 + simple_lights_bump_specular_0 + 
			(specular_1 + simple_lights_bump_specular_1) *specular_noise;
	}

	float3 area_specular_radiance;
	{
		calculate_area_specular_phong_order_2(			
			view_reflect_by_hair_1,
			sh_lighting_coefficients,						
			area_specular_radiance);
		area_specular_radiance= max(area_specular_radiance, 0);
	}

	SHADER_DATA.specular_radiance.xyz=
		SHADER_DATA.analytic_specular_radiance*analytical_specular_coefficient + 
		area_specular_radiance*area_specular_coefficient;

	SHADER_DATA.specular_radiance.xyz*=
		specular_tint * specular_map_color.rgb;


	// calculate environment parameters
	{
		SHADER_DATA.envmap_area_specular_only= SHADER_DATA.prt_ravi_diff.z;
		SHADER_DATA.envmap_specular_reflectance_and_roughness.xyz= environment_map_tint * environment_map_coefficient * specular_map_color.rgb;
		SHADER_DATA.envmap_specular_reflectance_and_roughness.w= 1.0f;
	}
	
	//do color output
	SHADER_DATA.specular_radiance.xyz=
		SHADER_DATA.specular_radiance;
	SHADER_DATA.specular_radiance.w= 1.0f; 	
	
	//do albedo
	SHADER_DATA.diffuse_radiance= 		
		diffuse_color;

	// final tint
	SHADER_DATA.specular_radiance.xyz*= final_tint * SHADER_DATA.prt_ravi_diff.z;
	SHADER_DATA.diffuse_radiance*= final_tint * SHADER_DATA.prt_ravi_diff.x;
}


////////////////////////////////////////////////////////////////////////////////////////////
// No idea
////////////////////////////////////////////////////////////////////////////////////////////

float3 get_analytical_specular_multiplier_hair_ps(float specular_mask)
{
	return 1.0f;
}

float3 get_diffuse_multiplier_hair_ps()
{
	return 0.0f;
}

void calc_material_analytic_specular_hair_ps(
	inout s_shader_data SHADER_DATA)
/*
	in float3 SHADER_DATA.common.view_dir,										// fragment to camera, in world space
	in float3 bump_normal,									// bumped fragment surface normal, in world space
	in float3 view_reflect_by_bump_dir,						// SHADER_DATA.common.view_dir reflected about surface normal, in world space
	in float3 light_dir,									// fragment to light, in world space
	in float3 light_irradiance,								// light intensity at fragment; i.e. light_color
	in float3 diffuse_albedo_color,							// diffuse reflectance (ignored for cook-torrance) // SHADER_DATA.albedo
	in float2 SHADER_DATA.common.texcoord,
	in float vertex_n_dot_l,
	in float3x3 SHADER_DATA.common.tangent_frame,
	out float4 SHADER_DATA.spatially_varying_material_parameters,							// only when use_material_texture is defined
	out float3 specular_fresnel_color,						// fresnel(SHADER_DATA.specular_albedo_color)
	out float3 SHADER_DATA.specular_albedo_color,						// specular reflectance at normal incidence
	out float3 SHADER_DATA.analytic_specular_radiance)					// return specular radiance from this light				<--- ONLY REQUIRED OUTPUT FOR DYNAMIC LIGHTS
	*/
{
	//float3 SHADER_DATA.bump_normal= SHADER_DATA.common.tangent_frame[2];
	float3 surface_normal= SHADER_DATA.common.tangent_frame[2];
	float3 surface_tangent= SHADER_DATA.common.tangent_frame[1];

	// sample specular map
	float4 specular_map_color= sample2D(specular_map, SHADER_DATA.common.texcoord);
	float power_or_roughness= specular_map_color.a * specular_power;	

	// calculate diffuse color
	//float3 simple_lights_bump_diffuse= saturate(dot(SHADER_DATA.dominant_light_intensity, bump_normal)) * SHADER_DATA.dominant_light_intensity;
	float3 simple_lights_bump_diffuse= saturate(dot(SHADER_DATA.dominant_light_direction, SHADER_DATA.bump_normal)) * SHADER_DATA.dominant_light_intensity;	
	float3 diffuse_color= 
			simple_lights_bump_diffuse * diffuse_coefficient * diffuse_tint;

	// calculate specular from analytic and area
		// calculate specular from analytic and area
	float3 specular_color;
	{
		float3 reflect_half= SHADER_DATA.common.view_dir + SHADER_DATA.dominant_light_direction;
		reflect_half= normalize(reflect_half);

		float specular_shift= sample2D(specular_shift_map, SHADER_DATA.common.texcoord).x;
		specular_shift-= 0.5f;

		float specular_noise= sample2D(specular_noise_map, SHADER_DATA.common.texcoord).x;

		float3 tangent_0= surface_tangent + surface_normal*specular_shift;
		float3 tangent_1= surface_tangent - surface_normal*specular_shift*specular_noise;
		normalize(tangent_0);
		normalize(tangent_1);

		float3 specular_0, specular_1;
		calc_material_analytic_specular_hair(
			tangent_0,
			reflect_half,
			SHADER_DATA.dominant_light_direction,
			SHADER_DATA.dominant_light_intensity,		
			power_or_roughness,
			specular_0);

		calc_material_analytic_specular_hair(	
			tangent_1,
			reflect_half,
			SHADER_DATA.dominant_light_direction,
			SHADER_DATA.dominant_light_intensity,		
			power_or_roughness*specular_noise,
			specular_1);

		specular_color= specular_0 + specular_1*specular_noise;
	}

	specular_color*= analytical_specular_coefficient *
			specular_tint * specular_map_color.rgb;

	//do color output
	SHADER_DATA.analytic_specular_radiance= 			
		specular_color+ 				
		diffuse_color * SHADER_DATA.albedo.rgb;

	SHADER_DATA.analytic_specular_radiance*= final_tint;

	// bullshits
	SHADER_DATA.spatially_varying_material_parameters= 0.0f;
	SHADER_DATA.specular_fresnel_color= 0.0f;
	SHADER_DATA.specular_albedo_color= 0.0f;
}

#undef FORCE_BRANCH
#endif //_HAIR_MATERIAL_FX_
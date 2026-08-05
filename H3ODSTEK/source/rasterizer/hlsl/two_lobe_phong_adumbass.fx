#ifndef _TWO_LOBE_PHONG_FX_
#define _TWO_LOBE_PHONG_FX_

/*
two_lobe_phong.fx
Mon, Nov 11, 2005 2:01pm (haochen)
*/

//****************************************************************************
// Two lobe phong material model parameters
//****************************************************************************

PARAM(float,	normal_specular_power);						// power of the specular lobe at normal incident angle
PARAM(float3,	normal_specular_tint);						// specular color of the normal specular lobe
PARAM(float,	glancing_specular_power);					// power of the specular lobe at glancing incident angle
PARAM(float3,	glancing_specular_tint);					// specular color of the glancing specular lobe
PARAM(float,	fresnel_curve_steepness);					// 
PARAM(float,	albedo_specular_tint_blend);				// mix albedo color into specular reflectance

PARAM(float, analytical_anti_shadow_control);

//*****************************************************************************
// artist fresnel
//*****************************************************************************

void calculate_fresnel(
	in float3 view_dir,				
	in float3 normal_dir,
	in float3 albedo_color,
	out float power,
	out float3 tint)
{
	//float n_dot_v = dot( normal_dir, view_dir );
    float n_dot_v = max(dot( normal_dir, view_dir ), 0.0f);
    float fresnel_blend= pow((1.0f - n_dot_v ), fresnel_curve_steepness); 
    power= lerp(normal_specular_power, glancing_specular_power, fresnel_blend);
    //float3 normal_tint= lerp(normal_specular_tint, albedo_color, albedo_specular_tint_blend);
    //tint= lerp(normal_tint, glancing_specular_tint, fresnel_blend);

    tint= lerp(normal_specular_tint, glancing_specular_tint, fresnel_blend);
    tint= lerp(tint, albedo_color, albedo_specular_tint_blend);
}

//*****************************************************************************
// Analytical model for point light source only
//*****************************************************************************

float get_material_two_lobe_phong_specular_power(float power_or_roughness)
{
	return power_or_roughness;
}


float3 get_analytical_specular_multiplier_two_lobe_phong_ps(float specular_mask)
{
	return specular_mask * specular_coefficient * analytical_specular_contribution;
}

float3 get_diffuse_multiplier_two_lobe_phong_ps()
{
	return diffuse_coefficient;
}

void calc_material_analytic_specular_two_lobe_phong_ps(
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
	out float3 SHADER_DATA.specular_fresnel_color,						// fresnel(SHADER_DATA.specular_albedo_color)
	out float3 SHADER_DATA.specular_albedo_color,						// specular reflectance at normal incidence
	out float3 SHADER_DATA.analytic_specular_radiance)					// return specular radiance from this light				<--- ONLY REQUIRED OUTPUT FOR DYNAMIC LIGHTS
	*/
{
	//float3 SHADER_DATA.bump_normal= SHADER_DATA.common.tangent_frame[2]; // isn't used

	//figure out the blended power and blended specular tint
	float power_or_roughness= 0.0f;
	SHADER_DATA.specular_fresnel_color= 0.0f; //7/13/2026 specular_fresnel_color to SHADER_DATA.specular_fresnel_color
	// open all material files and replace common values at the same time
	// looking at foliage_material and organism_material, different names are used lol
	// still have to go through all the material_model fx so many name changes..
	calculate_fresnel(SHADER_DATA.common.view_dir, SHADER_DATA.bump_normal, SHADER_DATA.albedo.rgb, power_or_roughness, SHADER_DATA.specular_fresnel_color);
	SHADER_DATA.specular_albedo_color= normal_specular_tint;
	SHADER_DATA.spatially_varying_material_parameters.rgb= float3(specular_coefficient, albedo_specular_tint_blend, environment_map_specular_contribution);
	SHADER_DATA.spatially_varying_material_parameters.a= power_or_roughness;
    
	float l_dot_r = dot(SHADER_DATA.dominant_light_direction, SHADER_DATA.common.view_reflect_dir); 

    if (l_dot_r > 0)
    {
		//SHADER_DATA.analytic_specular_radiance= pow(l_dot_r, power_or_roughness) * ((sqrt(power_or_roughness) + 1.0f) / 6.2832) * SHADER_DATA.specular_fresnel_color * light_irradiance;
		SHADER_DATA.analytic_specular_radiance= pow(l_dot_r, power_or_roughness) * ((power_or_roughness + 1.0f) / 6.2832) * SHADER_DATA.specular_fresnel_color * SHADER_DATA.dominant_light_intensity;
	}
	else
	{
		SHADER_DATA.analytic_specular_radiance= 0.0f;
	}
}


/*
void calculate_analytical_phong(
  	in float3 normal_dir,
	in float3 SHADER_DATA.common.view_dir,	
	in float3 reflect_dir,
	in float3 light_dir,
	in float3 light_color,
	in float power,
	in float3 tint,
	out float3 specular)
{			
    float n_dot_l = dot( normal_dir, light_dir );
    float n_dot_v = dot( normal_dir, SHADER_DATA.common.view_dir );
    float l_dot_r = max(dot(light_dir, reflect_dir), 0.0f); 
    
    if (n_dot_l > 0 && n_dot_v > 0 )
    {
		specular= pow(l_dot_r, power) * ((power + 1.0f) / 6.2832) * tint * light_color;
	}
	else
	{
		specular= 0.0f;
	}
}
*/


//*****************************************************************************
// area specular for area light source
//*****************************************************************************
void calculate_area_specular_phong_order_3(
	in float3 reflection_dir,
	in float4 sh_lighting_coefficients[10],
	in float power,
	in float3 tint,
	out float3 s0)
{
	
	//float power_invert= 1.0f/(power+ 0.00001f);
	//float p_0= 0.282095f * 1.5f;
	//float p_1= exp(-0.5f * power_invert) * (-0.488602f);
	//float p_2= exp(-2.0f * power_invert) * (-1.092448f);
	
	float p_0= 0.4231425f;									// 0.886227f			0.282095f * 1.5f;
	float p_1= -0.3805236f;									// 0.511664f * -2		exp(-0.5f * power_invert) * (-0.488602f);
	float p_2= -0.4018891f;									// 0.429043f * -2		exp(-2.0f * power_invert) * (-1.092448f);
	float p_3= -0.2009446f;									// 0.429043f * -1

	float3 x0, x1, x2, x3;
	
	//constant
	x0= sh_lighting_coefficients[0].r * p_0;
	
	// linear
	x1.r=  dot(reflection_dir, sh_lighting_coefficients[1].xyz);
	x1.g=  dot(reflection_dir, sh_lighting_coefficients[2].xyz);
	x1.b=  dot(reflection_dir, sh_lighting_coefficients[3].xyz);
	x1 *= p_1;
	
	//quadratic
	float3 quadratic_a= (reflection_dir.xyz)*(reflection_dir.yzx);
	x2.x= dot(quadratic_a, sh_lighting_coefficients[4].xyz);
	x2.y= dot(quadratic_a, sh_lighting_coefficients[5].xyz);
	x2.z= dot(quadratic_a, sh_lighting_coefficients[6].xyz);
	x2 *= p_2;

	float4 quadratic_b = float4( reflection_dir.xyz*reflection_dir.xyz, 1.f/3.f );
	x3.x= dot(quadratic_b, sh_lighting_coefficients[7]);
	x3.y= dot(quadratic_b, sh_lighting_coefficients[8]);
	x3.z= dot(quadratic_b, sh_lighting_coefficients[9]);
	x3 *= p_3;
	
	s0= (x0 + x1 + x2 + x3) * tint;
		
}

void calculate_area_specular_phong_order_2(
	in float3 reflection_dir,
	in float4 sh_lighting_coefficients[4],
	in float power,
	in float3 tint,
	out float3 s0)
{

	float p_0= 0.4231425f;									// 0.886227f			0.282095f * 1.5f;
	float p_1= -0.3805236f;									// 0.511664f * -2		exp(-0.5f * power_invert) * (-0.488602f);
	float p_2= -0.4018891f;									// 0.429043f * -2		exp(-2.0f * power_invert) * (-1.092448f);
	float p_3= -0.2009446f;									// 0.429043f * -1

	float3 x0, x1, x2, x3;
	
	//constant
	x0= sh_lighting_coefficients[0].r * p_0;
	
	// linear
	x1.r=  dot(reflection_dir, sh_lighting_coefficients[1].xyz);
	x1.g=  dot(reflection_dir, sh_lighting_coefficients[2].xyz);
	x1.b=  dot(reflection_dir, sh_lighting_coefficients[3].xyz);
	x1 *= p_1;
	
	s0= (x0 + x1 ) * tint;
		
}

//*****************************************************************************
// the material model
//*****************************************************************************
	
void calc_material_two_lobe_phong_ps(
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
/*	calculate_analytical_phong(
		SHADER_DATA.bump_normal, 
		SHADER_DATA.common.view_dir,
		SHADER_DATA.common.view_reflect_dir,
		SHADER_DATA.dominant_light_direction,
		SHADER_DATA.dominant_light_intensity,
		power,
		tint,
		analytical);
*/
	/*float3 SHADER_DATA.analytic_specular_radiance;
	float3 SHADER_DATA.specular_fresnel_color;
	float3 SHADER_DATA.specular_albedo_color;
	float4 SHADER_DATA.spatially_varying_material_parameters;*/
	
	calc_material_analytic_specular_two_lobe_phong_ps(
		SHADER_DATA);
		/*SHADER_DATA.common.view_dir,
		SHADER_DATA.bump_normal,
		SHADER_DATA.common.view_reflect_dir,
		SHADER_DATA.dominant_light_direction,
		SHADER_DATA.dominant_light_intensity,
		SHADER_DATA.albedo.rgb,
		SHADER_DATA.common.texcoord,
		SHADER_DATA.prt_ravi_diff.w,
		SHADER_DATA.common.tangent_frame,
		SHADER_DATA.spatially_varying_material_parameters,
		SHADER_DATA.specular_fresnel_color,
		SHADER_DATA.specular_albedo_color,
		SHADER_DATA.analytic_specular_radiance);*/
		
	// apply anti-shadow
	if (analytical_anti_shadow_control > 0.0f)
	{
		float4 temp[4]= {sh_lighting_coefficients[0], sh_lighting_coefficients[1], sh_lighting_coefficients[2], sh_lighting_coefficients[3]};
		float ambientness= calculate_ambientness(temp, SHADER_DATA.dominant_light_intensity, SHADER_DATA.dominant_light_direction);
		float ambient_multiplier= pow((1-ambientness), analytical_anti_shadow_control * 100.0f);
		SHADER_DATA.analytic_specular_radiance*= ambient_multiplier;
	}

	// calculate simple dynamic lights	
	//float3 SHADER_DATA.simple_light_diffuse_light;//= 0.0f;
	//float3 SHADER_DATA.simple_light_specular_light;//= 0.0f;	
	
	if (!no_dynamic_lights)
	{
		SHADER_DATA.specular_power = GET_MATERIAL_SPECULAR_POWER(material_type)(SHADER_DATA.spatially_varying_material_parameters.a);
		//float3 SHADER_DATA.common.fragment_position_world= Camera_Position_PS - SHADER_DATA.common.fragment_to_camera_world;
		calc_simple_lights_analytical(
			SHADER_DATA.common.fragment_position_world,
			SHADER_DATA.bump_normal,
	//		SHADER_DATA.common.fragment_to_camera_world,
			SHADER_DATA.common.view_reflect_dir,												// view direction = fragment to camera,   reflected around fragment normal
			SHADER_DATA.spatially_varying_material_parameters.a,
			SHADER_DATA.simple_light_diffuse_light,
			SHADER_DATA.simple_light_specular_light);
			
	}
	else
	{
		SHADER_DATA.simple_light_diffuse_light= 0.0f;
		SHADER_DATA.simple_light_specular_light= 0.0f;
	}
	
	float3 area_specular_radiance;
	if (order3_area_specular)
	{
		calculate_area_specular_phong_order_3(
			SHADER_DATA.common.view_reflect_dir,
			sh_lighting_coefficients,
			SHADER_DATA.spatially_varying_material_parameters.a,
			SHADER_DATA.specular_fresnel_color,
			area_specular_radiance);
	}
	else
	{
		float4 temp[4]= {sh_lighting_coefficients[0], sh_lighting_coefficients[1], sh_lighting_coefficients[2], sh_lighting_coefficients[3]};

		calculate_area_specular_phong_order_2(
			SHADER_DATA.common.view_reflect_dir,
			temp,
			SHADER_DATA.spatially_varying_material_parameters.a,
			SHADER_DATA.specular_fresnel_color,
			area_specular_radiance);
	}
	
	//scaling and masking
	SHADER_DATA.specular_radiance.xyz= SHADER_DATA.specular_mask * SHADER_DATA.spatially_varying_material_parameters.r * (
		(SHADER_DATA.simple_light_specular_light + max(SHADER_DATA.analytic_specular_radiance, 0.0f)) * analytical_specular_contribution +
		max(area_specular_radiance * area_specular_contribution, 0.0f));
		
	SHADER_DATA.specular_radiance.w= 0.0f;

	//modulate with prt	
	SHADER_DATA.specular_radiance*= SHADER_DATA.prt_ravi_diff.z;	

	//output for environment stuff
	SHADER_DATA.envmap_area_specular_only= area_specular_radiance * SHADER_DATA.prt_ravi_diff.z;
	SHADER_DATA.envmap_specular_reflectance_and_roughness.xyz=	SHADER_DATA.spatially_varying_material_parameters.b * SHADER_DATA.specular_mask * SHADER_DATA.spatially_varying_material_parameters.r;
	SHADER_DATA.envmap_specular_reflectance_and_roughness.w= max(0.01f, 1.01 - SHADER_DATA.spatially_varying_material_parameters.a / 200.0f);		// convert specular power to roughness (cheap and bad approximation);

	//do diffuse
	//float3 diffuse_part= ravi_order_3(SHADER_DATA.bump_normal, sh_lighting_coefficients);
	SHADER_DATA.diffuse_radiance= SHADER_DATA.prt_ravi_diff.x * SHADER_DATA.diffuse_radiance;
	SHADER_DATA.diffuse_radiance= (SHADER_DATA.simple_light_diffuse_light + SHADER_DATA.diffuse_radiance) * diffuse_coefficient;
	
}


#endif 
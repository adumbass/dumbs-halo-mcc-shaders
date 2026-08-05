#include "clip_plane.fx"
#include "dynamic_light_clip.fx"
#include "stipple.fx"


//#ifndef pc
#define ALPHA_OPTIMIZATION
//#endif

#ifndef APPLY_OVERLAYS
#define APPLY_OVERLAYS(color, texcoord, view_dot_normal)
#endif // APPLY_OVERLAYS

PARAM_SAMPLER_2D(radiance_map);
PARAM_SAMPLER_2D(dynamic_light_gel_texture);
PARAM(bool, sev_shadow_test);
//float4 dynamic_light_gel_texture_xform;		// no way to extern this, so I replace it with p_dynamic_light_gel_xform which is aliased on p_lighting_constant_4


float3 get_constant_analytical_light_dir_vs()
{
 	return -normalize(v_lighting_constant_1.xyz + v_lighting_constant_2.xyz + v_lighting_constant_3.xyz);		// ###ctchou $PERF : pass this in as a constant
}
#include "entry_points_adumbass_vertex.fx"


void get_albedo_and_normal(inout s_shader_data SHADER_DATA)
{
#ifdef maybe_calc_albedo
	if (actually_calc_albedo)					// transparent objects must generate their own albedo + normal
	{
		SHADER_DATA.bump_normal = calc_bumpmap_ps(SHADER_DATA);
		SHADER_DATA.albedo = calc_albedo_ps(SHADER_DATA);
	}
	else		
#endif
	{
#ifndef pc
		SHADER_DATA.common.fragment_position.xy+= p_tiling_vpos_offset.xy;
#endif

//#if DX_VERSION == 11
		int3 fragment_position_int = int3(SHADER_DATA.common.fragment_position.xy, 0);
		SHADER_DATA.bump_normal = normal_texture.Load(fragment_position_int) * 2.0f - 1.0f;
		SHADER_DATA.albedo = albedo_texture.Load(fragment_position_int);
/*
#elif defined(pc)
		float2 screen_texcoord= (SHADER_DATA.common.fragment_position.xy + float2(0.5f, 0.5f)) / texture_size.xy;
		SHADER_DATA.bump_normal= sample2D(normal_texture, screen_texcoord).xyz * 2.0f - 1.0f;
		SHADER_DATA.albedo= sample2D(albedo_texture, screen_texcoord);
#else // xenon
		float2 screen_texcoord= SHADER_DATA.common.fragment_position.xy;
		float4 bump_value, albedo;
		asm {
			tfetch2D bump_value, screen_texcoord, normal_texture, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true, FetchValidOnly= false
			tfetch2D albedo, screen_texcoord, albedo_texture, AnisoFilter= disabled, MagFilter= point, MinFilter= point, MipFilter= point, UnnormalizedTextureCoords= true
		};
		SHADER_DATA.bump_normal= bump_value.xyz * 2.0f - 1.0f;
#endif // xenon
*/
	}
}

s_common_pixel_data build_common_pixel_data(
	in float4 position,
	in float2 texcoord,
	in float3 normal,
	in float3 binormal,
	in float3 tangent,
    in float3 fragment_to_camera_world,
    //in float3 fragment_position_world,
    //in float3 view_dir,
    //in float3 view_dir_in_tangent_space,
	//in float3 view_reflect_dir,
	//in float view_dot_normal,
	in float3 object_position,
	in float3 object_scale
	//in float depth,
	//in float linear_depth
	)

{
	s_common_pixel_data data = (s_common_pixel_data)0;
	
    data.fragment_position = position;
    data.texcoord = texcoord;
    data.object_position = object_position;
    data.fragment_to_camera_world = fragment_to_camera_world;
    data.fragment_position_world = Camera_Position_PS - fragment_to_camera_world;
    data.object_scale = object_scale;
    data.depth = data.fragment_position.w;
	
	data.normal= normal;
	data.binormal= binormal;
	data.tangent= tangent;

	// normalize interpolated values
#ifndef ALPHA_OPTIMIZATION
	data.normal= normalize(normal);
	data.binormal= normalize(binormal);
	data.tangent= normalize(tangent);
#endif

	data.view_dir= normalize(fragment_to_camera_world);

	// setup tangent frame 
	data.tangent_frame = float3x3(data.tangent, data.binormal, data.normal);
	// convert view direction from world space to tangent space
	data.view_dir_in_tangent_space= mul(data.tangent_frame, data.view_dir);
	return data;
}

albedo_pixel albedo_ps(in albedo_vsout vsin)
{
    s_shader_data SHADER_DATA = (s_shader_data)0;

	SHADER_DATA.common = build_common_pixel_data(
		vsin.common.position,
		vsin.common.texcoord,
		vsin.common.normal,
		vsin.common.binormal,
		vsin.common.tangent,
		vsin.common.fragment_to_camera_world,
		vsin.common.object_position,
		vsin.common.object_scale
	);

	SHADER_DATA.common.texcoord = calc_parallax_ps(SHADER_DATA);

	// do alpha test
	SHADER_DATA.output_alpha = calc_alpha_test_ps(SHADER_DATA);
	
   	// compute the bump normal in world_space
	SHADER_DATA.bump_normal = calc_bumpmap_ps(SHADER_DATA);

	SHADER_DATA.albedo = calc_albedo_ps(SHADER_DATA);
	
#ifndef NO_ALPHA_TO_COVERAGE
	SHADER_DATA.output_alpha = 1.f;
#endif
	
	return convert_to_albedo_target(SHADER_DATA.albedo, SHADER_DATA.bump_normal, SHADER_DATA.common.fragment_position.w);
}

accum_pixel static_default_ps(in albedo_vsout vsin)
{
    s_shader_data SHADER_DATA = (s_shader_data)0;

	SHADER_DATA.common = build_common_pixel_data(
		vsin.common.position,
		vsin.common.texcoord,
		vsin.common.normal,
		vsin.common.binormal,
		vsin.common.tangent,
		vsin.common.fragment_to_camera_world,
		vsin.common.object_position,
		vsin.common.object_scale
	);
	// compute parallax
	SHADER_DATA.common.texcoord = calc_parallax_ps(SHADER_DATA);

	//float output_alpha;
	SHADER_DATA.output_alpha = calc_alpha_test_ps(SHADER_DATA);
	
   	// compute the bump normal in world_space
	SHADER_DATA.bump_normal = calc_bumpmap_ps(SHADER_DATA);

	SHADER_DATA.albedo = calc_albedo_ps(SHADER_DATA);
	
#ifndef NO_ALPHA_TO_COVERAGE
	SHADER_DATA.output_alpha = 1.f;
#endif
	
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(SHADER_DATA.albedo, true, false);
}

float4 calc_output_color_with_explicit_light_quadratic(
	float4 sh_lighting_coefficients[10],
	s_shader_data SHADER_DATA)
{
	// compute parallax
	SHADER_DATA.common.texcoord = calc_parallax_ps(SHADER_DATA);

	// do alpha test
	SHADER_DATA.output_alpha = calc_alpha_test_ps(SHADER_DATA);

	// get diffuse albedo, specular mask and bump normal	
	get_albedo_and_normal(SHADER_DATA);
	
	// compute a blended normal attenuation factor from the length squared of the normal vector
	// blended normal pixels are MSAA pixels that contained normal samples from two different polygons, therefore the lerped vector upon resolve does not have a length of 1.0
	float normal_lengthsq= dot(SHADER_DATA.bump_normal.xyz, SHADER_DATA.bump_normal.xyz);
#ifndef pc	
	float blended_normal_attenuate= pow(normal_lengthsq, 8);
	light_intensity*= blended_normal_attenuate;
#endif

	// normalize bump to make sure specular is smooth as a baby's bottom	
	SHADER_DATA.bump_normal /= sqrt(normal_lengthsq);

	SHADER_DATA.specular_mask = calc_specular_mask_ps(SHADER_DATA);
	
	// calculate view reflection direction (in world space of course)
	SHADER_DATA.common.view_dot_normal=	dot(SHADER_DATA.common.view_dir, SHADER_DATA.bump_normal);
	///  DESC: 18 7 2007   12:50 BUNGIE\yaohhu :
	///    We don't need to normalize view_reflect_dir, as long as bump_normal and view_dir have been normalized
	/// float3 view_reflect_dir= normalize( (SHADER_DATA.common.view_dot_normal * bump_normal - view_dir) * 2 + view_dir );
	SHADER_DATA.common.view_reflect_dir= (SHADER_DATA.common.view_dot_normal * SHADER_DATA.bump_normal - SHADER_DATA.common.view_dir) * 2 + SHADER_DATA.common.view_dir;

	SHADER_DATA.diffuse_radiance= ravi_order_3(SHADER_DATA.bump_normal, sh_lighting_coefficients);

	CALC_MATERIAL(material_type)(
		sh_lighting_coefficients,	
		SHADER_DATA);

	//compute environment map
	SHADER_DATA.envmap_area_specular_only = max(SHADER_DATA.envmap_area_specular_only, 0.001f);
	SHADER_DATA.envmap_radiance = CALC_ENVMAP(envmap_type)(SHADER_DATA);

	//compute self illumination	
	SHADER_DATA.self_illum_radiance = calc_self_illumination_ps(SHADER_DATA) * ILLUM_SCALE;
	
	float4 out_color;
	
	// set color channels
#ifdef BLEND_MULTIPLICATIVE
	out_color.xyz= (SHADER_DATA.albedo.xyz + SHADER_DATA.self_illum_radiance);		// No lighting, no fog, no exposure
	APPLY_OVERLAYS(out_color.xyz, SHADER_DATA.common.texcoord, SHADER_DATA.common.view_dot_normal)
	out_color.xyz= out_color.xyz * BLEND_MULTIPLICATIVE;
	out_color.w= ALPHA_CHANNEL_OUTPUT;
#elif defined(BLEND_FRESNEL)
	out_color.xyz= (SHADER_DATA.diffuse_radiance * SHADER_DATA.albedo.xyz * SHADER_DATA.albedo.w + SHADER_DATA.self_illum_radiance + SHADER_DATA.envmap_radiance + SHADER_DATA.specular_radiance);
	APPLY_OVERLAYS(out_color.xyz, SHADER_DATA.common.texcoord, SHADER_DATA.common.view_dot_normal)
	out_color.xyz= (out_color.xyz * SHADER_DATA.extinction + SHADER_DATA.inscatter * BLEND_FOG_INSCATTER_SCALE) * g_exposure.rrr;
	out_color.w= saturate(SHADER_DATA.specular_radiance.w + SHADER_DATA.albedo.w);
#else
	out_color.xyz= (SHADER_DATA.diffuse_radiance * SHADER_DATA.albedo.xyz + SHADER_DATA.specular_radiance + SHADER_DATA.self_illum_radiance + SHADER_DATA.envmap_radiance);
	APPLY_OVERLAYS(out_color.xyz, SHADER_DATA.common.texcoord, SHADER_DATA.common.view_dot_normal)
	out_color.xyz= (out_color.xyz * SHADER_DATA.extinction + SHADER_DATA.inscatter * BLEND_FOG_INSCATTER_SCALE) * g_exposure.rrr;
	out_color.w= ALPHA_CHANNEL_OUTPUT;
#endif
		

	return out_color;
}
	

float4 calc_output_color_with_explicit_light_linear_with_dominant_light(
	float4 sh_lighting_coefficients[4],
	s_shader_data SHADER_DATA)
{
	// compute parallax
	SHADER_DATA.common.texcoord = calc_parallax_ps(SHADER_DATA);

	// do alpha test
	SHADER_DATA.output_alpha = calc_alpha_test_ps(SHADER_DATA);

	// get diffuse albedo, specular mask and bump normal
	get_albedo_and_normal(SHADER_DATA);
	
	// compute a blended normal attenuation factor from the length squared of the normal vector
	// blended normal pixels are MSAA pixels that contained normal samples from two different polygons, therefore the lerped vector upon resolve does not have a length of 1.0
	float normal_lengthsq= dot(SHADER_DATA.bump_normal.xyz, SHADER_DATA.bump_normal.xyz);
#ifndef pc	
   // PC normals are denormalized due to 8888 format
	float blended_normal_attenuate= pow(normal_lengthsq, 8);
	light_intensity*= blended_normal_attenuate;
#endif

	///  DESC: 20 7 2007   19:54 BUNGIE\yaohhu :
	///   normalize normal to avoid band effect for specular
	SHADER_DATA.bump_normal/=sqrt(normal_lengthsq);

	///  DESC: 11 7 2007   18:1 BUNGIE\yaohhu :
	///     Denomalized normal (averaged in AA) will cause artifact (raid bug 44328)
	///     Not perfect, when demoanized only a little, like the wire's top on the ground
	///     We still have problem. Hard to fix theoritically. We can only hack. 
	///     This is my hack:
#ifndef pc	
	if(normal_lengthsq>=1-1e-2f)
	{
    	SHADER_DATA.specular_mask = calc_specular_mask_ps(SHADER_DATA);
    }else{
       SHADER_DATA.specular_mask=0;
    }
#else    
   // No MSAA on PC and normals are denormalized due to 8888 format
 	SHADER_DATA.specular_mask = calc_specular_mask_ps(SHADER_DATA);
#endif

	// calculate view reflection direction (in world space of course)
	SHADER_DATA.common.view_dot_normal=	dot(SHADER_DATA.common.view_dir, SHADER_DATA.bump_normal);
	///  DESC: 18 7 2007   12:50 BUNGIE\yaohhu :
	///    We don't need to normalize view_reflect_dir, as long as bump_normal and view_dir have been normalized
	/// float3 view_reflect_dir= normalize( (SHADER_DATA.common.view_dot_normal * bump_normal - view_dir) * 2 + view_dir );
	SHADER_DATA.common.view_reflect_dir= (SHADER_DATA.common.view_dot_normal * SHADER_DATA.bump_normal - SHADER_DATA.common.view_dir) * 2 + SHADER_DATA.common.view_dir;

	SHADER_DATA.diffuse_radiance= ravi_order_2_with_dominant_light(SHADER_DATA.bump_normal, sh_lighting_coefficients, SHADER_DATA.dominant_light_direction, SHADER_DATA.dominant_light_intensity);
	
	float4 zero_vec= 0.0f;
	float4 lightint_coefficients[10]= {
		sh_lighting_coefficients[0],
		sh_lighting_coefficients[1],
		sh_lighting_coefficients[2],
		sh_lighting_coefficients[3],
		zero_vec,
		zero_vec,
		zero_vec,
		zero_vec,
		zero_vec,
		zero_vec};

	CALC_MATERIAL(material_type)(
		lightint_coefficients,
		SHADER_DATA);
			
	//compute environment map
	SHADER_DATA.envmap_area_specular_only = max(SHADER_DATA.envmap_area_specular_only, 0.001f);
	SHADER_DATA.envmap_radiance = CALC_ENVMAP(envmap_type)(SHADER_DATA);

	//compute self illumination	
	SHADER_DATA.self_illum_radiance = calc_self_illumination_ps(SHADER_DATA) * ILLUM_SCALE;
	
	float4 out_color;
	
	// set color channels
#ifdef BLEND_MULTIPLICATIVE
	out_color.xyz= (SHADER_DATA.albedo.xyz + SHADER_DATA.self_illum_radiance);		// No lighting, no fog, no exposure
	APPLY_OVERLAYS(out_color.xyz, SHADER_DATA.common.texcoord, SHADER_DATA.common.view_dot_normal)
	out_color.xyz= out_color.xyz * BLEND_MULTIPLICATIVE;
	out_color.w= ALPHA_CHANNEL_OUTPUT;
#elif defined(BLEND_FRESNEL)
	out_color.xyz= (SHADER_DATA.diffuse_radiance * SHADER_DATA.albedo.xyz * SHADER_DATA.albedo.w + SHADER_DATA.self_illum_radiance + SHADER_DATA.envmap_radiance + SHADER_DATA.specular_radiance);
	APPLY_OVERLAYS(out_color.xyz, SHADER_DATA.common.texcoord, SHADER_DATA.common.view_dot_normal)
	out_color.xyz= (out_color.xyz * SHADER_DATA.extinction + SHADER_DATA.inscatter * BLEND_FOG_INSCATTER_SCALE) * g_exposure.rrr;
	out_color.w= saturate(SHADER_DATA.specular_radiance.w + SHADER_DATA.albedo.w);
#else
	out_color.xyz= (SHADER_DATA.diffuse_radiance * SHADER_DATA.albedo.xyz + SHADER_DATA.specular_radiance + SHADER_DATA.self_illum_radiance + SHADER_DATA.envmap_radiance);
	APPLY_OVERLAYS(out_color.xyz, SHADER_DATA.common.texcoord, SHADER_DATA.common.view_dot_normal)
	out_color.xyz= (out_color.xyz * SHADER_DATA.extinction + SHADER_DATA.inscatter * BLEND_FOG_INSCATTER_SCALE) * g_exposure.rrr;
	out_color.w= ALPHA_CHANNEL_OUTPUT;
#endif
		
//	return float4(albedo.xyz, 0);	
	return out_color;
}


#include "lightmap_sampling.fx"

accum_pixel static_per_pixel_ps(in static_per_pixel_vsout vsin) : SV_Target

{
    s_shader_data SHADER_DATA = (s_shader_data)0;

	SHADER_DATA.common = build_common_pixel_data(
		vsin.common.position,
		vsin.common.texcoord,
		vsin.common.normal,
		vsin.common.binormal,
		vsin.common.tangent,
		vsin.common.fragment_to_camera_world,
		vsin.common.object_position,
		vsin.common.object_scale
	);

	float3 sh_coefficients[4];

	SHADER_DATA.dominant_light_direction;
	SHADER_DATA.dominant_light_intensity;

	sample_lightprobe_texture(
		vsin.lightmap_texcoord.xy,
		sh_coefficients,
		SHADER_DATA.dominant_light_direction,
		SHADER_DATA.dominant_light_intensity);

	SHADER_DATA.prt_ravi_diff= float4(1.0f, 1.0f, 1.0f, dot(SHADER_DATA.common.tangent_frame[2], SHADER_DATA.dominant_light_direction));

	float4 sh_lighting_coefficients[4];	
	pack_constants_texture_array_linear(sh_coefficients, sh_lighting_coefficients);

	SHADER_DATA.extinction = vsin.extinction;
	SHADER_DATA.inscatter = vsin.inscatter;

	float4 out_color= calc_output_color_with_explicit_light_linear_with_dominant_light(
		sh_lighting_coefficients,
		SHADER_DATA);

	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);
	
}

#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
accum_pixel static_sh_ps(in static_sh_vsout vsin)
{
    s_shader_data SHADER_DATA = (s_shader_data)0;

	SHADER_DATA.common = build_common_pixel_data(
		vsin.common.position,
		vsin.common.texcoord,
		vsin.common.normal,
		vsin.common.binormal,
		vsin.common.tangent,
		vsin.common.fragment_to_camera_world,
		vsin.common.object_position,
		vsin.common.object_scale
	);
	// build sh_lighting_coefficients
	float4 sh_lighting_coefficients[10]=
		{
			p_lighting_constant_0, 
			p_lighting_constant_1, 
			p_lighting_constant_2, 
			p_lighting_constant_3, 
			p_lighting_constant_4, 
			p_lighting_constant_5, 
			p_lighting_constant_6, 
			p_lighting_constant_7, 
			p_lighting_constant_8, 
			p_lighting_constant_9 
		}; 	
	
	SHADER_DATA.dominant_light_direction = k_ps_dominant_light_direction;
	SHADER_DATA.dominant_light_intensity = k_ps_dominant_light_intensity;

	SHADER_DATA.prt_ravi_diff= float4(1.0f, 0.0f, 1.0f, dot(SHADER_DATA.common.tangent_frame[2], SHADER_DATA.dominant_light_direction));

	SHADER_DATA.extinction = vsin.extinction;
	SHADER_DATA.inscatter = vsin.inscatter;

	float4 out_color= calc_output_color_with_explicit_light_quadratic(
		sh_lighting_coefficients,
		SHADER_DATA);

	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);	
}

#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
accum_pixel static_per_vertex_ps(in static_per_vertex_vsout vsin)
{
    s_shader_data SHADER_DATA = (s_shader_data)0;

	SHADER_DATA.common = build_common_pixel_data(
		vsin.common.position,
		vsin.common.texcoord,
		vsin.common.normal,
		vsin.common.binormal,
		vsin.common.tangent,
		vsin.common.fragment_to_camera_world,
		vsin.common.object_position,
		vsin.common.object_scale
	);
	// build sh_lighting_coefficients
	float4 L0_3[3]= {vsin.probe0_3_r, vsin.probe0_3_g, vsin.probe0_3_b};
	
	//compute dominant light dir
	SHADER_DATA.dominant_light_direction= vsin.probe0_3_r.wyz * 0.212656f + vsin.probe0_3_g.wyz * 0.715158f + vsin.probe0_3_b.wyz * 0.0721856f;
	SHADER_DATA.dominant_light_direction= SHADER_DATA.dominant_light_direction * float3(-1.0f, -1.0f, 1.0f);
	SHADER_DATA.dominant_light_direction= normalize(SHADER_DATA.dominant_light_direction);
	
	float4 lighting_constants[4];
	pack_constants_linear(L0_3, lighting_constants);

	SHADER_DATA.prt_ravi_diff= float4(1.0f, 1.0f, 1.0f, dot(SHADER_DATA.common.tangent_frame[2], SHADER_DATA.dominant_light_direction));

	SHADER_DATA.dominant_light_intensity = vsin.dominant_light_intensity;
	SHADER_DATA.extinction = vsin.extinction;
	SHADER_DATA.inscatter = vsin.inscatter;//float3(vsin.texcoord.z, vsin.texcoord.w, vsin.extinction.w);

	float4 out_color= calc_output_color_with_explicit_light_linear_with_dominant_light(
		lighting_constants,
		SHADER_DATA);
		
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);	
}



#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
accum_pixel static_per_vertex_color_ps(in static_per_vertex_color_vsout vsin)
{
	s_shader_data SHADER_DATA = (s_shader_data)0;

	SHADER_DATA.common = build_common_pixel_data(
		vsin.common.position,
		vsin.common.texcoord,
		vsin.common.normal,
		vsin.common.binormal,
		vsin.common.tangent,
		vsin.common.fragment_to_camera_world,
		vsin.common.object_position,
		vsin.common.object_scale
	);
	// no parallax?

	// do alpha test
	SHADER_DATA.output_alpha = calc_alpha_test_ps(SHADER_DATA);
	
	// get diffuse albedo, specular mask and bump normal
	//float4 albedo;	
#ifdef maybe_calc_albedo
	if (actually_calc_albedo)						// transparent objects must generate their own albedo + normal
	{
		SHADER_DATA.albedo = calc_albedo_ps(SHADER_DATA);
	}
	else		
#endif
	{
#if DX_VERSION == 11
		SHADER_DATA.albedo = albedo_texture.Load(int3(SHADER_DATA.common.fragment_position.xy, 0));
#else
#ifndef pc
		SHADER_DATA.common.fragment_position.xy+= p_tiling_vpos_offset.xy;
#endif
		float2 screen_texcoord= (SHADER_DATA.common.fragment_position.xy + float2(0.5f, 0.5f)) / texture_size.xy;
		SHADER_DATA.albedo= sample2D(albedo_texture, screen_texcoord);
#endif
	}

	//compute self illumination	
	SHADER_DATA.self_illum_radiance = calc_self_illumination_ps(SHADER_DATA) * ILLUM_SCALE;

	SHADER_DATA.common.view_reflect_dir= -normalize(reflect(SHADER_DATA.common.view_dir, SHADER_DATA.bump_normal));
	SHADER_DATA.specular_power = 1.0;
	calc_simple_lights_analytical(
		SHADER_DATA.common.fragment_position_world,
		SHADER_DATA.common.normal,
		float3(1.0f, 0.0f, 0.0f),										// view reflection direction (not needed cuz we're doing diffuse only)
		1.0f,
		SHADER_DATA.simple_light_diffuse_light,
		SHADER_DATA.simple_light_specular_light);
		//SHADER_DATA);
	
	// set color channels
	float4 out_color;
#ifdef BLEND_MULTIPLICATIVE
	out_color.xyz= (vsin.vertex_color * SHADER_DATA.albedo.xyz + SHADER_DATA.self_illum_radiance) * BLEND_MULTIPLICATIVE;		// No lighting, no fog, no exposure
#else
	out_color.xyz= ((vsin.vertex_color + SHADER_DATA.simple_light_diffuse_light) * SHADER_DATA.albedo.xyz  + SHADER_DATA.self_illum_radiance);
	out_color.xyz= (out_color.xyz * vsin.extinction + vsin.inscatter * BLEND_FOG_INSCATTER_SCALE) * g_exposure.rrr;
#endif
	//out_color.xyz= vsin.vertex_color * g_exposure.rgb;
	out_color.w= ALPHA_CHANNEL_OUTPUT;
		
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);
	
}

accum_pixel static_prt_ps(in static_prt_vsout vsin)
{
	s_shader_data SHADER_DATA = (s_shader_data)0;

	SHADER_DATA.common = build_common_pixel_data(
		vsin.common.position,
		vsin.common.texcoord,
		vsin.common.normal,
		vsin.common.binormal,
		vsin.common.tangent,
		vsin.common.fragment_to_camera_world,
		vsin.common.object_position,
		vsin.common.object_scale
	);
	// build sh_lighting_coefficients
	float4 sh_lighting_coefficients[10]=
		{
			p_lighting_constant_0, 
			p_lighting_constant_1, 
			p_lighting_constant_2, 
			p_lighting_constant_3, 
			p_lighting_constant_4, 
			p_lighting_constant_5, 
			p_lighting_constant_6, 
			p_lighting_constant_7, 
			p_lighting_constant_8, 
			p_lighting_constant_9 
		}; 

	SHADER_DATA.dominant_light_direction = k_ps_dominant_light_direction.xyz;
	SHADER_DATA.dominant_light_intensity = k_ps_dominant_light_intensity.rgb;

	SHADER_DATA.prt_ravi_diff= vsin.prt_ravi_diff;

	SHADER_DATA.extinction = vsin.extinction;
	SHADER_DATA.inscatter = vsin.inscatter;

	
	float4 out_color= calc_output_color_with_explicit_light_quadratic(
		sh_lighting_coefficients,
		SHADER_DATA);
				
	return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);	
}

accum_pixel default_dynamic_light_ps(in dynamic_light_vsout vsin, bool cinematic)		
{
	s_shader_data SHADER_DATA = (s_shader_data)0;
	
	SHADER_DATA.common = build_common_pixel_data(
		vsin.position,
		vsin.texcoord,
		vsin.normal,
		vsin.binormal,
		vsin.tangent,
		vsin.fragment_to_camera_world,
		vsin.object_position,
		vsin.object_scale
	);

	SHADER_DATA.fragment_position_shadow = vsin.fragment_position_shadow;

	// compute parallax
	SHADER_DATA.common.texcoord = calc_parallax_ps(SHADER_DATA);

	// do alpha test
	SHADER_DATA.output_alpha = calc_alpha_test_ps(SHADER_DATA);

	// calculate simple light falloff for expensive light
	calculate_simple_light(
		0,
		SHADER_DATA.common.fragment_position_world,
		SHADER_DATA.light_radiance,
		SHADER_DATA.fragment_to_light);			// return normalized direction to the light

	SHADER_DATA.fragment_position_shadow.xyz /= SHADER_DATA.fragment_position_shadow.w;							// projective transform on xy coordinates
	
	// apply light gel
	SHADER_DATA.light_radiance *=  sample2D(dynamic_light_gel_texture, transform_texcoord(SHADER_DATA.fragment_position_shadow, p_dynamic_light_gel_xform));
	
	// clip if the pixel is too far
//	clip(light_radiance - 0.0000001f);				// ###ctchou $TODO $REVIEW turn this into a dynamic branch?

	// get diffuse albedo, specular mask and bump normal
	get_albedo_and_normal(SHADER_DATA);

	// calculate view reflection direction (in world space of course)
	///  DESC: 18 7 2007   12:50 BUNGIE\yaohhu :
	///    We don't need to normalize view_reflect_dir, as long as bump_normal and view_dir have been normalized
	///    and hlsl reflect can do that directly
	///float3 view_reflect_dir= normalize( (dot(view_dir, bump_normal) * bump_normal - view_dir) * 2 + view_dir );
	//SHADER_DATA.common.view_reflect_dir= normalize( (dot(SHADER_DATA.common.view_dir, SHADER_DATA.bump_normal) * SHADER_DATA.bump_normal - SHADER_DATA.common.view_dir) * 2 + SHADER_DATA.common.view_dir );
	SHADER_DATA.common.view_reflect_dir= -normalize(reflect(SHADER_DATA.common.view_dir, SHADER_DATA.bump_normal));


	// calculate diffuse lobe
	SHADER_DATA.analytic_diffuse_radiance= SHADER_DATA.light_radiance * dot(SHADER_DATA.fragment_to_light, SHADER_DATA.bump_normal) * SHADER_DATA.albedo.rgb;
	float3 radiance= SHADER_DATA.analytic_diffuse_radiance * GET_MATERIAL_DIFFUSE_MULTIPLIER(material_type)();

	// compute a blended normal attenuation factor from the length squared of the normal vector
	// blended normal pixels are MSAA pixels that contained normal samples from two different polygons, therefore the lerped vector upon resolve does not have a length of 1.0
	float normal_lengthsq= dot(SHADER_DATA.bump_normal.xyz, SHADER_DATA.bump_normal.xyz);
#ifndef pc	
	float blended_normal_attenuate= pow(normal_lengthsq, 8);
#endif	

	// calculate specular lobe
	SHADER_DATA.specular_mask = calc_specular_mask_ps(SHADER_DATA);

	float3 specular_multiplier= GET_MATERIAL_ANALYTICAL_SPECULAR_MULTIPLIER(material_type)(SHADER_DATA.specular_mask);
	
	if (dot(specular_multiplier, specular_multiplier) > 0.0001f)			// ###ctchou $PERF unproven 'performance' hack
	{

	SHADER_DATA.dominant_light_direction = SHADER_DATA.fragment_to_light;
	SHADER_DATA.dominant_light_intensity = SHADER_DATA.light_radiance;
	CALC_MATERIAL_ANALYTIC_SPECULAR(material_type)(
		SHADER_DATA);

		radiance += SHADER_DATA.analytic_specular_radiance * specular_multiplier;
	}
	
#ifndef pc	
	radiance*= blended_normal_attenuate;
#endif	
	
	// calculate shadow
	float unshadowed_percentage= 1.0f;
	if (dynamic_light_shadowing)
	{
		if (dot(radiance, radiance) > 0.0f)									// ###ctchou $PERF unproven 'performance' hack
		{
			float cosine= dot(SHADER_DATA.common.normal.xyz, p_lighting_constant_1.xyz);								// p_lighting_constant_1.xyz = normalized forward direction of light (along which depth values are measured)
	//		float cosine= dot(normal.xyz, Shadow_Projection_z.xyz);

			float slope= sqrt(1-cosine*cosine) / cosine;										// slope == tan(theta) == sin(theta)/cos(theta) == sqrt(1-cos^2(theta))/cos(theta)
	//		slope= min(slope, 4.0f) + 0.2f;														// don't let slope get too big (results in shadow errors - see master chief helmet), add a little bit of slope to account for curvature
																								// ###ctchou $REVIEW could make this (4.0) a shader parameter if you have trouble with the masterchief's helmet not shadowing properly	

	//		slope= slope / dot(p_lighting_constant_1.xyz, fragment_to_light.xyz);				// adjust slope to be slope for z-depth
																			
			float half_pixel_size= p_lighting_constant_1.w * SHADER_DATA.fragment_position_shadow.w;		// the texture coordinate distance from the center of a pixel to the corner of the pixel - increases linearly with increasing depth
			float depth_bias= (slope + 0.2f) * half_pixel_size;

			depth_bias= 0.0f;
		
			if (cinematic)
			{
				unshadowed_percentage= sample_percentage_closer_PCF_5x5_block_predicated(SHADER_DATA.fragment_position_shadow.xyz, depth_bias);
			}
			//if (sev_shadow_test == true)
			//{
			//	unshadowed_percentage= sample_percentage_closer_PCF_SEV(SHADER_DATA.fragment_position_shadow.xyz, SHADER_DATA.fragment_position_shadow.xy, depth_bias);
			//}
			else
			{
				unshadowed_percentage= sample_percentage_closer_PCF_3x3_block(SHADER_DATA.fragment_position_shadow.xyz, depth_bias);
			}
		}
	}

	float4 out_color;
	
	// set color channels
	out_color.xyz= (radiance) * g_exposure.rrr * unshadowed_percentage;

	// set alpha channel
	out_color.w= ALPHA_CHANNEL_OUTPUT;

	return convert_to_render_target(out_color, true, true);
}

accum_pixel dynamic_light_ps(in dynamic_light_vsout vsin)
{
	return default_dynamic_light_ps(vsin, false);
}

accum_pixel dynamic_light_cine_ps(in dynamic_light_vsout vsin)
{
	return default_dynamic_light_ps(vsin, true);
}


//===============================================================
// DEBUG

#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
void lightmap_debug_mode_vs(
	in vertex_type vertex,
	in s_lightmap_per_pixel lightmap,
	out float4 position : SV_Position,
	CLIP_OUTPUT
	out float2 lightmap_texcoord:TEXCOORD0,
	out float3 normal:TEXCOORD1,
	out float2 texcoord:TEXCOORD2,
	out float3 tangent:TEXCOORD3,
	out float3 binormal:TEXCOORD4,
	out float3 fragment_to_camera_world:TEXCOORD5)
{

	float4 local_to_world_transform[3];
	fragment_to_camera_world= Camera_Position-vertex.position;

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position);
	lightmap_texcoord= lightmap.texcoord;	
	normal= vertex.normal;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	binormal= vertex.binormal;
	
	CALC_CLIP(position);
}

accum_pixel lightmap_debug_mode_ps(
	SCREEN_POSITION_INPUT(screen_position),
	CLIP_INPUT
	in float2 lightmap_texcoord:TEXCOORD0,
	in float3 normal:TEXCOORD1,
	in float2 texcoord:TEXCOORD2,
	in float3 tangent:TEXCOORD3,
	in float3 binormal:TEXCOORD4,
	in float3 fragment_to_camera_world:TEXCOORD5) : SV_Target
{   	
	float4 out_color;
	s_shader_data SHADER_DATA = (s_shader_data)0;

    SHADER_DATA.common.fragment_position = screen_position;
    SHADER_DATA.common.texcoord = texcoord;

	SHADER_DATA.common.fragment_to_camera_world = fragment_to_camera_world;

	SHADER_DATA.common.normal= normal;
	SHADER_DATA.common.binormal= binormal;
	SHADER_DATA.common.tangent= tangent;

	// setup tangent frame
	SHADER_DATA.common.tangent_frame = float3x3(SHADER_DATA.common.tangent, SHADER_DATA.common.binormal, SHADER_DATA.common.normal);
	SHADER_DATA.bump_normal = calc_bumpmap_ps(SHADER_DATA);

	float3 ambient_only= 0.0f;
	float3 linear_only= 0.0f;
	float3 quadratic= 0.0f;

	out_color= display_debug_modes(
		lightmap_texcoord,
		SHADER_DATA.common.normal,
		SHADER_DATA.common.texcoord,
		SHADER_DATA.common.tangent,
		SHADER_DATA.common.binormal,
		SHADER_DATA.bump_normal,
		ambient_only,
		linear_only,
		quadratic);
		
	return convert_to_render_target(out_color, true, false);
	
}

#if DX_VERSION == 11

void stipple_vs(
	in vertex_type vertex,
	out float4 position : SV_Position,
	CLIP_OUTPUT
	out float2 texcoord : TEXCOORD0)
{
	float4 local_to_world_transform[3];

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, true);

	texcoord= vertex.texcoord;
	
	CALC_CLIP(position);
}

float4 stipple_ps(
	SCREEN_POSITION_INPUT(screen_position),
	CLIP_INPUT
	in float2 texcoord : TEXCOORD0) : SV_Target
{
	stipple_test(screen_position);

	s_shader_data SHADER_DATA = (s_shader_data)0;

    SHADER_DATA.common.texcoord = texcoord;

	SHADER_DATA.output_alpha = calc_alpha_test_ps(SHADER_DATA);	
	
	return 0;
}

#endif
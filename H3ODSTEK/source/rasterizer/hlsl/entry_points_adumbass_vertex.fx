// blah
struct s_common_vertex_data
{
    float4		position					: SV_Position;
	//float		clip_distance				: SV_ClipDistance;
	float2		texcoord                 	: TEXCOORD0;
	float3		normal                   	: TEXCOORD1;
	float3		binormal					: TEXCOORD2;
	float3		tangent                  	: TEXCOORD3;
	float3		fragment_to_camera_world 	: TEXCOORD4;
	float3 		object_position				: TEXCOORD5;
	float3		object_scale             	: TEXCOORD6;
};

s_common_vertex_data common_vertex_transform(inout vertex_type vertex, inout float4 local_to_world_transform[3])
{
	s_common_vertex_data data = (s_common_vertex_data)0;
	data.object_position = vertex.position;
	always_local_to_view(vertex, local_to_world_transform, data.position);


	data.texcoord= vertex.texcoord;
	data.normal= vertex.normal;
	data.binormal= vertex.binormal;
	data.tangent= vertex.tangent;

	// world space vector from vertex to eye/camera
	data.fragment_to_camera_world= Camera_Position - vertex.position;

	data.object_scale = 1 / extract_scale_halo(local_to_world_transform);
	
	return data;
}

#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
struct albedo_vsout
{
	s_common_vertex_data 	common;
	float clip_distance				: SV_ClipDistance;
};
albedo_vsout albedo_vs(
	in vertex_type vertex)
{
	albedo_vsout vsout;
	float4 local_to_world_transform[3];
	
	vsout.common = common_vertex_transform(vertex, local_to_world_transform);

	vsout.clip_distance = dot(vsout.common.position, v_clip_plane);
	
	return vsout;
}

#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
albedo_vsout static_default_vs(
	in vertex_type vertex)
{
	albedo_vsout vsout;
	vsout = albedo_vs(vertex);
}

///constant to do order 2 SH convolution
#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
struct static_per_pixel_vsout
{
	s_common_vertex_data 			common;
	float clip_distance				: SV_ClipDistance;
	float4 lightmap_texcoord        : TEXCOORD7;
	float3 extinction               : COLOR0;
	float3 inscatter                : COLOR1;
};
static_per_pixel_vsout static_per_pixel_vs(
	in vertex_type vertex,
	in s_lightmap_per_pixel lightmap)
{
	static_per_pixel_vsout vsout;
	float4 local_to_world_transform[3];

	vsout.common = common_vertex_transform(vertex, local_to_world_transform);

	vsout.lightmap_texcoord = float4(lightmap.texcoord, 0, 0);

	compute_scattering(Camera_Position, vertex.position, vsout.extinction, vsout.inscatter);

	vsout.clip_distance = dot(vsout.common.position, v_clip_plane);

	return vsout;
}

///constant to do order 2 SH convolution
#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
struct static_sh_vsout
{
	s_common_vertex_data 			common;
	float clip_distance				: SV_ClipDistance;
	/*float4 position					: SV_Position;
	float clip_distance				: SV_ClipDistance;
	float3 texcoord_and_vertexNdotL : TEXCOORD0;
	float3 normal                   : TEXCOORD3;
	float3 binormal                 : TEXCOORD4;
	float3 tangent                  : TEXCOORD5;
	float3 fragment_to_camera_world : TEXCOORD6;
    float3 object_position          : TEXCOORD7;
    float3 object_scale             : TEXCOORD8;*/
    //float3 object_center            : TEXCOORD10;
	float3 extinction               : COLOR0;
	float3 inscatter                : COLOR1;
};
static_sh_vsout static_sh_vs(	
	in vertex_type vertex)
{
	static_sh_vsout vsout;
	float4 local_to_world_transform[3];

	vsout.common = common_vertex_transform(vertex, local_to_world_transform);

	compute_scattering(Camera_Position, vertex.position, vsout.extinction, vsout.inscatter);

	vsout.clip_distance = dot(vsout.common.position, v_clip_plane);

	return vsout;
}

///constant to do order 2 SH convolution
#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
struct static_per_vertex_vsout
{
	s_common_vertex_data 			common;
	float clip_distance				: SV_ClipDistance;
	float4 probe0_3_r               : TEXCOORD7;
	float4 probe0_3_g               : TEXCOORD8;
	float4 probe0_3_b               : TEXCOORD9;
	float3 dominant_light_intensity : TEXCOORD10;
	float3 extinction               : COLOR0;  
	float3 inscatter                : COLOR1;
	/*float4 position					: SV_Position;
	float clip_distance				: SV_ClipDistance;
	float4 texcoord                 : TEXCOORD0;    // zw contains inscatter.xy
	float3 fragment_to_camera_world : TEXCOORD1;
	float3 tangent                  : TEXCOORD2;
	float3 normal                   : TEXCOORD3;	
	float3 binormal                 : TEXCOORD4;
	float4 probe0_3_r               : TEXCOORD5;
	float4 probe0_3_g               : TEXCOORD6;
	float4 probe0_3_b               : TEXCOORD7;
	float3 dominant_light_intensity : TEXCOORD8;
    float3 object_position          : TEXCOORD9;
    float3 object_scale             : TEXCOORD10;
	float4 extinction               : COLOR0;       // w contains inscatter.z
	*/
};
static_per_vertex_vsout static_per_vertex_vs(
	in vertex_type vertex,
	in float4 light_intensity : TEXCOORD3,
	in float4 c0_3_rgbe : TEXCOORD4,
	in float4 c1_1_rgbe : TEXCOORD5,
	in float4 c1_2_rgbe : TEXCOORD6,
	in float4 c1_3_rgbe : TEXCOORD7)
{
#ifdef pc	
   // on PC vertex lightnap is stored in unsigned format
   // convert to signed
   	light_intensity = 2 * light_intensity - 1;
	c0_3_rgbe = 2 * c0_3_rgbe - 1;
	c1_1_rgbe = 2 * c1_1_rgbe - 1;
	c1_2_rgbe = 2 * c1_2_rgbe - 1;
	c1_3_rgbe = 2 * c1_3_rgbe - 1;
#endif

//   float3 debug_out = c1_3_rgbe.xyz;

	static_per_vertex_vsout vsout;
	float4 local_to_world_transform[3];

	vsout.common = common_vertex_transform(vertex, local_to_world_transform);

	//const real exponent_mult= 127.f/pow(2.f, fractional_exponent_bits); == 31.75f
	
	float scale= exp2(light_intensity.a * 31.75f);
	light_intensity.rgb*= scale;
	
	scale= exp2(c0_3_rgbe.a * 31.75f);
	c0_3_rgbe.rgb*= scale;
	
	scale= exp2(c1_1_rgbe.a * 31.75f);
	c1_1_rgbe.rgb*= scale;

	scale= exp2(c1_2_rgbe.a * 31.75f);
	c1_2_rgbe.rgb*= scale;
	
	scale= exp2(c1_3_rgbe.a * 31.75f);
	c1_3_rgbe.rgb*= scale;
		
	vsout.probe0_3_r= float4(c0_3_rgbe.r, c1_1_rgbe.r, c1_2_rgbe.r, c1_3_rgbe.r);
	vsout.probe0_3_g= float4(c0_3_rgbe.g, c1_1_rgbe.g, c1_2_rgbe.g, c1_3_rgbe.g);
	vsout.probe0_3_b= float4(c0_3_rgbe.b, c1_1_rgbe.b, c1_2_rgbe.b, c1_3_rgbe.b);

	vsout.dominant_light_intensity= light_intensity.xyz;

//	dominant_light_intensity= debug_out;

	compute_scattering(Camera_Position, vertex.position, vsout.extinction, vsout.inscatter);

	//CALC_CLIP(position);
	vsout.clip_distance = dot(vsout.common.position, v_clip_plane);

	return vsout;
}


//straight vert color
#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
struct static_per_vertex_color_vsout
{
	s_common_vertex_data 			common;
	float clip_distance				: SV_ClipDistance;
	/*float4 position					: SV_Position;
	float clip_distance				: SV_ClipDistance;
	float2 texcoord                 : TEXCOORD0;
	float3 vertex_color				: TEXCOORD1;
	float3 fragment_to_camera_world : TEXCOORD2;
	float3 normal                   : TEXCOORD3;
	float3 binormal                 : TEXCOORD4;
	float3 tangent                  : TEXCOORD5;
    float3 object_position          : TEXCOORD6;
    float3 object_scale             : TEXCOORD7;
	*/
	float3 vertex_color				: TEXCOORD7;
	float3 extinction               : COLOR0; 
	float3 inscatter               	: COLOR1; 
};
static_per_vertex_color_vsout static_per_vertex_color_vs(
	in vertex_type vertex,
	in float3 vert_color				: TEXCOORD3)
{
	static_per_vertex_color_vsout vsout;
	float4 local_to_world_transform[3];

	vsout.common = common_vertex_transform(vertex, local_to_world_transform);

	vsout.vertex_color= vert_color;	

	compute_scattering(Camera_Position, vertex.position, vsout.extinction, vsout.inscatter);

	vsout.clip_distance = dot(vsout.common.position, v_clip_plane);

	return vsout;
}

#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
struct static_prt_vsout
{
	s_common_vertex_data 			common;
	float clip_distance				: SV_ClipDistance;
	/*float4 position					: SV_Position;
	float clip_distance				: SV_ClipDistance;
	float2 texcoord                 : TEXCOORD0;
	float3 normal                   : TEXCOORD3;
	float3 binormal                 : TEXCOORD4;
	float3 tangent                  : TEXCOORD5;
	float3 fragment_to_camera_world : TEXCOORD6;

    float3 object_position          : TEXCOORD8;
    float3 object_scale             : TEXCOORD9;
	*/
	float4 prt_ravi_diff            : TEXCOORD7;
	float3 extinction               : COLOR0;
	float3 inscatter                : COLOR1;
};
static_prt_vsout static_prt_ambient_vs(
	in vertex_type vertex,
//#ifdef pc
	in float prt_c0_c3 : BLENDWEIGHT1)
//#else // xenon
	//in float vertex_index : SV_VertexID,
//#endif // xenon

{
//#ifdef pc
//	float prt_c0= PRT_C0_DEFAULT;
	float prt_c0= prt_c0_c3;
//#else // xenon
/*
	// fetch PRT data from compressed 
	float prt_c0;

	float prt_fetch_index= vertex_index * 0.25f;								// divide vertex index by 4
	float prt_fetch_fraction= frac(prt_fetch_index);							// grab fractional part of index (should be 0, 0.25, 0.5, or 0.75) 

	float4 prt_values, prt_component;
	float4 prt_component_match= float4(0.75f, 0.5f, 0.25f, 0.0f);				// bytes are 4-byte swapped (each dword is stored in reverse order)
	asm
	{
		vfetch	prt_values, prt_fetch_index, blendweight1						// grab four PRT samples
		seq		prt_component, prt_fetch_fraction.xxxx, prt_component_match		// set the component that matches to one		
	};
	prt_c0= dot(prt_component, prt_values);
*/
//#endif // xenon

	//output to pixel shader
	static_prt_vsout vsout;
	float4 local_to_world_transform[3];

	vsout.common = common_vertex_transform(vertex, local_to_world_transform);

	float ambient_occlusion= prt_c0;
	float lighting_c0= 	dot(v_lighting_constant_0.xyz, float3(1.0f/3.0f, 1.0f/3.0f, 1.0f/3.0f));			// ###ctchou $PERF convert to monochrome before passing in!
	float ravi_mono= (0.886227f * lighting_c0)/3.1415926535f;
	float prt_mono= ambient_occlusion * lighting_c0;
		
	prt_mono= max(prt_mono, 0.01f);													// clamp prt term to be positive
	ravi_mono= max(ravi_mono, 0.01f);									// clamp ravi term to be larger than prt term by a little bit
	float prt_ravi_ratio= prt_mono /ravi_mono;
	vsout.prt_ravi_diff.x= prt_ravi_ratio;												// diffuse occlusion % (prt ravi ratio)
	vsout.prt_ravi_diff.y= prt_mono;														// unused
	vsout.prt_ravi_diff.z= (ambient_occlusion * 3.1415926535f)/0.886227f;					// specular occlusion % (ambient occlusion)
	vsout.prt_ravi_diff.w= min(dot(vsout.common.normal, get_constant_analytical_light_dir_vs()), prt_mono);		// specular (vertex N) dot L (kills backfacing specular)
	
	compute_scattering(Camera_Position, vertex.position, vsout.extinction, vsout.inscatter);

	vsout.clip_distance = dot(vsout.common.position, v_clip_plane);

	return vsout;
}
static_prt_vsout static_prt_linear_vs(
	in vertex_type vertex,
	in float4 prt_c0_c3 : BLENDWEIGHT1)
{
	static_prt_vsout vsout;
	float4 local_to_world_transform[3];

	vsout.common = common_vertex_transform(vertex, local_to_world_transform);
	// new monochrome PRT/RAVI ratio calculation
	
#ifdef pc	
   // on PC vertex linear PRT data is stored in unsigned format convert to signed
	prt_c0_c3 = 2 * prt_c0_c3 - 1;
#endif
	
	// convert to monochrome
//#ifdef pc
//	float4 prt_c0_c3_monochrome= float4(PRT_C0_DEFAULT, 0.0f, 0.0f, 0.0f);
//#else // xenon	
	float4 prt_c0_c3_monochrome= prt_c0_c3;
//#endif // xenon
	float4 SH_monochrome_3120;
	SH_monochrome_3120.xyz= (v_lighting_constant_1.xyz + v_lighting_constant_2.xyz + v_lighting_constant_3.xyz) / 3.0f;		// ###ctchou $PERF convert to monochrome before setting the constants yo
	SH_monochrome_3120.w= dot(v_lighting_constant_0.xyz, float3(1.0f/3.0f, 1.0f/3.0f, 1.0f/3.0f));

	//rotate the first 4 coefficients	
	float4 SH_monochrome_local_0123;
	sh_inverse_rotate_0123_monochrome(
		local_to_world_transform,
		SH_monochrome_3120,
		SH_monochrome_local_0123);
		
	float prt_mono=		dot(SH_monochrome_local_0123, prt_c0_c3_monochrome);		
	float ravi_mono= ravi_order_2_monochromatic(vsout.common.normal, SH_monochrome_3120);
		
	prt_mono= max(prt_mono, 0.01f);													// clamp prt term to be positive
	ravi_mono= max(ravi_mono, 0.01f);									// clamp ravi term to be larger than prt term by a little bit
	float prt_ravi_ratio= prt_mono / ravi_mono;
	vsout.prt_ravi_diff.x= prt_ravi_ratio;												// diffuse occlusion % (prt ravi ratio)
	vsout.prt_ravi_diff.y= prt_mono;														// unused
	vsout.prt_ravi_diff.z= (prt_c0_c3_monochrome.x * 3.1415926535f)/0.886227f;			// specular occlusion % (ambient occlusion)
	vsout.prt_ravi_diff.w= min(dot(vsout.common.normal, get_constant_analytical_light_dir_vs()), prt_mono);		// specular (vertex N) dot L (kills backfacing specular)

	compute_scattering(Camera_Position, vertex.position, vsout.extinction, vsout.inscatter);

	vsout.clip_distance = dot(vsout.common.position, v_clip_plane);

	return vsout;
}
void prt_quadratic(
	in float3 prt_c0_c2,
	in float3 prt_c3_c5,
	in float3 prt_c6_c8,	
	in float3 normal,
	float4 local_to_world_transform[3],
	out float4 prt_ravi_diff)
{
	// convert first 4 coefficients to monochrome
	float4 prt_c0_c3_monochrome= float4(prt_c0_c2.xyz, prt_c3_c5.x);			//(prt_c0_c3_r + prt_c0_c3_g + prt_c0_c3_b) / 3.0f;
	float4 SH_monochrome_3120;
	SH_monochrome_3120.xyz= (v_lighting_constant_1.xyz + v_lighting_constant_2.xyz + v_lighting_constant_3.xyz) / 3.0f;			// ###ctchou $PERF convert to mono before passing in?
	SH_monochrome_3120.w= dot(v_lighting_constant_0.xyz, float3(1.0f/3.0f, 1.0f/3.0f, 1.0f/3.0f));
	
	// rotate the first 4 coefficients
	float4 SH_monochrome_local_0123;
	sh_inverse_rotate_0123_monochrome(
		local_to_world_transform,
		SH_monochrome_3120,
		SH_monochrome_local_0123);

	float prt_mono=		dot(SH_monochrome_local_0123, prt_c0_c3_monochrome);

	// convert last 5 coefficients to monochrome
	float4 prt_c4_c7_monochrome= float4(prt_c3_c5.yz, prt_c6_c8.xy);						//(prt_c4_c7_r + prt_c4_c7_g + prt_c4_c7_b) / 3.0f;
	float prt_c8_monochrome= prt_c6_c8.z;													//dot(prt_c8, float3(1.0f/3.0f, 1.0f/3.0f, 1.0f/3.0f));
	float4 SH_monochrome_457= (v_lighting_constant_4 + v_lighting_constant_5 + v_lighting_constant_6) / 3.0f;
	float4 SH_monochrome_8866= (v_lighting_constant_7 + v_lighting_constant_8 + v_lighting_constant_9) / 3.0f;

	// rotate last 5 coefficients
	float4 SH_monochrome_local_4567;
	float SH_monochrome_local_8;
	sh_inverse_rotate_45678_monochrome(
		local_to_world_transform,
		SH_monochrome_457,
		SH_monochrome_8866,
		SH_monochrome_local_4567,
		SH_monochrome_local_8);

	prt_mono	+=	dot(SH_monochrome_local_4567, prt_c4_c7_monochrome);
	prt_mono	+=	SH_monochrome_local_8 * prt_c8_monochrome;

	float ravi_mono= ravi_order_3_monochromatic(normal, SH_monochrome_3120, SH_monochrome_457, SH_monochrome_8866);
	
	prt_mono= max(prt_mono, 0.01f);													// clamp prt term to be positive
	ravi_mono= max(ravi_mono, 0.01f);									// clamp ravi term to be larger than prt term by a little bit
	float prt_ravi_ratio= prt_mono / ravi_mono;
	prt_ravi_diff.x= prt_ravi_ratio;												// diffuse occlusion % (prt ravi ratio)
	prt_ravi_diff.y= prt_mono;														// unused
	prt_ravi_diff.z= (prt_c0_c3_monochrome.x * 3.1415926535f)/0.886227f;			// specular occlusion % (ambient occlusion)
	prt_ravi_diff.w= min(dot(normal, get_constant_analytical_light_dir_vs()), prt_mono);		// specular (vertex N) dot L (kills backfacing specular)
}
static_prt_vsout static_prt_quadratic_vs(
	in vertex_type vertex,
	in float3 prt_c0_c2 : BLENDWEIGHT1,
	in float3 prt_c3_c5 : BLENDWEIGHT2,
	in float3 prt_c6_c8 : BLENDWEIGHT3)	
{
	static_prt_vsout vsout;
	float4 local_to_world_transform[3];

	vsout.common = common_vertex_transform(vertex, local_to_world_transform);

// #ifdef pc	
// 	prt_ravi_diff.x= 1.0f;														// diffuse occlusion % (prt ravi ratio)
// 	prt_ravi_diff.y= 1.0f;														// unused
// 	prt_ravi_diff.z= 1.0f;														// specular occlusion % (ambient occlusion)
// 	prt_ravi_diff.w= dot(normal, get_constant_analytical_light_dir_vs());				// specular (vertex N) dot L (kills backfacing specular)
// #else // xenon
	prt_quadratic(
		prt_c0_c2,
		prt_c3_c5,
		prt_c6_c8,
		vsout.common.normal,
		local_to_world_transform,
		vsout.prt_ravi_diff);
//#endif // xenon
		
	compute_scattering(Camera_Position, vertex.position, vsout.extinction, vsout.inscatter);

	vsout.clip_distance = dot(vsout.common.position, v_clip_plane);

	return vsout;
}
/*
struct s_common_vertex_data_dl
{
    float4		position					: SV_Position;
	//float		clip_distance				: SV_ClipDistance;
	float2		texcoord                 	: TEXCOORD0;
	float3		normal                   	: TEXCOORD1;
	float3		binormal					: TEXCOORD2;
	float3		tangent                  	: TEXCOORD3;
	float3		fragment_to_camera_world 	: TEXCOORD4;
	float3 		object_position				: TEXCOORD5;
	float3		object_scale             	: TEXCOORD6;
};

s_common_vertex_data_dl common_vertex_transform_dl(inout vertex_type vertex, inout float4 local_to_world_transform[3])
{
	s_common_vertex_data_dl data = (s_common_vertex_data_dl)0;

	always_local_to_view(vertex, local_to_world_transform, data.position);

	data.object_position = vertex.position;
	data.texcoord= vertex.texcoord;
	data.normal= vertex.normal;
	data.binormal= vertex.binormal;
	data.tangent= vertex.tangent;

	// world space vector from vertex to eye/camera
	data.fragment_to_camera_world= Camera_Position - vertex.position;

	data.object_scale = 1 / extract_scale_halo(local_to_world_transform);
	
	return data;
}*/

#ifdef xdk_2907
[noExpressionOptimizations] 
#endif
struct dynamic_light_vsout
{
	//s_common_vertex_data_dl 			common;
	float4 position								: SV_Position;
	s_dynamic_light_clip_distance clip_distance : SV_ClipDistance;
	float2 texcoord								: TEXCOORD0;
	float3 normal								: TEXCOORD1;
	float3 binormal								: TEXCOORD2;
	float3 tangent								: TEXCOORD3;
	float3 fragment_to_camera_world				: TEXCOORD4;
    float3 object_position                      : TEXCOORD5;
    float3 object_scale                         : TEXCOORD6;
	float4 fragment_position_shadow				: TEXCOORD7; // homogenous coordinates of the fragment position in projective shadow space
};
dynamic_light_vsout default_dynamic_light_vs(
	in vertex_type vertex)
{
	dynamic_light_vsout vsout;
	float4 local_to_world_transform[3];

	//vsout.common = common_vertex_transform_dl(vertex, local_to_world_transform);

	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, vsout.position);

    vsout.object_position = vertex.position;
	vsout.texcoord = vertex.texcoord;
	vsout.normal = vertex.normal;
	vsout.binormal = vertex.binormal;
	vsout.tangent = vertex.tangent;

	// world space direction to eye/camera
	vsout.fragment_to_camera_world = Camera_Position - vertex.position;
	
	vsout.fragment_position_shadow = mul(float4(vertex.position, 1.0f), Shadow_Projection);

    vsout.object_scale = 1 / extract_scale_halo(local_to_world_transform);

//#if DX_VERSION == 11	
	vsout.clip_distance = calc_dynamic_light_clip_distance(vsout.position);
//#endif
    return vsout;
}

dynamic_light_vsout dynamic_light_vs(
	in vertex_type vertex)
{
    return default_dynamic_light_vs(vertex);
}

dynamic_light_vsout dynamic_light_cine_vs(
	in vertex_type vertex)
{
	return default_dynamic_light_vs(vertex);
}

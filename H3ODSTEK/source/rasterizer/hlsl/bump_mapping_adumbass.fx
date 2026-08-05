PARAM_SAMPLER_2D(bump_map);
PARAM(float4, bump_map_xform);
PARAM_SAMPLER_2D(bump_detail_map);
PARAM(float4, bump_detail_map_xform);
PARAM_SAMPLER_2D(bump_directional_map);
PARAM(float4, bump_directional_map_xform);

PARAM_SAMPLER_2D(top_bump_map);
PARAM(float4, top_bump_map_xform);

PARAM(float, bump_strength);
PARAM(float, top_bump_strength);

PARAM(float, top_bump_mask_power);
PARAM(float, top_bump_mask_width);
PARAM(float, top_bump_blend_offset);
PARAM(float, top_bump_blend_sharpness);

#if defined(pc) && (DX_VERSION == 9)
#define BUMP_CONVERT(x)  ((x) * (255.0f / 127.f) - (128.0f / 127.f))
#else
#define BUMP_CONVERT(x)  (x)
#endif

/*
float3 sample_bumpmap(in texture_sampler_2d bump_map, in float4 xform, in s_shader_data SHADER_DATA)
{
#ifdef pc
	float3 bump= sample_base_maps_ps(bump_map, xform, SHADER_DATA).rgb;
   bump.xy = BUMP_CONVERT(bump.xy);
#else					// xenon compressed bump textures don't calculate z automatically
	float4 bump;
	asm {
		tfetch2D bump, texcoord, bump_map, FetchValidOnly= false
	};
#endif
	
	float2 bump2= bump.xy * bump.xy;
	bump.z= min(bump2.x + bump2.y, 1.0f);
	bump.z= sqrt(1 - bump.z);

	//bump.xyz= normalize(bump.xyz);		// ###ctchou $PERF do we need to normalize?  why?
	
	return bump.xyz;
}

float3 sample_bump_detailmap(in texture_sampler_2d bump_map, in float4 xform, in s_shader_data SHADER_DATA)
{
	float3 bump= sample_bump_detail_ps(bump_map, xform, SHADER_DATA).rgb;
   	bump.xy = BUMP_CONVERT(bump.xy);
	float2 bump2= bump.xy * bump.xy;
	bump.z= min(bump2.x + bump2.y, 1.0f);
	bump.z= sqrt(1 - bump.z);
	//bump.xyz= normalize(bump.xyz);		// ###ctchou $PERF do we need to normalize?  why?
	return bump.xyz;
}
*/

float3 calc_bumpmap_off_ps(
	in s_shader_data SHADER_DATA)
{
//	float3 bump= fast3(0.0f, 0.0f, 1.0f);		// in tangent space

	// rotate bump to world space (same space as lightprobe) and normalize
//	return normalize( mul(bump, tangent_frame) );		// V*M = M'*V = inverse(M)*V    if M is orthogonal (tangent_frame should be orthogonal)

	return SHADER_DATA.common.tangent_frame[2];
}


float3 calc_bumpmap_default_ps(
	in s_shader_data SHADER_DATA)
{
	float3 bump= sample_base_maps_ps(bump_map, bump_map_xform, SHADER_DATA, true);		// in tangent space
	//bump = unpack_bump_bungie(bump);
	// rotate bump to world space (same space as lightprobe) and normalize
	return normalize( mul(bump, SHADER_DATA.common.tangent_frame) );		// V*M = M'*V = inverse(M)*V    if M is orthogonal (tangent_frame should be orthogonal)
}


float3 calc_bumpmap_detail_ps(
	in s_shader_data SHADER_DATA)
{
	float3 bump= sample_base_maps_ps(bump_map, bump_map_xform, SHADER_DATA, true);		// in tangent space
	//bump = unpack_bump_bungie(bump);
	float3 detail= sample_detail_maps_ps(bump_detail_map, bump_detail_map_xform, SHADER_DATA, true);		// in tangent space
	//detail = unpack_bump_bungie(detail);
	// ^ this has an issue if base maps are also triplanar with rnm in the triplanar func
	bump.xy+= detail.xy;
	//bump = blend_rnm_signed(bump, detail);
	//bump= normalize(bump);
	
	// rotate bump to world space (same space as lightprobe) and normalize
	return normalize( mul(bump, SHADER_DATA.common.tangent_frame) );		// V*M = M'*V = inverse(M)*V    if M is orthogonal (tangent_frame should be orthogonal)	
}


float3 calc_bumpmap_detail_top_mask_ps(
	in s_shader_data SHADER_DATA)
{
	float3 bump= sample_base_maps_ps(bump_map, bump_map_xform, SHADER_DATA, true);		// in tangent space
	//bump = unpack_bump_bungie(bump);
	float3 detail= sample_detail_maps_ps(bump_detail_map, bump_detail_map_xform, SHADER_DATA, true);		// in tangent space
	//detail = unpack_bump_bungie(detail);
	bump.xy+= detail.xy;

	float top_mask = calc_top_mask_vertex_ps(SHADER_DATA,
											top_bump_mask_power,
											top_bump_mask_width,
											top_bump_blend_offset,
											top_bump_blend_sharpness);
	float3 top_bump= sample_detail_maps_ps(top_bump_map, top_bump_map_xform, SHADER_DATA, true);		// in tangent space
	//top_bump = unpack_bump_bungie(top_bump);
	top_bump = lerp( float3(0, 0, 1), top_bump, top_bump_strength);

	bump = lerp(bump, top_bump, top_mask);
	
	// rotate bump to world space (same space as lightprobe) and normalize
	return normalize( mul(bump, SHADER_DATA.common.tangent_frame) );		// V*M = M'*V = inverse(M)*V    if M is orthogonal (tangent_frame should be orthogonal)	
}


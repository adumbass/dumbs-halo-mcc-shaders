
PARAM(float, mask_direction_x);
PARAM(float, mask_direction_y);
PARAM(float, mask_direction_z);
PARAM(float, triplanar_sharpness);

#line 2 "source\rasterizer\hlsl\texture_xform.fx"
#ifndef __TEXTURE_XFORM_FX
#define __TEXTURE_XFORM_FX

#define BITMAP_ROTATION(rotation) ROTATION_TYPE_##rotation
#define ROTATION_TYPE_0 0
#define ROTATION_TYPE_1 1


float2 transform_texcoord(in float2 texcoord, in float4 transform)
{
#if BITMAP_ROTATION(bitmap_rotation)==ROTATION_TYPE_1
	float2 output_texcoord;
	float sine= sin(transform.x);
	float cosine= cos(transform.x);
	
	texcoord-= transform.zw;

	output_texcoord.x= transform.y*(cosine*texcoord.x - sine*texcoord.y);
	output_texcoord.y= transform.y*(sine*texcoord.x + cosine*texcoord.y);
	
	output_texcoord+= transform.zw;

	return output_texcoord;
#else
	return texcoord * transform.xy + transform.zw;
#endif // BITMAP_ROTATION
}


#endif // __TEXTURE_XFORM_FX

//////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////// new sampling functions so i can turn it into a render method option
//////////////////////////////////////////////////////////////////////////////////////////////////

// Reoriented Normal Mapping
// http://blog.selfshadow.com/publications/blending-in-detail/
// Altered to take normals (-1 to 1 ranges) rather than unsigned normal maps (0 to 1 ranges)
half3 blend_rnm_temp(half3 n1, half3 n2)
{
    n1.z += 1;
    n2.xy = -n2.xy;

    return n1 * dot(n1, n2) / n1.z - n2;
}

// already in adumbass_functions need to remove that include later
float3 rnmBlendUnpacked_temp(float3 n1, float3 n2)
{
    n1 += float3( 0,  0, 1);
    n2 *= float3(-1, -1, 1);
    return n1*dot(n1, n2)/n1.z - n2;
}
// already in adumbass_functions need to remove that include later
float3 unpack_bump_bungie(float3 bump_normal)
{
	float2 bump2= bump_normal.xy * bump_normal.xy;
	bump_normal.z= min(bump2.x + bump2.y, 1.0f);
	bump_normal.z= sqrt(1 - bump_normal.z);
    return bump_normal;
}


float4 sample_bias_global_2d_ps(in texture_sampler_2d s, in float4 xform, in s_shader_data SHADER_DATA)
{
	//return sampleBias2D(s, transform_texcoord(SHADER_DATA.common.texcoord, xform), ps_global_mip_bias);
    return sampleBiasGlobal2D(s, transform_texcoord(SHADER_DATA.common.texcoord, xform));
}

float3 sample_bias_global_2d_ps(in texture_sampler_2d s, in float4 xform, in s_shader_data SHADER_DATA, bool dummy)
{
	//return unpack_bump_bungie(sampleBias2D(s, transform_texcoord(SHADER_DATA.common.texcoord, xform), ps_global_mip_bias));
    return unpack_bump_bungie(sampleBiasGlobal2D(s, transform_texcoord(SHADER_DATA.common.texcoord, xform)));
}



////////////////////////////////////
//////////// world space triplanar 
////////////////////////////////////
// https://bgolus.medium.com/normal-mapping-for-a-triplanar-shader-10bf39dca05a

float4 sample_world_space_triplanar_2d_ps(texture_sampler_2d s, float4 xform, in s_shader_data SHADER_DATA)//in float3 abs_world_position, in float3 world_normal)
{
    // calculate triplanar blend
    float3 triblend = saturate(pow(SHADER_DATA.common.normal, 4));
    triblend /= max(dot(triblend, float3(1,1,1)), 0.0001);

    // preview blend
    // return fixed4(triblend.xyz, 1);

    // calculate triplanar uvs
    // applying texture scale and offset values ala TRANSFORM_TEX macro
    float2 uvX = transform_texcoord(SHADER_DATA.common.fragment_position_world.zy, xform);
    float2 uvY = transform_texcoord(SHADER_DATA.common.fragment_position_world.xz, xform);
    float2 uvZ = transform_texcoord(SHADER_DATA.common.fragment_position_world.xy, xform);

    // offset UVs to prevent obvious mirroring
#if defined(TRIPLANAR_UV_OFFSET)
    uvY += 0.33;
    uvZ += 0.67;
#endif

    // minor optimization of sign(). prevents return value of 0
    float3 axisSign = SHADER_DATA.common.normal < 0 ? -1 : 1;

    // flip UVs horizontally to correct for back side projection
#if defined(TRIPLANAR_CORRECT_PROJECTED_U)
    uvX.x *= axisSign.x;
    uvY.x *= axisSign.y;
    uvZ.x *= -axisSign.z;
#endif
    // sample textures
    float4 colX = sampleBiasGlobal2D(s, uvX);
    float4 colY = sampleBiasGlobal2D(s, uvY);
    float4 colZ = sampleBiasGlobal2D(s, uvZ);
    float4 col = colX * triblend.x + colY * triblend.y + colZ * triblend.z;
    return col;
}


//sample_world_space_triplanar_2d_normal_ps
float3 sample_world_space_triplanar_2d_ps(texture_sampler_2d s, float4 xform, in s_shader_data SHADER_DATA, bool dummy)
{
    // me dumb
    SHADER_DATA.common.normal = normalize(mul(SHADER_DATA.common.tangent_frame, SHADER_DATA.common.normal));

    // calculate triplanar blend
    float3 triblend = saturate(pow(SHADER_DATA.common.normal, 4));
    triblend /= max(dot(triblend, float3(1,1,1)), 0.0001);

    // preview blend
    // return fixed4(triblend.xyz, 1);

    // calculate triplanar uvs
    // applying texture scale and offset values ala TRANSFORM_TEX macro
    float2 uvX = transform_texcoord(SHADER_DATA.common.fragment_position_world.zy, xform);
    float2 uvY = transform_texcoord(SHADER_DATA.common.fragment_position_world.xz, xform);
    float2 uvZ = transform_texcoord(SHADER_DATA.common.fragment_position_world.xy, xform);

    // offset UVs to prevent obvious mirroring
#if defined(TRIPLANAR_UV_OFFSET)
    uvY += 0.33;
    uvZ += 0.67;
#endif

    // minor optimization of sign(). prevents return value of 0
    float3 axisSign = SHADER_DATA.common.normal < 0 ? -1 : 1;

    // flip UVs horizontally to correct for back side projection
#if defined(TRIPLANAR_CORRECT_PROJECTED_U)
    uvX.x *= axisSign.x;
    uvY.x *= axisSign.y;
    uvZ.x *= -axisSign.z;
#endif
    // sample textures
    float3 tnormalX = unpack_bump_bungie(sampleBiasGlobal2D(s, uvX));
    float3 tnormalY = unpack_bump_bungie(sampleBiasGlobal2D(s, uvY));
    float3 tnormalZ = unpack_bump_bungie(sampleBiasGlobal2D(s, uvZ));

    //float3 tnormalX = (sampleBiasGlobal2D(s, uvX));
    //float3 tnormalY = (sampleBiasGlobal2D(s, uvY));
    //float3 tnormalZ = (sampleBiasGlobal2D(s, uvZ));

#if defined(TRIPLANAR_CORRECT_PROJECTED_U)
    tnormalX.x *= axisSign.x;
    tnormalY.x *= axisSign.y;
    tnormalZ.x *= -axisSign.z;
#endif
    float3 absVertNormal = abs(SHADER_DATA.common.normal);

    // swizzle world normals to match tangent space and apply reoriented world_normal mapping blend
    tnormalX = rnmBlendUnpacked_temp(float3(SHADER_DATA.common.normal.zy, absVertNormal.x), tnormalX);
    tnormalY = rnmBlendUnpacked_temp(float3(SHADER_DATA.common.normal.xz, absVertNormal.y), tnormalY);
    tnormalZ = rnmBlendUnpacked_temp(float3(SHADER_DATA.common.normal.xy, absVertNormal.z), tnormalZ);

    // apply world space sign to tangent space Z
    tnormalX.z *= axisSign.x;
    tnormalY.z *= axisSign.y;
    tnormalZ.z *= axisSign.z;

    // sizzle tangent normals to match world world_normal and blend together
    float3 worldNormal = normalize(
        tnormalX.zyx * triblend.x +
        tnormalY.xzy * triblend.y +
        tnormalZ.xyz * triblend.z
    );

    //worldNormal = normalize( mul(worldNormal, SHADER_DATA.common.tangent_frame) );

    // preview world normals
    // return fixed4(worldNormal * 0.5 + 0.5, 1);
    return worldNormal;
}

////////////////////////////////////
//////////// triplanar 
////////////////////////////////////
// from: https://iquilezles.org/articles/biplanar/
// The MIT License
// Copyright © 2015 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// How to do texture map a 3D object when it doesn't have 
// uv coordinates but can't afford full 3D solid texturing.

// The idea is to perform three planar texture projections 
// and blend the results based on the alignment of the
// normal vector to each one of the projection directions.

// The technique was invented by Mitch Prater in the early
// 90s, and has been called "Box mapping" or "Rounded cube
// mapping" traditionally, although more recently it has
// become popular in the realtime rendering community and
// rebranded as "triplanar" mapping.

// For a "biplanar" mapping example, visit:
//
// https://www.shadertoy.com/view/ws3Bzf


// "p" point apply texture to
// "n" normal at "p"
// "k" controls the sharpness of the blending in the transitions areas.
// "s" texture sampler
float4 sample_cheap_triplanar_2d_ps( in texture_sampler_2d s, float4 xform, in s_shader_data SHADER_DATA)
{
    // project+fetch
    float4 x = sampleBiasGlobal2D( s, transform_texcoord(SHADER_DATA.common.object_position.yz, xform) );
	float4 y = sampleBiasGlobal2D( s, transform_texcoord(SHADER_DATA.common.object_position.zx, xform) );
	float4 z = sampleBiasGlobal2D( s, transform_texcoord(SHADER_DATA.common.object_position.xy, xform) );
    
    // and blend
    float3 m = pow( abs(SHADER_DATA.common.normal), float3(triplanar_sharpness, triplanar_sharpness, triplanar_sharpness) );
	return (x*m.x + y*m.y + z*m.z) / (m.x + m.y + m.z);
}

float3 sample_cheap_triplanar_2d_ps( in texture_sampler_2d s, float4 xform, in s_shader_data SHADER_DATA, bool dummy)
{
    // project+fetch
    float3 x = unpack_bump_bungie( sampleBiasGlobal2D( s, transform_texcoord(SHADER_DATA.common.object_position.yz, xform) ).xyz );
	float3 y = unpack_bump_bungie( sampleBiasGlobal2D( s, transform_texcoord(SHADER_DATA.common.object_position.zx, xform) ).xyz );
	float3 z = unpack_bump_bungie( sampleBiasGlobal2D( s, transform_texcoord(SHADER_DATA.common.object_position.xy, xform) ).xyz );
    
    // and blend
    float3 m = pow( abs(SHADER_DATA.common.normal), float3(triplanar_sharpness, triplanar_sharpness, triplanar_sharpness) );
	return (x*m.x + y*m.y + z*m.z) / (m.x + m.y + m.z);
}


float4 sample_triplanar_2d_ps(texture_sampler_2d s, float4 xform, in s_shader_data SHADER_DATA)//in float3 abs_world_position, in float3 world_normal)
{
    // calculate triplanar blend
    float3 triblend = saturate(pow(SHADER_DATA.common.normal, 4));
    triblend /= max(dot(triblend, float3(1,1,1)), 0.0001);

    // preview blend
    // return fixed4(triblend.xyz, 1);

    // calculate triplanar uvs
    // applying texture scale and offset values ala TRANSFORM_TEX macro
    float2 uvX = transform_texcoord(SHADER_DATA.common.object_position.zy, xform);
    float2 uvY = transform_texcoord(SHADER_DATA.common.object_position.xz, xform);
    float2 uvZ = transform_texcoord(SHADER_DATA.common.object_position.xy, xform);

    // offset UVs to prevent obvious mirroring
#if defined(TRIPLANAR_UV_OFFSET)
    uvY += 0.33;
    uvZ += 0.67;
#endif

    // minor optimization of sign(). prevents return value of 0
    float3 axisSign = SHADER_DATA.common.normal < 0 ? -1 : 1;

    // flip UVs horizontally to correct for back side projection
#if defined(TRIPLANAR_CORRECT_PROJECTED_U)
    uvX.x *= axisSign.x;
    uvY.x *= axisSign.y;
    uvZ.x *= -axisSign.z;
#endif
    // sample textures
    float4 colX = sampleBiasGlobal2D(s, uvX);
    float4 colY = sampleBiasGlobal2D(s, uvY);
    float4 colZ = sampleBiasGlobal2D(s, uvZ);
    float4 col = colX * triblend.x + colY * triblend.y + colZ * triblend.z;
    return col;
}


//sample_world_space_triplanar_2d_normal_ps
float3 sample_triplanar_2d_ps(texture_sampler_2d s, float4 xform, in s_shader_data SHADER_DATA, bool dummy)
{
    // me dumb
    SHADER_DATA.common.normal = normalize(mul(SHADER_DATA.common.tangent_frame, SHADER_DATA.common.normal));

    // calculate triplanar blend
    float3 triblend = saturate(pow(SHADER_DATA.common.normal, 4));
    triblend /= max(dot(triblend, float3(1,1,1)), 0.0001);

    // preview blend
    // return fixed4(triblend.xyz, 1);

    // calculate triplanar uvs
    // applying texture scale and offset values ala TRANSFORM_TEX macro
    float2 uvX = transform_texcoord(SHADER_DATA.common.object_position.zy, xform);
    float2 uvY = transform_texcoord(SHADER_DATA.common.object_position.xz, xform);
    float2 uvZ = transform_texcoord(SHADER_DATA.common.object_position.xy, xform);

    // offset UVs to prevent obvious mirroring
#if defined(TRIPLANAR_UV_OFFSET)
    uvY += 0.33;
    uvZ += 0.67;
#endif

    // minor optimization of sign(). prevents return value of 0
    float3 axisSign = SHADER_DATA.common.normal < 0 ? -1 : 1;

    // flip UVs horizontally to correct for back side projection
#if defined(TRIPLANAR_CORRECT_PROJECTED_U)
    uvX.x *= axisSign.x;
    uvY.x *= axisSign.y;
    uvZ.x *= -axisSign.z;
#endif
    // sample textures
    float3 tnormalX = unpack_bump_bungie(sampleBiasGlobal2D(s, uvX));
    float3 tnormalY = unpack_bump_bungie(sampleBiasGlobal2D(s, uvY));
    float3 tnormalZ = unpack_bump_bungie(sampleBiasGlobal2D(s, uvZ));

    //float3 tnormalX = (sampleBiasGlobal2D(s, uvX));
    //float3 tnormalY = (sampleBiasGlobal2D(s, uvY));
    //float3 tnormalZ = (sampleBiasGlobal2D(s, uvZ));

#if defined(TRIPLANAR_CORRECT_PROJECTED_U)
    tnormalX.x *= axisSign.x;
    tnormalY.x *= axisSign.y;
    tnormalZ.x *= -axisSign.z;
#endif
    float3 absVertNormal = abs(SHADER_DATA.common.normal);

    // swizzle world normals to match tangent space and apply reoriented world_normal mapping blend
    tnormalX = rnmBlendUnpacked_temp(float3(SHADER_DATA.common.normal.zy, absVertNormal.x), tnormalX);
    tnormalY = rnmBlendUnpacked_temp(float3(SHADER_DATA.common.normal.xz, absVertNormal.y), tnormalY);
    tnormalZ = rnmBlendUnpacked_temp(float3(SHADER_DATA.common.normal.xy, absVertNormal.z), tnormalZ);

    // apply world space sign to tangent space Z
    tnormalX.z *= axisSign.x;
    tnormalY.z *= axisSign.y;
    tnormalZ.z *= axisSign.z;

    // sizzle tangent normals to match world world_normal and blend together
    float3 worldNormal = normalize(
        tnormalX.zyx * triblend.x +
        tnormalY.xzy * triblend.y +
        tnormalZ.xyz * triblend.z
    );

    //worldNormal = normalize( mul(worldNormal, SHADER_DATA.common.tangent_frame) );

    // preview world normals
    // return fixed4(worldNormal * 0.5 + 0.5, 1);
    return worldNormal;
}


////////////////////////////////////
///// directional masking
////////////////////////////////////
float calc_top_mask_vertex_ps(
	in s_shader_data SHADER_DATA,
    in float vertex_normal_mask_power,
    in float vertex_normal_mask_width,
    in float blend_offset,
    in float blend_sharpness)
{
    /// blend mask from vertex normals instead of vertex color
	float3 abs_normal = abs(SHADER_DATA.common.normal); //(SHADER_DATA.bump_normal);
    abs_normal = pow(abs_normal, vertex_normal_mask_power);
    float blend_mask = dot(abs_normal, vertex_normal_mask_width);
    blend_mask = (blend_mask > 1.5) ? 0.0 : ((blend_mask == 1.5) ? 0.0 : 1.0);

	float3 mask_direction = float3(0, 0, 1);

    float dir_mask = dot(mask_direction, SHADER_DATA.common.normal);

    blend_mask += ((dir_mask + blend_offset) * blend_mask) * 2;
    dir_mask = (dir_mask + blend_offset) - blend_mask;
							                                                                                            
	dir_mask = saturate(dir_mask);                                                                                        
	dir_mask = saturate(pow(dir_mask, blend_sharpness));
	
	return dir_mask;
}

float calc_dir_mask_vertex_ps(
	in s_shader_data SHADER_DATA,
    in float vertex_normal_mask_power,
    in float vertex_normal_mask_width,
    in float blend_offset,
    in float blend_sharpness
    )
{
    /// blend mask from vertex normals instead of vertex color
	float3 abs_normal = abs(SHADER_DATA.common.normal);
    abs_normal = pow(abs_normal, vertex_normal_mask_power);
    float blend_mask = dot(abs_normal, vertex_normal_mask_width);
    blend_mask = (blend_mask > 1.5) ? 0.0 : ((blend_mask == 1.5) ? 0.0 : 1.0);

	// direction as parameter instead of only top mask
	float3 mask_direction = float3(mask_direction_x, mask_direction_y, mask_direction_z);


    float dir_mask = dot(mask_direction, SHADER_DATA.common.normal);
	
    //float dir_mask_mod = (dir_mask * lerp(0, blend_sample, blend_mask_power)) + dir_mask;		
    //mask_direction += ((dir_mask_mod + blend_offset) * blend_mask) * 2;
    //dir_mask = (dir_mask_mod + blend_offset) - mask_direction;

    blend_mask += ((dir_mask + blend_offset) * blend_mask) * 2;
    dir_mask = (dir_mask + blend_offset) - blend_mask;
							                                                                                            
	dir_mask = saturate(dir_mask);                                                                                        
	dir_mask = saturate(pow(dir_mask, blend_sharpness));
	
	return dir_mask;
}

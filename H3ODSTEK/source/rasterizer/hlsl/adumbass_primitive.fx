#ifdef disable_register_reorder
// magic pragma given to us by the DX10 team
// to disable the register reordering pass that was
// causing a lot of pain on the PC side of the compiler
// with this pragma we get a massive speedup on compile times
// on the PC side
//#pragma ruledisable 0x0a0c0101
#endif // #ifdef disable_register_reorder

// rename entry point of passes 
#define vertex_shader static_prt_quadratic_vs//lightmap_debug_mode_vs
//static_per_pixel_vs   //static_sh_vs  //static_prt_quadratic_vs   //static_per_pixel_vs   // static_per_vertex_vs
//dynamic_light_vs//shadow_generate_vs    //shadow_apply_vs/  /albedo_vs  //  static_prt_ambient_vs // default_vs
#define fragment_shader static_prt_ps//lightmap_debug_mode_ps
//static_per_pixel_ps//static_sh_ps //static_prt_ps //static_per_pixel_ps   //static_per_vertex_ps
//dynamic_light_ps//shadow_generate_ps    //shadow_apply_ps   //albedo_ps  //  static_prt_ps // default_ps

#define vertex_shader_2 dynamic_light_vs
#define fragment_shader_2 dynamic_light_ps


#include "global.fx"
#include "hlsl_constant_mapping.fx"
#include "decal_registers.fx"
// The strings in this test should be external preprocessor defines
#define TEST_CATEGORY_OPTION(cat, opt) (category_##cat== category_##cat##_option_##opt)
#define IF_CATEGORY_OPTION(cat, opt) if (TEST_CATEGORY_OPTION(cat, opt))
#define IF_NOT_CATEGORY_OPTION(cat, opt) if (!TEST_CATEGORY_OPTION(cat, opt))

#if DX_VERSION == 9
#define CATEGORY_PARAM(_name) PARAM(int, _name)
#elif DX_VERSION == 11
#define CATEGORY_PARAM(_name) PARAM(float, _name)
#endif

#ifndef category_blend_mode
CATEGORY_PARAM(category_blend_mode);
#endif
#ifndef category_primitive
CATEGORY_PARAM(category_primitive);
#endif
#ifndef category_env_mapping
CATEGORY_PARAM(category_env_mapping);
#endif


PARAM_SAMPLER_2D(dynamic_light_gel_texture);
PARAM_SAMPLER_2D(base_map);
PARAM(float4, base_map_xform);
PARAM_SAMPLER_2D(bump_map);
PARAM_SAMPLER_2D(palette);
PARAM_SAMPLER_2D(uv_map);

PARAM(float4, color);
PARAM(float3, change_color_0);
PARAM(float, color_multiplier);
PARAM(float, gradient_blend_factor);
PARAM(float4, color1);

PARAM(float, decal_scale_x);
PARAM(float, decal_scale_y);
PARAM(float, decal_scale_z);
PARAM(float, projection_sharpness);

PARAM(float, edge_fade_range);
PARAM(float, edge_fade_falloff);
PARAM(float, edge_fade_alpha_power);
PARAM(float, projection_clip);
PARAM(float, depth_offset);
PARAM(float, alpha_clip_scale);


// ssao
PARAM_SAMPLER_2D(noise_map);
PARAM(float4, noise_map_xform);
PARAM(float, total_strength);
PARAM(float, base);
PARAM(float, area);
PARAM(float, ssao_falloff);
PARAM(float, radius);
//PARAM_SAMPLER_2D(depth_sampler_a);
//PARAM_SAMPLER_2D(depth_sampler_b);
// ssao

PARAM(float, checker_density);


PARAM(bool, alpha_invert);
PARAM(bool, alpha_location);
PARAM(float, rotation_angle);
PARAM(bool, rotated_uvs);

PARAM(bool, order3_area_specular);

PARAM_SAMPLER_2D(trajectory_helper_texture);
PARAM(float4, trajectory_helper_texture_xform);
PARAM(float4, trajectory_helper_color);
PARAM(float, projectile_initial_velocity);
PARAM(float, projectile_max_time);
PARAM(float, projectile_max_range);
PARAM(float, projectile_gravity);
PARAM(float, line_width);
PARAM(float, segment_count);
PARAM(float, dash_length);
PARAM(float, soft_edge_min);
PARAM(float, soft_edge_max);
PARAM(float, soft_edge_multiplier);


PARAM(float, position_x);
PARAM(float, position_y);
PARAM(float, position_z);



// vertex shader rain params


PARAM(float, rain_time);
PARAM(float, rain_speed);
PARAM(float, fall_distance);
PARAM(float, streak_length);
PARAM(float, streak_width);
PARAM(float, random_offset);

// end vertex shader rain params


 // We set the sampler address mode to black border in the render_method_option.  That guarantees no effect
// for most blend modes, but not all.  For the other modes, we do a pixel kill.
#define BLACK_BORDER_INSUFFICIENT (TEST_CATEGORY_OPTION(blend_mode, opaque) \
|| TEST_CATEGORY_OPTION(blend_mode, multiply)								\
|| TEST_CATEGORY_OPTION(blend_mode, double_multiply)						\
|| TEST_CATEGORY_OPTION(blend_mode, inv_alpha_blend))						\

// Even with this turned on, we get z-fighting, because the decal is not guaranteed to list the
// verts in the same order as the underlying mesh
#undef REPRODUCIBLE_Z


#include "hlsl_vertex_types.fx"
//#include "hlsl_constant_persist.fx"
//#include "hlsl_constant_oneshot.fx"
#include "deform.fx"
#include "blend.fx"
#include "player_emblem.fx"
#include "clip_plane.fx"
#include "utilities.fx"
#include "spherical_harmonics.fx"
#include "simple_lights.fx"
#include "texture_xform.fx"
#include "adumbass_matrix.hlsl"
#include "adumbass_functions.fx"
#include "adumbass_packing.fx"
//#include "adumbass_cook_torrance.fx"
//#include "adumbass_environment_mapping.fx"

#include "entry.fx"
#include "atmosphere.fx"
#include "debug_modes.fx"



struct s_primitive_data
{
    float4      screen_position;                 // screen pixel position, not divided by w
	float4	 	texcoord;		            // xy vert texcoord, zw para texcoord

	float4	 	normal;		                // vertex normals
	float4	 	binormal;
	float4	 	tangent;
    float3x3	TBN;                        // tangent_frame
    
    float4x4     world_to_oject;

    float3      fragment_to_camera_world;   // world space vector from vertex to eye/camera
    float3	 	view_dir;	                // normalized
    float3		view_dir_tangent_space;		// = mul(TBN, mat.view_dir_world_space);
	//float3		view_reflect_dir;		    // ReflectionVector = reflect(-mat.view_dir_world_space, mat.v_normal);

    float4      scale;                      // currenttly wpos
    float4      position_vs;
    float       sampled_depth;
    float       linear_depth;
    
    float3      object_center;
    float3      world_ray_vs;
    float3      world_position;
    float3      object_position;

    float3      vs_rain_color;

    //float4      g_buffer_albedo;
    //float4      g_buffer_normal;
    //float4      out_color_0;
    //float4      out_color_1;
    //float       gbuffer_mat_id;

};

//#include "adumbass_albedo_pass.fx"
/*
#define ENVMAP_TYPE(env_map_type) ENVMAP_TYPE_##env_map_type
#define ENVMAP_TYPE_none 0
#define ENVMAP_TYPE_per_pixel 1
#define ENVMAP_TYPE_dynamic 2
#define ENVMAP_TYPE_from_flat_texture 3
#define ENVMAP_TYPE_from_flat_texture_as_cubemap 4

#define CALC_ENVMAP(env_map_type) calc_environment_map_##env_map_type##_ps

*/

/*float3 calc_environment_map_ps(float3 view_dir, float3 normal, float3 view_reflect_dir, float4 envmap_specular_reflectance_and_roughness, float3 envmap_area_specular_only, float roughness)
{
    IF_CATEGORY_OPTION(env_mapping, none)
	{
        return calc_environment_map_none_ps(view_dir, normal, view_reflect_dir, envmap_specular_reflectance_and_roughness, envmap_area_specular_only, roughness);
	}
    IF_CATEGORY_OPTION(env_mapping, per_pixel)
	{
        return calc_environment_map_per_pixel_ps(view_dir, normal, view_reflect_dir, envmap_specular_reflectance_and_roughness, envmap_area_specular_only, roughness);
	}
    IF_CATEGORY_OPTION(env_mapping, dynamic)
	{
        return calc_environment_map_dynamic_ps(view_dir, normal, view_reflect_dir, envmap_specular_reflectance_and_roughness, envmap_area_specular_only, roughness);
	}
    IF_CATEGORY_OPTION(env_mapping, from_flat_texture)
	{
        return calc_environment_map_dynamic_ps(view_dir, normal, view_reflect_dir, envmap_specular_reflectance_and_roughness, envmap_area_specular_only, roughness);
	}
}*/

 
#ifndef APPLY_OVERLAYS
#define APPLY_OVERLAYS(color, texcoord, view_dot_normal)
#endif // APPLY_OVERLAYS

// define before render_target.fx
#ifndef LDR_ALPHA_ADJUST
#define LDR_ALPHA_ADJUST g_exposure.w
#endif
#ifndef HDR_ALPHA_ADJUST
#define HDR_ALPHA_ADJUST g_exposure.b
#endif
#ifndef DARK_COLOR_MULTIPLIER
#define DARK_COLOR_MULTIPLIER g_exposure.g
#endif


// Don't apply gamma twice!  This should really be taken care of in render_target.fx . 
#if TEST_CATEGORY_OPTION(blend_mode, multiply) || TEST_CATEGORY_OPTION(blend_mode, double_multiply)
#define LDR_gamma2 false
#define HDR_gamma2 false
#endif

#define blend_mode_USES_SRC_ALPHA (!(						\
	TEST_CATEGORY_OPTION(blend_mode, opaque) ||				\
	TEST_CATEGORY_OPTION(blend_mode, additive) ||			\
	TEST_CATEGORY_OPTION(blend_mode, multiply) ||			\
	TEST_CATEGORY_OPTION(blend_mode, double_multiply) ||	\
	TEST_CATEGORY_OPTION(blend_mode, maximum) ||			\
	TEST_CATEGORY_OPTION(blend_mode, multiply_add)			\
))

//#include "bump_mapping.fx"
#include "albedo_pass.fx"
#include "render_target.fx"
//#include "active_camo.fx"

float3 get_constant_analytical_light_dir_vs()
{
 	return -normalize(v_lighting_constant_1.xyz + v_lighting_constant_2.xyz + v_lighting_constant_3.xyz);		// ###ctchou $PERF : pass this in as a constant
}

PARAM_SAMPLER_2D(shadow_depth_map_1);
PARAM_SAMPLER_2D(depth_texture);
PARAM_SAMPLER_2D(selection_texture);
PARAM_SAMPLER_3D(cube_base_map);

//LOCAL_SAMPLER_2D(common_sampler, 8);


//LOCAL_SAMPLER_2D_IN_VIEWPORT_ALLWAYS(screen_sampler, 8);
PARAM(float, vs_anglefaderangecutoff_x);
PARAM(float, vs_anglefaderangecutoff_y);
PARAM(float, depthfaderange);
PARAM(bool, depthfadeinvert);
PARAM(bool, depth_fade_enabled);
PARAM(float3, vs_direction);
PARAM(float, vs_pos_x);
PARAM(float, test_1);

PARAM(float, diffuse_coefficient);
PARAM(float, area_specular_contribution);
PARAM(float, analytical_specular_contribution);
PARAM(float, environment_map_specular_contribution);
PARAM(float3, fresnel_color);
PARAM(float, roughness_scale);
PARAM(float, albedo_blend);
PARAM(float3, specular_tint);
PARAM(float, analytical_anti_shadow_control);


PARAM(float, luminosity);
PARAM(float, diffuse_factor);
PARAM(float, specular_factor);



PARAM(float4, scale_all);
PARAM(float4, envmap_pos_1);
PARAM(float4, envmap_pos_2);
PARAM_SAMPLER_CUBE(envmap_1);
PARAM_SAMPLER_CUBE(envmap_2);
PARAM_SAMPLER_2D_ARRAY(env_0);	// dynamic_environment_map_0





PARAM(float, debug_lod_1);
PARAM(float, debug_lod_2);
PARAM(float, debug_max_array_slices);

PARAM(float, sphere_radius_x);
PARAM(float, sphere_radius_y);
PARAM(float, sphere_radius_z);
PARAM(float, quad_size_x);
PARAM(float, quad_size_y);
PARAM(float, range);

PARAM(float, power);

PARAM(float, light_position);
PARAM(float, object_id);


PARAM(float3, sphereCenter ); // float3(0.0, 0.0, 0.0);  Center of the sphere
PARAM(float4, expandFactor ); // 1.2 Adjust this factor to control the expansion

PARAM(float4, intersect_color);
PARAM(float, min_intensity);

PARAM(float, roughness1);
PARAM(float, roughness2);
PARAM(float, pos1_z);

PARAM(float, scale);
PARAM(float2, offset);
PARAM(float, brightness);
PARAM(float, emulate_lighting);
PARAM(float, depth_fade_range);
PARAM(float, mesh_scale);

PARAM(float, v_tiles);
PARAM(float, pos_y);

PARAM(float, width_scale);
PARAM(float, height_scale);
PARAM(float, min_distance);
PARAM(float, max_distance);





static const float nearPlane = 0.078125;
static const float farPlane = 10240.0;
static const float FarClip = 1;

void calc_alpha_test_ps(in float2 texcoord, out float output_alpha)
{
	output_alpha = 1.0f;
}


float hash(float2 p) {
  return frac(sin(dot(p * 17.17, float2(14.91, 67.31))) * 4791.9511);
}

float noise(float2 x) {
  float2 p = floor(x);
  float2 f = frac(x);
  f = f * f * (3.0 - 2.0 * f);
  float2 a = float2(1.0, 0.0);
  return lerp(lerp(hash(p + a.yy), hash(p + a.xy), f.x),
         lerp(hash(p + a.yx), hash(p + a.xx), f.x), f.y);
}

float fbm(float2 x) {
  float height = 0.0;
  float amplitude = 0.5;
  float frequency = 3.0;
  for (int i = 0; i < 6; i++){
    height += noise(x * frequency) * amplitude;
    amplitude *= 0.5;
    frequency *= 2.0;
  }
  return height;
}

float3 mod_transform_point(in float4 position, in float4 node[3])
{
	float3 result;

	result.x= dot(position, node[0]);
	result.y= dot(position, node[1]);
	result.z= dot(position, node[2]);

	return result;
}

float3 mod_transform_vector(in float3 vect, in float4 node[3])
{
	float3 result;

	result.x= dot(vect, node[0].xyz);
	result.y= dot(vect, node[1].xyz);
	result.z= dot(vect, node[2].xyz);

	return result;
}



float compute_depth_fade(float target_depth, float sampled_depth, float  fade_range, float view_dot_normal)
{

//	float scene_depth= 1.0f - sampled_depth.x;
//	scene_depth= 1.0f / (global_depth_constants.x + scene_depth * global_depth_constants.y);	// convert to real depth
	float scene_depth = 1.0f / (global_depth_constants.z - sampled_depth * global_depth_constants.y);	// convert to real depth
	//float particle_depth = target_depth;
	float delta_depth = scene_depth - target_depth;
	return saturate(delta_depth * view_dot_normal / fade_range);

}


void BoundsClip(float3 v, float3 tr, float3 bl) {
    clip(v.x > tr.x || v.x < bl.x);
    clip(v.y > tr.y || v.y < bl.y);
    clip(v.z > tr.z || v.z < bl.z);
}


float tri_wave(float t, float offset, float y_offset) {
    return clamp(abs(frac(offset + t) * 2.0 - 1.0) + y_offset, 0, 1);
}




float4x4 OLDcreateModelMatrix(
    float4 model_matrix_0,
    float4 model_matrix_1,
    float4 model_matrix_2,
    float4 model_matrix_3
)
{
    float4x4 modelMatrix;

    //modelMatrix = float4x4(
    //    model_matrix_0.x, model_matrix_0.y, model_matrix_0.z, model_matrix_0.w,
   //    model_matrix_1.x, model_matrix_1.y, model_matrix_1.z, model_matrix_1.w,
    //    model_matrix_2.x, model_matrix_2.y, model_matrix_2.z, model_matrix_2.w,
   //    model_matrix_3.x, model_matrix_3.y, model_matrix_3.z, model_matrix_3.w
    //);

    modelMatrix = float4x4(model_matrix_0.x, model_matrix_1.x, model_matrix_2.x, model_matrix_3.x,
                           model_matrix_0.y, model_matrix_1.y, model_matrix_2.y, model_matrix_3.y,
                           model_matrix_0.z, model_matrix_1.z, model_matrix_2.z, model_matrix_3.z,
                           model_matrix_0.w, model_matrix_1.w, model_matrix_2.w, model_matrix_3.w);


    return modelMatrix;
}




float4x4 construct_orthonormal_matrix(
        //float4 Nodes_0 , 
        //float4 Nodes_1 , 
        //float4 Nodes_2
    )
{
    float4x4 orthonormal_matrix;
    //float viewport_width = ps_global_viewport_bounds_pixel.z - ps_global_viewport_bounds_pixel.x;
    //float viewport_height = ps_global_viewport_bounds_pixel.w - ps_global_viewport_bounds_pixel.y;
    float width = ps_global_viewport_res.x;
    float height = ps_global_viewport_res.y;

    float w = 2/width;
    float h = 2/height;
    float a = 1.0f / (1-nearPlane);
    float b = -a * nearPlane;

    orthonormal_matrix = float4x4(
                    w, 0, 0, 0,
                    0, h, 0, 0,
                    0, 0, a, 0,
                    0, 0, b, 1);

    return orthonormal_matrix;
}








float4x4 construct_billboard_matrix(
        float4 Nodes_0 , 
        float4 Nodes_1 , 
        float4 Nodes_2
    )
{
    float4x4 billboard_matrix;

    // Transpose the matrix
   // modelMatrix = float4x4(Nodes_0.xyz, 0.0f,
   //                        Nodes_1.xyz, 0.0f,
    //                       Nodes_2.xyz, 0.0f,
    //                       0.0f, 0.0f, 0.0f, 1.0f);

    /*billboard_matrix = float4x4(
            Camera_Forward.x, Camera_Forward.x, Camera_Forward.x, 0.0f,
            Camera_Left.y, Camera_Left.y, Camera_Left.y, 0.0f,
            Camera_Up.z, Camera_Up.z, Camera_Up.z, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f);
    billboard_matrix = float4x4(
            Camera_Forward.x, Camera_Up.x, Camera_Left.x, 0.0f,
            Camera_Forward.y, Camera_Up.y, Camera_Left.y, 0.0f,
            Camera_Forward.z, Camera_Up.z, Camera_Left.z, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f);
               billboard_matrix = float4x4(
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1);
            
            */

      billboard_matrix = float4x4(
            1-Camera_Left.x, Camera_Up.x, Camera_Forward.x, 0.0f,
            1-Camera_Left.y, Camera_Up.y, Camera_Forward.y, 0.0f,
            1-Camera_Left.z, Camera_Up.z, Camera_Forward.z, 0.0f,
                    0, 0, 0, 1);

    // Extract translation and apply it to the last column
    billboard_matrix[3].xyz = float3(Nodes_0.w, Nodes_1.w, Nodes_2.w);
    return billboard_matrix;
}

float4x4 CreateCameraMatrix(float3 cameraPosition, float3 cameraForward, float3 cameraLeft, float3 cameraUp)
{
    // Create the view matrix
    float4x4 viewMatrix;

    viewMatrix[0] = float4(cameraLeft, 0);
    viewMatrix[1] = float4(cameraUp, 0);
    viewMatrix[2] = float4(-cameraForward, 0);
    viewMatrix[3] = float4(0, 0, 0, 1);

    // Apply translation (negative camera position)
    viewMatrix = mul(viewMatrix, float4x4(1, 0, 0, 0,
                                          0, 1, 0, 0,
                                          0, 0, 1, 0,
                                          -cameraPosition.x, -cameraPosition.y, -cameraPosition.z, 1));
    //return transpose(viewMatrix);
    return viewMatrix;
}



float4 ComputeScreenPos(float4 positionCS)
{
    float4 o = positionCS * 0.5f;
    o.xy = float2(o.x, o.y * 1) + o.w; //_ProjectionParams.x is 1.0 (or –1.0 if currently rendering with a flipped projection matrix)
    o.zw = positionCS.zw;
    return o;
}

// Take this and multiply your UV by the resulting mat2 to get the rotation
float2x2 rotationMatrix(float angle)
{
	angle *= M_PI / 180.0;
    float sine = sin(angle), cosine = cos(angle);
    return float2x2( cosine, -sine, 
                 sine,    cosine );
}


PARAM(float, initial_velocity);
PARAM(float, final_velocity);
PARAM(float, acceleration_range_min);
PARAM(float, acceleration_range_max);
PARAM(float, gravity_scale);
PARAM(float, maximum_range);
PARAM(float, predicted_end_point_x);
PARAM(float, predicted_end_point_y);
PARAM(float, predicted_end_point_z);

void unit_status_off_vs(
    inout vertex_type vertex,
    out float4 position,
	out float2 texcoord,
    out float4 wpos,
    out float4x4 world_to_oject,
    out float3 fragment_to_camera_world
	)
{
    position = 1;
    texcoord = 0;
    wpos = 0;
    world_to_oject = 0;0;
    fragment_to_camera_world = 0;
}

void trajectory_helper_off_vs(
    inout vertex_type vertex,
    out float4 position,
	out float2 texcoord,
    out float4 wpos,
    out float4x4 world_to_oject,
    out float3 fragment_to_camera_world
	)
{
    position = 1;
    texcoord = 0;
    wpos = 0;
    world_to_oject = 0;;
    fragment_to_camera_world = 0;
}

void decal_projector_off_vs(
    inout vertex_type vertex,
    out float4 position,
	out float2 texcoord,
    out float4 wpos,
    out float4x4 world_to_oject,
    out float3 fragment_to_camera_world
	)
{
    position = 1;
    texcoord = 0;
    wpos = 0;
    world_to_oject = 0;
    fragment_to_camera_world = 0;
}

void trajectory_helper_line_vs(
    inout vertex_type vertex,
    out float4 position,
	out float4 texcoord,
    out float4 wpos,
    out float3 fragment_to_camera_world,
    out float4 position_vs,
    out float4 normal,
    out float4 tangent,
    out float4 binormal,
    out float4x4 world_to_oject
	)
{
	float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    world_to_oject= construct_model_matrix(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;
    normal.xyz= vertex.normal;
	tangent.xyz= vertex.tangent;
	binormal.xyz= vertex.binormal;
    normal.w = 1;
    tangent.w = 1;
    binormal.w = 1;
    float3 initialPosition = float3(0, 0, 0);
    //float4x4 billboard_matrix = float4x4(
    //        Camera_Forward.x, Camera_Up.x, Camera_Left.x, 0.0f,
    //        Camera_Forward.y, Camera_Up.y, Camera_Left.y, 0.0f,
    //        Camera_Forward.z, Camera_Up.z, Camera_Left.z, 0.0f,
    //        0.0f, 0.0f, 0.0f, 1.0f);
    //float4x4 look_model_matrix = mul(  transpose(billboard_matrix), world_to_oject);  // SORTA WORKS FOR ORIENTATION

    initialPosition = mul(float4(initialPosition, 1.0f), world_to_oject); 
    float3 predicted_end_point = float3(predicted_end_point_x, predicted_end_point_y, predicted_end_point_z);

    //initialPosition = mul(float4(initialPosition, 1.0f), world_to_oject);
    predicted_end_point = mul(float4(predicted_end_point, 1.0f), world_to_oject);
    //initial_velocity
    //final_velocity
    //acceleration_range_min
    //acceleration_range_max
    //predicted_end_point
    //gravity_scale
    ////////////////

    // Calculate the direction from the origin to the predicted end point
    float3 direction = predicted_end_point - float3(0, 0, 0);

    // Calculate the distance to the predicted end point
    float distance = length(direction);

    // Normalize the direction vector
    direction = normalize(direction);

    // Calculate the velocity scaling factor based on the distance
    float velocityFactor = 1.0;
    if (distance > acceleration_range_min && distance <= acceleration_range_max)
    {
        velocityFactor = lerp(initial_velocity, final_velocity, (distance - acceleration_range_min) / (acceleration_range_max - acceleration_range_min));
    }
    else if (distance > acceleration_range_max)
    {
        velocityFactor = final_velocity;
    }

    // Apply gravity scaling
    float gravity = 9.8 * gravity_scale;

    // Calculate time of flight
    float timeOfFlight = (2 * velocityFactor * sin(0.5 * asin((gravity * distance) / (velocityFactor * velocityFactor)))) / gravity;

    // Calculate vertex displacement along the trajectory
    float t = saturate(2 * vertex.position.x / distance); // t parameterized from 0 to 1 along the line
    float3 displacement = direction * (velocityFactor * t * timeOfFlight);

    // Apply the displacement to the vertex position
    position = float4(vertex.position + displacement, 1.0);



    //////////////
    position = mul(position, world_to_oject);

	position = mul(position, View_Projection);

    float2 ScreenParams = float2(1.0 + 1.0/texture_size.y, 1.0 + 1.0 / texture_size.x);
    float ProjectionParams = -1;
	//projPos = float4(newPosition, position.w);

    fragment_to_camera_world = Camera_Position - vertex.position;
    //transpose
    //inverse
    //inverse_object_to_world = inverse(View_Projection);
    //inverse_view = inverse(View);
    texcoord.xy = vertex.texcoord;
    texcoord.zw = 1;
    wpos = position;//mul(vertex.position, View_Projection);
    position_vs = 0;
}

void trajectory_helper_vs(
    inout vertex_type vertex,
    uint vertexID : SV_VertexID,
    out float4 position,
	out float4 texcoord,
    out float4 wpos,
    out float3 fragment_to_camera_world,
    out float4 position_vs,
    out float4 normal,
    out float4 tangent,
    out float4 binormal,
    out float4x4 world_to_oject
	)
{    
    float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4x4 model_matrix = construct_model_matrix(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);
    world_to_oject = model_matrix;

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;
    normal.xyz= vertex.normal;
	tangent.xyz= vertex.tangent;
	binormal.xyz= vertex.binormal;
    //normal.w = 1;
    tangent.w = 1;
    binormal.w = 1;
    texcoord.xy = vertex.texcoord;
    //texcoord.zw = 1;


    // Each point spawns 2 vertices (left/right edge of ribbon)
    // So mesh needs SegmentCount * 2 vertices
    int   pointIndex = vertexID / 2;
    int   side       = vertexID % 2;  // 0 = left, 1 = right

    // Reconstruct arc position
    float3 origin  = model_matrix._m30_m31_m32;
    float3 forward = normalize(model_matrix._m00_m01_m02);
    float3 velocity = forward * projectile_initial_velocity;
    
    //float2 horizontalVel = float2(velocity.x, velocity.z);
    //float  horizontalSpeed = length(horizontalVel);

    wpos = mul(float4(vertex.position, 1.0f), (model_matrix));

/*
    // Real gravity
    float realGravity = 9.81 * projectile_gravity;

    // Flight time: solve for when Z returns to origin height
    // 0 = velocityZ * t - 0.5 * realGravity * t²
    // t(velocityZ - 0.5 * realGravity * t) = 0
    // t = 2 * velocityZ / realGravity  (non-zero solution)
    float velocityZ    = velocity.z;
    float flightTime   = (2.0 * velocityZ) / realGravity;
    // True horizontal range over that flight time
    float2 horizontalVel   = float2(velocity.x, velocity.y); // XY is horizontal in Z-up
    float  horizontalSpeed = length(horizontalVel);
    float  trueRange       = horizontalSpeed * flightTime;

    // Clamp to MaxRange
    float  effectiveRange  = min(trueRange, projectile_max_range);

    // Now sample along effectiveRange
    float dist = (float(pointIndex) / float(segment_count - 1)) * effectiveRange;
    float t    = (dist / effectiveRange) * flightTime; // t proportional to flight time

    float3 arcPos = origin + velocity * t + float3(0, 0, -0.5 * realGravity * t * t);
*/
/*
            
    // Gravity multiplier applied to standard gravity
    float gravityActual = projectile_gravity * 9.81;

    // Time the projectile is in the air until it returns to launch height (Z)
    // Solve: 0 = velocityZ*t - 0.5*gravityActual*t^2
    // t = 2*velocityZ / gravityActual
    float velocityZ    = velocity.z;  // Vertical component (Z+ up)
    float hangTime     = (2.0 * velocityZ) / gravityActual;

    // Horizontal speed (XY plane since Z is up)
    float horizontalSpeed = length(float2(velocity.x, velocity.y));

    // Actual horizontal distance traveled during hang time
    float actualRange  = horizontalSpeed * hangTime;

    // Clamp to MaxRange
    float simRange     = min(actualRange, projectile_max_range);

    // If MaxRange is hit before landing, find the time at that distance
    float simTime      = (actualRange > projectile_max_range) ? projectile_max_range / horizontalSpeed : hangTime;

    // Now sample using simTime across vertices
    float tNorm  = float(pointIndex) / float(segment_count - 1);
    float t      = tNorm * simTime;

    float3 arcPos = origin + velocity * t + float3(0, 0, -0.5 * gravityActual * t * t);
    */
    float adjusted_gravity = projectile_gravity * 4;
    float dist = (float(pointIndex) / float(segment_count - 1)) * projectile_max_range;
    //float spd  = ProjectileSpeed;

    float3 arcPos = origin + forward * dist + float3(0, 0, -0.5 * adjusted_gravity * (dist / projectile_initial_velocity) * (dist / projectile_initial_velocity));

    ////
    // Arc position for this vertex
    //float dist = (float(pointIndex) / float(segment_count - 1)) * projectile_max_range;
    //float t    = dist / projectile_initial_velocity;

    //float3 arcPos = origin + velocity * t + float3(0, 0, -0.5 * projectile_gravity * t * t);

    // Sample a nearby point to get the local tangent of the arc
    float distNext = ((float(pointIndex) + 0.5) / float(segment_count - 1)) * projectile_max_range;
    float tNext    = distNext / projectile_initial_velocity;

    float3 arcPosNext = origin
                    + velocity * tNext
                    + float3(0, 0, -0.5 * adjusted_gravity * tNext * tNext);

    float3 trajectory_tangent   = normalize(arcPosNext - arcPos);       // Direction along the arc
    float3 toCamera  = normalize(Camera_Position - arcPos);        // Vector toward camera
    float3 ribbonDir = normalize(cross(trajectory_tangent, toCamera));  // Perpendicular to both

    // Offset left/right along ribbonDir
    float  sign     = side == 0 ? -1.0 : 1.0;
    wpos.xyz = arcPos + ribbonDir * (sign * line_width * 0.5);


    // Transform from world space to clip space. 
    position = mul(float4(wpos.xyz, 1.0f), View_Projection);
    
    //output.position = mul(float4(wpos, 1.0), View_Projection);
    //output.uv       = float2(t / projectile_max_time, float(side));
    //output.alpha    = 1.0 - (t / projectile_max_time);

    //texcoord.zw = float2(t / projectile_max_time, float(side));
    //normal.w = 1.0 - (t / projectile_max_time);

    texcoord.zw = float2(float(pointIndex) / float(segment_count - 1), float(side));
    normal.w = 1.0 - (float(pointIndex) / float(segment_count - 1));

	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;
    position_vs = position;

}

float4 InvertRotations (float4 input)
            {
                float _FixtureRotationX, _FixtureBaseRotationY = 0;
                float sX, cX, sY, cY;
                sX = sin(radians(_FixtureRotationX));
                cX = cos(radians(_FixtureRotationX));
                float4x4 rotX = float4x4(1, 0, 0, 0,
                    0, cX, sX, 0,
                    0, -sX, cX, 0,
                    0, 0, 0, 1);
                sY = sin(radians(_FixtureBaseRotationY));
                cY = cos(radians(_FixtureBaseRotationY));
                float4x4 rotY = float4x4(cY, sY, 0, 0,
                    -sY, cY, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1);
                float4x4 combinedRot = mul(rotX, rotY);
                input = mul(combinedRot, input);
                return input;
            }


void unit_status_basic_vs(
    inout vertex_type vertex,
    out float4 position,
	out float4 texcoord,
    out float4 wpos,
    out float3 fragment_to_camera_world,
    out float4 position_vs,
    out float4 normal,
    out float4 tangent,
    out float4 binormal,
    out float4x4 world_to_oject
	)
{
	float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4x4 model_matrix = construct_model_matrix_transform_only(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;
    normal.xyz= vertex.normal;
	tangent.xyz= vertex.tangent;
	binormal.xyz= vertex.binormal;
    normal.w = 1;
    tangent.w = 1;
    binormal.w = 1;
    float3 object_center = float3(0,0,0);
    float4x4 billboard_matrix = float4x4(
            Camera_Forward.x, Camera_Left.x, Camera_Up.x, 0.0f,
            Camera_Forward.y, Camera_Left.y, Camera_Up.y, 0.0f,
            Camera_Forward.z, Camera_Left.z, Camera_Up.z, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f);
    float4x4 look_model_matrix = mul(transpose(billboard_matrix), model_matrix);  // SORTA WORKS FOR ORIENTATION

    object_center = mul(float4(object_center, 1.0f), look_model_matrix); 
    //float scale_distance= abs(length(Camera_Position - object_center));
    vertex.position.z *= height_scale;
    vertex.position.y *= width_scale;
    vertex.position.xyz *= scale;
   // vertex.position.xyz *=  lerp(scale_at_min_distance, scale_at_max_distance, clamp(scale_distance, 0, max_distance));
 
    wpos = mul(float4(vertex.position, 1.0f), look_model_matrix);  //  SORTA WORKS FOR ORIENTATION


    // Transform from world space to clip space. 
    position= mul(wpos, View_Projection);
    //position.z += 0.1;
    texcoord.xy = vertex.texcoord;
    texcoord.zw = 1;
    wpos = position;
    world_to_oject = billboard_matrix;
    //inverse_object_to_world = inverse(View_Projection);
    //inverse_view = inverse(View);
	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;
    position_vs = position;
    //CALC_CLIP(position);
}


void active_camo_vs(
    in vertex_type vertex,
    uint vertexID : SV_VertexID,
    CLIP_OUTPUT
    out float4 position : SV_Position,
	out float2 texcoord : TEXCOORD0,
    out float4 wpos : TEXCOORD1
	)
{
	float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4x4 model_matrix = construct_model_matrix(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;
    texcoord.xy = vertex.texcoord;
    float3 object_center = float3(0,0,0);
    float4x4 billboard_matrix = float4x4(
            Camera_Forward.x, Camera_Forward.y, Camera_Forward.z, 0.0f,
            Camera_Left.x, Camera_Left.y, Camera_Left.z, 0.0f,
            Camera_Up.x, Camera_Up.y, Camera_Up.z, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f);
    float4x4 look_model_matrix = mul( (billboard_matrix), model_matrix);  // SORTA WORKS FOR ORIENTATION

    object_center = mul(float4(object_center, 1.0f), look_model_matrix); 
    // Generates the 4 corners of a quad from vertex index
    float2 corners[4] = {
        float2(-1, -1),  // 0: bottom left
        float2(-1,  1),  // 1: top left
        float2( 1, -1),  // 2: bottom right
        float2( 1,  1),  // 3: top right
    };

    float2 ndcPos = corners[vertexID] * scale + float2(position_x, position_y);
 
    
    position = float4(ndcPos, 0.5, 1.0);

    wpos = mul(float4(vertex.position, 1.0f), look_model_matrix);
    // Transform from world space to clip space. 
    position = mul(wpos, View_Projection);

    float2 uv = float2((vertexID << 1) & 2, vertexID & 2);

        uv *= position_x;
        uv += position_y;
        position = float4(uv.x, uv.y, position_z, 1.0);
            wpos = position;
	CALC_CLIP(position);
}


void test_screen_space_hud_vs(
    inout vertex_type vertex,
    uint vertexID : SV_VertexID,
    out float4 position,
	out float4 texcoord,
    out float4 wpos,
    out float3 fragment_to_camera_world,
    out float4 position_vs,
    out float4 normal,
    out float4 tangent,
    out float4 binormal,
    out float4x4 world_to_oject
	)
{
	float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4x4 model_matrix = construct_model_matrix(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    //vertex.position.xyz += float3(position_x, position_y, position_z);
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;
    normal.xyz= vertex.normal;
	tangent.xyz= vertex.tangent;
	binormal.xyz= vertex.binormal;
    normal.w = 1;
    tangent.w = 1;
    binormal.w = 1;
   
    float3 object_center = float3(0,0,0);
    float4x4 billboard_matrix = float4x4(
            Camera_Forward.x, Camera_Forward.y, Camera_Forward.z, 0.0f,
            Camera_Left.x, Camera_Left.y, Camera_Left.z, 0.0f,
            Camera_Up.x, Camera_Up.y, Camera_Up.z, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f);
    float4x4 look_model_matrix = mul( (billboard_matrix), model_matrix);  // SORTA WORKS FOR ORIENTATION

    object_center = mul(float4(object_center, 1.0f), look_model_matrix); 
    //float scale_distance= abs(length(Camera_Position - object_center));
    //vertex.position.z *= height_scale;
    //vertex.position.y *= width_scale;
    //vertex.position.xyz *= scale;

   // vertex.position.xyz *=  lerp(scale_at_min_distance, scale_at_max_distance, clamp(scale_distance, 0, max_distance));

    //wpos = mul(float4(vertex.position, 1.0f), look_model_matrix);  //  SORTA WORKS FOR ORIENTATION

    // Generates the 4 corners of a quad from vertex index
    float2 corners[4] = {
        float2(-1, -1),  // 0: bottom left
        float2(-1,  1),  // 1: top left
        float2( 1, -1),  // 2: bottom right
        float2( 1,  1),  // 3: top right
    };

    float2 ndcPos = corners[vertexID] * scale + float2(position_x, position_y);
 
    
    position = float4(ndcPos, 0.5, 1.0);


/*
    float4x4 test_matrix2 = float4x4(
            Camera_Forward.x, Screen_X.x, Screen_Y.x, 0.0f,
            Camera_Forward.y, Screen_X.y, Screen_Y.y, 0.0f,
            Camera_Forward.z, Screen_X.z, Screen_Y.z, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f);


    float4x4 test_matrix = mul( (test_matrix2), model_matrix);  // SORTA WORKS FOR ORIENTATION

*/

    //vertex.position = vertex.position + float3(position_x, position_y, 0.0);
   // vertex.position.xyz *= 100;
    wpos = mul(float4(vertex.position, 1.0f), model_matrix);  //  SORTA WORKS FOR ORIENTATION

   // vertex.position = float3(position_x, position_y, 0.5);
    //position = float4(vertex.position.xy, 0.5, 1.0);
   // position = mul(float4(vertex.position, 1.0f), model_matrix);
    // Transform from world space to clip space. 
    position = mul(wpos, View_Projection);


//works
    float2 uv = float2((vertexID << 1) & 2, vertexID & 2);
   //works //        position =  float4(uv * 2.0 - 1.0, 0.0, 1.0);
     //works   //position =  float4(uv  , 0.5, 1.0);
// below works no need for matrix mul
        uv *= position_x;
        uv += position_y;
        //position = float4(uv.x, uv.y, position_z, 1.0);

//     position = mul(position, model_matrix);
//         position = mul(position, View_Projection);



                
    //position = float4(0.0, 0.0, 0.5, 1.0);
  //  position = float4(vertex.position.xy, 0.0, 1.0); 

/*
    // Override xy, keep clip.w for depth to work correctly
    position.xy = corners[vertexID] * scale + float2(position_x, position_y);
    position.z = 0.5 * position.w; // keep z in valid range
*/


    //position= mul(float4(position.xy, 0.5, 1.0), View_Projection);
   //position = float4(position.xy, 0.5, 1.0);
    //position.z += 0.1;
    texcoord.xy = vertex.texcoord;
    texcoord.zw = 1;
    wpos = position;
    world_to_oject = model_matrix;
    //inverse_object_to_world = inverse(View_Projection);
    //inverse_view = inverse(View);
	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;
    position_vs = position;
    //CALC_CLIP(position);
}

void test_ssao_vs(
    inout vertex_type vertex,
    uint vertexID : SV_VertexID,
    out float4 position,
	out float4 texcoord,
    out float4 wpos,
    out float3 fragment_to_camera_world,
    out float4 position_vs,
    out float4 normal,
    out float4 tangent,
    out float4 binormal,
    out float4x4 world_to_oject
	)
{
	float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4x4 model_matrix = construct_model_matrix(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    //vertex.position.xyz += float3(position_x, position_y, position_z);
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;
    normal.xyz= vertex.normal;
	tangent.xyz= vertex.tangent;
	binormal.xyz= vertex.binormal;
    normal.w = 1;
    tangent.w = 1;
    binormal.w = 1;
   /*//comment
    float3 object_center = float3(0,0,0);
    float4x4 billboard_matrix = float4x4(
            Camera_Forward.x, Camera_Forward.y, Camera_Forward.z, 0.0f,
            Camera_Left.x, Camera_Left.y, Camera_Left.z, 0.0f,
            Camera_Up.x, Camera_Up.y, Camera_Up.z, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f);
    float4x4 look_model_matrix = mul( (billboard_matrix), model_matrix);  // SORTA WORKS FOR ORIENTATION

    object_center = mul(float4(object_center, 1.0f), look_model_matrix); 
    */
    //float scale_distance= abs(length(Camera_Position - object_center));
    //vertex.position.z *= height_scale;
    //vertex.position.y *= width_scale;
    //vertex.position.xyz *= scale;

   // vertex.position.xyz *=  lerp(scale_at_min_distance, scale_at_max_distance, clamp(scale_distance, 0, max_distance));

    //wpos = mul(float4(vertex.position, 1.0f), look_model_matrix);  //  SORTA WORKS FOR ORIENTATION

    // Generates the 4 corners of a quad from vertex index
/*//comment
    float2 corners[4] = {
        float2(-1, -1),  // 0: bottom left
        float2(-1,  1),  // 1: top left
        float2( 1, -1),  // 2: bottom right
        float2( 1,  1),  // 3: top right
    };

    float2 ndcPos = corners[vertexID] * scale + float2(position_x, position_y);
 
    
    position = float4(ndcPos, 0.5, 1.0);
    */


/*
    float4x4 test_matrix2 = float4x4(
            Camera_Forward.x, Screen_X.x, Screen_Y.x, 0.0f,
            Camera_Forward.y, Screen_X.y, Screen_Y.y, 0.0f,
            Camera_Forward.z, Screen_X.z, Screen_Y.z, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f);


    float4x4 test_matrix = mul( (test_matrix2), model_matrix);  // SORTA WORKS FOR ORIENTATION

*/

    //vertex.position = vertex.position + float3(position_x, position_y, 0.0);
   // vertex.position.xyz *= 100;
    wpos = mul(float4(vertex.position, 1.0f), model_matrix);  //  SORTA WORKS FOR ORIENTATION
    fragment_to_camera_world = (wpos.xyz - Camera_Position);
   // vertex.position = float3(position_x, position_y, 0.5);
    //position = float4(vertex.position.xy, 0.5, 1.0);
   // position = mul(float4(vertex.position, 1.0f), model_matrix);
    // Transform from world space to clip space. 
    position = mul(wpos, View_Projection);


//works
/* //comment
    float2 uv = float2((vertexID << 1) & 2, vertexID & 2);
   //works //        position =  float4(uv * 2.0 - 1.0, 0.0, 1.0);
     //works   //position =  float4(uv  , 0.5, 1.0);
// below works no need for matrix mul
        uv *= position_x;
        uv += position_y;
        position = float4(uv.x, uv.y, position_z, 1.0);
        */

//     position = mul(position, model_matrix);
//         position = mul(position, View_Projection);



                
    //position = float4(0.0, 0.0, 0.5, 1.0);
  //  position = float4(vertex.position.xy, 0.0, 1.0); 

/*
    // Override xy, keep clip.w for depth to work correctly
    position.xy = corners[vertexID] * scale + float2(position_x, position_y);
    position.z = 0.5 * position.w; // keep z in valid range
*/


    //position= mul(float4(position.xy, 0.5, 1.0), View_Projection);
   //position = float4(position.xy, 0.5, 1.0);
    //position.z += 0.1;
    texcoord.xy = vertex.texcoord;
    texcoord.zw = 1;
    wpos = position;
    world_to_oject = inverse(model_matrix);
    //inverse_object_to_world = inverse(View_Projection);
    //inverse_view = inverse(View);
	// world space vector from vertex to eye/camera
	//fragment_to_camera_world= Camera_Position - vertex.position;

    position_vs = position;
    //CALC_CLIP(position);
}

void area_light_sphere_vs(
    inout vertex_type vertex,
    in uint vertex_id,
    out float4 position,
	out float4 texcoord,
    out float4 attenuation,     // wpos aka out float3      world_ray_vs,
    out float3 fragment_to_camera_world,
    out float4 position_vs,
    out float4 normal,
    out float4 tangent,
    out float4 binormal,
    out float4x4 world_to_oject
	)
{
	float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4x4 model_matrix = construct_model_matrix(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;

    //float uv_mask = sample2Dlod(uv_map, vertex.texcoord.xy, 0);
    vertex.position.x *= (decal_scale_x);
    vertex.position.y *= (decal_scale_x);
    vertex.position.z *= (decal_scale_x);

    
    normal.xyz= vertex.normal;
	tangent.xyz= vertex.tangent;
	binormal.xyz= vertex.binormal;

    //float3 object_center = float3(0,0,0);
    /*float4x4 billboard_matrix = float4x4(
            Camera_Forward.x, Camera_Up.x, Camera_Left.x, 0.0f,
            Camera_Forward.y, Camera_Up.y, Camera_Left.y, 0.0f,
            Camera_Forward.z, Camera_Up.z, Camera_Left.z, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f);
    float4x4 look_model_matrix = mul(  transpose(billboard_matrix), model_matrix);  // SORTA WORKS FOR ORIENTATION
    */

    //object_center = mul(float4(object_center, 1.0f), look_model_matrix); 
    //float scale_distance= abs(length(Camera_Position - object_center));
    
    float3 object_center = mul(float4(0, 0, 0, 1), model_matrix).xyz;   // Object center in world space
    float3 worldPos = mul(float4(vertex.position.xyz, 1.0), model_matrix).xyz;                   // Vertex position in world space
    float3 offset = (worldPos - object_center);                            // Distance from center
    normal.w = offset.x;
    tangent.w = offset.y;
    binormal.w = offset.z;
 
   // vertex.position.xyz *=  lerp(scale_at_min_distance, scale_at_max_distance, clamp(scale_distance, 0, max_distance));

    //attenuation.xyz = float3(decal_scale_x, decal_scale_y, decal_scale_z);
    
    // Offset the first 4 vertices upward
    /*if (vertex_id < 4)
    {
        vertex.position.xyz *= (2 * attenuation.xyz);
        position = mul(float4(vertex.position, 1.0f), look_model_matrix);  //  SORTA WORKS FOR ORIENTATION
        position= mul(position, View_Projection);
        position.w -= color.a; 
        
       // position.z += 1.0; // Adjust the offset value as needed
    }*/

    //else
    //{
        position = mul(float4(vertex.position, 1.0f), model_matrix);
        position= mul(position, View_Projection);
        binormal.xyz = extract_scale_halo(model_matrix); // radius
    //}





    /*if (uv_mask == 1)
    {
        vertex.position.xyz *= (2 * attenuation.xyz);
        position = mul(float4(vertex.position, 1.0f), look_model_matrix);  //  SORTA WORKS FOR ORIENTATION
        position= mul(position, View_Projection);
        position.w -= 1;
        
    }
    else
    {
        position = mul(float4(vertex.position, 1.0f), model_matrix);
        position= mul(position, View_Projection);
        binormal.xyz = extract_scale_halo(model_matrix); // radius
    }*/
    
    position_vs = mul(float4(vertex.position, 1.0f), model_matrix);
    attenuation.xyz = (position_vs.xyz - Camera_Position);
    attenuation.w = 1;


    texcoord.xy = vertex.texcoord;
    texcoord.z = 1;
    texcoord.w = vertex_id;

  
    world_to_oject = inverse(model_matrix);

	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;
 

}


// Function to calculate rotation matrix based on normal
float3x3 RotationMatrixFromNormal(float3 normal)
{
    // Calculate a rotation matrix that aligns the Z-axis with the given normal
    float3 up = float3(0, 0, 1); // Assuming the decal box's local Z-axis is up
    float3 axis = cross(up, normal);
    float dotProduct = dot(up, normal);
    float angle = acos(dotProduct);

    // Create rotation matrix
    float3x3 rotationMatrix = float3x3(
        cos(angle) + axis.x * axis.x * (1 - cos(angle)),
        axis.x * axis.y * (1 - cos(angle)) - axis.z * sin(angle),
        axis.x * axis.z * (1 - cos(angle)) + axis.y * sin(angle),

        axis.y * axis.x * (1 - cos(angle)) + axis.z * sin(angle),
        cos(angle) + axis.y * axis.y * (1 - cos(angle)),
        axis.y * axis.z * (1 - cos(angle)) - axis.x * sin(angle),

        axis.z * axis.x * (1 - cos(angle)) - axis.y * sin(angle),
        axis.z * axis.y * (1 - cos(angle)) + axis.x * sin(angle),
        cos(angle) + axis.z * axis.z * (1 - cos(angle))
    );

    return rotationMatrix;
}

// Apply rotation to vertex
float3 RotateVertex(float3 pos, float3 normal)
{
    // Get rotation matrix
    float3x3 rotationMatrix = RotationMatrixFromNormal(normal);

    // Apply rotation to vertex
    return mul(rotationMatrix, pos);
}


void calc_prt_ambient(
    float3 position,
    float3 normal,
	in float prt_c0_c3,
    out float4 prt_ravi_diff,
    out float3 extinction,
	out float3 inscatter
	)
{

//	float prt_c0= PRT_C0_DEFAULT;
	float prt_c0= prt_c0_c3;

	float ambient_occlusion= prt_c0;
	float lighting_c0= 	dot(v_lighting_constant_0.xyz, float3(1.0f/3.0f, 1.0f/3.0f, 1.0f/3.0f));			// ###ctchou $PERF convert to monochrome before passing in!
	float ravi_mono= (0.886227f * lighting_c0)/3.1415926535f;
	float prt_mono= ambient_occlusion * lighting_c0;
		
	prt_mono= max(prt_mono, 0.01f);													// clamp prt term to be positive
	ravi_mono= max(ravi_mono, 0.01f);									// clamp ravi term to be larger than prt term by a little bit
	float prt_ravi_ratio= prt_mono /ravi_mono;
	prt_ravi_diff.x= prt_ravi_ratio;												// diffuse occlusion % (prt ravi ratio)
	prt_ravi_diff.y= prt_mono;														// unused
	prt_ravi_diff.z= (ambient_occlusion * 3.1415926535f)/0.886227f;					// specular occlusion % (ambient occlusion)
	prt_ravi_diff.w= min(dot(normal, get_constant_analytical_light_dir_vs()), prt_mono);		// specular (vertex N) dot L (kills backfacing specular)
	

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

void decal_projector_vs(
    inout vertex_type vertex,
    out float4 position,
	out float4 texcoord,
    out float4 wpos,
    out float3 fragment_to_camera_world,
    out float4 position_vs,
    out float4 normal,
    out float4 tangent,
    out float4 binormal,
    out float3 view_dir,
	in float3 prt_c0_c2,
	in float3 prt_c3_c5,
	in float3 prt_c6_c8,	
    out float4 prt_ravi_diff,
    out float3 extinction, 
    out float3 inscatter, 
    out float4x4 world_to_oject
	)
{
	float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];
    float4x4 model_matrix = construct_model_matrix(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);
    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;

    vertex.position.x *= (decal_scale_x);
    vertex.position.y *= (decal_scale_y);
    vertex.position.z *= (decal_scale_z);
    
	normal.xyz= transform_vector(vertex.normal,local_to_world_transform);
	binormal.xyz= transform_vector(vertex.binormal, local_to_world_transform);
	tangent.xyz= transform_vector(vertex.tangent, local_to_world_transform);

    normal.xyz= normalize(normal.xyz);
	binormal.xyz= normalize(binormal.xyz);
	tangent.xyz= normalize(tangent.xyz);

    position_vs = mul( float4(vertex.position, 1.0f), model_matrix);
    fragment_to_camera_world = (position_vs.xyz - Camera_Position);

    view_dir= Camera_Position - vertex.position;

    position = mul(position_vs, View_Projection);
 
    wpos = position_vs;
    position_vs = position ;
    texcoord.xy = vertex.texcoord.xy;
    world_to_oject = inverse(model_matrix);

    float3 scale = extract_scale_halo(model_matrix);
    float3 edge_distances = (scale - abs(vertex.position)) / scale;
    edge_distances = min(min(edge_distances.x, edge_distances.y), edge_distances.z);
    wpos.xyz = edge_distances;
// 	prt_ravi_diff.x= 1.0f;														// diffuse occlusion % (prt ravi ratio)
// 	prt_ravi_diff.y= 1.0f;														// unused
// 	prt_ravi_diff.z= 1.0f;														// specular occlusion % (ambient occlusion)
// 	prt_ravi_diff.w= dot(normal, get_constant_analytical_light_dir_vs());				// specular (vertex N) dot L (kills backfacing specular)
//    prt_quadratic(
//		prt_c0_c2,
//		prt_c3_c5,
//		prt_c6_c8,
//		normal,
//		local_to_world_transform,
//		prt_ravi_diff);

    prt_ravi_diff.xyz = prt_c0_c2;
    prt_ravi_diff.w = prt_c3_c5.x;
    texcoord.zw = prt_c3_c5.yz;
    normal.w = prt_c6_c8.x;
    tangent.w = prt_c6_c8.y;
    binormal.w = prt_c6_c8.z;
    compute_scattering(Camera_Position, vertex.position, extinction, inscatter);

    //calc_prt_ambient(vertex.position, vertex.normal, prt_c0_c3, prt_ravi_diff, extinction, inscatter);
}

/*
void albedo_vs(//albedo_vs(
    in vertex_type vertex,
    in uint         vertex_id               : SV_VertexID,
    out float4      position                : SV_Position,
    //out float       clip_distance           : SV_ClipDistance,
    CLIP_OUTPUT
	out float4      texcoord                : TEXCOORD0,
    out float4      wpos                    : TEXCOORD1,
    out float3      fragment_to_camera_world: TEXCOORD2,
	out float4x4    world_to_oject          : TEXCOORD3,
    out float4      position_vs             : TEXCOORD7,
    out float4      normal                  : TEXCOORD8,
    out float4      tangent                 : TEXCOORD9,
    out float4      binormal                : TEXCOORD10
	)
{


        IF_CATEGORY_OPTION(primitive, test_screen_space_hud)
    {
        test_screen_space_hud_vs(vertex, vertex_id, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, world_to_oject);
	}

    CALC_CLIP(position);
}
 */

void point_light_vs(
    inout vertex_type vertex,
    in uint vertex_id,
    out float4 position,
	out float4 texcoord,
    out float4 scale,
    out float3 fragment_to_camera_world,
    out float4 position_vs,
    out float4 normal,
    out float4 tangent,
    out float4 binormal,
    out float4x4 world_to_oject
	)
{
	float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4x4 model_matrix = construct_model_matrix(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;

    normal.xyz= vertex.normal;
	tangent.xyz= vertex.tangent;
	binormal.xyz= vertex.binormal;
    
    float3 object_center = mul(float4(0, 0, 0, 1), model_matrix).xyz;   // Object center in world space
    //float3 worldPos = mul(float4(vertex.position.xyz, 1.0), model_matrix).xyz;                   // Vertex position in world space
    //float3 offset = (worldPos - object_center);                            // Distance from center

    normal.w = 1;//offset.x;
    tangent.w = 1;//offset.y;
    binormal.w = 1;//offset.z;

    position_vs = mul(float4(vertex.position, 1.0f), model_matrix);
    position= mul(position_vs, View_Projection);

    scale.xyz = extract_scale_halo(model_matrix); // radius
    scale.w = 1;

    binormal.xyz= object_center;
    tangent.xyz = position_vs.xyz - Camera_Position;

    //wpos.xyz = (position_vs.xyz - Camera_Position);
    //wpos.w = 1;

    texcoord.xy = vertex.texcoord;
    texcoord.z = 1;
    texcoord.w = vertex_id;
  
    world_to_oject = inverse(model_matrix);

	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;
 

}
/*
cbuffer RainParameters : register(b0)
{
    float4x4 WorldViewProjection;
    float4x4 World;             // Object-to-World transformation matrix
    float3   RainDirection;      // World direction vector (e.g., float3(0.2, 0.0, -1.0))
    float    RainSpeed;          // Speed multiplier
    float    Time;               // Elapsed time
    float    FallDistance;       // Max distance a quad falls before looping along RainDirection
    float    StreakLength;       // Length multiplier along X+ / RainDirection
};
struct VS_INPUT
{
    float3 Position : POSITION;  // Local space position of the quad vertex
    float2 TexCoord : TEXCOORD0; // Single UV channel (0..1)
};

struct VS_OUTPUT
{
    float4 Position : SV_POSITION;
    float2 TexCoord : TEXCOORD0;
};
VS_OUTPUT MainVS(VS_INPUT input)
{
    VS_OUTPUT output;

    // 1. Transform local vertex position into World Space
    float3 worldPos = mul(float4(input.Position, 1.0), World).xyz;

    // 2. Derive local quad offset using UVs
    // Maps UV (0..1) to (-0.5 .. +0.5)
    float2 uvCentered = input.TexCoord - float2(0.5, 0.5);

    // 3. Reconstruct the pivot/center position of this specific quad in world space
    // Assumes quad width/height in local space matches standard UV scale
    float3 quadCenter = worldPos - float3(uvCentered.x, uvCentered.y, 0.0);

    // 4. Calculate total distance traveled along the rain vector
    // fmod causes each drop to cycle repeatedly along its path without wrapping around the player
    float3 normalizeDir = normalize(RainDirection);
    float movement = fmod(Time * RainSpeed, FallDistance);
    float3 travelOffset = normalizeDir * movement;

    // 5. Move the drop center along the trajectory vector
    float3 animatedCenter = quadCenter + travelOffset;

    // 6. Stretch/Align along local X+ or RainDirection using UV.x
    // uvCentered.x is negative on the left side (-0.5) and positive on the right (+0.5)
    float3 stretchedOffset = normalizeDir * (uvCentered.x * StreakLength);

    // 7. Reconstruct final world vertex position
    // Retain Y offset (uvCentered.y) for width/thickness perpendicular to direction
    float3 finalWorldPos = animatedCenter + float3(0.0, uvCentered.y, 0.0) + stretchedOffset;

    // 8. Transform to Clip Space
    output.Position = mul(float4(finalWorldPos, 1.0), WorldViewProjection);
    output.TexCoord = input.TexCoord;

    return output;
}
*/
/* params
    rain_time how the fuck i need a time only param
    rain_speed
    fall_distance
    streak_length
*/

// Simple hash to give each object instance a different phase/starting position
float Hash(float3 p)
{
    p = frac(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return frac((p.x + p.y) * p.z);
}
// 0. Simple 1D hash: turns an integer InstanceID into a pseudo-random float between 0.0 and 1.0
float HashInstance(uint id)
{
    id = (id ^ 61u) ^ (id >> 16u);
    id *= 9u;
    id = id ^ (id >> 4u);
    id *= 0x27d4eb2du;
    id = id ^ (id >> 15u);
    return float(id) * (1.0 / 4294967295.0); // Maps uint range to 0.0 .. 1.0
}
// Integer hash for QuadID -> float (0.0 to 1.0)
float HashQuad(uint id)
{
    id = (id ^ 61u) ^ (id >> 16u);
    id *= 9u;
    id = id ^ (id >> 4u);
    id *= 0x27d4eb2du;
    id = id ^ (id >> 15u);
    return float(id) * (1.0 / 4294967295.0); // Normalize uint max to 1.0
}

// Generate distinct RGB color for each quadID
float3 HueToRGB(float hue)
{
    float3 rgb = abs(hue * 6.0 - float3(3.0, 2.0, 4.0)) - 1.0;
    return saturate(float3(rgb.x, 1.0 - rgb.y, 1.0 - rgb.z));
}
// Simple Hash to generate 3 unique RGB values from seed
float3 HashColor(float seed)
{
    float r = frac(sin(seed * 12.9898) * 43758.5453);
    float g = frac(sin(seed * 78.2330) * 43758.5453);
    float b = frac(sin(seed * 45.5432) * 43758.5453);
    return float3(r, g, b);
}
void vertex_shader_rain_vs(
    inout vertex_type vertex,
    in uint vertex_id,
    in uint instance_id,
    out float4 position,
	out float4 texcoord,
    out float4 wpos,
    out float3 fragment_to_camera_world,
    out float4 position_vs,
    out float4 normal,
    out float4 tangent,
    out float4 binormal,
    out float4x4 world_to_oject,
    out float3 quad_color
	)
{
	float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4x4 model_matrix = construct_model_matrix(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;

/////
/*
    int3 fragment_position_int = int3(vertex.texcoord.xy, 0);
    //float4 scene_normal = normal_texture.Load(fragment_position_int);
    //float4 scene_color = albedo_texture.Load(fragment_position_int);

    //float scene_depth = (global_depth_constants.z - (wpos.z/wpos.w )* global_depth_constants.y);
    float sampled_depth = depth_buffer.Load(fragment_position_int);
    float linear_depth = GetLinearDepthBungie(sampled_depth);

    vertex.position.z = vertex.position.z * linear_depth;
    */
//

    //always_local_to_view(vertex, local_to_world_transform, position);
/*
    //float3 object_center = float3(0,0,0);
    float4x4 billboard_matrix = float4x4(
            Camera_Forward.x, Camera_Left.x, Camera_Up.x, 0.0f,
            Camera_Forward.y, Camera_Left.y, Camera_Up.y, 0.0f,
            Camera_Forward.z, Camera_Left.z, Camera_Up.z, 0.0f,
            0.0f, 0.0f, 0.0f, 1.0f);
    //float4x4 look_model_matrix = mul(transpose(billboard_matrix), model_matrix);  // SORTA WORKS FOR ORIENTATION

    //float4x4 axis_matrix = axis_matrix_halo(-Camera_Left, Camera_Up, Camera_Forward, vertex.position);
    //float4x4 look_model_matrix = mul(transpose(axis_matrix), model_matrix);
    float4x4 look_model_matrix =  look_at_matrix_halo(Camera_Forward, Camera_Up, model_matrix);
*/
    //object_center = mul(float4(object_center, 1.0f), look_model_matrix); 


/*
    wpos = mul(float4(vertex.position, 1.0f), model_matrix);

///// test 1 WORKS
/*
// 1. Calculate EXACT Quad ID for 4-vertex indexed quads
    uint quadID = vertex_id / 4; 

    // 2. Derive a 0.0 -> 1.0 random seed for this specific quad
    float randomSeed = HashQuad(quadID);

    // 2.5 Generate a distinct random color per quad
    //quad_color = float4(HashColor(randomSeed), 1.0);
    quad_color = HashColor(randomSeed);

    // 3. Calculate randomized Speed and Phase Offset
    // Phase staggers where the drop starts along the fall vector
    float phaseOffset     = randomSeed * fall_distance;

    // Speed variation (+/- 20% of base rain_speed)
    float speedMultiplier = 0.8 + (randomSeed * 0.4); 
    float instanceSpeed   = rain_speed * speedMultiplier;

    // 4. Compute movement offset along rain direction
    float3 RainDirection = float3(0.0, 0.0, -1.0);
    float3 normalizeDir = normalize(RainDirection);

    float movement = fmod((rain_time * instanceSpeed) + phaseOffset, fall_distance);
    float3 travelOffset = normalizeDir * movement;

    // 5. Apply motion equally to all 4 vertices of the quad
    float3 staticWPos = mul(float4(vertex.position, 1.0f), model_matrix).xyz;
    float3 finalWorldPos = staticWPos + travelOffset;

    // 6. Transform to Clip Space
    position = mul(float4(finalWorldPos, 1.0), View_Projection);
    //texcoord = vertex.texcoord;
*/
///////////// test 2 add streak length and width
/*
// 1. Calculate integer Quad ID (4 verts per quad)
    uint quadID = vertex_id / 4; 

    // 2. Derive unique random seed per quad
    float randomSeed = HashQuad(quadID);
    
    // 2.5 Generate a distinct random color per quad
    //quad_color = float4(HashColor(randomSeed), 1.0);
    quad_color = HashColor(randomSeed);

    // 3. Vary Phase & Speed
    float phaseOffset     = randomSeed * fall_distance;
    float speedMultiplier = 0.8 + (randomSeed * 0.4); 
    float instanceSpeed   = rain_speed * speedMultiplier;

    float3 RainDirection = float3(0.0, 0.0, -1.0);
    float3 normalizeDir  = normalize(RainDirection);

    // 4. Compute main falling movement
    float movement      = fmod((rain_time * instanceSpeed) + phaseOffset, fall_distance);
    float3 travelOffset = normalizeDir * movement;
    
/// test 2321312+1 add streak width

    // 5. Apply Width Scaling & Streak Stretch
    float2 uvCentered = vertex.texcoord - float2(0.5, 0.5);

    // Scale X horizontally (assuming local X/Y is width relative to local frame)
    // Or use perpendicular vector to RainDirection if quads face camera
    //float width_scale = 0.25; // 0.25 = 25% original width (slimmer)
    float3 widthOffset = float3(uvCentered.x * streak_width, 0.0, 0.0);

    // Streak stretch along -Z
    float3 streakStretch = normalizeDir * (uvCentered.y * streak_length);

    // 6. Apply both offsets
    float3 staticWPos = mul(float4(vertex.position, 1.0f), model_matrix).xyz;
    float3 finalWorldPos = staticWPos + travelOffset + streakStretch + widthOffset;
*/
///
/*
    // 5. Apply Streak Stretch along RainDirection (-Z)
    // Map local UV.y or local Z position to stretch the rear/front vertices
    float2 uvCentered    = vertex.texcoord - float2(0.5, 0.5);
    float3 streakStretch = normalizeDir * (uvCentered.y * streak_length);

    // 6. Transform static world position and add displacement
    float3 staticWPos    = mul(float4(vertex.position, 1.0f), model_matrix).xyz;
    float3 finalWorldPos = staticWPos + travelOffset + streakStretch;
*/
    // 7. Output to Clip Space
   // position = mul(float4(finalWorldPos, 1.0), View_Projection);
    
//////////// test 3 fix width 

// 1. Calculate integer Quad ID
    uint quadID = vertex_id / 4; 

    // 2. Derive unique random seed per quad
    float randomSeed = HashQuad(quadID);
    
    quad_color = HashColor(randomSeed);

    // 3. Vary Phase & Speed
    float phaseOffset     = randomSeed * fall_distance;
    float speedMultiplier = 0.8 + (randomSeed * 0.4); 
    float instanceSpeed   = rain_speed * speedMultiplier;

    float3 RainDirection = float3(0.0, 0.0, -1.0);
    float3 normalizeDir  = normalize(RainDirection);

    // 4. Compute main falling movement along -Z
    float movement      = fmod((rain_time * instanceSpeed) + phaseOffset, fall_distance);
    float3 travelOffset = normalizeDir * movement;

    // 5. Apply Local Width Scale BEFORE model_matrix transform
    // (Maps UV.x from -0.5..0.5 to control local thickness)
    float2 uvCentered = vertex.texcoord - float2(0.5, 0.5);

    // Modify local vertex position before transforming to world space!
    float3 scaledLocalPos = vertex.position;

    // Scale local X (or local Y depending on mesh alignment) using streak_width
    // e.g., streak_width = 0.2 gives 20% thickness, 1.0 is default, 2.0 is double
    scaledLocalPos.y *= streak_width; // <-- Adjust .x or .y depending on mesh local width axis

    // 6. Transform scaled local position to World Space
    float3 staticWPos = mul(float4(scaledLocalPos, 1.0f), model_matrix).xyz;

    // 7. Apply Streak Stretch along RainDirection (-Z)
    float3 streakStretch = normalizeDir * (uvCentered.y * streak_length);

    // 8. Final world position
    //float3 finalWorldPos = staticWPos + travelOffset + streakStretch;
    // 8. Final world position
    float3 finalWorldPos = staticWPos + travelOffset + streakStretch;

    // 9. Output to Clip Space
    position = mul(float4(finalWorldPos, 1.0), View_Projection);
 
 /////////// test 4 fix overall scaling now
// 7 22 2026 works but width scale and rotation issues
// use model matrix without rotation or scale
// remove width scale its useless after all this is rain... not making a particle shader or porting the particle shader (right?)
// scale width of rain quads in 3dsmax
// first axis align feature
// keep streak length + fix skewing
  /*  // 1. Calculate integer Quad ID (4 verts per quad)
    uint quadID = vertex_id / 4; 

    // 2. Derive unique random seed per quad
    float randomSeed = HashQuad(quadID);
    quad_color = HashColor(randomSeed);

    // 3. Vary Phase & Speed
    float phaseOffset     = randomSeed * fall_distance;
    float speedMultiplier = 0.8 + (randomSeed * 0.4); 
    float instanceSpeed   = rain_speed * speedMultiplier;

    float3 RainDirection = float3(0.0, 0.0, -1.0);
    float3 normalizeDir  = normalize(RainDirection);

    // 4. Compute main falling movement
    float movement      = fmod((rain_time * instanceSpeed) + phaseOffset, fall_distance);
    float3 travelOffset = normalizeDir * movement;

    // 5. Local Quad Width Scaling (Per-Quad Pivot Isolation)
    float2 uvCentered = vertex.texcoord - float2(0.5, 0.5);

    // Get static world position of vertex
    float3 staticWPos = mul(float4(vertex.position, 1.0f), model_matrix).xyz;

    // Isolate the width displacement for THIS specific corner (-0.5 to +0.5)
    // Scale local horizontal width across X/Y plane without moving the quad's world center
    float3 widthOffset = float3(uvCentered.x * streak_width, 0.0, 0.0);

    // 6. Apply Streak Stretch along RainDirection (-Z)
    float3 streakStretch = normalizeDir * (uvCentered.y * streak_length);

    // 7. Combine: Static position + Per-Quad Width + Stretch + Falling Travel
    // (Note: To prevent double-width, we replace raw X width with scaled widthOffset)
    float3 finalWorldPos = staticWPos + widthOffset - float3(uvCentered.x, 0.0, 0.0) + travelOffset + streakStretch;


    // basis has local-space vertical vector, and a perpendicular vector in screen space
    local_to_world_transform[0].xyz= float3(0.0f, 0.0f, 1.0f);
    local_to_world_transform[1].xyz= normalize(cross(local_to_world_transform[0], position - Camera_Position));	// could be simplified

    // 8. Output to Clip Space
    position = mul(float4(finalWorldPos, 1.0), View_Projection);
*/
    
//// test  4 aga

 
/////////////

    //position= mul(wpos, View_Projection);
    texcoord.xy = vertex.texcoord;
    texcoord.zw = 1;
//

    normal.xyz= mul(float4(vertex.normal, 1.0f), model_matrix).xyz;
	tangent.xyz= mul(float4(vertex.tangent, 1.0f), model_matrix).xyz;
	binormal.xyz= mul(float4(vertex.binormal, 1.0f), model_matrix).xyz;

    normal.w = 1;
    //normal.w = outAlpha;

    tangent.w = 1;
    binormal.w = 1;
    //position= mul(wpos, View_Projection);

    wpos = position;
    world_to_oject = model_matrix;
	fragment_to_camera_world= Camera_Position - vertex.position;
    position_vs = position;
    //CALC_CLIP(position);
}


void vertex_shader(
    in vertex_type vertex,
	in float3       prt_c0_c2               : BLENDWEIGHT1,
	in float3       prt_c3_c5               : BLENDWEIGHT2,
	in float3       prt_c6_c8               : BLENDWEIGHT3,		
    in uint         vertex_id               : SV_VertexID,
    in uint         instance_id             : SV_InstanceID,
    out float4      position                : SV_Position,
    //out float       clip_distance           : SV_ClipDistance,
    CLIP_OUTPUT
	out float4      texcoord                : TEXCOORD0,
    out float4      wpos                    : TEXCOORD1,
    out float3      fragment_to_camera_world: TEXCOORD2,
	out float4x4    world_to_oject          : TEXCOORD3,
    out float4      position_vs             : TEXCOORD7,
    out float4      normal                  : TEXCOORD8,
    out float4      tangent                 : TEXCOORD9,
    out float4      binormal                : TEXCOORD10,
    out float4      prt_ravi_diff           : TEXCOORD11,
    //out float3      view_dir                : TEXCOORD12,
    out float3      extinction              : COLOR0,
	out float3      inscatter               : COLOR1
	)
{
    //view_dir = 0;
    prt_ravi_diff = 0;
    extinction = 0;
    inscatter = 0;

    IF_CATEGORY_OPTION(primitive, sphere_light)
    {
        area_light_sphere_vs(vertex, vertex_id, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, world_to_oject);
    }
    IF_CATEGORY_OPTION(primitive, point_light)
    {
        point_light_vs(vertex, vertex_id, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, world_to_oject);
    }
    IF_CATEGORY_OPTION(primitive, unit_status_basic)
	{
        unit_status_basic_vs(vertex, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, world_to_oject);
	}
    IF_CATEGORY_OPTION(primitive, trajectory_helper)
    {
        trajectory_helper_vs(vertex, vertex_id, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, world_to_oject);
	}
    IF_CATEGORY_OPTION(primitive, test_screen_space_hud)
    {
        test_screen_space_hud_vs(vertex, vertex_id, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, world_to_oject);
	}
    IF_CATEGORY_OPTION(primitive, test_ssao)
    {
        test_ssao_vs(vertex, vertex_id, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, world_to_oject);
	}
    IF_CATEGORY_OPTION(primitive, test_rain)
    {
        vertex_shader_rain_vs(vertex, vertex_id, instance_id, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, world_to_oject, extinction);
	}
    //#if TEST_CATEGORY_OPTION(primitive, biplanar_decal) || TEST_CATEGORY_OPTION(primitive, triplanar_decal)
    /*IF_CATEGORY_OPTION(primitive, biplanar_decal)
	{
        decal_projector_vs(vertex, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, 
        view_dir, prt_c0_c2, prt_c3_c5, prt_c6_c8, prt_ravi_diff, extinction, inscatter, world_to_oject);
	}
    IF_CATEGORY_OPTION(primitive, triplanar_decal)
	{
        decal_projector_vs(vertex, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, 
        view_dir, prt_c0_c2, prt_c3_c5, prt_c6_c8, prt_ravi_diff, extinction, inscatter, world_to_oject);
	}
    IF_CATEGORY_OPTION(primitive, palettized_x_forward)
	{
        decal_projector_vs(vertex, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, 
        view_dir, prt_c0_c2, prt_c3_c5, prt_c6_c8, prt_ravi_diff, extinction, inscatter, world_to_oject);
	}
     IF_CATEGORY_OPTION(primitive, spherical)
	{
        decal_projector_vs(vertex, position, texcoord, wpos, fragment_to_camera_world, position_vs, normal, tangent, binormal, 
        view_dir, prt_c0_c2, prt_c3_c5, prt_c6_c8, prt_ravi_diff, extinction, inscatter, world_to_oject);
	}*/

    CALC_CLIP(position);
}
 

// Credit: https://stackoverflow.com/questions/32227283/getting-world-position-from-depth-buffer-value
float3 world_pos_from_depth(float depth, float2 screen_uv, float4x4 inverse_proj, float4x4 inverse_view) {
	float z = depth ;
	
    //inverse_proj = transpose(View_Projection);
    //inverse_view = transpose(View);
	float4 clipSpacePosition = float4(screen_uv * 2.0 - 1.0, z, 1.0);
	float4 viewSpacePosition = mul(clipSpacePosition, inverse_proj);
	
	viewSpacePosition /= viewSpacePosition.w;
	
	float4 worldSpacePosition = mul(viewSpacePosition, inverse_view);
	
	return worldSpacePosition.xyz;
}

bool depthIsNotSky(float depth)
{
    //#if defined(UNITY_REVERSED_Z)
    //return (depth > 0.0);
    //#else
    return (depth < 1.0);
    //#endif
}

void trajectory_helper_off_ps(
    float4 screen_position,
	float2 texcoord,
    float4 wpos,
    out float4 out_color
    )
{
  out_color = 0;
}

void unit_status_off_ps(
    float4 screen_position,
	float2 texcoord,
    float4 wpos,
    out float4 out_color
    )
{
    out_color = 0;
}
void decal_projector_off_ps(
    float4 screen_position,
	float2 texcoord,
    float4 wpos,
    float4x4 world_to_oject,
    float3 fragment_to_camera_world,
    out float4 out_color
    )
{   
    out_color = 0;
}

void unit_status_basic_ps(
    float4 screen_position,
	float2 texcoord,
    float4 wpos,
    out float4 out_color,
    out float out_depth
    )
{
    //float4 out_color;
    if (rotated_uvs)
    {     
        float2x2 uvRotate = rotationMatrix(rotation_angle);
        float2 texcoord_rotated = texcoord- 0.5;
        texcoord_rotated = mul(texcoord_rotated, uvRotate);
        out_color = sample2D(base_map, transform_texcoord(texcoord_rotated, base_map_xform));
    }
    else
    {
        out_color = sample2D(base_map, transform_texcoord(texcoord, base_map_xform));
    }

    int3 intScreenCoords = int3(screen_position.xy, 0);

    float scene_depth = (global_depth_constants.z - (wpos.z/wpos.w )* global_depth_constants.y);
    if (alpha_location)
    {
        clip(out_color.r-color.a);
    }
    else
    {
        clip(out_color.a-color.a);
    }
    out_depth = screen_position.z + depth_offset;
    out_color.rgb *= color.rgb;
    //return out_color;
    //return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);	
}


void trajectory_helper_ps(
    float4 screen_position,
	float4 texcoord,
    float4 wpos,
    float alpha,
    out float4 out_color
    )
{
    // Soft edges across the ribbon width
    float edge = 1.0 - abs(texcoord.w * 2.0 - 1.0);
    edge = smoothstep(soft_edge_min, soft_edge_max, soft_edge_multiplier * edge);

    // Dash pattern along the arc
    //if (dash_length > 0.0)
    //{
    //    if (frac(texcoord.z / dash_length) > 0.5) 
    //    discard;
    //}

    out_color = trajectory_helper_color;
    out_color.a *= alpha * edge;

}

float2 postProjToScreen(float4 position)
{
    float2 screenPos = position.xy / position.w;
    return 0.5 * (float2(screenPos.x, screenPos.y) + 1);
}

float4 reconstruct_pos(float z, float2 uv_f, float4x4 invProjView)
{
    float4 sPos = float4(uv_f * 2.0 - 1.0, z, 1.0);
    //sPos = invProjView * sPos;
   // sPos = mul(invProjView, sPos );
    sPos = mul(inverse(View_Projection), sPos );
    return float4((sPos.xyz / sPos.w ), sPos.w);
}

// Z buffer to linear 0..1 depth
float Linear01Depth( float z )
{
    //return 1.0 / (_ZBufferParams.x * z + _ZBufferParams.y);
    float4 _ZBufferParams;
    _ZBufferParams.x=  (1 - farPlane/nearPlane);
    _ZBufferParams.y= (farPlane/nearPlane);
    _ZBufferParams.z= (_ZBufferParams.x/farPlane);
    _ZBufferParams.w= (_ZBufferParams.y/farPlane);
    return 1.0 / (_ZBufferParams.x * z + _ZBufferParams.y);
}
/*
// depth to linear 0-1
void Linear01Depth_float(float InDepth, float NearClip, float FarClip, out float OutDepth){
 
    float x, y, z, w;
        x = (float)((FarClip-NearClip)/NearClip);
        y = 1.0f;
        z = (float)(FarClip-NearClip)/(NearClip*FarClip);
        w = (float)(1.0f / FarClip);
  OutDepth = 1.0 / (x * InDepth + y); //
}
*/
/*

bool insideBounds(float3 bounds, float mesh_scale)
{
    return (mesh_scale && Camera_Position >= bounds);
}


float3 getProjectedObjectPos(float2 screenPos, float3 worldRay, float4x4 WorldToObject, float depth){
	//get depth from depth texture
	//float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenPos);
    //float depth = sample2D(depth_texture, screenPos);
    //_ProjectionParams.z = 10240.0f; or 1
	//depth = Linear01Depth (depth) * 102400.0f;
   // depth = ConvertZToLinearDepth(depth)  ;
    worldRay = normalize(worldRay); 

   // float4 forward = float4(1, 0, 0, 0);
   // forward = mul(View , forward );// just for testing

   	//the 3rd row of the view matrix has the camera forward vector encoded, so a dot product with that will give the inverse distance in that direction
	worldRay /= dot(worldRay, (Camera_Forward.xyz));
    

	//reconstruct world and object space positions
	float3 worldPos = Camera_Position_PS + worldRay * depth;
    float3 objectPos =  mul (  float4(worldPos,1), WorldToObject).xyz;
	//float3 objectPos =  mul (WorldToObject, float4(worldPos,1)).xyz;
    clip( projection_clip - abs(objectPos) );
    //get -0.5|0.5 space to 0|1 for nice texture stuff if thats what we want
    // objectPos *= 5;
    objectPos = (objectPos * 5) * (1 / mesh_scale);
    objectPos += 0.5;
    //objectPos = objectPos * 0.5 + 0.5;
	return objectPos.xyz;
}
*/

// fade out ... cover a few of the common blend modes
float4 fade_out(float3 color0, float alpha0, float3 color1, float alpha1)
{
    float4 blended_color;
    //IF_CATEGORY_OPTION(blend_mode, opaque)
	//{
		blended_color.rgb = color1;
        blended_color.a = alpha1;
	//}
    IF_CATEGORY_OPTION(blend_mode, additive)
	{
		blended_color.rgb = BlendMode_LinearDodge(color0, color1);
	}
	 IF_CATEGORY_OPTION(blend_mode, multiply)
	{
		//blended_color.rgb = BlendMode_Multiply(color0, color1);
        blended_color.rgb= lerp(1.0f, color1, alpha1);
	}
	 IF_CATEGORY_OPTION(blend_mode, double_multiply)
	{
		blended_color.rgb = BlendMode_Multiply(color0, color1) * BlendMode_Multiply(color0, color1);
	}
     IF_CATEGORY_OPTION(blend_mode, maximum)
	{
		blended_color.rgb = BlendMode_Lighten(color0, color1);
	}
    IF_CATEGORY_OPTION(blend_mode, multiply_add)
	{
		blended_color.rgb = BlendMode_Multiply(color0, color1) + color1;
	}



	// bump and specular needs an alpha even if diffuse doesn't
	if ( blend_mode_USES_SRC_ALPHA)
	{
		blended_color.a *= alpha0;//fade.x;
	}
	
	IF_CATEGORY_OPTION(blend_mode, pre_multiplied_alpha)
	{
		
        blended_color.a *= alpha1;

        blended_color.a *= alpha0;//fade.x;
	}
    return blended_color;
}






/*float4 calc_output_color_with_explicit_light_quadratic(float3 object_position, float2 texcoord, float3 view_dir, float3 decal_color, 
        float3 decal_normal, float decal_alpha, float3 prt_c0_c2, float3 prt_c3_c5, float3 prt_c6_c8, float3 extinction, float3 inscatter, float4 scene_color)
{

    float3 view_dir_normalized = normalize(view_dir);
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
	
	// compute a blended normal attenuation factor from the length squared of the normal vector
	// blended normal pixels are MSAA pixels that contained normal samples from two different polygons, therefore the lerped vector upon resolve does not have a length of 1.0
    float3 light_intensity = k_ps_dominant_light_intensity;
    float3 light_direction = k_ps_dominant_light_direction;
	float normal_lengthsq= dot(decal_normal.xyz, decal_normal.xyz);
#ifndef pc	
	float blended_normal_attenuate= pow(normal_lengthsq, 8);
	float3 light_intensity*= blended_normal_attenuate;
#endif

	// calculate view reflection direction (in world space of course)
	float view_dot_normal=	dot(view_dir_normalized, decal_normal);
	///  DESC: 18 7 2007   12:50 BUNGIE\yaohhu :
	///    We don't need to normalize view_reflect_dir, as long as bump_normal and view_dir have been normalized
	/// float3 view_reflect_dir= normalize( (view_dot_normal * bump_normal - view_dir) * 2 + view_dir );
	//float3 view_reflect_dir= (view_dot_normal * decal_normal - view_dir_normalized) * 2 + view_dir_normalized;
    float3 view_reflect_dir = reflect(-view_dir_normalized, decal_normal);


    float specular, roughness, occlusion, ID_mask, specular_mask;
    roughness = 0.75-decal_color.r ;
    occlusion = roughness;
    specular =  decal_color.r;
    specular_mask = decal_alpha;
	float4 envmap_specular_reflectance_and_roughness;
	float3 envmap_area_specular_only;
	float4 specular_radiance;
	float3 diffuse_radiance= ravi_order_3(decal_normal, sh_lighting_coefficients);

    //float4 temp_prt_ravi_diff = mul(float4(prt_ravi_diff.rgb,1.0), (world_to_oject));
    //float4 temp_prt_ravi_diff_alpha = mul(float4(prt_ravi_diff.aaa,1.0), (world_to_oject));
    //float4 new_prt_ravi_diff = float4(temp_prt_ravi_diff.rgb, temp_prt_ravi_diff_alpha.g);
	float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4 prt_pixel;
    prt_quadratic(
		prt_c0_c2,
		prt_c3_c5,
		prt_c6_c8,
		decal_normal.xyz,
		local_to_world_transform,
		prt_pixel);
  
 	//prt_pixel.x= 1.0f;														// diffuse occlusion % (prt ravi ratio)
 	//prt_pixel.y= 1.0f;														// unused
 	//prt_pixel.z= 1.0f;														// specular occlusion % (ambient occlusion)
 	//prt_pixel.w= dot(decal_normal, get_constant_analytical_light_dir_vs());				// specular (vertex N) dot L (kills backfacing specular)


	calc_material_cook_torrance_pbr_maps_ps(
		diffuse_coefficient,//diffuse_coefficient, 
        //specular_coefficient, 
        0.5,//area_specular_contribution, 
        0.5,//analytical_specular_contribution, 
        0.5,//environment_map_specular_contribution, 
        float3(0.75, 0.75, 0.75), //fresnel_color, 
        1,//albedo_blend, 
        decal_color,//specular_tint, 
        0.0,//analytical_anti_shadow_control,

        decal_normal,
        view_dir,
        view_dir_normalized,
        view_reflect_dir,
        decal_color,
        specular,//specular,
        roughness,//roughness,
        specular_mask,//specular_mask,
		
		sh_lighting_coefficients,	
		light_direction,				// normalized
		light_intensity,

		prt_pixel,
		envmap_specular_reflectance_and_roughness,
		envmap_area_specular_only,
		specular_radiance,
		diffuse_radiance);

    //compute environment map
	envmap_area_specular_only= max(envmap_area_specular_only, 0.001f);
	float3 envmap_radiance= calc_environment_map_ps(view_dir_normalized, decal_normal, view_reflect_dir, envmap_specular_reflectance_and_roughness, envmap_area_specular_only, roughness);

    envmap_radiance *= occlusion;
    specular_radiance *= occlusion;
    diffuse_radiance *= occlusion;


    float4 out_color;
    float self_illum_radiance = 1;
    /*out_color.xyz= (diffuse_radiance * decal_color + specular_radiance + envmap_radiance);
    //out_color.xyz= (diffuse_radiance * decal_color );
    out_color.xyz= (out_color.xyz * extinction + inscatter) * g_exposure.rrr;
    out_color.w= decal_alpha;
*/
	// set color channels

	/*out_color.xyz= (diffuse_radiance * decal_color + specular_radiance + envmap_radiance);
	//APPLY_OVERLAYS(out_color.xyz, texcoord, view_dot_normal)
	out_color.xyz= (out_color.xyz * extinction + inscatter * 0.5) * g_exposure.rrr;
	out_color.w= saturate(specular_radiance.w +decal_alpha);

    //out_color.xyz=decal_color;
   // out_color.w=decal_alpha;
    //fade_out(scene_color.rgb, decal_alpha, out_color.rgb, out_color.a);
    return out_color;

}*/


float2 SampleSphericalMap(float3 direction)
{
    float2 invAtan = float2(0.1591, 0.3183);
    float2 uv = float2(atan2(direction.y, direction.x), asin(direction.z));
    uv *= invAtan;
    uv += 0.5;
    return uv;
}

float2 RadialCoords(float3 a_coords)
{
    float3 a_coords_n = normalize(a_coords);
    float lon = atan2(a_coords_n.z, a_coords_n.x);
    float lat = acos(a_coords_n.y);
    float2 sphereCoords = float2(lon, lat) * (1.0 / M_PI);
    return float2(sphereCoords.x * 0.5 + 0.5, 1 - sphereCoords.y);
}

// Function to choose the best axes for sampling based on surface normal
float2 ChooseUVAxes(float3 normal) {
    // Calculate the absolute value of the normal components
    float3 absNormal = abs(normal);

    // Determine which axes to use based on the largest normal component
    if (absNormal.x > absNormal.y && absNormal.x > absNormal.z) {
        // X component is dominant, sample using YZ axes
        return float2(normal.y, normal.z);
    } else if (absNormal.y > absNormal.x && absNormal.y > absNormal.z) {
        // Y component is dominant, sample using XZ axes
        return float2(normal.x, normal.z);
    } else {
        // Z component is dominant, sample using XY axes
        return float2(normal.x, normal.y);
    }
}

void Unity_FresnelEffect_float(float3 Normal, float3 ViewDir, float Power, out float Out)
{
    Out = pow((1.0 - saturate(dot(normalize(Normal), normalize(ViewDir)))), Power);
}
 

 /*
    float4 sampled_color;
    if (uv_mask < 0.5) {

        float3 inside_normal = (normal) * (1-uv_mask);
        inside_normal = mul(float4(inside_normal,1.0), (world_to_oject));  
        float3 inside_pos = (object_position) * (1-uv_mask);

        clip(projection_clip - abs(inside_pos)); 
        inside_pos = (inside_pos * 5) * (1 / pos_y);
        inside_pos += 0.5;

        sampled_color = boxmap_2d(base_map,  (inside_pos),  (inside_normal), projection_sharpness);

        out_color.a =  lerp(sampled_color.a, 1-sampled_color.r, color.a);//clamp(1-sampled_color.a * color.a, 0, 0.7) ;
        out_color.rgb = (sampled_color.rgb * u_tiles) * color.rgb;

        
        out_color.rgb = lerp( out_color.rgb , scene_color.rgb * out_color.rgb, out_color.a  );

        out_depth = screen_position.z + pos_z;
        clip(out_color.a - projection_angle_discard_threshold);

    } else {

        float3 outside_normal = (normal) * (uv_mask);
        outside_normal = mul(float4(outside_normal,1.0), (world_to_oject));  
        float3 outside_pos = (object_position) * (uv_mask);

        clip(projection_clip - abs(outside_pos)); 
        outside_pos = (outside_pos * 5) * (1 / pos_y);
        outside_pos += 0.5;

        sampled_color = boxmap_2d(base_map,  (outside_pos),  (outside_normal), projection_sharpness);

        out_color.a =  lerp(sampled_color.a, 1-sampled_color.r, color.a);//clamp(1-sampled_color.a * color.a, 0, 0.7) ;
        out_color.rgb = (sampled_color.rgb * u_tiles) * color.rgb;

        out_color.rgb = lerp( out_color.rgb , scene_color.rgb * out_color.rgb, out_color.a  );

        out_depth = screen_position.z;
        clip(out_color.a - projection_angle_discard_threshold);
    }
*/





    //


  //  out_depth = screen_position.z;
  //  out_color.rgb = normal;
  //  out_color.a = 1;
//
 
    /*
    if (uv_mask <= 0 && front_face == false && camera_distance > 0) 

    {    




        float4 sampled_color = biplanar_2d(base_map,  (object_position),  (depth_normal), projection_sharpness);

        out_color.a =  lerp(sampled_color.a, 1-sampled_color.r, color.a);//clamp(1-sampled_color.a * color.a, 0, 0.7) ;

        out_color.rgb = (sampled_color.rgb * u_tiles) * color.rgb;
        float4 scene_col = albedo_texture.Load(fragment_position_int);

        //out_normal.xyz = depth_normal;
        //out_normal.w = position_vs.z;
        //out_depth = screen_position.z;

        out_color.rgb =  lerp( out_color.rgb , scene_col.rgb * out_color.rgb, out_color.a  );

        clip(out_color.a-projection_angle_discard_threshold);

    } 
*/
/*
    //float3 ndcSample = float3(ndcPos.xy, linear_depth);
    //float4 hViewPos     = mul (float4(ndcSample.xyz, 1.0), inverse(View_Projection));
    //float3 viewPosition = hViewPos.xyz / hViewPos.w;
    //float3 WorldPos       = mul(float4(viewPosition, 1.0),  transpose(View));

    float3 worldRay = normalize(fragment_to_camera_world); 
    worldRay /= dot(worldRay, (Camera_Forward.xyz));
    float3 WorldPos = Camera_Position_PS + worldRay * linear_depth;

    float3 object_position = mul(float4(WorldPos,1.0), (world_to_oject));  
    clip( projection_clip - abs(object_position) );

    object_position = (object_position * 5) * (1 / pos_z);
    object_position += 0.5;

    ///////////////// reconstructed normals from depth
    float2 ndcPosDepth = position_vs.xy / position_vs.w;
    float2 texCoordDepth = ndcPosDepth.xy * 0.5 + 0.5;
    texCoordDepth.y = 1 - texCoordDepth.y;
    float3 depth_normal = normal_from_depth(texCoordDepth.xy, sampled_depth);
    /////////////////

    float4 sampled_color = biplanar_2d(base_map,  (object_position),  (depth_normal), projection_sharpness);

    out_color.a =  lerp(sampled_color.a, 1-sampled_color.r, color.a);//clamp(1-sampled_color.a * color.a, 0, 0.7) ;

    out_color.rgb = (sampled_color.rgb * u_tiles) * color.rgb;
    float4 scene_col = albedo_texture.Load(fragment_position_int);

    //out_normal.xyz = depth_normal;
    //out_normal.w = position_vs.z;
    //out_depth = screen_position.z;

    out_color.rgb =  lerp( out_color.rgb , scene_col.rgb * out_color.rgb, out_color.a  );

    clip(out_color.a-projection_angle_discard_threshold);
*/


/////////////////


/*
        float3 fragment_position_world= Camera_Position_PS - normalize(fragment_to_camera_world);
        // calculate direction to light (4 instructions)
        float3 fragment_to_light= object_position - fragment_position_world;				// vector from fragment to light
        float  light_dist2= dot(fragment_to_light, fragment_to_light);				// distance to the light, squared
        fragment_to_light  *=rsqrt(light_dist2);									// normalized vector pointing to the light
        float3 light_dir = float3(1,0,0);
        float LIGHT_FALLOFF_SCALE, LIGHT_FALLOFF_OFFSET, LIGHT_SMOOTH, LIGHT_SPHERE;
        LIGHT_FALLOFF_SCALE = 0.5;
        LIGHT_FALLOFF_OFFSET = 0.25;
        LIGHT_SMOOTH = 0.05;
        LIGHT_SPHERE = 0.1;
        float3 LIGHT_COLOR = color.rgb;
        float2 falloff;
        falloff.x= 1 / (mesh_scale + light_dist2);									// distance based falloff				(2 instructions)
        falloff.y= dot(fragment_to_light, light_dir);							// angle based falloff (spot-light)		(1 instruction)
        falloff= max(0.0f, falloff * LIGHT_FALLOFF_SCALE + LIGHT_FALLOFF_OFFSET);	// scale, offset, clamp result			(2 instructions)
        falloff.y= pow(falloff.y, LIGHT_SMOOTH) + LIGHT_SPHERE;						// smooth and add ambient				(4 instructions)
        float combined_falloff= saturate(falloff.x) * saturate(falloff.y);								//										(1 instruction)

        float3 light_radiance= LIGHT_COLOR * combined_falloff;		
        out_color.rgb = scene_col.rgb + light_radiance;
        out_color.a = 1;
*/




void area_light_sphere_ps(
    float4 screen_position,
	float4 texcoord,
    float4 normal,
    float3 center_replace_me,
    float4 radius_replace_me,
    float4 attenuation_replace_me, // wpos aka world_ray_vs
    float4 position_vs,
    float3 fragment_to_camera_world,
    float4x4 world_to_oject,
    out float4 out_color,
    out float out_depth
    )
{
    int3 fragment_position_int = int3(screen_position.xy, 0);
    float4 scene_normal = normal_texture.Load(fragment_position_int);
    float4 scene_color = albedo_texture.Load(fragment_position_int);

    //float scene_depth = (global_depth_constants.z - (wpos.z/wpos.w )* global_depth_constants.y);
    float sampled_depth = depth_buffer.Load(fragment_position_int);
    float linear_depth = GetLinearDepthBungie(sampled_depth);

    //float uv_mask = sample2Dlod(uv_map, texcoord.xy, 0);
    float3 light_position ;
    //light_position = (position_vs.xyz/position_vs.w) ;//* (1-uv_mask);
    light_position =  (position_vs.xyz) ;/// 2;
    //light_position = float3(0.5, 0.5, 0.5);
    float edge_fade;
    float3 object_center = float3(0.5, 0.5, 0.5);
    
///////////////// reconstruct decal position /////////////////
    float3 worldRay = normalize(attenuation_replace_me.xyz); 
    worldRay /= dot(worldRay, (Camera_Forward.xyz));
    float3 WorldPos = Camera_Position_PS + worldRay * linear_depth;
    float3 object_position = mul(float4(WorldPos,1.0), (world_to_oject));  

    clip(projection_clip - abs(object_position)); 
    object_position += 0.5;
///////////////// end reconstruct decal position /////////////////

    //if (uv_mask == 1)

    //if (texcoord.w > 4)
    //{
        /*
        float3 sphereRadius =  (radius.xyz);
        float alpha = 0.6;//1-scene_color.a;
        //alpha *= alpha;
        float3 view_dir = normalize(fragment_to_camera_world);
        scene_normal.rgb = scene_normal.rgb * 2 - 1;
        float3 r = reflect(-view_dir, scene_normal.rgb);
        
  
        float3 L = light_position - position_vs.xyz;
        float3 centerToRay = (dot(L, r) * r) - L;
        float3 closestPoint = L + centerToRay * saturate(sphereRadius / length(centerToRay));
            L = normalize(closestPoint);
        float distLight = length(closestPoint);
        
        float alphaPrime = saturate(sphereRadius/(distLight*2.0)+alpha);
        alphaPrime *= alpha;
        float lightRadius = length(attenuation.xyz);
        float falloff = pow(saturate(1.0 - pow(distLight/(lightRadius), 4)), 2) / ((distLight * distLight) + 1.0);	

        float3 lightColor = color.rgb;
        float3 light = (specular_factor + diffuse_factor) * falloff * lightColor * luminosity;		

        out_color.rgb = scene_color.rgb * light;// sample2D(base_map, transform_texcoord(texcoord, base_map_xform)) * light;
        //out_color.rgb *= float3(0.75, 0.0, 0.0);
        out_depth = screen_position.z + 0.1;
        */


        //discard;
        /*
        float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world;
        float distance    = length(light_position - fragment_position_world);
        float attenuation = 1.0 / (diffuse_factor + specular_factor * distance + luminosity * (distance * distance));   

        out_color.rgb = (color * attenuation) * scene_color.rgb;
        out_depth = screen_position.z + 0.1;
        */
        //out_color.rgb = linear_depth;

    //}
    //else
    //{
        //out_color.rgb = linear_depth;//color.rgb;
       // out_depth = screen_position.z;

        float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world;

        float3 lightDir = normalize(object_position - WorldPos);
        float NdotL = max(dot(scene_normal.rgb * 2.0f - 1.0f, lightDir), 0.0);
        float attenuation = saturate(  length(object_position - WorldPos) / decal_scale_z);

        //float distance    = length(object_position - position_vs);
        //float attenuation = 1.0 / (diffuse_factor + specular_factor * distance + luminosity * (distance * distance));   

        out_color.rgb = (decal_scale_y * color) * scene_color.rgb * NdotL * attenuation;
        out_depth = screen_position.z;

    //}
    Unity_SphereMask_float4(object_position, object_center, edge_fade_range, edge_fade_falloff, edge_fade);
    float alpha_map = sample2D(base_map, transform_texcoord(texcoord, base_map_xform)) ;
    float edge_fade_alpha = (edge_fade - pow(1-alpha_map, edge_fade_alpha_power));

    out_color.a = ( edge_fade_alpha);// * color.a;
    //clip(color.a - abs(edge_fade_alpha)); 


}

void active_camo_ps(

	SCREEN_POSITION_INPUT(screen_position),
        CLIP_INPUT
    in float2 texcoord : TEXCOORD0,
    in float4 wpos : TEXCOORD1,
    out float4 COLOR : SV_Target0

    )
{
    int3 fragment_position_int = int3(screen_position.xy, 0);
    float4 scene_col = albedo_texture.Load(fragment_position_int);
    float4 scene_normal = normal_texture.Load(fragment_position_int);

    float sampled_depth = depth_buffer.Load(fragment_position_int);
    //float sampled_depth = depth_buffer.Sample(depth_sampler_a.s, texcoord.xy );
    float linear_depth = ConvertZToLinearDepth(sampled_depth);
    
    float2 texc= texcoord;
    texc.x = 1 - texc.x;
    float2 texcws = float2(wpos.x, 1-wpos.y);
    texcws.x = texcws.x * 0.5 + 0.5;
    texcws.y = 1- (texcws.y - 0.5);

    float4 ldr_color= sample2D(scene_ldr_texture, texcws);

    float4 out_color = scene_normal;//scene_col * color;

    //out_color.rgb = 1-color;
    //out_color.a = k_ps_active_camo_factor.x;// color.a * 0.5;
    //return convert_to_render_target(out_color, false, false);
    COLOR.rgb = out_color;
    COLOR.a =  1 ;//k_ps_active_camo_factor.x;//
   // clip(scene_col.a - color.a);
}

float4 RGB_to_RGBE(in float3 rgb)
{
	float4 rgbe;
	float maximum= max(max(rgb.r, rgb.g), rgb.b);
#ifdef pc
	maximum= max(maximum, 0.000000001f);			// ###ctchou $TODO this in a hack to get nVidia cards to work (for some reason they often return negative zero) - remove this in Xenon builds through a #define
#endif
	float exponent;
	float mantissa= frexp(maximum, exponent);		// note this is an expensive function
	rgbe.rgb= rgb.rgb * (mantissa / maximum);
	rgbe.a= (exponent + 128) / 255.0f;
	return rgbe;
}

float3 RGBE_to_RGB(in float4 rgbe)
{
	return rgbe.rgb * ldexp(1.0, rgbe.a * 255.0f - 128);
}
#include "hud_camera_nightvision_registers.fx"
float3 calculate_world_position(float2 texcoord, float depth)
{
	float4 clip_space_position= float4(texcoord.xy, depth, 1.0f);
	//float4 world_space_position= mul(clip_space_position, transpose(screen_to_world)); //screen_to_world bound in hud_camera_nightvision but in standard objects
    float4 world_space_position= mul(clip_space_position, inverse(View_Projection)); // seems to work. but not the right output?
	return world_space_position.xyz / world_space_position.w;
}
/*
float3 viewspace_to_worldspace(float3 pos_viewspace)
{
	//float4 pos_worldspace = mul(float4(pos_viewspace, 1.0f), k_water_view_xform_inverse);
    float4 pos_worldspace = mul(float4(pos_viewspace, 1.0f), inverse(View));
	pos_worldspace.xyz = pos_worldspace.xyz/pos_worldspace.w;
	
	return pos_worldspace.xyz;
}
*/

float3 reconstruct_world_position(float2 uv, float depth)
{
    // inv_proj reconstructs view space from NDC
    float4 ndc  = float4(uv * 2.0 - 1.0, depth, 1.0);
   // float4x4 inv_proj = mul(inverse(View), View_Projection);
 
   //float4 view_pos = mul(ndc, inv_proj);
    float4 view_pos = mul(ndc, inverse(View_Projection));

    return view_pos.xyz / view_pos.w;
}


void calculate_light_test(
		uniform int light_index,
		in float3 fragment_position_world,
        out float3 light_position,
        out float3 light_color)
		//out float3 light_radiance,
		//out float3 fragment_to_light)			// return normalized direction to the light
{

#define		LIGHT_DATA(offset, registers)	(SIMPLE_LIGHT_DATA[light_index][(offset)].registers)

//#define		LIGHT_DATA(offset, registers)	(SIMPLE_LIGHT_DATA[(light_index * 5) + (offset)].registers)


#define		LIGHT_POSITION			LIGHT_DATA(0, xyz)
#define		LIGHT_DIRECTION			LIGHT_DATA(1, xyz)
#define		LIGHT_COLOR				LIGHT_DATA(2, xyz)
#define		LIGHT_SIZE				LIGHT_DATA(0, w)
#define		LIGHT_SPHERE			LIGHT_DATA(1, w)
#define		LIGHT_SMOOTH			LIGHT_DATA(2, w)
#define		LIGHT_FALLOFF_SCALE		LIGHT_DATA(3, xy)
#define		LIGHT_FALLOFF_OFFSET	LIGHT_DATA(3, zw)
#define		LIGHT_BOUNDING_RADIUS	LIGHT_DATA(4, x)

    	for (int light_index= 0; light_index < SIMPLE_LIGHT_COUNT; light_index++)
	{
    light_position = LIGHT_POSITION;
    light_color = LIGHT_COLOR;
    }
	/*
	// calculate direction to light (4 instructions)
	fragment_to_light= LIGHT_POSITION - fragment_position_world;				// vector from fragment to light

    float  light_dist2= dot(fragment_to_light, fragment_to_light);				// distance to the light, squared
	fragment_to_light  *=rsqrt(light_dist2);									// normalized vector pointing to the light
		
	float2 falloff;
	falloff.x= 1 / (LIGHT_SIZE + light_dist2);									// distance based falloff				(2 instructions)
	falloff.y= dot(fragment_to_light, LIGHT_DIRECTION);							// angle based falloff (spot-light)		(1 instruction)
	falloff= max(0.0f, falloff * LIGHT_FALLOFF_SCALE + LIGHT_FALLOFF_OFFSET);	// scale, offset, clamp result			(2 instructions)
	falloff.y= pow(falloff.y, LIGHT_SMOOTH) + LIGHT_SPHERE;						// smooth and add ambient				(4 instructions)
	float combined_falloff= saturate(falloff.x) * saturate(falloff.y);								//										(1 instruction)

	light_radiance= LIGHT_COLOR * combined_falloff;								//										(1 instruction)
    */
}


void calculate_light_test_2(
		uniform int light_index,
		in float3 fragment_position_world,
        //out float3 light_position,
        //out float3 light_color)
		out float3 light_radiance,
		out float3 fragment_to_light,			// return normalized direction to the light
        out float3 light_position,
        out float3 light_color
        )
{

#define		LIGHT_DATA(offset, registers)	(SIMPLE_LIGHT_DATA[light_index][(offset)].registers)

//#define		LIGHT_DATA(offset, registers)	(SIMPLE_LIGHT_DATA[(light_index * 5) + (offset)].registers)


#define		LIGHT_POSITION			LIGHT_DATA(0, xyz)
#define		LIGHT_DIRECTION			LIGHT_DATA(1, xyz)
#define		LIGHT_COLOR				LIGHT_DATA(2, xyz)
#define		LIGHT_SIZE				LIGHT_DATA(0, w)
#define		LIGHT_SPHERE			LIGHT_DATA(1, w)
#define		LIGHT_SMOOTH			LIGHT_DATA(2, w)
#define		LIGHT_FALLOFF_SCALE		LIGHT_DATA(3, xy)
#define		LIGHT_FALLOFF_OFFSET	LIGHT_DATA(3, zw)
#define		LIGHT_BOUNDING_RADIUS	LIGHT_DATA(4, x)


	// calculate direction to light (4 instructions)
    for (int light_index= 0; light_index < SIMPLE_LIGHT_COUNT; light_index++)
	{
        fragment_to_light= LIGHT_POSITION - fragment_position_world;				// vector from fragment to light

        float  light_dist2= dot(fragment_to_light, fragment_to_light);				// distance to the light, squared
        fragment_to_light  *=rsqrt(light_dist2);									// normalized vector pointing to the light
            
        float2 falloff;
        falloff.x= 1 / (LIGHT_SIZE + light_dist2);									// distance based falloff				(2 instructions)
        falloff.y= dot(fragment_to_light, LIGHT_DIRECTION);							// angle based falloff (spot-light)		(1 instruction)
        falloff= max(0.0f, falloff * LIGHT_FALLOFF_SCALE + LIGHT_FALLOFF_OFFSET);	// scale, offset, clamp result			(2 instructions)
        falloff.y= pow(falloff.y, LIGHT_SMOOTH) + LIGHT_SPHERE;						// smooth and add ambient				(4 instructions)
        float combined_falloff= saturate(falloff.x) * saturate(falloff.y);								//										(1 instruction)

        light_radiance= LIGHT_COLOR * combined_falloff;								//										(1 instruction)
        
        light_position = LIGHT_POSITION;
        light_color = LIGHT_COLOR;
		if( light_dist2 >= LIGHT_BOUNDING_RADIUS )
		{
                    light_color = 0;

		}
    }
  
}


void test_screen_space_hud_ps(
    float4 screen_position,
	float4 texcoord,
    float4 wpos,
    float4 position_vs,
    out float4 out_color,
    out float4 out_color1
    )
{
    int3 fragment_position_int = int3(screen_position.xy, 0);
    float4 scene_col = albedo_texture.Load(fragment_position_int);
    float4 scene_normal = normal_texture.Load(fragment_position_int);
    float sampled_depth = depth_buffer.Load(fragment_position_int);
    float linear_depth = 1-ConvertZToLinearDepth(sampled_depth);
    float4 ldr_color = sample2D(scene_ldr_texture, texcoord.xy);
   // float4 hdr_color = sample2D(scene_hdr_texture, texcoord);
    //out_color = scene_col*color;

    float4 base_color = sample2D(base_map, transform_texcoord(texcoord, base_map_xform));

    //out_color.rgb = lerp(scene_col.rgb, scene_col.rgb+color.rgb, scene_normal.z);
    //out_color.a = (scene_normal.z);
    float3 pos_ws =  reconstruct_world_position(texcoord, sampled_depth);
   // float3 pos_ws = viewspace_to_worldspace(pos_vs);

    float3 light_pos_1, light_pos_2, light_color_1, light_color_2, light_radiance, fragment_to_light;
 
    //calculate_light_test(0, pos_ws, light_pos_1, light_color_1);
    //calculate_light_test(1, pos_ws, light_pos_2, light_color_2);
    

    //out_color.rgb = lerp(light_color_1, light_color_2, screen_position.xyz/screen_position.w);

   calculate_light_test_2(1, pos_ws, light_radiance, fragment_to_light, light_pos_1, light_color_1);

    light_radiance *=  sample2D(dynamic_light_gel_texture, screen_position.xy);//transform_texcoord(fragment_position_shadow.xy, p_dynamic_light_gel_xform));



/*
	float3 simple_light_diffuse_light;
	float3 simple_light_specular_light;
	//float3 fragment_position_world= Camera_Position_PS - fragment_to_camera_world;
	calc_simple_lights_analytical(
		//fragment_position_world,
        pos_ws,
		scene_normal.xyz,
		float3(1.0f, 0.0f, 0.0f),										// view reflection direction (not needed cuz we're doing diffuse only)
		1.0f,
		simple_light_diffuse_light,
		simple_light_specular_light);

        */






    out_color.rgb = color.rgb * light_color_1;//* linear_depth;
    out_color.a = color.a ;//* base_color.a;
    out_color1.rgb = float3(1.0, 0.0, 0.0);
    //out_color1 = color1.a * linear_depth;
    out_color1.a = color1.a;
    //out_color1 = RGB_to_RGBE(out_color1);
    //clip(out_color.a-color.a);

/*
	out_color= display_debug_modes(
		screen_position.xy,//lightmap_texcoord,
		wpos.xyz,//normal,
		texcoord.xy,//texcoord,
		wpos.xyz,//tangent,
		wpos.xyz,//binormal,
		wpos.xyz,//bump_normal,
		position_vs.xyz,//ambient_only,
		position_vs.xyz,//linear_only,
		position_vs.xyz);//quadratic);
*/

}


float3 normal_from_depth(
    float4 screen_position,
	float4 texcoord,
    float depth
    )
{
  
    const float2 offset1 = float2(0.0,0.001);
    const float2 offset2 = float2(0.001,0.0);
  //  int3 offset_int1 = int3(shader.uv.xy + offset1, 0);
  //  int3 offset_int2 = int3(shader.uv.xy + offset2, 0);
  //  float depth1 = tex2D(DepthTextureSampler, texcoord + offset1).r;
  //  float depth2 = tex2D(DepthTextureSampler, texcoord + offset2).r;
    float depth1 =  depth_buffer.Sample(depth_sampler_a.s, texcoord.xy + offset1);
    float depth2 =  depth_buffer.Sample(depth_sampler_a.s, texcoord.xy + offset2);
  // depth1 = ConvertZToLinearDepth(depth1);
  //  depth2 = ConvertZToLinearDepth(depth2);
    //float depth1 = 1 - sample2D(depth_map, shader.uv + offset1).r;
    //float depth2 = 1 - sample2D(depth_map, shader.uv + offset2).r;

    float3 p1 = float3(offset1, depth1 - depth);
    float3 p2 = float3(offset2, depth2 - depth);

    float3 normal = cross(p1, p2);
    normal.z = -normal.z;

    return normalize(normal);
}


// https://theorangeduck.com/page/pure-depth-ssao
void test_ssao_ps(
    float4 screen_position,
	float4 texcoord,
    float4 wpos,
    float4 position_vs,
    float3 fragment_to_camera_world,
    float4x4 world_to_oject,
    out float4 out_color
    )
{ 
    int3 fragment_position_int = int3(screen_position.xy, 0);

    //float depth_new_2 = lerp(0.00078125, 1, depth_new_linear);
    //float2 screen_texc;
    //screen_texc.x = texcoord.x;
    //screen_texc.y = texcoord.y;
    float depth_new_3 = depth_buffer.Sample(depth_sampler_a.s, calc_global_uv(screen_position));
    float depth_new_3_linear = GetLinearDepthBungieAlt(depth_new_3);

    ///////////////// depth checkerboard /////////////////
    // https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@11.0/manual/writing-shaders-urp-reconstruct-world-position.html

        ///////////////// reconstruct position /////////////////
        // from adumbass decal to reconstruct object position, except im stopping at world position reconstruction for unity checkerboard example
        float depth_new = depth_buffer.Load(fragment_position_int).r;
        float depth_new_linear = GetLinearDepthBungie(depth_new);
        // GetLinearDepthBungie from adumbass_functions
        /*
            // unity _ZBufferParams = x is (1-far/near), y is (far/near), z is (x/far) and w is (y/far).
            //global_depth_constants = 1/near,  -(far-near)/(far*near), focus distance, aperture
            float GetLinearDepthBungie(float depth)
            {
                depth = 1 - depth;
                depth =  (global_depth_constants.x + depth * global_depth_constants.y);	// convert to real depth
                //return saturate(depth);
                return  (1 / depth);
            }
        */

        float3 world_ray = normalize(fragment_to_camera_world); 
        world_ray /= dot(world_ray, (Camera_Forward.xyz));
        float3 world_position = Camera_Position_PS + world_ray * depth_new_linear;
        float3 object_position = mul(float4(world_position,1.0), (world_to_oject));  
        ///////////////// end reconstruct position /////////////////

    //uint scale = 10;
    // Scale, mirror and snap the coordinates.
    uint3 worldIntPos = uint3(abs(world_position.xyz * checker_density));
    // Divide the surface into squares. Calculate the color ID value.
    bool white = ((worldIntPos.x) & 1) ^ (worldIntPos.y & 1) ^ (worldIntPos.z & 1);
    // Color the square based on the ID value (black or white).
    float4 checker_color = white ? float4(1,1,1,1) : float4(0,0,0,1);
    if(depth_new < 0.0001)
    checker_color = float4(0,0,0,1);
    ///////////////// end depth checkerboard /////////////////
    /*
    float2 c = texcoord.xy * checker_density;
    c = floor(c) / 2;
    float checker = frac(c.x + c.y) * 2;
    */
  // random = normalize( sample2D(noise_map, transform_texcoord(object_position.xy, noise_map_xform)).rgb );
 
    ///////////////// test ssao /////////////////
    const int samples = 16;
    float3 sample_sphere[samples] = {
        float3( 0.5381, 0.1856,-0.4319), float3( 0.1379, 0.2486, 0.4430),
        float3( 0.3371, 0.5679,-0.0057), float3(-0.6999,-0.0451,-0.0019),
        float3( 0.0689,-0.1598,-0.8547), float3( 0.0560, 0.0069,-0.1843),
        float3(-0.0146, 0.1402, 0.0762), float3( 0.0100,-0.1924,-0.0344),
        float3(-0.3577,-0.5301,-0.4358), float3(-0.3169, 0.1063, 0.0158),
        float3( 0.0103,-0.5869, 0.0046), float3(-0.0897,-0.4940, 0.3287),
        float3( 0.7119,-0.0154,-0.0918), float3(-0.0533, 0.0596,-0.5411),
        float3( 0.0352,-0.0631, 0.5460), float3(-0.4776, 0.2847,-0.0271)
    };
    
    float3 random = normalize( sample2D(noise_map, transform_texcoord(object_position.xy, noise_map_xform)).rgb );

    //float depth = tex2D(DepthTextureSampler, texcoord).r;
   // float depth = 1 - sample2D(depth_map, shader.uv).r;
   // float depth = 1 - depth_buffer.Load(fragment_position_int);
    // float depth = depth_buffer.Sample(depth_sampler_a.s, shader.uv.xy );
    //float depth = depth_buffer.Load(fragment_position_int).r;
 
   // depth = GetLinearDepthBungieAlt(depth);
    // depth = ConvertZToLinearDepth(depth);
    
    //float3 position = float3(texcoord.xy, depth_new_linear);
   // float3 normal = normal_from_depth(depth, shader.uv);
    //float3 normal = normal_from_depth(screen_position, texcoord, depth);

    float4 normal = normal_texture.Load(fragment_position_int) * 2.0f - 1.0f;
   // float3 normal = normal_texture.Load(int3(shader.screen_pos.xy, 0));
   //float3 normal = normal_texture.Sample(depth_sampler_a.s, shader.uv.xy);
    //normal = normalize(normal);
    /*
    int3 fragment_position_int = int3(shader.screen_pos.xy, 0);
    float3 normal =  normal_texture.Load(fragment_position_int);
    normal.z = -normal.z;
    normal = normalize(normal);
*/

    float radius_depth = radius / depth_new;
    float occlusion = 0.0;
    for(int ix=0; ix < samples; ix++) {
    
        float3 ray = radius_depth * reflect(sample_sphere[ix], random);
        float3 hemi_ray = world_position + sign(dot(ray,normal)) * ray;
        
        //float occ_depth = tex2D(DepthTextureSampler, saturate(hemi_ray.xy)).r;
        //float occ_depth = 1 - sample2D(depth_map, saturate(hemi_ray.xy)).r;
        int3 occ_depth_int = int3(saturate(hemi_ray.xy), 0);
       // float occ_depth = 1 - depth_buffer.Load(occ_depth_int);
       // float occ_depth = depth_buffer.Load(occ_depth_int).r;
       float occ_depth = depth_buffer.Sample(depth_sampler_b.s, calc_global_uv(saturate(hemi_ray.xy)));
          // occ_depth = GetLinearDepthBungieAlt(occ_depth);
       // occ_depth = ConvertZToLinearDepth(occ_depth);
        float difference = depth_new - occ_depth;
        
        occlusion += step(ssao_falloff, difference) * (1.0-smoothstep(ssao_falloff, area, difference));
    }
    float ao = 1.0 - total_strength * occlusion * (1.0 / samples);
    //float ao = total_strength * occlusion * (1.0 / samples);
    //Output.RGBColor = saturate(ao + base);
    //float Output = saturate(ao + base);

    out_color =  saturate(ao + base);
    ///////////////// end test ssao /////////////////

  //  float3 test_texcoords = normal_texture.Sample(depth_sampler_a.s, texcoord);
    //float4 ldr_color= sample2D(scene_ldr_texture, texcoord.xy);
  float4 ldr_color = albedo_texture.Load(fragment_position_int);
    out_color.rgb = depth_new_3_linear * color.rgb;

    //depth_buffer.SampleLevel(depth_sampler_b.s, saturate(texcoord.xy), 0);
    //out_color.rgb= normal;
    out_color.a = color.a;
  //  color = saturate(ao + base);
  //  ao = ssao_blur(VERT, ao);
 //   ao = depth;
}


void calc_simple_lights_analytical_test(
        in s_primitive_data v2f,
		//in float3 fragment_position_world,
		in float3 surface_normal,
		in float3 view_reflect_dir_world,							// view direction = fragment to camera,   reflected around fragment normal
		in float specular_power,
		out float3 diffusely_reflected_light,						// diffusely reflected light (not including diffuse surface color)
		out float3 specularly_reflected_light,						// specularly reflected light (not including specular surface color)
        out float3 fragment_to_light,
		out float3 light_radiance
        )


{
	diffusely_reflected_light= float3(0.0f, 0.0f, 0.0f);
	specularly_reflected_light= float3(0.0f, 0.0f, 0.0f);
	
	// add in simple lights
//#ifndef pc	
	//[loop]
//#endif
	//for (int light_index= 0; light_index < SIMPLE_LIGHT_COUNT; light_index++)
	//{
		// Compute distance squared to light, to see if we can skip this light.
		// Note: This is also computed in calculate_simple_light below, but the shader
		// compiler will remove the second computation and share the results of this
		// computation.
		float3 fragment_to_light_test= v2f.object_center - v2f.world_position;				// vector from fragment to light
		float  light_dist2_test= dot(fragment_to_light_test, fragment_to_light_test);				// distance to the light, squared
  
		//if( light_dist2_test >= LIGHT_BOUNDING_RADIUS )
		//{
			// debug: use a strong green tint to highlight area outside of the light's radius
			//diffusely_reflected_light += float3( 0, 1, 0 );
			//specularly_reflected_light += float3( 0, 1, 0 );
		//	continue;
		//}
		
		//float3 fragment_to_light;
		//float3 light_radiance;
		//calculate_simple_light(
		//	light_index, fragment_position_world, light_radiance, fragment_to_light);
///////
	// calculate direction to light (4 instructions)
	fragment_to_light= v2f.object_center  - v2f.world_position;				// vector from fragment to light
	float  light_dist2= dot(fragment_to_light, fragment_to_light);				// distance to the light, squared
	fragment_to_light  *=rsqrt(light_dist2);									// normalized vector pointing to the light
		
	float2 falloff;
	falloff.x= 1 / (v2f.scale + light_dist2);									// distance based falloff				(2 instructions)
	falloff.y= dot(fragment_to_light, 0.5);							// angle based falloff (spot-light)		(1 instruction)
	falloff= max(0.0f, falloff * 0.5 + 0.5);	// scale, offset, clamp result			(2 instructions)
	falloff.y= pow(falloff.y, 0.1) + 0.1;						// smooth and add ambient				(4 instructions)
	float combined_falloff= saturate(falloff.x) * saturate(falloff.y);								//										(1 instruction)

	light_radiance= color * combined_falloff;								//										(1 instruction)

//////

		
		// calculate diffuse cosine lobe (diffuse surface N dot L)
		float cosine_lobe= dot(surface_normal, fragment_to_light);
		
		diffusely_reflected_light  += light_radiance * max(0.05f, cosine_lobe);			// add light with cosine lobe (add ambient 5% light)
//		diffusely_reflected_light  += light_radiance * saturate(cosine_lobe);			// add light with cosine lobe (clamped positive)
		
		// step(0.0f, cosine_lobe)
		specularly_reflected_light += light_radiance * safe_pow(max(0.0f, dot(fragment_to_light, view_reflect_dir_world)), specular_power);
//		specularly_reflected_light += light_radiance * pow(saturate(dot(fragment_to_light, view_reflect_dir_world)), specular_power);
// #ifdef pc
// 		if (light_index >= 7)		// god damn PC compiler likes to unroll these loops - only support 8 lights or so (:P)
// 		{
// 			light_index= 100;
// 		}
// #endif // pc
	//}
	specularly_reflected_light *= specular_power;
}


void point_light_ps(
    inout s_primitive_data v2f, 
    out float4 out_color_0, 
    out float4 out_color_1)
{
    
    int3 fragment_position_int = int3(v2f.screen_position.xy, 0);
    float4 scene_col = albedo_texture.Load(fragment_position_int);
    float4 scene_normal = normal_texture.Load(fragment_position_int);
    v2f.sampled_depth = depth_buffer.Load(fragment_position_int);
    //v2f.linear_depth = 1-ConvertZToLinearDepth(v2f.sampled_depth);
    v2f.linear_depth = GetLinearDepthBungie(v2f.sampled_depth);
    float4 ldr_color = sample2D(scene_ldr_texture, v2f.texcoord.xy);


	float3 simple_light_diffuse_light;
	float3 simple_light_specular_light;
    float3 fragment_to_light;
    float3 light_radiance;

/*
    ///////////////// reconstruct decal position /////////////////
    float3 world_ray = normalize(v2f.world_ray_vs); 
    world_ray /= dot(world_ray, (Camera_Forward.xyz));
    v2f.world_position = Camera_Position_PS + world_ray * v2f.linear_depth;
    v2f.object_position = mul(float4(v2f.world_position,1.0), (v2f.world_to_oject));  
    ///////////////// end reconstruct decal position /////////////////
    clip(sphere_radius_x - abs(v2f.object_position)); 
    


	//float3 fragment_position_world= Camera_Position_PS - v2f.fragment_to_camera_world;
    //float3 fragment_position_world = reconstruct_world_position(v2f.texcoord, v2f.sampled_depth);

	calc_simple_lights_analytical_test(
        v2f,
		//world_position,
		scene_normal.xyz,
		v2f.view_dir,   //float3(1.0f, 0.0f, 0.0f),										// view reflection direction (not needed cuz we're doing diffuse only)
		1.0f,
		simple_light_diffuse_light,
		simple_light_specular_light,
        fragment_to_light,
        light_radiance);

*/
    out_color_0.rgb = change_color_0;
    out_color_0.a = color.a;
    
    out_color_1 = color;
}
void vertex_shader_rain_ps(
    inout s_primitive_data v2f, 
    out float4 out_color_0, 
    out float4 out_color_1)
{
    out_color_0.rgb = v2f.vs_rain_color;
    out_color_0.a = 1;
    
    out_color_1 = 0;
}

void fragment_shader(
	SCREEN_POSITION_INPUT(screen_position),
    CLIP_INPUT
    //in float        clip_distance           : SV_ClipDistance,
	in float4       texcoord                : TEXCOORD0,
    in float4       wpos                    : TEXCOORD1,
    in float3       fragment_to_camera_world: TEXCOORD2,
	in float4x4     world_to_oject          : TEXCOORD3,
    in float4       position_vs             : TEXCOORD7,
    in float4       normal                  : TEXCOORD8,
    in float4       tangent                 : TEXCOORD9,
    in float4       binormal                : TEXCOORD10,
    in float4       prt_ravi_diff           : TEXCOORD11,
    //in float3       view_dir                : TEXCOORD12,
    in float3       extinction              : COLOR0,
	in float3       inscatter               : COLOR1,
    in bool         front_face              : SV_IsFrontFace,
    //out float       DEPTH                   : SV_Depth ,
    // out float DEPTH         : SV_DepthGreaterEqual
    // out float DEPTH         : SV_DepthLessEqual,
    out float4      COLOR                   : SV_Target0
    //out float4      COLOR1              : SV_Target1
    // out uint      stencil_val               : SV_StencilRef
    //out float4      NORMAL              : SV_Target1

	//in float3 normal    : TEXCOORD1,
	//in float3 binormal  : TEXCOORD2,
	//in float3 tangent   : TEXCOORD3
	//in float3 fragment_to_camera_world : TEXCOORD4
    ) //: SV_Target0
{
    s_primitive_data v2f = (s_primitive_data)0;
    v2f.vs_rain_color = extinction;

    v2f.screen_position = screen_position;
    v2f.texcoord = texcoord;

    v2f.normal.w = normal.w;
    v2f.binormal.w = binormal.w;
    v2f.tangent.w = tangent.w;
    v2f.fragment_to_camera_world = fragment_to_camera_world;

    v2f.normal.xyz = normalize(normal.xyz);
    v2f.binormal.xyz = normalize(binormal.xyz);
    v2f.tangent.xyz = normalize(tangent.xyz);

    v2f.object_center = binormal.xyz;
    v2f.world_ray_vs = tangent.xyz;
    v2f.view_dir = normalize(v2f.fragment_to_camera_world);

    //float3x3 tangent_frame = {v2f.tangent.xyz, v2f.binormal.xyz, v2f.normal.xyz}; // use{} when float3x3 tangent_frame = ... // use() when v2f.TBN = float3x3( the {} or () matters look up why later
    v2f.TBN = float3x3(v2f.tangent.xyz, v2f.binormal.xyz, v2f.normal.xyz);
    //v2f.normal.xyz = mul(v2f.TBN, v2f.normal.xyz);
    //v2f.view_dir_tangent_space = mul(v2f.TBN, v2f.view_dir);

    v2f.world_to_oject = world_to_oject;

    v2f.scale = wpos;
    v2f.position_vs = position_vs;

    //stencil_val = 0;
    float out_depth = screen_position.z;
    float4 out_color_0 = 0;
    float4 out_color_1 = 0;
    float4 out_normal = 0;

    IF_CATEGORY_OPTION(primitive, sphere_light)
    {
        float3 center = float3(normal.w, tangent.w, binormal.w);
        float4 radius = 0;
        float4 attenuation = 0;
        area_light_sphere_ps(screen_position, texcoord, normal, center, radius, wpos, position_vs, fragment_to_camera_world, world_to_oject, out_color_0, out_depth);
    }
        IF_CATEGORY_OPTION(primitive, point_light)
    {
        point_light_ps(v2f, out_color_0, out_color_1);
    }
    IF_CATEGORY_OPTION(primitive, unit_status_basic)
    {
        unit_status_basic_ps(screen_position, texcoord.xy, wpos, out_color_0, out_depth);
    }
    IF_CATEGORY_OPTION(primitive, trajectory_helper)
    {
        trajectory_helper_ps(screen_position, texcoord, wpos, normal.w, out_color_0);
    }
        IF_CATEGORY_OPTION(primitive, test_screen_space_hud)
    {
        test_screen_space_hud_ps(screen_position, texcoord, wpos, position_vs, out_color_0, out_color_1);
	}
        IF_CATEGORY_OPTION(primitive, test_ssao)
    {
        test_ssao_ps(screen_position, texcoord, wpos, position_vs, fragment_to_camera_world, world_to_oject, out_color_0);
	}
        IF_CATEGORY_OPTION(primitive, test_rain)
    {
        vertex_shader_rain_ps(v2f, out_color_0, out_color_1);
	}
    /*IF_CATEGORY_OPTION(primitive, biplanar_decal)
    {
        decal_projector_biplanar_ps(screen_position, texcoord, wpos, world_to_oject, fragment_to_camera_world, position_vs, normal, binormal, tangent, front_face, prt_ravi_diff, extinction, inscatter, view_dir, out_color, out_depth);
    }
    IF_CATEGORY_OPTION(primitive, triplanar_decal)
    {
        decal_projector_triplanar_ps(screen_position, texcoord, wpos, world_to_oject, fragment_to_camera_world, position_vs, normal, binormal, tangent, front_face, prt_ravi_diff, extinction, inscatter, view_dir, out_color, out_depth);
    }
    IF_CATEGORY_OPTION(primitive, palettized_x_forward)
    {
        decal_projector_palettized_x_forward_ps(screen_position, texcoord, wpos, world_to_oject, fragment_to_camera_world, position_vs, normal, binormal, tangent, front_face, prt_ravi_diff, extinction, inscatter, view_dir, out_color, out_depth);
    }
    IF_CATEGORY_OPTION(primitive, spherical)
    {
        decal_projector_spherical_ps(screen_position, texcoord, wpos, world_to_oject, fragment_to_camera_world, position_vs, normal, binormal, tangent, front_face, prt_ravi_diff, extinction, inscatter, view_dir, out_color, out_depth);
    }*/

    //out_color_0.xyz = dot(v2f.normal.xyz ,float3(0,0,1));
    //DEPTH = out_depth;
    COLOR = out_color_0;
    //COLOR1 = out_color_0;
    //NORMAL = out_color;
 
   // return convert_to_decal_target(out_normal, normal, screen_position.w);
    //return out_color;
    //return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);
}

/*
void albedo_ps(//albedo_ps(
	SCREEN_POSITION_INPUT(screen_position),
    CLIP_INPUT
    //in float        clip_distance           : SV_ClipDistance,
	in float4       texcoord                : TEXCOORD0,
    in float4       wpos                    : TEXCOORD1,
    in float3       fragment_to_camera_world: TEXCOORD2,
	in float4x4     world_to_oject          : TEXCOORD3,
    in float4       position_vs             : TEXCOORD7,
    in float4       normal                  : TEXCOORD8,
    in float4       tangent                 : TEXCOORD9,
    in float4       binormal                : TEXCOORD10,
  //  out float       DEPTH                   : SV_Depth ,
    // out float DEPTH         : SV_DepthGreaterEqual
    // out float DEPTH         : SV_DepthLessEqual,
    out float4      COLOR                   : SV_Target0
    // out uint      stencil_val               : SV_StencilRef
   // out float4      NORMAL              : SV_Target1

	//in float3 normal    : TEXCOORD1,
	//in float3 binormal  : TEXCOORD2,
	//in float3 tangent   : TEXCOORD3
	//in float3 fragment_to_camera_world : TEXCOORD4
    ) //: SV_Target0
{
    float4 out_color = 0;


        IF_CATEGORY_OPTION(primitive, test_screen_space_hud)
    {
        out_color = float4(1.0, 0.0, 0.0, 0.5);
        out_color.xyz = normal.xyz;
	}
    
    COLOR = position_vs;    //float4(1.0, 0.0, 0.0, 1.0);
    //clip(COLOR.a - color.a);
   // NORMAL = float4(1.0, 0.0, 0.0, 1.0);
   // DEPTH = scale;
    //return convert_to_albedo_target(color, normal.xyz, normal.w);
}
*/

void vertex_shader_2(//albedo_vs(
    in vertex_type vertex,
    //in s_lightmap_per_pixel lightmap,
    //in s_lightmap_per_vertex in_vertex_color,
   // in float2 lightmap_texcoord		:TEXCOORD1,
  //in float3 in_vertex_color		:COLOR0,
    //in uint         vertex_id               : SV_VertexID,
    out float4      position                : SV_Position,
    //out float       clip_distance           : SV_ClipDistance,
    CLIP_OUTPUT
	out float2      texcoord                : TEXCOORD0,
    out float3      normal                  : TEXCOORD1,
    out float3      binormal                : TEXCOORD2,
	out float3      tangent                 : TEXCOORD3
   // out float3      vertex_color            : TEXCOORD4
	)
{
float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4x4 model_matrix = construct_model_matrix(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    //vertex.position.xyz += float3(position_x, position_y, position_z);
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;

    position = mul(float4(vertex.position, 1.0f), model_matrix); 
    position = mul(position, View_Projection);

    texcoord.xy = vertex.texcoord;
   //texcoord.zw = lightmap_texcoord;
    //vertex_color = in_vertex_color;


    // What you measured from zero-input test:
    // tangent(0,0,0)  -> (0,   0,   0  )   bias = (0,   0,   0  )
    // binormal(0,0,0) -> (0,   0.5, 0  )   bias = (0,   0.5, 0  )
    // normal(0,0,0)   -> (0,   0,   0.5)   bias = (0,   0,   0.5)

    //float3 tangent_color  = tangent;               // bias ~= 0, no correction needed
    //float3 binormal_color = binormal - float3(0, 0.5, 0);   // subtract green bias
    //float3 normal_color   = normal   - float3(0, 0,   0.5); // subtract blue bias


    normal =  (vertex.normal);
    binormal =  vertex.binormal;// - float3(0, 0.5, 0);   // subtract green bias
    //binormal.g = binormal.g - 0.5;
    tangent = vertex.tangent;

    CALC_CLIP(position);
}

void fragment_shader_2(
	SCREEN_POSITION_INPUT(screen_position),
    CLIP_INPUT
    //in float        clip_distance           : SV_ClipDistance,
	in float2       texcoord                : TEXCOORD0,
    in float3       normal                  : TEXCOORD1,
    in float3       binormal                : TEXCOORD2,
	in float3       tangent                 : TEXCOORD3,
    //in float3       vertex_color            : TEXCOORD4,
    out float4      COLOR                   : SV_Target0
    )
{
    /*
    float4 out_color = 0;
        IF_CATEGORY_OPTION(primitive, test_screen_space_hud)
    {
        out_color = float4(1.0, 0.0, 0.0, 0.5);
        out_color.xyz = screen_position.xyz;
	}
    COLOR = screen_position;    //float4(1.0, 0.0, 0.0, 1.0);
    */

	normal=   (normal);
	binormal=  (binormal);
	tangent=  (tangent);
    float3x3 tangent_frame = {tangent, binormal, normal};

    //normal = mul(normal, tangent_frame);


    int3 fragment_position_int = int3(screen_position.xy, 0);
    float sampled_depth = depth_buffer.Load(fragment_position_int);
    float linear_depth = 1-ConvertZToLinearDepth(sampled_depth);
    float3 pos_ws =  reconstruct_world_position(texcoord, sampled_depth);

    //float3 light_pos_1, light_pos_2, light_color_1, light_color_2;
 
    //calculate_light_test(0, pos_ws, light_pos_1, light_color_1);
    //calculate_light_test(1, pos_ws, light_pos_2, light_color_2);
    
    float4 base_map_sampled = sample2D(base_map, transform_texcoord(texcoord.xy, base_map_xform));
    COLOR.rgb = 1;


    float3 color_from_binormal = binormal + float3(0, 0.5, 0);

/*
    if (color1.a == 0)
    {
        COLOR.rgb = normal_color;//normal;
    }
     if (color1.a == 1)
    {
        COLOR.rgb = binormal_color;//binormal;
    }
     if (color1.a == 2)
    {
        COLOR.rgb = tangent_color;//tangent;
    }*/

    COLOR.rgb = tangent;

    //COLOR.rgb = normal;//base_map_sampled.rgb;
    //lerp(light_color_1, light_color_2, screen_position.xyz/screen_position.w);//distance(light_color_1, light_color_2)); //ldr_color;//* linear_depth;
    COLOR.a = color.a;

    //clip(COLOR.a - color.a);
   // NORMAL = float4(1.0, 0.0, 0.0, 1.0);
   // DEPTH = scale;
    //return convert_to_albedo_target(color, normal.xyz, normal.w);
}



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
	//stipple_test(screen_position);
    //float stipple = stipple_texture.Load(uint3(uint2(screen_position.xy)&7, 0)).r;
	//clip(stipple_threshold - stipple);
	
	//float output_alpha;
	//calc_alpha_test_ps(texcoord, output_alpha);
   // int3 fragment_position_int = int3(screen_position.xy/screen_position.w, 0);
    //float gbuffer_normal =  normal_texture.Load(fragment_position_int).a;
   // clip(5 - gbuffer_normal);
	return 1;
}


/*
void frag2(
	SCREEN_POSITION_INPUT(screen_position),
	CLIP_INPUT
    in bool         front_face              : SV_IsFrontFace,
	in float2       texcoord                : TEXCOORD0,
    in float4       wpos                    : TEXCOORD1,
    in float3       fragment_to_camera_world: TEXCOORD2,
	in float4x4     world_to_oject          : TEXCOORD3,
    in float4       position_vs             : TEXCOORD7,
    in float3       normal                  : TEXCOORD8,
    in float3       tangent                 : TEXCOORD9,
    in float3       binormal                : TEXCOORD10,
    //out float       DEPTH                   : SV_Depth, 
  //   out float DEPTH         : SV_DepthGreaterEqual
   // out float DEPTH         : SV_DepthLessEqual,
    out float4      COLOR               : SV_Target0
    // out uint      stencil_val               : SV_StencilRef
    //    out float4      out_normal              : SV_Target1

	//in float3 normal    : TEXCOORD1,
	//in float3 binormal  : TEXCOORD2,
	//in float3 tangent   : TEXCOORD3
	//in float3 fragment_to_camera_world : TEXCOORD4
    ) //: SV_Target0
{

    //stencil_val = 0;
    float  out_depth = 1;
    float4   out_color = 1;
    float4   out_normal = 1;


    IF_CATEGORY_OPTION(primitive, unit_status_basic)
    {
        unit_status_basic_ps(screen_position, texcoord, wpos, out_color);
    }
    IF_CATEGORY_OPTION(primitive, biplanar_decal)
    {
        decal_projector_biplanar_ps(screen_position, texcoord, wpos, world_to_oject, fragment_to_camera_world, position_vs, normal, tangent, front_face, out_color, out_normal, out_depth);
    }
   // DEPTH = out_depth ;
    COLOR = 1 ;
    
 
   // return convert_to_decal_target(out_normal, normal, screen_position.w);
    //return out_color;
    //return CONVERT_TO_RENDER_TARGET_FOR_BLEND(out_color, true, false);
}
*/

/*
void albedo_vs(
	in vertex_type vertex,
	out float4 position : SV_Position,
	CLIP_OUTPUT
	out float2 texcoord : TEXCOORD0,
	out float4 normal : TEXCOORD1,
	out float3 binormal : TEXCOORD2,
	out float3 tangent : TEXCOORD3,
	out float3 fragment_to_camera_world : TEXCOORD4,
    out float4 posw : TEXCOORD5)
{
	
    float4 local_to_world_transform[3];
    local_to_world_transform= Nodes[0];

    float4x4 model_matrix = construct_model_matrix_transform_only(local_to_world_transform[0], local_to_world_transform[1], local_to_world_transform[2]);

    vertex.position.xyz= vertex.position.xyz * Position_Compression_Scale.xyz + Position_Compression_Offset.xyz;
    vertex.position.xyz *= projection_clip;
    vertex.texcoord= vertex.texcoord * UV_Compression_Scale_Offset.xy + UV_Compression_Scale_Offset.zw;
    normal.xyz= vertex.normal;
    tangent= vertex.tangent;
	binormal= vertex.binormal;


    position = mul(float4(vertex.position, 1.0f), model_matrix);
    position = mul(position, View_Projection);
	normal.w= position.w;
	texcoord= vertex.texcoord;
    posw = position;
	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;
	
	CALC_CLIP(position);
}

void albedo_ps(	
    SCREEN_POSITION_INPUT(screen_position),
	CLIP_INPUT
	in float2 texcoord : TEXCOORD0,
	in float4 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4,
    in float4 posw : TEXCOORD5,
     out float      out_depth               : SV_Depth,
   out float4      out_color          : SV_Target0
    //out float4      out_normal          : SV_Target1
    )  
{
   // float4 albedo = float4(0,1,2,3);
   // float4 bump_normal = float4(0,1,2,3);

   // int3 fragment_position_int = int3(screen_position.xy, 0);
    //float depth = depth_buffer.Load(fragment_position_int);
    //float linear_depth = GetLinearDepthBungie(depth);
   // float4 COL =  albedo_texture.Load(fragment_position_int);
    //float4 NOR =  normal_texture.Load(fragment_position_int);

   // float4 ldr_color= sample2D(scene_ldr_texture, texcoord);

    float depth = 1 / (global_depth_constants.z - (posw.z/posw.w ) * global_depth_constants.y);
    out_color =screen_position.w ;// (1 - color);
    //out_depth = (posw.z / -posw.w) + 1;
    out_depth= -depth;// ( posw.z / posw.w ) ;
    //clip(-1);
   // out_normal = NOR;

    //out_color.a = COL.a;
   // return convert_to_albedo_target(albedo, normal.xyz, normal.w);
}

/*/
/*
void shadow_apply_vs(
	in vertex_type vertex,
	out float4 position : SV_Position,
	CLIP_OUTPUT
	out float2 texcoord : TEXCOORD0,
	out float4 normal : TEXCOORD1,
	out float3 binormal : TEXCOORD2,
	out float3 tangent : TEXCOORD3,
	out float3 fragment_to_camera_world : TEXCOORD4)
{
	float4 local_to_world_transform[3];
    vertex.position.xyz *= projection_clip;
	//output to pixel shader
	always_local_to_view(vertex, local_to_world_transform, position, true);
	
	// normal, tangent and binormal are all in world space
	normal.xyz= vertex.normal;
	normal.w= position.w;
	texcoord= vertex.texcoord;
	tangent= vertex.tangent;
	binormal= vertex.binormal;

	// world space vector from vertex to eye/camera
	fragment_to_camera_world= Camera_Position - vertex.position;
	
	CALC_CLIP(position);
}

albedo_pixel shadow_apply_ps(	
    SCREEN_POSITION_INPUT(screen_position),
	CLIP_INPUT
	in float2 original_texcoord : TEXCOORD0,
	in float4 normal : TEXCOORD1,
	in float3 binormal : TEXCOORD2,
	in float3 tangent : TEXCOORD3,
	in float3 fragment_to_camera_world : TEXCOORD4)
{
    float4 albedo = float4(0,0,0,1);
    float4 bump_normal = float4(1,1,0,1);
    return convert_to_albedo_target(albedo, normal.xyz, normal.w);
}
*/
#undef vertex_shader
#undef fragment_shader
#undef vertex_shader_2
#undef fragment_shader_2
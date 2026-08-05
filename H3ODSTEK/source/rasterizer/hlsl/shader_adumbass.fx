#ifdef disable_register_reorder
// magic pragma given to us by the DX10 team
// to disable the register reordering pass that was
// causing a lot of pain on the PC side of the compiler
// with this pragma we get a massive speedup on compile times
// on the PC side
//#pragma ruledisable 0x0a0c0101
#endif // #ifdef disable_register_reorder

struct s_common_pixel_data
{
    float4		fragment_position;         // screen pixel position, not divided by w
	float2		texcoord;
	
	float3		normal;
	float3		binormal;
	float3		tangent;
	float3x3	tangent_frame;
	
    float3      fragment_to_camera_world;   // world space vector from vertex to eye/camera
    float3      fragment_position_world;         // fragment_position_world = absolute world position = Camera_Position_PS - fragment_to_camera_world;

    float3	 	view_dir;	                // normalized
    float3		view_dir_in_tangent_space;		// = mul(TBN, mat.view_dir_world_space);
	float3		view_reflect_dir;		    // ReflectionVector = reflect(-mat.view_dir_world_space, mat.normal);
	float		view_dot_normal;

	float3 		object_position;
	float3		object_scale;

	float       depth;
	float       linear_depth;
};


struct s_shader_data
{
    s_common_pixel_data common;
	float4		albedo;
	float3		bump_normal;
	float		occlusion;
	float		roughness;
	float		metallic;
	float		height;
	
	float		output_alpha;
	float		specular_mask;
	float3		envmap_radiance;
	float3 		self_illum_radiance;

	float4		fragment_position_shadow;

	float4		spatially_varying_material_parameters;
	float3 		specular_fresnel_color;
	float3 		specular_albedo_color;

	float3		analytic_diffuse_radiance;
	float3 		analytic_specular_radiance;

	float4		envmap_specular_reflectance_and_roughness;
	float3 		envmap_area_specular_only;
	float4 		specular_radiance;
	float3		diffuse_radiance;

	float4 		prt_ravi_diff;
	float3		dominant_light_direction;		//fragment_to_light
	float3		dominant_light_intensity;		//light color, light_radiance

	float3 		light_radiance;
	float3 		fragment_to_light;

    float3      extinction;
    float3      inscatter;

	// simple lights
	float3 		simple_light_diffuse_light;
	float3 		simple_light_specular_light;
	float		specular_power;					// 7/15/2026 10:26 am to do: doesnt seem like most shaders even use this. can i remove this and use material parameters.a? though some do? check
	float		organism_specular_power;
	float		subsurface_specular_power;
	float3 		translucency;

	float3		simple_light_organism_subsurface_normal;
	// simple lights organism
	float3		dynamic_radiance_trasparence;
	float3 		simple_lights_bump_diffuse;
	float3 		simple_lights_bump_specular;

	float3 		simple_lights_subsurface_diffuse;
	float3 		simple_lights_subsurface_specular;
	// end simple lights organism
	float3		view_reflect_dir_organism;
	// end simple lights

	//doggy poo poo
	float		power_or_roughness_organism_mat;
	//doggy poo poo

    float       decal_id;

    //float       instance_id;

    //float3      object_center;              // center position from vertex shader
    //int         decal_mask;
};

#include "global.fx"
#include "hlsl_constant_mapping.fx"

#define LDR_ALPHA_ADJUST g_exposure.w
#define HDR_ALPHA_ADJUST g_exposure.b
#define DARK_COLOR_MULTIPLIER g_exposure.g

#include "utilities.fx"
#include "deform.fx"
#include "texture_xform_adumbass.fx"

#include "adumbass_matrix.hlsl"
#include "adumbass_functions_extra.fx"

#include "albedo_adumbass.fx"
#include "parallax_adumbass.fx"
#include "bump_mapping_adumbass.fx"
#include "self_illumination_adumbass.fx"
#include "specular_mask_adumbass.fx"
#include "material_models_adumbass.fx"
#include "environment_mapping_adumbass.fx"
#include "atmosphere.fx"
#include "alpha_test_adumbass.fx"

// any bloom overrides must be #defined before #including render_target.fx
#include "render_target.fx"
#include "albedo_pass.fx"
#include "blend_adumbass.fx"

#include "shadow_generate_adumbass.fx"

#include "active_camo.fx"

#include "debug_modes.fx"

#include "entry_points_adumbass.fx"


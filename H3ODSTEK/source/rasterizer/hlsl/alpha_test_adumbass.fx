#include "entry.fx"

PARAM_SAMPLER_2D(alpha_test_map);
PARAM(float4, alpha_test_map_xform);

float calc_alpha_test_off_ps(
	in s_shader_data SHADER_DATA)
{
	return 1.0;
}




float calc_alpha_test_on_ps(
	in s_shader_data SHADER_DATA)
{
	float alpha= sample2D(alpha_test_map, transform_texcoord(SHADER_DATA.common.texcoord, alpha_test_map_xform)).a;
	float output_alpha= alpha;

#if ENTRY_POINT(entry_point) == ENTRY_POINT_shadow_generate

	clip(alpha-0.5f);			// always on for shadow

#else

#ifdef NO_ALPHA_TO_COVERAGE
	clip(alpha-0.5f);			// have to clip pixels ourselves
#elif (DX_VERSION == 11)
	
	// we don't use alpha to coverage in D3D11, so we need to clip when alpha to coverage would have been enabled on Xenon
	// - this does the same test that is done in c_render_method_shader::postprocess_shader
	
	#define IS_NOT_ATOC_MATERIAL(material) IS_NOT_ATOC_MATERIAL_##material
	#define IS_NOT_ATOC_MATERIAL_cook_torrance 1
	#define IS_NOT_ATOC_MATERIAL_two_lobe_phong 1
	#define IS_NOT_ATOC_MATERIAL_default_skin 1
	#define IS_NOT_ATOC_MATERIAL_glass 1
	#define IS_NOT_ATOC_MATERIAL_organism 1
	
	#if IS_NOT_ATOC_MATERIAL(material_type)	!= 1
		clip(alpha-0.5f);
	#endif
#endif

#endif
	return output_alpha;
}


//#include "adumbass_alpha_test_custom.fx"
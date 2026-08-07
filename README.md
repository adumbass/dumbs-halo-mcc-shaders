# adumbass's-Halo-MCC-shaders

Modified stock Halo MCC shader hlsl + tags with more features and to enable easier writing of custom shader features. The stock hlsl shader source included in Halo 3, Halo ODST and Halo Reach in the Master Chief Collection is difficult to write custom shader for. Adding a simple triplanar function is difficult due to how these shaders were written and the tag edits needed.

# Installation
Drag and drop the files into your editing kit's root directory.
Since these hlsl files do not edit the stock `shader.render_method_definition` tag but instead a copy named `shader_adumbass.render_method_definition` stock shaders will not be affected. to use these custom shaders you have to edit the tag reference in the shader. This can be edited by enabling expert mode in guerilla, holding alt when opening a tag (in this case the relevant .shader tag) and changing the definition field at the very top to shaders\shader_adumbass.render_method_definition. Next you will most likely need to compile shaders, if you don't this can crash Sapien. Note that most stock shader tags are already compiled so Sapien doesn't crash but with custom or uncompiled shaders Sapien can crash on loading the shader. Halo3/odst/reach MCC all use shader templates, these are dev compiled shaders that are referenced in the shader tags themselves - they also get compiled when lighting a level if not compiled. You can compile them multiple ways - the two most common (before lighting a level if that is relevant) :
Example of compiling a single shader, this creates the templates but only for that single shader - if any other shader shares the exact same option and render method setup it should use this template.
```
                tool compile-shader "path\to\your\shader\tag" "win
```
if you need to compile many shaders at once you will need at least two commands.
```
                tool dump-render-method-options
```
this dumps all active shader templates, basically templates of all shader options + definitions being used in your tags directory

# New Shader Options
`
base_maps_uv_coords
` - controls texture coordinates for all base maps in all categories.

`
detail_maps_uv_coords
` - controls texture coordinates for the all detail maps in all categories.

`uv coordinate options`

**standard mesh uvs -** uses the texture coordinates of the imported mesh.
  
**world space triplanar uvs -** triplanar texture coordinates based on world position that can match across multiple objects. Can help blend terrain meshes together. On moving objects uvs will appear to 'swim' as object moves.
  
**triplanar uvs -** triplanar uv projection. 

Source : Ben Golus https://bgolus.medium.com/normal-mapping-for-a-triplanar-shader-10bf39dca05a
  
**cheap triplanar uvs -** A basic triplanar uv projection. 

Source : Inigo Quilez https://iquilezles.org/articles/biplanar/
  


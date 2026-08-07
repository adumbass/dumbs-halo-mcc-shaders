# adumbass's-Halo-MCC-shaders

Modified stock Halo MCC shader hlsl + tags with more features and to enable easier writing of custom shader features. The stock hlsl shader source included in Halo 3, Halo ODST and Halo Reach in the Master Chief Collection is difficult to write custom shader for. Adding a simple triplanar function is difficult due to how these shaders were written and the tag edits needed.

# Installation
Drag and drop the files into your editing kit's root directory

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
  


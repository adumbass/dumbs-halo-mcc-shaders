# adumbass's-Halo-MCC-shaders

Modified stock Halo MCC shader hlsl + tags with more features and to enable easier writing of custom shader features. The stock hlsl shader source included in Halo 3, Halo ODST and Halo Reach in the Master Chief Collection is difficult to write custom shader for. Adding a simple triplanar function is difficult due to how these shaders were written and the tag edits needed.

# Installation
Drag and drop the files into your editing kit's root directory

# New Shader Options
```
                base_maps_uv_coords
```
```
                detail_maps_uv_coords
```
- standard mesh uvs 
    uses the texture coordinates of the imported mesh.
- world space triplanar uvs
    triplanr texture coordinates based on world position that can match across multiple objects. Can help blend terrain meshes together, on moving objects uvs will apear to swim as object moves.
- triplanar uvs
    triplanr uv projection from Ben Golus : https://bgolus.medium.com/normal-mapping-for-a-triplanar-shader-10bf39dca05a
- cheap triplanar uvs
    triplanr uv projection from Inigo Quilez : https://iquilezles.org/articles/biplanar/
base maps uv coords controls texture coordinates for base textures in all categories
detail maps uv coords controls texture coordinates for the detail textures in all categories when they have detail texture.

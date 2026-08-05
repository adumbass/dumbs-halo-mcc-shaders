float3 extract_scale_halo(float4x4 m)
{
    float3 scale;
    scale.x = length(float3(m[0][0], m[0][1], m[0][2]));
    scale.y = length(float3(m[1][0], m[1][1], m[1][2]));
    scale.z = length(float3(m[2][0], m[2][1], m[2][2]));
    return scale;
}

float3 extract_scale_halo(in float4 node[3])
{
    float3 scale;
    scale.x = length(float3(node[0][0], node[0][1], node[0][2]));
    scale.y = length(float3(node[1][0], node[1][1], node[1][2]));
    scale.z = length(float3(node[2][0], node[2][1], node[2][2]));
    return scale;
}
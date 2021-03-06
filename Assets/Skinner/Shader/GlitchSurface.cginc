// Surface shader for Skinner Glitch
#include "Common.cginc"

// Buffers from the animation kernels
sampler2D _PositionBuffer;
float4 _PositionBuffer_TexelSize;
float _BufferOffset;

// Base material properties
half3 _Albedo;
half _Smoothness;
half _Metallic;

// Glitch thresholds
half _EdgeThreshold;
half _AreaThreshold;

// Self illumination
half _BaseHue;
half _HueRandomness;
half _Saturation;
half _Brightness;
half _EmissionProb;

// Color animation
half _HueShift;
half _BrightnessOffs;
half _AttackLength;

struct Input
{
    half3 color : COLOR;
    fixed facing : VFACE;
};

// Calculate the area of a triangle from the length of the sides.
half TriangleArea(half a, half b, half c)
{
    // Heron's formula
    half s = 0.5 * (a + b + c);
    return sqrt(s * (s - a) * (s - b) * (s - c));
}

void vert(inout appdata_full v)
{
    // Hash ID of the triangle
    float hash = v.texcoord.w;

    // V-coodinate offset for the position buffer.
    float voffs = UVRandom(hash, 0) + _BufferOffset * _PositionBuffer_TexelSize.y;

    // U-coodinate offset: change randomly when V-offs wraps around.
    float uoffs = frac(UVRandom(hash + floor(voffs), 1));

    // Actually the fractional part of V-offs is needed.
    voffs = frac(voffs);

    // Decaying animation parameter
    float decay = pow(1 - voffs, 6);

    // Fetch the world space positions.
    // p0: current vertex, p1: left-hand neighbor, p2: right-hand neighbor
    float3 p0 = tex2Dlod(_PositionBuffer, float4(frac(v.texcoord.x + uoffs), voffs, 0, 0)).xyz;
    float3 p1 = tex2Dlod(_PositionBuffer, float4(frac(v.texcoord.y + uoffs), voffs, 0, 0)).xyz;
    float3 p2 = tex2Dlod(_PositionBuffer, float4(frac(v.texcoord.z + uoffs), voffs, 0, 0)).xyz;

    // Centroid of the triangle
    float3 center = (p0 + p1 + p2) / 3;

    // Lengths of the triangle edges
    half3 edges = half3(length(p1 - p0), length(p2 - p1), length(p0 - p2));

    // Soft thresholding by the edge lengths
    half3 ecull3 = saturate((edges - _EdgeThreshold) / _EdgeThreshold);
    half ecull = max(max(ecull3.x, ecull3.y), ecull3.z);

    // Soft thresholding by the triangle area
    half area = TriangleArea(edges.x, edges.y, edges.z);
    half acull = saturate((area - _AreaThreshold) / _AreaThreshold);

    // Scale factor
    half scale = saturate(1 - max(ecull, acull)) * decay;

    // Modify the vertex position.
    v.vertex.xyz = lerp(center, p0, scale);

    // Calculate the normal vector.
    v.normal = normalize(cross(p1 - p0, p2 - p0));

    // Attack envelope
    half attack = smoothstep(0.9 - _AttackLength * 0.9, 0.95, decay);

    // Low frequency oscillation with half-wave rectified sinusoid.
    half phase = UVRandom(hash, 0) * 32 + _Time.y * 4;
    half lfo = abs(sin(phase * UNITY_PI));

    // Switch LFO randomly at zero-cross points.
    lfo *= UVRandom(hash + floor(phase), 1) < _EmissionProb;

    // Calculate HSB and convert it to RGB.
    half hue = _BaseHue + UVRandom(hash, 2) * _HueRandomness + _HueShift * attack;
    half br = _Brightness * lfo + _BrightnessOffs * attack;
    v.color.rgb = lerp(1, HueToRGB(hue), _Saturation) * br;
}

void surf(Input IN, inout SurfaceOutputStandard o)
{
    o.Albedo = _Albedo;
    o.Smoothness = _Smoothness;
    o.Metallic = _Metallic;
    o.Emission = IN.color;
    o.Normal = float3(0, 0, IN.facing > 0 ? 1 : -1);
}

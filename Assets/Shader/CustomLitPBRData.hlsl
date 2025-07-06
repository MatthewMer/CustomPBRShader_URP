#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#ifdef _ATTRIBUTES
struct Attributes {
    float4 positionOS	: POSITION;
#ifdef _NORMALMAP
	float4 tangentOS 	: TANGENT;
#endif
    float4 normalOS		: NORMAL;
    float2 uv		    : TEXCOORD0;
    float2 lightmapUV	: TEXCOORD1;
    float4 color		: COLOR;
};
#endif

#ifdef _VARYINGS
struct Varyings
{
    float4 positionCS 					: SV_POSITION;
	float2 uv		    				: TEXCOORD0;
	DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
	float3 positionWS					: TEXCOORD2;

#ifdef _NORMALMAP
	half3 normalWS					: TEXCOORD3;
	half3 tangentWS					: TEXCOORD4;
	half3 bitangentWS				: TEXCOORD5;
#else
	half3 normalWS					: TEXCOORD3;
#endif
				
#ifdef _ADDITIONAL_LIGHTS_VERTEX
	half4 fogFactorAndVertexLight	: TEXCOORD6; // x: fogFactor, yzw: vertex light
#else
	half  fogFactor					: TEXCOORD6;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	float4 shadowCoord 				: TEXCOORD7;
#endif

    half3 viewDir                   : TEXCOORD8;
	float4 color						: COLOR;
};
#endif

struct SamplesPBR
{
    float3 albedo;
#if defined(_ALPHATEST_ON) || defined(_SURFACE_TYPE_TRANSPARENT)
    float alpha;
#endif
#if defined(_NORMALMAP)
    float3 normalTS;
#endif
#if defined(_METALLICSPECGLOSSMAP)
#if defined(_SPECULAR_SETUP)
    float3 specular;
#else
    float metallic;
#endif
#endif
#if !defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
    float roughness;
#endif
#if defined(_OCCLUSIONMAP)
    float occlusion;
#endif
#if defined(_EMISSION)
    float3 emission;
#endif
};
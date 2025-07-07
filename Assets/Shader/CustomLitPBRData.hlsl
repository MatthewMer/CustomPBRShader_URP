#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#if defined(_ATTRIBUTES)
struct Attributes {
    float4 positionOS	: POSITION;
#if defined(_NORMALMAP)
	float4 tangentOS 	: TANGENT;
#endif
    float4 normalOS		: NORMAL;
    float2 uv		    : TEXCOORD0;
    float2 lightmapUV	: TEXCOORD1;
    float4 color		: COLOR;

#if defined(UNITY_INSTANCING_ENABLED)
    uint instanceID                 : TEXCOORD2;
#endif
};
#endif

#if defined(_VARYINGS)
struct Varyings
{
    float4 positionCS 					: SV_POSITION;
	float2 uv		    				: TEXCOORD0;
	DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
	float3 positionWS					: TEXCOORD2;

#if defined(_NORMALMAP)
	float4 normalWS					: TEXCOORD3;    // store viewDir in w component
	float4 tangentWS			    : TEXCOORD4;
	float4 bitangentWS				: TEXCOORD5;
#else
	float3 normalWS					: TEXCOORD3;
    float3 viewDirWS                : TEXCOORD4;
#endif
				
#if defined(_ADDITIONAL_LIGHTS_VERTEX)
	float4 fogFactorAndVertexLight	: TEXCOORD6; // x: fogFactor, yzw: vertex light
#else
	float  fogFactor					: TEXCOORD6;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	float4 shadowCoord 				: TEXCOORD7;
#endif

	float4 color						: COLOR;
#if defined(UNITY_INSTANCING_ENABLED)
    float3 positionBB               : TEXCOORD8;        // position relative to bounding box centre
    uint instanceID                 : TEXCOORD9;
#endif
};
#endif

struct SamplesPBR
{
    float4 albedoAlpha;
#if defined(_NORMALMAP)
    float3 normalTS;
#endif
#if defined(_METALLICSPECGLOSSMAP)
#if defined(_SPECULAR_SETUP)
    float3 specular;
#else
    float metallic;
#endif
    float roughness;
#endif
#if defined(_OCCLUSIONMAP)
    float occlusion;
#endif
#if defined(_EMISSION)
    float3 emission;
#endif
};
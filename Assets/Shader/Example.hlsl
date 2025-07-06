Shader "Custom/CustomShading"
{
    Properties
    {
        _EmissionStrength ("Emission Strength", Range(0, 5)) = 0.0
        _NormalStrength ("Normal Strength", Range(0, 2)) = 1.0
        _OcclusionStrength ("Occlusion Strength", Range(0, 1)) = 1.0
        _MetallicMultiplier ("Metallic Multiplier", Range(0, 1)) = 0.0
        _SmoothnessMultiplier ("Smoothness Multiplier", Range(0, 2)) = 0.5
    }
    SubShader
    {
        Tags { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"     
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags {
                "LightMode" = "UniversalForward" 
            }

            HLSLPROGRAM
            #pragma vertex CustomLitPBR_Vert
            #pragma fragment CustomLitPBR_Frag
            #pragma target 3.5

            // ---------------------------------------------------------------------------
			// Keywords
			// ---------------------------------------------------------------------------

			// Material Keywords: control which member fields are present in @SamplesPBR struct and how Unity URP handles lighting
			#define _NORMALMAP
			#define _OCCLUSIONMAP
            #define _METALLICSPECGLOSSMAP
            #define _EMISSION

			// URP Keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN

			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
			#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION // v10+ only (for SSAO support)
			#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
			#pragma multi_compile _ SHADOWS_SHADOWMASK

			// Unity Keywords
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS

            // ---------------------------------------------------------------------------
			// Structs: define custom structs @Varyings, @Attributes with all required
            //          member fields and additional ones or use defines _ATTRIBUTES,
            //          _VARYINGS followed by include "CustomLitPBRData.hlsl" for fallback
            //          to default implementations
			// ---------------------------------------------------------------------------

            #define _ATTRIBUTES
            #include "Assets/Custom/Shaders/CustomLitPBRData.hlsl"

            struct Varyings
            {
                // ***** Data required by shader stages *****
                float4 positionCS 					: SV_POSITION;
	            float2 uv		    				: TEXCOORD0;
	            DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
	            float3 positionWS					: TEXCOORD2;

            #ifdef _NORMALMAP
	            float4 normalWS					: TEXCOORD3;    // store viewDir in w component
	            float4 tangentWS			    : TEXCOORD4;
	            float4 bitangentWS				: TEXCOORD5;
            #else
	            float3 normalWS					: TEXCOORD3;
            #endif
				
            #ifdef _ADDITIONAL_LIGHTS_VERTEX
	            float4 fogFactorAndVertexLight	: TEXCOORD6; // x: fogFactor, yzw: vertex light
            #else
	            float  fogFactor					: TEXCOORD6;
            #endif

            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
	            float4 shadowCoord 				: TEXCOORD7;
            #endif

	            float4 color						: COLOR;

                // ***** Custom data *****
                float mipLevel : TEXCOORD9;
                float3 custom : TEXCOORD10;
			};

            // ---------------------------------------------------------------------------
			// Prog start:  implement required functions @Vert, @Frag, @SampleTextures 
            //              followed by include "CustomLitPBR.hlsl"
			// ---------------------------------------------------------------------------
            TEXTURE2D(_MyTex);
            SAMPLER(sampler_MyTex);

            float sigmoid(float x, float t, float s)
            {
                return 1.0 / (1.0 + exp(-s * (x - t)));
            }

            // called by CustomLitPBR_Vert: passes through Attributes and expects all additional Varyings data to be initialized besides regular interpolated PBR information
            void Vert(Attributes IN, inout Varyings OUT)
            {
                OUT.mipLevel = log2(distance(_WorldSpaceCameraPos, OUT.positionWS) * 0.3 + 1.0);
                OUT.custom = sigmoid(IN.positionWS.y, 0, 1);
            }

            // called by CustomLitPBR_Frag: passes through Varyings and expects all required samples in SamplesPBR struct
            void SampleTextures(Varyings IN, inout SamplesPBR samples)
            {
                float3 color = SAMPLE_TEXTURE2D_LOD(_MyTex, sampler_MyTex, IN.uv, IN.mipLevel).rgb;

                samples = (SamplesPBR)0;
                samples.albedoAlpha = float4(color, 1.0);
                samples.normalTS = float3(0, 0, 1);
                samples.roughness = 1.0;
                samples.occlusion = 1.0;
            }

            // _DEBUG_SURFACE will pass through SurfaceData struct
            //#define _DEBUG_SURFACE
            #ifdef _DEBUG_SURFACE
            float4 Frag (SurfaceData surfaceData)
            {
                return float4(surfaceData.normalTS, 1.0);
            }
            #endif

            // _DEBUG_INPUT will pass through InputData struct
            //#define _DEBUG_INPUT
            #ifdef _DEBUG_INPUT
            float4 Frag (InputData inputData)
            {
                float shadow =  MainLightRealtimeShadow(inputData.shadowCoord);
                return float4(shadow, shadow, shadow ,1);
            }
            #endif

            // called by CustomLitPBR_Frag: passes through final PBR color and expects final output color as return value
            float4 Frag (Varyings IN, float4 color)
            {
                return color;
            }

            #include "Assets/Custom/Shaders/CustomLitPBR.hlsl"

            ENDHLSL
        }
    }
}

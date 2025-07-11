CBUFFER_START(MaterialParameters)
float _NormalStrength;
float _EmissionStrength;
float _OcclusionStrength;
float _MetallicMultiplier;
float _SmoothnessMultiplier;
CBUFFER_END


void InitializeInputData(Varyings IN, half3 normalTS, out InputData inputData)
{
    inputData = (InputData) 0;

    inputData.positionWS = IN.positionWS;

#if defined(_NORMALMAP)
    half3 viewDirWS = half3(IN.normalWS.w, IN.tangentWS.w, IN.bitangentWS.w);
    // transform normal from tangentspace to world normal
    half3x3 TBN = half3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz);
	inputData.normalWS = TransformTangentToWorld(normalTS, TBN);
#else
    half3 viewDirWS = IN.viewDirWS;
    inputData.normalWS = IN.normalWS.xyz;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);

    viewDirWS = SafeNormalize(viewDirWS);
    inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = IN.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
	inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif

	// Fog
#ifdef _ADDITIONAL_LIGHTS_VERTEX
	inputData.fogCoord = IN.fogFactorAndVertexLight.x;
	inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
#else
    inputData.fogCoord = IN.fogFactor;
    inputData.vertexLighting = float3(0, 0, 0);
#endif

/* in v11/v12?, could use :
#ifdef _ADDITIONAL_LIGHTS_VERTEX
	inputData.fogCoord = InitializeInputDataFog(float4(inputData.positionWS, 1.0), IN.fogFactorAndVertexLight.x);
	inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
#else
	inputData.fogCoord = InitializeInputDataFog(float4(inputData.positionWS, 1.0), IN.fogFactor);
	inputData.vertexLighting = half3(0, 0, 0);
#endif
*/

    inputData.bakedGI = SAMPLE_GI(IN.lightmapUV, IN.vertexSH, inputData.normalWS.xyz);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(IN.lightmapUV);
}

void InitializeSurfaceData(Varyings IN, out SurfaceData surfaceData)
{
    surfaceData = (SurfaceData) 0;

    SamplesPBR samples;
    SampleTextures(IN, samples);
    
    surfaceData.albedo = samples.albedoAlpha.xyz * IN.color.rgb;
    
#if defined(_ALPHATEST_ON) || defined(_SURFACE_TYPE_TRANSPARENT)
    surfaceData.alpha = samples.albedoAlpha.w;
#else
    surfaceData.alpha = 1.0;
#endif
    
#ifdef _NORMALMAP
    surfaceData.normalTS = normalize(lerp(float3(0, 0, 1), samples.normalTS, _NormalStrength));
#else
    surfaceData.normalTS = float3(0, 0, 1);
#endif
    
#if defined(_EMISSION)
    surfaceData.emission = samples.emission * _EmissionStrength;
#endif

#if defined(_OCCLUSIONMAP)
    surfaceData.occlusion = lerp(1.0, samples.occlusion, _OcclusionStrength);
#else
    surfaceData.occlusion = 1.0;
#endif

#if defined(_SPECULAR_SETUP)
    surfaceData.metallic = 1.0h;
    surfaceData.specular = samples.specular.rgb;
#else
#if defined(_METALLICSPECGLOSSMAP)
    surfaceData.metallic = samples.metallic * _MetallicMultiplier;
#else
    surfaceData.metallic = 0.0h;
#endif
    surfaceData.specular = (half3) 0;
#endif

#if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
    surfaceData.smoothness = samples.albedoAlpha.w * _SmoothnessMultiplier;
#elif defined(_METALLICSPECGLOSSMAP)
    surfaceData.smoothness = (1.0 - samples.roughness) * _SmoothnessMultiplier;
#else
    surfaceData.smoothness = 0.5;
#endif
}

void InitializeVaryings(Attributes IN, out Varyings OUT)
{
    OUT = (Varyings) 0;
    
#if defined(UNITY_INSTANCING_ENABLED)
    OUT.instanceID = IN.instanceID;
#endif

#if !defined(UNITY_INSTANCING_ENABLED)
    VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
#else
    half4x4 transform = GetInstanceMatrix(IN.instanceID);
    OUT.positionBB = mul(transform, half4(IN.positionOS.xyz, 1)).xyz;
    
    VertexPositionInputs positionInputs = (VertexPositionInputs)0;
    positionInputs.positionWS = TransformObjectToWorld(OUT.positionBB);
    positionInputs.positionCS = TransformObjectToHClip(OUT.positionBB);
#endif

#if !defined(UNITY_INSTANCING_ENABLED)
#ifdef _NORMALMAP
	VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz, IN.tangentOS);
#else
    VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz);
#endif
#else
    VertexNormalInputs normalInputs = (VertexNormalInputs)0;
    half3x3 rotationScale = (float3x3)transform;
    
    normalInputs.normalWS = normalize(mul(rotationScale, IN.normalOS.xyz));
#ifdef _NORMALMAP
    normalInputs.tangentWS = normalize(mul(rotationScale, IN.tangentOS.xyz));
    normalInputs.bitangentWS = normalize(cross(normalInputs.normalWS, normalInputs.tangentWS) * IN.tangentOS.w);
#endif
#endif

    OUT.positionCS = positionInputs.positionCS;
    OUT.positionWS = positionInputs.positionWS;
    
    half3 viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
    half3 vertexLight = VertexLighting(positionInputs.positionWS, normalInputs.normalWS);
    half fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
    
#ifdef _NORMALMAP
	OUT.normalWS = float4(normalInputs.normalWS, viewDirWS.x);
	OUT.tangentWS = float4(normalInputs.tangentWS, viewDirWS.y);
	OUT.bitangentWS = float4(normalInputs.bitangentWS, viewDirWS.z);
#else
    OUT.normalWS = NormalizeNormalPerVertex(normalInputs.normalWS);
    OUT.viewDirWS = viewDirWS;
#endif
    
    OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
    OUTPUT_SH(OUT.normalWS.xyz, OUT.vertexSH);

#ifdef _ADDITIONAL_LIGHTS_VERTEX
	OUT.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
#else
    OUT.fogFactor = fogFactor;
#endif

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    OUT.shadowCoord = GetShadowCoord(positionInputs);
#endif

    OUT.uv = IN.uv;
    OUT.color = IN.color;
}

#if defined(UNITY_INSTANCING_ENABLED)
Varyings CustomLitPBR_Vert(Attributes IN, uint instanceID : SV_InstanceID)
{
    Varyings OUT;
    IN.instanceID = instanceID;
    InitializeVaryings(IN, OUT);
    Vert(IN, OUT);
    return OUT;
}
#else
Varyings CustomLitPBR_Vert(Attributes IN)
{
    Varyings OUT;
    InitializeVaryings(IN, OUT);
    Vert(IN, OUT);
    return OUT;
}
#endif

float4 CustomLitPBR_Frag(Varyings IN) : SV_Target
{
    SurfaceData surfaceData;
    InitializeSurfaceData(IN, surfaceData);

    InputData inputData;
    InitializeInputData(IN, surfaceData.normalTS, inputData);

    float4 color = UniversalFragmentPBR(inputData, surfaceData);
    
#if defined(_DEBUG_SURFACE)
    return Frag(surfaceData);
#elif defined(_DEBUG_INPUT)
    return Frag(inputData);
#else
    return Frag(IN, color);
#endif
}
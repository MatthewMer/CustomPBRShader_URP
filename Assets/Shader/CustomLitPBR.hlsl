void InitializeInputData(Varyings IN, half3 normalTS, out InputData inputData)
{
    inputData = (InputData) 0;

    inputData.positionWS = IN.positionWS;

#ifdef _NORMALMAP
    // transform normal from tangentspace to world normal
    half3x3 TBN = half3x3(IN.tangentWS.xyz, IN.bitangentWS.xyz, IN.normalWS.xyz);
	inputData.normalWS = TransformTangentToWorld(normalTS, TBN);
#else
    inputData.normalWS = IN.normalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);

    half3 viewDirWS = SafeNormalize(IN.viewDir);
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
    inputData.vertexLighting = half3(0, 0, 0);
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

    inputData.bakedGI = SAMPLE_GI(IN.lightmapUV, IN.vertexSH, inputData.normalWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(IN.lightmapUV);
}

void InitializeSurfaceData(Varyings IN, out SurfaceData surfaceData)
{
    surfaceData = (SurfaceData) 0;

    SamplesPBR samples;
    SampleTextures(IN, samples);
    
    surfaceData.albedo = samples.albedo.xyz * IN.color.rgb;
    
#if defined(_ALPHATEST_ON) || defined(_SURFACE_TYPE_TRANSPARENT)
    surfaceData.alpha = samples.albedo.w;
#else
    surfaceData.alpha = 1.0;
#endif
    
#ifdef _NORMALMAP
    surfaceData.normalTS = samples.normalTS;
#else
    surfaceData.normalTS = float3(0, 0, 1);
#endif
    
#if defined(_EMISSION)
    surfaceData.emission = samples.emission;
#endif
    
#if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
    surfaceData.smoothness = samples.albedo.w;
#elif defined(_METALLICSPECGLOSSMAP)
    surfaceData.smoothness = 1.0 - samples.roughness;
#else
    surfaceData.smoothness = 0.5;
#endif

#ifdef _OCCLUSIONMAP
    surfaceData.occlusion = samples.occlusion;
#else
    surfaceData.occlusion = 1.0;
#endif

#if _SPECULAR_SETUP
	surfaceData.metallic = 1.0h;
	surfaceData.specular = samples.specular.rgb;
#else
    surfaceData.metallic = samples.metallic;
    surfaceData.specular = (half3)0;
#endif
}

Varyings InitializeVaryings(Attributes IN)
{
    Varyings OUT = (Varyings) 0;

    VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
#ifdef _NORMALMAP
	VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz, IN.tangentOS);
#else
    VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz);
#endif

    OUT.positionCS = positionInputs.positionCS;
    OUT.positionWS = positionInputs.positionWS;
    
    half3 viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
    half3 vertexLight = VertexLighting(positionInputs.positionWS, normalInputs.normalWS);
    half fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
    
    OUT.viewDir = viewDirWS;
    
#ifdef _NORMALMAP
	OUT.normalWS = normalInputs.normalWS;
	OUT.tangentWS = normalInputs.tangentWS;
	OUT.bitangentWS = normalInputs.bitangentWS;
#else
    OUT.normalWS = NormalizeNormalPerVertex(normalInputs.normalWS);
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

    return OUT;
}

Varyings CustomLitPBR_Vert(Attributes IN)
{
    Varyings OUT = InitializeVaryings(IN);
    Vert(IN, OUT);
    return OUT;
}

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
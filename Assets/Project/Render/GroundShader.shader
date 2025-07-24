Shader "Custom/Ground"
{
    Properties
    {
        _BaseColor          ("Color", Color)                      = (0.5,0.5,0.5,1)

        [Space]
        _ShadowStep         ("ShadowStep", Range(0, 1))           = 0.5
        _ShadowStepSmooth   ("ShadowStepSmooth", Range(0, 1))     = 0.04

        [Space] 
        _SpecularStep       ("SpecularStep", Range(0, 1))         = 0.6
        _SpecularStepSmooth ("SpecularStepSmooth", Range(0, 1))   = 0.05
        [HDR]_SpecularColor ("SpecularColor", Color)              = (1,1,1,1)

        [Space]
        _RimStep            ("RimStep", Range(0, 1))              = 0.65
        _RimStepSmooth      ("RimStepSmooth",Range(0,1))          = 0.4
        _RimColor           ("RimColor", Color)                   = (1,1,1,1)

        [Space]
        _GrassTex           ("Grass Texture", 2D)                 = "white" {}
        _RockTex            ("Rock Texture", 2D)                  = "white" {}
        _SandTex            ("Sand Texture", 2D)                  = "white" {}
    }

    SubShader
    {
        Tags 
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "LightMode" = "UniversalForward"
        }

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }
            

            HLSLPROGRAM
            #pragma prefer_hlslcc gles

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

            TEXTURE2D(_GrassTex); SAMPLER(sampler_GrassTex);
            TEXTURE2D(_RockTex); SAMPLER(sampler_RockTex);
            TEXTURE2D(_SandTex); SAMPLER(sampler_SandTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float _ShadowStep;
                float _ShadowStepSmooth;
                float _SpecularStep;
                float _SpecularStepSmooth;
                float4 _SpecularColor;
                float _RimStepSmooth;
                float _RimStep;
                float4 _RimColor;
                float4 _GrassTex_ST;
                float4 _RockTex_ST;
                float4 _SandTex_ST;
            CBUFFER_END

            struct appdata
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uvGrass : TEXCOORD0;
                float2 uvRock : TEXCOORD1;
                float2 uvSand : TEXCOORD2;
                float3 normalWS : TEXCOORD4;
                float3 viewDirWS : TEXCOORD5;
                float3 positionWS : TEXCOORD6;
                float4 vertexColor : COLOR;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 7);
                float4 shadowCoord : TEXCOORD8;
                float4 fogCoord : TEXCOORD9;
                float4 positionCS : SV_POSITION;
                #if defined(DYNAMICLIGHTMAP_ON)
                    float2 dynamicLightmapUV : TEXCOORD10;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);

                float3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;

                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;
                o.normalWS = normalInput.normalWS;
                o.viewDirWS = viewDirWS;

                o.uvGrass = TRANSFORM_TEX(v.uv, _GrassTex);
                o.uvRock  = TRANSFORM_TEX(v.uv, _RockTex);
                o.uvSand  = TRANSFORM_TEX(v.uv, _SandTex);

                //o.shadowCoord = TransformWorldToShadowCoord(vertexInput.positionWS);
                o.fogCoord = ComputeFogFactor(o.positionCS.z);

                o.vertexColor = v.color;

                OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS.xyz, o.vertexSH);
                #if defined(DYNAMICLIGHTMAP_ON)
                    o.dynamicLightmapUV = v.lightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);

               

                float3 texGrass = SAMPLE_TEXTURE2D(_GrassTex, sampler_GrassTex, i.uvGrass).rgb;
                float3 texRock  = SAMPLE_TEXTURE2D(_RockTex, sampler_RockTex, i.uvRock).rgb;
                float3 texSand  = SAMPLE_TEXTURE2D(_SandTex, sampler_SandTex, i.uvSand).rgb;

                float3 blend = saturate(i.vertexColor.rgb);
                blend /= max(0.0001, blend.r + blend.g + blend.b);

                float3 baseColor = texGrass * blend.r + texRock * blend.g + texSand * blend.b;
                float3 albedo = baseColor * _BaseColor.rgb;

                float3 bakedGI = SampleSH(i.normalWS);
                #ifdef LIGHTMAP_ON
                    #ifdef DIRLIGHTMAP_COMBINED
                        bakedGI = SampleLightmap(i.lightmapUV, i.normalWS);
                    #else
                        bakedGI = SampleSingleLightmap(i.lightmapUV, i.normalWS);
                    #endif
                #endif

                #if defined(DYNAMICLIGHTMAP_ON)
                    bakedGI += SampleDynamicLightmap(i.dynamicLightmapUV, i.normalWS);
                #endif


                Light mainLight = GetMainLight(shadowCoord);
                mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
                half3 attenuatedLightColor = mainLight.color * (mainLight.distanceAttenuation * mainLight.shadowAttenuation);

                float3 N = normalize(i.normalWS);
                float3 V = normalize(i.viewDirWS);

                float3 L = normalize(mainLight.direction);
                float3 H = normalize(V + L);

                float NV = dot(N, V);
                float NL = dot(N, L);
                float NH = dot(N, H);

                float shadowNL = smoothstep(_ShadowStep - _ShadowStepSmooth, _ShadowStep + _ShadowStepSmooth, NL * 0.5 + 0.5);
                float specularNH = smoothstep((1 - _SpecularStep * 0.05) - _SpecularStepSmooth * 0.05,
                                              (1 - _SpecularStep * 0.05) + _SpecularStepSmooth * 0.05, NH);
                float rim = smoothstep((1 - _RimStep) - _RimStepSmooth * 0.5,
                                       (1 - _RimStep) + _RimStepSmooth * 0.5, 0.5 - NV);

                float3 diffuse = albedo * shadowNL * attenuatedLightColor;

                float3 specular = _SpecularColor.rgb * specularNH * attenuatedLightColor;
                float3 rimLight = rim * _RimColor.rgb * albedo;
                float3 ambient = bakedGI * albedo + rimLight;

                float3 finalColor = (diffuse + ambient + specular);

                int additionalLightsCount = GetAdditionalLightsCount();
                for (int e = 0; e < additionalLightsCount; ++e)
                {
                    Light light = GetAdditionalLight(e, i.positionWS);
                    float3 lightDir = normalize(light.direction);
                    float3 H_add = normalize(V + lightDir);

                    float NL_add = dot(N, lightDir);
                    float NH_add = dot(N, H_add);

                    float diffuseTerm = smoothstep(_ShadowStep - _ShadowStepSmooth, _ShadowStep + _ShadowStepSmooth, NL_add * 0.5 + 0.5);
                    float specularTerm = smoothstep((1 - _SpecularStep * 0.05) - _SpecularStepSmooth * 0.05,
                                                    (1 - _SpecularStep * 0.05) + _SpecularStepSmooth * 0.05, NH_add);

                    float3 addDiffuse = albedo * diffuseTerm * light.color;
                    float3 addSpecular = _SpecularColor.rgb * specularTerm * light.color;

                    finalColor += (addDiffuse + addSpecular) * light.distanceAttenuation;
                }

                finalColor = MixFog(finalColor, i.fogCoord);
                return float4(finalColor, 1.0);
            }

            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }

            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            #pragma multi_compile_instancing
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"
            ENDHLSL
        }


        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        


    }
}

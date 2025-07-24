Shader "Custom/ToonWater"
{
    Properties
    {
        _DepthGradientShallow("Depth Gradient Shallow", Color) = (0.325, 0.807, 0.971, 0.725)
        _DepthGradientDeep("Depth Gradient Deep", Color) = (0.086, 0.407, 1, 0.749)
        _DepthMaxDistance("Depth Maximum Distance", Float) = 1
        _FoamColor("Foam Color", Color) = (1,1,1,1)

        [Space]
        _SurfaceNoise("Surface Noise", 2D) = "white" {}
        _SurfaceNoiseScroll("Surface Noise Scroll Amount", Vector) = (0.03, 0.03, 0, 0)
        _SurfaceNoiseCutoff("Surface Noise Cutoff", Range(0, 1)) = 0.777

        [Space]
        _SurfaceDistortion("Surface Distortion", 2D) = "white" {}
        _SurfaceDistortionAmount("Surface Distortion Amount", Range(0, 1)) = 0.27

        [Space]
        _FoamMaxDistance("Foam Maximum Distance", Float) = 0.4
        _FoamMinDistance("Foam Minimum Distance", Float) = 0.04
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS_PIXEL
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

            TEXTURE2D(_SurfaceNoise); SAMPLER(sampler_SurfaceNoise);
            TEXTURE2D(_SurfaceDistortion); SAMPLER(sampler_SurfaceDistortion);
            TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraNormalsTexture); SAMPLER(sampler_CameraNormalsTexture);

            CBUFFER_START(UnityPerMaterial)
                float4 _DepthGradientShallow;
                float4 _DepthGradientDeep;
                float4 _FoamColor;
                float _DepthMaxDistance;
                float _FoamMaxDistance;
                float _FoamMinDistance;
                float _SurfaceNoiseCutoff;
                float _SurfaceDistortionAmount;
                float2 _SurfaceNoiseScroll;
                float4 _SurfaceNoise_ST;
                float4 _SurfaceDistortion_ST;
            CBUFFER_END

            struct appdata
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionCS     : SV_POSITION;
                float2 uvNoise        : TEXCOORD0;
                float2 uvDistortion   : TEXCOORD1;
                float4 screenUV       : TEXCOORD2;
                float3 viewNormalWS   : TEXCOORD3;
                float4 fogCoord       : TEXCOORD4;
            };

            v2f vert(appdata v)
            {
                v2f o;
                VertexPositionInputs vPos = GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs vNorm = GetVertexNormalInputs(v.normalOS);

                o.positionCS = vPos.positionCS;
                o.screenUV = ComputeScreenPos(o.positionCS);

                o.uvNoise = TRANSFORM_TEX(v.uv, _SurfaceNoise);
                o.uvDistortion = TRANSFORM_TEX(v.uv, _SurfaceDistortion);

                float3 viewDirWS = GetWorldSpaceViewDir(vPos.positionWS);
                o.viewNormalWS = normalize(reflect(-viewDirWS, vNorm.normalWS));

                o.fogCoord = ComputeFogFactor(o.positionCS.z);
                return o;
            }

            float4 alphaBlend(float4 top, float4 bottom)
            {
                float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
                float alpha = top.a + bottom.a * (1 - top.a);
                return float4(color, alpha);
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 screenUV = i.screenUV.xy / i.screenUV.w;

                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                float linearDepth = LinearEyeDepth(rawDepth, _ZBufferParams);

                float depthDifference = linearDepth - i.screenUV.w;

                float depthFactor = saturate(depthDifference / _DepthMaxDistance);
                float4 waterColor = lerp(_DepthGradientShallow, _DepthGradientDeep, depthFactor);

                float3 normalTex = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, screenUV).rgb;
                float foamNormalDot = saturate(dot(normalTex, i.viewNormalWS));

                float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, foamNormalDot);
                float foamFactor = saturate(depthDifference / foamDistance);
                float noiseCut = foamFactor * _SurfaceNoiseCutoff;

                float2 distortion = (SAMPLE_TEXTURE2D(_SurfaceDistortion, sampler_SurfaceDistortion, i.uvDistortion).xy * 2 - 1) * _SurfaceDistortionAmount;
                float2 noiseUV = i.uvNoise + _Time.y * _SurfaceNoiseScroll + distortion;

                float noiseSample = SAMPLE_TEXTURE2D(_SurfaceNoise, sampler_SurfaceNoise, noiseUV).r;
                float surfaceNoise = smoothstep(noiseCut - 0.01, noiseCut + 0.01, noiseSample);

                float4 foamColor = _FoamColor;
                foamColor.a *= surfaceNoise;
                waterColor.rgb = MixFog(waterColor.rgb, i.fogCoord);

                return alphaBlend(foamColor, waterColor);
            }
            ENDHLSL
        }
    }
    FallBack Off
}

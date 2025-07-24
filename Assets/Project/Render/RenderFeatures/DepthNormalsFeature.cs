using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DepthNormalsFeature : ScriptableRendererFeature
{
    class DepthNormalsPass : ScriptableRenderPass
    {
        RTHandle depthNormalsTexture;
        ShaderTagId shaderTagId = new ShaderTagId("DepthNormals");
        FilteringSettings filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

        public DepthNormalsPass()
        {
            renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        }

        [System.Obsolete]
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var descriptor = renderingData.cameraData.cameraTargetDescriptor;
            descriptor.colorFormat = RenderTextureFormat.ARGB32;
            descriptor.depthBufferBits = 0;
            descriptor.msaaSamples = 1;

            RenderingUtils.ReAllocateIfNeeded(ref depthNormalsTexture, descriptor, name: "_CameraDepthNormalsTexture");

            ConfigureTarget(depthNormalsTexture);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        [System.Obsolete]
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!depthNormalsTexture.rt.IsCreated()) return;

            CommandBuffer cmd = CommandBufferPool.Get("Render DepthNormals");
            using (new ProfilingScope(cmd, new ProfilingSampler("DepthNormals Pass")))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                var drawingSettings = CreateDrawingSettings(shaderTagId, ref renderingData, SortingCriteria.CommonOpaque);
                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            // Optional: Clear temporary RTHandle if needed here
        }
    }

    DepthNormalsPass depthNormalsPass;

    public override void Create()
    {
        depthNormalsPass = new DepthNormalsPass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(depthNormalsPass);
    }
}

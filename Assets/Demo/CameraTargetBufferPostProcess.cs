using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
[Serializable]
[PostProcess(typeof(CameraTargetBufferPostProcessRenderer), PostProcessEvent.BeforeStack, "Custom/CameraTargetBufferPostProcess", false)]
public sealed class CameraTargetBufferPostProcess : PostProcessEffectSettings
{

}
public sealed class CameraTargetBufferPostProcessRenderer : PostProcessEffectRenderer<CameraTargetBufferPostProcess>
{
    private AWater.CameraRenderTargetReplace cameraRenderTarget;
    private Shader _shader;
    public override void Init()
    {
        var mainCamera = Camera.main;
        if (mainCamera != null)
        {
            cameraRenderTarget = mainCamera.GetComponent<AWater.CameraRenderTargetReplace>();
        }
        _shader = Shader.Find("Hidden/PostProcessing/CopyKeepUV");
    }

    public override void Render(PostProcessRenderContext context)
    {
        if (cameraRenderTarget != null && cameraRenderTarget.ColorRenderTexture != null)
        {
            var sheet = context.propertySheets.Get(_shader);
            context.command.BlitFullscreenTriangle(cameraRenderTarget.ColorRenderTexture, context.destination, sheet, 0);
        }
    }
}

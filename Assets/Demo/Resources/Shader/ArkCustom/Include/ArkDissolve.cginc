#ifndef _MINIPBR_DISSOLVE_
#define _MINIPBR_DISSOLVE_

/// 【引擎技术应用部 - 白糖】 本cginc负责实现溶解效果
/// 因为一些具体的需求，采用了和PBRVFX中不一样的处理办法。

// Property block
    // [Header(Dissolving)]
    // [Toggle(_DISSOLVE)]_Dissolve("Use Dissolving Effect", Int) = 0
    // [ShowIfEnabled(_DISSOLVE)][NoScaleOffset]_DissolveTexture("Dissolving Texture", 2D) = "white" {}
    // [ShowIfEnabled(_DISSOLVE)]_DissolveProgress("Dissolving Progress", Float) = 0
    // [ShowIfEnabled(_DISSOLVE)][HDR]_DissolveBorderColor("Dissolving Border Color", Color) = (1,1,1,1)
    // [ShowIfEnabled(_DISSOLVE)]_DissolveBorderWidth("Dissolving Border Width", Range(0,1)) = 0.01
    // [ShowIfEnabled(_DISSOLVE)]_DissolveBorderSmooth("Dissolving Border Smooth", Range(0, 0.2)) = 0.01
    // [ShowIfEnabled(_DISSOLVE)]_DirectionalDissolveDirection("Directional Dissolve Direction", Vector) = (0,0,0,0)
    // [ShowIfEnabled(_DISSOLVE)]_DirectionalDissolvePivot("Directional Dissolve Pivot (World Space)", Vector) = (0,0,0,0)
    // [ShowIfEnabled(_DISSOLVE)]_DirectionalDissolveRange("Directional Dissolve Range", Range(0.01,10)) = 1


#ifdef _DISSOLVE

    sampler2D _DissolveTexture;
    half _DissolveProgress;
    half4 _DissolveBorderColor;                 // 边缘颜色
    half _DissolveBorderWidth;                  // 边缘宽度
    half _DissolveBorderSmooth;                 // 边缘和普通衣服过渡的范围
    half4 _DirectionalDissolveDirection;        // 方向溶解的坐标
    half4 _DirectionalDissolvePivot;            // 方向溶解的中点，因为以世界坐标，所以使用时需要代码赋值
    half _DirectionalDissolveRange;             // 方向溶解的范围

    inline half CalculateDissolveProgress()
    {
        half a;
        a = lerp(-0.05 - _DissolveBorderWidth - _DissolveBorderSmooth, 1.05 * (1 + _DirectionalDissolveDirection.w * _DirectionalDissolveRange), _DissolveProgress);
        return a;
    }

    inline half CalculateDissolveBorder(fixed dissolveAlpha, half progress)
    {
        half weight = smoothstep( dissolveAlpha - _DissolveBorderWidth - _DissolveBorderSmooth, dissolveAlpha - _DissolveBorderWidth, progress);
        return weight;
    }

    inline half CalculateDirectionalOffset(half3 worldPos)
    {
        half3 offsetDirection = worldPos - _DirectionalDissolvePivot;
        half directionalOffset = dot(normalize(_DirectionalDissolveDirection.xyz), offsetDirection);
        directionalOffset *= _DirectionalDissolveDirection.w * _DirectionalDissolveRange; // 用这个来储存要不要方向。
        return directionalOffset;
    }

    #define DissolveColor(color, uv, worldPos) color = ApplyDissolve(color,uv,worldPos);
    #define DissolveSilhoute(color, uv, worldPos) color = ApplyDissolveSilhoute(color,uv, worldPos);

    half4 ApplyDissolve(inout half4 color, half2 uv, half3 worldPos)
    {
        fixed dissolveAlpha = tex2D(_DissolveTexture, uv).r;

        // 加算方向
        dissolveAlpha += CalculateDirectionalOffset(worldPos);

        half a = CalculateDissolveProgress();
        clip(dissolveAlpha - a);
        color.rgb = lerp(color.rgb, _DissolveBorderColor.rgb, CalculateDissolveBorder(dissolveAlpha, a));
        return color;
    }

    half4 ApplyDissolveSilhoute(half4 color, half2 uv, half3 worldPos)
    {
        fixed dissolveAlpha = tex2D(_DissolveTexture, uv).r;

        // 加算方向
        dissolveAlpha += CalculateDirectionalOffset(worldPos);


        clip(dissolveAlpha - CalculateDissolveProgress());
        return color;
    }

    

#else
    #define DissolveColor(color, uv, worldPos)
    #define DissolveSilhoute(color, uv, worldPos)

#endif



#endif  // _MINIPBR_DISSOLVE_
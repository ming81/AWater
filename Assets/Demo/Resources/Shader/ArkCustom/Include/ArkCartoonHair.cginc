#ifndef _MINIPBR_CartoonHair_
#define _MINIPBR_CartoonHair_

/// 【引擎技术应用部 - 白糖】 本cginc负责实现头发的效果
/// 这里运用的是Matcap的做法。
/// 参考了UCS https://github.com/unity3d-jp/UnityChanToonShaderVer2_Project/blob/master/Manual/UTS2_Manual_en.md


            uniform fixed _MatCap;
            uniform sampler2D _MatCap_Sampler; uniform float4 _MatCap_Sampler_ST;
            uniform float4 _MatCapColor;
            uniform fixed _Is_LightColor_MatCap;
            uniform fixed _Is_BlendAddToMatCap;
            uniform float _Tweak_MatCapUV;
            uniform float _Rotate_MatCapUV;
            uniform fixed _Is_NormalMapForMatCap;
            uniform sampler2D _NormalMapForMatCap; uniform float4 _NormalMapForMatCap_ST;
            uniform float _Rotate_NormalMapForMatCapUV;
            uniform fixed _Is_UseTweakMatCapOnShadow;
            uniform float _TweakMatCapOnShadow;
            //MatcapMask
            uniform sampler2D _Set_MatcapMask; uniform float4 _Set_MatcapMask_ST;
            uniform float _Tweak_MatcapMaskLevel;
            //v.2.0.5
            uniform fixed _Is_Ortho;
            //v.2.0.6
            uniform float _CameraRolling_Stabilizer;
            uniform fixed _BlurLevelMatcap;
            uniform fixed _Inverse_MatcapMask;

half4 ApplyMatCap(half4 inputColor, float2 uv, float3 worldDir, float3x3 tangentTransform, half3 viewDirection, half3 lightColor)
{
    half4 finalColor;

    float2 Set_UV0 = uv;
    float3 Set_LightColor = lightColor.rgb;
    float Set_FinalShadowMask = 1.0;
    float3 Set_HighColor = float3(1,0,0);

    //Matcap
    //v.2.0.6 : CameraRolling Stabilizer
    //鏡スクリプト判定：_sign_Mirror = -1 なら、鏡の中と判定.
    //fixed _sign_Mirror = facing >0 ? 1 : -1;
    fixed _sign_Mirror = 1;
    float3 _Camera_Right = UNITY_MATRIX_V[0].xyz;
    float3 _Camera_Front = UNITY_MATRIX_V[2].xyz;
    float3 _Up_Unit = float3(0, 1, 0);
    float3 _Right_Axis = cross(_Camera_Front, _Up_Unit);
    //鏡の中なら反転.
    if(_sign_Mirror < 0){
        _Right_Axis = -1 * _Right_Axis;
        _Rotate_MatCapUV = -1 * _Rotate_MatCapUV;
    }else{
        _Right_Axis = _Right_Axis;
    }
    float _Camera_Right_Magnitude = sqrt(_Camera_Right.x*_Camera_Right.x + _Camera_Right.y*_Camera_Right.y + _Camera_Right.z*_Camera_Right.z);
    float _Right_Axis_Magnitude = sqrt(_Right_Axis.x*_Right_Axis.x + _Right_Axis.y*_Right_Axis.y + _Right_Axis.z*_Right_Axis.z);
    float _Camera_Roll_Cos = dot(_Right_Axis, _Camera_Right) / (_Right_Axis_Magnitude * _Camera_Right_Magnitude);
    float _Camera_Roll = acos(clamp(_Camera_Roll_Cos, -1, 1));
    fixed _Camera_Dir = _Camera_Right.y < 0 ? -1 : 1;
    float _Rot_MatCapUV_var_ang = (_Rotate_MatCapUV*3.141592654) - _Camera_Dir*_Camera_Roll*_CameraRolling_Stabilizer;
    //
    float _Rot_MatCapUV_var_spd = 1.0;
    float _Rot_MatCapUV_var_cos = cos(_Rot_MatCapUV_var_spd*_Rot_MatCapUV_var_ang);
    float _Rot_MatCapUV_var_sin = sin(_Rot_MatCapUV_var_spd*_Rot_MatCapUV_var_ang);
    float2 _Rot_MatCapUV_var_piv = float2(0.5,0.5);
    float _Rot_MatCapNmUV_var_ang = (_Rotate_NormalMapForMatCapUV*3.141592654);
    float _Rot_MatCapNmUV_var_spd = 1.0;
    float _Rot_MatCapNmUV_var_cos = cos(_Rot_MatCapNmUV_var_spd*_Rot_MatCapNmUV_var_ang);
    float _Rot_MatCapNmUV_var_sin = sin(_Rot_MatCapNmUV_var_spd*_Rot_MatCapNmUV_var_ang);
    float2 _Rot_MatCapNmUV_var_piv = float2(0.5,0.5);
    float2 _Rot_MatCapNmUV_var = (mul(Set_UV0-_Rot_MatCapNmUV_var_piv,float2x2( _Rot_MatCapNmUV_var_cos, -_Rot_MatCapNmUV_var_sin, _Rot_MatCapNmUV_var_sin, _Rot_MatCapNmUV_var_cos))+_Rot_MatCapNmUV_var_piv);
    //V.2.0.6
    float3 _NormalMapForMatCap_var = UnpackNormal(tex2D(_NormalMapForMatCap,TRANSFORM_TEX(_Rot_MatCapNmUV_var, _NormalMapForMatCap)));
    //float3 _NormalMapForMatCap_var = UnpackScaleNormal(tex2D(_NormalMapForMatCap,TRANSFORM_TEX(_Rot_MatCapNmUV_var, _NormalMapForMatCap)),_BumpScaleMatcap);
    //v.2.0.5: MatCap with camera skew correction
    //float3 viewNormal = (mul(UNITY_MATRIX_V, float4(lerp( i.normalDir, mul( _NormalMapForMatCap_var.rgb, tangentTransform ).rgb, _Is_NormalMapForMatCap ),0))).rgb;
    float3 viewNormal = (mul(UNITY_MATRIX_V, float4(lerp( worldDir, mul( _NormalMapForMatCap_var.rgb, tangentTransform ).rgb, _Is_NormalMapForMatCap ),0))).rgb;
    float3 NormalBlend_MatcapUV_Detail = viewNormal.rgb * float3(-1,-1,1);
    float3 NormalBlend_MatcapUV_Base = (mul( UNITY_MATRIX_V, float4(viewDirection,0) ).rgb*float3(-1,-1,1)) + float3(0,0,1);
    float3 noSknewViewNormal = NormalBlend_MatcapUV_Base*dot(NormalBlend_MatcapUV_Base, NormalBlend_MatcapUV_Detail)/NormalBlend_MatcapUV_Base.b - NormalBlend_MatcapUV_Detail;                
    float2 _ViewNormalAsMatCapUV = (lerp(noSknewViewNormal,viewNormal,_Is_Ortho).rg*0.5)+0.5;
    //
    float2 _Rot_MatCapUV_var = (mul((0.0 + ((_ViewNormalAsMatCapUV - (0.0+_Tweak_MatCapUV)) * (1.0 - 0.0) ) / ((1.0-_Tweak_MatCapUV) - (0.0+_Tweak_MatCapUV)))-_Rot_MatCapUV_var_piv,float2x2( _Rot_MatCapUV_var_cos, -_Rot_MatCapUV_var_sin, _Rot_MatCapUV_var_sin, _Rot_MatCapUV_var_cos))+_Rot_MatCapUV_var_piv);
    //鏡の中ならUV左右反転.
    if(_sign_Mirror < 0){
        _Rot_MatCapUV_var.x = 1-_Rot_MatCapUV_var.x;
    }else{
        _Rot_MatCapUV_var = _Rot_MatCapUV_var;
    }
    //v.2.0.6 : LOD of Matcap
    //float4 _MatCap_Sampler_var = tex2D(_MatCap_Sampler,TRANSFORM_TEX(_Rot_MatCapUV_var, _MatCap_Sampler));
    float4 _MatCap_Sampler_var = tex2Dlod(_MatCap_Sampler,float4(TRANSFORM_TEX(_Rot_MatCapUV_var, _MatCap_Sampler),0.0,_BlurLevelMatcap));
    //
    //MatcapMask
    float4 _Set_MatcapMask_var = tex2D(_Set_MatcapMask,TRANSFORM_TEX(Set_UV0, _Set_MatcapMask));
    float _Tweak_MatcapMaskLevel_var = saturate(lerp(_Set_MatcapMask_var.g, (1.0 - _Set_MatcapMask_var.g), _Inverse_MatcapMask) + _Tweak_MatcapMaskLevel);
    //
    float3 _Is_LightColor_MatCap_var = lerp( (_MatCap_Sampler_var.rgb*_MatCapColor.rgb), ((_MatCap_Sampler_var.rgb*_MatCapColor.rgb)*Set_LightColor), _Is_LightColor_MatCap );
    //v.2.0.6 : ShadowMask on Matcap in Blend mode : multiply
    float3 Set_MatCap = lerp( _Is_LightColor_MatCap_var, (_Is_LightColor_MatCap_var*((1.0 - Set_FinalShadowMask)+(Set_FinalShadowMask*_TweakMatCapOnShadow)) + lerp(Set_HighColor*Set_FinalShadowMask*(1.0-_TweakMatCapOnShadow), float3(0.0, 0.0, 0.0), _Is_BlendAddToMatCap)), _Is_UseTweakMatCapOnShadow );
    //
    //float4 _Emissive_Tex_var = tex2D(_Emissive_Tex,TRANSFORM_TEX(Set_UV0, _Emissive_Tex));
    //Composition: RimLight and MatCap as finalColor
    //Broke down finalColor composition
    float3 matCapColorOnAddMode = inputColor.rgb+Set_MatCap*_Tweak_MatcapMaskLevel_var;
    float _Tweak_MatcapMaskLevel_var_MultiplyMode = _Tweak_MatcapMaskLevel_var * lerp (1.0, (1.0 - (Set_FinalShadowMask)*(1.0 - _TweakMatCapOnShadow)), _Is_UseTweakMatCapOnShadow);
    //float3 matCapColorOnMultiplyMode = Set_HighColor*(1-_Tweak_MatcapMaskLevel_var_MultiplyMode) + Set_HighColor*Set_MatCap*_Tweak_MatcapMaskLevel_var_MultiplyMode + lerp(float3(0,0,0),Set_RimLight,_RimLight);
    //float3 matCapColorFinal = lerp(matCapColorOnMultiplyMode, matCapColorOnAddMode, _Is_BlendAddToMatCap);
    //float3 finalColor_v3 = lerp(inputColor.rgb, matCapColorFinal, _MatCap);// Final Composition before Emissive
    float3 finalColor_v3 = lerp(inputColor.rgb, matCapColorOnAddMode, _MatCap);// Final Composition before Emissive
    //
    finalColor = half4(finalColor_v3,inputColor.a);

    return finalColor;
}


#endif  // _MINIPBR_DISSOLVE_
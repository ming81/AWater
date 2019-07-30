#ifndef _ZEUS_PBR_VFX_
#define _ZEUS_PBR_VFX_

#include "UnityCG.cginc" 
 
/*ASE_PROPERTY_START FEATURE_FXLight
[Header(FXLight)]
[Toggle(FEATURE_FXLight)]FEATURE_FXLight("FEATURE FXLight", Int) = 0
[ShowIfEnabled(FEATURE_FXLight)] _FXMap("FX Map", 2D) ="black"{}
[ShowIfEnabled(FEATURE_FXLight)]_FXScale("FX Scale",  Range(0.0, 2.0)) = 1.0
[ShowIfEnabled(FEATURE_FXLight)]_FXSpeed("FX Speed",  Range(-2, 2.0)) = 1.0
[ShowIfEnabled(FEATURE_FXLight)]_FXPause("FX Pause",  Range(0,10)) = 2.0
[ShowIfEnabled(FEATURE_FXLight)]_FXOffset("FX Offset",  Range(-1,1)) = 0.0
[ShowIfEnabled(FEATURE_FXLight)]_FXBump("FX Bump",   Range(0,1)) = 0.0
[ShowIfEnabled(FEATURE_FXLight)]_FXColor("FX Color",  Color) = (1.0,1.0,1.0,1.0)
[ShowIfEnabled(FEATURE_FXLight)]_FXDirection("FX Direction", Float) = 2.0
ASE_PROPERTY_END */

/*ASE_FEATURE_START FEATURE_FXLight
#include "Assets/Zeus/RenderFramework/Carava/MiniPBR/Shader/Include/PBRVFX.cginc"
#pragma multi_compile _ FEATURE_FXLight
ASE_FEATURE_END  */


/*ASE_PROPERTY_START FEATURE_Dissolve
[Header(Dissolve)]
[Toggle(FEATURE_Dissolve)] FEATURE_Dissolve("FEATURE Dissolve", Int) = 0
[ShowIfEnabled(FEATURE_Dissolve)]_DissolveTex("Dissolve Texture (R)", 2D) = "white"{}
[ShowIfEnabled(FEATURE_Dissolve)]_DissolveBlend("Dissolve Blend", Range(0, 1)) = 0.5
[ShowIfEnabled(FEATURE_Dissolve)]_BorderSize("Border Size", Range(0.0, 1.0)) = 0.1
[ShowIfEnabled(FEATURE_Dissolve)]_BorderMap("Border Map", 2D) = "white"{}
[ShowIfEnabled(FEATURE_Dissolve)]_DissolveUVOffset("uv offset to avoid mirror", Range(-0.1, 0.1)) = 0.01
ASE_PROPERTY_END */

/*ASE_FEATURE_START FEATURE_Dissolve
#include "Assets/Zeus/RenderFramework/Carava/MiniPBR/Shader/Include/PBRVFX.cginc"
#pragma multi_compile _ FEATURE_Dissolve
ASE_FEATURE_END */


/*ASE_PROPERTY_START FEATURE_EMISSION
[Header(Emission)]
[HDR]_EmissionColor("Emission Color", Color) = (1.0,1.0,1.0,1.0)
ASE_PROPERTY_END */

/*ASE_FEATURE_START FEATURE_EMISSION
#include "Assets/Zeus/RenderFramework/Carava/MiniPBR/Shader/Include/PBRVFX.cginc"
ASE_FEATURE_END */

/*ASE_PROPERTY_START FEATURE_RIM
[Header(Rim)]
[Toggle(FEATURE_RIM)] FEATURE_RIM("FEATURE Rim", Int) = 0
[ShowIfEnabled(FEATURE_RIM)][HDR]_RimColor("Rim Color", Color) = (1.0,1.0,1.0,1.0)
[ShowIfEnabled(FEATURE_RIM)]_RimExponent("Rim Exponent", Range(0, 20)) = 10.0
[ShowIfEnabled(FEATURE_RIM)]_RimFade("Rim Fade", Range(0, 10)) = 5.0
[ShowIfEnabled(FEATURE_RIM)]_FakeDir("Rim FakeDir", Vector) = (0.0,0.0,1.0,0.0)
ASE_PROPERTY_END */

/*ASE_FEATURE_START FEATURE_RIM
#include "Assets/Zeus/RenderFramework/Carava/MiniPBR/Shader/Include/PBRVFX.cginc"
#pragma multi_compile _ FEATURE_RIM
ASE_FEATURE_END */

// Dissolve Effect
sampler2D	_DissolveTex;
half		_DissolveBlend;
half		_BorderSize;
sampler2D	_BorderMap;
half		_DissolveUVOffset; 

 
half2 DissolveVert(half3 vertex)
{
	return vertex.xz;
}

half3 DissolveFrag(half3 finalColor, half2 uv, half2 uv_fx)
{
	float2 dis_uv = uv + uv_fx * _DissolveUVOffset;
	half dissolve = tex2D(_DissolveTex, dis_uv).r;

	half clipValue = dissolve - _DissolveBlend;
	clip(clipValue);

	if (clipValue < _BorderSize && _DissolveBlend > 0 && _DissolveBlend < 1) {
		float t = clipValue / _BorderSize;
		return tex2D(_BorderMap, float2(t, 0)).rgb;
		//return lerp(tex2D(_BorderMap, float2(t, 0)), mainColor, t);
	}
	else
	{
		return finalColor;
	}
}

void DissolveShadow(half2 uv, half2 uv_fx)
{
	float2 dis_uv = uv + uv_fx * _DissolveUVOffset;
	half dissolve = tex2D(_DissolveTex, dis_uv).r;
	clip(dissolve - _DissolveBlend);
}


// FX Light
sampler2D	_FXMap;
half		_FXScale;
half		_FXSpeed;
half		_FXPause;
half		_FXOffset;
half		_FXBump;
half		_FXIntensity;
half4		_FXColor;
half		_FXDirection;
 
half2 FXLightVert(half3 vertex, half3 normal)
{
	//half dt = 1.0 / abs(_FXSpeed);
	//float bias = min(frac(_Time.y / (dt + _FXPause)) * (dt + _FXPause) / dt, 1.0) * sign(_FXSpeed);
	float bias = frac(_Time.y * abs(_FXSpeed)) * sign(_FXSpeed);
	half2 uv;
	if (_FXDirection < 0.5)
	{
		uv = vertex.zx * _FXScale - normal.zx * normal.y * _FXBump + _FXOffset + bias.xx;
	}
	else if (_FXDirection < 1.5)
	{
		uv = vertex.xy * _FXScale - normal.xy * normal.z * _FXBump + _FXOffset + bias.xx;
	}
	else
	{
		uv = vertex.yz * _FXScale - normal.yz * normal.x * _FXBump + _FXOffset + bias.xx;
	}
	return uv;
}

half3 FXlightFrag(half3 specColor, half occlusion, half2 uv)
{
	half fx = tex2D(_FXMap, uv).r;
	half3 c = fx * 1 * _FXColor.rgb * occlusion * (specColor * 0.5 + 0.5);
	return c;
}


// Emmsion
half4		_EmissionColor;

half3 EmissionFrag(half mask)
{
	return _EmissionColor.rgb * mask;
}

// Rim
half4		_RimColor;
half		_RimExponent;
half		_RimFade;
half3		_FakeDir;

half3 RimFrag(half3 normalWorld, half3 viewDir, half mask)
{
	half nv = dot(normalWorld, viewDir);
	half rim = pow(saturate(1.0 - nv), _RimExponent);
	half3 normalView = mul((float3x3)unity_MatrixV, normalWorld);
	half3 fakeDir = normalize(_FakeDir);
	half nl = dot(normalView, fakeDir);
	half fade = saturate(nl * _RimFade);
	return rim * fade * mask * _RimColor.rgb;
}

#endif 

// _ZEUS_PBR_VFX
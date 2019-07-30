#ifndef _MINIPBR_INPUTCOMMON_
#define _MINIPBR_INPUTCOMMON_

#include "UnityCG.cginc"
#include "./Config.cginc"

// PBR Base
sampler2D   _MainTex;
float4      _MainTex_ST;
half4		_Color;
sampler2D	_BumpTex;
half		_Glossiness;
half		_Metallic;
half		_Occlusion;
sampler2D	_MSAMap;
half		_Cutoff;
sampler2D	_SpecGlossMap;

// Cartoon
half		_EdgeThickness;
half		_EdgeColorDarkness;
half		_ShadowAmount;
sampler2D	_ShadowTex;

// Anisotropy
half		_Anisotropy;
sampler2D	_TangentTex;

// Subsurface
half4		_SubsurfaceColor;
half		_SubsurfaceIntensity;
sampler2D	_SubsurfaceMask;


half3 Albedo(in float2 uv, out half alpha, out half albedoMap_a)
{
	half4 col = tex2D(_MainTex, uv) * _Color;
	half3 albedo = col.rgb;
	albedoMap_a = col.a;
	alpha = col.a;
	#if defined(_ALPHATEST_ON)
		clip(alpha - _Cutoff);
	#endif
	#ifndef _ALPHABLEND_ON
		alpha = 1.0;
	#endif
	return albedo;
}

half3 NormalTS(in float2 uv, out half normalMap_a)
{
	#ifdef USE_NORMAL_MAP
		half4 bump = tex2D(_BumpTex, uv);
		normalMap_a = bump.a;
		half3 normalTangent = UnpackNormal(bump);
	#else
		half3 normalTangent = half3(0,0,1);
		normalMap_a = 1.0;
	#endif
	return normalTangent;
}

void GetMSA(in float2 uv, out half metallic, out half smoothness, out half occlusion, out half msaMap_a)
{
	half4 msa = tex2D(_MSAMap, uv);
	#if defined(_FORMAT_METALLICSMOOTHNESSAO)
		metallic = msa.r * _Metallic;
		smoothness = msa.g * _Glossiness;
		occlusion = lerp(1.0, msa.b, _Occlusion);
	#elif defined(_FORMAT_SMOOTHNESSMETALLICAO)
		metallic = msa.g * _Metallic;
		smoothness = msa.r * _Glossiness;
		occlusion = lerp(1.0, msa.b, _Occlusion);
	#elif defined(_FORMAT_ROUGHNESSMETALLICAO)
		metallic = msa.g * _Metallic;
		smoothness = (1.0 - msa.r) * _Glossiness;
		occlusion = lerp(1.0, msa.b, _Occlusion);
	#elif defined(_FORMAT_METALLICROUGHNESSAO)
		metallic = msa.r * _Metallic;
		smoothness = (1.0 - msa.g) * _Glossiness;
		occlusion = lerp(1.0, msa.b, _Occlusion);
	#else
		metallic = _Metallic;
		smoothness = _Glossiness;
		occlusion = _Occlusion;
	#endif
	msaMap_a = msa.a;
}

void GetSpecGloss(in float2 uv, out half3 specColor, out half smoothness)
{
	half4 sg = tex2D(_SpecGlossMap, uv);
	specColor = sg.rgb;
	smoothness = sg.a * _Glossiness;
}

half3 TangentTS(float2 uv)
{
	half3 tan = tex2D(_TangentTex, uv).xyz * 2.0 - 1.0;
	return tan;
}

fixed SubsurfaceMask(float2 uv)
{
	fixed mask = tex2D(_SubsurfaceMask, uv).r;
	return mask;
}
#endif 
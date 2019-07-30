#ifndef _MINIPBR_WEATHER_
#define _MINIPBR_WEATHER_

#include "UnityCG.cginc"

/*ASE_FEATURE_START FEATURE_RAINY
#include "Assets/Zeus/RenderFramework/Carava/MiniPBR/Shader/Include/Weather.cginc"
#pragma multi_compile _ FEATURE_RAINY_RIPPLE FEATURE_RAINY_WET
ASE_FEATURE_END  */

/*ASE_PROPERTY_START FEATURE_RAINY
[Header(Rainy)]
[KeywordEnum(None, Ripple, Wet)] FEATURE_RAINY ("FEATURE Rainy", Int) = 0
[ShowIfEnabled(FEATURE_RAINY_RIPPLE)] _RainyMap("Rainy Map", 2D) = "black" {}
[ShowIfEnabled(FEATURE_RAINY_RIPPLE)] _RippleNormalMap("Ripple Normal Map", 2D) = "bump" {}
[ShowIfEnabled(FEATURE_RAINY_RIPPLE)] _RippleTiling("Ripple Tiling", Range(0,2)) = 1.0
[ShowIfEnabled(FEATURE_RAINY_RIPPLE)] _RippleEdgeWidth("Ripple Edge Width", Range(0.0, 0.2)) = 0.05
[ShowIfEnabled(FEATURE_RAINY_RIPPLE)] _RippleSpeed("Rippple Speed", Range(0,2)) = 1.0
[ShowIfEnabled(FEATURE_RAINY_RIPPLE, FEATURE_RAINY_WET)] _Wetness("Wetness", Range(0,1)) = 1.0
ASE_PROPERTY_END */

/*ASE_FEATURE_START FEATURE_HEIGHTFOG
#include "Assets/Zeus/RenderFramework/Carava/MiniPBR/Shader/Include/Weather.cginc"
#pragma multi_compile _ FEATURE_HEIGHTFOG
ASE_FEATURE_END  */

/*ASE_PROPERTY_START FEATURE_HEIGHTFOG
[Header(Rainy)]
[Toggle(FEATURE_HEIGHTFOG)] FEATURE_HEIGHTFOG ("FEATURE HeightFog", Int) = 0
ASE_PROPERTY_END */

// Rain
sampler2D	_RainyMap;
sampler2D	_RippleNormalMap;
half		_RippleTiling;
half		_RippleSpeed;
half		_RippleEdgeWidth;
half		_Wetness;

half RippleCore(half2 uv, half time)
{
	half rippleMask = tex2D (_RainyMap, uv).r;
	half t = 1.0 - frac(time);
	half ripple = abs((rippleMask - t) - _RippleEdgeWidth) / _RippleEdgeWidth;
	ripple = 1.0 - smoothstep(0.0, 1.0, ripple);
	half fade = saturate(1.0 - 2.0 * abs(t - 0.5));
	return ripple * fade;
}

void Ripple(in half3 worldPos, in half3 normalTangent, out half ripple, out half3 rippleNormal) 
{
	float time0 = _Time.y * _RippleSpeed;
	float time1 = _Time.y * _RippleSpeed + 0.5;

	float2 uv = worldPos.xz * _RippleTiling;
	float2 uv_ripple0 = uv;
	float2 uv_ripple1 = uv + 0.2;

	half ripple0 = RippleCore(uv_ripple0, time0);
	half ripple1 = RippleCore(uv_ripple1, time1);

	half3 rippleNormal0 = UnpackNormal(tex2D(_RippleNormalMap, uv_ripple0));
	half3 rippleNormal1 = UnpackNormal(tex2D(_RippleNormalMap, uv_ripple1));

	float t = 1.0 - frac(time0);
	half blendRipple = saturate(1.0 - 2.0 * abs(t - 0.5));
	ripple = lerp(ripple1, ripple0, blendRipple);

	rippleNormal = lerp(rippleNormal1, rippleNormal0, blendRipple);
	rippleNormal = BlendNormals(rippleNormal, normalTangent);
	rippleNormal = lerp(normalTangent, rippleNormal, ripple);
}

half3 RainyFrag(in half3 worldPos, in half3 vertNormalWS, in half3 normalTangent, inout half3 diffColor, inout half3 specColor, inout half smoothness)
{
	half ripple;
	half3 rippleNormal;
	#if FEATURE_RAINY_RIPPLE
		Ripple(worldPos, normalTangent, ripple, rippleNormal);
	#else
		ripple = 0.0;
		rippleNormal = half3(0.0,0.0,1.0);
	#endif
	half blendy = saturate(vertNormalWS.y);
	half finalMask = saturate(max(ripple, _Wetness) * blendy);

	diffColor = lerp(diffColor, diffColor*diffColor, saturate(finalMask*3.0));
	specColor = lerp(specColor, 0.25, saturate(finalMask*2.0));
	normalTangent = lerp(normalTangent,  half3(0.0,0.0,1.0), _Wetness);
	normalTangent = lerp(normalTangent, rippleNormal, blendy);
	smoothness = lerp(smoothness, 0.9, finalMask);
	return normalTangent;
}

// Height Fog
float _FogMinDistance;
half _FogDensity;
half _FogMaxHeight;
half _FogHeightDensity;

half4 _BaseFogColor;
half4 _HeightFogColor;
half4 _SunFogColor;

half HeightFogVert(float3 posWorld)
{
	float dist = length(posWorld.xyz - _WorldSpaceCameraPos);
	half height01 = saturate((_FogMaxHeight - posWorld.y) * _FogHeightDensity);
	half height01Sqr = height01 * height01;
	half heightCoef = height01Sqr * height01Sqr;
	dist = max(0.0, dist - _FogMinDistance);
    half fogDensity = _FogDensity * max(heightCoef, 0.1);
    half fogAmount = 1.0 - exp(-dist * fogDensity);
	return fogAmount;
}

half3 HeightFogBaseFrag(half3 finalColor, half3 lightDir, half3 viewDir, half fogAmount)
{
	half3 fogColor = _HeightFogColor.rgb * saturate(viewDir.y * 5.0 + 1.0) + _BaseFogColor.rgb;
	half VoL = saturate(dot(-viewDir, lightDir));
	fogColor = fogColor + _SunFogColor.rgb * VoL * VoL;
	half3 col = lerp(finalColor, fogColor, fogAmount);
	return col;	
}

half3 HeightFogAddFrag(half3 finalColor, half fogAmount)
{
	half3 col = finalColor - finalColor * fogAmount;
	return col;	
}

#endif 
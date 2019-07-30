#ifndef _MINIPBR_GICOMMON_
#define _MINIPBR_GICOMMON_

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityImageBasedLighting.cginc"
#include "UnityStandardUtils.cginc"

// Light Functions
inline void MainLight(out half3 lightColor, out half3 lightDir)
{
	lightColor = _LightColor0.rgb;
	lightDir = _WorldSpaceLightPos0.xyz;
}

inline void AdditiveLight(in float3 worldPos, in half atten, out half3 lightColor, out half3 lightDir)
{
    lightColor = _LightColor0.rgb;
	lightColor *= atten;
    #ifndef USING_DIRECTIONAL_LIGHT
        lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
	#else
		lightDir = _WorldSpaceLightPos0.xyz;
    #endif
}

// GI Functions
inline half4 VertexGIForward( half2 uv1, half2 uv2, float3 posWorld, half3 normalWorld )
{
	half4 ambientOrLightmapUV = 0;
	#ifdef LIGHTMAP_ON
		ambientOrLightmapUV.xy = uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
		ambientOrLightmapUV.zw = 0;
	#elif UNITY_SHOULD_SAMPLE_SH
		#ifdef VERTEXLIGHT_ON
			ambientOrLightmapUV.rgb = Shade4PointLights (
				unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
				unity_4LightAtten0, posWorld, normalWorld);
		#endif
		ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, ambientOrLightmapUV.rgb);
	#endif
	#ifdef DYNAMICLIGHTMAP_ON
		ambientOrLightmapUV.zw = uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
	#endif
	return ambientOrLightmapUV;
}

inline UnityGIInput UnityGIInputSetup( half3 lightColor, half3 lightDir, float3 posWorld, half3 viewDir, half atten, half4 i_ambientOrLightmapUV )
{
	UnityLight light;
	light.color = lightColor;
	light.dir = lightDir;

	UnityGIInput data;
	data.light = light;
	data.worldPos = posWorld;
	data.worldViewDir = viewDir;
	data.atten = atten;
		#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
		data.ambient = 0;
		data.lightmapUV = i_ambientOrLightmapUV;
	#else
		data.ambient = i_ambientOrLightmapUV.rgb;
		data.lightmapUV = 0;
	#endif
	data.probeHDR[0] = unity_SpecCube0_HDR;
	data.probeHDR[1] = unity_SpecCube1_HDR;
	#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
	data.boxMin[0] = unity_SpecCube0_BoxMin;
	#endif
	#ifdef UNITY_SPECCUBE_BOX_PROJECTION
	data.boxMax[0] = unity_SpecCube0_BoxMax;
	data.probePosition[0] = unity_SpecCube0_ProbePosition;
	data.boxMax[1] = unity_SpecCube1_BoxMax;
	data.boxMin[1] = unity_SpecCube1_BoxMin;
	data.probePosition[1] = unity_SpecCube1_ProbePosition;
	#endif
	return data;
}

inline UnityGI FragmentGIForward( UnityGIInput d, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData g )
{
	#ifdef USE_REFLECTION
		UnityGI gi =  UnityGlobalIllumination (d, occlusion, normalWorld, g);
	#else 
		UnityGI gi =  UnityGlobalIllumination (d, occlusion, normalWorld);
		gi.indirect.specular = unity_IndirectSpecColor.rgb;
	#endif
	return gi;
}

#endif 
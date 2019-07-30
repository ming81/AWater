#ifndef _MINIPBR_UTILS_
#define _MINIPBR_UTILS_

#include "UnityCG.cginc"

inline float3 Safe_Normalize( float3 inVec )
{
	float dp3 = max(0.001f, dot(inVec, inVec));
	return inVec * rsqrt(dp3);
}

half3 NormalShift(half3 N, half3 V)
{
	float shiftAmount = dot(N, V);
	return shiftAmount < 0.0f ? N + V * (-shiftAmount + 1e-4h) : N;
}

// Anisotropy
void ConvertAnisotropyToRoughness(half roughness, half anisotropy, out half roughnessT, out half roughnessB)
{
	float anisoAspect = sqrt(1.0 - 0.9 * anisotropy);

	roughnessT = roughness / anisoAspect;
	roughnessB = roughness * anisoAspect;
}

half3 GetAnisotropicModifiedNormal(half3 binormal, half3 normal, half3 view, half anisotropy)
{
	half3 anisoTangent = cross(view, binormal);
	half3 anisoNormal = cross(binormal, anisoTangent);
	half3 reflectNormal = normalize(lerp(normal, anisoNormal, anisotropy));
	return reflectNormal;
}

#endif 
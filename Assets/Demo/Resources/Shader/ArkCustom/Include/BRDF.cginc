#ifndef _MINIPBR_BRDF_
#define _MINIPBR_BRDF_

#include "UnityCG.cginc"

// GGX
inline float D_GGX( float roughness, float nh )
{
	float a = roughness;
	float a2 = a * a;
	float d = ( nh * a2 - nh ) * nh + 1;
	return a2 / ( d*d * UNITY_PI + 1e-4h );
}
		
inline half V_SmithJointApprox( half roughness, half nv, half nl )
{
	half a = roughness;
	half Vis_SmithV = nl * ( nv * ( 1 - a ) + a );
	half Vis_SmithL = nv * ( nl * ( 1 - a ) + a );
	return 0.5 / ( Vis_SmithV + Vis_SmithL + 1e-4h );
}

inline half3 F_Schlick( half3 F0, half vh )
{
	half Fc = 1 - vh;
	half Fc2 = Fc * Fc;
	half Fc5 = Fc2 * Fc2 * Fc;
	return saturate( 50.0 * F0.g ) * Fc5 + (1 - F0) * F0;
}

inline half3 EnvBRDF_Zioma( half3 specularColor, half perceptualRoughness, half nv )
{
	half envTerm = 1.0 - max(perceptualRoughness, nv);
	half3 env = envTerm * envTerm * envTerm + specularColor;
	half surfaceReduction = saturate(1.08 - 0.58 * perceptualRoughness);
	return env * surfaceReduction;
}

// Anisotropy
inline float D_GGXaniso( float RoughnessT, float RoughnessB, float NoH, float ToH, float BoH )
{
	float aT = RoughnessT;
	float aB = RoughnessB;
	float d = ToH * ToH / (aT*aT) + BoH * BoH / (aB*aB) + NoH * NoH;
	return 1.0 / ( aT*aB * d*d * UNITY_PI + 1e-4h );
}

inline half V_SmithJointGGXAniso(half ToV, half BoV, half NoV, half ToL, half BoL, half NoL, half RoughnessT, half RoughnessB)
{
	half aT = RoughnessT;
	half aT2 = aT * aT;
	half aB = RoughnessB;
	half aB2 = aB * aB;
	half lambdaV = NoL * sqrt(aT2 * ToV * ToV + aB2 * BoV * BoV + NoV * NoV);
	half lambdaL = NoV * sqrt(aT2 * ToL * ToL + aB2 * BoL * BoL + NoL * NoL);
	return 0.5 / (lambdaV + lambdaL + 1e-4h );
}

// Cloth
inline float D_Ashikhmin( float roughness, float nh )
{
	float m2    = roughness * roughness;
	float cos2h = nh * nh;
	float sin2h = 1.0 - cos2h;
	float sin4h = sin2h * sin2h;
	return (sin4h + 4.0 * exp(-cos2h / (sin2h * m2))) / (UNITY_PI * (1.0 + 4.0 * m2) * sin4h);
}

inline float D_Charlie( float roughness, float nh )
{
	float invR = 1.0 / roughness;
	float cos2h = nh * nh;
	float sin2h = 1.0 - cos2h;
	return (2.0 + invR) * pow(sin2h, invR * 0.5) / (2.0 * UNITY_PI);
}

inline half V_Ashikhmin(half nv, half nl)
{
	return 1.0 / (4.0 * (nl + nv - nl * nv));
}

// BRDF Specular
half3 GGX_BRDF_Optimized( half perceptualRoughness, float nh, float lh, half3 specColor )
{
	half a = perceptualRoughness * perceptualRoughness;
	float a2 = a * a;
	float d = nh * nh * (a2 - 1.h) + 1.00001h;
	half specularTerm = a2 / (max(0.1h, lh*lh) * (perceptualRoughness + 0.5h) * (d * d + 1e-4h) * 4);
	specularTerm = specularTerm - 1e-4h;
	return specularTerm * specColor;
}

half3 GGX_BRDF_Standard( half perceptualRoughness, float nv, float nl, float nh, float lh, half3 specColor )
{
	half roughness = perceptualRoughness * perceptualRoughness;
	half D = D_GGX(roughness, nh);
	half V = V_SmithJointApprox(roughness, nv, nl);
	half3 F = F_Schlick(specColor, lh );
	half3 specularTerm = D * V * F * UNITY_PI;
	return specularTerm;
}

half3 BlinnPhong_BRDF( half perceptualRoughness, float nh, half lh, half3 specColor )
{
	half specPower = PerceptualRoughnessToSpecPower(perceptualRoughness);
	half invV = lh * lh * (1.0 - perceptualRoughness) + perceptualRoughness * perceptualRoughness;
	half invF = lh;
	half specularTerm = ((specPower + 1) * pow (nh, specPower)) / (8 * invV * invF + 1e-4h);
	specularTerm = clamp(specularTerm, 0.0, 100.0);
	return specularTerm * specColor;
}

half3 GGX_BRDF_Cloth( half perceptualRoughness, float nv, float nl, float nh, float lh, half3 specColor )
{
	half roughness = perceptualRoughness * perceptualRoughness;
	half D = D_Charlie(roughness, nh);
	half V = V_Ashikhmin(nv, nl);
	half3 F = F_Schlick(specColor, lh );
	half3 specularTerm = D * V * F * UNITY_PI;
	return specularTerm;
}

#endif 
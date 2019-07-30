#ifndef _MINIPBR_SHADINGMODELS_
#define _MINIPBR_SHADINGMODELS_

#include "UnityCG.cginc"
#include "UnityStandardUtils.cginc"
#include "./Config.cginc"
#include "./BRDF.cginc"
#include "./Utils.cginc"

// Surface Shading Model
// Optional Defines : USE_GGX_OPTIMIZED, USE_GGX_STANDARD, USE_BLINN_PHONG
half4 BRDF_PBS (half3 diffColor, half3 specColor, half smoothness, half3 normal, half3 viewDir, half3 lightColor, half3 lightDir, half3 indirectDiffuse, half3 indirectSpecular)
{
	float3 halfDir = Safe_Normalize(lightDir + viewDir);
	half nl = saturate(dot(normal, lightDir));
	float nh = saturate(dot(normal, halfDir));
	half nv = abs(dot(normal, viewDir));
	float lh = saturate(dot(lightDir, halfDir));
	half perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
	perceptualRoughness = max(0.05, perceptualRoughness);

	#if defined(USE_GGX_OPTIMIZED)
		half3 specularTerm = GGX_BRDF_Optimized(perceptualRoughness, nh, lh, specColor);
	#elif defined(USE_GGX_STANDARD)
		half3 specularTerm = GGX_BRDF_Standard(perceptualRoughness, nv, nl, nh, lh, specColor);
	#elif defined(USE_BLINN_PHONG)
		half3 specularTerm = BlinnPhong_BRDF(perceptualRoughness, nh, lh, specColor);
	#else
		half3 specularTerm = 0;
	#endif
	half3 env = EnvBRDF_Zioma(specColor, perceptualRoughness, nv);
	half3 color =	(diffColor + specularTerm) * lightColor * nl
					+ indirectDiffuse * diffColor
					+ env * indirectSpecular;					
	return half4(color, 1);
}

half4 BRDF_PBS_Cartoon (half3 diffColor, half3 specColor, half smoothness, half3 normal, half3 viewDir, half3 lightColor, half3 lightDir, half3 indirectDiffuse, half3 indirectSpecular, half shadowAmount)
{
	float3 halfDir = Safe_Normalize(lightDir + viewDir);
	half nl = saturate(dot(normal, lightDir));
	nl = smoothstep(0, shadowAmount, nl);
	float nh = saturate(dot(normal, halfDir));
	half nv = abs(dot(normal, viewDir));
	float lh = saturate(dot(lightDir, halfDir));
	half perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
	perceptualRoughness = max(0.05, perceptualRoughness);

	#if defined(USE_GGX_OPTIMIZED)
		half3 specularTerm = GGX_BRDF_Optimized(perceptualRoughness, nh, lh, specColor);
	#elif defined(USE_GGX_STANDARD)
		half3 specularTerm = GGX_BRDF_Standard(perceptualRoughness, nv, nl, nh, lh, specColor);
	#elif defined(USE_BLINN_PHONG)
		half3 specularTerm = BlinnPhong_BRDF(perceptualRoughness, nh, lh, specColor);
	#else
		half3 specularTerm = 0;
	#endif
	half3 env = EnvBRDF_Zioma(specColor, perceptualRoughness, nv);
	half3 color =	(diffColor + specularTerm) * lightColor * nl
					+ indirectDiffuse * diffColor
					+ env * indirectSpecular;					
	return half4(color, 1);
}

half4 BRDF_PBS_Cloth (half3 diffColor, half3 specColor, half smoothness, half3 normal, half3 viewDir, half3 lightColor, half3 lightDir, half3 indirectDiffuse, half3 indirectSpecular)
{
	float3 halfDir = Safe_Normalize(lightDir + viewDir);
	half nl = saturate(dot(normal, lightDir));
	float nh = saturate(dot(normal, halfDir));
	half nv = abs(dot(normal, viewDir));
	float lh = saturate(dot(lightDir, halfDir));
	half perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
	perceptualRoughness = max(0.05, perceptualRoughness);

	#if defined(USE_GGX_OPTIMIZED) || defined(USE_GGX_STANDARD)
		half3 specularTerm = GGX_BRDF_Cloth(perceptualRoughness, nv, nl, nh, lh, specColor);
	#else
		half3 specularTerm = 0;
	#endif
	half3 env = EnvBRDF_Zioma(specColor, perceptualRoughness, nv);
	half3 color =	(diffColor + specularTerm) * lightColor * nl
					+ indirectDiffuse * diffColor
					+ env * indirectSpecular;					
	return half4(color, 1);
}

half4 BRDF_PBS_Anisotropy ( half3 diffColor, half3 specColor, half smoothness, half anisotropy, half3 tangent, half3 binormal, half3 normal, half3 viewDir, half3 lightColor, half3 lightDir, half3 indirectDiffuse, half3 indirectSpecular )
{
	float3 halfDir = Safe_Normalize(lightDir + viewDir);
	half nl = saturate(dot(normal, lightDir));
	half nv = abs(dot(normal, viewDir));
	half perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
	perceptualRoughness = max(0.05, perceptualRoughness);
	half roughness = perceptualRoughness * perceptualRoughness;

	#if defined(USE_GGX_OPTIMIZED) || defined(USE_GGX_STANDARD)
		float nh = saturate(dot(normal, halfDir));
		float lh = saturate(dot(lightDir, halfDir));
		half th = dot(tangent, halfDir);
		half bh = dot(binormal, halfDir);
		half tv = dot(tangent, viewDir);
		half bv = dot(binormal, viewDir);
		half tl = dot(tangent, lightDir);
		half bl = dot(binormal, lightDir);
		half roughnessT, roughnessB;
		ConvertAnisotropyToRoughness(roughness, anisotropy, roughnessT, roughnessB);
		half D = D_GGXaniso(roughnessT, roughnessB, nh, th, bh);
		half V = V_SmithJointGGXAniso(tv, bv, nv, tl, bl, nl, roughnessT, roughnessB);
		half3 F = F_Schlick(specColor, lh );
		half3 specularTerm = D * V * F * UNITY_PI;
	#else
		half3 specularTerm = 0.0;
	#endif
		half3 env = EnvBRDF_Zioma(specColor, perceptualRoughness, nv);
		half3 color =	(diffColor + specularTerm) * lightColor * nl
						+ indirectDiffuse * diffColor
						+ env * indirectSpecular;
	return half4(color, 1);
}


// Subsurface Shading Model
half3 SubsurfaceShadingSubsurface( half3 normal, half3 viewDir, half3 lightColor, half3 lightDir, half4 subsurfaceColor )
{
	float3 halfDir = Safe_Normalize(lightDir + viewDir);
	half Opacity = subsurfaceColor.a;
	half3 SubsurfaceColor = subsurfaceColor.rgb * subsurfaceColor.rgb;

	half InScatter = pow(saturate(dot(lightDir, -viewDir)), 12) * lerp(3, 0.1f, Opacity);
	half NormalContribution = saturate(dot(normal, halfDir) * Opacity + 1 - Opacity);
	half BackScatter = NormalContribution * UNITY_INV_PI * 0.5;
	half subsurfaceTerm = lerp(BackScatter, 1, InScatter);
	return lightColor * SubsurfaceColor * subsurfaceTerm * UNITY_PI;
}

half3 SubsurfaceShadingPreintegratedSkin( half3 normal, half3 lightColor, half3 lightDir, half4 subsurfaceColor )
{
	half nl = dot(normal, lightDir);
	half Opacity = subsurfaceColor.a;
	half3 SubsurfaceColor = subsurfaceColor.rgb * subsurfaceColor.rgb;

	// Approximations for skin scatter LUT
	float x = saturate(nl * 0.5 + 0.5);
	float x2 = x * x;
	half3 c1 = saturate((x2 * half3(0.8973, 1.3784, 1.4091) + half3(-0.158, -0.4179, -0.4319)) * x2 + half3(0.0063, 0.0152, 0.0155));
	half c0 = saturate((x2 * 1.4125 - 0.4021) * x2 + 0.013);
	half3 c = lerp(c0.xxx, c1, 1.0 - Opacity);
	return lightColor * c * SubsurfaceColor * UNITY_PI;

	//half3 PreintegratedBRDF = tex2D(_PreIntegratedBRDF, half2(saturate(nl * 0.5 + 0.5), 1 - Opacity)).rgb;
	//return PreintegratedBRDF * SubsurfaceColor * occlusion * UNITY_PI;
}

half3 SubsurfaceShadingTwoSided( half3 normal, half3 viewDir, half3 lightColor, half3 lightDir, half4 subsurfaceColor )
{
	half3 SubsurfaceColor = subsurfaceColor.rgb * subsurfaceColor.rgb;
	half WrapNoL = saturate((dot(-normal, lightDir) + 0.5) / 2.25);
	float VoL = dot(viewDir, lightDir);
	float Scatter = D_GGX(0.36, saturate(-VoL));
	return lightColor * SubsurfaceColor * WrapNoL * Scatter * UNITY_PI;
}

#endif 
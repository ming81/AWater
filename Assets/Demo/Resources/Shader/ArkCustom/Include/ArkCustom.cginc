#ifndef _MINIPBR_ARKCUSTOM_
#define _MINIPBR_ARKCUSTOM_

#include "UnityCG.cginc"
#include "UnityStandardUtils.cginc"
#include "./Config.cginc"
#include "./BRDF.cginc"
#include "./Utils.cginc"

// 根据经验调整光线方向的做法。 星空物语的需求。
half AdjustedNdotL (half3 normal, half3 viewDir, half3 lightDir, half shadowAmount, half shadowCutPosition, half rimShadowAmount, half rimShadowCutPosition, half viewRelativity )
{
	half nl = dot(normal, lightDir);  	// 重复了所以可优化


	//float3 lightDirAdjusted = Safe_Normalize(lerp(lightDir, viewDir, viewRelativity));			// 插值计算
	float2 lightDirXZ = lightDir.xz;
	float lightDirXZLength = length(lightDirXZ);
	float2 lightDirXZAdjusted = lerp(lightDirXZ, viewDir.xz, viewRelativity); 						// 仅仅计算水平坐标上的插值，不计算高度。这里没有用安全归一化，可能有问题。
	lightDirXZAdjusted = normalize(lightDirXZAdjusted) * lightDirXZLength;
	float3 lightDirAdjusted = float3(lightDirXZAdjusted.x, lightDir.y, lightDirXZAdjusted.y); 		// 结合调整后的水平向量和高度向量。
	lightDirAdjusted = normalize(lightDirAdjusted);													// 保险起见进行一次归一化

	half nlAdjusted = dot(normal, lightDirAdjusted);

	nl = saturate(nl + shadowCutPosition);															// 真实影子
	nl = smoothstep(0, shadowAmount, nl);

	nlAdjusted = saturate(nlAdjusted + rimShadowCutPosition);
	nlAdjusted = smoothstep(0, rimShadowAmount, nlAdjusted);

	nlAdjusted = min(nl, nlAdjusted);		// 取最小值

	return nlAdjusted;
}

half4 BRDF_PBS_Cartoon_ArkCustom (half3 diffColor, half3 specColor, half smoothness, half3 normal, half3 viewDir, half3 lightColor, half3 lightDir, half3 indirectDiffuse, half3 indirectSpecular, half nlAdjusted)
{
	float3 halfDir = Safe_Normalize(lightDir + viewDir);
	//half nl = saturate(dot(normal, lightDir));
	half nl = dot(normal, lightDir);    // 增加切换的空间
	//nl = saturate(nl + shadowCutPosition);
	//nl = smoothstep(0, shadowAmount, nl);

	float nh = saturate(dot(normal, halfDir));

	// 按比例计算折中位置
	// half ndotv = saturate(dot(lightDir, viewDir));
	// ndotv = 1 - (1 - ndotv) * (1 - ndotv);

	//half nlAdjusted = AdjustedNdotL(normal, viewDir, lightDir, shadowAmount, shadowCutPosition, lightBaseShadowOffset, viewRelativity);

	nl = saturate(nl); 	// 做区间避免额外的错误。


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
	// half3 color =	(diffColor + specularTerm) * lightColor * nl
	// 				+ indirectDiffuse * diffColor
	// 				+ env * indirectSpecular;		
	half3 color =	specularTerm * lightColor * nl
					+ diffColor * lightColor //* nlAdjusted
					+ indirectDiffuse * diffColor
					+ env * indirectSpecular;	
	//return half4(nlAdjusted, nlAdjusted, nlAdjusted, 1);	
	return half4(color, 1);
	//return half4(diffColor * lightColor * nhAdjusted, 1);
	//return half4(indirectDiffuse * diffColor, 1);
}

#endif 
#ifndef _MINIPBR_ARKWEATHER_
#define _MINIPBR_ARKWEATHER_

#if defined(_SNOW) || defined(_RAIN)
    #define ARK_WEATHER_HEIGHT_MASK(idx) half heightMask : TEXCOORD##idx;
#else  
    #define ARK_WEATHER_HEIGHT_MASK(idx)
#endif

#if defined(_HEIGHT_FOG)
    #define ARK_WEATHER_FOG_AMOUNT(idx) half fogAmount : TEXCOORD##idx;
#else  
    #define ARK_WEATHER_FOG_AMOUNT(idx)
#endif

#if defined(_SNOW) || defined(_RAIN)
    sampler2D _HeightMap;
    half4 _HeightMapInfo;

    #define ARK_WEATHER_SAMPLE_HEIGHT_MASK(o, posWorld) o.heightMask = SampleHeightMap(posWorld);

    half SampleHeightMap(float3 posWorld)
    {
        float2 uv = posWorld.xz / 400.0;
        half h = tex2Dlod(_HeightMap, half4(uv, 0, 0)).r;
        h = _HeightMapInfo.x + h * _HeightMapInfo.y;
        return step(0.0, posWorld.y - h + 1.0);
    }
#else  
    #define ARK_WEATHER_SAMPLE_HEIGHT_MASK(o, posWorld)
#endif

#if defined(_HEIGHT_FOG)
    half4 _FogInfo; // fogInfo : start distance, density multiplier, height multiplier, fog max height
    half4 _FogColor0;
    half4 _FogColor1;
    half4 _FogColor2;

    #define ARK_WEATHER_CALC_FOG_AMOUNT(o, worldPos) o.fogAmount = CalcFogAmountVS(worldPos);
    
    half CalcFogAmountVS(half3 worldPos)
    {
    	float dist = length(worldPos.xyz - _WorldSpaceCameraPos);
    	half height01 = saturate((_FogInfo.w - worldPos.y) * _FogInfo.z);
    	half heightCoef = height01 * height01 * height01 * height01;
    	half d = max(0.0, dist - _FogInfo.x);
    	half c = _FogInfo.y * max(heightCoef, 0.1);
    	half fogAmount = (1.0 - exp(-d * c));
    	return fogAmount * fogAmount;
    }
#else  
    #define ARK_WEATHER_CALC_FOG_AMOUNT(o, posWorld)
#endif

#if defined(_SNOW)
    //normal, albedo, specColor, smoothness, occlusion为inout参数
    #define ARK_APPLY_SNOW(i, posWorld, occlusion, vertNormal, normal, albedo, specColor, smoothness) half snowMask = ApplySnow(posWorld, i.heightMask, occlusion, vertNormal, normal, albedo, specColor, smoothness, occlusion);
    #define ARK_APPLY_SNOW_COLOR(color, normal, viewDir, lightColor, lightDir) color.rgb = color.rgb + SnowSSS(normal, viewDir, lightDir) * lightColor * snowMask;

    sampler2D _SnowAlbedoMap;	// rgb:albedo, a:smoothness
    sampler2D _SnowNormalMap;	// rg: normal, b:height, a:ao
    half _SnowTiling;
    half _SnowProgress;
    half _SnowRange;
    half _SnowTopAmount;
    half _SnowBottomAmount;
    half _SnowNormalIntensity;
    half4 _SnowSSSColor;
    half _SnowMinLevel;

    half ApplySnow(float3 posWorld, half maskVS, half height, half3 vertNormalWS, inout half3 normalWS, inout half3 diffColor, inout half3 specColor, inout half smoothness, inout half occlusion)
    {
        float2 uv = -posWorld.xz * _SnowTiling * 0.1;
        half4 sa = tex2D(_SnowAlbedoMap, uv);
        half4 sn = tex2D(_SnowNormalMap, uv);
        half snowHeight = sn.b;
        half level = _SnowProgress * lerp(_SnowTopAmount, _SnowBottomAmount, saturate(normalWS.y));
        half mask = saturate((normalWS.y - 1.0 + _SnowRange) * level * lerp(0.25, 1.0, snowHeight));
        mask = mask * mask;
        half mask2 = smoothstep(snowHeight-0.5, snowHeight, maskVS);
        mask2 = lerp(_SnowMinLevel, 1.0, mask2);
        mask = mask * lerp(1.0, mask2, saturate(2.0 * vertNormalWS.y));
        diffColor = lerp(diffColor, sa.rgb*0.8, mask);
        sn.xy = sn.xy * 2 - 1;
        sn.xy *= _SnowNormalIntensity;
        half z = sqrt(1 - saturate(dot(sn.xy, sn.xy)));
        half3 snormalWS = half3(-sn.x, z, -sn.y);
        normalWS = lerp(normalWS, snormalWS, mask);
        smoothness = lerp(smoothness, sa.a, mask);
        specColor = lerp(specColor, 0.2, mask);
        occlusion = lerp(occlusion, sn.a, mask);
        return mask;
    }

    half3 SnowSSS(half3 N, half3 V, half3 L)
    {
        half3 H = normalize(L + V);
        half Opacity = _SnowSSSColor.a;
        half InScatter = pow(saturate(dot(L, -V)), 12.0) * lerp(3.0, 0.1f, Opacity);
        half NdotH = dot(N, H);
        half NormalContribution = saturate(NdotH * Opacity + 1 - Opacity);
        half BackScatter = NormalContribution / (UNITY_PI * 2);
        half3 col = lerp(BackScatter, 1, InScatter) * _SnowSSSColor.rgb;
        return col;
    }
#else
    #define ARK_APPLY_SNOW(i, posWorld, occlusion, vertNormal, normal, albedo, specColor, smoothness)
    #define ARK_APPLY_SNOW_COLOR(color, normal, viewDir, lightColor, lightDir)
#endif

#if defined(_RAIN)
    //normal, albedo, specColor, smoothness, occlusion为inout参数
    #define ARK_APPLY_RIPPLE(i, posWorld, occlusion, normal, albedo, specColor, smoothness) ApplyRipple(posWorld, i.heightMask, 0.8*occlusion, 1.0, normal, albedo, specColor, smoothness, occlusion);
	
	sampler2D _RippleTexture;
	sampler2D _RainAnimTexture;
	half _RainProgress;
	half _Wetness;

    half ClampRange(half input, half minimum, half maximum)
    {
        return saturate((input - minimum) / (maximum - minimum));
    }

    void DoWetProcess(inout half3 diffuse, inout half3 specular, inout half smoothness, inout half occlusion, half WetLevel)
    {
        diffuse = lerp(diffuse, diffuse*diffuse, ClampRange(WetLevel, 0.0, 0.35));
        smoothness = lerp(smoothness, 0.9, ClampRange(WetLevel, 0.2, 1.0));
        specular = lerp(specular, 0.25, ClampRange(WetLevel, 0.25, 0.5));
        occlusion = lerp(occlusion, 1.0, ClampRange(WetLevel, 0.45, 0.95));
    }

    void ApplyRipple(float3 posWorld, half maskVS, half height, half puddle, inout half3 normalWS, inout half3 diffColor, inout half3 specColor, inout half smoothness, inout half occlusion)
    {
        half4 AnimateValues = tex2Dlod(_RainAnimTexture, half4(_RainProgress, 0.5, 0.0, 0.0));
        half2 FloodLevel = AnimateValues.zw; // HM, VC
        half  WetLevel = AnimateValues.y * _Wetness;
        half  RainIntensity = AnimateValues.x;
        half mask = saturate(normalWS.y * 2.0 - 0.6);
        mask *= smoothstep(0.5, 1.0, maskVS);
        half2 AccumulatedWaters;
        AccumulatedWaters.x = min(FloodLevel.x, 1.0 - height);
        AccumulatedWaters.y = saturate((FloodLevel.y - puddle) / 0.4);
        half AccumulatedWater = max(AccumulatedWaters.x, AccumulatedWaters.y) * mask;
        float2 uv = posWorld.xz*0.1;
        float3 RippleNormal = normalize(tex2D(_RippleTexture, uv).rgb * 2.0 - 1.0);
        RippleNormal = half3(RippleNormal.x, RippleNormal.z, RippleNormal.y);
        half3 WaterNormal = lerp(float3(0, 1, 0), RippleNormal, saturate(RainIntensity * 100.0));
        half NewWetLevel = saturate(WetLevel + AccumulatedWater);
        DoWetProcess(diffColor, specColor, smoothness, occlusion, NewWetLevel);
        normalWS = lerp(normalWS, WaterNormal, AccumulatedWater);
    }
#else
    #define ARK_APPLY_RIPPLE(i, posWorld, occlusion, normal, albedo, specColor, smoothness)
#endif

#if defined(_HEIGHT_FOG)
    #define AKA_APPLY_HEIGHT_FOG(color, fogAmount, lightDir, viewDir) color.rgb = BlendFog(color.rgb, fogAmount, lightDir, viewDir);

    half3 BlendFog(half3 col, half fogAmount, half3 lightDir, half3 viewDir)
    {
    	half3 fogColor = _FogColor1.rgb * saturate(viewDir.y * 5.0 + 1.0) + _FogColor0.rgb;
    	half VoL = saturate(dot(-viewDir, lightDir));
    	fogColor = fogColor + _FogColor2.rgb * VoL * VoL;
    	col = col * (1.0 - fogAmount * fogAmount) + fogColor * fogAmount;
    	col = clamp(col, 0.0, 4.0);
    	return col;
    }
#else
    #define AKA_APPLY_HEIGHT_FOG(color, fogAmount, lightDir, viewDir)
#endif

#endif 
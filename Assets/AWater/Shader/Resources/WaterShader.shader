// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/WaterShader" {
	Properties{
		//_WaveScale("Wave scale", Range(0.02,0.15)) = 0.063
		_ReflDistort("Reflection distort", Range(0,0.2)) = 0.02
		_ReflDistort_Cube("Reflection distort_Cube", Range(0,0.2)) = 0.05
		_RefrDistort("Refraction distort", Range(0,0.5)) = 0.06
		_SpecDistort("Spec Distort", Range(0,10.0)) = 1.0
		_SpecPower("Spec Power", Range(20, 400)) = 100
		_ScatterIntensity("Scatter intensity", Range(0.0, 1.0)) = 0.05
		_GlobalTranslucent("Global translucent", Range(0.0, 1.0)) = 1.0
		_GlobalReflectIntensity("Global Reflect Intensity", Range(0.0, 1.0)) = 1.0
		_MaxWaterDepth("Max Water Depth", Range(0.0, 20.0)) = 10.0
		_WaterTransmittance("Water Transmittance", COLOR) = (0.065, 0.028, 0.35, 1.0)
		_ShallowScatterColor("Shallow Scatter Color", COLOR) = (0.0, 0.7, 0.3, 1.0)
		_DeepScatterColor("Deep Scatter Color", COLOR) = (0.0, 0.7, 0.3, 1.0)
		
		_WaveScale("Wave scale", Range(0.02,0.15)) = 0.063
		WaveSpeed("Wave speed (map1 x,y; map2 x,y)", Vector) = (19,9,-16,-7)
		
		_SoftEdgeScale("Soft Edge scale", Range(1.0, 100.0)) = 1.0

		[NoScaleOffset] _BumpMap("Normalmap ", 2D) = "bump" {}

		[NoScaleOffset]_FoamTexture("Foam Texture", 2D) = "white" {}
		_FoamTiling("Foam Tiling", Float) = 1
		_FoamSpeed("Foam Speed", Range(0.0, 2.0)) = 1.0
		_FoamIntensity("Foam Intensity", Range(0.0, 1.0)) = 0.5
		_FoamMaxDepth("Foam Max Depth", Range(0.0, 2.0)) = 0.5
		_FoamMinDepth("Foam Min Depth", Range(0.0, 1.0)) = 0.1
	}

		Subshader{
			Tags { "Queue" = "Transparent" "RenderType" = "Translucent" "WaterReflType" = "SSR" }

		GrabPass
		{
			"_BackgroundTexture"
		}

		Pass {
		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		#pragma multi_compile_fog
		#pragma multi_compile  WATER_NOZBUFFER WATER_HASZBUFFER
		#pragma multi_compile  WATER_REFL_CUBE WATER_REFL_SSR WATER_REFL_PLANER
		#pragma multi_compile  _ USE_COPY_DEPTH_TEXTURE

		#if WATER_REFL_SSR
			#define SSR_MINIMUM_ATTENUATION 0.275
			#define SSR_ATTENUATION_SCALE (1.0 - SSR_MINIMUM_ATTENUATION)
			#define SSR_VIGNETTE_INTENSITY 0.5
			#define SSR_VIGNETTE_SMOOTHNESS 5.
			#define _Attenuation .25
		#endif

		#define USING_DIRECTIONAL_LIGHT 1

		#include "UnityCG.cginc"

		uniform float4 _WaveScale4;
		uniform float4 _WaveOffset;
		uniform float _ReflDistort;
		uniform float _ReflDistort_Cube;
		uniform float _RefrDistort;
		uniform float _SpecDistort;
		uniform float _SpecPower;
		uniform float _ScatterIntensity;
		uniform float _GlobalTranslucent;
		uniform float _GlobalReflectIntensity;
		uniform float _MaxWaterDepth;
		uniform float _SoftEdgeScale;

		uniform float _FoamSpeed;
		uniform float _FoamTiling;
		uniform float _FoamIntensity;
		uniform float _FoamMaxDepth;
		uniform float _FoamMinDepth;

		uniform float4 _WaterTransmittance;
		uniform float4 _ShallowScatterColor;
		uniform float4 _DeepScatterColor;

		struct appdata {
			float4 vertex : POSITION;
			float3 normal : NORMAL;
		};

		struct v2f {
			float4 pos : SV_POSITION;

			float4 ref : TEXCOORD0;
			float4 bumpuv0 : TEXCOORD1;
			float4 bumpuv1 : TEXCOORD2;
			float3 worldPos : TEXCOORD3;
			float3 viewDir : TEXCOORD4;

			UNITY_FOG_COORDS(5)
		};

		v2f vert(appdata v)
		{
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);

			// scroll bump waves
			float4 temp;
			float4 wpos = mul(unity_ObjectToWorld, v.vertex);

			o.bumpuv0 = wpos.xzxz * _WaveScale4;
			o.bumpuv1 = _WaveOffset;
			
			o.worldPos = wpos.xyz;

			// object space view direction (will normalize per pixel)
			o.viewDir.xyz = UnityWorldSpaceViewDir(o.worldPos);
			
			o.ref = ComputeNonStereoScreenPos(o.pos);
			//o.ref.z = UnityObjectToViewPos(v.vertex).z;
			COMPUTE_EYEDEPTH(o.ref.z);
			
			UNITY_TRANSFER_FOG(o,o.pos);
			return o;
		}

#if WATER_HASZBUFFER
#if USE_COPY_DEPTH_TEXTURE
		sampler2D _CameraCopyDepthTexture;
#else
		sampler2D _CameraDepthTexture;
#endif
#endif

		#if WATER_REFL_PLANER || WATER_REFL_SSR
		sampler2D _ReflectTexture;
		#endif

		uniform sampler2D _BumpMap;  uniform float4 _BumpMap_ST;
		uniform sampler2D _FoamTexture; uniform float4 _FoamTexture_ST;
		sampler2D _BackgroundTexture;
		float4 _BackgroundTexture_TexelSize;

		#if WATER_REFL_SSR
		float Attenuate(float2 uv)
		{
			float offset = min(1.0 - max(uv.x, uv.y), min(uv.x, uv.y));

			float result = offset / (SSR_ATTENUATION_SCALE * _Attenuation + SSR_MINIMUM_ATTENUATION);
			result = saturate(result);

			return pow(result, 0.5);
		}

		float Vignette(float2 uv)
		{
			float2 k = abs(uv - 0.5) * SSR_VIGNETTE_INTENSITY;
			k.x *= _BackgroundTexture_TexelSize.y * _BackgroundTexture_TexelSize.z;
			return pow(saturate(1.0 - dot(k, k)), SSR_VIGNETTE_SMOOTHNESS);
		}
		#endif

		half4 frag(v2f i) : SV_Target
		{
			float3 vViewDir = normalize(i.viewDir.xyz);

			// normal
			float2 bumpuv0 = i.bumpuv0.xy + i.bumpuv1.xy;
			float2 bumpuv1 = i.bumpuv0.wz + i.bumpuv1.wz;
			half3 bump1 = UnpackNormal(tex2D(_BumpMap, bumpuv0)).rgb;
			half3 bump2 = UnpackNormal(tex2D(_BumpMap, bumpuv1)).rgb;
			half3 bump = (bump1 + bump2) * 0.5;
			//bump = normalize(bump);

			bump.xyz = bump.xzy;

			// fresnel factor
			half fresnelFac = dot(vViewDir, bump);

			float decodedDepth = 1.0;
			float2 ScreenUV = i.ref.xy / i.ref.w;
			// water depth

			float fEdgeFactor = 1.0;
			float4 DepthUV = i.ref;
#if WATER_HASZBUFFER
			float2 DeltaDepthUV = bump.xz * _RefrDistort;
			float4 tmpDepthUV = float4(DepthUV.xy + DeltaDepthUV, DepthUV.z, DepthUV.w);
#if USE_COPY_DEPTH_TEXTURE
			decodedDepth = tex2Dproj(_CameraCopyDepthTexture, tmpDepthUV).r;
#else
			decodedDepth = tex2Dproj(_CameraDepthTexture, tmpDepthUV).r;
#endif
			decodedDepth = LinearEyeDepth(decodedDepth);
			float pixelDepth = i.ref.z;
			float waterDepth = decodedDepth - abs(pixelDepth);
			if (waterDepth < 0.0)
			{
				DeltaDepthUV = float2(0, 0);
#if USE_COPY_DEPTH_TEXTURE
				decodedDepth = tex2D(_CameraCopyDepthTexture, ScreenUV).r;
#else
				decodedDepth = tex2D(_CameraDepthTexture, ScreenUV).r;
#endif
				decodedDepth = LinearEyeDepth(decodedDepth);
				waterDepth = decodedDepth - abs(pixelDepth);
			}
			waterDepth = max(0, waterDepth);
			fEdgeFactor = saturate(waterDepth * _SoftEdgeScale); // soft edge.
#endif

			
			float3 vLight = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz, _WorldSpaceLightPos0.w));
			float3 vNormal = normalize(float3(0, 1, 0) + bump.xyz * _RefrDistort);

			// Cube Reflection
			float3 vReflectNormal = normalize(float3(0, 1, 0) + bump.xyz * _ReflDistort_Cube);
			float3 vRefReflect = reflect(vViewDir.xyz * -1, vReflectNormal);
			half4 reflcube = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, vRefReflect);
			half4 refl = reflcube;

			// SSR or Planer Reflection
		#if WATER_REFL_SSR
			//return tex2D(_ReflectTexture, ScreenUV);
			half4 reflssr = tex2D(_ReflectTexture, ScreenUV - bump.xz * _ReflDistort);
			{
				//reflssr.w = reflssr.w < 0.50 ? 0.0 : reflssr.w;
				reflssr.w *= Attenuate(ScreenUV) * Vignette(ScreenUV);

				refl.xyz = lerp(reflssr.xyz, reflcube.xyz, 1.0 - reflssr.w);
				//refl.xyz = reflssr.xyz;
				refl.w = 1.0;
				//refl.w = reflssr.w;
			}

			//return refl;

		#elif WATER_REFL_PLANER
			refl = tex2D(_ReflectTexture, ScreenUV - bump.xz * _ReflDistort);
		#endif

			// HAS_REFRACTION
			
			//half4 refr = tex2Dproj(_BackgroundTexture, UNITY_PROJ_COORD(uv2));

			//return refr;

			float depth_damper = 1.0;
			float tNVDot = max(dot(vNormal, vViewDir), 0);

		#if WATER_HASZBUFFER
			float4 tmpRefrUV = float4(DepthUV.xy + DeltaDepthUV * fEdgeFactor, DepthUV.z, DepthUV.w);
			half4 refr = tex2Dproj(_BackgroundTexture, tmpRefrUV);

			depth_damper = min(waterDepth * 3.0, 1.0);
			float depth_samper_sss = min(waterDepth * 0.5, 1.0);
			float3 tLightVector = float3(vLight.x, 0, vLight.z);
			float tVLDot = max(dot(tLightVector, vViewDir), 0.0);
			tVLDot *= tVLDot;
			float tNLDot = dot(vNormal, vLight);
			float tVLMulNL = tVLDot * tNLDot;
			float tWaterScatterFactor = (tVLMulNL + tNVDot) * _ScatterIntensity; 
			float tWaterDepth = waterDepth * -2.0;
			float3 tExp = tWaterDepth.xxx * _WaterTransmittance;
			float3 tTransmit = pow(2.718, tExp);
			refr.xyz *= tTransmit;
			tWaterScatterFactor *= depth_samper_sss;
			float3 tWaterScatterColor = lerp(_ShallowScatterColor.xyz, _DeepScatterColor.xyz, saturate(waterDepth / _MaxWaterDepth));
			tWaterScatterColor = tWaterScatterColor * tWaterScatterFactor;
			
			refr.xyz += tWaterScatterColor * fEdgeFactor *_GlobalTranslucent;
		#else
			half4 refr = tex2D(_BackgroundTexture, ScreenUV);
			float3 tWaterScatterColor = _DeepScatterColor.xyz;
			refr.xyz = lerp(refr.xyz, tWaterScatterColor, _GlobalTranslucent);
		#endif
			// fresnel
			float fresnel = (1 - saturate(vRefReflect.y * -2)) * depth_damper;
			float r = (1 - 1.33) * (1 - 1.33) / (( 1 + 1.33) * ( 1 + 1.33));
			float fresnel_factor = r + (1 - r) * pow(saturate(1 - tNVDot), 5);
			fresnel *= fresnel_factor;
			
			//float3 halfDirection = normalize(viewDirection + lightDirection);
			float3 vHalf = normalize(vViewDir + vLight);
			float3 vSpeNormal = normalize(float3(0, 1, 0) + bump * _SpecDistort / i.ref.w);
			//float3 vSpeNormal = bump;
			float fLRDot = max(dot(vHalf, vSpeNormal), 0);

			//return float4(fLRDot.xxx, 1.0);

			float3 vSpecColor = pow(fLRDot, _SpecPower);

			float4 retColor = lerp(refr, refl, fresnel_factor * fEdgeFactor * refl.w * _GlobalReflectIntensity);
#if WATER_HASZBUFFER
			// foam
			float2 _foamPanner = i.bumpuv0.xy * _FoamTiling + i.bumpuv1.xy * _FoamSpeed;
			float foam_bubbles = tex2D(_FoamTexture, TRANSFORM_TEX(_foamPanner, _FoamTexture)).r;
			foam_bubbles = saturate(5.0 * (foam_bubbles - 0.8));
			float foamCenter = (_FoamMaxDepth + _FoamMinDepth) * 0.5;
			float foamLength = (_FoamMaxDepth - _FoamMinDepth) * 0.5;
			float tmp = saturate(abs(waterDepth - foamCenter) / foamLength);
			tmp *= tmp;
			tmp = sqrt(1 - tmp);
			tmp = pow(tmp, 10);
			retColor.xyz += foam_bubbles.rrr * _FoamIntensity * tmp;
#endif

			retColor.xyz += vSpecColor * fEdgeFactor;

			retColor.w = 1.0;

			UNITY_APPLY_FOG(i.fogCoord, retColor);
			return retColor;
	}
	ENDCG

		}
	}

}

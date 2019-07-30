/// 【引擎技术应用部 - 郑毅烨（白糖）维护】
///  这个Shader基于张天翔维护的Zeus Shader框架中的PBR-Metallic-Cartoon更改而来。
///  有三个性能等级，最高等级使用了GGX的PBR框架，中间等级使用的是blinnPhong，最低等级没有法线和高光。
///  高光和镜面反射部分仍然走的PBR金属反射部分，但漫反射部分走了风格化的Celshading，通过调整ndotl的结果来实现。
///  屏蔽了MSA的多种材质格式选项，统一使用MSA。

Shader "Carava/MiniPBR/PBR_Metallic_Cartoon_ArkCustom"
{
	Properties
	{
		[RenderingMode] _Mode ("Blend Mode", Int) = 0
		[ShowIfEnabled(_ALPHATEST_ON)] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 1.0
		[Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Int) = 2
		//[KeywordEnum(RoughnessMetallicAO, SmoothnessMetallicAO, MetallicRoughnessAO, MetallicSmoothnessAO)] _Format ("MSA Tex Format", Int) = 0
		[KeywordEnum(Highest, Medium, Lowest)] CARAVA_KEYWORD_QUALITY ("Quality", Int) = 0

		[Space(10)]
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo", 2D) = "white" {}
		_BumpTex ("Normal Map", 2D) = "bump" {}
		_MSAMap ("MSA Map", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 1.0
		_Metallic ("Metallic", Range(0,1)) = 1.0
		_MetallicThreshold ("Metallic Threshold For Toon shading", Range(0, 1)) = 0.15
		_Occlusion ("Occlusion", Range(0,1)) = 1.0

		[Toggle(_USEEMISSION)] _UseEmission("Emission", Int) = 0
		[ShowIfEnabled(_USEEMISSION)]_EmissionTex("Emission Texture", 2D) = "white"{}
		[ShowIfEnabled(_USEEMISSION)][HDR][Gamma]_EmissionColor("Emission Color", Color) = (0,0,0)

		[Header(Cartoon)]
		_EdgeThickness("Edge Thickness", Range(0,10)) = 1.0
		_EdgeColorDarkness("EdgeColor Darkness", Range(0,1)) = 1.0
		_EdgeAdditiveColor("EdgeColor Additive Color", Color) = (0,0,0,0)
		[KeywordEnum(Null,ShadowTexture,ColorMultiply,RampTexture)]_Shadow("Shadow Area Calculation", Int) = 0
		//[Toggle(_SHADOW_ALBEDO_ON)] _ShadowAlbedo("Shadow Albedo", Int) = 0
		[ShowIfEnabled(_SHADOW_SHADOWTEXTURE)] _ShadowTex("Shadow Albedo Map", 2D) = "white" {}
		[ShowIfEnabled(_SHADOW_SHADOWTEXTURE)] _ShadowTexScale("Shadow Albedo Scale", Range(0,1)) = 1
		[ShowIfEnabled(_SHADOW_COLORMULTIPLY)] _ShadowColorMultiply("Shadow Color Multiply", Color) = (1,1,1,1)
		[ShowIfEnabled(_SHADOW_RAMPTEXTURE)] _ShadowRampTexture("Ramp Texture", 2D) = "white" {}

		_RealShadowIntensity("Real Shadow Intensity", Range(0,1)) = 1

		_ShadowAmount("Shadow Amount", Range(0,1)) = 0.5
		_ShadowCutPosition("Shadow Cut Position",Range(-1,1)) = 0    							// 亮暗面的偏移值

		_RimShadowAmount("Rim Shadow Amount", Range(0,1)) = 0.5
		_RimShadowCutPosition("Rim Shadow Cut Position", Range(-1,1)) = 0

		_ViewRelativity("View Relativity", Range(0,1)) = 0.5									// 镜头的相关性

		_EnvironmentGIGain("Environment GI Gain", Float) = 1									// 环境GI增益，尝试增加GI来减少颜色的强烈对比
		[Toggle(_FLATAMBIENTLIGHT)]_FlatAmbientLight("Flat Ambient Light", Int) = 0 			// 是否使用扁平环境色，使用世界空间正上方的采样颜色取代根据法线的环境色。

		[Header(Weather)]
		_SnowMinLevel("Min Level", Range(0,1)) = 0.0
		_HeightMap("HeightMap", 2D) = "black" {}
		_HeightMapInfo("HeightMap Info", Vector) = (0, 1000, 0.1, 0)

		[Header(Dissolving)]
		[Toggle(_DISSOLVE)]_Dissolve("Use Dissolving Effect", Int) = 0
		[ShowIfEnabled(_DISSOLVE)][NoScaleOffset]_DissolveTexture("Dissolving Texture", 2D) = "white" {}
		[ShowIfEnabled(_DISSOLVE)]_DissolveProgress("Dissolving Progress", Float) = 0
		[ShowIfEnabled(_DISSOLVE)][HDR]_DissolveBorderColor("Dissolving Border Color", Color) = (1,1,1,1)
		[ShowIfEnabled(_DISSOLVE)]_DissolveBorderWidth("Dissolving Border Width", Range(0,1)) = 0.01
		[ShowIfEnabled(_DISSOLVE)]_DissolveBorderSmooth("Dissolving Border Smooth", Range(0, 0.2)) = 0.01
		[ShowIfEnabled(_DISSOLVE)]_DirectionalDissolveDirection("Directional Dissolve Direction", Vector) = (0,0,0,0)
		[ShowIfEnabled(_DISSOLVE)]_DirectionalDissolvePivot("Directional Dissolve Pivot (World Space)", Vector) = (0,0,0,0)
		[ShowIfEnabled(_DISSOLVE)]_DirectionalDissolveRange("Directional Dissolve Range", Range(0.01,10)) = 1

		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
		LOD 200

		Pass
		{
			Name "ForwardBase"
			Tags { "LightMode" = "ForwardBase" }

			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]
			Cull [_Cull]

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
            #define DIRECTIONAL 
            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ LIGHTPROBE_SH 

            #pragma multi_compile_instancing

			#pragma shader_feature _ _USEEMISSION
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON
			//#pragma shader_feature _ _SHADOW_ALBEDO_ON
			//#pragma shader_feature _FORMAT_ROUGHNESSMETALLICAO _FORMAT_SMOOTHNESSMETALLICAO _FORMAT_METALLICROUGHNESSAO _FORMAT_METALLICSMOOTHNESSAO
			#define _FORMAT_METALLICSMOOTHNESSAO
			#pragma shader_feature _SHADOW_NULL _SHADOW_SHADOWTEXTURE _SHADOW_COLORMULTIPLY _SHADOW_RAMPTEXTURE
			// #pragma multi_compile CARAVA_KEYWORD_QUALITY_HIGHEST CARAVA_KEYWORD_QUALITY_MEDIUM CARAVA_KEYWORD_QUALITY_LOWEST
			#define CARAVA_KEYWORD_QUALITY_HIGHEST
			#pragma multi_compile _ _RAIN _SNOW
			#pragma multi_compile _ _HEIGHT_FOG
			#pragma multi_compile _ _DISSOLVE

			#pragma shader_feature _ _FLATAMBIENTLIGHT

			#pragma target 3.5
			
			#include "UnityCG.cginc"
			#include "/Include/Config.cginc"
			#include "/Include/InputCommon.cginc"
			#include "/Include/GICommon.cginc"
			#include "/Include/ShadingModels.cginc"
			#include "/Include/ArkCustom.cginc"
			#include "/Include/ArkWeather.cginc"
			#include "/Include/ArkDissolve.cginc"

			half _MetallicThreshold;

			#ifdef _USEEMISSION

			sampler2D _EmissionTex;
			half4 _EmissionColor;

			#endif
			
			half _ShadowTexScale;
			half4 _ShadowColorMultiply;
			half _ShadowCutPosition;
			sampler2D _ShadowRampTexture;
			half _RealShadowIntensity;
			half _RimShadowAmount;
			half _RimShadowCutPosition;
			half _ViewRelativity;
			half _EnvironmentGIGain;
			//half _LightBaseShadowPositionOffset;

			struct VertexInput
			{
				float4 vertex		: POSITION;
				float3 normal		: NORMAL;
				float4 tangent		: TANGENT;
				half2 texcoord0		: TEXCOORD0;
				half2 texcoord1		: TEXCOORD1;
				half2 texcoord2		: TEXCOORD2;
				half4 color 		: Color;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float4 pos			: SV_POSITION;
				float2 uv0			: TEXCOORD0;
				float4 posWorld		: TEXCOORD1;
				float3 normalDir	: TEXCOORD2;
				float3 tangentDir	: TEXCOORD3;
				float3 bitangentDir : TEXCOORD4;
				half4 ambientOrLightmapUV : TEXCOORD5;
				UNITY_FOG_COORDS(6)
				UNITY_SHADOW_COORDS(7)
				half4 vertexColor	: TEXCOORD8;	
				ARK_WEATHER_HEIGHT_MASK(9)
				ARK_WEATHER_FOG_AMOUNT(10)		
				UNITY_VERTEX_OUTPUT_STEREO
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			VertexOutput vert (VertexInput v) 
			{
				UNITY_SETUP_INSTANCE_ID(v);
				VertexOutput o;
				UNITY_INITIALIZE_OUTPUT(VertexOutput, o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.uv0 = TRANSFORM_TEX(v.texcoord0, _MainTex);
				o.normalDir = UnityObjectToWorldNormal(v.normal);
				o.tangentDir = UnityObjectToWorldDir(v.tangent.xyz);
				o.bitangentDir = cross(o.normalDir, o.tangentDir) * v.tangent.w * unity_WorldTransformParams.w;
				half3 v_normalWorld;
				v_normalWorld = o.normalDir;
				float4 v_posWorld;
				v_posWorld = mul(unity_ObjectToWorld, v.vertex);
				o.posWorld = v_posWorld;
				o.pos = UnityWorldToClipPos(v_posWorld.xyz);

				#if defined(_FLATAMBIENTLIGHT)
					o.ambientOrLightmapUV = VertexGIForward(v.texcoord1, v.texcoord2, o.posWorld, half3(0,1,0));
				#else
					o.ambientOrLightmapUV = VertexGIForward(v.texcoord1, v.texcoord2, o.posWorld, o.normalDir);
				#endif

				ARK_WEATHER_SAMPLE_HEIGHT_MASK(o, o.posWorld)

				ARK_WEATHER_CALC_FOG_AMOUNT(o, o.posWorld)

				UNITY_TRANSFER_SHADOW(o, v.texcoord1);
				UNITY_TRANSFER_FOG(o,o.pos);

				o.vertexColor = v.color;
				return o;
			}
			
			half4 frag (VertexOutput i) : SV_Target
			{
				// Albedo & Alpha
				half f_alpha;
				half f_albedoMap_a;
				half3 albedo = Albedo(i.uv0, f_alpha, f_albedoMap_a); 

				// Metallic, Smoothness & Occlusion
				half f_smoothness;
				half f_metallic;
				half f_occlusion;
				half f_msaMap_a;
				GetMSA(i.uv0, f_metallic, f_smoothness, f_occlusion, f_msaMap_a);

				// WorldPos
				float3 f_posWorld;
				f_posWorld = i.posWorld.xyz;
	
				// View
				half3 f_viewDirWorld;
				f_viewDirWorld = normalize(UnityWorldSpaceViewDir(f_posWorld));

				// Normal
				half f_normalMap_a;
				half3 f_normalTangent;
				f_normalTangent = NormalTS(i.uv0, f_normalMap_a);
				half3 f_vertexNormalWorld;
				f_vertexNormalWorld = 0;

				// Normal World
				float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
				half3 f_normalWorld;
				f_normalWorld = Safe_Normalize(mul(f_normalTangent, tangentTransform));

				// Light
				UNITY_LIGHT_ATTENUATION(atten, i, f_posWorld);
				half3 f_lightColor;
				half3 f_lightDirWorld;
				MainLight(f_lightColor, f_lightDirWorld);


				// Energy Conservation
				half oneMinusReflectivity;
				half3 f_specularColor;
				half3 f_diffuseColor;
				f_diffuseColor = DiffuseAndSpecularFromMetallic(albedo, f_metallic, f_specularColor, oneMinusReflectivity);

				//SNOW, RAIN, 会调整后5个参数.
				ARK_APPLY_SNOW(i, f_posWorld, f_occlusion, i.normalDir, f_normalWorld, f_diffuseColor, f_specularColor, f_smoothness)
				ARK_APPLY_RIPPLE(i, f_posWorld, f_occlusion, f_normalWorld, f_diffuseColor, f_specularColor, f_smoothness)

				// GI
				UnityGIInput giData = UnityGIInputSetup(f_lightColor, f_lightDirWorld, f_posWorld, f_viewDirWorld, atten, i.ambientOrLightmapUV);
				Unity_GlossyEnvironmentData glossEnvData = UnityGlossyEnvironmentSetup(f_smoothness, f_viewDirWorld, f_normalWorld, f_specularColor);
				UnityGI gi = FragmentGIForward(giData, f_occlusion, f_normalWorld, glossEnvData);
				//f_lightColor = gi.light.color;
				f_lightColor *= max(atten, 1 - _RealShadowIntensity);
				f_lightDirWorld = gi.light.dir;
				half3 indirectDiffuse;
				//indirectDiffuse = gi.indirect.diffuse;
				half3 indirectSpecular;
				indirectSpecular = gi.indirect.specular;

				// 调整GI
				#if defined(_FLATAMBIENTLIGHT)
					indirectDiffuse = ShadeSHPerPixel(half3(0,1,0), giData.ambient, giData.worldPos);
				#else
					indirectDiffuse = gi.indirect.diffuse;
				#endif

				indirectDiffuse *= _EnvironmentGIGain;
				//indirectSpecular *= _EnvironmentGIGain;

				// 计算卡通渲染的部分
				half adjustedNdotL;
				if(f_metallic < _MetallicThreshold)
				{
					adjustedNdotL = AdjustedNdotL(f_normalWorld, f_viewDirWorld, f_lightDirWorld, _ShadowAmount, _ShadowCutPosition, _RimShadowAmount, _RimShadowCutPosition, _ViewRelativity);
				}
				else
				{
					adjustedNdotL = dot(f_normalWorld, f_lightDirWorld);
				}

				// 阴影部分

				// Shadow Albedo  (Shadow Texture)
				#if _SHADOW_SHADOWTEXTURE
					half3 shadowAlbedo = tex2D(_ShadowTex, i.uv0).rgb * _Color.rgb;
					half3 darkSpecularColor = f_specularColor;    			// 实际上用不到，只是用来代替f_specularColor 参加DiffuseAndSpecularFromMetallic
					half3 darkDiffuseColor = DiffuseAndSpecularFromMetallic(shadowAlbedo, f_metallic, darkSpecularColor, oneMinusReflectivity);

					darkDiffuseColor = lerp(f_diffuseColor, darkDiffuseColor, _ShadowTexScale);
					
					adjustedNdotL = saturate(adjustedNdotL);	// 补充进行saturate
					adjustedNdotL = min(adjustedNdotL, atten);
					f_diffuseColor = lerp(darkDiffuseColor, f_diffuseColor, adjustedNdotL);

				// Shadow ColorMultiply
				#elif _SHADOW_COLORMULTIPLY

					half3 darkDiffuseColor = f_diffuseColor * _ShadowColorMultiply;
					adjustedNdotL = saturate(adjustedNdotL);	// 补充进行saturate
					adjustedNdotL = min(adjustedNdotL, atten);
					f_diffuseColor = lerp(darkDiffuseColor, f_diffuseColor, adjustedNdotL);

				// Ramp Texture
				#elif _SHADOW_RAMPTEXTURE

					half halfNdotL = (adjustedNdotL / 2) + 0.5;
					halfNdotL = min(halfNdotL, atten);
					// 使用G通道来判断贴图ID
					half4 ramp = tex2D (_ShadowRampTexture, half2 (halfNdotL, i.vertexColor.g));

					f_diffuseColor *= ramp;

					adjustedNdotL = saturate(adjustedNdotL);	// 在运算之后再进行saturate

				#endif


				// Surface Shading
				half4 f_finalColor;
				f_finalColor = BRDF_PBS_Cartoon_ArkCustom(f_diffuseColor, f_specularColor, f_smoothness, 
															f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, 
															indirectDiffuse, indirectSpecular, adjustedNdotL);
				
				ARK_APPLY_SNOW_COLOR(f_finalColor, f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld)

				f_finalColor.a = f_alpha;

				// Apply Emission
				#ifdef _USEEMISSION

				half3 emissionColor = _EmissionColor.rgb;

				half3 emission = tex2D(_EmissionTex, i.uv0).rgb;
				emission *= emissionColor;

				f_finalColor.rgb += emission;
				#endif

				// 应用溶解颜色
				DissolveColor(f_finalColor, i.uv0, f_posWorld);

				//UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
				// Fog
				UNITY_APPLY_FOG(i.fogCoord, f_finalColor);

				AKA_APPLY_HEIGHT_FOG(f_finalColor, i.fogAmount, f_lightDirWorld, f_viewDirWorld)

				return f_finalColor;

			}
			ENDCG
		}

		Pass
		{
			Name "Silhoute"
			Cull Front
			ZTest Less
			Blend [_SrcBlend] [_DstBlend]

			CGPROGRAM
			#pragma vertex vert_silhouette
			#pragma fragment frag_silhouette

			#pragma multi_compile_fwdbase
			#pragma skip_variants VERTEXLIGHT_ON DYNAMICLIGHTMAP_ON
			#pragma multi_compile_instancing
			#pragma multi_compile_fog
			#pragma multi_compile _ _DISSOLVE
			#pragma multi_compile _ _RAIN _SNOW
			#pragma multi_compile _ _HEIGHT_FOG

			#pragma target 3.5

			#include "UnityCG.cginc"
			#include "/Include/Config.cginc"
			#include "/Include/InputCommon.cginc"
			#include "/Include/ArkDissolve.cginc"
			#include "/Include/ArkWeather.cginc"

			struct VertexInput
			{ 
				float4 vertex		: POSITION;
				float3 normal		: NORMAL; 
				float2 uv0			: TEXCOORD0;
				half3 color			: COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{  
				float4 pos			: SV_POSITION;
				float2 uv0			: TEXCOORD0; 
				float4 worldPos 	: TEXCOORD1;
				ARK_WEATHER_HEIGHT_MASK(2)
				ARK_WEATHER_FOG_AMOUNT(3)
			};

			fixed4 _EdgeAdditiveColor;

			#define INV_EDGE_THICKNESS_DIVISOR 0.002

			VertexOutput vert_silhouette(VertexInput v)
			{
				UNITY_SETUP_INSTANCE_ID(v);
				VertexOutput o;
				UNITY_INITIALIZE_OUTPUT(VertexOutput, o);
				//UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.uv0 = TRANSFORM_TEX(v.uv0, _MainTex);
				half3 v_normalWorld;
				v_normalWorld = 0;
				float4 v_posWorld;
				v_posWorld = mul(unity_ObjectToWorld, v.vertex);
				o.worldPos = v_posWorld;
				o.pos = UnityWorldToClipPos(v_posWorld.xyz); 

				float3 normalVS = normalize(mul((float3x3)UNITY_MATRIX_IT_MV, v.normal));
				float2 offset = TransformViewToProjection(normalVS.xy);
				float edgeThickness = _EdgeThickness * INV_EDGE_THICKNESS_DIVISOR  * clamp(o.pos.w, 0.5, 1.2) * v.color.g;
				o.pos.xy += offset * edgeThickness;
				o.pos.z -= (1 - v.color.b) * edgeThickness;

				ARK_WEATHER_SAMPLE_HEIGHT_MASK(o, o.worldPos)

				ARK_WEATHER_CALC_FOG_AMOUNT(o, o.worldPos)
				return o;  
			}

			fixed4 frag_silhouette(VertexOutput i) : SV_Target
			{ 
				fixed4 albedo;
				albedo = tex2D(_MainTex, i.uv0);
				half4 finalColor;
				finalColor.rgb = albedo.rgb * (1.0 - _EdgeColorDarkness);
				finalColor.a = 1.0;

				// 增加额外颜色，但是这要求把边缘色的Darkness调到最高
				finalColor.rgb += _EdgeAdditiveColor.rgb * _EdgeAdditiveColor.a;

				DissolveColor(finalColor, i.uv0, i.worldPos) 

				return finalColor;
			}
			ENDCG
		}

		// Pass
		// {
		// 	Name "ForwardAdd"
		// 	Tags { "LightMode" = "ForwardAdd" }

		// 	ZTest LEqual
		// 	Blend [_SrcBlend] One
		// 	ZWrite Off
		// 	Cull [_Cull]
		// 	Fog { Color(0,0,0,0) }

		// 	CGPROGRAM
		// 	#pragma vertex vert
		// 	#pragma fragment frag

		// 	#pragma multi_compile_fwdadd_fullshadows
		// 	#pragma multi_compile_fog

		// 	#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON
		// 	#pragma shader_feature _ _SHADOW_ALBEDO_ON
		// 	#pragma shader_feature _FORMAT_ROUGHNESSMETALLICAO _FORMAT_SMOOTHNESSMETALLICAO _FORMAT_METALLICROUGHNESSAO _FORMAT_METALLICSMOOTHNESSAO
		// 	#pragma multi_compile CARAVA_KEYWORD_QUALITY_HIGHEST CARAVA_KEYWORD_QUALITY_MEDIUM CARAVA_KEYWORD_QUALITY_LOWEST

		// 	#include "UnityCG.cginc"
		// 	#include "/Include/Config.cginc"
		// 	#include "/Include/InputCommon.cginc"
		// 	#include "/Include/GICommon.cginc"
		// 	#include "/Include/ShadingModels.cginc"

		// 	struct VertexInput
		// 	{
		// 		float4 vertex		: POSITION;
		// 		float3 normal		: NORMAL;
		// 		float4 tangent		: TANGENT;
		// 		half2 texcoord0		: TEXCOORD0;
		// 		half2 texcoord1		: TEXCOORD1;
		// 	};

		// 	struct VertexOutput
		// 	{
		// 		float4 pos			: SV_POSITION;
		// 		float2 uv0			: TEXCOORD0;
		// 		float4 posWorld		: TEXCOORD1;
		// 		float3 normalDir	: TEXCOORD2;
		// 		float3 tangentDir	: TEXCOORD3;
		// 		float3 bitangentDir : TEXCOORD4;
		// 		UNITY_FOG_COORDS(6)
		// 		UNITY_SHADOW_COORDS(7)
		// 		UNITY_VERTEX_OUTPUT_STEREO
		// 	};

		// 	VertexOutput vert(VertexInput v)
		// 	{
		// 		UNITY_SETUP_INSTANCE_ID(v);
		// 		VertexOutput o;
		// 		UNITY_INITIALIZE_OUTPUT(VertexOutput, o);
		// 		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

		// 		o.uv0 = TRANSFORM_TEX(v.texcoord0, _MainTex);
		// 		o.normalDir = UnityObjectToWorldNormal(v.normal);
		// 		o.tangentDir = UnityObjectToWorldDir(v.tangent.xyz);
		// 		o.bitangentDir = cross(o.normalDir, o.tangentDir) * v.tangent.w * unity_WorldTransformParams.w;
		// 		half3 v_normalWorld;
		// 		v_normalWorld = o.normalDir;
		// 		float4 v_posWorld;
		// 		v_posWorld = mul(unity_ObjectToWorld, v.vertex);
		// 		o.posWorld = v_posWorld;
		// 		o.pos = UnityWorldToClipPos(v_posWorld.xyz);

		// 		UNITY_TRANSFER_SHADOW(o, v.texcoord1);
		// 		UNITY_TRANSFER_FOG(o, o.pos);
		// 		return o; 
		// 	}

		// 	fixed4 frag(VertexOutput i) : SV_Target
		// 	{
		// 		// Albedo & Alpha
		// 		half f_alpha;
		// 		half f_albedoMap_a;
		// 		half3 albedo = Albedo(i.uv0, f_alpha, f_albedoMap_a); 

		// 		// Metallic, Smoothness & Occlusion
		// 		half f_smoothness;
		// 		half f_metallic;
		// 		half f_occlusion;
		// 		half f_msaMap_a;
		// 		GetMSA(i.uv0, f_metallic, f_smoothness, f_occlusion, f_msaMap_a);

		// 		// Energy Conservation
		// 		half oneMinusReflectivity;
		// 		half3 f_specularColor;
		// 		half3 f_diffuseColor;
		// 		f_diffuseColor = DiffuseAndSpecularFromMetallic(albedo, f_metallic, f_specularColor, oneMinusReflectivity);

		// 		// WorldPos
		// 		float3 f_posWorld;
		// 		f_posWorld = i.posWorld.xyz;
	
		// 		// View
		// 		half3 f_viewDirWorld;
		// 		f_viewDirWorld = normalize(UnityWorldSpaceViewDir(f_posWorld));

		// 		// Normal
		// 		half f_normalMap_a;
		// 		half3 f_normalTangent;
		// 		f_normalTangent = NormalTS(i.uv0, f_normalMap_a);
		// 		half3 f_vertexNormalWorld;
		// 		f_vertexNormalWorld = 0;

		// 		// Normal World
		// 		float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
		// 		half3 f_normalWorld;
		// 		f_normalWorld = Safe_Normalize(mul(f_normalTangent, tangentTransform));

		// 		// Light
		// 		UNITY_LIGHT_ATTENUATION(atten, i, f_posWorld);
		// 		half3 f_lightColor;
		// 		half3 f_lightDirWorld;
		// 		AdditiveLight(f_posWorld, atten, f_lightColor, f_lightDirWorld);

		// 		// Shadow Albedo
		// 		#if _SHADOW_ALBEDO_ON
		// 			half3 shadowAlbedo = tex2D(_ShadowTex, i.uv0).rgb * _Color.rgb;
		// 			half3 darkDiffuseColor = DiffuseAndSpecularFromMetallic(shadowAlbedo, f_metallic, f_specularColor, oneMinusReflectivity);
		// 			half nl = saturate(dot(f_normalWorld, f_lightDirWorld));
		// 			nl = smoothstep(0, _ShadowAmount, nl*atten);
		// 			f_diffuseColor = lerp(darkDiffuseColor, f_diffuseColor, nl);
		// 		#endif

		// 		// Shading model
		// 		half4 f_finalColor;
		// 		f_finalColor = BRDF_PBS(f_diffuseColor, f_specularColor, f_smoothness, f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, 0.0, 0.0);
		// 		f_finalColor.a = f_alpha;
 	
		// 		// Fog
		// 		UNITY_APPLY_FOG_COLOR(i.fogCoord, f_finalColor.rgb, half4(0,0,0,0));

		// 		return f_finalColor; 
		// 	}
		// 	ENDCG
		// }

		Pass 
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			ZWrite On
			ZTest LEqual
			Cull [_Cull]

			CGPROGRAM
			#pragma vertex vert_caster
			#pragma fragment frag_caster

			#include "UnityCG.cginc"
			#include "/Include/Config.cginc"
			#include "/Include/InputCommon.cginc"
			#include "/Include/ArkDissolve.cginc"

			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			#pragma multi_compile _ _DISSOLVE

			#pragma target 3.5

			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON

			struct appdata
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 texcoord : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f_caster
			{
				V2F_SHADOW_CASTER;
				float2 uv : TEXCOORD1;
				float4 worldPos : TEXCOORD2;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f_caster vert_caster(appdata v)
			{
				v2f_caster o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				half3 v_normalWorld;
				v_normalWorld = 0;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				return o;
			}

			fixed4 frag_caster(v2f_caster i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				fixed alpha;
				alpha = col.a;
				#if defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON)
					clip(alpha - _Cutoff);
				#endif

				DissolveSilhoute(col, i.uv, i.worldPos) 

				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
	FallBack "VertexLit"
}
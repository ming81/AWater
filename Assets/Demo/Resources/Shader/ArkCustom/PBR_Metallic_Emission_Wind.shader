/// 【引擎技术应用部 - 郑毅烨（白糖）维护】
///  这个Shader基于张天翔维护的Zeus Shader框架中的PBR-Metallic-Cartoon更改而来。
///  增加了自发光的功能。
///  屏蔽了MSA的多种材质格式选项，统一使用MSA。
///  对于当前项目来说，风的版本应该是不需要其他光照模型，在本shader中，默认使用defaultModel

Shader "Carava/MiniPBR/PBR_Metallic_Emission_Wind"
{

	Properties
	{
		//[KeywordEnum(Default, Cloth, Subsurface, Skin, Foliage, Anisotropy)] _Model ("Shading Model", Int) = 0
		[RenderingMode] _Mode("Blend Mode", Int) = 0
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
		_Occlusion ("Occlusion", Range(0,1)) = 1.0

		[Toggle(_USEEMISSION)] _UseEmission("Emission", Int) = 0
		[ShowIfEnabled(_USEEMISSION)]_EmissionTex("Emission Texture", 2D) = "white"{}
		[ShowIfEnabled(_USEEMISSION)][HDR][Gamma]_EmissionColor("Emission Color", Color) = (0,0,0)

		[Space(10)]
		[ShowIfEnabled(_MODEL_ANISOTROPY)] _Anisotropy ("Anisotropy", Range(0,1)) = 1.0
		[ShowIfEnabled(_MODEL_ANISOTROPY)] _TangentTex ("Tangent Map", 2D) = "grey" {}

		[Header(Wind)]_WindSpeed("Wind Speed", Float) = 1.0
		_WindDirection("Wind Direction", Vector) = (1,0,0,0)
		_WindIntensity("Wind Intensity", Float) = 1
		_WindBlending("Wind Blending", Float) = 1
		[Toggle(_USESIMPLEWIND)]_UseSimpleWind("Use Simple Wind", Int) = 0
		
		//[ShowIfEnabled(_MODEL_SUBSURFACE, _MODEL_SKIN, _MODEL_FOLIAGE)] _SubsurfaceColor ("Subsurface Color", Color) = (1,1,1,1)
		//[ShowIfEnabled(_MODEL_SUBSURFACE, _MODEL_SKIN, _MODEL_FOLIAGE)] _SubsurfaceIntensity ("Subsurface Intensity", Range(0.0, 5.0)) = 1.0
		//[ShowIfEnabled(_MODEL_SUBSURFACE, _MODEL_SKIN, _MODEL_FOLIAGE)] _SubsurfaceMask ("Subsurface Mask", 2D) = "white" {}

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
			//#pragma shader_feature _FORMAT_ROUGHNESSMETALLICAO _FORMAT_SMOOTHNESSMETALLICAO _FORMAT_METALLICROUGHNESSAO _FORMAT_METALLICSMOOTHNESSAO
			#define _FORMAT_METALLICSMOOTHNESSAO
			//#pragma shader_feature _MODEL_DEFAULT _MODEL_CLOTH _MODEL_SUBSURFACE _MODEL_SKIN _MODEL_FOLIAGE _MODEL_ANISOTROPY
			#define _MODEL_DEFAULT
			// #pragma multi_compile CARAVA_KEYWORD_QUALITY_HIGHEST CARAVA_KEYWORD_QUALITY_MEDIUM CARAVA_KEYWORD_QUALITY_LOWEST			
			#define CARAVA_KEYWORD_QUALITY_HIGHEST
			#pragma shader_feature _ _USESIMPLEWIND
			#pragma multi_compile _ _RAIN _SNOW
			#pragma multi_compile _ _HEIGHT_FOG

			#pragma target 3.5
			
			#include "UnityCG.cginc"
			#include "/Include/Config.cginc"
			#include "/Include/InputCommon.cginc"
			#include "/Include/GICommon.cginc"
			#include "/Include/ShadingModels.cginc"
			#include "/Include/ArkWind.cginc"
			#include "/Include/ArkWeather.cginc"

			#ifdef _USEEMISSION

			sampler2D _EmissionTex;
			half4 _EmissionColor;

			#endif
			
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
				ARK_WEATHER_HEIGHT_MASK(8)
				ARK_WEATHER_FOG_AMOUNT(9)
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

				// 增加风的影响
				#ifdef _USESIMPLEWIND
				v_posWorld.xyz += SimpleWind(v.color.r, v_posWorld.xyz);
				#else
				v_posWorld.xyz += Wind(v.color.r, v_posWorld.xyz);
				#endif

				o.posWorld = v_posWorld;
				o.pos = UnityWorldToClipPos(v_posWorld.xyz);
				o.ambientOrLightmapUV = VertexGIForward(v.texcoord1, v.texcoord2, o.posWorld, o.normalDir);

				ARK_WEATHER_SAMPLE_HEIGHT_MASK(o, o.posWorld)

				ARK_WEATHER_CALC_FOG_AMOUNT(o, o.posWorld)

				UNITY_TRANSFER_SHADOW(o, v.texcoord1);
				UNITY_TRANSFER_FOG(o,o.pos);
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

				// Energy Conservation
				half oneMinusReflectivity;
				half3 f_specularColor;
				half3 f_diffuseColor;
				f_diffuseColor = DiffuseAndSpecularFromMetallic(albedo, f_metallic, f_specularColor, oneMinusReflectivity);

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

				// Tangent
				#ifdef _MODEL_ANISOTROPY
					half3 tangentTangent = TangentTS(i.uv0);
					half3 tangentWorld = normalize(mul(tangentTangent, tangentTransform));
					half3 binormalWorld = cross(f_normalWorld, tangentWorld);
					tangentWorld = cross(binormalWorld, f_normalWorld);
					half3 anisoNormalWorld = GetAnisotropicModifiedNormal(binormalWorld, f_normalWorld, f_viewDirWorld, _Anisotropy);
				#endif 

				//SNOW, RAIN, 会调整后5个参数.
				ARK_APPLY_SNOW(i, f_posWorld, f_occlusion, i.normalDir, f_normalWorld, f_diffuseColor, f_specularColor, f_smoothness)
				ARK_APPLY_RIPPLE(i, f_posWorld, f_occlusion, f_normalWorld, f_diffuseColor, f_specularColor, f_smoothness)

				// Light
				UNITY_LIGHT_ATTENUATION(atten, i, f_posWorld);
				half3 f_lightColor;
				half3 f_lightDirWorld;
				MainLight(f_lightColor, f_lightDirWorld);

				// GI
				UnityGIInput giData = UnityGIInputSetup(f_lightColor, f_lightDirWorld, f_posWorld, f_viewDirWorld, atten, i.ambientOrLightmapUV);
				#ifdef _MODEL_ANISOTROPY
					Unity_GlossyEnvironmentData glossEnvData = UnityGlossyEnvironmentSetup(f_smoothness, f_viewDirWorld, anisoNormalWorld, f_specularColor);
					UnityGI gi = FragmentGIForward (giData, f_occlusion, anisoNormalWorld, glossEnvData);
				#else
					Unity_GlossyEnvironmentData glossEnvData = UnityGlossyEnvironmentSetup(f_smoothness, f_viewDirWorld, f_normalWorld, f_specularColor);
					UnityGI gi = FragmentGIForward(giData, f_occlusion, f_normalWorld, glossEnvData);
				#endif
				f_lightColor = gi.light.color;
				f_lightDirWorld = gi.light.dir;
				half3 indirectDiffuse;
				indirectDiffuse = gi.indirect.diffuse;
				half3 indirectSpecular;
				indirectSpecular = gi.indirect.specular;

				// Surface Shading
				half4 f_finalColor;
				#if defined(_MODEL_CLOTH)
					f_finalColor = BRDF_PBS_Cloth(f_diffuseColor, f_specularColor, f_smoothness, f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, indirectDiffuse, indirectSpecular);
				#elif defined(_MODEL_ANISOTROPY)
					f_finalColor = BRDF_PBS_Anisotropy (f_diffuseColor, f_specularColor, f_smoothness, _Anisotropy, tangentWorld, binormalWorld, f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, indirectDiffuse, indirectSpecular);
				#else
					f_finalColor = BRDF_PBS(f_diffuseColor, f_specularColor, f_smoothness, f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, indirectDiffuse, indirectSpecular);
				#endif
				f_finalColor.a = f_alpha;

				// Subsurface Shading
				fixed subsurfaceMask = SubsurfaceMask(i.uv0);
				half4 subsurfaceColor = half4(f_diffuseColor,1.0) * _SubsurfaceColor * subsurfaceMask * _SubsurfaceIntensity;
				#if defined(_MODEL_SUBSURFACE)
					half3 subcol = SubsurfaceShadingSubsurface(f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, subsurfaceColor);
				#elif defined(_MODEL_SKIN)
					half3 subcol = SubsurfaceShadingPreintegratedSkin(f_normalWorld, f_lightColor, f_lightDirWorld, subsurfaceColor);
				#elif defined(_MODEL_FOLIAGE)
					half3 subcol = SubsurfaceShadingTwoSided(f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, subsurfaceColor);
				#else
					half3 subcol = 0;
				#endif
				f_finalColor.rgb += subcol;

				ARK_APPLY_SNOW_COLOR(f_finalColor, f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld)

				// Apply Emission
				#ifdef _USEEMISSION
				half3 emissionColor = _EmissionColor.rgb;
				half3 emission = tex2D(_EmissionTex, i.uv0).rgb;
				emission *= emissionColor;
				f_finalColor.rgb += emission;

				#endif

				// Fog
				UNITY_APPLY_FOG(i.fogCoord, f_finalColor);

				AKA_APPLY_HEIGHT_FOG(f_finalColor, i.fogAmount, f_lightDirWorld, f_viewDirWorld)

				return f_finalColor;
			}
			ENDCG
		}

		Pass
		{
			Name "ForwardAdd"
			Tags { "LightMode" = "ForwardAdd" }
            
            ZTest LEqual
			Blend [_SrcBlend] One
			ZWrite Off
			Cull [_Cull]
			Fog { Color (0,0,0,0) }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON
			//#pragma shader_feature _FORMAT_ROUGHNESSMETALLICAO _FORMAT_SMOOTHNESSMETALLICAO _FORMAT_METALLICROUGHNESSAO _FORMAT_METALLICSMOOTHNESSAO
			//#pragma shader_feature _MODEL_DEFAULT _MODEL_CLOTH _MODEL_SUBSURFACE _MODEL_SKIN _MODEL_FOLIAGE _MODEL_ANISOTROPY
			#define _FORMAT_METALLICSMOOTHNESSAO
			#define _MODEL_DEFAULT
			// #pragma multi_compile CARAVA_KEYWORD_QUALITY_HIGHEST CARAVA_KEYWORD_QUALITY_MEDIUM CARAVA_KEYWORD_QUALITY_LOWEST
			#define CARAVA_KEYWORD_QUALITY_HIGHEST
			
			#include "UnityCG.cginc"
			#include "/Include/Config.cginc"
			#include "/Include/InputCommon.cginc"
			#include "/Include/GICommon.cginc"
			#include "/Include/ShadingModels.cginc"

			struct VertexInput 
			{
				float4 vertex		: POSITION;
				float3 normal		: NORMAL;
				float4 tangent		: TANGENT;
				half2 texcoord0		: TEXCOORD0;
				half2 texcoord1		: TEXCOORD1;
			};

			struct VertexOutput
			{
				float4 pos			: SV_POSITION;
				float2 uv0			: TEXCOORD0;
				float4 posWorld		: TEXCOORD1;
				float3 normalDir	: TEXCOORD2;
				float3 tangentDir	: TEXCOORD3;
				float3 bitangentDir : TEXCOORD4;
				UNITY_FOG_COORDS(6)
				UNITY_SHADOW_COORDS(7)
				UNITY_VERTEX_OUTPUT_STEREO
			};

			VertexOutput vert (VertexInput v) 
			{
				UNITY_SETUP_INSTANCE_ID(v);
				VertexOutput o;
				UNITY_INITIALIZE_OUTPUT(VertexOutput, o);
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

				UNITY_TRANSFER_SHADOW(o, v.texcoord1);
				UNITY_TRANSFER_FOG(o, o.pos);
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

				// Energy Conservation
				half oneMinusReflectivity;
				half3 f_specularColor;
				half3 f_diffuseColor;
				f_diffuseColor = DiffuseAndSpecularFromMetallic(albedo, f_metallic, f_specularColor, oneMinusReflectivity);

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

				// Tangent
				#ifdef _MODEL_ANISOTROPY
					half3 tangentTangent = TangentTS(i.uv0);
					half3 tangentWorld = normalize(mul(tangentTangent, tangentTransform));
					half3 binormalWorld = cross(f_normalWorld, tangentWorld);
					tangentWorld = cross(binormalWorld, f_normalWorld);
				#endif

				// Light
				UNITY_LIGHT_ATTENUATION(atten, i, f_posWorld);
				half3 f_lightColor;
				half3 f_lightDirWorld;
				AdditiveLight(f_posWorld, atten, f_lightColor, f_lightDirWorld);

				// Surface Shading
				half4 f_finalColor;
				#if defined(_MODEL_CLOTH)
					f_finalColor = BRDF_PBS_Cloth(f_diffuseColor, f_specularColor, f_smoothness, f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, 0.0, 0.0);
				#elif defined(_MODEL_ANISOTROPY)
					f_finalColor = BRDF_PBS_Anisotropy (f_diffuseColor, f_specularColor, f_smoothness, _Anisotropy, tangentWorld, binormalWorld, f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, 0.0, 0.0);
				#else
					f_finalColor = BRDF_PBS(f_diffuseColor, f_specularColor, f_smoothness, f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, 0.0, 0.0);
				#endif
				f_finalColor.a = f_alpha;

				// Subsurface Shading
				fixed subsurfaceMask = SubsurfaceMask(i.uv0);
				half4 subsurfaceColor = half4(f_diffuseColor,1.0) * _SubsurfaceColor * subsurfaceMask * _SubsurfaceIntensity;
				#if defined(_MODEL_SUBSURFACE)
					half3 subcol = SubsurfaceShadingSubsurface(f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, subsurfaceColor);
				#elif defined(_MODEL_SKIN)
					half3 subcol = SubsurfaceShadingPreintegratedSkin(f_normalWorld, f_lightColor, f_lightDirWorld, subsurfaceColor);
				#elif defined(_MODEL_FOLIAGE)
					half3 subcol = SubsurfaceShadingTwoSided(f_normalWorld, f_viewDirWorld, f_lightColor, f_lightDirWorld, subsurfaceColor);
				#else
					half3 subcol = 0;
				#endif
				f_finalColor.rgb += subcol;

				// Fog
				UNITY_APPLY_FOG_COLOR(i.fogCoord, f_finalColor.rgb, half4(0,0,0,0));

				return f_finalColor;
			}
			ENDCG
		}

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
			#include "/Include/ArkWind.cginc"

			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing

			#pragma shader_feature _ _USESIMPLEWIND
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON

			struct appdata_shadow {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
				half4 color   : COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f_caster 
			{
				V2F_SHADOW_CASTER;
				float2 uv : TEXCOORD1;
				UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f_caster vert_caster( appdata_shadow v )
			{
				v2f_caster o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				half3 v_normalWorld;
				v_normalWorld = 0;

				float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
				#ifdef _USESIMPLEWIND
				worldPos.xyz += SimpleWind(v.color, worldPos.xyz);
				#else
				worldPos.xyz += Wind(v.color, worldPos.xyz);
				#endif
				v.vertex = mul(unity_WorldToObject, worldPos);

				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				return o;
			}

			half4 frag_caster( v2f_caster i ) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				fixed alpha;
				alpha = col.a;
				#if defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON)
					clip(alpha - _Cutoff);
				#endif
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}
	}
	FallBack "VertexLit"
}
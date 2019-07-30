// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Skybox/CubemapWithFog" {
Properties {
    _Tint ("Tint Color", Color) = (.5, .5, .5, .5)
    [Gamma] _Exposure ("Exposure", Range(0, 8)) = 1.0
    _Rotation ("Rotation", Range(0, 360)) = 0
    [NoScaleOffset] _Tex ("Cubemap   (HDR)", Cube) = "grey" {}
	_SunColor("Sun Color", Color) = (1, 1, 1, 1)
	_SunRadius("Sun Radius", Range(0, 0.1)) = 0.01
	_SunGlowRadius("Sun Glow Radius", Range(0, 2)) = 1.0
	_SunGlowAttenuation("Sun Glow Attenuation", Range(1, 100)) = 50
	_SunCameraCorrelation("Sun Camera Correlation", Range(0, 10)) = 2
}

SubShader {
    Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
    Cull Off ZWrite Off

    Pass {

        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        #pragma target 3.0
		#pragma multi_compile _ ALTITUDE_FOG_ON

        #include "UnityCG.cginc"
		#include "AltitudeFog.cginc"

        samplerCUBE _Tex;
        half4 _Tex_HDR;
        half4 _Tint;
        half _Exposure;
        float _Rotation;
		half4 _SunColor;
		float _SunRadius;
		float _SunGlowRadius;
		float _SunGlowAttenuation;
		float _SunCameraCorrelation;

        float3 RotateAroundYInDegrees (float3 vertex, float degrees)
        {
            float alpha = degrees * UNITY_PI / 180.0;
            float sina, cosa;
            sincos(alpha, sina, cosa);
            float2x2 m = float2x2(cosa, -sina, sina, cosa);
            return float3(mul(m, vertex.xz), vertex.y).xzy;
        }

        struct appdata_t {
            float4 vertex : POSITION;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct v2f {
            float4 vertex : SV_POSITION;
            float3 texcoord : TEXCOORD0;
			float4 posWorld : TEXCOORD1;
			float cameraToLight : TEXCOORD2;
            UNITY_VERTEX_OUTPUT_STEREO
        };

		inline float CalculateCameraToLight()
		{
			float3 worldViewDir = normalize(UNITY_MATRIX_V[2].xyz);
			fixed3 lightDir = _WorldSpaceLightPos0.xyz; // after some testing I discovered that _WorldSpaceLightPos0 is a normalized vector
			return max(_SunCameraCorrelation, dot(-lightDir, worldViewDir) * (_SunCameraCorrelation + 1)) - _SunCameraCorrelation;
		}

        v2f vert (appdata_t v)
        {
            v2f o;
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
            float3 rotated = RotateAroundYInDegrees(v.vertex, _Rotation);
            o.vertex = UnityObjectToClipPos(rotated);
            o.texcoord = v.vertex.xyz;
			o.posWorld = mul(unity_ObjectToWorld, v.vertex);
			o.cameraToLight = CalculateCameraToLight();
            return o;
        }

		inline half3 MixSunColor(half3 color, float3 relativePosVec, float cameraToLight)
		{
			fixed3 lightDir = _WorldSpaceLightPos0.xyz; // after some testing I discovered that _WorldSpaceLightPos0 is a normalized vector
			float pixelToLight = length(lightDir - relativePosVec);
			float ratio = saturate((_SunRadius + _SunGlowRadius - pixelToLight) / (_SunGlowRadius + 0.001));
			ratio = pow(ratio, _SunGlowAttenuation / (cameraToLight + 0.001));
			return lerp(color, _SunColor.rgb, _SunColor.a * ratio);
		}

        fixed4 frag (v2f i) : SV_Target
        {
            half4 tex = texCUBE (_Tex, i.texcoord);
            half3 c = DecodeHDR (tex, _Tex_HDR);
            c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
            c *= _Exposure;

			// TODO: move RotateAroundYInDegrees() to vert()
			float3 relativePosVec = normalize(i.posWorld - _WorldSpaceCameraPos);
			c = MixSunColor(c, RotateAroundYInDegrees(relativePosVec, _Rotation), i.cameraToLight);

#ifdef ALTITUDE_FOG_ON
			c = ComputeSkyColor(fixed4(c, 1), relativePosVec);
#endif

            half lum = (c.r + c.g + c.b) / 6;
            return half4(c, lum);
        }
        ENDCG
    }
}


Fallback Off

}

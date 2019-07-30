// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/SSRBlurEdgeShader" {
	Properties{ _MainTex("", any) = "" {} }
		CGINCLUDE
#include "UnityCG.cginc"
		struct v2f {
		float4 pos : POSITION;
		half2 uv : TEXCOORD0;
		half2 taps[4] : TEXCOORD1;
	};
	sampler2D _MainTex;
	half4 _MainTex_TexelSize;
	half4 _BlurOffsets;
	v2f vert(appdata_img v) {
		v2f o;
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv = v.texcoord;// -_BlurOffsets.xy * _MainTex_TexelSize.xy; // hack, see BlurEffect.cs for the reason for this. let's make a new blur effect soon
		o.taps[0] = o.uv + _MainTex_TexelSize * _BlurOffsets.xy;
		o.taps[1] = o.uv - _MainTex_TexelSize * _BlurOffsets.xy;
		o.taps[2] = o.uv + _MainTex_TexelSize * _BlurOffsets.xy * half2(1, -1);
		o.taps[3] = o.uv - _MainTex_TexelSize * _BlurOffsets.xy * half2(1, -1);
		return o;
	}
	half4 frag(v2f i) : COLOR{
		half4 color = float4(0, 0, 0, 0);

		half4 texColor0 = tex2D(_MainTex, i.taps[0]);
		color += texColor0;

		half4 texColor1 = tex2D(_MainTex, i.taps[1]);
		color += texColor1;

		half4 texColor2 = tex2D(_MainTex, i.taps[2]);
		color += texColor2;

		half4 texColor3 = tex2D(_MainTex, i.taps[3]);
		color += texColor3;

		half4 texColorOrigin = tex2D(_MainTex, i.uv);
		color += texColorOrigin;
		color /= 5;

		//color.w *= color.w;
		//color.w = 1;
		return color;
	}
		ENDCG
		SubShader {
		Pass{
			 ZTest Off Cull Off ZWrite Off
			 Fog { Mode off }

			 CGPROGRAM
			 #pragma fragmentoption ARB_precision_hint_fastest
			 #pragma vertex vert
			 #pragma fragment frag
			 ENDCG
		}
	}
	Fallback off
}
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/SSREdgeStretchShader" {
	Properties{ _MainTex("", any) = "" {} }
		CGINCLUDE
#include "UnityCG.cginc"
		struct v2f {
		float4 pos : POSITION;
		half2 uv : TEXCOORD0;
	};
	sampler2D _MainTex;
	half4 _MainTex_TexelSize;
	half4 _BlurOffsets;
	v2f vert(appdata_img v) {
		v2f o;
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv = v.texcoord;// -_BlurOffsets.xy * _MainTex_TexelSize.xy; // hack, see BlurEffect.cs for the reason for this. let's make a new blur effect soon
		return o;
	}
	half4 frag(v2f i) : COLOR{
		half4 color = float4(0, 0, 0, 0);

		float2 stretchUV = float2(0, _BlurOffsets.y) * _MainTex_TexelSize.xy;

		half4 texColorOrigin = tex2D(_MainTex, i.uv);
		if (texColorOrigin.w == 0)
		{
			half4 texColor0 = tex2D(_MainTex, i.uv + stretchUV);
			color += texColor0;

			half4 texColor1 = tex2D(_MainTex, i.uv + stretchUV * 2);
			color += texColor1;

			half4 texColor2 = tex2D(_MainTex, i.uv + stretchUV * 3);
			color += texColor2;

			color /= 3;
			color.w = 1.0;
		}
		else
		{
			color = texColorOrigin;
		}
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
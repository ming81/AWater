Shader "Hidden/CameraColorCopyShader"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	}
		SubShader
	{
		Pass
		{
			Tags {"Queue" = "Geometry" }
			LOD 100
			Cull Off
			ZWrite Off
			ZTest Off
			Blend Off
			CGPROGRAM

			#include "UnityCG.cginc"

			sampler2D _MainTex;;

			struct IN
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct VertToFrag
			{
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			VertToFrag vertex_prog(IN v)
			{
				VertToFrag data;
				data.position = UnityObjectToClipPos(v.vertex);
				data.uv = v.uv;
				return data;
			}

			fixed4 fragment_prog(VertToFrag i) : COLOR0
			{
				return tex2D(_MainTex, i.uv);
			}

			#pragma vertex vertex_prog 
			#pragma fragment fragment_prog 

			ENDCG
		}
	}
}

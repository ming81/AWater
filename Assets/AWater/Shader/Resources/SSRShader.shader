Shader "Hidden/SSRShader"
{
	// We need to use internal Unity lighting structures and functions for this effect so we have to
	// stick to CGPROGRAM instead of HLSLPROGRAM

	CGINCLUDE

	#include "UnityCG.cginc"
	//#pragma target 5.0

		// Ported from StdLib, we can't include it as it'll conflict with internal Unity includes
	struct AttributesDefault
	{
		float3 vertex : POSITION;
	};

	struct VaryingsDefault
	{
		float4 pos : SV_POSITION;
		float4 uv : TEXCOORD0;
		float3 viewPos : TEXCOORD1;
	};

	VaryingsDefault VertDefault(AttributesDefault v)
	{
		VaryingsDefault o;

		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv = ComputeScreenPos(o.pos);
		o.viewPos.xyz = UnityObjectToViewPos(v.vertex);
		return o;
	}

	#include "ForwardSSR.hlsl"

	ENDCG

	SubShader
	{
		Cull Off ZWrite Off ZTest Always
		Pass
		{
			CGPROGRAM

				#pragma vertex VertDefault
				#pragma fragment FragSSR

			ENDCG
		}
	}
}

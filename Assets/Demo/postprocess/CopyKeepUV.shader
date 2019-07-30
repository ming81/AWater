Shader "Hidden/PostProcessing/CopyKeepUV"
{
    HLSLINCLUDE

        #include "../StdLib.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);

		VaryingsDefault Vert(AttributesDefault v)
		{
			VaryingsDefault o;
			o.vertex = float4(v.vertex.xy, 0.0, 1.0);
			o.texcoord = TransformTriangleVertexToUV(v.vertex.xy);
			o.texcoordStereo = TransformStereoScreenSpaceTex(o.texcoord, 1.0);
			return o;
		}

        float4 Frag(VaryingsDefault i) : SV_Target
        {
            float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);
            return color;
        }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        // 0 - Fullscreen triangle copy
        Pass
        {
            HLSLPROGRAM

                #pragma vertex Vert
                #pragma fragment Frag

            ENDHLSL
        }
    }
}

#ifndef A_FORWARD_WATER_SSR
#define A_FORWARD_WATER_SSR

#include "UnityCG.cginc"
#include "UnityStandardUtils.cginc"

#define SSR_MINIMUM_ATTENUATION 0.275
#define SSR_ATTENUATION_SCALE (1.0 - SSR_MINIMUM_ATTENUATION)

#define SSR_VIGNETTE_INTENSITY _VignetteIntensity
#define SSR_VIGNETTE_SMOOTHNESS 5.

#define SSR_COLOR_NEIGHBORHOOD_SAMPLE_SPREAD 1.0

#define SSR_FINAL_BLEND_STATIC_FACTOR 0.95
#define SSR_FINAL_BLEND_DYNAMIC_FACTOR 0.7

#define SSR_ENABLE_CONTACTS 0
#define SSR_KILL_FIREFLIES 0

//
// Helper structs
//
struct Ray
{
    float3 origin;
    float3 direction;
};

struct Segment
{
    float3 start;
    float3 end;

    float3 direction;
};

struct Result
{
	bool isHit;

	float2 uv;
	float3 position;

	int iterationCount;
};


//
// Uniforms
//
Texture2D _MainTex; SamplerState sampler_MainTex;

Texture2D _CameraCopyDepthTexture; SamplerState sampler_CameraCopyDepthTexture;
Texture2D _Noise; SamplerState sampler_Noise;

float4 _MainTex_TexelSize;

float4 _Params; // x: vignette intensity, y: distance fade, z: maximum march distance, w: blur pyramid lod count
float4 _Params2; // x: aspect ratio, y: noise tiling, z: thickness, w: maximum iteration count
#define _Attenuation .25
#define _VignetteIntensity _Params.x
#define _DistanceFade _Params.y
#define _MaximumMarchDistance _Params.z
#define _BlurPyramidLODCount _Params.w
#define _AspectRatio _Params2.x
#define _NoiseTiling _Params2.y
#define _Bandwidth _Params2.z
#define _MaximumIterationCount _Params2.w

//
// Helper functions
//

float GetSquaredDistance(float2 first, float2 second)
{
    first -= second;
    return dot(first, first);
}

float4 ProjectToScreenSpace(float3 position)
{
	float4 clip_pos = mul(UNITY_MATRIX_P, float4(position, 1.0));
	clip_pos = ComputeScreenPos(clip_pos);
	clip_pos.xyz /= clip_pos.w;

	clip_pos.xy *= _ScreenParams.xy;
	return clip_pos;;
}

// Heavily adapted from McGuire and Mara's original implementation
// http://casual-effects.blogspot.com/2014/08/screen-space-ray-tracing.html
float4 March(Ray ray, VaryingsDefault input)
{
	float4 RetColor = 0.0;
	Result result;

	result.isHit = false;

	result.uv = 0.5;
	result.position = 0.0;

	result.iterationCount = 0;

	float2 inputTexcoord = input.uv.xy / input.uv.w;

	Segment segment;

	segment.start = ray.origin;

	float end = ray.origin.z + ray.direction.z * _MaximumMarchDistance;
	float magnitude = _MaximumMarchDistance;

	//if (end > -_ProjectionParams.y)
	//	magnitude = (-_ProjectionParams.y - ray.origin.z) / ray.direction.z;

	segment.end = ray.origin + ray.direction * magnitude;

	float4 r = ProjectToScreenSpace(segment.start);
	float4 q = ProjectToScreenSpace(segment.end);

	const float2 homogenizers = rcp(float2(r.w, q.w));

	segment.start *= homogenizers.x;
	segment.end *= homogenizers.y;

	float4 endPoints = float4(r.xy, q.xy);// *homogenizers.xxyy;
	endPoints.zw += step(GetSquaredDistance(endPoints.xy, endPoints.zw), 0.0001) * max(_MainTex_TexelSize.x, _MainTex_TexelSize.y);

	float2 displacement = endPoints.zw - endPoints.xy;

	bool isPermuted = false;

	if (abs(displacement.x) < abs(displacement.y))
	{
		isPermuted = true;

		displacement = displacement.yx;
		endPoints.xyzw = endPoints.yxwz;
	}

	float direction = sign(displacement.x);
	float normalizer = direction / displacement.x;

	segment.direction = (segment.end - segment.start) * normalizer;
	float4 derivatives = float4(float2(direction, displacement.y * normalizer), (homogenizers.y - homogenizers.x) * normalizer, segment.direction.z);

	float stride = 1.0 - min(1.0, -ray.origin.z * 0.01);

	float2 uv = inputTexcoord * _NoiseTiling;
	uv.y *= _AspectRatio;

	float jitter = _Noise.SampleLevel(sampler_Noise, uv + _WorldSpaceCameraPos.xz, 0).a;
	stride *= _Bandwidth;

	derivatives *= stride;
	segment.direction *= stride;

	float2 z = 0.0;
	float4 tracker = float4(endPoints.xy, homogenizers.x, segment.start.z) + derivatives * jitter;

	UNITY_LOOP
	for (int i = 0; i < (int)_MaximumIterationCount; ++i)
	{
		if (any(result.uv <= 0.0) || any(result.uv >= 1.0))
		{
			result.isHit = false;

			return RetColor;
		}

		tracker += derivatives;

		z.x = z.y;
		z.y = tracker.w + derivatives.w * 0.5;
		z.y /= tracker.z + derivatives.z * 0.5;

//#if SSR_KILL_FIREFLIES
		UNITY_FLATTEN
			if (z.y < -_MaximumMarchDistance)
			{
				result.isHit = false;
				return RetColor;
			}
//#endif

		UNITY_FLATTEN
			if (z.y > z.x)
			{
				float k = z.x;
				z.x = z.y;
				z.y = k;
			}

		result.uv = tracker.xy;

		UNITY_FLATTEN
			if (isPermuted)
				result.uv = result.uv.yx;

		result.uv *= _MainTex_TexelSize.xy;

		float d = _CameraCopyDepthTexture.SampleLevel(sampler_CameraCopyDepthTexture, result.uv, 0);
		float depth = -LinearEyeDepth(d);

		UNITY_FLATTEN
			if (z.y < depth)
			{
				float blurW = 1.0;
#if UNITY_UV_STARTS_AT_TOP
				//blurW = sqrt(1- (1 - result.uv.y) * (1 - result.uv.y));
				//blurW = saturate(blurW);
				//blurW = pow(blurW, 2);
#else
				//blurW = sqrt(1 - result.uv.y * result.uv.y);
				//blurW = saturate(blurW);
#endif
				//result.uv = uv;
				result.isHit = true;
				result.iterationCount = i + 1;
				RetColor = _MainTex.Sample(sampler_MainTex, result.uv);
				RetColor.w = blurW;//  *(1 - result.iterationCount / _MaximumIterationCount);
				RetColor.w = 1.0;
				return RetColor;
			}
	}

	return RetColor;
}

//
// Fragment shaders
//
float4 FragSSR(VaryingsDefault i) : SV_Target
{
    float3 normal = float3(0, 1, 0);
    normal = mul((float3x3)UNITY_MATRIX_V, normal);

    Ray ray;

    ray.origin = i.viewPos;

    if (ray.origin.z < -_MaximumMarchDistance)
        return 0.0;

    ray.direction = normalize(reflect(normalize(ray.origin), normal));

    if (ray.direction.z > 0.0)
        return 0.0;

    return March(ray, i);
}


#endif // UNITY_POSTFX_SSR

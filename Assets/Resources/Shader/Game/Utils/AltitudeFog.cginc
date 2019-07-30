#include "UnityCG.cginc"

/*
*
Typical steps to add alititude fog:

0. Include altitude fog:
#include "../Include/AltitudeFog.cginc"

1. Insert multi-compile macro:
#pragma multi_compile _ ALTITUDE_FOG_ON

2. In the vertex input struct, insert:
#ifdef ALTITUDE_FOG_ON
	half2 altitudeFogCoord;
#endif

3. In vert function, insert:
#ifdef ALTITUDE_FOG_ON
	o.altitudeFogCoord = CalcAltitudeFogCoord(mul(unity_ObjectToWorld, v.vertex));
#endif

4. In frag or final function, insert:
#ifdef ALTITUDE_FOG_ON
	color = GetAltitudeFogColor(IN.altitudeFogCoord, color);
#endif
*
*/

#ifndef ALTITUDE_FOG_INCLUDED
#define ALTITUDE_FOG_INCLUDED

fixed _AltitudeFogAlpha;
float _AltitudeFogMinDistance;
float _AltitudeFogFalloffDistance;
float _AltitudeFogHeight;
float _AltitudeFogBaseHeight;
float _AltitudeFogHeightFalloff;
fixed4 _AltitudeFogColorLow;
fixed4 _AltitudeFogColorHigh;
fixed4 _AltitudeFogColorNear;
fixed _AltitudeFogHazeAlpha;
float _AltitudeFogHazeFalloff;

inline fixed4 MixColor(fixed4 color, fixed4 fogColor, float alpha)
{
	fixed4 resultColor;
	resultColor.a = color.a;
	//if (fogColor.r <= 0.5)
	//	resultColor.r = 2 * fogColor.r * color.r;
	//else
	//	resultColor.r = 1 - 2 * (1 - fogColor.r) * (1 - color.r);
	//if (fogColor.g <= 0.5)
	//	resultColor.g = 2 * fogColor.g * color.g;
	//else
	//	resultColor.g = 1 - 2 * (1 - fogColor.g) * (1 - color.g);
	//if (fogColor.b <= 0.5)
	//	resultColor.b = 2 * fogColor.b * color.b;
	//else
	//	resultColor.b = 1 - 2 * (1 - fogColor.b) * (1 - color.b);
	fixed3 stepRGB = step(fogColor.rgb, 0.5);
	resultColor.rgb = (1 - stepRGB) * (1 - 2 * (1 - fogColor.rgb) * (1 - color.rgb)) + stepRGB * (2 * fogColor.rgb * color.rgb);
	return lerp(color, resultColor, alpha);
}

inline fixed4 ComputeSkyColor(fixed4 color, float3 relativePosVec) {
	float ratio = (_AltitudeFogBaseHeight + _AltitudeFogHeight - relativePosVec.y) / (_AltitudeFogHeight + 0.001);
	fixed4 fogColorFar = lerp(_AltitudeFogColorHigh, _AltitudeFogColorLow, ratio);
	float wpy = saturate(relativePosVec.y) * _AltitudeFogHazeFalloff + 1;
	return lerp(color, fogColorFar, _AltitudeFogAlpha * saturate(_AltitudeFogHazeAlpha / wpy));
}

inline half2 CalcAltitudeFogCoord(float3 worldPos)
{
	float heightRatio = saturate((_AltitudeFogBaseHeight + _AltitudeFogHeight - worldPos.y) / (_AltitudeFogHeight + 0.001));
	float dist = length(_WorldSpaceCameraPos - worldPos);
	float distRatio = saturate((dist - _AltitudeFogMinDistance) / (_AltitudeFogFalloffDistance + 0.001));
	return half2(distRatio, heightRatio);
}

inline fixed4 GetAltitudeFogColor(half2 altitudeFogCoord, fixed4 color) {
	half heightRatio = pow(altitudeFogCoord.y, _AltitudeFogHeightFalloff);
	half distRatio = altitudeFogCoord.x;
	fixed4 fogColorFar = lerp(_AltitudeFogColorHigh, _AltitudeFogColorLow, heightRatio);
	fixed4 fogColor = lerp(_AltitudeFogColorNear, fogColorFar, distRatio);
	return MixColor(color, fogColor, _AltitudeFogAlpha * heightRatio * distRatio);
}

inline fixed4 GetAltitudeFogColorForAdditive(half2 altitudeFogCoord, fixed4 color) {
	half heightRatio = pow(altitudeFogCoord.y, _AltitudeFogHeightFalloff);
	half distRatio = altitudeFogCoord.x;
	return MixColor(color, fixed4(0, 0, 0, 0), _AltitudeFogAlpha * heightRatio * distRatio);
}

inline fixed4 GetAltitudeFogColorWithAlpha(half2 altitudeFogCoord, fixed4 color, fixed alpha) {
	half heightRatio = pow(altitudeFogCoord.y, _AltitudeFogHeightFalloff);
	half distRatio = altitudeFogCoord.x;
	fixed4 fogColorFar = lerp(_AltitudeFogColorHigh, _AltitudeFogColorLow, heightRatio);
	fixed4 fogColor = lerp(_AltitudeFogColorNear, fogColorFar, distRatio);
	return MixColor(color, fogColor, _AltitudeFogAlpha * heightRatio * distRatio * alpha);
}

#endif
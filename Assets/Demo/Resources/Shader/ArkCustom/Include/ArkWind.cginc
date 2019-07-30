#ifndef _MINIPBR_WIND_
#define _MINIPBR_WIND_

/// 【引擎技术应用部】 风的实现。

half _WindSpeed;
half4 _WindDirection;
half _WindIntensity;
half _WindBlending;
//half _WindNoise

// 实现草的碰撞（全局唯一）
half4 _GlobalGrassCollisionPos;
half _GlobalGrassCollisionRadius;
half _GlobalGrassCollisionIntensity;

half3 Wind(half vertexcolor,float3 worldPos)
{
     half3 windOffset = half3(0,0,0);
    half spaceOffset = worldPos.x + worldPos.z + sin(worldPos.x * worldPos.z * 10) * 5 ;
    half weightedTime = spaceOffset * 0.2 + _Time.y * _WindSpeed ;
    // half sin1 = sin(_Time.y + weightedTime);
    // half sin2 = sin(_Time.y * 1.25 + weightedTime);
    // half sin3 = sin(_Time.y * 0.75 + weightedTime);

    //half weightedTime = spaceOffset * 0.2 + _Time.y * _WindSpeed ;
    //half y = (sin1 + sin2 + sin3) ;
    //half sway = 1 * sin(weightedTime + 0.5 * sin(weightedTime)) + 0.5 * sin(3.4 * weightedTime) + 0.5 * sin(1.3 * weightedTime);
    half sway = 1 * sin(weightedTime + 0.5 * sin(weightedTime)) + 0.5 * sin(3.4 * weightedTime);

    // windOffset += half4(0,y * 0.1,0,0);
    // windOffset *= vertexcolor.r;

    // float theta = sin(_Time.y);
    //float theta = y;

    // float windTime = _Time.w * 0.25f;

    // float windTheta = 0.125 * cos (windTime / 0.5 * 6.28f) + 0.25 * cos(windTime / 0.73 * 6.28f) +
    //     0.5 * cos(windTime / 1.28 * 6.28f) + 1.0 * cos(windTime / 3.9 * 6.28f);

    // float leafTime = _Time.w * 0.5f + worldPos.y * 3 + worldPos.x * worldPos.y * 0.25f;

    // float leafFlutter = 0.125 * cos(leafTime / 0.5 * 6.28f) + 0.25 * cos(leafTime / 0.73 * 6.28f) + 
    //     0.5 * cos(leafTime / 1.28 * 6.28f) + 1.0 * cos (leafTime / 3.9 * 6.28f);

    // theta += 0.01 * windTheta;

    // half xoffset = cos(theta);
    // half yoffset = sin(theta);

    half2 dir = normalize(_WindDirection.xz);

    // 计算碰撞方向
    half3 collisionDirection = worldPos.xyz - _GlobalGrassCollisionPos.xyz;
    half collisionDistance = length(collisionDirection);
   
    // 计算风倒的方向
    half collisionWeight = smoothstep(_GlobalGrassCollisionRadius * 0.5, _GlobalGrassCollisionRadius, collisionDistance);
    dir = lerp(normalize(collisionDirection.xz), dir, collisionWeight);
    
    half clampedCollisionWeight = clamp(collisionWeight, 0.5, 1);
    sway = lerp(0, sway, clampedCollisionWeight);

    sway *= _WindBlending;
    half yoffset = -sin(sway) - 0.8 - (1 - collisionWeight) * _GlobalGrassCollisionIntensity;
    half horizontalOffset = cos(sway) + (1 - collisionWeight) * _GlobalGrassCollisionIntensity ;
    half xoffset = horizontalOffset * dir.x ;
    half zoffset = horizontalOffset * dir.y ;


    windOffset += half3(xoffset, yoffset ,zoffset) * vertexcolor * 0.2 * _WindIntensity;

    return windOffset;
}

half3 SimpleWind(half vertexcolor,float3 worldPos)
{
    half3 windOffset = half3(0,0,0);

    half weightedTime = _Time.y * _WindSpeed;

    half sin1 = sin(_Time.y + weightedTime);
    half sin2 = sin(_Time.y * 1.25 + weightedTime);
    half sin3 = sin(_Time.y * 0.75 + weightedTime);

    sin1 = (sin1 + sin2 + sin3) / 2;
    
    half2 dir = normalize(_WindDirection.xz);
    half xoffset = dir.x * sin1 * _WindIntensity;
    half zoffset = dir.y * sin1 * _WindIntensity;

    windOffset += half3(xoffset, 0 ,zoffset) * vertexcolor * 0.2;

    return windOffset;
}

#endif 
#ifndef _ZEUS_PBR_ANIMATION_
#define _ZEUS_PBR_ANIMATION_

#include "UnityCG.cginc"

/*ASE_FEATURE_START FEATURE_VegetationMove
#include "Assets/Zeus/RenderFramework/Carava/MiniPBR/Shader/Include/Animation.cginc"
#pragma shader_feature _ FEATURE_VegetationMove
ASE_FEATURE_END  */

/*ASE_PROPERTY_START FEATURE_VegetationMove
[Header(VegetationMove)]
[Toggle(FEATURE_VegetationMove)] FEATURE_VegetationMove("FEATURE VegetationMove", Int) = 0
[ShowIfEnabled(FEATURE_VegetationMove)] _WindDirection("Wind Direction", Vector) = (1, 0, 1, 0)
[ShowIfEnabled(FEATURE_VegetationMove)] _ModelAxis ("Model Axis", Vector) = (0, 0, 1, 0)
[ShowIfEnabled(FEATURE_VegetationMove)] _GlobalMoveFrequency("Global Move Frequency", Range(0, 50)) = 10
[ShowIfEnabled(FEATURE_VegetationMove)] _GlobalMoveFactor("Global Move Factor", Range(0, 0.1)) = 0.03
[ShowIfEnabled(FEATURE_VegetationMove)] _GlobalMovePower("Global Move Power", Range(0.5, 3)) = 10
[ShowIfEnabled(FEATURE_VegetationMove)] _BranchMoveFrequency("Branch Move Frequency", Range(0, 50)) = 10
[ShowIfEnabled(FEATURE_VegetationMove)] _BranchMoveFactor("Branch Move Factor", Range(0, 0.1)) = 0
[ShowIfEnabled(FEATURE_VegetationMove)] _BranchMovePower("Branch Move Power", Range(0.5, 3)) = 1
ASE_PROPERTY_END */

half4	_WindDirection;
half4	_ModelAxis;
half	_GlobalMoveFrequency;
half	_BranchMoveFrequency;
half	_GlobalMoveFactor;
half	_GlobalMovePower;
half	_BranchMoveFactor;
half	_BranchMovePower;

float4 VegetationMove(float3 posVertex, float3 normalWorld)
{
	float4 posLocal = float4(posVertex, 1.0);
	float4 posWorld = mul(unity_ObjectToWorld, posLocal);
	_WindDirection.y = 0;
	float GlobalMove = _Time.x * _GlobalMoveFrequency;
	float BranchMove = _Time.x * _BranchMoveFrequency;
	float axisValue = dot(posLocal, _ModelAxis);
	
	float Global_posX = abs(((frac(((posWorld.x + GlobalMove) + 0.5))* 2.0) - 1.0));
	float Global_posZ = abs(((frac(((posWorld.z + (GlobalMove * 0.65)) + 0.5))* 2.0) - 1.0));
	float d_Global_posZ = ((((Global_posZ * Global_posZ)*(3.0 - (2.0 * Global_posZ))) - 0.5) * 2.0);
	float d_Global_posX = ((((Global_posX * Global_posX)*(3.0 - (2.0 * Global_posX))) - 0.5) * 2.0);

	float Branch_posX = abs(((frac(((posWorld.x + BranchMove) + 0.5))* 2.0) - 1.0));
	float Branch_posZ = abs(((frac(((posWorld.z + (BranchMove * 0.72)) + 0.5))* 2.0) - 1.0));
	float d_Branch_posZ = ((((Branch_posZ * Branch_posZ)*(3.0 - (2.0 * Branch_posZ))) - 0.5) * 2.0);
	float d_Branch_posX = ((((Branch_posX * Branch_posX) * (3.0 -(2.0 * Branch_posX))) - 0.5) * 2.0);

	float3 GlobalOut =  (_WindDirection * ( (d_Global_posX + (d_Global_posZ * d_Global_posZ)) + 0.5)) 
		* pow (clamp ((axisValue * _GlobalMoveFactor), 0.0, 1.0), _GlobalMovePower);

	float3 BranchOut =  ((dot (_WindDirection, normalWorld) * normalWorld) * ( d_Branch_posX +  (d_Branch_posZ * d_Branch_posZ))) 
		* pow (_BranchMoveFactor, _BranchMovePower);

	posWorld.xyz = posWorld.xyz + (GlobalOut + BranchOut) * 
		(sqrt(dot(unity_ObjectToWorld[0].xyz, unity_ObjectToWorld[0].xyz)));

	float4 newPosLocal = mul(unity_WorldToObject, posWorld);

	return newPosLocal;
}

#endif // _ZEUS_PBR_VEGETATION_